-- ============================================================================
-- ADD EMAIL TO PROFILES TABLE FOR SEARCH
-- ============================================================================
-- This SQL migration adds email column to profiles for user search functionality
-- Email is cached from auth.users for easier searching and indexing

-- ============================================================================
-- STEP 1: Add email column to profiles table if it doesn't exist
-- ============================================================================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email TEXT;

-- ============================================================================
-- STEP 2: Populate email from auth.users for existing profiles
-- ============================================================================
-- This one-time migration populates email from Supabase auth.users table
UPDATE profiles p
SET email = au.email
FROM auth.users au
WHERE p.id = au.id AND p.email IS NULL;

-- ============================================================================
-- STEP 3: Create indices for efficient searching
-- ============================================================================
-- Unique index on email for fast exact matches
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email) WHERE email IS NOT NULL;

-- Index on display_name for display_name searches
CREATE INDEX IF NOT EXISTS idx_profiles_display_name ON profiles(display_name);

-- ============================================================================
-- VERIFICATION QUERIES (Run these to confirm successful migration)
-- ============================================================================
-- Check that emails were populated:
SELECT COUNT(*) as total_profiles, 
       COUNT(email) as profiles_with_email,
       COUNT(*) - COUNT(email) as profiles_without_email
FROM profiles;

-- Sample query to verify data:
SELECT id, email, display_name FROM profiles LIMIT 5;

-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS
-- ============================================================================
-- 1. Copy ALL SQL above (lines 7-23) - that's the migration
-- 2. Go to: Supabase Dashboard → SQL Editor
-- 3. Click "New query"
-- 4. Paste the SQL
-- 5. Click "RUN" button
-- 6. Wait for success (usually 1-5 seconds)
-- 7. Run verification queries to confirm
-- 8. Return to Flutter and hot reload (`r`)
-- 9. Test search now!
--
-- ============================================================================
-- AFTER MIGRATION - SEARCH BEHAVIOR
-- ============================================================================
-- ✅ Exact email match: "hamzaabdulhakim3@gmail.com" → Shows user
-- ✅ Exact display_name match: "John Doe" → Shows user  
-- ✅ Partial text: "abc", "ham", "jo" → No results (security feature)
-- ✅ Empty search: "" → No results
--
-- The search logic in Dart will:
--   1. Try email match first (if email column exists)
--   2. Fall back to display_name match if no email found
--   3. Return empty list if neither matches
--
-- ============================================================================
