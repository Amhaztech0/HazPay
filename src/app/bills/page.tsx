'use client';

import { AdminProtection } from '@/components/AdminProtection';
import { useEffect, useState, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { BillPayment } from '@/types';
import { Zap, Tv, Wifi, Phone, Receipt } from 'lucide-react';
import Papa from 'papaparse';
import {
  Card, StatCard, EmptyState,
  PageHeader, RefreshButton, ExportButton, FilterBar, ResultsCount,
  SearchInput, Select, BackButton,
  TableSkeleton, StatusCell, CurrencyCell, DateCell, Alert,
} from '@/components/ui';
import { formatDate } from '@/lib/theme';

type FilterType = 'all' | 'electricity' | 'cable' | 'internet' | 'airtime';
type FilterStatus = 'all' | 'success' | 'failed' | 'pending';

const TYPE_OPTIONS = [
  { value: 'all', label: 'All Types' },
  { value: 'electricity', label: 'Electricity' },
  { value: 'cable', label: 'Cable TV' },
  { value: 'internet', label: 'Internet' },
  { value: 'airtime', label: 'Airtime' },
];

const STATUS_OPTIONS = [
  { value: 'all', label: 'All Status' },
  { value: 'success', label: 'Success' },
  { value: 'pending', label: 'Pending' },
  { value: 'failed', label: 'Failed' },
];

export default function BillPaymentsPage() {
  const [bills, setBills] = useState<BillPayment[]>([]);
  const [filteredBills, setFilteredBills] = useState<BillPayment[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterType, setFilterType] = useState<FilterType>('all');
  const [filterStatus, setFilterStatus] = useState<FilterStatus>('all');
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [stats, setStats] = useState({
    total: 0,
    electricity: 0,
    cable: 0,
    internet: 0,
    airtime: 0,
    totalAmount: 0,
  });

  const fetchBills = useCallback(async () => {
    try {
      setError(null);
      const { data, error } = await supabase
        .from('bill_payments')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(1000);

      // Handle RLS permission errors gracefully - treat as empty data
      if (error) {
        // Check if it's a permission/RLS error
        const errorMsg = error.message?.toLowerCase() || '';
        if (errorMsg.includes('permission') || errorMsg.includes('policy') || error.code === 'PGRST301') {
          console.warn('Bill payments: Admin access not configured. Please run FIX_ADMIN_RLS_POLICIES.sql');
          setBills([]);
          setStats({ total: 0, electricity: 0, cable: 0, internet: 0, airtime: 0, totalAmount: 0 });
          setLastUpdated(new Date());
          return;
        }
        throw error;
      }

      const billData: BillPayment[] = data || [];
      setBills(billData);

      // Calculate stats
      const totalAmount = billData.reduce((sum: number, bill: BillPayment) => sum + (bill.amount || 0), 0);
      setStats({
        total: billData.length,
        electricity: billData.filter((b: BillPayment) => b.bill_type === 'electricity').length,
        cable: billData.filter((b: BillPayment) => b.bill_type === 'cable').length,
        internet: billData.filter((b: BillPayment) => b.bill_type === 'internet').length,
        airtime: billData.filter((b: BillPayment) => b.bill_type === 'airtime').length,
        totalAmount,
      });
      setLastUpdated(new Date());
    } catch (err) {
      console.error('Error fetching bills:', err);
      // Check for network errors vs data errors
      const isNetworkError = err instanceof TypeError || (err as Error)?.message?.includes('fetch');
      setError(isNetworkError 
        ? 'Unable to connect to server. Please check your connection.'
        : 'No bill payment records found. Data will appear once users make bill payments.');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchBills();
    const interval = setInterval(fetchBills, 30000);
    return () => clearInterval(interval);
  }, [fetchBills]);

  useEffect(() => {
    applyFilters();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [bills, searchTerm, filterType, filterStatus]);

  const applyFilters = () => {
    let filtered = [...bills];

    // Search filter
    if (searchTerm) {
      filtered = filtered.filter(
        (bill) =>
          bill.account_number?.toLowerCase().includes(searchTerm.toLowerCase()) ||
          bill.reference?.toLowerCase().includes(searchTerm.toLowerCase()) ||
          bill.provider?.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    // Type filter
    if (filterType !== 'all') {
      filtered = filtered.filter((bill) => bill.bill_type === filterType);
    }

    // Status filter
    if (filterStatus !== 'all') {
      filtered = filtered.filter((bill) => bill.status === filterStatus);
    }

    setFilteredBills(filtered);
  };

  const handleRefresh = () => {
    setIsLoading(true);
    fetchBills();
  };

  const exportCSV = () => {
    const csv = Papa.unparse(
      filteredBills.map((bill) => ({
        Date: formatDate(bill.created_at),
        Type: bill.bill_type,
        Provider: bill.provider,
        'Account Number': bill.account_number,
        Amount: bill.amount,
        Status: bill.status,
        Reference: bill.reference,
      }))
    );
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `bill-payments-${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
  };

  const getBillIcon = (type: string) => {
    const iconProps = { size: 16 };
    switch (type) {
      case 'electricity':
        return <Zap {...iconProps} className="text-[var(--color-warning)]" />;
      case 'cable':
        return <Tv {...iconProps} className="text-[var(--color-accent)]" />;
      case 'internet':
        return <Wifi {...iconProps} className="text-[var(--color-primary)]" />;
      case 'airtime':
        return <Phone {...iconProps} className="text-[var(--color-success)]" />;
      default:
        return <Receipt {...iconProps} className="text-[var(--color-text-muted)]" />;
    }
  };

  if (isLoading && !lastUpdated) {
    return (
      <div className="space-y-6">
        <PageHeader
          title="Bill Payments"
          description="Track electricity, cable, internet, and airtime payments"
        />
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
          {[...Array(6)].map((_, i) => (
            <Card key={i} className="animate-pulse">
              <div className="h-4 bg-[var(--color-gray-200)] rounded w-1/2 mb-2" />
              <div className="h-8 bg-[var(--color-gray-200)] rounded w-3/4" />
            </Card>
          ))}
        </div>
        <Card>
          <TableSkeleton rows={10} columns={7} />
        </Card>
      </div>
    );
  }

  return (
    <AdminProtection>
      <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <BackButton />
        <PageHeader
          title="Bill Payments"
          description="Manage bill payments and transactions"
        >
          <RefreshButton 
            onClick={handleRefresh}
            isLoading={isLoading}
            lastUpdated={lastUpdated}
          />
        </PageHeader>
      </div>

      {/* Error Alert */}
      {error && (
        <Alert variant="danger" title="Error" onDismiss={() => setError(null)}>
          {error}
        </Alert>
      )}

      {/* Stats Cards */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <StatCard 
          label="Total Bills" 
          value={stats.total} 
          icon={<Receipt size={24} />} 
          color="blue"
          isCurrency={false}
        />
        <StatCard 
          label="Electricity" 
          value={stats.electricity} 
          icon={<Zap size={24} />} 
          color="amber"
          isCurrency={false}
        />
        <StatCard 
          label="Cable TV" 
          value={stats.cable} 
          icon={<Tv size={24} />} 
          color="purple"
          isCurrency={false}
        />
        <StatCard 
          label="Internet" 
          value={stats.internet} 
          icon={<Wifi size={24} />} 
          color="blue"
          isCurrency={false}
        />
        <StatCard 
          label="Airtime" 
          value={stats.airtime} 
          icon={<Phone size={24} />} 
          color="green"
          isCurrency={false}
        />
        <StatCard 
          label="Total Amount" 
          value={stats.totalAmount} 
          icon={<Receipt size={24} />} 
          color="purple"
          isCurrency={true}
        />
      </div>

      {/* Filters */}
      <FilterBar>
        <SearchInput
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          placeholder="Search by account, reference, or provider..."
          className="flex-1 min-w-[200px]"
        />

        <Select
          value={filterType}
          onChange={(e) => setFilterType(e.target.value as FilterType)}
          className="w-40"
        >
          {TYPE_OPTIONS.map((opt) => (
            <option key={opt.value} value={opt.value}>{opt.label}</option>
          ))}
        </Select>

        <Select
          value={filterStatus}
          onChange={(e) => setFilterStatus(e.target.value as FilterStatus)}
          className="w-36"
        >
          {STATUS_OPTIONS.map((opt) => (
            <option key={opt.value} value={opt.value}>{opt.label}</option>
          ))}
        </Select>

        <ExportButton onClick={exportCSV} label="Export CSV" />

        <ResultsCount count={filteredBills.length} label="bill" />
      </FilterBar>

      {/* Table */}
      <Card noPadding>
        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th className="table-header">Date</th>
                <th className="table-header">Type</th>
                <th className="table-header">Provider</th>
                <th className="table-header">Account Number</th>
                <th className="table-header">Amount (₦)</th>
                <th className="table-header">Status</th>
                <th className="table-header">Reference</th>
              </tr>
            </thead>
            <tbody>
              {filteredBills.map((bill) => (
                <tr key={bill.id} className="table-row">
                  <DateCell date={bill.created_at} />
                  <td className="table-cell">
                    <div className="flex items-center gap-2">
                      {getBillIcon(bill.bill_type)}
                      <span className="capitalize">{bill.bill_type}</span>
                    </div>
                  </td>
                  <td className="table-cell uppercase font-medium">
                    {bill.provider}
                  </td>
                  <td className="table-cell font-mono">
                    {bill.account_number}
                  </td>
                  <CurrencyCell amount={bill.amount} />
                  <StatusCell status={bill.status} />
                  <td className="table-cell font-mono text-xs text-[var(--color-text-muted)]">
                    {bill.reference}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      {/* Empty State */}
      {filteredBills.length === 0 && !isLoading && (
        <EmptyState
          icon="📄"
          title="No bill payments found"
          description="Try adjusting your search or filter criteria"
        />
      )}
      </div>
    </AdminProtection>
  );
}
