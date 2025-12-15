-- Privacy Controls and Blocking System
-- Run this in your Supabase SQL Editor

-- ============================================
-- 1. Add privacy settings to profiles table
-- ============================================

-- Add messaging privacy column to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS messaging_privacy TEXT DEFAULT 'everyone' CHECK (messaging_privacy IN ('everyone', 'approved_only'));

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_messaging_privacy ON profiles(messaging_privacy);

-- ============================================
-- 2. Create blocked_users table
-- ============================================

CREATE TABLE IF NOT EXISTS blocked_users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  blocker_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(blocker_id, blocked_id),
  -- Prevent blocking yourself
  CONSTRAINT no_self_block CHECK (blocker_id != blocked_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker ON blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked ON blocked_users(blocked_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_created_at ON blocked_users(created_at DESC);

-- Enable RLS
ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can insert blocks (block someone)
CREATE POLICY "Users can block others"
ON blocked_users
FOR INSERT
WITH CHECK (auth.uid() = blocker_id);

-- Policy 2: Users can view blocks where they are the blocker
CREATE POLICY "Users can view their blocks"
ON blocked_users
FOR SELECT
USING (auth.uid() = blocker_id);

-- Policy 3: Users can delete their own blocks (unblock)
CREATE POLICY "Users can unblock"
ON blocked_users
FOR DELETE
USING (auth.uid() = blocker_id);

-- ============================================
-- 3. Create message_requests table
-- ============================================

CREATE TABLE IF NOT EXISTS message_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  first_message_id UUID REFERENCES messages(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(sender_id, receiver_id),
  -- Prevent requesting yourself
  CONSTRAINT no_self_request CHECK (sender_id != receiver_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_message_requests_sender ON message_requests(sender_id);
CREATE INDEX IF NOT EXISTS idx_message_requests_receiver ON message_requests(receiver_id);
CREATE INDEX IF NOT EXISTS idx_message_requests_status ON message_requests(status);
CREATE INDEX IF NOT EXISTS idx_message_requests_created_at ON message_requests(created_at DESC);

-- Enable RLS
ALTER TABLE message_requests ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can insert message requests when sending first message
CREATE POLICY "Users can create message requests"
ON message_requests
FOR INSERT
WITH CHECK (auth.uid() = sender_id);

-- Policy 2: Users can view requests where they are sender or receiver
CREATE POLICY "Users can view their requests"
ON message_requests
FOR SELECT
USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Policy 3: Receivers can update request status
CREATE POLICY "Receivers can update request status"
ON message_requests
FOR UPDATE
USING (auth.uid() = receiver_id)
WITH CHECK (auth.uid() = receiver_id);

-- Policy 4: Users can delete their own sent requests
CREATE POLICY "Senders can delete their requests"
ON message_requests
FOR DELETE
USING (auth.uid() = sender_id);

-- ============================================
-- 4. Helper Functions
-- ============================================

-- Function to check if user A has blocked user B
CREATE OR REPLACE FUNCTION is_user_blocked(blocker_user_id UUID, blocked_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM blocked_users
    WHERE blocker_id = blocker_user_id
    AND blocked_id = blocked_user_id
  );
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to check if users can message each other
CREATE OR REPLACE FUNCTION can_message_user(sender_id UUID, receiver_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  receiver_privacy TEXT;
  has_accepted_request BOOLEAN;
  is_blocked BOOLEAN;
  is_blocker BOOLEAN;
BEGIN
  -- Check if either user has blocked the other
  SELECT 
    is_user_blocked(receiver_id, sender_id) INTO is_blocked;
  SELECT 
    is_user_blocked(sender_id, receiver_id) INTO is_blocker;
    
  IF is_blocked OR is_blocker THEN
    RETURN FALSE;
  END IF;

  -- Get receiver's privacy setting
  SELECT messaging_privacy INTO receiver_privacy
  FROM profiles
  WHERE id = receiver_id;

  -- If receiver allows everyone, return true
  IF receiver_privacy = 'everyone' THEN
    RETURN TRUE;
  END IF;

  -- If receiver allows only approved, check for accepted request
  SELECT EXISTS (
    SELECT 1 FROM message_requests
    WHERE message_requests.sender_id = sender_id
    AND message_requests.receiver_id = receiver_id
    AND status = 'accepted'
  ) INTO has_accepted_request;

  RETURN has_accepted_request;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get pending message requests count
CREATE OR REPLACE FUNCTION get_pending_requests_count(user_id UUID)
RETURNS INTEGER AS $$
  SELECT COUNT(*)::INTEGER
  FROM message_requests
  WHERE receiver_id = user_id
  AND status = 'pending';
$$ LANGUAGE SQL STABLE;

-- ============================================
-- 5. Update Messages RLS Policies
-- ============================================

-- Drop existing message policies (we'll recreate them with blocking checks)
DROP POLICY IF EXISTS "Users can view messages in their chats" ON messages;
DROP POLICY IF EXISTS "Users can send messages" ON messages;
DROP POLICY IF EXISTS "Users can update own messages" ON messages;
DROP POLICY IF EXISTS "Users can delete own messages" ON messages;

-- Policy 1: Users can view messages in their chats (if not blocked)
CREATE POLICY "Users can view messages in their chats"
ON messages
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM chats
    WHERE chats.id = messages.chat_id
    AND (chats.user1_id = auth.uid() OR chats.user2_id = auth.uid())
    -- Check not blocked
    AND NOT is_user_blocked(
      CASE WHEN chats.user1_id = auth.uid() THEN chats.user2_id ELSE chats.user1_id END,
      auth.uid()
    )
  )
);

-- Policy 2: Users can send messages (if not blocked and have permission)
CREATE POLICY "Users can send messages"
ON messages
FOR INSERT
WITH CHECK (
  auth.uid() = sender_id
  AND EXISTS (
    SELECT 1 FROM chats
    WHERE chats.id = messages.chat_id
    AND (chats.user1_id = auth.uid() OR chats.user2_id = auth.uid())
  )
  -- Check if user can message the other person
  AND can_message_user(
    auth.uid(),
    (SELECT CASE WHEN chats.user1_id = auth.uid() THEN chats.user2_id ELSE chats.user1_id END
     FROM chats WHERE chats.id = messages.chat_id)
  )
);

-- Policy 3: Users can update their own messages
CREATE POLICY "Users can update own messages"
ON messages
FOR UPDATE
USING (sender_id = auth.uid())
WITH CHECK (sender_id = auth.uid());

-- Policy 4: Users can delete their own messages
CREATE POLICY "Users can delete own messages"
ON messages
FOR DELETE
USING (sender_id = auth.uid());

-- ============================================
-- 6. Grant Permissions
-- ============================================

GRANT SELECT, INSERT, DELETE ON blocked_users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON message_requests TO authenticated;
GRANT EXECUTE ON FUNCTION is_user_blocked TO authenticated;
GRANT EXECUTE ON FUNCTION can_message_user TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_requests_count TO authenticated;

-- ============================================
-- 7. Verify Setup
-- ============================================

-- Check blocked_users policies
SELECT 
  tablename, 
  policyname, 
  permissive, 
  cmd 
FROM pg_policies 
WHERE tablename = 'blocked_users'
ORDER BY policyname;

-- Check message_requests policies
SELECT 
  tablename, 
  policyname, 
  permissive, 
  cmd 
FROM pg_policies 
WHERE tablename = 'message_requests'
ORDER BY policyname;

-- Check messages policies
SELECT 
  tablename, 
  policyname, 
  permissive, 
  cmd 
FROM pg_policies 
WHERE tablename = 'messages'
ORDER BY policyname;

-- Test queries (optional)
-- SELECT * FROM blocked_users WHERE blocker_id = auth.uid();
-- SELECT * FROM message_requests WHERE receiver_id = auth.uid() AND status = 'pending';
-- SELECT messaging_privacy FROM profiles WHERE id = auth.uid();
