'use client';

import { useEffect, useState, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { 
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, 
  PieChart, Pie, Cell 
} from 'recharts';
import { TrendingUp, Users, Wallet, CreditCard, RefreshCw } from 'lucide-react';
import { DailySalesMetric, Transaction } from '@/types';
import { 
  Card, CardHeader, CardContent, StatCard, MetricCard,
  PageHeader, RefreshButton,
  StatsGridSkeleton, ChartSkeleton, Alert
} from '@/components/ui';
import { theme, formatCurrency } from '@/lib/theme';

interface DashboardStats {
  totalRevenue: number;
  totalProfit: number;
  totalTransactions: number;
  activeUsers: number;
  todaySales: number;
  todayProfit: number;
}

const CHART_COLORS = [
  theme.chart.primary,
  theme.chart.success,
  theme.chart.warning,
  theme.chart.danger,
];

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
  const [networkData, setNetworkData] = useState<Array<{ name: string; value: number }>>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  const fetchDashboardData = useCallback(async () => {
    try {
      setError(null);
      
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
      setLastUpdated(new Date());
    } catch (err) {
      console.error('Failed to fetch dashboard data:', err);
      setError('Failed to load dashboard data. Please try again.');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchDashboardData();
    const interval = setInterval(fetchDashboardData, 60000); // Refresh every minute
    return () => clearInterval(interval);
  }, [fetchDashboardData]);

  const handleRefresh = () => {
    setIsLoading(true);
    fetchDashboardData();
  };

  if (isLoading && !lastUpdated) {
    return (
      <div className="space-y-8">
        <PageHeader 
          title="Dashboard" 
          description="Welcome to HazPay Admin Dashboard" 
        />
        <StatsGridSkeleton count={4} />
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <ChartSkeleton height="120px" />
          <ChartSkeleton height="120px" />
        </div>
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2">
            <ChartSkeleton height="300px" />
          </div>
          <ChartSkeleton height="300px" />
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <PageHeader 
        title="Dashboard" 
        description="Welcome to HazPay Admin Dashboard"
      >
        <RefreshButton 
          onClick={handleRefresh} 
          isLoading={isLoading}
          lastUpdated={lastUpdated}
        />
      </PageHeader>

      {/* Error Alert */}
      {error && (
        <Alert 
          variant="danger" 
          title="Error" 
          onDismiss={() => setError(null)}
        >
          {error}
        </Alert>
      )}

      {/* Key Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard 
          label="Total Revenue" 
          value={stats.totalRevenue} 
          icon={<CreditCard size={28} />} 
          color="blue" 
        />
        <StatCard 
          label="Total Profit" 
          value={stats.totalProfit} 
          icon={<TrendingUp size={28} />} 
          color="green" 
        />
        <StatCard 
          label="Transactions" 
          value={stats.totalTransactions} 
          icon={<Wallet size={28} />} 
          color="amber" 
          isCurrency={false}
        />
        <StatCard 
          label="Active Users" 
          value={stats.activeUsers} 
          icon={<Users size={28} />} 
          color="purple" 
          isCurrency={false}
        />
      </div>

      {/* Today's Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <MetricCard
          label="Today's Sales"
          value={formatCurrency(stats.todaySales)}
          color="blue"
        />
        <MetricCard
          label="Today's Profit"
          value={formatCurrency(stats.todayProfit)}
          color="green"
        />
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Sales Trend */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <h2 className="text-lg font-semibold text-gray-900">
              Sales Trend (Last 30 Days)
            </h2>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={salesData}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--color-gray-200)" />
                <XAxis 
                  dataKey="date" 
                  tick={{ fill: 'var(--color-text-secondary)', fontSize: 12 }}
                  tickFormatter={(value) => {
                    const date = new Date(value);
                    return `${date.getDate()}/${date.getMonth() + 1}`;
                  }}
                />
                <YAxis 
                  tick={{ fill: 'var(--color-text-secondary)', fontSize: 12 }}
                  tickFormatter={(value) => `₦${(value / 1000).toFixed(0)}k`}
                />
                <Tooltip 
                  formatter={(value: number) => formatCurrency(value)}
                  contentStyle={{
                    backgroundColor: 'var(--color-white)',
                    border: '1px solid var(--color-gray-200)',
                    borderRadius: 'var(--radius-md)',
                  }}
                />
                <Legend />
                <Line 
                  type="monotone" 
                  dataKey="sales" 
                  stroke={theme.chart.primary}
                  strokeWidth={2}
                  dot={{ fill: theme.chart.primary, strokeWidth: 2 }}
                  name="Sales" 
                />
                <Line 
                  type="monotone" 
                  dataKey="profit" 
                  stroke={theme.chart.success}
                  strokeWidth={2}
                  dot={{ fill: theme.chart.success, strokeWidth: 2 }}
                  name="Profit" 
                />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Network Distribution */}
        <Card>
          <CardHeader>
            <h2 className="text-lg font-semibold text-gray-900">
              Network Distribution
            </h2>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={networkData}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, percent }) => 
                    `${name || 'Unknown'}: ${((percent ?? 0) * 100).toFixed(0)}%`
                  }
                  outerRadius={80}
                  fill="#8884d8"
                  dataKey="value"
                >
                  {networkData.map((_, index) => (
                    <Cell 
                      key={`cell-${index}`} 
                      fill={CHART_COLORS[index % CHART_COLORS.length]} 
                    />
                  ))}
                </Pie>
                <Tooltip 
                  contentStyle={{
                    backgroundColor: '#ffffff',
                    border: '1px solid #e5e7eb',
                    borderRadius: '8px',
                  }}
                />
              </PieChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
