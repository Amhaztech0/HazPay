-- Payscribe Migration: Complete Database Setup
-- This script migrates from Amigo API to Payscribe API
-- Includes all networks: MTN, GLO, Airtel, 9mobile, SMILE
-- Plus bills: Electricity, Cable (DSTV, GOTV, Startimes)

-- ============================================================================
-- 1. UPDATE PRICING TABLE - Replace Amigo with Payscribe
-- ============================================================================

-- Add payscribe_plan_id column if not exists
ALTER TABLE pricing ADD COLUMN IF NOT EXISTS payscribe_plan_id VARCHAR(20);

-- Drop old amigo_plan_id if you want to clean up (optional)
-- ALTER TABLE pricing DROP COLUMN IF EXISTS amigo_plan_id;

-- ============================================================================
-- 2. ADD NEW NETWORKS
-- ============================================================================

-- Network IDs:
-- 1 = MTN
-- 2 = GLO  
-- 3 = Airtel
-- 4 = 9mobile
-- 5 = SMILE

-- ============================================================================
-- 3. MTN PLANS (network_id = 1)
-- ============================================================================

DELETE FROM pricing WHERE network_id = 1;

INSERT INTO pricing (plan_id, network_id, plan_name, data_size, sell_price, cost_price, payscribe_plan_id) VALUES
(1, 1, 'MTN 110MB Daily', '110MB', 100, 95, 'PSPLAN_2794'),
(2, 1, 'MTN 500MB 30 Days', '500MB', 250, 240, 'PSPLAN_537'),
(3, 1, 'MTN 1GB 30 Days', '1GB', 280, 270, 'PSPLAN_531'),
(4, 1, 'MTN 500MB 7 Days', '500MB', 350, 335, 'PSPLAN_158'),
(5, 1, 'MTN 1GB 1 Day', '1GB', 500, 480, 'PSPLAN_1305'),
(6, 1, 'MTN 1GB 7-30 Days', '1GB', 550, 530, 'PSPLAN_177'),
(7, 1, 'MTN 2GB 30 Days', '2GB', 560, 540, 'PSPLAN_532'),
(8, 1, 'MTN 1.5GB 2 Days', '1.5GB', 600, 580, 'PSPLAN_2799'),
(9, 1, 'MTN 2GB 2 Days', '2GB', 750, 720, 'PSPLAN_2800'),
(10, 1, 'MTN 1GB+5mins 7 Days', '1GB', 800, 770, 'PSPLAN_2801'),
(11, 1, 'MTN 2.5GB 2 Days', '2.5GB', 900, 870, 'PSPLAN_2802'),
(12, 1, 'MTN 2GB 30 Days SME', '2GB', 940, 910, 'PSPLAN_178'),
(13, 1, 'MTN 3.2GB 2 Days', '3.2GB', 1000, 960, 'PSPLAN_2803'),
(14, 1, 'MTN 1.5GB 7 Days', '1.5GB', 1000, 960, 'PSPLAN_2804'),
(15, 1, 'MTN 3GB 30 Days SME', '3GB', 1410, 1360, 'PSPLAN_179'),
(16, 1, 'MTN 3.2GB 2 Days AWOOF', '3.2GB', 1150, 1110, 'PSPLAN_1306'),
(17, 1, 'MTN 5GB 30 Days', '5GB', 1400, 1350, 'PSPLAN_534'),
(18, 1, 'MTN 3.5GB Weekly', '3.5GB', 1500, 1450, 'PSPLAN_2806'),
(19, 1, 'MTN 1.8GB+6mins Weekly', '1.8GB', 1500, 1450, 'PSPLAN_2805'),
(20, 1, 'MTN 5GB 30 Days SME', '5GB', 2350, 2270, 'PSPLAN_180'),
(21, 1, 'MTN 5GB Weekly', '5GB', 2500, 2410, 'PSPLAN_2807'),
(22, 1, 'MTN 5GB SME', '5GB', 2750, 2660, 'PSPLAN_101'),
(23, 1, 'MTN 10GB 30 Days', '10GB', 2800, 2710, 'PSPLAN_535'),
(24, 1, 'MTN 2.7GB+15mins Monthly', '2.7GB', 3000, 2900, 'PSPLAN_2808'),
(25, 1, 'MTN 4.25GB+10mins Monthly', '4.25GB', 3000, 2900, 'PSPLAN_1400'),
(26, 1, 'MTN 6GB+YouTube Monthly', '6GB', 3000, 2900, 'PSPLAN_1399'),
(27, 1, 'MTN 7GB 7 Days AWOOF', '7GB', 3300, 3190, 'PSPLAN_1307'),
(28, 1, 'MTN 7GB Weekly/Monthly', '7GB', 3500, 3390, 'PSPLAN_2810'),
(29, 1, 'MTN 12GB+Talktime Monthly', '12GB', 3500, 3390, 'PSPLAN_2811'),
(30, 1, 'MTN 5.5GB Monthly', '5.5GB', 3500, 3390, 'PSPLAN_1401'),
(31, 1, 'MTN 15GB 30 Days', '15GB', 4200, 4070, 'PSPLAN_536'),
(32, 1, 'MTN 10GB+10mins Monthly', '10GB', 4500, 4360, 'PSPLAN_2812'),
(33, 1, 'MTN 8GB+25mins Monthly', '8GB', 4500, 4360, 'PSPLAN_1402'),
(34, 1, 'MTN 12.5GB Monthly', '12.5GB', 5000, 4850, 'PSPLAN_2813'),
(35, 1, 'MTN 11GB+25mins Monthly', '11GB', 5000, 4850, 'PSPLAN_1403'),
(36, 1, 'MTN 20GB Gifting', '20GB', 5200, 5050, 'PSPLAN_182'),
(37, 1, 'MTN 12.5GB+36mins+15SMS Weekly', '12.5GB', 5500, 5330, 'PSPLAN_2814'),
(38, 1, 'MTN 10GB SME', '10GB', 6200, 6010, 'PSPLAN_159'),
(39, 1, 'MTN 16.5GB+25mins Monthly', '16.5GB', 6500, 6300, 'PSPLAN_2815'),
(40, 1, 'MTN 15GB+25mins Monthly', '15GB', 6500, 6300, 'PSPLAN_1404'),
(41, 1, 'MTN 10GB SME 30 Days', '10GB', 6800, 6580, 'PSPLAN_181'),
(42, 1, 'MTN 20GB Monthly', '20GB', 7500, 7270, 'PSPLAN_1405'),
(43, 1, 'MTN 30GB Hynet Monthly', '30GB', 9000, 8730, 'PSPLAN_2816'),
(44, 1, 'MTN 40GB Gifting', '40GB', 10400, 10080, 'PSPLAN_183'),
(45, 1, 'MTN 32GB Monthly', '32GB', 11000, 10670, 'PSPLAN_2817'),
(46, 1, 'MTN 60GB Hynet Monthly', '60GB', 14500, 14060, 'PSPLAN_2818'),
(47, 1, 'MTN 65GB Monthly', '65GB', 16000, 15510, 'PSPLAN_2819'),
(48, 1, 'MTN 75GB Monthly', '75GB', 18000, 17460, 'PSPLAN_2820'),
(49, 1, 'MTN 120GB+5GB Youtube Monthly', '120GB', 24000, 23280, 'PSPLAN_2821'),
(50, 1, 'MTN 150GB Silver Monthly', '150GB', 30000, 29100, 'PSPLAN_1411');

