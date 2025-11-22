'use client';

import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
import { BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import { TrendingUp, Users, Wallet, CreditCard } from 'lucide-react';
import { DailySalesMetric, Transaction } from '@/types';

interface DashboardStats {
  totalRevenue: number;
  totalProfit: number;
  totalTransactions: number;
  activeUsers: number;
  todaySales: number;
  todayProfit: number;
}

const COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444'];

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats>({
    totalRevenue: 0,
    totalProfit: 0,
    totalTransactions: 0,
    activeUsers: 0,
    todaySales: 0,
    todayProfit: 0,
  });
  const [salesData, setSalesData] = useState<DailySalesMetric[]>([]);
  const [networkData, setNetworkData] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        // Fetch all transactions
        const { data: transactions, error: txError } = await supabase
          .from('hazpay_transactions')
          .select('*')
          .order('created_at', { ascending: false });

        if (txError) throw txError;

        // Fetch users count
        const { count: userCount } = await supabase
          .from('profiles')
          .select('*', { count: 'exact' });

        // Calculate stats
        let totalRevenue = 0;
        let totalProfit = 0;
        let todaySales = 0;
        let todayProfit = 0;
        const networkMap: Record<string, number> = {};
        const dailyMap: Record<string, DailySalesMetric> = {};

        const today = new Date().toISOString().split('T')[0];

        transactions?.forEach((tx: Transaction) => {
          if (tx.status === 'success') {
            const sellPrice = tx.sell_price || tx.amount;
            const profit = tx.profit || 0;

            totalRevenue += sellPrice;
            totalProfit += profit;

            // Daily metrics
            const txDate = new Date(tx.created_at).toISOString().split('T')[0];
            if (!dailyMap[txDate]) {
              dailyMap[txDate] = { date: txDate, sales: 0, profit: 0, transactions: 0 };
            }
            dailyMap[txDate].sales += sellPrice;
            dailyMap[txDate].profit += profit;
            dailyMap[txDate].transactions += 1;

            // Today's metrics
            if (txDate === today) {
              todaySales += sellPrice;
              todayProfit += profit;
            }

            // Network breakdown
            const network = tx.network_name || 'Unknown';
            networkMap[network] = (networkMap[network] || 0) + 1;
          }
        });

        // Prepare chart data
        const sortedDaily = Object.values(dailyMap)
          .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())
          .slice(-30); // Last 30 days

        const networkChartData = Object.entries(networkMap).map(([name, value]) => ({
          name,
          value,
        }));

        setStats({
          totalRevenue,
          totalProfit,
          totalTransactions: transactions?.length || 0,
          activeUsers: userCount || 0,
          todaySales,
          todayProfit,
        });
        setSalesData(sortedDaily);
        setNetworkData(networkChartData);
      } catch (error) {
        console.error('Failed to fetch dashboard data:', error);
      } finally {
        setIsLoading(false);
      }
    };

    fetchDashboardData();
    const interval = setInterval(fetchDashboardData, 60000); // Refresh every minute

    return () => clearInterval(interval);
  }, []);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-lg text-gray-600">Loading dashboard...</div>
      </div>
    );
  }

  const StatCard = ({ label, value, icon: Icon, color }: any) => (
    <div className="bg-white rounded-lg shadow p-6 border-l-4" style={{ borderColor: color }}>
      <div className="flex items-center justify-between">
        <div>
          <p className="text-gray-600 text-sm font-medium">{label}</p>
          <p className="text-3xl font-bold text-gray-900 mt-2">
            {typeof value === 'number' && label.includes('₦') ? `₦${value.toLocaleString()}` : value.toLocaleString()}
          </p>
        </div>
        <Icon size={32} style={{ color }} className="opacity-20" />
      </div>
    </div>
  );

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-gray-600 mt-2">Welcome to HazPay Admin Dashboard</p>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard label="Total Revenue" value={stats.totalRevenue} icon={CreditCard} color="#3b82f6" />
        <StatCard label="Total Profit" value={stats.totalProfit} icon={TrendingUp} color="#10b981" />
        <StatCard label="Transactions" value={stats.totalTransactions} icon={CreditCard} color="#f59e0b" />
        <StatCard label="Active Users" value={stats.activeUsers} icon={Users} color="#8b5cf6" />
      </div>

      {/* Today's Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-blue-50 rounded-lg p-6 border border-blue-200">
          <h3 className="text-sm font-medium text-blue-900">Today's Sales</h3>
          <p className="text-3xl font-bold text-blue-600 mt-2">₦{stats.todaySales.toLocaleString()}</p>
        </div>
        <div className="bg-green-50 rounded-lg p-6 border border-green-200">
          <h3 className="text-sm font-medium text-green-900">Today's Profit</h3>
          <p className="text-3xl font-bold text-green-600 mt-2">₦{stats.todayProfit.toLocaleString()}</p>
        </div>
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Sales Trend */}
        <div className="lg:col-span-2 bg-white rounded-lg shadow p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Sales Trend (Last 30 Days)</h2>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={salesData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="date" />
              <YAxis />
              <Tooltip formatter={(value) => `₦${value.toLocaleString()}`} />
              <Legend />
              <Line type="monotone" dataKey="sales" stroke="#3b82f6" name="Sales" />
              <Line type="monotone" dataKey="profit" stroke="#10b981" name="Profit" />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Network Distribution */}
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Network Distribution</h2>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={networkData}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={({ name, value }) => `${name}: ${value}`}
                outerRadius={80}
                fill="#8884d8"
                dataKey="value"
              >
                {networkData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  );
}
