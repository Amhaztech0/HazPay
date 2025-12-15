-- =====================================================
-- VOICE/VIDEO CALLING SYSTEM - DATABASE SCHEMA
-- =====================================================
-- This schema supports both 1-on-1 WebRTC calls and server group calls via 100ms
-- Run this in your Supabase SQL Editor

-- =====================================================
-- 1. CALLS TABLE - Track all calls (1-on-1 and group)
-- =====================================================
CREATE TABLE IF NOT EXISTS calls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_type VARCHAR(20) NOT NULL CHECK (call_type IN ('direct', 'server')),
    media_type VARCHAR(20) NOT NULL CHECK (media_type IN ('audio', 'video')),
    
    -- For direct calls
    caller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- For server calls (using server_id only, no channels table dependency)
    server_id UUID, -- References servers if table exists
    channel_id UUID, -- Store channel ID without foreign key constraint
    channel_name VARCHAR(255), -- Store channel name for reference
    
    -- Call status
    status VARCHAR(20) NOT NULL DEFAULT 'initiated' CHECK (status IN ('initiated', 'ringing', 'active', 'ended', 'rejected', 'missed', 'cancelled')),
    
    -- Call metadata
    started_at TIMESTAMPTZ DEFAULT NOW(),
    answered_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER DEFAULT 0,
    
    -- External service IDs
    hms_room_id VARCHAR(255), -- 100ms room ID for server calls
    hms_room_code VARCHAR(100), -- 100ms room code for joining
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_calls_caller ON calls(caller_id) WHERE call_type = 'direct';
CREATE INDEX IF NOT EXISTS idx_calls_receiver ON calls(receiver_id) WHERE call_type = 'direct';
CREATE INDEX IF NOT EXISTS idx_calls_server ON calls(server_id) WHERE call_type = 'server';
CREATE INDEX IF NOT EXISTS idx_calls_channel ON calls(channel_id) WHERE call_type = 'server';
CREATE INDEX IF NOT EXISTS idx_calls_status ON calls(status);
CREATE INDEX IF NOT EXISTS idx_calls_created_at ON calls(created_at DESC);

-- =====================================================
-- 2. CALL_PARTICIPANTS - Track who's in server calls
-- =====================================================
CREATE TABLE IF NOT EXISTS call_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_id UUID NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Participant status
    status VARCHAR(20) NOT NULL DEFAULT 'invited' CHECK (status IN ('invited', 'joined', 'left', 'declined')),
    
    -- Timestamps
    joined_at TIMESTAMPTZ,
    left_at TIMESTAMPTZ,
    duration_seconds INTEGER DEFAULT 0,
    
    -- Media state
    is_audio_muted BOOLEAN DEFAULT false,
    is_video_muted BOOLEAN DEFAULT false,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(call_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_call_participants_call ON call_participants(call_id);
CREATE INDEX IF NOT EXISTS idx_call_participants_user ON call_participants(user_id);

-- =====================================================
-- 3. WEBRTC_SIGNALS - Signaling for direct calls
-- =====================================================
CREATE TABLE IF NOT EXISTS webrtc_signals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_id UUID NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
    from_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    to_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Signal data
    signal_type VARCHAR(20) NOT NULL CHECK (signal_type IN ('offer', 'answer', 'ice-candidate')),
    signal_data JSONB NOT NULL,
    
    -- Metadata
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_webrtc_signals_call ON webrtc_signals(call_id);
CREATE INDEX IF NOT EXISTS idx_webrtc_signals_to_user ON webrtc_signals(to_user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_webrtc_signals_created ON webrtc_signals(created_at DESC);

-- =====================================================
-- 4. CALL_SETTINGS - User preferences for calls
-- =====================================================
CREATE TABLE IF NOT EXISTS call_settings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Call preferences
    allow_direct_calls BOOLEAN DEFAULT true,
    allow_server_calls BOOLEAN DEFAULT true,
    default_audio_muted BOOLEAN DEFAULT false,
    default_video_muted BOOLEAN DEFAULT false,
    
    -- Notification preferences
    call_notifications_enabled BOOLEAN DEFAULT true,
    vibrate_on_call BOOLEAN DEFAULT true,
    call_ringtone VARCHAR(100) DEFAULT 'default',
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 5. ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own calls" ON calls;
DROP POLICY IF EXISTS "Users can create calls" ON calls;
DROP POLICY IF EXISTS "Call participants can update calls" ON calls;
DROP POLICY IF EXISTS "Users can view call participants" ON call_participants;
DROP POLICY IF EXISTS "Users can insert call participants" ON call_participants;
DROP POLICY IF EXISTS "Users can update their own participant status" ON call_participants;
DROP POLICY IF EXISTS "Users can view their signals" ON webrtc_signals;
DROP POLICY IF EXISTS "Users can send signals" ON webrtc_signals;
DROP POLICY IF EXISTS "Users can update their received signals" ON webrtc_signals;
DROP POLICY IF EXISTS "Users can view their own settings" ON call_settings;
DROP POLICY IF EXISTS "Users can insert their own settings" ON call_settings;
DROP POLICY IF EXISTS "Users can update their own settings" ON call_settings;

-- Enable RLS
ALTER TABLE calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE call_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE webrtc_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE call_settings ENABLE ROW LEVEL SECURITY;

-- Calls policies
CREATE POLICY "Users can view their own calls"
    ON calls FOR SELECT
    USING (
        auth.uid() = caller_id 
        OR auth.uid() = receiver_id
    );

CREATE POLICY "Users can create calls"
    ON calls FOR INSERT
    WITH CHECK (
        auth.uid() = caller_id
    );

CREATE POLICY "Call participants can update calls"
    ON calls FOR UPDATE
    USING (
        auth.uid() = caller_id 
        OR auth.uid() = receiver_id
    );

-- Call participants policies
CREATE POLICY "Users can view call participants"
    ON call_participants FOR SELECT
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM calls
            WHERE calls.id = call_participants.call_id
            AND (calls.caller_id = auth.uid() OR calls.receiver_id = auth.uid())
        )
    );