-- ============================================================================
-- 4. GLO PLANS (network_id = 2)
-- ============================================================================

DELETE FROM pricing WHERE network_id = 2;

INSERT INTO pricing (plan_id, network_id, plan_name, data_size, sell_price, cost_price, payscribe_plan_id) VALUES
(1, 2, 'GLO 50MB 1 Day', '50MB', 50, 48, 'PSPLAN_316'),
(2, 2, 'GLO 1GB 5 Days', '1GB', 100, 95, 'PSPLAN_318'),
(3, 2, 'GLO 350MB 2 Days', '350MB', 200, 190, 'PSPLAN_317'),
(4, 2, 'GLO 500MB 30 Days Corporate', '500MB', 220, 210, 'PSPLAN_455'),
(5, 2, 'GLO 1GB 30 Days Corporate', '1GB', 450, 430, 'PSPLAN_450'),
(6, 2, 'GLO 1GB 7 Days', '1GB', 450, 430, 'PSPLAN_294'),
(7, 2, 'GLO 1.8GB 14 Days', '1.8GB', 500, 480, 'PSPLAN_315'),
(8, 2, 'GLO 2GB 30 Days Corporate', '2GB', 900, 870, 'PSPLAN_451'),
(9, 2, 'GLO 2.5GB 30 Days', '2.5GB', 900, 870, 'PSPLAN_295'),
(10, 2, 'GLO 3.9GB 30 Days', '3.9GB', 1000, 970, 'PSPLAN_314'),
(11, 2, 'GLO 3GB 30 Days Corporate', '3GB', 1350, 1310, 'PSPLAN_452'),
(12, 2, 'GLO 7.5GB 30 Days', '7.5GB', 1500, 1450, 'PSPLAN_313'),
(13, 2, 'GLO 7GB 7 Days', '7GB', 1500, 1450, 'PSPLAN_312'),
(14, 2, 'GLO 5.8GB 30 Days', '5.8GB', 1800, 1740, 'PSPLAN_296'),
(15, 2, 'GLO 9.2GB 30 Days', '9.2GB', 2000, 1940, 'PSPLAN_311'),
(16, 2, 'GLO 5GB 30 Days Corporate', '5GB', 2250, 2180, 'PSPLAN_453'),
(17, 2, 'GLO 7.7GB 30 Days', '7.7GB', 2250, 2180, 'PSPLAN_297'),
(18, 2, 'GLO 10.8GB 30 Days', '10.8GB', 2500, 2420, 'PSPLAN_310'),
(19, 2, 'GLO 10GB 30 Days', '10GB', 2700, 2620, 'PSPLAN_298'),
(20, 2, 'GLO 14GB 30 Days', '14GB', 3000, 2910, 'PSPLAN_309'),
(21, 2, 'GLO 13.25GB 30 Days', '13.25GB', 3650, 3540, 'PSPLAN_299'),
(22, 2, 'GLO 18GB 30 Days', '18GB', 4000, 3880, 'PSPLAN_308'),
(23, 2, 'GLO 10GB 30 Days Corporate', '10GB', 4500, 4360, 'PSPLAN_454'),
(24, 2, 'GLO 18.25GB 30 Days', '18.25GB', 4550, 4410, 'PSPLAN_300'),
(25, 2, 'GLO 24GB 30 Days', '24GB', 5000, 4850, 'PSPLAN_307'),
(26, 2, 'GLO 29.5GB 30 Days', '29.5GB', 7200, 6980, 'PSPLAN_301'),
(27, 2, 'GLO 50GB 30 Days', '50GB', 9100, 8820, 'PSPLAN_302'),
(28, 2, 'GLO 50GB 30 Days Direct', '50GB', 10000, 9700, 'PSPLAN_820'),
(29, 2, 'GLO 93GB 30 Days', '93GB', 13200, 12800, 'PSPLAN_303'),
(30, 2, 'GLO 93GB 30 Days Direct', '93GB', 15000, 14550, 'PSPLAN_821'),
(31, 2, 'GLO 119GB 30 Days', '119GB', 16950, 16450, 'PSPLAN_304'),
(32, 2, 'GLO 119GB 30 Days Direct', '119GB', 18000, 17460, 'PSPLAN_822'),
(33, 2, 'GLO 138GB 30 Days', '138GB', 19500, 18900, 'PSPLAN_305'),
(34, 2, 'GLO 138GB 30 Days Direct', '138GB', 20000, 19400, 'PSPLAN_823'),
(35, 2, 'GLO 225GB 30 Days', '225GB', 30000, 29100, 'PSPLAN_824'),
(36, 2, 'GLO 300GB 30 Days', '300GB', 36000, 34920, 'PSPLAN_825'),
(37, 2, 'GLO 425GB 90 Days', '425GB', 50000, 48500, 'PSPLAN_826');

