'use client';

import { useEffect, useState, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { Transaction } from '@/types';
import { ChevronUp, ChevronDown } from 'lucide-react';
import Papa from 'papaparse';
import {
  Card, EmptyState,
  PageHeader, RefreshButton, ExportButton, FilterBar, ResultsCount,
  SearchInput, Select, BackButton,
  TableSkeleton, StatusCell, CurrencyCell, DateCell, Alert,
} from '@/components/ui';
import { formatCurrency, formatDate } from '@/lib/theme';

type SortField = 'created_at' | 'amount' | 'profit' | 'status';
type FilterNetwork = 'all' | 'MTN' | 'GLO' | 'AIRTEL' | '9MOBILE';

const NETWORK_OPTIONS = [
  { value: 'all', label: 'All Networks' },
  { value: 'MTN', label: 'MTN' },
  { value: 'AIRTEL', label: 'Airtel' },
  { value: 'GLO', label: 'Glo' },
  { value: '9MOBILE', label: '9Mobile' },
];

export default function TransactionsPage() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [filteredTransactions, setFilteredTransactions] = useState<Transaction[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterNetwork, setFilterNetwork] = useState<FilterNetwork>('all');
  const [sortField, setSortField] = useState<SortField>('created_at');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  const fetchTransactions = useCallback(async () => {
    try {
      setError(null);
      const { data, error } = await supabase
        .from('hazpay_transactions')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(1000);

      if (error) throw error;
      setTransactions(data || []);
      setLastUpdated(new Date());
    } catch (err) {
      console.error('Failed to fetch transactions:', err);
      setError('Failed to load transactions. Please try again.');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchTransactions();
    const interval = setInterval(fetchTransactions, 30000);
    return () => clearInterval(interval);
  }, [fetchTransactions]);

  useEffect(() => {
    applyFiltersAndSort();
  }, [transactions, searchTerm, filterNetwork, sortField, sortOrder]);

  const applyFiltersAndSort = () => {
    let filtered = [...transactions];

    // Search filter
    if (searchTerm) {
      const term = searchTerm.toLowerCase();
      filtered = filtered.filter(
        (tx) =>
          tx.mobile_number?.includes(term) ||
          tx.reference?.toLowerCase().includes(term) ||
          tx.user_id?.includes(term)
      );
    }

    // Network filter
    if (filterNetwork !== 'all') {
      filtered = filtered.filter((tx) => tx.network_name === filterNetwork);
    }

    // Sort
    filtered.sort((a, b) => {
      let aVal = a[sortField];
      let bVal = b[sortField];

      if (aVal === null || aVal === undefined) aVal = 0;
      if (bVal === null || bVal === undefined) bVal = 0;

      if (sortOrder === 'asc') {
        return aVal > bVal ? 1 : -1;
      } else {
        return aVal < bVal ? 1 : -1;
      }
    });

    setFilteredTransactions(filtered);
  };

  const handleSort = (field: SortField) => {
    if (sortField === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortOrder('desc');
    }
  };

  const handleRefresh = () => {
    setIsLoading(true);
    fetchTransactions();
  };

  const exportCSV = () => {
    const csv = Papa.unparse(
      filteredTransactions.map((tx) => ({
        'Transaction ID': tx.id,
        'User ID': tx.user_id,
        Type: tx.type,
        'Mobile Number': tx.mobile_number,
        'Network': tx.network_name,
        'Data Plan': tx.data_capacity,
        'Amount Charged (₦)': tx.sell_price || tx.amount,
        'Cost Price (₦)': tx.cost_price || '-',
        'Profit (₦)': tx.profit || '-',
        Status: tx.status,
        'Reference': tx.reference,
        'Date': formatDate(tx.created_at),
      }))
    );

    const element = document.createElement('a');
    element.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv);
    element.download = `transactions-${new Date().toISOString().split('T')[0]}.csv`;
    element.click();
  };

  const SortHeader = ({ field, label }: { field: SortField; label: string }) => (
    <th
      onClick={() => handleSort(field)}
      className="table-header cursor-pointer hover:bg-[var(--color-gray-100)] transition-colors"
    >
      <div className="flex items-center gap-2">
        {label}
        {sortField === field && (
          sortOrder === 'asc' ? <ChevronUp size={16} /> : <ChevronDown size={16} />
        )}
      </div>
    </th>
  );

  if (isLoading && !lastUpdated) {
    return (
      <div className="space-y-6">
        <PageHeader
          title="Transactions"
          description="Track all user purchases and transactions"
        />
        <Card>
          <TableSkeleton rows={10} columns={9} />
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <BackButton />
        <PageHeader
          title="Transactions"
          description="Track all user purchases and transactions"
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

      {/* Controls */}
      <FilterBar>
        <SearchInput
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          placeholder="Search by phone, reference..."
          className="md:w-64"
        />

        <Select
          value={filterNetwork}
          onChange={(e) => setFilterNetwork(e.target.value as FilterNetwork)}
          className="md:w-48"
        >
          {NETWORK_OPTIONS.map((opt) => (
            <option key={opt.value} value={opt.value}>{opt.label}</option>
          ))}
        </Select>

        <ExportButton onClick={exportCSV} label="Export CSV" />
        
        <ResultsCount 
          count={filteredTransactions.length} 
          label="transaction"
        />
      </FilterBar>

      {/* Table */}
      <Card noPadding>
        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <SortHeader field="created_at" label="Date" />
                <th className="table-header">Mobile Number</th>
                <th className="table-header">Network</th>
                <th className="table-header">Plan</th>
                <SortHeader field="amount" label="Amount (₦)" />
                <th className="table-header">Cost (₦)</th>
                <SortHeader field="profit" label="Profit (₦)" />
                <SortHeader field="status" label="Status" />
                <th className="table-header">Reference</th>
              </tr>
            </thead>
            <tbody>
              {filteredTransactions.map((tx) => (
                <tr key={tx.id} className="table-row">
                  <DateCell date={tx.created_at} />
                  <td className="table-cell">{tx.mobile_number}</td>
                  <td className="table-cell">
                    <span className="font-medium">{tx.network_name}</span>
                  </td>
                  <td className="table-cell">{tx.data_capacity || '-'}</td>
                  <CurrencyCell amount={tx.sell_price || tx.amount} />
                  <td className="table-cell text-[var(--color-text-secondary)]">
                    {tx.cost_price ? formatCurrency(tx.cost_price) : '-'}
                  </td>
                  <td className="table-cell font-medium text-[var(--color-success)]">
                    {tx.profit ? formatCurrency(tx.profit) : '-'}
                  </td>
                  <StatusCell status={tx.status} />
                  <td className="table-cell text-[var(--color-text-muted)] text-xs font-mono">
                    {tx.reference}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      {/* Empty State */}
      {filteredTransactions.length === 0 && !isLoading && (
        <EmptyState
          icon="📊"
          title="No transactions found"
          description="Try adjusting your search or filter criteria"
        />
      )}
    </div>
  );
}
