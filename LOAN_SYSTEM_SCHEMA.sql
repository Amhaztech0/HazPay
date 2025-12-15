-- Loan System Schema for HazPay

-- First, ensure pricing table has proper unique constraint
CREATE UNIQUE INDEX IF NOT EXISTS idx_pricing_plan_id_unique 
ON pricing(plan_id) WHERE network_id = 1;

-- Create loans table
CREATE TABLE IF NOT EXISTS loans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id INTEGER NOT NULL,
  loan_fee DECIMAL(10, 2) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, issued, repaid, failed
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  issued_at TIMESTAMP,
  repaid_at TIMESTAMP,
  failure_reason VARCHAR(255)
);

-- Create partial unique index to allow only one active loan per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_loans_one_active_per_user 
ON loans(user_id) 
WHERE status IN ('pending', 'issued');

-- Add columns to users/profiles table to track loan eligibility and active status
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS has_active_loan BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS loan_eligible BOOLEAN DEFAULT false;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_loans_user_id ON loans(user_id);
CREATE INDEX IF NOT EXISTS idx_loans_status ON loans(status);
CREATE INDEX IF NOT EXISTS idx_loans_created_at ON loans(created_at DESC);

-- Enable RLS on loans table
ALTER TABLE loans ENABLE ROW LEVEL SECURITY;

-- RLS Policies for loans
-- Users can see their own loans
CREATE POLICY "Users can view their own loans"
  ON loans FOR SELECT
  USING (auth.uid() = user_id OR auth.jwt() ->> 'email' LIKE '%admin%');

-- Users can insert their own loan requests
CREATE POLICY "Users can request loans"
  ON loans FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Only admins can update loan status
CREATE POLICY "Only admins can update loans"
  ON loans FOR UPDATE
  USING (auth.jwt() ->> 'email' LIKE '%admin%')
  WITH CHECK (auth.jwt() ->> 'email' LIKE '%admin%');

-- Function to check loan eligibility based on transaction volume
CREATE OR REPLACE FUNCTION check_loan_eligibility(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  total_spent DECIMAL;
BEGIN
  -- Sum up all successful purchase transactions
  SELECT COALESCE(SUM(sell_price), 0)
  INTO total_spent
  FROM hazpay_transactions
  WHERE user_id = p_user_id
    AND type = 'purchase'
    AND status = 'success';
  
  -- User is eligible if they've spent ₦10,000 or more
  RETURN total_spent >= 10000;
END;
$$ LANGUAGE plpgsql;

-- Function to check if user has active loan
CREATE OR REPLACE FUNCTION has_active_loan(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS(
    SELECT 1 FROM loans
    WHERE user_id = p_user_id
      AND status IN ('pending', 'issued')
  );
END;
$$ LANGUAGE plpgsql;

-- Function to update loan eligibility status
CREATE OR REPLACE FUNCTION update_loan_eligibility_status(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE profiles
  SET 
    loan_eligible = check_loan_eligibility(p_user_id),
    has_active_loan = has_active_loan(p_user_id),
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update loan eligibility after each transaction
CREATE OR REPLACE FUNCTION update_eligibility_after_transaction()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM update_loan_eligibility_status(NEW.user_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_loan_eligibility_after_transaction
AFTER INSERT OR UPDATE ON hazpay_transactions
FOR EACH ROW
EXECUTE FUNCTION update_eligibility_after_transaction();

-- Trigger to update loan eligibility after wallet operations
CREATE OR REPLACE FUNCTION update_eligibility_after_deposit()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM update_loan_eligibility_status(NEW.user_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_eligibility_after_deposit
AFTER INSERT OR UPDATE ON hazpay_deposits
FOR EACH ROW
EXECUTE FUNCTION update_eligibility_after_deposit();

-- Verify the setup
SELECT 'Loan system schema created successfully' AS status;
