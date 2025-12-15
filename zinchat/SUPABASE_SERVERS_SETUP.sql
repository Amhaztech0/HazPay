-- Server Features Database Schema
-- Run this in your Supabase SQL Editor

-- ============================================
-- SERVERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS servers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    icon_url TEXT,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_public BOOLEAN DEFAULT false,
    member_count INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- SERVER MEMBERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS server_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(server_id, user_id)
);

-- ============================================
-- SERVER MESSAGES TABLE (for server-wide chat)
-- ============================================
CREATE TABLE IF NOT EXISTS server_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'video', 'audio', 'file')),
    media_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- SERVER INVITES TABLE (for private server invitations)
-- ============================================
CREATE TABLE IF NOT EXISTS server_invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    invite_code TEXT UNIQUE NOT NULL,
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    expires_at TIMESTAMP WITH TIME ZONE,
    max_uses INTEGER DEFAULT NULL, -- NULL means unlimited
    current_uses INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_servers_owner ON servers(owner_id);
CREATE INDEX IF NOT EXISTS idx_servers_public ON servers(is_public) WHERE is_public = true;
CREATE INDEX IF NOT EXISTS idx_server_members_server ON server_members(server_id);
CREATE INDEX IF NOT EXISTS idx_server_members_user ON server_members(user_id);
CREATE INDEX IF NOT EXISTS idx_server_messages_server ON server_messages(server_id);
CREATE INDEX IF NOT EXISTS idx_server_messages_created ON server_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_server_invites_code ON server_invites(invite_code) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_server_invites_server ON server_invites(server_id);

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS
ALTER TABLE servers ENABLE ROW LEVEL SECURITY;
ALTER TABLE server_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE server_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE server_invites ENABLE ROW LEVEL SECURITY;

-- Servers policies
-- Drop existing policies if present so the script can be re-run safely
DROP POLICY IF EXISTS "Public servers are viewable by everyone" ON servers;
DROP POLICY IF EXISTS "Server owners can view their servers" ON servers;
DROP POLICY IF EXISTS "Users can view servers they are members of" ON servers;
DROP POLICY IF EXISTS "Users can create servers" ON servers;
DROP POLICY IF EXISTS "Server owners can update their servers" ON servers;
DROP POLICY IF EXISTS "Server owners can delete their servers" ON servers;

CREATE POLICY "Public servers are viewable by everyone"
    ON servers FOR SELECT
    USING (is_public = true);

CREATE POLICY "Server owners can view their servers"
    ON servers FOR SELECT
    USING (auth.uid() = owner_id);

CREATE POLICY "Users can view servers they are members of"
    ON servers FOR SELECT
    USING (
        auth.uid() IN (
            SELECT user_id FROM server_members WHERE server_id = servers.id
        )
    );

CREATE POLICY "Users can create servers"
    ON servers FOR INSERT
    WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Server owners can update their servers"
    ON servers FOR UPDATE
    USING (auth.uid() = owner_id);

CREATE POLICY "Server owners can delete their servers"
    ON servers FOR DELETE
    USING (auth.uid() = owner_id);

-- Server members policies
-- Drop existing policies on server_members so script is idempotent
DROP POLICY IF EXISTS "Users can view server members if they are members" ON server_members;
DROP POLICY IF EXISTS "Anyone can view server members" ON server_members;
DROP POLICY IF EXISTS "Users can join servers" ON server_members;
DROP POLICY IF EXISTS "Users can leave servers" ON server_members;
DROP POLICY IF EXISTS "Admins and owners can remove members" ON server_members;

-- Simplified: Allow anyone to view members (needed for join checks, no recursion)
CREATE POLICY "Anyone can view server members"
    ON server_members FOR SELECT
    USING (true);

CREATE POLICY "Users can join servers"
    ON server_members FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave servers"
    ON server_members FOR DELETE
    USING (auth.uid() = user_id);

-- Note: Removed admin removal policy to avoid recursion - can add via function later

