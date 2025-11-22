'use client';

import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
import { Search, Download } from 'lucide-react';
import Papa from 'papaparse';
import { Card, StatCard } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Button';

interface Loan {
  id: string;
  user_id: string;
  user_email?: string;
  user_name?: string;
  amount: number;
  status: 'pending' | 'approved' | 'active' | 'repaid' | 'defaulted';
  issued_date: string;
  repaid_date?: string;
  created_at: string;
  updated_at: string;
}

export default function LoansPage() {
  const [loans, setLoans] = useState<Loan[]>([]);
  const [filteredLoans, setFilteredLoans] = useState<Loan[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState<'all' | Loan['status']>('all');

  useEffect(() => {
    fetchLoans();
  }, []);

  useEffect(() => {
    applyFilters();
  }, [loans, searchTerm, filterStatus]);

  const fetchLoans = async () => {
    try {
      const { data, error } = await supabase
        .from('loans')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) {
        console.error('Supabase error:', error);
        // For now, show empty state - table doesn't exist yet
        setLoans([]);
      } else {
        setLoans(data || []);
      }
    } catch (error) {
      console.error('Failed to fetch loans:', error);
      setLoans([]);
    } finally {
      setIsLoading(false);
    }
  };

  const applyFilters = () => {
    let filtered = [...loans];

    // Search filter
    if (searchTerm) {
      const term = searchTerm.toLowerCase();
      filtered = filtered.filter(
        (loan) =>
          loan.user_email?.toLowerCase().includes(term) ||
          loan.user_name?.toLowerCase().includes(term) ||
          loan.user_id?.includes(term) ||
          loan.id?.includes(term)
      );
    }

    // Status filter
    if (filterStatus !== 'all') {
      filtered = filtered.filter((loan) => loan.status === filterStatus);
    }

    setFilteredLoans(filtered);
  };

  const getStatusBadgeColor = (status: Loan['status']) => {
    const colors: Record<Loan['status'], 'blue' | 'green' | 'amber' | 'red' | 'purple'> = {
      pending: 'amber',
      approved: 'blue',
      active: 'purple',
      repaid: 'green',
      defaulted: 'red',
    };
    return colors[status] || 'blue';
  };

  const exportCSV = () => {
    const csv = Papa.unparse(
      filteredLoans.map((loan) => ({
        'Loan ID': loan.id,
        'User Email': loan.user_email || '-',
        'User Name': loan.user_name || '-',
        'Amount (₦)': loan.amount,
        Status: loan.status,
        'Issued Date': new Date(loan.issued_date).toLocaleDateString(),
        'Repaid Date': loan.repaid_date ? new Date(loan.repaid_date).toLocaleDateString() : '-',
      }))
    );

    const element = document.createElement('a');
    element.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv);
    element.download = `loans-${new Date().toISOString().split('T')[0]}.csv`;
    element.click();
  };

  const stats = {
    totalLoans: loans.length,
    activeLoans: loans.filter((l) => l.status === 'active').length,
    totalAmount: loans.reduce((sum, l) => sum + l.amount, 0),
    repaidAmount: loans
      .filter((l) => l.status === 'repaid')
      .reduce((sum, l) => sum + l.amount, 0),
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-lg text-gray-600">Loading loans...</div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Loans Management</h1>
        <p className="text-gray-600 mt-2">Track user loans and repayment status</p>
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard label="Total Loans" value={stats.totalLoans} color="blue" />
        <StatCard label="Active Loans" value={stats.activeLoans} color="purple" />
        <StatCard label="Total Loan Amount" value={stats.totalAmount} color="amber" />
        <StatCard label="Total Repaid" value={stats.repaidAmount} color="green" />
      </div>

      {/* Controls */}
      <Card className="p-4 space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          {/* Search */}
          <div className="relative md:col-span-2">
            <Search size={18} className="absolute left-3 top-3 text-gray-400" />
            <input
              type="text"
              placeholder="Search by email, name, or user ID..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {/* Status Filter */}
          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value as any)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
          >
            <option value="all">All Status</option>
            <option value="pending">Pending</option>
            <option value="approved">Approved</option>
            <option value="active">Active</option>
            <option value="repaid">Repaid</option>
            <option value="defaulted">Defaulted</option>
          </select>

          {/* Export */}
          <button
            onClick={exportCSV}
            className="flex items-center justify-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
          >
            <Download size={18} />
            Export CSV
          </button>
        </div>
      </Card>

      {/* Loans Table */}
      <div className="bg-white rounded-lg shadow overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-50 border-b">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">User</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Loan Amount (₦)</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Status</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Issued Date</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Repaid Date</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Loan ID</th>
            </tr>
          </thead>
          <tbody className="divide-y">
            {filteredLoans.length > 0 ? (
              filteredLoans.map((loan) => (
                <tr key={loan.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div>
                      <p className="text-sm font-medium text-gray-900">{loan.user_name || 'Unknown'}</p>
                      <p className="text-xs text-gray-600">{loan.user_email || '-'}</p>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-semibold text-gray-900">
                    ₦{loan.amount.toLocaleString()}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <Badge color={getStatusBadgeColor(loan.status)}>
                      {loan.status.charAt(0).toUpperCase() + loan.status.slice(1)}
                    </Badge>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {new Date(loan.issued_date).toLocaleDateString()}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {loan.repaid_date ? new Date(loan.repaid_date).toLocaleDateString() : '-'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600 font-mono">
                    {loan.id.substring(0, 8)}...
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={6} className="px-6 py-12 text-center text-gray-600">
                  <p className="text-lg font-medium">No loans found</p>
                  <p className="text-sm text-gray-500 mt-1">
                    {loans.length === 0 ? 'The loans table may not exist yet in your database.' : 'Try adjusting your filters.'}
                  </p>
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Info Box */}
      {loans.length === 0 && (
        <Card className="bg-blue-50 border-blue-200 border p-4">
          <p className="text-blue-900 text-sm">
            💡 <strong>Note:</strong> To start tracking loans, create a <code className="bg-blue-100 px-2 py-1 rounded">loans</code> table in your Supabase database with columns: id, user_id, amount, status, issued_date, repaid_date, created_at, updated_at.
          </p>
        </Card>
      )}
    </div>
  );
}
