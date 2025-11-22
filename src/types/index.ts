export interface Transaction {
  id: string;
  user_id: string;
  type: 'purchase' | 'deposit' | 'withdrawal';
  amount: number;
  network_name: string;
  data_capacity: string;
  mobile_number: string;
  reference: string;
  status: 'pending' | 'success' | 'failed';
  sell_price?: number;
  cost_price?: number;
  profit?: number;
  created_at: string;
}

export interface Wallet {
  id: string;
  user_id: string;
  balance: number;
  total_deposits: number;
  total_spent: number;
  updated_at: string;
}

export interface DataPlan {
  id: string;
  plan_id: number;
  network_id: number;
  plan_name: string;
  data_size: string;
  cost_price: number;
  sell_price: number;
  profit: number;
  amigo_plan_id: string;
  updated_at: string;
}

export interface User {
  id: string;
  email: string;
  phone: string;
  name: string;
  status: 'active' | 'suspended';
  created_at: string;
  last_login?: string;
}

export interface DailySalesMetric {
  date: string;
  sales: number;
  profit: number;
  transactions: number;
}
