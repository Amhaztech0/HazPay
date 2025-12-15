-- ============================================
-- SERVER MANAGEMENT ENHANCEMENTS
-- ============================================
--
-- ⚠️ IMPORTANT: Run SUPABASE_SERVERS_SETUP.sql FIRST!
-- 
-- This file adds server management features:
-- - 2-server creation limit per user
-- - Ban/Mute/Timeout member moderation
-- - Server editing (name, description, icon)
--
-- Prerequisites:
-- 1. SUPABASE_SERVERS_SETUP.sql must be executed first
-- 2. Tables required: servers, server_members, server_messages
-- 3. Function required: is_server_admin()
--
-- To run:
-- 1. Open Supabase SQL Editor
-- 2. Copy and paste this entire file
-- 3. Click "Run"
-- ============================================

-- ============================================
-- MEMBER MODERATION TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS server_member_moderation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    moderation_type TEXT NOT NULL CHECK (moderation_type IN ('ban', 'mute', 'timeout')),
    reason TEXT,
    moderator_id UUID NOT NULL REFERENCES auth.users(id),
    expires_at TIMESTAMP WITH TIME ZONE, -- NULL for permanent ban, or specific time for timeout/temp mute
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(server_id, user_id, moderation_type)
);

CREATE INDEX IF NOT EXISTS idx_server_moderation_server_user ON server_member_moderation(server_id, user_id);
CREATE INDEX IF NOT EXISTS idx_server_moderation_expiry ON server_member_moderation(expires_at) WHERE expires_at IS NOT NULL;

-- ============================================
-- RLS POLICIES FOR MODERATION TABLE
-- ============================================
ALTER TABLE server_member_moderation ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Server members can view moderation records" ON server_member_moderation;
DROP POLICY IF EXISTS "Admins can create moderation records" ON server_member_moderation;
DROP POLICY IF EXISTS "Admins can delete moderation records" ON server_member_moderation;

CREATE POLICY "Server members can view moderation records"
    ON server_member_moderation FOR SELECT
    USING (
        auth.uid() IN (
            SELECT user_id FROM server_members WHERE server_id = server_member_moderation.server_id
        )
    );

CREATE POLICY "Admins can create moderation records"
    ON server_member_moderation FOR INSERT
    WITH CHECK (
        auth.uid() = moderator_id AND
        is_server_admin(server_id, auth.uid())
    );

