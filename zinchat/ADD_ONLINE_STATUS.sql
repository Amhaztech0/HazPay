-- Add last_seen column to profiles table for online status tracking
-- Run this in your Supabase SQL Editor

-- Add last_seen column if it doesn't exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Create index for faster queries on last_seen
CREATE INDEX IF NOT EXISTS idx_profiles_last_seen ON profiles(last_seen DESC);

-- Create a function to check if user is online (active within last 2 minutes)
CREATE OR REPLACE FUNCTION is_user_online(user_last_seen TIMESTAMP WITH TIME ZONE)
RETURNS BOOLEAN AS $$
BEGIN
    IF user_last_seen IS NULL THEN
        RETURN FALSE;
    END IF;
    
    RETURN (NOW() - user_last_seen) < INTERVAL '2 minutes';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Optional: Create a view for easy online status checking
CREATE OR REPLACE VIEW user_online_status AS
SELECT 
    id,
    display_name,
    last_seen,
    is_user_online(last_seen) as is_online,
    CASE 
        WHEN is_user_online(last_seen) THEN 'online'
        WHEN last_seen IS NULL THEN 'last seen recently'
        WHEN (NOW() - last_seen) < INTERVAL '1 hour' THEN 
            'last seen ' || EXTRACT(MINUTE FROM (NOW() - last_seen))::INTEGER || ' minutes ago'
        WHEN (NOW() - last_seen) < INTERVAL '24 hours' THEN 
            'last seen ' || EXTRACT(HOUR FROM (NOW() - last_seen))::INTEGER || ' hours ago'
        WHEN (NOW() - last_seen) < INTERVAL '48 hours' THEN 
            'last seen yesterday'
        WHEN (NOW() - last_seen) < INTERVAL '7 days' THEN 
            'last seen ' || EXTRACT(DAY FROM (NOW() - last_seen))::INTEGER || ' days ago'
        ELSE 'last seen recently'
    END as last_seen_text
FROM profiles;

-- Grant access to the view
GRANT SELECT ON user_online_status TO authenticated;

-- Optional: Add a trigger to automatically update last_seen on profile updates
-- (This is if you want to track any profile activity, not just explicit presence updates)
CREATE OR REPLACE FUNCTION update_last_seen_on_profile_update()
RETURNS TRIGGER AS $$
BEGIN
    -- Only update last_seen if it's not being explicitly set in the UPDATE
    IF (TG_OP = 'UPDATE' AND OLD.last_seen = NEW.last_seen) THEN
        NEW.last_seen = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_update_last_seen_on_profile_update ON profiles;

-- Create trigger (optional - only if you want automatic tracking)
-- Comment this out if you prefer manual presence updates only
-- CREATE TRIGGER trigger_update_last_seen_on_profile_update
--     BEFORE UPDATE ON profiles
--     FOR EACH ROW
--     EXECUTE FUNCTION update_last_seen_on_profile_update();

-- Update existing users to have current timestamp as initial last_seen
UPDATE profiles 
SET last_seen = NOW() 
WHERE last_seen IS NULL;

COMMENT ON COLUMN profiles.last_seen IS 'Last time user was active. Users are considered online if active within last 2 minutes.';
COMMENT ON FUNCTION is_user_online IS 'Returns true if user has been active within the last 2 minutes';
COMMENT ON VIEW user_online_status IS 'Convenient view showing each user''s online status and formatted last seen text';
