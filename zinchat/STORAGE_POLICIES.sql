-- Storage Policies for Profile Photos, Status Media, and Server Media
-- Run this in your Supabase SQL Editor

-- ============================================
-- PROFILE PHOTOS BUCKET POLICIES
-- ============================================

-- Allow authenticated users to upload their own profile photos
CREATE POLICY "Users can upload their own profile photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile-photos' AND
  auth.role() = 'authenticated'
);

-- Allow public viewing of all profile photos
CREATE POLICY "Anyone can view profile photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'profile-photos');

-- Allow users to update their own profile photos
CREATE POLICY "Users can update their own profile photos"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'profile-photos')
WITH CHECK (bucket_id = 'profile-photos');

-- Allow users to delete their own profile photos
CREATE POLICY "Users can delete their own profile photos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile-photos' AND
  auth.role() = 'authenticated'
);

-- ============================================
-- STATUS MEDIA BUCKET POLICIES
-- ============================================

-- Allow authenticated users to upload status media
CREATE POLICY "Users can upload status media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'status-media' AND
  auth.role() = 'authenticated'
);

-- Allow public viewing of status media
CREATE POLICY "Anyone can view status media"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'status-media');

-- Allow users to delete their own status media
CREATE POLICY "Users can delete their own status media"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'status-media' AND
  auth.role() = 'authenticated'
);

-- ============================================
-- SERVER MEDIA BUCKET POLICIES (if not already created)
-- ============================================

-- Allow authenticated users to upload server media
CREATE POLICY "Users can upload server media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'server-media' AND
  auth.role() = 'authenticated'
);

-- Allow public viewing of server media
CREATE POLICY "Anyone can view server media"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'server-media');

-- Allow users to delete server media
CREATE POLICY "Users can delete server media"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'server-media' AND
  auth.role() = 'authenticated'
);

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check all storage policies
-- Run this to verify policies were created:
-- SELECT * FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage';

-- Check buckets
-- SELECT * FROM storage.buckets;

-- ============================================
-- NOTES
-- ============================================

-- If you get "policy already exists" errors, that's OK - it means they're already there
-- If you need to drop and recreate policies, use:
-- DROP POLICY IF EXISTS "policy_name_here" ON storage.objects;

-- Make sure your buckets are set as PUBLIC in the Supabase dashboard:
-- Storage → Click on bucket → Make sure "Public bucket" toggle is ON