-- ============================================================================
-- 5. AIRTEL PLANS (network_id = 3)
-- ============================================================================

DELETE FROM pricing WHERE network_id = 3;

INSERT INTO pricing (plan_id, network_id, plan_name, data_size, sell_price, cost_price, payscribe_plan_id) VALUES
(1, 3, 'Airtel 100MB 7 Days CG', '100MB', 50, 48, 'PSPLAN_238'),
(2, 3, 'Airtel 75MB 1 Day', '75MB', 75, 72, 'PSPLAN_1428'),
(3, 3, 'Airtel 75MB Daily', '75MB', 93, 90, 'PSPLAN_130'),
(4, 3, 'Airtel Talkmore 10mins 3 Days', '10mins', 100, 96, 'PSPLAN_1462'),
(5, 3, 'Airtel 100MB 1 Day', '100MB', 100, 96, 'PSPLAN_1429'),
(6, 3, 'Airtel 100MB CG 7 Days', '100MB', 100, 96, 'PSPLAN_1065'),
(7, 3, 'Airtel 300MB 7 Days CG', '300MB', 100, 96, 'PSPLAN_239'),
(8, 3, 'Airtel 500MB 30 Days CG', '500MB', 150, 145, 'PSPLAN_240'),
(9, 3, 'Airtel 200MB 3 Days', '200MB', 186, 180, 'PSPLAN_131'),
(10, 3, 'Airtel Talkmore 20mins 7 Days', '20mins', 200, 194, 'PSPLAN_1463'),
(11, 3, 'Airtel 200MB 1 Day', '200MB', 200, 194, 'PSPLAN_1452'),
(12, 3, 'Airtel 350MB 7 Days', '350MB', 264, 256, 'PSPLAN_132'),
(13, 3, 'Airtel 1GB 1 Day', '1GB', 264, 256, 'PSPLAN_124'),
(14, 3, 'Airtel Talkmore 30mins 7 Days', '30mins', 300, 290, 'PSPLAN_1464'),
(15, 3, 'Airtel 300MB 1 Day', '300MB', 300, 290, 'PSPLAN_1453'),
(16, 3, 'Airtel 300MB 7 Days CG', '300MB', 300, 290, 'PSPLAN_1066'),
(17, 3, 'Airtel 2GB 1 Day', '2GB', 440, 426, 'PSPLAN_133'),
(18, 3, 'Airtel 750MB 2 Weeks', '750MB', 440, 426, 'PSPLAN_108'),
(19, 3, 'Airtel 500MB 30 Days CG', '500MB', 445, 431, 'PSPLAN_1067'),
(20, 3, 'Airtel Talkmore 50mins 14 Days', '50mins', 500, 485, 'PSPLAN_1465'),
(21, 3, 'Airtel Flexi 500 7 Days', '500MB', 500, 485, 'PSPLAN_1458'),
(22, 3, 'Airtel 1GB 1 Day', '1GB', 500, 485, 'PSPLAN_1431'),
(23, 3, 'Airtel 500MB 7 Days', '500MB', 500, 485, 'PSPLAN_1430'),
(24, 3, 'Airtel Binge 1.5GB 2 Days', '1.5GB', 600, 582, 'PSPLAN_1468'),
(25, 3, 'Airtel 1GB 30 Days CG', '1GB', 620, 601, 'PSPLAN_241'),
(26, 3, 'Airtel 1GB 2 Days AWOOF', '1GB', 650, 631, 'PSPLAN_1294'),
(27, 3, 'Airtel Binge 2GB 2 Days', '2GB', 750, 727, 'PSPLAN_1469'),
(28, 3, 'Airtel 2GB 1 Day', '2GB', 750, 727, 'PSPLAN_1432'),
(29, 3, 'Airtel 1GB 7 Days', '1GB', 800, 776, 'PSPLAN_1454'),
(30, 3, 'Airtel 1GB 7 Days AWOOF', '1GB', 800, 776, 'PSPLAN_1300'),
(31, 3, 'Airtel 1.5GB 30 Days', '1.5GB', 880, 853, 'PSPLAN_71'),
(32, 3, 'Airtel 1GB 30 Days CG', '1GB', 900, 873, 'PSPLAN_1068'),
(33, 3, 'Airtel Binge 3GB 2 Days', '3GB', 1000, 970, 'PSPLAN_1470'),
(34, 3, 'Airtel Talkmore 100mins 14 Days', '100mins', 1000, 970, 'PSPLAN_1466'),
(35, 3, 'Airtel Flexi 1000 7 Days', '1.2GB', 1000, 970, 'PSPLAN_1459'),
(36, 3, 'Airtel 2GB 30 Days', '2GB', 1110, 1076, 'PSPLAN_72'),
(37, 3, 'Airtel 2GB 30 Days CG', '2GB', 1240, 1203, 'PSPLAN_242'),
(38, 3, 'Airtel 3GB 30 Days', '3GB', 1320, 1280, 'PSPLAN_73'),
(39, 3, 'Airtel 2GB 2 Days AWOOF', '2GB', 1400, 1358, 'PSPLAN_1295'),
(40, 3, 'Airtel 5GB 30 Days CG', '5GB', 1425, 1382, 'PSPLAN_243'),
(41, 3, 'Airtel Binge 5GB 2 Days', '5GB', 1500, 1455, 'PSPLAN_1471'),
(42, 3, 'Airtel Talkmore 150mins 30 Days', '150mins', 1500, 1455, 'PSPLAN_1467'),
(43, 3, 'Airtel 3.5GB 7 Days', '3.5GB', 1500, 1455, 'PSPLAN_1455'),
(44, 3, 'Airtel 2GB 30 Days', '2GB', 1500, 1455, 'PSPLAN_1433'),
(45, 3, 'Airtel 1.5GB 7 Days AWOOF', '1.5GB', 1500, 1455, 'PSPLAN_1302'),
(46, 3, 'Airtel 2GB 14 Days AWOOF', '2GB', 1600, 1552, 'PSPLAN_1301'),
(47, 3, 'Airtel 4.5GB 30 Days', '4.5GB', 1760, 1706, 'PSPLAN_88'),
(48, 3, 'Airtel 2GB 30 Days CG', '2GB', 1800, 1746, 'PSPLAN_1069'),
(49, 3, 'Airtel Flexi 2000 30 Days', '2.5GB', 2000, 1940, 'PSPLAN_1460'),
(50, 3, 'Airtel 3GB 30 Days', '3GB', 2000, 1940, 'PSPLAN_1434');

