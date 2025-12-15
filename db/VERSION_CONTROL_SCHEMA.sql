-- ============================================
-- App Version Control System
-- Created: November 16, 2025
-- ============================================

-- Create app_versions table
CREATE TABLE IF NOT EXISTS app_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version VARCHAR(20) NOT NULL UNIQUE,
  download_url TEXT NOT NULL,
  release_notes TEXT,
  is_required BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for quick lookups
CREATE INDEX IF NOT EXISTS idx_app_versions_created_at 
  ON app_versions(created_at DESC);

-- Add RLS policy (enable for app_versions table)
ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;

-- Policy: Allow public read access
CREATE POLICY "Allow public read access on app_versions"
  ON app_versions
  FOR SELECT
  USING (true);

-- Policy: Only authenticated users can insert (for admin)
CREATE POLICY "Allow authenticated insert on app_versions"
  ON app_versions
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- ============================================
-- Version Check Logs (Analytics)
-- ============================================

CREATE TABLE IF NOT EXISTS version_check_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  current_version VARCHAR(20),
  latest_version VARCHAR(20),
  update_available BOOLEAN,
  checked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_version_check_logs_user_id 
  ON version_check_logs(user_id);

CREATE INDEX IF NOT EXISTS idx_version_check_logs_checked_at 
  ON version_check_logs(checked_at DESC);

-- Add RLS policy
ALTER TABLE version_check_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own logs
CREATE POLICY "Users can view their own version check logs"
  ON version_check_logs
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Allow insert for logged in users
CREATE POLICY "Users can insert their own version check logs"
  ON version_check_logs
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ============================================
-- Sample Data
-- ============================================

-- Current version (1.0.0)
INSERT INTO app_versions (version, download_url, release_notes, is_required)
VALUES (
  '1.0.0',
  'https://play.google.com/store/apps/details?id=com.zinchat.app',
  '• Initial release
• Core messaging features
• Server/channel support
• Voice and video calls',
  false
)
ON CONFLICT (version) DO NOTHING;

-- Next version (optional) - Use this as a test
-- INSERT INTO app_versions (version, download_url, release_notes, is_required)
-- VALUES (
--   '1.0.1',
--   'https://play.google.com/store/apps/details?id=com.zinchat.app',
--   '• Bug fixes
--   • Performance improvements
--   • UI refinements',
--   false
-- );

-- Critical version (required) - Uncomment to test
-- INSERT INTO app_versions (version, download_url, release_notes, is_required)
-- VALUES (
--   '1.1.0',
--   'https://play.google.com/store/apps/details?id=com.zinchat.app',
--   '• Security patches
--   • Critical bug fixes',
--   true
-- );
