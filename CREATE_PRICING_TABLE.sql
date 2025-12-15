-- Create pricing table for custom pricing control
CREATE TABLE IF NOT EXISTS pricing (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id INTEGER NOT NULL,
  network_id INTEGER NOT NULL,
  plan_name VARCHAR(50) NOT NULL,
  data_size VARCHAR(20) NOT NULL,
  cost_price DECIMAL(10, 2) NOT NULL,
  sell_price DECIMAL(10, 2) NOT NULL,
  profit DECIMAL(10, 2) GENERATED ALWAYS AS (sell_price - cost_price) STORED,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(plan_id, network_id)
);

-- Add column comments
COMMENT ON COLUMN pricing.cost_price IS 'Amigo buy rate';
COMMENT ON COLUMN pricing.sell_price IS 'Your selling price';

-- Enable RLS
ALTER TABLE pricing ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Allow anyone to read pricing (public data)
CREATE POLICY "Allow public read pricing"
  ON pricing FOR SELECT
  USING (true);

-- Only admin can insert/update/delete pricing
CREATE POLICY "Allow admin pricing write"
  ON pricing FOR INSERT
  WITH CHECK (auth.jwt() ->> 'email' = 'admin@example.com');

CREATE POLICY "Allow admin pricing update"
  ON pricing FOR UPDATE
  USING (auth.jwt() ->> 'email' = 'admin@example.com')
  WITH CHECK (auth.jwt() ->> 'email' = 'admin@example.com');

CREATE POLICY "Allow admin pricing delete"
  ON pricing FOR DELETE
  USING (auth.jwt() ->> 'email' = 'admin@example.com');

-- Insert MTN pricing (network_id = 1)
INSERT INTO pricing (plan_id, network_id, plan_name, data_size, cost_price, sell_price) VALUES
(1, 1, 'MTN', '500MB', 250, 350),
(2, 1, 'MTN', '1GB', 350, 500),
(3, 1, 'MTN', '2GB', 650, 1000),
(4, 1, 'MTN', '3GB', 950, 1500),
(5, 1, 'MTN', '5GB', 1400, 2100),
(6, 1, 'MTN', '10GB', 2600, 3900),
(7, 1, 'MTN', '15GB', 3950, 5900),
(8, 1, 'MTN', '20GB', 5500, 8200),
(9, 1, 'MTN', '36GB', 8400, 12500);

-- Insert GLO pricing (network_id = 2)
INSERT INTO pricing (plan_id, network_id, plan_name, data_size, cost_price, sell_price) VALUES
(10, 2, 'GLO', '500MB', 140, 240),
(11, 2, 'GLO', '1GB', 280, 450),
(12, 2, 'GLO', '2GB', 550, 950),
(13, 2, 'GLO', '3GB', 800, 1350),
(14, 2, 'GLO', '5GB', 1350, 2200),
(15, 2, 'GLO', '10GB', 2650, 4200);

-- Add column to hazpay_transactions to track profit and sell_price
ALTER TABLE hazpay_transactions 
ADD COLUMN IF NOT EXISTS sell_price DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS cost_price DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS profit DECIMAL(10, 2);

-- Verify pricing table
SELECT * FROM pricing ORDER BY network_id, plan_id;
