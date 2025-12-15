-- Add foreign key relationship from server_members to profiles
-- This allows us to join server_members with profiles using Supabase PostgREST

-- First, check if the constraint already exists and drop it if needed
ALTER TABLE IF EXISTS server_members 
DROP CONSTRAINT IF EXISTS server_members_user_id_fkey CASCADE;

-- Add the foreign key relationship
ALTER TABLE server_members 
ADD CONSTRAINT server_members_user_id_fkey 
FOREIGN KEY (user_id) 
REFERENCES auth.users(id) 
ON DELETE CASCADE;

-- Also verify server_id foreign key exists
ALTER TABLE IF EXISTS server_members 
DROP CONSTRAINT IF EXISTS server_members_server_id_fkey CASCADE;

ALTER TABLE server_members 
ADD CONSTRAINT server_members_server_id_fkey 
FOREIGN KEY (server_id) 
REFERENCES servers(id) 
ON DELETE CASCADE;

-- Note: The view creation is optional - the app now fetches members and profiles separately
-- If you want to create a view, first check your profiles table columns with:
-- SELECT column_name FROM information_schema.columns WHERE table_name='profiles';
-- Then uncomment and modify the CREATE VIEW statement below with the correct column names

-- Example (modify column names based on your actual profiles table):
-- DROP VIEW IF EXISTS server_members_with_profiles CASCADE;
-- CREATE VIEW server_members_with_profiles AS
-- SELECT 
--   sm.id,
--   sm.server_id,
--   sm.user_id,
--   sm.role,
--   sm.joined_at,
--   p.id as profile_id,
--   p.username,  -- or full_name, display_name, etc. depending on your schema
--   p.avatar_url,
--   p.bio,
--   p.status,
--   p.updated_at as profile_updated_at
-- FROM server_members sm
-- LEFT JOIN auth.users au ON sm.user_id = au.id
-- LEFT JOIN profiles p ON au.id = p.id;
-- GRANT SELECT ON server_members_with_profiles TO authenticated;
-- GRANT SELECT ON server_members_with_profiles TO anon;
