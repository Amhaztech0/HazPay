-- HazPay Fintech System Database Setup
-- This script creates all necessary tables and functions for the HazPay system

-- 1. Create hazpay_wallets table
CREATE TABLE IF NOT EXISTS public.hazpay_wallets (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
  total_transactions INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Create hazpay_transactions table
CREATE TABLE IF NOT EXISTS public.hazpay_transactions (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('purchase', 'deposit', 'withdrawal')),
  amount DECIMAL(15, 2) NOT NULL,
  network_name TEXT,
  data_capacity TEXT,
  mobile_number TEXT,
  reference TEXT UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed')),
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT positive_amount CHECK (amount > 0)
);

-- 3. Create hazpay_deposits table
CREATE TABLE IF NOT EXISTS public.hazpay_deposits (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount DECIMAL(15, 2) NOT NULL,
  payment_method TEXT DEFAULT 'card',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
  reference TEXT UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT positive_deposit_amount CHECK (amount > 0)
);

-- 4. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_hazpay_wallets_user_id ON public.hazpay_wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_hazpay_transactions_user_id ON public.hazpay_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_hazpay_transactions_created_at ON public.hazpay_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_hazpay_deposits_user_id ON public.hazpay_deposits(user_id);
CREATE INDEX IF NOT EXISTS idx_hazpay_deposits_created_at ON public.hazpay_deposits(created_at DESC);

-- 5. Enable Row Level Security
ALTER TABLE public.hazpay_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hazpay_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hazpay_deposits ENABLE ROW LEVEL SECURITY;

-- 6. Create RLS policies for hazpay_wallets
CREATE POLICY "Users can view own wallet"
  ON public.hazpay_wallets FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own wallet"
  ON public.hazpay_wallets FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Authenticated users can insert wallets"
  ON public.hazpay_wallets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 7. Create RLS policies for hazpay_transactions
CREATE POLICY "Users can view own transactions"
  ON public.hazpay_transactions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Authenticated users can insert transactions"
  ON public.hazpay_transactions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own transactions"
  ON public.hazpay_transactions FOR UPDATE
  USING (auth.uid() = user_id);

-- 8. Create RLS policies for hazpay_deposits
CREATE POLICY "Users can view own deposits"
  ON public.hazpay_deposits FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Authenticated users can insert deposits"
  ON public.hazpay_deposits FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own deposits"
  ON public.hazpay_deposits FOR UPDATE
  USING (auth.uid() = user_id);

-- 9. Create functions for wallet operations (atomic)
CREATE OR REPLACE FUNCTION add_to_hazpay_wallet(user_id_param UUID, amount_param DECIMAL)
RETURNS VOID AS $$
BEGIN
  UPDATE public.hazpay_wallets
  SET 
    balance = balance + amount_param,
    total_transactions = total_transactions + 1,
    updated_at = CURRENT_TIMESTAMP
  WHERE user_id = user_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION deduct_from_hazpay_wallet(user_id_param UUID, amount_param DECIMAL)
RETURNS VOID AS $$
BEGIN
  UPDATE public.hazpay_wallets
  SET 
    balance = balance - amount_param,
    total_transactions = total_transactions + 1,
    updated_at = CURRENT_TIMESTAMP
  WHERE user_id = user_id_param AND balance >= amount_param;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insufficient balance or wallet not found';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Create trigger to auto-create wallet on user signup
CREATE OR REPLACE FUNCTION create_hazpay_wallet_on_signup()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.hazpay_wallets (user_id, balance, total_transactions)
  VALUES (NEW.id, 0.00, 0);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created_hazpay ON auth.users;
CREATE TRIGGER on_auth_user_created_hazpay
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_hazpay_wallet_on_signup();

-- 11. Create view for user transaction summary
CREATE OR REPLACE VIEW hazpay_user_summary AS
SELECT 
  w.user_id,
  w.balance,
  w.total_transactions,
  COUNT(t.id) FILTER (WHERE t.type = 'purchase' AND t.status = 'success') as successful_purchases,
  COUNT(t.id) FILTER (WHERE t.type = 'deposit' AND t.status = 'success') as successful_deposits,
  SUM(t.amount) FILTER (WHERE t.type = 'purchase' AND t.status = 'success') as total_spent_on_data,
  SUM(t.amount) FILTER (WHERE t.type = 'deposit' AND t.status = 'success') as total_deposited
FROM public.hazpay_wallets w
LEFT JOIN public.hazpay_transactions t ON w.user_id = t.user_id
GROUP BY w.user_id, w.balance, w.total_transactions;

-- Grant permissions for RLS functions
GRANT EXECUTE ON FUNCTION add_to_hazpay_wallet(UUID, DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION deduct_from_hazpay_wallet(UUID, DECIMAL) TO authenticated;

GRANT SELECT ON hazpay_user_summary TO authenticated;

-- Notes:
-- 1. RLS policies ensure users can only access their own data
-- 2. Wallet functions are SECURITY DEFINER so they can execute with elevated privileges
-- 3. Automatic wallet creation happens on user signup via trigger
-- 4. All amounts are stored as DECIMAL for financial precision
-- 5. Transactions are immutable once created (no DELETE policy)
-- 6. Test with Supabase SQL Editor before applying to production
