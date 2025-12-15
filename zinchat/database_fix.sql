-- Fix empty display names in profiles table
-- Run this in your Supabase SQL Editor

-- Update all empty or null display_name values to 'ZinChat User'
UPDATE profiles 
SET display_name = 'ZinChat User'
WHERE display_name IS NULL OR display_name = '' OR TRIM(display_name) = '';

-- Verify the update
SELECT id, display_name, phone_number, created_at 
FROM profiles 
ORDER BY created_at DESC;
