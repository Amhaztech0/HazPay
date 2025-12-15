
-- FIX_STORAGE_POLICIES.sql
-- This script resolves issues with file uploads for server icons and server media.
-- It ensures the required buckets exist and applies the correct RLS policies.

BEGIN;

-- 1. Create `server-icons` bucket if it doesn't exist
-- This bucket stores server profile pictures.
INSERT INTO storage.buckets (id, name, public)
VALUES ('server-icons', 'server-icons', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Create `server-media` bucket if it doesn't exist
-- This bucket stores images and other files sent in server chats.
INSERT INTO storage.buckets (id, name, public)
VALUES ('server-media', 'server-media', false) -- Keep it private, access is via RLS
ON CONFLICT (id) DO NOTHING;

-- 3. RLS Policies for `server-icons`
-- Allow public read access for server icons.
DROP POLICY IF EXISTS "Allow public read access on server-icons" ON storage.objects;
CREATE POLICY "Allow public read access on server-icons"
ON storage.objects FOR SELECT
USING ( bucket_id = 'server-icons' );

-- Allow authenticated users who are server owners or admins to upload/update icons.
-- Path format: servers/{server-id}.{ext} (e.g., servers/abc-123-def.png)
DROP POLICY IF EXISTS "Allow owner/admin to upload server icons" ON storage.objects;
CREATE POLICY "Allow owner/admin to upload server icons"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'server-icons' AND
    auth.role() = 'authenticated' AND
    (
        -- Extract server ID from path: servers/{server-id}.ext
        -- Split by '/' to get: [servers, {server-id}.ext]
        -- Then split by '.' to get the server-id part
        EXISTS (
            SELECT 1
            FROM public.server_members sm
            WHERE sm.user_id = auth.uid()
            AND sm.server_id = (
                -- Get the second element after splitting by '/', then remove extension
                split_part((string_to_array(name, '/'))[2], '.', 1)
            )::uuid
            AND (sm.role = 'owner' OR sm.role = 'admin')
        )
    )
);

DROP POLICY IF EXISTS "Allow owner/admin to update server icons" ON storage.objects;
CREATE POLICY "Allow owner/admin to update server icons"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'server-icons' AND
    auth.role() = 'authenticated' AND
    (
        EXISTS (
            SELECT 1
            FROM public.server_members sm
            WHERE sm.user_id = auth.uid()
            AND sm.server_id = (
                split_part((string_to_array(name, '/'))[2], '.', 1)
            )::uuid
            AND (sm.role = 'owner' OR sm.role = 'admin')
        )
    )
);


-- 4. RLS Policies for `server-media`
-- Allow server members to view media from their server.
-- Path format: servers/{server-id}/{timestamp}_{filename}
DROP POLICY IF EXISTS "Allow server members to view media" ON storage.objects;
CREATE POLICY "Allow server members to view media"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'server-media' AND
    auth.role() = 'authenticated' AND
    (
        -- Extract server ID from path: servers/{server-id}/{timestamp}_{filename}
        -- Split by '/' gives: ['servers', '{server-id}', '{timestamp}_{filename}']
        -- Index [2] is the server-id (PostgreSQL arrays are 1-indexed)
        EXISTS (
            SELECT 1
            FROM public.server_members sm
            WHERE sm.user_id = auth.uid()
            AND sm.server_id = (string_to_array(name, '/'))[2]::uuid
        )
    )
);

-- Allow authenticated server members to upload media to their server.
DROP POLICY IF EXISTS "Allow server members to upload media" ON storage.objects;
CREATE POLICY "Allow server members to upload media"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'server-media' AND
    auth.role() = 'authenticated' AND
    (
        -- Extract server ID from path: servers/{server-id}/{timestamp}_{filename}
        -- Split by '/' gives: ['servers', '{server-id}', '{timestamp}_{filename}']
        -- Index [2] is the server-id (PostgreSQL arrays are 1-indexed)
        EXISTS (
            SELECT 1
            FROM public.server_members sm
            WHERE sm.user_id = auth.uid()
            AND sm.server_id = (string_to_array(name, '/'))[2]::uuid
        )
    )
);

COMMIT;
