-- Alternative: More Permissive UPDATE Policy
-- Use this if the first policy doesn't work

-- Drop existing UPDATE policy if it exists
DROP POLICY IF EXISTS "Users can update messages sent to them" ON messages;
DROP POLICY IF EXISTS "Users can mark messages as read" ON messages;

-- Simple policy: Users can update any message in their chats
CREATE POLICY "Users can mark messages as read"
ON messages
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM chats
    WHERE chats.id = messages.chat_id
    AND (chats.user1_id = auth.uid() OR chats.user2_id = auth.uid())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM chats
    WHERE chats.id = messages.chat_id
    AND (chats.user1_id = auth.uid() OR chats.user2_id = auth.uid())
  )
);

-- List all policies on messages table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'messages'
ORDER BY policyname;
