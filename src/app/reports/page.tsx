'use client';

import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
import { Transaction } from '@/types';
import { BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { Download } from 'lucide-react';
import Papa from 'papaparse';

interface ReportData {
  period: string;
  sales: number;
  profit: number;
  transactions: number;
  topPlans: Array<{ plan: string; count: number; revenue: number }>;
}

export default function ReportsPage() {
  const [timeframe, setTimeframe] = useState<'daily' | 'weekly' | 'monthly'>('daily');
  const [reportData, setReportData] = useState<ReportData[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    fetchReports();
  }, [timeframe]);

  const fetchReports = async () => {
    setIsLoading(true);
    try {
      const { data: transactions, error } = await supabase
        .from('hazpay_transactions')
        .select('*')
        .eq('status', 'success')
        .order('created_at', { ascending: false })
        .limit(1000);

      if (error) throw error;

      const reportMap: Record<string, ReportData> = {};

      transactions?.forEach((tx: Transaction) => {
        let periodKey: string;
        const date = new Date(tx.created_at);

        if (timeframe === 'daily') {
          periodKey = date.toISOString().split('T')[0];
        } else if (timeframe === 'weekly') {
          const weekStart = new Date(date);
          weekStart.setDate(date.getDate() - date.getDay());
          periodKey = `Week of ${weekStart.toISOString().split('T')[0]}`;
        } else {
          periodKey = date.toLocaleDateString('en-US', { year: 'numeric', month: 'long' });
        }

        if (!reportMap[periodKey]) {
          reportMap[periodKey] = {
            period: periodKey,
            sales: 0,
            profit: 0,
            transactions: 0,
            topPlans: [],
          };
        }

        const sellPrice = tx.sell_price || tx.amount;
        const profit = tx.profit || 0;

        reportMap[periodKey].sales += sellPrice;
        reportMap[periodKey].profit += profit;
        reportMap[periodKey].transactions += 1;
      });

      const sorted = Object.values(reportMap).sort((a, b) => {
        if (timeframe === 'daily') {
          return new Date(a.period).getTime() - new Date(b.period).getTime();
        }
        return 0;
      });

      setReportData(sorted);
    } catch (error) {
      console.error('Failed to fetch reports:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const exportReport = () => {
    const csv = Papa.unparse(
      reportData.map((r) => ({
        Period: r.period,
        'Sales (₦)': r.sales,
        'Profit (₦)': r.profit,
        Transactions: r.transactions,
        'Avg Profit Per Transaction': (r.profit / r.transactions).toFixed(2),
      }))
    );

    const element = document.createElement('a');
    element.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv);
    element.download = `hazpay-report-${timeframe}-${new Date().toISOString().split('T')[0]}.csv`;
    element.click();
  };

  const totalSales = reportData.reduce((sum, r) => sum + r.sales, 0);
  const totalProfit = reportData.reduce((sum, r) => sum + r.profit, 0);
  const totalTransactions = reportData.reduce((sum, r) => sum + r.transactions, 0);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-lg text-gray-600">Loading reports...</div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Reports & Analytics</h1>
        <p className="text-gray-600 mt-2">View sales trends and business metrics</p>
      </div>

      {/* Controls */}
      <div className="bg-white rounded-lg shadow p-4 flex justify-between items-center gap-4">
        <div className="flex gap-2">
          {(['daily', 'weekly', 'monthly'] as const).map((tf) => (
            <button
              key={tf}
              onClick={() => setTimeframe(tf)}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                timeframe === tf
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-200 text-gray-900 hover:bg-gray-300'
              }`}
            >
              {tf.charAt(0).toUpperCase() + tf.slice(1)}
            </button>
          ))}
        </div>
        <button
          onClick={exportReport}
          className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
        >
          <Download size={18} /> Export CSV
        </button>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white rounded-lg shadow p-6 border-l-4 border-blue-600">
          <p className="text-gray-600 text-sm font-medium">Total Sales</p>
          <p className="text-3xl font-bold text-gray-900 mt-2">₦{totalSales.toLocaleString()}</p>
          <p className="text-sm text-gray-600 mt-2">{reportData.length} periods</p>
        </div>
        <div className="bg-white rounded-lg shadow p-6 border-l-4 border-green-600">
          <p className="text-gray-600 text-sm font-medium">Total Profit</p>
          <p className="text-3xl font-bold text-gray-900 mt-2">₦{totalProfit.toLocaleString()}</p>
          <p className="text-sm text-gray-600 mt-2">
            {((totalProfit / totalSales) * 100).toFixed(1)}% margin
          </p>
        </div>
        <div className="bg-white rounded-lg shadow p-6 border-l-4 border-purple-600">
          <p className="text-gray-600 text-sm font-medium">Total Transactions</p>
          <p className="text-3xl font-bold text-gray-900 mt-2">{totalTransactions}</p>
          <p className="text-sm text-gray-600 mt-2">
            Avg: ₦{(totalSales / totalTransactions).toFixed(0)} per tx
          </p>
        </div>
      </div>

      {/* Sales Trend Chart */}
      <div className="bg-white rounded-lg shadow p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Sales & Profit Trend</h2>
        <ResponsiveContainer width="100%" height={400}>
          <LineChart data={reportData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="period" />
            <YAxis />
            <Tooltip formatter={(value) => `₦${value.toLocaleString()}`} />
            <Legend />
            <Line type="monotone" dataKey="sales" stroke="#3b82f6" name="Sales" strokeWidth={2} />
            <Line type="monotone" dataKey="profit" stroke="#10b981" name="Profit" strokeWidth={2} />
          </LineChart>
        </ResponsiveContainer>
      </div>

      {/* Transactions Trend */}
      <div className="bg-white rounded-lg shadow p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Transaction Volume</h2>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={reportData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="period" />
            <YAxis />
            <Tooltip />
            <Bar dataKey="transactions" fill="#f59e0b" name="Transactions" />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Detailed Table */}
      <div className="bg-white rounded-lg shadow overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-50 border-b">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Period</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Sales (₦)</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Profit (₦)</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Transactions</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Avg Value (₦)</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Margin %</th>
            </tr>
          </thead>
          <tbody className="divide-y">
            {reportData.map((report, idx) => (
              <tr key={idx} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  {report.period}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  ₦{report.sales.toLocaleString()}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm font-semibold text-green-600">
                  ₦{report.profit.toLocaleString()}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {report.transactions}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  ₦{(report.sales / report.transactions).toFixed(0)}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  {((report.profit / report.sales) * 100).toFixed(1)}%
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
