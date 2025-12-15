-- Payscribe Virtual Accounts Schema
-- Tables for tracking virtual accounts and deposit transactions

-- Table 1: Virtual Accounts (generated for deposits)
CREATE TABLE IF NOT EXISTS virtual_accounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Account Details from PayScribe
  account_number VARCHAR(20) NOT NULL,
  account_name VARCHAR(100) NOT NULL,
  bank_name VARCHAR(50) NOT NULL,
  bank_code VARCHAR(10) NOT NULL,
  
  -- Order Info
  order_ref UUID NOT NULL UNIQUE,
  amount DECIMAL(12,2) NOT NULL,
  amount_type VARCHAR(10) NOT NULL, -- EXACT or ANY
  description TEXT,
  
  -- Expiry
  expires_at TIMESTAMP NOT NULL,
  
  -- Status
  status VARCHAR(20) DEFAULT 'active', -- active, expired, completed
  paid_amount DECIMAL(12,2),
  
  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Table 2: Deposit Transactions (track webhook confirmations)
CREATE TABLE IF NOT EXISTS deposit_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  virtual_account_id UUID REFERENCES virtual_accounts(id) ON DELETE SET NULL,
  
  -- Transaction Details
  trans_id VARCHAR(100) UNIQUE NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  fee DECIMAL(10,2),
  currency VARCHAR(3) DEFAULT 'NGN',
  
  -- Sender Info (from webhook)
  sender_account VARCHAR(20),
  sender_name VARCHAR(100),
  sender_bank VARCHAR(50),
  
  -- Status
  status VARCHAR(20) DEFAULT 'pending', -- pending, completed, failed
  webhook_verified BOOLEAN DEFAULT FALSE,
  
  -- Webhook Data
  transaction_hash VARCHAR(512),
  webhook_received_at TIMESTAMP,
  
  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_virtual_accounts_user_id ON virtual_accounts(user_id);
CREATE INDEX idx_virtual_accounts_order_ref ON virtual_accounts(order_ref);
CREATE INDEX idx_virtual_accounts_expires_at ON virtual_accounts(expires_at);
CREATE INDEX idx_deposit_transactions_user_id ON deposit_transactions(user_id);
CREATE INDEX idx_deposit_transactions_trans_id ON deposit_transactions(trans_id);
CREATE INDEX idx_deposit_transactions_status ON deposit_transactions(status);

-- Enable realtime for virtual_accounts and deposit_transactions
ALTER PUBLICATION supabase_realtime ADD TABLE virtual_accounts;
ALTER PUBLICATION supabase_realtime ADD TABLE deposit_transactions;
