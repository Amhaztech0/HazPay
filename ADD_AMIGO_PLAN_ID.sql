-- Add amigo_plan_id column to pricing table
ALTER TABLE pricing ADD COLUMN IF NOT EXISTS amigo_plan_id VARCHAR(20);

-- Update MTN plans with Amigo plan IDs (network_id = 1)
UPDATE pricing SET amigo_plan_id = '5000' WHERE plan_id = 1 AND network_id = 1;   -- 500MB
UPDATE pricing SET amigo_plan_id = '1001' WHERE plan_id = 2 AND network_id = 1;   -- 1GB
UPDATE pricing SET amigo_plan_id = '6666' WHERE plan_id = 3 AND network_id = 1;   -- 2GB
UPDATE pricing SET amigo_plan_id = '3333' WHERE plan_id = 4 AND network_id = 1;   -- 3GB
UPDATE pricing SET amigo_plan_id = '9999' WHERE plan_id = 5 AND network_id = 1;   -- 5GB
UPDATE pricing SET amigo_plan_id = '1110' WHERE plan_id = 6 AND network_id = 1;   -- 10GB
UPDATE pricing SET amigo_plan_id = '1515' WHERE plan_id = 7 AND network_id = 1;   -- 15GB
UPDATE pricing SET amigo_plan_id = '424' WHERE plan_id = 8 AND network_id = 1;    -- 20GB
UPDATE pricing SET amigo_plan_id = '379' WHERE plan_id = 9 AND network_id = 1;    -- 36GB

-- Update GLO plans with Amigo plan IDs (network_id = 2)
UPDATE pricing SET amigo_plan_id = '296' WHERE plan_id = 10 AND network_id = 2;   -- 200MB
UPDATE pricing SET amigo_plan_id = '258' WHERE plan_id = 11 AND network_id = 2;   -- 500MB
UPDATE pricing SET amigo_plan_id = '261' WHERE plan_id = 12 AND network_id = 2;   -- 1GB
UPDATE pricing SET amigo_plan_id = '262' WHERE plan_id = 13 AND network_id = 2;   -- 2GB
UPDATE pricing SET amigo_plan_id = '263' WHERE plan_id = 14 AND network_id = 2;   -- 3GB
UPDATE pricing SET amigo_plan_id = '297' WHERE plan_id = 15 AND network_id = 2;   -- 5GB
UPDATE pricing SET amigo_plan_id = '265' WHERE plan_id = 16 AND network_id = 2;   -- 10GB

-- Verify the updates
SELECT plan_id, network_id, data_size, amigo_plan_id, sell_price, cost_price FROM pricing ORDER BY network_id, plan_id;
