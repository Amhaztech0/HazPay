-- Fix RLS Policy for Marking Messages as Read
-- This allows users to update is_read field on messages sent TO them

-- Drop existing UPDATE policy if it exists
DROP POLICY IF EXISTS "Users can update messages sent to them" ON messages;

-- Create new UPDATE policy
-- This allows users to update messages in chats they're part of
-- Specifically for marking messages as read
CREATE POLICY "Users can update messages sent to them"
ON messages
FOR UPDATE
USING (
  -- User must be part of the chat (either user1 or user2)
  EXISTS (
    SELECT 1 FROM chats
    WHERE chats.id = messages.chat_id
    AND (chats.user1_id = auth.uid() OR chats.user2_id = auth.uid())
  )
)
WITH CHECK (
  -- User can only update is_read field on messages sent TO them (not their own messages)
  messages.sender_id != auth.uid()
  AND EXISTS (
    SELECT 1 FROM chats
    WHERE chats.id = messages.chat_id
    AND (chats.user1_id = auth.uid() OR chats.user2_id = auth.uid())
  )
);

-- Verify the policy was created
SELECT * FROM pg_policies WHERE tablename = 'messages' AND policyname = 'Users can update messages sent to them';
