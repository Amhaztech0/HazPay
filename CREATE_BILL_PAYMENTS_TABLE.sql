-- ============================================================================
-- CREATE BILL PAYMENTS TABLE FOR PAYSCRIBE INTEGRATION
-- Created: 2025-12-15
-- Tracks electricity, cable, internet, and airtime bill payments
-- ============================================================================

-- Create bill_payments table
CREATE TABLE IF NOT EXISTS bill_payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  bill_type TEXT NOT NULL CHECK (bill_type IN ('electricity', 'cable', 'internet', 'airtime')),
  provider TEXT NOT NULL,
  account_number TEXT NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'success', 'failed')),
  reference TEXT UNIQUE NOT NULL,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_bill_payments_user ON bill_payments(user_id);
CREATE INDEX IF NOT EXISTS idx_bill_payments_created ON bill_payments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bill_payments_type ON bill_payments(bill_type);
CREATE INDEX IF NOT EXISTS idx_bill_payments_status ON bill_payments(status);
CREATE INDEX IF NOT EXISTS idx_bill_payments_reference ON bill_payments(reference);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_bill_payments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER bill_payments_updated_at
  BEFORE UPDATE ON bill_payments
  FOR EACH ROW
  EXECUTE FUNCTION update_bill_payments_updated_at();

-- Enable Row Level Security (RLS)
ALTER TABLE bill_payments ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own bill payments
CREATE POLICY "Users can view own bill payments"
  ON bill_payments
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own bill payments
CREATE POLICY "Users can create own bill payments"
  ON bill_payments
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Service role can do everything (for admin dashboard and edge functions)
CREATE POLICY "Service role full access"
  ON bill_payments
  FOR ALL
  USING (auth.role() = 'service_role');

-- Create a view for admin dashboard with user details
CREATE OR REPLACE VIEW bill_payments_with_user AS
SELECT 
  bp.*,
  p.email as user_email,
  p.name as user_name
FROM bill_payments bp
LEFT JOIN profiles p ON bp.user_id = p.id;

-- Grant access to authenticated users
GRANT SELECT ON bill_payments TO authenticated;
GRANT INSERT ON bill_payments TO authenticated;
GRANT SELECT ON bill_payments_with_user TO authenticated;

-- Grant full access to service role (for edge functions)
GRANT ALL ON bill_payments TO service_role;
GRANT ALL ON bill_payments_with_user TO service_role;

-- ============================================================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================================================

-- Uncomment to insert sample data
/*
INSERT INTO bill_payments (user_id, bill_type, provider, account_number, amount, status, reference)
VALUES 
  (
    (SELECT id FROM auth.users LIMIT 1),
    'electricity',
    'ikedc',
    '1234567890',
    5000.00,
    'success',
    'BILL_' || gen_random_uuid()
  ),
  (
    (SELECT id FROM auth.users LIMIT 1),
    'cable',
    'dstv',
    '9876543210',
    3000.00,
    'success',
    'BILL_' || gen_random_uuid()
  ),
  (
    (SELECT id FROM auth.users LIMIT 1),
    'airtime',
    'mtn',
    '08012345678',
    500.00,
    'success',
    'BILL_' || gen_random_uuid()
  );
*/

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check table structure
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'bill_payments'
ORDER BY ordinal_position;

-- Check indexes
SELECT 
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename = 'bill_payments';

-- Check policies
SELECT 
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'bill_payments';

SELECT '✅ Bill payments table created successfully!' as status;
