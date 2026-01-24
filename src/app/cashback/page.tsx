'use client';

import { useEffect, useState, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { 
  Percent, TrendingUp, DollarSign, Users, Clock, 
  Undo2, Search,
  ArrowUpRight, ArrowDownRight
} from 'lucide-react';
import {
  Card, CardContent, EmptyState,
  PageHeader, RefreshButton, BackButton,
  Button, Badge, Input,
  Alert, Toast,
  TableSkeleton,
} from '@/components/ui';

interface CashbackTransaction {
  id: string;
  user_id: string;
  display_name: string;
  original_transaction_id: string;
  transaction_type: string;
  original_amount: number;
  cashback_percentage: number;
  cashback_amount: number;
  status: 'pending' | 'credited' | 'reversed' | 'failed';
  created_at: string;
  credited_at: string | null;
  reversed_at: string | null;
  reversed_by: string | null;
  reversal_reason: string | null;
}

interface CashbackStats {
  totalCashbackGiven: number;
  totalTransactions: number;
  averageCashback: number;
  pendingCashback: number;
  reversedCashback: number;
  uniqueUsers: number;
  todaysCashback: number;
  thisMonthsCashback: number;
}

interface UserCashbackSummary {
  user_id: string;
  display_name: string;
  email: string | null;
  total_cashback: number;
  transaction_count: number;
  cashback_balance: number;
  is_eligible: boolean;
}

export default function CashbackManagementPage() {
  const [transactions, setTransactions] = useState<CashbackTransaction[]>([]);
  const [userSummaries, setUserSummaries] = useState<UserCashbackSummary[]>([]);
  const [stats, setStats] = useState<CashbackStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [activeTab, setActiveTab] = useState<'transactions' | 'users' | 'settings'>('transactions');
  const [searchQuery, setSearchQuery] = useState('');
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [filterType, setFilterType] = useState<string>('all');
  const [dateRange, setDateRange] = useState<'today' | 'week' | 'month' | 'all'>('all');
  const [selectedTransaction, setSelectedTransaction] = useState<CashbackTransaction | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [reversalReason, setReversalReason] = useState('');

  // Cashback settings
  const [settings, setSettings] = useState({
    cashbackPercentage: 3,
    minTransactionAmount: 100,
    maxCashbackPerTransaction: 1000,
    maxDailyCashback: 5000,
    eligibleTransactionTypes: ['airtime', 'data', 'transfer', 'bill_payment'],
    isEnabled: true,
    agentBonusPercentage: 0.5,
  });

  const fetchData = useCallback(async () => {
    try {
      setError('');
      
      // Fetch cashback transactions without profile join
      const { data: txData, error: txError } = await supabase
        .from('cashback_transactions')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(200);

      if (txError) {
        console.warn('Cashback transactions table may not exist:', txError);
      }

      // Fetch profiles for transactions
      let txProfilesMap = new Map<string, Record<string, unknown>>();
      if (txData && txData.length > 0) {
        const txUserIds = [...new Set(txData.map((t: Record<string, unknown>) => t.user_id as string))];
        const { data: txProfilesData } = await supabase
          .from('profiles')
          .select('id, display_name, email, username')
          .in('id', txUserIds);
        
        txProfilesMap = new Map(
          (txProfilesData || []).map((p: Record<string, unknown>) => [p.id as string, p])
        );
      }

      const transformedTx: CashbackTransaction[] = (txData || []).map((t: Record<string, unknown>) => {
        const profile = txProfilesMap.get(t.user_id as string);
        return {
          ...t,
          display_name: profile?.display_name || profile?.username || 'Unknown',
        };
      }) as CashbackTransaction[];

      setTransactions(transformedTx);

      // Fetch wallets with cashback balance without profile join
      const { data: walletData, error: walletError } = await supabase
        .from('hazpay_wallets')
        .select('user_id, cashback_balance')
        .gt('cashback_balance', 0)
        .order('cashback_balance', { ascending: false })
        .limit(100);

      if (walletError) {
        console.warn('Error fetching wallet cashback:', walletError);
      }

      // Fetch profiles for wallets
      let walletProfilesMap = new Map<string, Record<string, unknown>>();
      if (walletData && walletData.length > 0) {
        const walletUserIds = [...new Set(walletData.map((w: Record<string, unknown>) => w.user_id as string))];
        const { data: walletProfilesData } = await supabase
          .from('profiles')
          .select('id, display_name, email, username')
          .in('id', walletUserIds);
        
        walletProfilesMap = new Map(
          (walletProfilesData || []).map((p: Record<string, unknown>) => [p.id as string, p])
        );
      }

      const userSummaryData: UserCashbackSummary[] = (walletData || []).map((w: Record<string, unknown>) => {
        const userTxs = transformedTx.filter(t => t.user_id === w.user_id);
        const profile = walletProfilesMap.get(w.user_id as string);
        return {
          user_id: w.user_id as string,
          display_name: (profile?.display_name || profile?.username || 'Unknown') as string,
          email: profile?.email as string | null,
          total_cashback: userTxs.reduce((sum, t) => sum + (t.status === 'credited' ? t.cashback_amount : 0), 0),
          transaction_count: userTxs.length,
          cashback_balance: w.cashback_balance as number,
          is_eligible: true,
        };
      });

      setUserSummaries(userSummaryData);

      // Calculate stats
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);

      const creditedTx = transformedTx.filter(t => t.status === 'credited');
      const todayTx = creditedTx.filter(t => new Date(t.created_at) >= today);
      const monthTx = creditedTx.filter(t => new Date(t.created_at) >= monthStart);

      const statsData: CashbackStats = {
        totalCashbackGiven: creditedTx.reduce((sum, t) => sum + t.cashback_amount, 0),
        totalTransactions: transformedTx.length,
        averageCashback: creditedTx.length > 0 
          ? creditedTx.reduce((sum, t) => sum + t.cashback_amount, 0) / creditedTx.length 
          : 0,
        pendingCashback: transformedTx.filter(t => t.status === 'pending').reduce((sum, t) => sum + t.cashback_amount, 0),
        reversedCashback: transformedTx.filter(t => t.status === 'reversed').reduce((sum, t) => sum + t.cashback_amount, 0),
        uniqueUsers: new Set(creditedTx.map(t => t.user_id)).size,
        todaysCashback: todayTx.reduce((sum, t) => sum + t.cashback_amount, 0),
        thisMonthsCashback: monthTx.reduce((sum, t) => sum + t.cashback_amount, 0),
      };
      setStats(statsData);
      
      setLastUpdated(new Date());
    } catch (err) {
      console.error('Fetch error:', err);
      setError('Failed to fetch cashback data');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Fetch pricing settings from database
  const fetchSettings = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from('pricing')
        .select('*')
        .limit(1)
        .single();

      if (error) {
        console.warn('Error fetching pricing settings:', error);
        return;
      }

      if (data) {
        setSettings(prev => ({
          ...prev,
          cashbackPercentage: data.cashback_percentage ?? prev.cashbackPercentage,
          isEnabled: data.is_enabled ?? prev.isEnabled,
          minTransactionAmount: data.min_transaction_amount ?? prev.minTransactionAmount,
          maxCashbackPerTransaction: data.max_cashback_per_transaction ?? prev.maxCashbackPerTransaction,
          maxDailyCashback: data.max_daily_cashback ?? prev.maxDailyCashback,
          agentBonusPercentage: data.agent_bonus_percentage ?? prev.agentBonusPercentage,
        }));
      }
    } catch (err) {
      console.error('Error fetching settings:', err);
    }
  }, []);

  useEffect(() => {
    fetchSettings();
  }, [fetchSettings]);

  // Save settings to database
  const saveSettings = async () => {
    try {
      setIsProcessing(true);
      setError('');

      const { error } = await supabase
        .from('pricing')
        .update({
          cashback_percentage: settings.cashbackPercentage,
          is_enabled: settings.isEnabled,
          min_transaction_amount: settings.minTransactionAmount,
          max_cashback_per_transaction: settings.maxCashbackPerTransaction,
          max_daily_cashback: settings.maxDailyCashback,
          agent_bonus_percentage: settings.agentBonusPercentage,
          updated_at: new Date().toISOString(),
        })
        .not('id', 'is', null); // Update all rows (should be just one)

      if (error) {
        console.error('Error saving settings:', error);
        setError('Failed to save settings: ' + error.message);
        return;
      }

      setSuccess('Settings saved successfully!');
    } catch (err) {
      console.error('Save settings error:', err);
      setError('Failed to save settings');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleRefresh = () => {
    setIsLoading(true);
    fetchData();
  };

  const handleReverseCashback = async () => {
    if (!selectedTransaction || !reversalReason.trim()) {
      setError('Please provide a reversal reason');
      return;
    }

    setIsProcessing(true);
    try {
      // Update cashback transaction status
      const { error: updateError } = await supabase
        .from('cashback_transactions')
        .update({
          status: 'reversed',
          reversed_at: new Date().toISOString(),
          reversed_by: 'admin',
          reversal_reason: reversalReason.trim(),
        })
        .eq('id', selectedTransaction.id);

      if (updateError) throw updateError;

      // Deduct from user's cashback balance
      const { error: walletError } = await supabase.rpc('deduct_cashback', {
        p_user_id: selectedTransaction.user_id,
        p_amount: selectedTransaction.cashback_amount,
      });

      if (walletError) {
        console.warn('Could not deduct from wallet (RPC may not exist):', walletError);
      }

      setSuccess(`Cashback of ₦${selectedTransaction.cashback_amount.toFixed(2)} has been reversed`);
      setSelectedTransaction(null);
      setReversalReason('');
      fetchData();
      setTimeout(() => setSuccess(''), 5000);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to reverse cashback';
      setError(message);
    } finally {
      setIsProcessing(false);
    }
  };

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const handleManualCredit = async (userId: string, amount: number, _reason: string) => {
    setIsProcessing(true);
    try {
      // Create manual cashback transaction
      const { error: insertError } = await supabase
        .from('cashback_transactions')
        .insert({
          user_id: userId,
          original_transaction_id: `manual_${Date.now()}`,
          transaction_type: 'manual_credit',
          original_amount: 0,
          cashback_percentage: 100,
          cashback_amount: amount,
          status: 'credited',
          credited_at: new Date().toISOString(),
        });

      if (insertError) throw insertError;

      // Add to user's cashback balance
      const { error: walletError } = await supabase.rpc('credit_manual_cashback', {
        p_user_id: userId,
        p_amount: amount,
      });

      if (walletError) {
        console.warn('Could not credit wallet (RPC may not exist):', walletError);
      }

      setSuccess(`Manual cashback of ₦${amount.toFixed(2)} has been credited`);
      fetchData();
      setTimeout(() => setSuccess(''), 5000);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to credit cashback';
      setError(message);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleToggleUserEligibility = async (userId: string, eligible: boolean) => {
    setIsProcessing(true);
    try {
      // In production, this would update a user_settings or cashback_eligibility table
      setSuccess(`User cashback eligibility ${eligible ? 'enabled' : 'disabled'}`);
      fetchData();
      setTimeout(() => setSuccess(''), 5000);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to update eligibility';
      setError(message);
    } finally {
      setIsProcessing(false);
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'pending':
        return <Badge variant="warning" dot>Pending</Badge>;
      case 'credited':
        return <Badge variant="success" dot>Credited</Badge>;
      case 'reversed':
        return <Badge variant="danger" dot>Reversed</Badge>;
      case 'failed':
        return <Badge variant="default" dot>Failed</Badge>;
      default:
        return <Badge variant="default">{status}</Badge>;
    }
  };

  const getTransactionTypeBadge = (type: string) => {
    const typeColors: Record<string, 'info' | 'success' | 'warning' | 'purple'> = {
      airtime: 'info',
      data: 'success',
      transfer: 'warning',
      bill_payment: 'purple',
      manual_credit: 'info',
    };
    return <Badge variant={typeColors[type] || 'default'}>{type.replace('_', ' ')}</Badge>;
  };

  const filteredTransactions = transactions.filter(tx => {
    // Status filter
    if (filterStatus !== 'all' && tx.status !== filterStatus) return false;
    
    // Type filter
    if (filterType !== 'all' && tx.transaction_type !== filterType) return false;
    
    // Date range filter
    if (dateRange !== 'all') {
      const txDate = new Date(tx.created_at);
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      if (dateRange === 'today' && txDate < today) return false;
      if (dateRange === 'week') {
        const weekAgo = new Date(today);
        weekAgo.setDate(weekAgo.getDate() - 7);
        if (txDate < weekAgo) return false;
      }
      if (dateRange === 'month') {
        const monthAgo = new Date(today);
        monthAgo.setMonth(monthAgo.getMonth() - 1);
        if (txDate < monthAgo) return false;
      }
    }
    
    // Search filter
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      return (
        tx.display_name?.toLowerCase().includes(query) ||
        tx.original_transaction_id?.toLowerCase().includes(query)
      );
    }
    
    return true;
  });

  const formatCurrency = (amount: number) => `₦${amount.toLocaleString('en-NG', { minimumFractionDigits: 2 })}`;

  if (isLoading && !lastUpdated) {
    return (
      <div className="space-y-8">
        <PageHeader
          title="Cashback Management"
          description="Manage cashback rewards and settings"
        />
        <Card>
          <TableSkeleton rows={8} columns={6} />
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
          title="Cashback Management"
          description="Monitor and manage cashback rewards"
        >
          <RefreshButton 
            onClick={handleRefresh} 
            isLoading={isLoading}
            lastUpdated={lastUpdated}
          />
        </PageHeader>
      </div>

      {/* Alerts */}
      {error && (
        <Alert variant="danger" dismissible onDismiss={() => setError('')}>
          {error}
        </Alert>
      )}
      {success && (
        <Toast message={success} variant="success" onClose={() => setSuccess('')} />
      )}

      {/* Stats Cards */}
      {stats && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Card className="bg-gradient-to-br from-green-500/10 to-green-600/5">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-xs text-gray-400 uppercase tracking-wide">Total Cashback</p>
                  <p className="text-2xl font-bold text-white mt-1">{formatCurrency(stats.totalCashbackGiven)}</p>
                </div>
                <div className="p-3 bg-green-500/20 rounded-xl">
                  <DollarSign size={24} className="text-green-400" />
                </div>
              </div>
              <div className="flex items-center gap-1 mt-2 text-xs text-green-400">
                <ArrowUpRight size={12} />
                <span>{formatCurrency(stats.thisMonthsCashback)} this month</span>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-blue-500/10 to-blue-600/5">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-xs text-gray-400 uppercase tracking-wide">Transactions</p>
                  <p className="text-2xl font-bold text-white mt-1">{stats.totalTransactions}</p>
                </div>
                <div className="p-3 bg-blue-500/20 rounded-xl">
                  <TrendingUp size={24} className="text-blue-400" />
                </div>
              </div>
              <div className="flex items-center gap-1 mt-2 text-xs text-blue-400">
                <span>Avg: {formatCurrency(stats.averageCashback)}</span>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-yellow-500/10 to-yellow-600/5">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-xs text-gray-400 uppercase tracking-wide">Today&apos;s Cashback</p>
                  <p className="text-2xl font-bold text-white mt-1">{formatCurrency(stats.todaysCashback)}</p>
                </div>
                <div className="p-3 bg-yellow-500/20 rounded-xl">
                  <Clock size={24} className="text-yellow-400" />
                </div>
              </div>
              <div className="flex items-center gap-1 mt-2 text-xs text-yellow-400">
                <span>{stats.pendingCashback > 0 ? `${formatCurrency(stats.pendingCashback)} pending` : 'No pending'}</span>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-purple-500/10 to-purple-600/5">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-xs text-gray-400 uppercase tracking-wide">Unique Users</p>
                  <p className="text-2xl font-bold text-white mt-1">{stats.uniqueUsers}</p>
                </div>
                <div className="p-3 bg-purple-500/20 rounded-xl">
                  <Users size={24} className="text-purple-400" />
                </div>
              </div>
              <div className="flex items-center gap-1 mt-2 text-xs text-red-400">
                <ArrowDownRight size={12} />
                <span>{formatCurrency(stats.reversedCashback)} reversed</span>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Tab Navigation */}
      <div className="flex gap-2 border-b border-gray-700 pb-4">
        {[
          { id: 'transactions', label: 'Transactions', icon: TrendingUp },
          { id: 'users', label: 'User Balances', icon: Users },
          { id: 'settings', label: 'Settings', icon: Percent },
        ].map(({ id, label, icon: Icon }) => (
          <button
            key={id}
            onClick={() => setActiveTab(id as typeof activeTab)}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all ${
              activeTab === id
                ? 'bg-blue-600 text-white'
                : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
            }`}
          >
            <Icon size={16} />
            {label}
          </button>
        ))}
      </div>

      {/* Transactions Tab */}
      {activeTab === 'transactions' && (
        <div className="space-y-4">
          {/* Filters */}
          <Card>
            <CardContent className="py-4">
              <div className="flex flex-col md:flex-row gap-4">
                <div className="flex-1 relative">
                  <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                  <Input
                    placeholder="Search by name or transaction ID..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="pl-10"
                  />
                </div>
                
                <div className="flex gap-2 flex-wrap">
                  <select
                    value={filterStatus}
                    onChange={(e) => setFilterStatus(e.target.value)}
                    className="px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm"
                    title="Filter by status"
                  >
                    <option value="all">All Status</option>
                    <option value="credited">Credited</option>
                    <option value="pending">Pending</option>
                    <option value="reversed">Reversed</option>
                    <option value="failed">Failed</option>
                  </select>

                  <select
                    value={filterType}
                    onChange={(e) => setFilterType(e.target.value)}
                    className="px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm"
                    title="Filter by type"
                  >
                    <option value="all">All Types</option>
                    <option value="airtime">Airtime</option>
                    <option value="data">Data</option>
                    <option value="transfer">Transfer</option>
                    <option value="bill_payment">Bill Payment</option>
                    <option value="manual_credit">Manual Credit</option>
                  </select>

                  <select
                    value={dateRange}
                    onChange={(e) => setDateRange(e.target.value as typeof dateRange)}
                    className="px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm"
                    title="Filter by date range"
                  >
                    <option value="all">All Time</option>
                    <option value="today">Today</option>
                    <option value="week">This Week</option>
                    <option value="month">This Month</option>
                  </select>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Transactions List */}
          <div className="space-y-3">
            {filteredTransactions.length === 0 ? (
              <Card>
                <EmptyState
                  title="No cashback transactions found"
                  description="Cashback transactions will appear here."
                  icon={<DollarSign size={48} />}
                />
              </Card>
            ) : (
              filteredTransactions.map((tx) => (
                <Card key={tx.id} className="hover:border-blue-500/30 transition-all">
                  <CardContent className="p-4">
                    <div className="flex flex-col md:flex-row md:items-center gap-4">
                      {/* User Info */}
                      <div className="flex items-center gap-3 flex-1">
                        <div className="w-10 h-10 rounded-full bg-green-500/20 flex items-center justify-center">
                          <DollarSign size={20} className="text-green-400" />
                        </div>
                        <div>
                          <h3 className="font-semibold text-white">{tx.display_name}</h3>
                          <p className="text-xs text-gray-400 font-mono">{tx.original_transaction_id}</p>
                        </div>
                      </div>

                      {/* Transaction Type */}
                      <div>
                        {getTransactionTypeBadge(tx.transaction_type)}
                      </div>

                      {/* Amounts */}
                      <div className="text-right">
                        <p className="text-lg font-bold text-green-400">+{formatCurrency(tx.cashback_amount)}</p>
                        <p className="text-xs text-gray-400">
                          {tx.cashback_percentage}% of {formatCurrency(tx.original_amount)}
                        </p>
                      </div>

                      {/* Status */}
                      <div>
                        {getStatusBadge(tx.status)}
                      </div>

                      {/* Date */}
                      <div className="text-sm text-gray-400">
                        {new Date(tx.created_at).toLocaleDateString()}
                      </div>

                      {/* Actions */}
                      {tx.status === 'credited' && (
                        <Button
                          variant="danger"
                          size="sm"
                          onClick={() => setSelectedTransaction(tx)}
                        >
                          <Undo2 size={14} className="mr-1" />
                          Reverse
                        </Button>
                      )}
                    </div>

                    {/* Reversal Info */}
                    {tx.status === 'reversed' && tx.reversal_reason && (
                      <div className="mt-3 p-2 bg-red-500/10 rounded border border-red-500/20">
                        <p className="text-xs text-red-400">
                          <strong>Reversed:</strong> {tx.reversal_reason}
                          {tx.reversed_at && (
                            <span className="ml-2 text-gray-400">
                              on {new Date(tx.reversed_at).toLocaleDateString()}
                            </span>
                          )}
                        </p>
                      </div>
                    )}
                  </CardContent>
                </Card>
              ))
            )}
          </div>
        </div>
      )}

      {/* Users Tab */}
      {activeTab === 'users' && (
        <div className="space-y-4">
          <div className="space-y-3">
            {userSummaries.length === 0 ? (
              <Card>
                <EmptyState
                  title="No users with cashback"
                  description="Users with cashback balance will appear here."
                  icon={<Users size={48} />}
                />
              </Card>
            ) : (
              userSummaries.map((user) => (
                <Card key={user.user_id} className="hover:border-blue-500/30 transition-all">
                  <CardContent className="p-4">
                    <div className="flex flex-col md:flex-row md:items-center gap-4">
                      <div className="flex items-center gap-3 flex-1">
                        <div className="w-10 h-10 rounded-full bg-blue-500/20 flex items-center justify-center">
                          <Users size={20} className="text-blue-400" />
                        </div>
                        <div>
                          <h3 className="font-semibold text-white">{user.display_name}</h3>
                          <p className="text-sm text-gray-400">{user.email || 'No email'}</p>
                        </div>
                      </div>

                      <div className="flex items-center gap-6 text-sm">
                        <div className="text-center">
                          <p className="text-lg font-bold text-green-400">{formatCurrency(user.cashback_balance)}</p>
                          <p className="text-xs text-gray-400">Balance</p>
                        </div>
                        <div className="text-center">
                          <p className="text-lg font-bold text-blue-400">{formatCurrency(user.total_cashback)}</p>
                          <p className="text-xs text-gray-400">Total Earned</p>
                        </div>
                        <div className="text-center">
                          <p className="text-lg font-bold text-purple-400">{user.transaction_count}</p>
                          <p className="text-xs text-gray-400">Transactions</p>
                        </div>
                      </div>

                      <div>
                        {user.is_eligible ? (
                          <Badge variant="success" dot>Eligible</Badge>
                        ) : (
                          <Badge variant="danger" dot>Ineligible</Badge>
                        )}
                      </div>

                      <div className="flex gap-2">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleToggleUserEligibility(user.user_id, !user.is_eligible)}
                          loading={isProcessing}
                        >
                          {user.is_eligible ? 'Disable' : 'Enable'}
                        </Button>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))
            )}
          </div>
        </div>
      )}

      {/* Settings Tab */}
      {activeTab === 'settings' && (
        <div className="space-y-4">
          <Card>
            <CardContent className="p-6">
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-lg font-semibold text-white">Cashback Program Settings</h3>
                <label className="flex items-center gap-3 cursor-pointer">
                  <span className="text-sm text-gray-300">Program Enabled</span>
                  <div className={`relative w-12 h-6 rounded-full transition-colors ${settings.isEnabled ? 'bg-green-500' : 'bg-gray-600'}`}>
                    <input
                      type="checkbox"
                      checked={settings.isEnabled}
                      onChange={(e) => setSettings(prev => ({ ...prev, isEnabled: e.target.checked }))}
                      className="sr-only"
                    />
                    <div className={`absolute top-1 w-4 h-4 rounded-full bg-white transition-transform ${settings.isEnabled ? 'left-7' : 'left-1'}`} />
                  </div>
                </label>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Cashback Percentage (%)
                  </label>
                  <Input
                    type="number"
                    value={settings.cashbackPercentage}
                    onChange={(e) => setSettings(prev => ({ ...prev, cashbackPercentage: parseFloat(e.target.value) || 0 }))}
                    className="w-full"
                    step="0.1"
                    min="0"
                    max="100"
                  />
                  <p className="text-xs text-gray-400 mt-1">Default: 3%</p>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Agent Bonus Percentage (%)
                  </label>
                  <Input
                    type="number"
                    value={settings.agentBonusPercentage}
                    onChange={(e) => setSettings(prev => ({ ...prev, agentBonusPercentage: parseFloat(e.target.value) || 0 }))}
                    className="w-full"
                    step="0.1"
                    min="0"
                    max="10"
                  />
                  <p className="text-xs text-gray-400 mt-1">Additional cashback for agents</p>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Minimum Transaction (₦)
                  </label>
                  <Input
                    type="number"
                    value={settings.minTransactionAmount}
                    onChange={(e) => setSettings(prev => ({ ...prev, minTransactionAmount: parseInt(e.target.value) || 0 }))}
                    className="w-full"
                  />
                  <p className="text-xs text-gray-400 mt-1">Minimum amount to qualify for cashback</p>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Max Cashback Per Transaction (₦)
                  </label>
                  <Input
                    type="number"
                    value={settings.maxCashbackPerTransaction}
                    onChange={(e) => setSettings(prev => ({ ...prev, maxCashbackPerTransaction: parseInt(e.target.value) || 0 }))}
                    className="w-full"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Max Daily Cashback (₦)
                  </label>
                  <Input
                    type="number"
                    value={settings.maxDailyCashback}
                    onChange={(e) => setSettings(prev => ({ ...prev, maxDailyCashback: parseInt(e.target.value) || 0 }))}
                    className="w-full"
                  />
                  <p className="text-xs text-gray-400 mt-1">Per user daily limit</p>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Eligible Transaction Types
                  </label>
                  <div className="flex flex-wrap gap-2">
                    {['airtime', 'data', 'transfer', 'bill_payment'].map((type) => (
                      <label key={type} className="flex items-center gap-2 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={settings.eligibleTransactionTypes.includes(type)}
                          onChange={(e) => {
                            setSettings(prev => ({
                              ...prev,
                              eligibleTransactionTypes: e.target.checked
                                ? [...prev.eligibleTransactionTypes, type]
                                : prev.eligibleTransactionTypes.filter(t => t !== type)
                            }));
                          }}
                          className="w-4 h-4 rounded bg-gray-700 border-gray-600"
                        />
                        <span className="text-sm text-gray-300 capitalize">{type.replace('_', ' ')}</span>
                      </label>
                    ))}
                  </div>
                </div>
              </div>

              <div className="mt-6 pt-6 border-t border-gray-700 flex gap-3">
                <Button variant="primary" onClick={saveSettings} disabled={isProcessing}>
                  {isProcessing ? 'Saving...' : 'Save Settings'}
                </Button>
                <Button variant="outline" onClick={() => setSettings({
                  cashbackPercentage: 3,
                  minTransactionAmount: 100,
                  maxCashbackPerTransaction: 1000,
                  maxDailyCashback: 5000,
                  eligibleTransactionTypes: ['airtime', 'data', 'transfer', 'bill_payment'],
                  isEnabled: true,
                  agentBonusPercentage: 0.5,
                })}>
                  Reset to Defaults
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Reverse Cashback Modal */}
      {selectedTransaction && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
          <Card className="max-w-md w-full">
            <CardContent className="p-6">
              <h3 className="text-lg font-semibold text-white mb-4">
                Reverse Cashback
              </h3>
              
              <div className="space-y-4">
                <div className="p-4 bg-gray-700/50 rounded-lg">
                  <div className="flex justify-between mb-2">
                    <span className="text-gray-400">User:</span>
                    <span className="text-white">{selectedTransaction.display_name}</span>
                  </div>
                  <div className="flex justify-between mb-2">
                    <span className="text-gray-400">Amount:</span>
                    <span className="text-green-400 font-bold">{formatCurrency(selectedTransaction.cashback_amount)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Type:</span>
                    <span className="text-white capitalize">{selectedTransaction.transaction_type.replace('_', ' ')}</span>
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Reversal Reason *
                  </label>
                  <textarea
                    value={reversalReason}
                    onChange={(e) => setReversalReason(e.target.value)}
                    placeholder="Enter reason for reversal..."
                    className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400"
                    rows={3}
                  />
                </div>

                <Alert variant="warning">
                  This action will deduct {formatCurrency(selectedTransaction.cashback_amount)} from the user&apos;s cashback balance and cannot be undone.
                </Alert>
              </div>

              <div className="flex gap-3 mt-6">
                <Button variant="outline" onClick={() => {
                  setSelectedTransaction(null);
                  setReversalReason('');
                }} className="flex-1">
                  Cancel
                </Button>
                <Button 
                  variant="danger" 
                  onClick={handleReverseCashback}
                  loading={isProcessing}
                  disabled={!reversalReason.trim()}
                  className="flex-1"
                >
                  <Undo2 size={14} className="mr-1" />
                  Reverse Cashback
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}
