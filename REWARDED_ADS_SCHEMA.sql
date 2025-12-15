-- Rewarded Ads System Schema for HazPay
-- Tracks user points, daily ad limits, and redemptions

-- 1. USER POINTS TABLE
CREATE TABLE IF NOT EXISTS user_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  points INT DEFAULT 0,
  total_points_earned INT DEFAULT 0,
  total_redemptions INT DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 2. REWARD ADS WATCHED TABLE
-- Tracks individual ad views and daily limits
CREATE TABLE IF NOT EXISTS reward_ads_watched (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  watched_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  points_earned INT DEFAULT 1,
  ad_unit_id TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 3. REWARD REDEMPTIONS TABLE
-- Tracks when users redeem their points for data
CREATE TABLE IF NOT EXISTS reward_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  points_spent INT DEFAULT 100,
  data_amount TEXT DEFAULT '500MB', -- '500MB', '1GB', etc.
  network_id INT NOT NULL, -- 1 for MTN, 2 for GLO
  status TEXT DEFAULT 'pending', -- pending, issued, failed
  transaction_id TEXT,
  failure_reason TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  redeemed_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 4. DAILY AD LIMITS TRACKING TABLE
-- Stores daily ad view count per user (resets every 24h)
CREATE TABLE IF NOT EXISTS daily_ad_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ads_watched_today INT DEFAULT 0,
  limit_date DATE DEFAULT CURRENT_DATE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  CONSTRAINT unique_daily_limit UNIQUE(user_id, limit_date)
);

-- INDEXES FOR PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_reward_ads_user_watched ON reward_ads_watched(user_id, watched_at DESC);
CREATE INDEX IF NOT EXISTS idx_reward_ads_user_id ON reward_ads_watched(user_id);
CREATE INDEX IF NOT EXISTS idx_reward_redemptions_user ON reward_redemptions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_daily_ad_limits_user ON daily_ad_limits(user_id, limit_date DESC);

-- ROW LEVEL SECURITY POLICIES

-- Enable RLS on all tables
ALTER TABLE user_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_ads_watched ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_ad_limits ENABLE ROW LEVEL SECURITY;

-- USER POINTS POLICIES
CREATE POLICY "Users can view own points"
  ON user_points FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own points"
  ON user_points FOR UPDATE
  USING (auth.uid() = user_id);

-- Admins can update (for backend operations)
CREATE POLICY "Admins can manage all points"
  ON user_points FOR ALL
  USING ((SELECT is_admin FROM profiles WHERE id = auth.uid() LIMIT 1) = true);

-- REWARD ADS WATCHED POLICIES
CREATE POLICY "Users can view own ad watch history"
  ON reward_ads_watched FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own ad watches"
  ON reward_ads_watched FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can manage all ad watches"
  ON reward_ads_watched FOR ALL
  USING ((SELECT is_admin FROM profiles WHERE id = auth.uid() LIMIT 1) = true);

-- REWARD REDEMPTIONS POLICIES
CREATE POLICY "Users can view own redemptions"
  ON reward_redemptions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create own redemptions"
  ON reward_redemptions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can manage all redemptions"
  ON reward_redemptions FOR ALL
  USING ((SELECT is_admin FROM profiles WHERE id = auth.uid() LIMIT 1) = true);

-- DAILY AD LIMITS POLICIES
CREATE POLICY "Users can view own daily limits"
  ON daily_ad_limits FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own daily limits"
  ON daily_ad_limits FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all daily limits"
  ON daily_ad_limits FOR ALL
  USING ((SELECT is_admin FROM profiles WHERE id = auth.uid() LIMIT 1) = true);

-- HELPER FUNCTIONS

-- Function to get today's ad watch count
CREATE OR REPLACE FUNCTION get_daily_ad_count(p_user_id UUID)
RETURNS INT AS $$
  SELECT COALESCE(ads_watched_today, 0)
  FROM daily_ad_limits
  WHERE user_id = p_user_id AND limit_date = CURRENT_DATE;
$$ LANGUAGE SQL STABLE;

-- Function to check if user can watch more ads
CREATE OR REPLACE FUNCTION can_watch_more_ads(p_user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT get_daily_ad_count(p_user_id) < 10;
$$ LANGUAGE SQL STABLE;

-- Function to increment daily ad count
CREATE OR REPLACE FUNCTION increment_daily_ad_count(p_user_id UUID)
RETURNS INT AS $$
  INSERT INTO daily_ad_limits (user_id, limit_date, ads_watched_today)
  VALUES (p_user_id, CURRENT_DATE, 1)
  ON CONFLICT (user_id, limit_date)
  DO UPDATE SET 
    ads_watched_today = daily_ad_limits.ads_watched_today + 1,
    updated_at = NOW()
  RETURNING ads_watched_today;
$$ LANGUAGE SQL;

-- Function to add points to user
CREATE OR REPLACE FUNCTION add_points(p_user_id UUID, p_points INT DEFAULT 1)
RETURNS INT AS $$
  UPDATE user_points
  SET 
    points = points + p_points,
    total_points_earned = total_points_earned + p_points,
    updated_at = NOW()
  WHERE user_id = p_user_id
  RETURNING points;
$$ LANGUAGE SQL;

-- Function to redeem points for data
CREATE OR REPLACE FUNCTION redeem_points(p_user_id UUID, p_points INT DEFAULT 100)
RETURNS INT AS $$
  UPDATE user_points
  SET 
    points = points - p_points,
    total_redemptions = total_redemptions + 1,
    updated_at = NOW()
  WHERE user_id = p_user_id AND points >= p_points
  RETURNING points;
$$ LANGUAGE SQL;

-- TRIGGER: Auto-initialize user points when profiles are created
CREATE OR REPLACE FUNCTION init_user_points()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_points (user_id, points, total_points_earned, total_redemptions)
  VALUES (NEW.id, 0, 0, 0);
  RETURN NEW;
END;
$$ LANGUAGE PLPGSQL;

DROP TRIGGER IF EXISTS trigger_init_user_points ON profiles;
CREATE TRIGGER trigger_init_user_points
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION init_user_points();

-- TRIGGER: Reset daily ad count at midnight (cleanup old records)
CREATE OR REPLACE FUNCTION cleanup_old_daily_limits()
RETURNS void AS $$
BEGIN
  DELETE FROM daily_ad_limits
  WHERE limit_date < CURRENT_DATE - INTERVAL '7 days';
END;
$$ LANGUAGE PLPGSQL;

-- Note: Schedule this cleanup job via pg_cron or call manually
-- SELECT cron.schedule('cleanup-old-daily-limits', '0 0 * * *', 'SELECT cleanup_old_daily_limits()');

-- COMMENTS
COMMENT ON TABLE user_points IS 'Tracks accumulated points per user for rewarded ads system';
COMMENT ON TABLE reward_ads_watched IS 'Records individual ad watch events with timestamps';
COMMENT ON TABLE reward_redemptions IS 'Tracks when users redeem points for free data';
COMMENT ON TABLE daily_ad_limits IS 'Enforces 10-ads-per-day limit, resets at midnight';
COMMENT ON COLUMN user_points.points IS 'Current accumulated points balance';
COMMENT ON COLUMN user_points.total_points_earned IS 'Lifetime total points earned';
COMMENT ON COLUMN daily_ad_limits.ads_watched_today IS 'Counter for ads watched in CURRENT_DATE (resets next day)';
COMMENT ON COLUMN reward_redemptions.status IS 'pending (awaiting edge function), issued (data sent), or failed (error occurred)';
