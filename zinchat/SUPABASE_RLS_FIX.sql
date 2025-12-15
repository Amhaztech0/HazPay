-- Run this SQL in your Supabase Dashboard → SQL Editor
-- This allows authenticated users to upload files to the chat-media bucket

-- Drop existing policies if they exist (ignore errors if they don't)
DROP POLICY IF EXISTS "allow_authenticated_upload_chat_media" ON storage.objects;
DROP POLICY IF EXISTS "allow_authenticated_read_chat_media" ON storage.objects;
DROP POLICY IF EXISTS "allow_delete_own_chat_media" ON storage.objects;

-- 1. Allow authenticated users to INSERT files into chat-media bucket
CREATE POLICY "allow_authenticated_upload_chat_media"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'chat-media'
);

-- 2. Allow authenticated users to READ files from chat-media bucket
CREATE POLICY "allow_authenticated_read_chat_media"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'chat-media');

-- 3. Allow users to DELETE their own uploads
CREATE POLICY "allow_delete_own_chat_media"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'chat-media' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Optional: Make bucket public for easier access
-- (You can also do this in Dashboard → Storage → Buckets → chat-media → Toggle Public)
UPDATE storage.buckets 
SET public = true 
WHERE id = 'chat-media';
