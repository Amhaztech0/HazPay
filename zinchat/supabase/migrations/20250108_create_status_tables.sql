-- Create status_updates table
CREATE TABLE IF NOT EXISTS status_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT,
  media_url TEXT,
  media_type TEXT NOT NULL CHECK (media_type IN ('text', 'image', 'video')),
  background_color TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  CONSTRAINT status_not_expired CHECK (expires_at > created_at)
);

-- Create status_views table (tracks who viewed which status)
CREATE TABLE IF NOT EXISTS status_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  status_id UUID NOT NULL REFERENCES status_updates(id) ON DELETE CASCADE,
  viewer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(status_id, viewer_id)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_status_updates_user_id ON status_updates(user_id);
CREATE INDEX IF NOT EXISTS idx_status_updates_expires_at ON status_updates(expires_at);
CREATE INDEX IF NOT EXISTS idx_status_views_status_id ON status_views(status_id);
CREATE INDEX IF NOT EXISTS idx_status_views_viewer_id ON status_views(viewer_id);

-- Enable RLS
ALTER TABLE status_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_views ENABLE ROW LEVEL SECURITY;

-- RLS Policies for status_updates
-- Anyone can select non-expired statuses
CREATE POLICY "Anyone can view active statuses" ON status_updates
  FOR SELECT USING (expires_at > NOW());

-- Users can create their own statuses
CREATE POLICY "Users can create own statuses" ON status_updates
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can delete their own statuses
CREATE POLICY "Users can delete own statuses" ON status_updates
  FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for status_views
-- Anyone can read status views
CREATE POLICY "Anyone can view status views" ON status_views
  FOR SELECT USING (true);

-- Users can create view records for themselves
CREATE POLICY "Users can mark statuses as viewed" ON status_views
  FOR INSERT WITH CHECK (auth.uid() = viewer_id);

-- Users can only see their own view records (for data consistency)
CREATE POLICY "Users can only read own view records" ON status_views
  FOR SELECT USING (auth.uid() = viewer_id OR viewer_id = auth.uid());

-- Storage bucket for status media
INSERT INTO storage.buckets (id, name, public)
VALUES ('status-media', 'status-media', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for status-media bucket
CREATE POLICY "Authenticated users can upload status media" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'status-media' 
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "Anyone can view status media" ON storage.objects
  FOR SELECT USING (bucket_id = 'status-media');

CREATE POLICY "Users can delete their own status media" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'status-media'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
