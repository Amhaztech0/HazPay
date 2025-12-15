-- ============================================================================
-- UPDATE PRICING TABLE WITH SELECTED PLANS
-- Created: 2025-12-15
-- This migration updates the pricing table with manually selected plans
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. MTN PLANS (network_id = 1) - 60% Profit Margin
-- ============================================================================

DELETE FROM pricing WHERE network_id = 1;

INSERT INTO pricing (plan_id, network_id, plan_name, data_size, sell_price, cost_price, payscribe_plan_id) VALUES
(1, 1, 'MTN 500MB 30 Days', '500MB', 240, 150, 'PSPLAN_185'),
(2, 1, 'MTN 1GB 30 Days', '1GB', 450, 280, 'PSPLAN_531'),
(3, 1, 'MTN 2GB 30 Days', '2GB', 900, 560, 'PSPLAN_532'),
(4, 1, 'MTN 3GB 30 Days', '3GB', 1350, 840, 'PSPLAN_533'),
(5, 1, 'MTN 3.2GB 30 Days', '3.2GB', 1600, 1000, 'PSPLAN_2739'),
(6, 1, 'MTN 5GB 30 Days', '5GB', 2250, 1400, 'PSPLAN_534'),
(7, 1, 'MTN 5GB Weekly', '5GB', 2400, 1500, 'PSPLAN_1396'),
(8, 1, 'MTN 10GB 30 Days', '10GB', 4500, 2800, 'PSPLAN_535'),
(9, 1, 'MTN 20GB 30 Days', '20GB', 8350, 5200, 'PSPLAN_182'),
(10, 1, 'MTN 40GB 30 Days', '40GB', 16650, 10400, 'PSPLAN_183'),
(11, 1, 'MTN 65GB 30 Days', '65GB', 25600, 16000, 'PSPLAN_2819'),
(12, 1, 'MTN 75GB 30 Days', '75GB', 28800, 18000, 'PSPLAN_2820'),
(13, 1, 'MTN 165GB 30 Days', '165GB', 56000, 35000, 'PSPLAN_2822');

-- ============================================================================
-- 2. AIRTEL PLANS (network_id = 3) - 90% Profit Margin (except 1GB daily = fixed 400)
-- ============================================================================

DELETE FROM pricing WHERE network_id = 3;

INSERT INTO pricing (plan_id, network_id, plan_name, data_size, sell_price, cost_price, payscribe_plan_id) VALUES
(1, 3, 'Airtel 100MB', '100MB', 100, 50, 'PSPLAN_238'),
(2, 3, 'Airtel 300MB', '300MB', 200, 100, 'PSPLAN_239'),
(3, 3, 'Airtel 500MB', '500MB', 290, 150, 'PSPLAN_240'),
(4, 3, 'Airtel 1GB Daily', '1GB', 400, 264, 'PSPLAN_124'),
(5, 3, 'Airtel 10GB', '10GB', 5020, 2640, 'PSPLAN_109'),
(6, 3, 'Airtel Router Unlimited', 'Unlimited', 285000, 150000, 'PSPLAN_1427');

-- ============================================================================
-- 3. GLO PLANS (network_id = 2) - Variable Profit Margins
-- ============================================================================

DELETE FROM pricing WHERE network_id = 2;

INSERT INTO pricing (plan_id, network_id, plan_name, data_size, sell_price, cost_price, payscribe_plan_id) VALUES
(1, 2, 'Glo 50MB', '50MB', 50, 50, 'PSPLAN_316'),
(2, 2, 'Glo 1GB 5 Days', '1GB', 200, 100, 'PSPLAN_318'),
(3, 2, 'Glo 1.8GB 14 Days', '1.8GB', 1000, 500, 'PSPLAN_315'),
(4, 2, 'Glo 2.5GB 30 Days', '2.5GB', 1450, 900, 'PSPLAN_295'),
(5, 2, 'Glo 7.5GB 30 Days', '7.5GB', 2400, 1500, 'PSPLAN_313'),
(6, 2, 'Glo 10GB 30 Days', '10GB', 4350, 2700, 'PSPLAN_298'),
(7, 2, 'Glo 24GB 30 Days', '24GB', 8000, 5000, 'PSPLAN_307'),
(8, 2, 'Glo 119GB 30 Days', '119GB', 24300, 18000, 'PSPLAN_822'),
(9, 2, 'Glo 675GB 120 Days', '675GB', 101250, 75000, 'PSPLAN_828'),
(10, 2, 'Glo 1TB 365 Days', '1TB', 135000, 100000, 'PSPLAN_829');

-- ============================================================================
-- COMMIT TRANSACTION
-- ============================================================================

COMMIT;

-- Verify the updates
SELECT 
  p.plan_id,
  p.network_id,
  p.plan_name,
  p.data_size,
  p.cost_price,
  p.sell_price,
  p.payscribe_plan_id
FROM pricing p
WHERE p.network_id IN (1, 2, 3)
ORDER BY p.network_id, p.sell_price ASC;