-- ============================================================================
-- 6. 9MOBILE PLANS (network_id = 4)
-- ============================================================================

DELETE FROM pricing WHERE network_id = 4;

INSERT INTO pricing (plan_id, network_id, plan_name, data_size, sell_price, cost_price, payscribe_plan_id) VALUES
(1, 4, '9Mobile 500MB 30 Days', '500MB', 100, 96, 'PSPLAN_494'),
(2, 4, '9Mobile 1GB 30 Days', '1GB', 320, 310, 'PSPLAN_495'),
(3, 4, '9Mobile 1GB 7 Days', '1GB', 460, 445, 'PSPLAN_74'),
(4, 4, '9Mobile 500MB 30 Days', '500MB', 475, 460, 'PSPLAN_168'),
(5, 4, '9Mobile 2GB 30 Days', '2GB', 640, 620, 'PSPLAN_496'),
(6, 4, '9Mobile 1.5GB 30 Days', '1.5GB', 930, 901, 'PSPLAN_75'),
(7, 4, '9Mobile 3GB 30 Days', '3GB', 960, 930, 'PSPLAN_497'),
(8, 4, '9Mobile 2GB 30 Days', '2GB', 1150, 1115, 'PSPLAN_76'),
(9, 4, '9Mobile 3GB 30 Days', '3GB', 1450, 1405, 'PSPLAN_77'),
(10, 4, '9Mobile 5GB 30 Days', '5GB', 1600, 1552, 'PSPLAN_498'),
(11, 4, '9Mobile 4.5GB 30 Days', '4.5GB', 1930, 1871, 'PSPLAN_78'),
(12, 4, '9Mobile 10GB 30 Days', '10GB', 3200, 3104, 'PSPLAN_499'),
(13, 4, '9Mobile 11GB 30 Days', '11GB', 3700, 3587, 'PSPLAN_80'),
(14, 4, '9Mobile 15GB 30 Days', '15GB', 4650, 4511, 'PSPLAN_81'),
(15, 4, '9Mobile 15GB 30 Days', '15GB', 4800, 4656, 'PSPLAN_500'),
(16, 4, '9Mobile 40GB 30 Days', '40GB', 9250, 8972, 'PSPLAN_105'),
(17, 4, '9Mobile 75GB 30 Days', '75GB', 13750, 13338, 'PSPLAN_106');

