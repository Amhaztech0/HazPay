-- Create message_reactions table for emoji reactions on messages
CREATE TABLE IF NOT EXISTS message_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES server_messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL, -- Store emoji as text (e.g., "👍", "❤️", "😂")
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Ensure one reaction per user per message per emoji (unique constraint)
  UNIQUE(message_id, user_id, emoji)
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_message_reactions_message_id ON message_reactions(message_id);
CREATE INDEX IF NOT EXISTS idx_message_reactions_user_id ON message_reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_message_reactions_emoji ON message_reactions(emoji);

-- Enable RLS
ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view all reactions on messages in their servers
CREATE POLICY "Users can view reactions on messages in their servers" ON message_reactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM server_messages sm
      INNER JOIN servers s ON sm.server_id = s.id
      INNER JOIN server_members sm2 ON s.id = sm2.server_id
      WHERE sm.id = message_reactions.message_id
      AND sm2.user_id = auth.uid()
    )
  );

-- RLS Policy: Users can add reactions to messages in their servers
CREATE POLICY "Users can add reactions to messages in their servers" ON message_reactions
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM server_messages sm
      INNER JOIN servers s ON sm.server_id = s.id
      INNER JOIN server_members sm2 ON s.id = sm2.server_id
      WHERE sm.id = message_id
      AND sm2.user_id = auth.uid()
    )
  );

-- RLS Policy: Users can only remove their own reactions
CREATE POLICY "Users can remove their own reactions" ON message_reactions
  FOR DELETE USING (auth.uid() = user_id);

-- Grant permissions
GRANT SELECT, INSERT, DELETE ON message_reactions TO authenticated;
