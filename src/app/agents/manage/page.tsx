'use client';

import { AdminProtection } from '@/components/AdminProtection';
import { useEffect, useState, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import Link from 'next/link';
import { 
  User, Shield, Ban, RotateCcw, TrendingUp, DollarSign, 
  Calendar, MapPin, RefreshCw, FileText, Users 
} from 'lucide-react';
import {
  Card, CardContent, EmptyState, StatCard,
  PageHeader, RefreshButton, BackButton,
  Button, Badge, Input,
  Alert, Toast,
  TableSkeleton,
} from '@/components/ui';
import { formatCurrency } from '@/lib/theme';

interface Agent {
  id: string;
  user_id: string;
  application_id: string | null;
  full_name: string;
  phone_number: string | null;
  email: string | null;
  state: string | null;
  town: string | null;
  business_name: string | null;
  status: 'active' | 'suspended' | 'revoked';
  tier: 'standard' | 'silver' | 'gold' | 'platinum';
  commission_rate: number;
  custom_discount: number;
  total_sales: number;
  total_profit: number;
  total_transactions: number;
  transactions_today: number;
  sales_today: number;
  profit_today: number;
  last_transaction_at: string | null;
  created_at: string;
  updated_at: string;
  // Joined data
  username?: string;
  avatar_url?: string;
}

export default function AgentManagementPage() {
  const [agents, setAgents] = useState<Agent[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [selectedAgent, setSelectedAgent] = useState<Agent | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [suspensionReason, setSuspensionReason] = useState('');
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [filterTier, setFilterTier] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState('');

  // Stats
  const [stats, setStats] = useState({
    totalAgents: 0,
    activeAgents: 0,
    totalSales: 0,
    totalProfit: 0,
  });

  const fetchAgents = useCallback(async () => {
    try {
      setError('');
      
      // Fetch agents without profile join
      let query = supabase
        .from('agents')
        .select('*')
        .order('created_at', { ascending: false });

      if (filterStatus !== 'all') {
        query = query.eq('status', filterStatus);
      }
      if (filterTier !== 'all') {
        query = query.eq('tier', filterTier);
      }

      const { data: agentsData, error: fetchError } = await query;

      // Handle RLS permission errors gracefully
      if (fetchError) {
        const errorMsg = fetchError.message?.toLowerCase() || '';
        if (errorMsg.includes('permission') || errorMsg.includes('policy') || fetchError.code === 'PGRST301') {
          console.warn('Agents: Admin access not configured. Please run FIX_ADMIN_RLS_POLICIES.sql');
          setAgents([]);
          setStats({ totalAgents: 0, activeAgents: 0, totalSales: 0, totalProfit: 0 });
          setLastUpdated(new Date());
          return;
        }
        throw fetchError;
      }

      // Fetch profiles for agents
      let profilesMap = new Map<string, Record<string, unknown>>();
      if (agentsData && agentsData.length > 0) {
        const userIds = [...new Set(agentsData.map((a: Record<string, unknown>) => a.user_id as string))];
        const { data: profilesData } = await supabase
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .in('id', userIds);
        
        profilesMap = new Map(
          (profilesData || []).map((p: Record<string, unknown>) => [p.id as string, p])
        );
      }
      
      const transformedData = (agentsData || []).map((agent: Record<string, unknown>) => {
        const profile = profilesMap.get(agent.user_id as string);
        return {
          ...agent,
          username: profile?.username || profile?.display_name || 'Unknown',
          avatar_url: profile?.avatar_url,
        };
      }) as Agent[];
      
      setAgents(transformedData);
      
      // Calculate stats
      const totalAgents = transformedData.length;
      const activeAgents = transformedData.filter((a: Agent) => a.status === 'active').length;
      const totalSales = transformedData.reduce((sum: number, a: Agent) => sum + (a.total_sales || 0), 0);
      const totalProfit = transformedData.reduce((sum: number, a: Agent) => sum + (a.total_profit || 0), 0);
      
      setStats({ totalAgents, activeAgents, totalSales, totalProfit });
      setLastUpdated(new Date());
    } catch (err) {
      console.error('Fetch error:', err);
      const isNetworkError = err instanceof TypeError || (err as Error)?.message?.includes('fetch');
      setError(isNetworkError 
        ? 'Unable to connect to server. Please check your connection.'
        : '');
    } finally {
      setIsLoading(false);
    }
  }, [filterStatus, filterTier]);

  useEffect(() => {
    fetchAgents();
  }, [fetchAgents]);

  const handleRefresh = () => {
    setIsLoading(true);
    fetchAgents();
  };

  const handleSuspend = async (agent: Agent) => {
    if (!suspensionReason.trim()) {
      setError('Please provide a suspension reason');
      return;
    }

    setIsProcessing(true);
    try {
      const { error: updateError } = await supabase
        .from('agents')
        .update({
          status: 'suspended',
          suspension_reason: suspensionReason.trim(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', agent.id);

      if (updateError) throw updateError;

      setSuccess(`${agent.full_name} has been suspended.`);
      setSelectedAgent(null);
      setSuspensionReason('');
      fetchAgents();
      setTimeout(() => setSuccess(''), 5000);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to suspend agent';
      setError(message);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleReactivate = async (agent: Agent) => {
    if (!confirm(`Are you sure you want to reactivate ${agent.full_name}?`)) return;

    setIsProcessing(true);
    try {
      const { error: updateError } = await supabase
        .from('agents')
        .update({
          status: 'active',
          suspension_reason: null,
          suspended_by: null,
          updated_at: new Date().toISOString(),
        })
        .eq('id', agent.id);

      if (updateError) throw updateError;

      setSuccess(`${agent.full_name} has been reactivated.`);
      fetchAgents();
      setTimeout(() => setSuccess(''), 5000);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to reactivate agent';
      setError(message);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleChangeTier = async (agent: Agent, newTier: string) => {
    setIsProcessing(true);
    try {
      const { error: updateError } = await supabase
        .from('agents')
        .update({
          tier: newTier,
          updated_at: new Date().toISOString(),
        })
        .eq('id', agent.id);

      if (updateError) throw updateError;

      setSuccess(`${agent.full_name}'s tier has been updated to ${newTier}.`);
      fetchAgents();
      setTimeout(() => setSuccess(''), 5000);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to update tier';
      setError(message);
    } finally {
      setIsProcessing(false);
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'active':
        return <Badge variant="success" dot>Active</Badge>;
      case 'suspended':
        return <Badge variant="warning" dot>Suspended</Badge>;
      case 'revoked':
        return <Badge variant="danger" dot>Revoked</Badge>;
      default:
        return <Badge variant="default">{status}</Badge>;
    }
  };

  const getTierBadge = (tier: string) => {
    const colorMap: Record<string, 'default' | 'success' | 'warning' | 'danger' | 'info'> = {
      standard: 'default',
      silver: 'info',
      gold: 'warning',
      platinum: 'success',
    };
    return <Badge variant={colorMap[tier] || 'default'} dot>{tier}</Badge>;
  };

  const filteredAgents = agents.filter(agent => {
    if (!searchQuery) return true;
    const query = searchQuery.toLowerCase();
    return (
      agent.full_name.toLowerCase().includes(query) ||
      (agent.state?.toLowerCase().includes(query)) ||
      (agent.town?.toLowerCase().includes(query)) ||
      (agent.phone_number?.includes(query)) ||
      (agent.email?.toLowerCase().includes(query)) ||
      (agent.username?.toLowerCase().includes(query)) ||
      (agent.business_name?.toLowerCase().includes(query))
    );
  });

  if (isLoading && !lastUpdated) {
    return (
      <div className="space-y-8">
        <PageHeader
          title="Agent Management"
          description="Manage approved agents"
        />
        <Card>
          <TableSkeleton rows={8} columns={6} />
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
          title="Agent System"
          description="Manage agent applications, agents, and pricing"
        >
          <RefreshButton 
            onClick={handleRefresh} 
            isLoading={isLoading}
            lastUpdated={lastUpdated}
          />
        </PageHeader>
      </div>

      {/* Sub Navigation */}
      <div className="flex gap-2 border-b border-[var(--color-gray-700)] pb-4">
        <Link
          href="/agents"
          className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all bg-[var(--color-gray-700)] text-[var(--color-gray-300)] hover:bg-[var(--color-gray-600)]"
        >
          <FileText size={16} />
          Applications
        </Link>
        <Link
          href="/agents/manage"
          className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all bg-[var(--color-primary)] text-white"
        >
          <Users size={16} />
          Manage Agents
        </Link>
        <Link
          href="/agents/pricing"
          className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all bg-[var(--color-gray-700)] text-[var(--color-gray-300)] hover:bg-[var(--color-gray-600)]"
        >
          <DollarSign size={16} />
          Agent Pricing
        </Link>
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
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <StatCard
          label="Total Agents"
          value={stats.totalAgents}
          icon={<User size={20} />}
          isCurrency={false}
        />
        <StatCard
          label="Active Agents"
          value={stats.activeAgents}
          icon={<Shield size={20} />}
          color="green"
          isCurrency={false}
        />
        <StatCard
          label="Total Sales"
          value={stats.totalSales}
          icon={<TrendingUp size={20} />}
          color="blue"
        />
        <StatCard
          label="Total Profit"
          value={stats.totalProfit}
          icon={<DollarSign size={20} />}
          color="amber"
        />
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="py-4">
          <div className="flex flex-col md:flex-row gap-4">
            <div className="flex-1">
              <Input
                placeholder="Search agents..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full"
              />
            </div>
            <div className="flex gap-2 flex-wrap">
              <select
                value={filterStatus}
                onChange={(e) => setFilterStatus(e.target.value)}
                title="Filter by agent status"
                className="px-4 py-2 rounded-lg bg-[var(--color-gray-700)] text-[var(--color-text-primary)] border border-[var(--color-gray-600)]"
              >
                <option value="all">All Status</option>
                <option value="active">Active</option>
                <option value="suspended">Suspended</option>
                <option value="revoked">Revoked</option>
              </select>
              <select
                value={filterTier}
                onChange={(e) => setFilterTier(e.target.value)}
                title="Filter by agent tier"
                className="px-4 py-2 rounded-lg bg-[var(--color-gray-700)] text-[var(--color-text-primary)] border border-[var(--color-gray-600)]"
              >
                <option value="all">All Tiers</option>
                <option value="standard">Standard</option>
                <option value="silver">Silver</option>
                <option value="gold">Gold</option>
                <option value="platinum">Platinum</option>
              </select>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Agents List */}
      <div className="grid gap-4">
        {filteredAgents.length === 0 ? (
          <Card>
            <EmptyState
              title="No agents found"
              description="There are no agents matching your filters."
              icon={<User size={48} />}
            />
          </Card>
        ) : (
          filteredAgents.map((agent) => (
            <Card key={agent.id} className="hover:border-[var(--color-primary)]/30 transition-all">
              <CardContent className="p-6">
                <div className="flex flex-col lg:flex-row lg:items-center gap-4">
                  {/* Agent Info */}
                  <div className="flex items-center gap-4 flex-1">
                    <div className="w-12 h-12 rounded-full bg-[var(--color-primary)]/20 flex items-center justify-center">
                      {agent.avatar_url ? (
                        <img 
                          src={agent.avatar_url} 
                          alt={agent.full_name}
                          className="w-12 h-12 rounded-full object-cover"
                        />
                      ) : (
                        <User size={24} className="text-[var(--color-primary)]" />
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <h3 className="font-semibold text-[var(--color-text-primary)]">
                          {agent.full_name}
                        </h3>
                        {getStatusBadge(agent.status)}
                        {getTierBadge(agent.tier)}
                      </div>
                      <p className="text-sm text-[var(--color-gray-400)]">
                        @{agent.username || 'unknown'} • {agent.business_name || 'No business name'}
                      </p>
                    </div>
                  </div>

                  {/* Stats */}
                  <div className="flex items-center gap-6 text-sm">
                    <div className="text-center">
                      <p className="font-semibold text-[var(--color-text-primary)]">
                        {agent.total_transactions}
                      </p>
                      <p className="text-[var(--color-gray-400)]">Transactions</p>
                    </div>
                    <div className="text-center">
                      <p className="font-semibold text-[var(--color-success)]">
                        {formatCurrency(agent.total_sales)}
                      </p>
                      <p className="text-[var(--color-gray-400)]">Sales</p>
                    </div>
                    <div className="text-center">
                      <p className="font-semibold text-[var(--color-warning)]">
                        {formatCurrency(agent.total_profit)}
                      </p>
                      <p className="text-[var(--color-gray-400)]">Profit</p>
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="flex items-center gap-2">
                    {agent.status === 'active' && (
                      <Button
                        variant="primary"
                        size="sm"
                        onClick={() => setSelectedAgent(agent)}
                      >
                        <Ban size={14} className="mr-1" />
                        Suspend
                      </Button>
                    )}
                    {agent.status === 'suspended' && (
                      <Button
                        variant="success"
                        size="sm"
                        onClick={() => handleReactivate(agent)}
                        disabled={isProcessing}
                      >
                        <RotateCcw size={14} className="mr-1" />
                        Reactivate
                      </Button>
                    )}
                    <select
                      value={agent.tier}
                      onChange={(e) => handleChangeTier(agent, e.target.value)}
                      disabled={isProcessing}
                      title="Change agent tier"
                      className="px-3 py-1.5 text-sm rounded-lg bg-[var(--color-gray-700)] text-[var(--color-text-primary)] border border-[var(--color-gray-600)]"
                    >
                      <option value="standard">Standard</option>
                      <option value="silver">Silver</option>
                      <option value="gold">Gold</option>
                      <option value="platinum">Platinum</option>
                    </select>
                  </div>
                </div>

                {/* Location & Last Activity */}
                <div className="mt-4 pt-4 border-t border-[var(--color-gray-700)] flex flex-wrap gap-4 text-sm text-[var(--color-gray-400)]">
                  {agent.state && agent.town && (
                    <div className="flex items-center gap-1">
                      <MapPin size={14} />
                      <span>{agent.town}, {agent.state}</span>
                    </div>
                  )}
                  <div className="flex items-center gap-1">
                    <Calendar size={14} />
                    <span>Joined {new Date(agent.created_at).toLocaleDateString()}</span>
                  </div>
                  {agent.last_transaction_at && (
                    <div className="flex items-center gap-1">
                      <TrendingUp size={14} />
                      <span>Last sale: {new Date(agent.last_transaction_at).toLocaleDateString()}</span>
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>
          ))
        )}
      </div>

      {/* Suspension Modal */}
      {selectedAgent && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
          <div className="bg-[var(--color-gray-800)] rounded-xl max-w-md w-full">
            <div className="p-6 border-b border-[var(--color-gray-700)]">
              <h2 className="text-xl font-bold text-[var(--color-text-primary)]">
                Suspend Agent
              </h2>
              <p className="text-sm text-[var(--color-gray-400)] mt-1">
                Suspending {selectedAgent.full_name}
              </p>
            </div>
            
            <div className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-[var(--color-gray-400)] mb-2">
                  Suspension Reason *
                </label>
                <textarea
                  value={suspensionReason}
                  onChange={(e) => setSuspensionReason(e.target.value)}
                  placeholder="Enter reason for suspension..."
                  className="w-full p-3 bg-[var(--color-gray-700)] border border-[var(--color-gray-600)] rounded-lg text-[var(--color-text-primary)] placeholder-[var(--color-gray-500)] focus:ring-2 focus:ring-[var(--color-warning)] focus:border-transparent"
                  rows={3}
                />
              </div>
              <p className="text-sm text-[var(--color-gray-500)]">
                The agent will lose access to agent pricing and dashboard until reactivated.
              </p>
            </div>

            <div className="p-6 border-t border-[var(--color-gray-700)] flex gap-3 justify-end">
              <Button
                variant="outline"
                onClick={() => {
                  setSelectedAgent(null);
                  setSuspensionReason('');
                }}
              >
                Cancel
              </Button>
              <Button
                variant="danger"
                onClick={() => handleSuspend(selectedAgent)}
                disabled={isProcessing || !suspensionReason.trim()}
              >
                {isProcessing ? <RefreshCw size={14} className="animate-spin mr-1" /> : <Ban size={14} className="mr-1" />}
                Suspend Agent
              </Button>
            </div>
          </div>
        </div>
      )}
      </div>
    </AdminProtection>
  );
}