CREATE POLICY "Admins can delete moderation records"
    ON server_member_moderation FOR DELETE
    USING (is_server_admin(server_id, auth.uid()));

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Function to check if user can create more servers (max 2)
CREATE OR REPLACE FUNCTION can_create_server(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_server_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_server_count
    FROM servers
    WHERE owner_id = p_user_id;
    
    RETURN v_server_count < 2;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is banned from server
CREATE OR REPLACE FUNCTION is_user_banned(p_server_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_ban_record RECORD;
BEGIN
    SELECT * INTO v_ban_record
    FROM server_member_moderation
    WHERE server_id = p_server_id
      AND user_id = p_user_id
      AND moderation_type = 'ban'
      AND (expires_at IS NULL OR expires_at > NOW());
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is muted in server
CREATE OR REPLACE FUNCTION is_user_muted(p_server_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_mute_record RECORD;
BEGIN
    SELECT * INTO v_mute_record
    FROM server_member_moderation
    WHERE server_id = p_server_id
      AND user_id = p_user_id
      AND moderation_type = 'mute'
      AND (expires_at IS NULL OR expires_at > NOW());
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is in timeout in server
CREATE OR REPLACE FUNCTION is_user_in_timeout(p_server_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_timeout_record RECORD;
BEGIN
    SELECT * INTO v_timeout_record
    FROM server_member_moderation
    WHERE server_id = p_server_id
      AND user_id = p_user_id
      AND moderation_type = 'timeout'
      AND (expires_at IS NULL OR expires_at > NOW());
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to ban user from server
CREATE OR REPLACE FUNCTION ban_user_from_server(
    p_server_id UUID,
    p_user_id UUID,
    p_moderator_id UUID,
    p_reason TEXT DEFAULT NULL,
    p_permanent BOOLEAN DEFAULT true
)
RETURNS JSON AS $$
DECLARE
    v_is_admin BOOLEAN;
BEGIN
    -- Check if moderator is admin
    SELECT is_server_admin(p_server_id, p_moderator_id) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RETURN json_build_object('success', false, 'error', 'Not authorized');
    END IF;
    
    -- Check if trying to ban an admin/owner
    SELECT is_server_admin(p_server_id, p_user_id) INTO v_is_admin;
    IF v_is_admin THEN
        RETURN json_build_object('success', false, 'error', 'Cannot ban admins or owners');
    END IF;
    
    -- Remove from server members
    DELETE FROM server_members
    WHERE server_id = p_server_id AND user_id = p_user_id;
    
    -- Add ban record (permanent if p_permanent is true)
    INSERT INTO server_member_moderation (server_id, user_id, moderation_type, reason, moderator_id, expires_at)
    VALUES (p_server_id, p_user_id, 'ban', p_reason, p_moderator_id, NULL)
    ON CONFLICT (server_id, user_id, moderation_type) 
    DO UPDATE SET 
        reason = EXCLUDED.reason,
        moderator_id = EXCLUDED.moderator_id,
        expires_at = EXCLUDED.expires_at,
        created_at = NOW();
    
    -- Decrement member count
    UPDATE servers
    SET member_count = GREATEST(member_count - 1, 0),
        updated_at = NOW()
    WHERE id = p_server_id;
    
    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to unban user from server
CREATE OR REPLACE FUNCTION unban_user_from_server(
    p_server_id UUID,
    p_user_id UUID,
    p_moderator_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_is_admin BOOLEAN;
BEGIN
    -- Check if moderator is admin
    SELECT is_server_admin(p_server_id, p_moderator_id) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RETURN json_build_object('success', false, 'error', 'Not authorized');
    END IF;
    
    -- Remove ban record
    DELETE FROM server_member_moderation
    WHERE server_id = p_server_id 
      AND user_id = p_user_id 
      AND moderation_type = 'ban';
    
    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mute user in server
CREATE OR REPLACE FUNCTION mute_user_in_server(
    p_server_id UUID,
    p_user_id UUID,
    p_moderator_id UUID,
    p_reason TEXT DEFAULT NULL,
    p_duration_minutes INTEGER DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_is_admin BOOLEAN;
    v_expires_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Check if moderator is admin
    SELECT is_server_admin(p_server_id, p_moderator_id) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RETURN json_build_object('success', false, 'error', 'Not authorized');
    END IF;
    
    -- Check if trying to mute an admin/owner
    SELECT is_server_admin(p_server_id, p_user_id) INTO v_is_admin;
    IF v_is_admin THEN
        RETURN json_build_object('success', false, 'error', 'Cannot mute admins or owners');
    END IF;
    
    -- Calculate expiry if duration provided
    IF p_duration_minutes IS NOT NULL THEN
        v_expires_at := NOW() + (p_duration_minutes || ' minutes')::INTERVAL;
    ELSE
        v_expires_at := NULL; -- Permanent mute
    END IF;
    
    -- Add mute record
    INSERT INTO server_member_moderation (server_id, user_id, moderation_type, reason, moderator_id, expires_at)
    VALUES (p_server_id, p_user_id, 'mute', p_reason, p_moderator_id, v_expires_at)
    ON CONFLICT (server_id, user_id, moderation_type) 
    DO UPDATE SET 
        reason = EXCLUDED.reason,
        moderator_id = EXCLUDED.moderator_id,
        expires_at = EXCLUDED.expires_at,
        created_at = NOW();
    
    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to unmute user in server
CREATE OR REPLACE FUNCTION unmute_user_in_server(
    p_server_id UUID,
    p_user_id UUID,
    p_moderator_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_is_admin BOOLEAN;
BEGIN
    -- Check if moderator is admin
    SELECT is_server_admin(p_server_id, p_moderator_id) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RETURN json_build_object('success', false, 'error', 'Not authorized');
    END IF;
    
    -- Remove mute record
    DELETE FROM server_member_moderation
    WHERE server_id = p_server_id 
      AND user_id = p_user_id 
      AND moderation_type = 'mute';
    
    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to timeout user in server
CREATE OR REPLACE FUNCTION timeout_user_in_server(
    p_server_id UUID,
    p_user_id UUID,
    p_moderator_id UUID,
    p_reason TEXT DEFAULT NULL,
    p_duration_minutes INTEGER DEFAULT 5
)
RETURNS JSON AS $$
DECLARE
    v_is_admin BOOLEAN;
    v_expires_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Check if moderator is admin
    SELECT is_server_admin(p_server_id, p_moderator_id) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RETURN json_build_object('success', false, 'error', 'Not authorized');
    END IF;
    
    -- Check if trying to timeout an admin/owner
    SELECT is_server_admin(p_server_id, p_user_id) INTO v_is_admin;
    IF v_is_admin THEN
        RETURN json_build_object('success', false, 'error', 'Cannot timeout admins or owners');
    END IF;
    
    -- Calculate expiry (timeouts are always temporary)
    v_expires_at := NOW() + (p_duration_minutes || ' minutes')::INTERVAL;
    
    -- Add timeout record
    INSERT INTO server_member_moderation (server_id, user_id, moderation_type, reason, moderator_id, expires_at)
    VALUES (p_server_id, p_user_id, 'timeout', p_reason, p_moderator_id, v_expires_at)
    ON CONFLICT (server_id, user_id, moderation_type) 
    DO UPDATE SET 
        reason = EXCLUDED.reason,
        moderator_id = EXCLUDED.moderator_id,
        expires_at = EXCLUDED.expires_at,
        created_at = NOW();
    
    RETURN json_build_object('success', true, 'expires_at', v_expires_at);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to remove timeout from user
CREATE OR REPLACE FUNCTION remove_timeout_from_user(
    p_server_id UUID,
    p_user_id UUID,
    p_moderator_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_is_admin BOOLEAN;
BEGIN
    -- Check if moderator is admin
    SELECT is_server_admin(p_server_id, p_moderator_id) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RETURN json_build_object('success', false, 'error', 'Not authorized');
    END IF;
    
    -- Remove timeout record
    DELETE FROM server_member_moderation
    WHERE server_id = p_server_id 
      AND user_id = p_user_id 
      AND moderation_type = 'timeout';
    
    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- UPDATE EXISTING POLICIES
-- ============================================

-- Note: Run SUPABASE_SERVERS_SETUP.sql FIRST before running this file!

-- Update server creation policy to enforce 2-server limit
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'servers' AND policyname = 'Users can create servers') THEN
        DROP POLICY "Users can create servers" ON servers;
    END IF;
END $$;

CREATE POLICY "Users can create servers"
    ON servers FOR INSERT
    WITH CHECK (
        auth.uid() = owner_id AND
        can_create_server(auth.uid())
    );

-- Update server join to prevent banned users
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'server_members' AND policyname = 'Users can join servers') THEN
        DROP POLICY "Users can join servers" ON server_members;
    END IF;
END $$;

CREATE POLICY "Users can join servers"
    ON server_members FOR INSERT
    WITH CHECK (
        auth.uid() = user_id AND
        NOT is_user_banned(server_id, user_id)
    );

-- Update message sending to prevent muted/timed out users
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'server_messages' AND policyname = 'Server members can send messages') THEN
        DROP POLICY "Server members can send messages" ON server_messages;
    END IF;
END $$;

CREATE POLICY "Server members can send messages"
    ON server_messages FOR INSERT
    WITH CHECK (
        auth.uid() = user_id AND
        auth.uid() IN (
            SELECT user_id FROM server_members WHERE server_id = server_messages.server_id
        ) AND
        NOT is_user_muted(server_id, user_id) AND
        NOT is_user_in_timeout(server_id, user_id)
    );

-- Update server update policy to allow admins
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'servers' AND policyname = 'Server owners can update their servers') THEN
        DROP POLICY "Server owners can update their servers" ON servers;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'servers' AND policyname = 'Server owners and admins can update their servers') THEN
        DROP POLICY "Server owners and admins can update their servers" ON servers;
    END IF;
END $$;

CREATE POLICY "Server owners and admins can update their servers"
    ON servers FOR UPDATE
    USING (is_server_admin(id, auth.uid()));

-- ============================================
-- CLEANUP EXPIRED MODERATION RECORDS
-- ============================================

-- Function to clean up expired moderation records
CREATE OR REPLACE FUNCTION cleanup_expired_moderation()
RETURNS void AS $$
BEGIN
    DELETE FROM server_member_moderation
    WHERE expires_at IS NOT NULL 
      AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- You can set up a cron job in Supabase to run this periodically
-- Or call it manually/from your app occasionally

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

GRANT EXECUTE ON FUNCTION can_create_server(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION is_user_banned(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION is_user_muted(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION is_user_in_timeout(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION ban_user_from_server(UUID, UUID, UUID, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION unban_user_from_server(UUID, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION mute_user_in_server(UUID, UUID, UUID, TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION unmute_user_in_server(UUID, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION timeout_user_in_server(UUID, UUID, UUID, TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION remove_timeout_from_user(UUID, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_expired_moderation() TO authenticated;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

/*
-- Check if user can create server
SELECT can_create_server('USER_ID_HERE');

-- Check server count for user
SELECT COUNT(*) FROM servers WHERE owner_id = 'USER_ID_HERE';

-- View all moderation records
SELECT * FROM server_member_moderation ORDER BY created_at DESC;

-- Clean up expired records
SELECT cleanup_expired_moderation();
*/
