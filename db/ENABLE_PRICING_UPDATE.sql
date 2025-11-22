-- Enable UPDATE on pricing table for authenticated admin users
-- This allows admins to change data plan prices

-- First, ensure RLS is enabled on pricing table
ALTER TABLE IF EXISTS public.pricing ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "pricing_select_for_all" ON public.pricing;
DROP POLICY IF EXISTS "pricing_update_for_admin" ON public.pricing;
DROP POLICY IF EXISTS "pricing_insert_for_admin" ON public.pricing;
DROP POLICY IF EXISTS "pricing_delete_for_admin" ON public.pricing;

-- Policy 1: Allow SELECT for all (anyone can see pricing)
CREATE POLICY "pricing_select_for_all"
  ON public.pricing
  FOR SELECT
  USING (true);

-- Policy 2: Allow UPDATE for authenticated users (admins)
CREATE POLICY "pricing_update_for_admin"
  ON public.pricing
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Policy 3: Allow INSERT for authenticated users (admins)
CREATE POLICY "pricing_insert_for_admin"
  ON public.pricing
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Policy 4: Allow DELETE for authenticated users (admins)
CREATE POLICY "pricing_delete_for_admin"
  ON public.pricing
  FOR DELETE
  TO authenticated
  USING (true);

-- Grant necessary permissions to authenticated role
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pricing TO authenticated;