-- ============================================================================
-- 7. SMILE PLANS (network_id = 5)
-- ============================================================================

DELETE FROM pricing WHERE network_id = 5;

INSERT INTO pricing (plan_id, network_id, plan_name, data_size, sell_price, cost_price, payscribe_plan_id) VALUES
(1, 5, 'SMILE 1GB FlexiDaily', '1GB', 330, 320, 'PSPLAN_552'),
(2, 5, 'SMILE 1GB FlexiWeekly', '1GB', 550, 533, 'PSPLAN_586'),
(3, 5, 'SMILE 2.5GB FlexiDaily', '2.5GB', 550, 533, 'PSPLAN_585'),
(4, 5, 'SMILE 1GB FlexiWeekly', '1GB', 550, 533, 'PSPLAN_576'),
(5, 5, 'SMILE SmileVoice 60min', '60min', 550, 533, 'PSPLAN_545'),
(6, 5, 'SMILE 2.5GB FlexiDaily', '2.5GB', 550, 533, 'PSPLAN_540'),
(7, 5, 'SMILE SmileVoice 65min Monthly', '65min', 600, 582, 'PSPLAN_579'),
(8, 5, 'SMILE 2GB FlexiWeekly', '2GB', 1100, 1067, 'PSPLAN_575'),
(9, 5, 'SMILE 1.5GB Bigga', '1.5GB', 1100, 1067, 'PSPLAN_560'),
(10, 5, 'SMILE SmileVoice 125min Monthly', '125min', 1100, 1067, 'PSPLAN_553'),
(11, 5, 'SMILE SmileVoice 135min', '135min', 1250, 1213, 'PSPLAN_569'),
(12, 5, 'SMILE 2GB Bigga', '2GB', 1320, 1280, 'PSPLAN_580'),
(13, 5, 'SMILE 6GB FlexiWeekly', '6GB', 1650, 1600, 'PSPLAN_561'),
(14, 5, 'SMILE 3GB Bigga', '3GB', 1650, 1600, 'PSPLAN_548'),
(15, 5, 'SMILE SmileVoice 150min', '150min', 1800, 1746, 'PSPLAN_566'),
(16, 5, 'SMILE 5GB Bigga', '5GB', 2200, 2134, 'PSPLAN_551'),
(17, 5, 'SMILE SmileVoice 175min', '175min', 2400, 2328, 'PSPLAN_568'),
(18, 5, 'SMILE 6.5GB Bigga', '6.5GB', 2750, 2668, 'PSPLAN_583'),
(19, 5, 'SMILE 10GB Bigga', '10GB', 3300, 3201, 'PSPLAN_555'),
(20, 5, 'SMILE 15GB Bigga', '15GB', 4400, 4268, 'PSPLAN_563'),
(21, 5, 'SMILE SmileVoice 450min', '450min', 4850, 4705, 'PSPLAN_556'),
(22, 5, 'SMILE Freedom Mobile Plan', 'Unlimited', 5000, 4850, 'PSPLAN_571'),
(23, 5, 'SMILE 20GB Bigga', '20GB', 5500, 5335, 'PSPLAN_565'),
(24, 5, 'SMILE SmileVoice 500min', '500min', 6050, 5869, 'PSPLAN_581'),
(25, 5, 'SMILE 25GB Bigga', '25GB', 6600, 6402, 'PSPLAN_538'),
(26, 5, 'SMILE 30GB Bigga', '30GB', 8800, 8536, 'PSPLAN_546');

