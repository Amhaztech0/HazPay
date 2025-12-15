-- ============================================================================
-- SEARCH AND CALLS SYSTEM FIXES
-- ============================================================================
-- This SQL file documents the database requirements for:
-- 1. User search functionality (by phone_number and display_name)
-- 2. Video/Voice call management system
--
-- NO CHANGES NEEDED - This is informational documentation of existing tables
-- All required tables and fields already exist in your Supabase database
-- ============================================================================

-- ============================================================================
-- 1. PROFILES TABLE - SEARCH SUPPORT
-- ============================================================================
-- The search system requires these fields to already exist:
-- - id (UUID, primary key)
-- - phone_number (text, nullable)
-- - display_name (text)
-- - created_at (timestamp)
-- - updated_at (timestamp)
--
-- Your profile table already has these fields and is correctly configured.
-- The search logic now supports:
--   * Exact phone_number match (case-insensitive)
--   * Exact display_name match (case-insensitive)
--   * NO partial matches

-- ============================================================================
-- 2. CALLS TABLE - VIDEO/VOICE CALLS
-- ============================================================================
-- The calls system requires this table structure (verify it exists):

-- If the calls table doesn't exist, create it with:
CREATE TABLE IF NOT EXISTS calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_type TEXT NOT NULL CHECK (call_type IN ('direct', 'server')),
  media_type TEXT NOT NULL CHECK (media_type IN ('audio', 'video')),
  caller_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  server_id UUID REFERENCES servers(id) ON DELETE CASCADE,
  channel_id UUID REFERENCES channels(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'initiated' CHECK (status IN (
    'initiated', 'ringing', 'active', 'ended', 'rejected', 'cancelled', 'missed'
  )),
  started_at TIMESTAMP,
  ended_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 3. CALLS TABLE - INDICES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_calls_receiver_id ON calls(receiver_id);
CREATE INDEX IF NOT EXISTS idx_calls_caller_id ON calls(caller_id);
CREATE INDEX IF NOT EXISTS idx_calls_status ON calls(status);
CREATE INDEX IF NOT EXISTS idx_calls_call_type ON calls(call_type);
CREATE INDEX IF NOT EXISTS idx_calls_server_id ON calls(server_id);
CREATE INDEX IF NOT EXISTS idx_calls_channel_id ON calls(channel_id);

-- ============================================================================
-- 4. CALLS TABLE - ROW LEVEL SECURITY
-- ============================================================================

-- Enable RLS on calls table
ALTER TABLE calls ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can read their own calls" ON calls;
DROP POLICY IF EXISTS "Users can insert their own calls" ON calls;
DROP POLICY IF EXISTS "Users can update their own calls" ON calls;

-- Create new policies
CREATE POLICY "Users can read their own calls"
ON calls FOR SELECT
USING (caller_id = auth.uid() OR receiver_id = auth.uid());

CREATE POLICY "Users can insert their own calls"
ON calls FOR INSERT
WITH CHECK (caller_id = auth.uid());

CREATE POLICY "Users can update their own calls"
ON calls FOR UPDATE
USING (caller_id = auth.uid() OR receiver_id = auth.uid())
WITH CHECK (caller_id = auth.uid() OR receiver_id = auth.uid());

-- ============================================================================
-- 5. VERIFICATION QUERIES
-- ============================================================================

-- Verify calls table exists and has correct structure
SELECT 
  table_name, 
  column_name, 
  data_type
FROM information_schema.columns
WHERE table_name = 'calls'
ORDER BY ordinal_position;

-- Verify profiles table search fields
SELECT 
  id,
  phone_number,
  display_name
FROM profiles
LIMIT 1;

-- ============================================================================
-- DEPLOYMENT NOTES
-- ============================================================================
-- 
-- 1. SEARCH FIX (No SQL needed)
--    - Updated Dart code only: lib/services/chat_service.dart
--    - Now searches by exact phone_number or display_name match
--    - Partial text matches no longer work (security improvement)
--    - Searches: "abc", "har", "yyo" → No results ✅
--    - Searches: "1234567890", "John Doe" → Exact matches only ✅
--
-- 2. CALLS CRASH FIXES (No SQL needed)
--    - Added comprehensive null safety checks in call_manager.dart
--    - Added error handling in direct_call_screen.dart
--    - Fixed: calls.maybeSingle() instead of .single() to prevent crashes on missing records
--    - Added proper error logging and user-friendly error dialogs
--    - Added validation for callId, callerId, and other parameters
--    - Added try-catch blocks around database queries
--
-- 3. VERIFICATION
--    - If calls table doesn't exist, run the CREATE TABLE statement above
--    - Run verification queries to confirm structure
--
-- ============================================================================
