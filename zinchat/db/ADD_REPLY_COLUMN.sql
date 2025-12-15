-- Add reply_to_message_id column to server_messages table
-- This allows messages to be replies to other messages

-- Check if column exists before adding
ALTER TABLE IF EXISTS server_messages 
ADD COLUMN IF NOT EXISTS reply_to_message_id UUID REFERENCES server_messages(id) ON DELETE SET NULL;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_server_messages_reply_to_message_id ON server_messages(reply_to_message_id);

-- Optional: Update RLS policies if needed
-- Note: The existing RLS policies should already allow SELECT on server_messages
-- since users can see all messages in their servers

-- Grant access
GRANT SELECT, INSERT, UPDATE ON server_messages TO authenticated;