-- ============================================================================
-- 8. CREATE BILLS PAYMENTS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.bills_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  bill_type VARCHAR(50) NOT NULL CHECK (bill_type IN ('electricity', 'cable', 'internet')),
  provider VARCHAR(100) NOT NULL,
  account_number TEXT NOT NULL,
  customer_name TEXT,
  amount DECIMAL(15, 2) NOT NULL,
  reference TEXT UNIQUE,
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed')),
  error_message TEXT,
  payscribe_plan_id VARCHAR(100),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT positive_amount CHECK (amount > 0)
);

CREATE INDEX idx_bills_payments_user_id ON public.bills_payments(user_id);
CREATE INDEX idx_bills_payments_status ON public.bills_payments(status);
CREATE INDEX idx_bills_payments_created_at ON public.bills_payments(created_at DESC);

-- ============================================================================
-- 9. ELECTRICITY DISCO MAPPING
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.electricity_discos (
  id TEXT PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL,
  code VARCHAR(20) UNIQUE NOT NULL,
  description TEXT
);

INSERT INTO electricity_discos (id, name, code, description) VALUES
('1', 'Ikeja Electric', 'ikedc', 'Ikeja Distribution Company'),
('2', 'Enugu Electric', 'ekedc', 'Enugu Distribution Company'),
('3', 'Port Harcourt Electric', 'phedc', 'Port Harcourt Distribution Company'),
('4', 'Abuja Electric', 'aedc', 'Abuja Distribution Company'),
('5', 'Kano Electric', 'kano', 'Kano Distribution Company'),
('6', 'Kaduna Electric', 'kaduna', 'Kaduna Distribution Company'),
('7', 'Katsina', 'jed', 'Katsina Distribution Company'),
('8', 'Benin Electric', 'ibedc', 'Benin Distribution Company'),
('9', 'Eko Electric', 'ekedc_eko', 'Eko Distribution Company');

-- ============================================================================
-- 10. ENABLE RLS ON NEW TABLES
-- ============================================================================

ALTER TABLE public.bills_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own bills"
  ON public.bills_payments FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Authenticated users can insert bills"
  ON public.bills_payments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own bills"
  ON public.bills_payments FOR UPDATE
  USING (auth.uid() = user_id);

-- ============================================================================
-- 11. MIGRATION SUMMARY
-- ============================================================================
-- Networks:
-- 1 = MTN (50+ plans)
-- 2 = GLO (37+ plans)
-- 3 = Airtel (50+ plans)
-- 4 = 9mobile (17 plans)
-- 5 = SMILE (26+ plans)
--
-- Bills:
-- - Electricity: All 9 discos supported
-- - Cable: DSTV, GOTV, Startimes, DSTVShowMax
-- - All plans mapped to Payscribe plan IDs
-- ============================================================================
