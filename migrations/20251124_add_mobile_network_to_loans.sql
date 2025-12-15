-- Migration: add mobile_number and network_id to loans
-- Created: 2025-11-24
-- Usage: paste into Supabase SQL editor (or run via psql/service role). Run inside a transaction.

BEGIN;

-- 1) Add columns (nullable by default so migration is non-destructive)
ALTER TABLE IF EXISTS loans
  ADD COLUMN IF NOT EXISTS mobile_number TEXT,
  ADD COLUMN IF NOT EXISTS network_id INT;

-- 2) Backfill mobile_number from profiles.phone_number when available
-- Adjust the 'phone_number' column name if your profiles table uses a different field.
UPDATE loans l
SET mobile_number = p.phone_number
FROM profiles p
WHERE l.user_id = p.id
  AND p.phone_number IS NOT NULL
  AND (l.mobile_number IS NULL OR l.mobile_number = '');

-- 3) Optionally set a sensible default for network_id for existing rows (uncomment if desired)
-- UPDATE loans SET network_id = 1 WHERE network_id IS NULL;

-- 4) Add an index to speed up queries by user and mobile
CREATE INDEX IF NOT EXISTS idx_loans_user_mobile ON loans(user_id, mobile_number);

-- 5) Add column comments
COMMENT ON COLUMN loans.mobile_number IS 'Mobile number to which the loan/data will be issued';
COMMENT ON COLUMN loans.network_id IS 'Network id used for issuance (1 = MTN, 2 = GLO)';

COMMIT;