-- Function to check if a user is admin/owner of a server
CREATE OR REPLACE FUNCTION is_server_admin(p_server_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_role TEXT;
BEGIN
    SELECT role INTO v_role
    FROM server_members
    WHERE server_id = p_server_id AND user_id = p_user_id
    LIMIT 1;

    IF v_role IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN v_role IN ('owner','admin');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin removal policy (uses SECURITY DEFINER function to avoid recursion)
CREATE POLICY "Admins and owners can remove members"
    ON server_members FOR DELETE
    USING (
        auth.uid() = user_id OR is_server_admin(server_id, auth.uid())
    );


-- Server messages policies
-- Drop existing policies on server_messages so script is idempotent
DROP POLICY IF EXISTS "Server members can view messages" ON server_messages;
DROP POLICY IF EXISTS "Server members can send messages" ON server_messages;
DROP POLICY IF EXISTS "Users can delete their own messages" ON server_messages;

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

CREATE POLICY "Users can delete their own messages"
    ON server_messages FOR DELETE
    USING (auth.uid() = user_id);

-- Allow admins and owners to delete any message in their server
DROP POLICY IF EXISTS "Admins can delete messages" ON server_messages;
CREATE POLICY "Admins can delete messages"
    ON server_messages FOR DELETE
    USING (
        auth.uid() = user_id OR is_server_admin(server_id, auth.uid())
    );

-- Server invites policies
-- Drop existing policies on server_invites so script is idempotent
DROP POLICY IF EXISTS "Server members can view invites" ON server_invites;
DROP POLICY IF EXISTS "Server owners and admins can create invites" ON server_invites;
DROP POLICY IF EXISTS "Server owners and admins can delete invites" ON server_invites;

CREATE POLICY "Server members can view invites"
    ON server_invites FOR SELECT
    USING (
        auth.uid() IN (
            SELECT user_id FROM server_members WHERE server_id = server_invites.server_id
        )
    );

CREATE POLICY "Server owners and admins can create invites"
    ON server_invites FOR INSERT
    WITH CHECK (
        auth.uid() IN (
            SELECT user_id FROM server_members 
            WHERE server_id = server_invites.server_id 
            AND role IN ('owner', 'admin')
        )
    );

CREATE POLICY "Server owners and admins can delete invites"
    ON server_invites FOR DELETE
    USING (
        auth.uid() IN (
            SELECT user_id FROM server_members 
            WHERE server_id = server_invites.server_id 
            AND role IN ('owner', 'admin')
        )
    );

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Function to increment server member count
CREATE OR REPLACE FUNCTION increment_server_members(server_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE servers
    SET member_count = member_count + 1,
        updated_at = NOW()
    WHERE id = server_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to decrement server member count
CREATE OR REPLACE FUNCTION decrement_server_members(server_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE servers
    SET member_count = GREATEST(member_count - 1, 0),
        updated_at = NOW()
    WHERE id = server_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- TRIGGERS
-- ============================================

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists so recreate won't fail
DROP TRIGGER IF EXISTS update_servers_updated_at ON servers;

CREATE TRIGGER update_servers_updated_at
    BEFORE UPDATE ON servers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to generate invite code
CREATE OR REPLACE FUNCTION generate_invite_code()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    result TEXT := '';
    i INTEGER;
BEGIN
    FOR i IN 1..8 LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to join server via invite code
CREATE OR REPLACE FUNCTION join_server_with_invite(p_invite_code TEXT, p_user_id UUID)
RETURNS JSON AS $$
DECLARE
    v_invite RECORD;
    v_server_id UUID;
    v_already_member BOOLEAN;
BEGIN
    -- Get invite details
    SELECT * INTO v_invite
    FROM server_invites
    WHERE invite_code = p_invite_code
      AND is_active = true
      AND (expires_at IS NULL OR expires_at > NOW())
      AND (max_uses IS NULL OR current_uses < max_uses);
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'Invalid or expired invite code');
    END IF;
    
    v_server_id := v_invite.server_id;
    
    -- Check if already a member
    SELECT EXISTS(
        SELECT 1 FROM server_members 
        WHERE server_id = v_server_id AND user_id = p_user_id
    ) INTO v_already_member;
    
    IF v_already_member THEN
        RETURN json_build_object('success', false, 'error', 'Already a member of this server');
    END IF;
    
    -- Add as member
    INSERT INTO server_members (server_id, user_id, role)
    VALUES (v_server_id, p_user_id, 'member');
    
    -- Increment invite usage
    UPDATE server_invites
    SET current_uses = current_uses + 1
    WHERE id = v_invite.id;
    
    -- Increment server member count
    UPDATE servers
    SET member_count = member_count + 1,
        updated_at = NOW()
    WHERE id = v_server_id;
    
    RETURN json_build_object('success', true, 'server_id', v_server_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- SAMPLE DATA (optional - for testing)
-- ============================================
/*
-- Create a test server
INSERT INTO servers (name, description, owner_id, is_public, member_count)
VALUES (
    'Flutter Developers',
    'A community for Flutter enthusiasts',
    (SELECT id FROM auth.users LIMIT 1),
    true,
    1
);
*/
