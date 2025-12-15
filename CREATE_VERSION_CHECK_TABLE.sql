-- Version Check System - Database Schema
-- Run this SQL in Supabase to set up the version tracking table

CREATE TABLE IF NOT EXISTS app_versions (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  version TEXT NOT NULL UNIQUE,
  version_order INT NOT NULL,
  release_notes TEXT,
  download_url TEXT,
  force_update BOOLEAN DEFAULT FALSE,
  min_supported_version TEXT,
  platforms TEXT[] DEFAULT ARRAY['android', 'ios'],
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS app_versions_version_order_idx ON app_versions(version_order DESC);

-- Insert example versions
INSERT INTO app_versions (version, version_order, release_notes, download_url, force_update, min_supported_version, platforms)
VALUES 
  ('1.0.0', 1, 'Initial release', 'https://play.google.com/store/apps/details?id=com.zinchat.app', FALSE, '0.9.0', ARRAY['android', 'ios']),
  ('1.0.1', 2, 'Bug fixes and performance improvements', 'https://play.google.com/store/apps/details?id=com.zinchat.app', FALSE, '0.9.0', ARRAY['android', 'ios']),
  ('1.1.0', 3, 'New features: voice messages, improved search', 'https://play.google.com/store/apps/details?id=com.zinchat.app', FALSE, '1.0.0', ARRAY['android', 'ios'])
ON CONFLICT DO NOTHING;

-- Enable RLS (Row Level Security)
ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;

-- Create policy to allow everyone to read version information (no update needed for this)
CREATE POLICY "Allow public read access" ON app_versions
  FOR SELECT
  USING (true);

-- Create policy to allow authenticated users to read
CREATE POLICY "Allow authenticated read access" ON app_versions
  FOR SELECT
  USING (auth.role() = 'authenticated');
