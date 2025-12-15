-- ============================================
-- SERVER CHANNELS TABLE
-- ============================================
-- Channels within servers (like Discord channels)

CREATE TABLE IF NOT EXISTS server_channels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    channel_type TEXT DEFAULT 'text' CHECK (channel_type IN ('text', 'voice', 'announcements')),
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    position INTEGER DEFAULT 0, -- For ordering channels
    
    -- Unique constraint: channel name must be unique per server
    UNIQUE(server_id, name)
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_server_channels_server_id ON server_channels(server_id);
CREATE INDEX IF NOT EXISTS idx_server_channels_created_at ON server_channels(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_server_channels_position ON server_channels(server_id, position);

-- ============================================
-- UPDATE SERVER_MESSAGES TABLE
-- ============================================
-- Add channel_id to server_messages to associate messages with channels

ALTER TABLE IF EXISTS server_messages 
ADD COLUMN IF NOT EXISTS channel_id UUID REFERENCES server_channels(id) ON DELETE CASCADE;

-- Create index for faster channel message queries
CREATE INDEX IF NOT EXISTS idx_server_messages_channel_id ON server_messages(channel_id);

-- ============================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================

ALTER TABLE server_channels ENABLE ROW LEVEL SECURITY;

-- ============================================
-- RLS POLICIES FOR SERVER_CHANNELS
-- ============================================

-- Drop existing policies
DROP POLICY IF EXISTS "Server members can view channels" ON server_channels;
DROP POLICY IF EXISTS "Server members can create channels" ON server_channels;
DROP POLICY IF EXISTS "Admins can edit channels" ON server_channels;
DROP POLICY IF EXISTS "Admins can delete channels" ON server_channels;

-- Policy 1: Server members can view all channels in their server
CREATE POLICY "Server members can view channels"
    ON server_channels FOR SELECT
    USING (
        auth.uid() IN (
            SELECT user_id FROM server_members WHERE server_id = server_channels.server_id
        )
    );

-- Policy 2: Server members can create channels (owner/admin can moderate later)
CREATE POLICY "Server members can create channels"
    ON server_channels FOR INSERT
    WITH CHECK (
        auth.uid() IN (
            SELECT user_id FROM server_members 
            WHERE server_id = server_channels.server_id
        )
        AND auth.uid() = created_by
    );

-- Policy 3: Admins/owners can edit channels
CREATE POLICY "Admins can edit channels"
    ON server_channels FOR UPDATE
    USING (
        auth.uid() IN (
            SELECT user_id FROM server_members 
            WHERE server_id = server_channels.server_id 
            AND role IN ('admin', 'owner')
        )
    );

-- Policy 4: Admins/owners can delete channels
CREATE POLICY "Admins can delete channels"
    ON server_channels FOR DELETE
    USING (
        auth.uid() IN (
            SELECT user_id FROM server_members 
            WHERE server_id = server_channels.server_id 
            AND role IN ('admin', 'owner')
        )
    );

-- ============================================
-- UPDATE SERVER_MESSAGES RLS
-- ============================================

-- Drop and recreate server_messages policies to include channel access

DROP POLICY IF EXISTS "Server members can view messages" ON server_messages;
DROP POLICY IF EXISTS "Server members can send messages" ON server_messages;

CREATE POLICY "Server members can view messages"
    ON server_messages FOR SELECT
    USING (
        auth.uid() IN (
            SELECT user_id FROM server_members WHERE server_id = server_messages.server_id
        )
    );

CREATE POLICY "Server members can send messages"
    ON server_messages FOR INSERT
    WITH CHECK (
        auth.uid() = user_id AND
        auth.uid() IN (
            SELECT user_id FROM server_members WHERE server_id = server_messages.server_id
        )
    );

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

GRANT SELECT, INSERT, UPDATE, DELETE ON server_channels TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON server_messages TO authenticated;

-- ============================================
-- SAMPLE DATA (optional - for testing)
-- ============================================
/*
-- Create default channels for a server
INSERT INTO server_channels (server_id, name, description, channel_type, created_by, position)
SELECT 
    id,
    'general',
    'General discussion',
    'text',
    owner_id,
    0
FROM servers
WHERE name = 'My Server'
LIMIT 1;

INSERT INTO server_channels (server_id, name, description, channel_type, created_by, position)
SELECT 
    id,
    'random',
    'Random topics',
    'text',
    owner_id,
    1
FROM servers
WHERE name = 'My Server'
LIMIT 1;

INSERT INTO server_channels (server_id, name, description, channel_type, created_by, position)
SELECT 
    id,
    'announcements',
    'Important updates',
    'announcements',
    owner_id,
    2
FROM servers
WHERE name = 'My Server'
LIMIT 1;
*/
