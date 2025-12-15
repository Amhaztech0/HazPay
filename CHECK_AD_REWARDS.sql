-- Check Rewarded Ads Activity
-- Run this in Supabase SQL Editor to see if your ad watches were recorded

-- 1. Check your user_points
SELECT 
    user_id, 
    points, 
    updated_at 
FROM user_points 
WHERE user_id = auth.uid()
ORDER BY updated_at DESC 
LIMIT 1;

-- 2. Check reward_ads_watched records
SELECT 
    id, 
    user_id, 
    ad_unit_id, 
    points_earned, 
    watched_at 
FROM reward_ads_watched 
WHERE user_id = auth.uid()
ORDER BY watched_at DESC 
LIMIT 10;

-- 3. Check daily_ad_limits for today
SELECT 
    user_id, 
    ads_watched_today, 
    last_reset 
FROM daily_ad_limits 
WHERE user_id = auth.uid()
AND CAST(last_reset AS DATE) = CURRENT_DATE;

-- 4. Count total ads watched by current user
SELECT 
    COUNT(*) as total_ads_watched,
    SUM(points_earned) as total_points_earned
FROM reward_ads_watched 
WHERE user_id = auth.uid();
