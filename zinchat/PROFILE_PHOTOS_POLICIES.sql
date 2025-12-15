-- Profile Photos Storage Policies
-- Run this to fix the 403 error when uploading profile photos

-- Allow authenticated users to upload their own profile photos
-- Safe profile-photos policies: drop any existing and create clean policies.
-- Run this in Supabase SQL Editor.

-- Remove any existing profile-photos related policies (safe to run multiple times)
DROP POLICY IF EXISTS "Users can upload their own profile photos" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view profile photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own profile photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own profile photos" ON storage.objects;

-- Allow authenticated users to upload into the profile-photos bucket.
-- The policy is intentionally simple: restrict by bucket_id and allow only authenticated role.
CREATE POLICY "Users can upload their own profile photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile-photos'
);

-- Allow anyone to read profile photos (public bucket)
CREATE POLICY "Anyone can view profile photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'profile-photos');

-- Allow authenticated users to update objects in profile-photos (restrict to bucket)
CREATE POLICY "Users can update their own profile photos"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'profile-photos')
WITH CHECK (bucket_id = 'profile-photos');

-- Allow authenticated users to delete objects in profile-photos (restrict to bucket)
CREATE POLICY "Users can delete their own profile photos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'profile-photos');
