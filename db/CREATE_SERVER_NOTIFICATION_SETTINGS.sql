-- =====================================================
-- SERVER NOTIFICATION SETTINGS TABLE
-- =====================================================
-- Stores per-user notification preferences for servers
-- Users can enable/disable notifications for each server

-- Drop existing table if needed (for clean migration)
DROP TABLE IF EXISTS server_notification_settings CASCADE;

-- Create server_notification_settings table
CREATE TABLE IF NOT EXISTS server_notification_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  notifications_enabled BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Ensure one setting per user per server
  UNIQUE(user_id, server_id)
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Index for quick lookup by user
CREATE INDEX IF NOT EXISTS idx_server_notif_settings_user_id 
ON server_notification_settings(user_id);

-- Index for quick lookup by server
CREATE INDEX IF NOT EXISTS idx_server_notif_settings_server_id 
ON server_notification_settings(server_id);

-- Composite index for common query pattern
CREATE INDEX IF NOT EXISTS idx_server_notif_settings_user_server 
ON server_notification_settings(user_id, server_id);

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS
ALTER TABLE server_notification_settings ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view their own notification settings
CREATE POLICY "Users can view own notification settings"
ON server_notification_settings
FOR SELECT
USING (auth.uid() = user_id);

-- Policy 2: Users can insert their own notification settings
CREATE POLICY "Users can create own notification settings"
ON server_notification_settings
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy 3: Users can update their own notification settings
CREATE POLICY "Users can update own notification settings"
ON server_notification_settings
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy 4: Users can delete their own notification settings
CREATE POLICY "Users can delete own notification settings"
ON server_notification_settings
FOR DELETE
USING (auth.uid() = user_id);

-- =====================================================
-- TRIGGER FOR UPDATED_AT
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_server_notification_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
CREATE TRIGGER set_server_notification_settings_updated_at
BEFORE UPDATE ON server_notification_settings
FOR EACH ROW
EXECUTE FUNCTION update_server_notification_settings_updated_at();

-- =====================================================
-- HELPER FUNCTION: Check if notifications are enabled
-- =====================================================

CREATE OR REPLACE FUNCTION are_server_notifications_enabled(
  p_user_id UUID,
  p_server_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_enabled BOOLEAN;
BEGIN
  -- Get notification setting, default to true if not found
  SELECT COALESCE(notifications_enabled, true)
  INTO v_enabled
  FROM server_notification_settings
  WHERE user_id = p_user_id AND server_id = p_server_id;
  
  -- If no setting exists, return true (notifications enabled by default)
  RETURN COALESCE(v_enabled, true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- SAMPLE DATA (Optional - for testing)
-- =====================================================

-- Note: This will only work if you have existing users and servers
-- Uncomment to insert sample settings:

/*
INSERT INTO server_notification_settings (user_id, server_id, notifications_enabled)
SELECT 
  sm.user_id,
  sm.server_id,
  true
FROM server_members sm
LIMIT 5
ON CONFLICT (user_id, server_id) DO NOTHING;
*/

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check table structure
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'server_notification_settings';

-- Check RLS policies
-- SELECT * FROM pg_policies WHERE tablename = 'server_notification_settings';

-- Check indexes
-- SELECT indexname, indexdef
-- FROM pg_indexes
-- WHERE tablename = 'server_notification_settings';

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

-- Grant necessary permissions
GRANT ALL ON server_notification_settings TO authenticated;
GRANT ALL ON server_notification_settings TO service_role;

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

-- Summary:
-- ✅ Created server_notification_settings table
-- ✅ Added 3 indexes for performance
-- ✅ Enabled RLS with 4 policies
-- ✅ Created updated_at trigger
-- ✅ Created helper function for checking notification status
-- ✅ Granted permissions

COMMENT ON TABLE server_notification_settings IS 
'Stores per-user notification preferences for servers. Users can enable/disable notifications for each server they are a member of.';