CREATE POLICY "Users can insert call participants"
    ON call_participants FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM calls
            WHERE calls.id = call_participants.call_id
            AND calls.caller_id = auth.uid()
        )
        OR user_id = auth.uid()
    );

CREATE POLICY "Users can update their own participant status"
    ON call_participants FOR UPDATE
    USING (user_id = auth.uid());

-- WebRTC signals policies
CREATE POLICY "Users can view their signals"
    ON webrtc_signals FOR SELECT
    USING (to_user_id = auth.uid() OR from_user_id = auth.uid());

CREATE POLICY "Users can send signals"
    ON webrtc_signals FOR INSERT
    WITH CHECK (from_user_id = auth.uid());

CREATE POLICY "Users can update their received signals"
    ON webrtc_signals FOR UPDATE
    USING (to_user_id = auth.uid());

-- Call settings policies
CREATE POLICY "Users can view their own settings"
    ON call_settings FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own settings"
    ON call_settings FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own settings"
    ON call_settings FOR UPDATE
    USING (user_id = auth.uid());

-- =====================================================
-- 6. REALTIME SUBSCRIPTIONS
-- =====================================================

-- Enable realtime for calls (skip if already added)
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE calls;
    EXCEPTION WHEN duplicate_object THEN
        NULL;
    END;
    
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE call_participants;
    EXCEPTION WHEN duplicate_object THEN
        NULL;
    END;
    
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE webrtc_signals;
    EXCEPTION WHEN duplicate_object THEN
        NULL;
    END;
END $$;

-- =====================================================
-- 7. FUNCTIONS & TRIGGERS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
DROP TRIGGER IF EXISTS update_calls_updated_at ON calls;
CREATE TRIGGER update_calls_updated_at
    BEFORE UPDATE ON calls
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_call_participants_updated_at ON call_participants;
CREATE TRIGGER update_call_participants_updated_at
    BEFORE UPDATE ON call_participants
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_call_settings_updated_at ON call_settings;
CREATE TRIGGER update_call_settings_updated_at
    BEFORE UPDATE ON call_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to calculate call duration on end
CREATE OR REPLACE FUNCTION calculate_call_duration()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'ended' AND NEW.answered_at IS NOT NULL THEN
        NEW.duration_seconds = EXTRACT(EPOCH FROM (NEW.ended_at - NEW.answered_at))::INTEGER;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS calculate_call_duration_trigger ON calls;
CREATE TRIGGER calculate_call_duration_trigger
    BEFORE UPDATE ON calls
    FOR EACH ROW
    WHEN (NEW.status = 'ended')
    EXECUTE FUNCTION calculate_call_duration();

-- Function to calculate participant duration
CREATE OR REPLACE FUNCTION calculate_participant_duration()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.left_at IS NOT NULL AND NEW.joined_at IS NOT NULL THEN
        NEW.duration_seconds = EXTRACT(EPOCH FROM (NEW.left_at - NEW.joined_at))::INTEGER;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS calculate_participant_duration_trigger ON call_participants;
CREATE TRIGGER calculate_participant_duration_trigger
    BEFORE UPDATE ON call_participants
    FOR EACH ROW
    WHEN (NEW.left_at IS NOT NULL)
    EXECUTE FUNCTION calculate_participant_duration();

-- Note: Auto-creation of call_settings removed because we cannot create triggers on auth.users
-- Users will get default settings created on first call attempt instead

-- =====================================================
-- 8. HELPER FUNCTIONS
-- =====================================================

-- Function to get active call for a user
CREATE OR REPLACE FUNCTION get_active_call(user_uuid UUID)
RETURNS TABLE (
    call_id UUID,
    call_type VARCHAR,
    media_type VARCHAR,
    status VARCHAR,
    other_user_id UUID,
    other_user_name TEXT,
    server_name TEXT,
    channel_name TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.call_type,
        c.media_type,
        c.status,
        CASE 
            WHEN c.caller_id = user_uuid THEN c.receiver_id
            ELSE c.caller_id
        END as other_user_id,
        CASE 
            WHEN c.caller_id = user_uuid THEN (SELECT display_name FROM profiles WHERE id = c.receiver_id)
            ELSE (SELECT display_name FROM profiles WHERE id = c.caller_id)
        END as other_user_name,
        NULL::TEXT as server_name,
        c.channel_name as channel_name
    FROM calls c
    WHERE c.status IN ('initiated', 'ringing', 'active')
    AND (
        c.caller_id = user_uuid 
        OR c.receiver_id = user_uuid
        OR EXISTS (
            SELECT 1 FROM call_participants cp
            WHERE cp.call_id = c.id
            AND cp.user_id = user_uuid
            AND cp.status = 'joined'
        )
    )
    ORDER BY c.created_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- SETUP COMPLETE!
-- =====================================================
-- Next steps:
-- 1. Run: flutter pub get
-- 2. Configure 100ms credentials in your app
-- 3. Setup free TURN servers (Metered.ca or similar)
-- 4. Test 1-on-1 calls with WebRTC
-- 5. Test server calls with 100ms
