-- Create loans table for HazPay admin dashboard
-- Run this SQL in your Supabase console to enable the loans feature

-- Create loans table
CREATE TABLE IF NOT EXISTS public.loans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount numeric NOT NULL DEFAULT 0 CHECK (amount >= 0),
  status varchar(50) NOT NULL DEFAULT 'pending'::varchar(50) CHECK (status IN ('pending', 'approved', 'active', 'repaid', 'defaulted')),
  issued_date timestamp with time zone NOT NULL DEFAULT now(),
  repaid_date timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Create index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_loans_user_id ON public.loans(user_id);

-- Create index on status for filtering
CREATE INDEX IF NOT EXISTS idx_loans_status ON public.loans(status);

-- Create index on created_at for sorting
CREATE INDEX IF NOT EXISTS idx_loans_created_at ON public.loans(created_at DESC);

-- Enable RLS on loans table
ALTER TABLE public.loans ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "loans_select_for_authenticated" ON public.loans;
DROP POLICY IF EXISTS "loans_insert_for_authenticated" ON public.loans;
DROP POLICY IF EXISTS "loans_update_for_authenticated" ON public.loans;
DROP POLICY IF EXISTS "loans_delete_for_authenticated" ON public.loans;

-- Policy 1: Allow SELECT for authenticated users to view loans
CREATE POLICY "loans_select_for_authenticated"
  ON public.loans
  FOR SELECT
  TO authenticated
  USING (true);

-- Policy 2: Allow INSERT for authenticated users (admins)
CREATE POLICY "loans_insert_for_authenticated"
  ON public.loans
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Policy 3: Allow UPDATE for authenticated users (admins)
CREATE POLICY "loans_update_for_authenticated"
  ON public.loans
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Policy 4: Allow DELETE for authenticated users (admins)
CREATE POLICY "loans_delete_for_authenticated"
  ON public.loans
  FOR DELETE
  TO authenticated
  USING (true);

-- Grant permissions to authenticated role
GRANT SELECT, INSERT, UPDATE, DELETE ON public.loans TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
