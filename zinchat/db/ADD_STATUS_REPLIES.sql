-- Status Replies Feature
-- Allows users to reply to statuses (like WhatsApp/Instagram stories)

-- Create status_replies table
CREATE TABLE IF NOT EXISTS status_replies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  status_id UUID NOT NULL REFERENCES status_updates(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  reply_type TEXT NOT NULL DEFAULT 'text', -- 'text' or 'emoji'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_status_replies_status_id ON status_replies(status_id);
CREATE INDEX IF NOT EXISTS idx_status_replies_user_id ON status_replies(user_id);
CREATE INDEX IF NOT EXISTS idx_status_replies_created_at ON status_replies(created_at DESC);

-- RLS Policies for status_replies

-- Enable RLS
ALTER TABLE status_replies ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can insert replies to any active status
CREATE POLICY "Users can reply to statuses"
ON status_replies
FOR INSERT
WITH CHECK (
  auth.uid() = user_id
  AND EXISTS (
    SELECT 1 FROM status_updates
    WHERE status_updates.id = status_id
    AND status_updates.expires_at > NOW()
  )
);

-- Policy 2: Users can view replies to their own statuses
CREATE POLICY "Users can view replies to their statuses"
ON status_replies
FOR SELECT
USING (
  -- User is the status owner
  EXISTS (
    SELECT 1 FROM status_updates
    WHERE status_updates.id = status_replies.status_id
    AND status_updates.user_id = auth.uid()
  )
  OR
  -- User is the reply author
  user_id = auth.uid()
);

-- Policy 3: Users can delete their own replies
CREATE POLICY "Users can delete their own replies"
ON status_replies
FOR DELETE
USING (user_id = auth.uid());

-- Add reply count function for efficient counting
CREATE OR REPLACE FUNCTION get_status_reply_count(status_uuid UUID)
RETURNS INTEGER AS $$
  SELECT COUNT(*)::INTEGER
  FROM status_replies
  WHERE status_id = status_uuid;
$$ LANGUAGE SQL STABLE;

-- Grant permissions
GRANT SELECT, INSERT, DELETE ON status_replies TO authenticated;
GRANT EXECUTE ON FUNCTION get_status_reply_count TO authenticated;

-- Verify setup
SELECT 
  tablename, 
  policyname, 
  permissive, 
  cmd 
FROM pg_policies 
WHERE tablename = 'status_replies'
ORDER BY policyname;
