-- Create user_tokens table to store FCM tokens
CREATE TABLE IF NOT EXISTS user_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL, -- 'android' or 'ios'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Ensure one token per device
  UNIQUE(user_id, fcm_token)
);

-- Create index for faster token lookups
CREATE INDEX IF NOT EXISTS idx_user_tokens_user_id ON user_tokens(user_id);

-- Enable RLS
ALTER TABLE user_tokens ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only see their own tokens
CREATE POLICY "Users can view their own tokens" ON user_tokens
  FOR SELECT USING (auth.uid() = user_id);

-- RLS Policy: Users can insert their own tokens
CREATE POLICY "Users can insert their own tokens" ON user_tokens
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can update their own tokens
CREATE POLICY "Users can update their own tokens" ON user_tokens
  FOR UPDATE USING (auth.uid() = user_id);

-- RLS Policy: Users can delete their own tokens
CREATE POLICY "Users can delete their own tokens" ON user_tokens
  FOR DELETE USING (auth.uid() = user_id);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON user_tokens TO authenticated;

-- Add notification_sent column to messages (optional, for tracking)
ALTER TABLE server_messages ADD COLUMN IF NOT EXISTS notification_sent BOOLEAN DEFAULT FALSE;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS notification_sent BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_server_messages_notification_sent ON server_messages(notification_sent);
CREATE INDEX IF NOT EXISTS idx_messages_notification_sent ON messages(notification_sent);
