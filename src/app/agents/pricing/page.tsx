'use client';

import { useEffect, useState, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import Link from 'next/link';
import { Edit2, Save, X, Users, DollarSign, TrendingUp, FileText } from 'lucide-react';
import {
  Card, EmptyState, StatCard,
  PageHeader, RefreshButton, PageSection, BackButton,
  Button, Input, Badge,
  Alert, InfoBox, Toast,
  TableSkeleton,
} from '@/components/ui';
import { formatCurrency, getNetworkStyles } from '@/lib/theme';

interface DataPlan {
  id: string;
  plan_id: number;
  network_id: number;
  plan_name: string;
  data_size: string;
  sell_price: number;
  cost_price: number;
  profit: number;
  // Agent pricing fields
  agent_price: number | null;
  agent_cost_price: number | null;
  is_agent_enabled: boolean;
}

interface NetworkGroup {
  id: number;
  name: string;
  plans: DataPlan[];
}

export default function AgentPricingPage() {
  const [plans, setPlans] = useState<DataPlan[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editValues, setEditValues] = useState<Partial<DataPlan>>({});
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [viewMode, setViewMode] = useState<'regular' | 'agent'>('agent');

  // Stats
  const [stats, setStats] = useState({
    totalPlans: 0,
    avgAgentDiscount: 0,
    agentEnabledPlans: 0,
  });

  const fetchPlans = useCallback(async () => {
    try {
      setError('');
      const { data, error: fetchError } = await supabase
        .from('pricing')
        .select('*')
        .order('network_id', { ascending: true })
        .order('plan_id', { ascending: true });

      if (fetchError) throw fetchError;
      
      const plansData = data || [];
      setPlans(plansData);
      
      // Calculate stats
      const totalPlans = plansData.length;
      const agentEnabledPlans = plansData.filter((p: DataPlan) => p.is_agent_enabled !== false).length;
      
      // Calculate average discount
      let totalDiscount = 0;
      let discountCount = 0;
      plansData.forEach((plan: DataPlan) => {
        if (plan.agent_price && plan.sell_price > 0) {
          const discount = ((plan.sell_price - plan.agent_price) / plan.sell_price) * 100;
          totalDiscount += discount;
          discountCount++;
        }
      });
      const avgAgentDiscount = discountCount > 0 ? totalDiscount / discountCount : 0;
      
      setStats({ totalPlans, avgAgentDiscount, agentEnabledPlans });
      setLastUpdated(new Date());
    } catch (err) {
      setError('Failed to fetch pricing plans');
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchPlans();
  }, [fetchPlans]);

  const handleEdit = (plan: DataPlan) => {
    setEditingId(plan.id);
    setEditValues({
      ...plan,
      agent_price: plan.agent_price ?? plan.sell_price * 0.95, // Default to 5% discount
    });
  };

  const handleCancel = () => {
    setEditingId(null);
    setEditValues({});
  };

  const handleRefresh = () => {
    setIsLoading(true);
    fetchPlans();
  };

  const handleSave = async () => {
    try {
      setError('');
      if (!editingId) return;

      const updateData: Record<string, unknown> = {};

      if (viewMode === 'agent') {
        if (editValues.agent_price !== undefined) {
          updateData.agent_price = Number(editValues.agent_price);
        }
        if (editValues.is_agent_enabled !== undefined) {
          updateData.is_agent_enabled = editValues.is_agent_enabled;
        }
      } else {
        if (editValues.sell_price !== undefined) {
          updateData.sell_price = Number(editValues.sell_price);
        }
        if (editValues.cost_price !== undefined) {
          updateData.cost_price = Number(editValues.cost_price);
        }
      }

      const { error: updateError } = await supabase
        .from('pricing')
        .update(updateData)
        .eq('id', editingId);

      if (updateError) throw updateError;

      setSuccess('Pricing updated successfully');
      setEditingId(null);
      setEditValues({});
      fetchPlans();
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError('Failed to save changes');
      console.error(err);
    }
  };

  const handleBulkSetDiscount = async (networkId: number, discountPercent: number) => {
    try {
      const networkPlans = plans.filter(p => p.network_id === networkId);
      
      for (const plan of networkPlans) {
        const agentPrice = plan.sell_price * (1 - discountPercent / 100);
        await supabase
          .from('pricing')
          .update({ agent_price: agentPrice })
          .eq('id', plan.id);
      }

      setSuccess(`Applied ${discountPercent}% discount to all plans`);
      fetchPlans();
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError('Failed to apply bulk discount');
    }
  };

  // Group plans by network
  const networkGroups: NetworkGroup[] = [
    { id: 1, name: 'MTN', plans: plans.filter((p) => p.network_id === 1) },
    { id: 3, name: 'Airtel', plans: plans.filter((p) => p.network_id === 3) },
    { id: 2, name: 'GLO', plans: plans.filter((p) => p.network_id === 2) },
    { id: 4, name: '9Mobile', plans: plans.filter((p) => p.network_id === 4) },
  ].filter(group => group.plans.length > 0);

  if (isLoading && !lastUpdated) {
    return (
      <div className="space-y-8">
        <PageHeader
          title="Agent Price Management"
          description="Manage agent pricing and discounts"
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
          className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all bg-[var(--color-gray-700)] text-[var(--color-gray-300)] hover:bg-[var(--color-gray-600)]"
        >
          <Users size={16} />
          Manage Agents
        </Link>
        <Link
          href="/agents/pricing"
          className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all bg-[var(--color-primary)] text-white"
        >
          <DollarSign size={16} />
          Agent Pricing
        </Link>
      </div>

      {/* Alerts */}
      {error && (
        <Alert variant="danger" title="Error" onDismiss={() => setError('')}>
          {error}
        </Alert>
      )}
      {success && (
        <Toast message={success} onClose={() => setSuccess('')} />
      )}

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <StatCard
          label="Total Plans"
          value={stats.totalPlans}
          icon={<DollarSign size={20} />}
          color="blue"
        />
        <StatCard
          label="Agent-Enabled Plans"
          value={stats.agentEnabledPlans}
          icon={<Users size={20} />}
          color="green"
        />
        <StatCard
          label="Avg. Agent Discount"
          value={`${stats.avgAgentDiscount.toFixed(1)}%`}
          icon={<TrendingUp size={20} />}
          color="amber"
        />
      </div>

      {/* View Mode Toggle */}
      <div className="flex gap-2">
        <button
          onClick={() => setViewMode('agent')}
          className={`px-4 py-2 rounded-lg font-medium transition-all ${
            viewMode === 'agent'
              ? 'bg-[var(--color-primary)] text-white'
              : 'bg-[var(--color-gray-700)] text-[var(--color-gray-300)] hover:bg-[var(--color-gray-600)]'
          }`}
        >
          <Users size={16} className="inline mr-2" />
          Agent Pricing
        </button>
        <button
          onClick={() => setViewMode('regular')}
          className={`px-4 py-2 rounded-lg font-medium transition-all ${
            viewMode === 'regular'
              ? 'bg-[var(--color-primary)] text-white'
              : 'bg-[var(--color-gray-700)] text-[var(--color-gray-300)] hover:bg-[var(--color-gray-600)]'
          }`}
        >
          <DollarSign size={16} className="inline mr-2" />
          Regular Pricing
        </button>
      </div>

      {/* Info Box */}
      <InfoBox title="Agent Pricing Tips">
        {viewMode === 'agent' ? (
          <>
            <strong>Agent Price</strong> is the discounted price agents pay.
            <strong> Regular Price</strong> is what end customers pay through agents.
            Agents keep the difference as profit.
          </>
        ) : (
          <>
            Edit the <strong>sell price</strong> to change what regular users pay.
            <strong> Cost price</strong> is what the API provider charges.
          </>
        )}
      </InfoBox>

      {/* Network Plans */}
      {networkGroups.map((group) => (
        <PageSection key={group.id}>
          <AgentPlanTable
            title={`${group.name} Data Plans`}
            data={group.plans}
            networkName={group.name}
            networkId={group.id}
            editingId={editingId}
            editValues={editValues}
            setEditValues={setEditValues}
            onEdit={handleEdit}
            onSave={handleSave}
            onCancel={handleCancel}
            onBulkDiscount={handleBulkSetDiscount}
            viewMode={viewMode}
          />
        </PageSection>
      ))}

      {/* Empty State */}
      {networkGroups.length === 0 && !isLoading && (
        <EmptyState
          icon="📋"
          title="No pricing plans found"
          description="Add data plans to the pricing table to get started"
        />
      )}
    </div>
  );
}

interface AgentPlanTableProps {
  title: string;
  data: DataPlan[];
  networkName: string;
  networkId: number;
  editingId: string | null;
  editValues: Partial<DataPlan>;
  setEditValues: (values: Partial<DataPlan>) => void;
  onEdit: (plan: DataPlan) => void;
  onSave: () => void;
  onCancel: () => void;
  onBulkDiscount: (networkId: number, discount: number) => void;
  viewMode: 'regular' | 'agent';
}

function AgentPlanTable({ 
  title, 
  data, 
  networkName,
  networkId,
  editingId, 
  editValues, 
  setEditValues,
  onEdit, 
  onSave, 
  onCancel,
  onBulkDiscount,
  viewMode,
}: AgentPlanTableProps) {
  const networkStyles = getNetworkStyles(networkName);
  const [showBulkDiscount, setShowBulkDiscount] = useState(false);
  const [bulkDiscount, setBulkDiscount] = useState('5');

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <Badge 
            variant="default" 
            className={`${networkStyles.bg} ${networkStyles.text} border-transparent`}
          >
            {networkName}
          </Badge>
          <h2 className="text-xl font-semibold text-[var(--color-text-primary)]">
            {title}
          </h2>
          <span className="text-sm text-[var(--color-gray-400)]">
            ({data.length} plans)
          </span>
        </div>
        
        {viewMode === 'agent' && (
          <div className="flex items-center gap-2">
            {showBulkDiscount ? (
              <>
                <Input
                  type="number"
                  value={bulkDiscount}
                  onChange={(e) => setBulkDiscount(e.target.value)}
                  className="w-20"
                  placeholder="%"
                />
                <Button
                  variant="success"
                  size="sm"
                  onClick={() => {
                    onBulkDiscount(networkId, parseFloat(bulkDiscount));
                    setShowBulkDiscount(false);
                  }}
                >
                  Apply
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setShowBulkDiscount(false)}
                >
                  Cancel
                </Button>
              </>
            ) : (
              <Button
                variant="outline"
                size="sm"
                onClick={() => setShowBulkDiscount(true)}
              >
                Bulk Discount
              </Button>
            )}
          </div>
        )}
      </div>

      <Card noPadding>
        <div className="overflow-x-auto">
          <table className="table w-full">
            <thead>
              <tr>
                <th className="table-header">Data Size</th>
                {viewMode === 'agent' ? (
                  <>
                    <th className="table-header">Regular Price</th>
                    <th className="table-header">Agent Price</th>
                    <th className="table-header">Agent Profit</th>
                    <th className="table-header">Discount %</th>
                    <th className="table-header">Enabled</th>
                  </>
                ) : (
                  <>
                    <th className="table-header">Cost Price</th>
                    <th className="table-header">Sell Price</th>
                    <th className="table-header">Profit</th>
                  </>
                )}
                <th className="table-header">Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.map((plan) => {
                const isEditing = editingId === plan.id;
                const agentPrice = isEditing 
                  ? (editValues.agent_price ?? plan.agent_price ?? plan.sell_price * 0.95)
                  : (plan.agent_price ?? plan.sell_price * 0.95);
                const agentProfit = plan.sell_price - agentPrice;
                const discountPercent = plan.sell_price > 0 
                  ? ((plan.sell_price - agentPrice) / plan.sell_price) * 100 
                  : 0;
                const regularProfit = plan.sell_price - plan.cost_price;
                
                return (
                  <tr key={plan.id} className="table-row border-b border-[var(--color-gray-700)]">
                    <td className="table-cell font-medium text-[var(--color-text-primary)]">
                      {plan.data_size}
                    </td>
                    
                    {viewMode === 'agent' ? (
                      <>
                        <td className="table-cell text-[var(--color-gray-300)]">
                          {formatCurrency(plan.sell_price)}
                        </td>
                        <td className="table-cell">
                          {isEditing ? (
                            <Input
                              type="number"
                              value={editValues.agent_price ?? ''}
                              onChange={(e) => setEditValues({ 
                                ...editValues, 
                                agent_price: parseFloat(e.target.value) 
                              })}
                              className="w-28"
                            />
                          ) : (
                            <span className="font-medium text-[var(--color-primary)]">
                              {formatCurrency(agentPrice)}
                            </span>
                          )}
                        </td>
                        <td className="table-cell">
                          <span className={`font-semibold ${
                            agentProfit > 0 
                              ? 'text-[var(--color-success)]' 
                              : 'text-[var(--color-gray-400)]'
                          }`}>
                            {formatCurrency(agentProfit)}
                          </span>
                        </td>
                        <td className="table-cell">
                          <Badge variant={discountPercent > 0 ? 'success' : 'default'} dot>
                            {discountPercent.toFixed(1)}%
                          </Badge>
                        </td>
                        <td className="table-cell">
                          {isEditing ? (
                            <input
                              type="checkbox"
                              checked={editValues.is_agent_enabled ?? plan.is_agent_enabled ?? true}
                              onChange={(e) => setEditValues({
                                ...editValues,
                                is_agent_enabled: e.target.checked
                              })}                            title="Enable for agents"                              className="w-4 h-4 accent-[var(--color-primary)]"
                            />
                          ) : (
                            <Badge variant={(plan.is_agent_enabled ?? true) ? 'success' : 'default'} dot>
                              {(plan.is_agent_enabled ?? true) ? 'Yes' : 'No'}
                            </Badge>
                          )}
                        </td>
                      </>
                    ) : (
                      <>
                        <td className="table-cell">
                          {isEditing ? (
                            <Input
                              type="number"
                              value={editValues.cost_price ?? ''}
                              onChange={(e) => setEditValues({ 
                                ...editValues, 
                                cost_price: parseFloat(e.target.value) 
                              })}
                              className="w-28"
                            />
                          ) : (
                            <span className="text-[var(--color-gray-300)]">
                              {formatCurrency(plan.cost_price)}
                            </span>
                          )}
                        </td>
                        <td className="table-cell">
                          {isEditing ? (
                            <Input
                              type="number"
                              value={editValues.sell_price ?? ''}
                              onChange={(e) => setEditValues({ 
                                ...editValues, 
                                sell_price: parseFloat(e.target.value) 
                              })}
                              className="w-28"
                            />
                          ) : (
                            <span className="font-medium text-[var(--color-text-primary)]">
                              {formatCurrency(plan.sell_price)}
                            </span>
                          )}
                        </td>
                        <td className="table-cell">
                          <span className={`font-semibold ${
                            regularProfit > 0 
                              ? 'text-[var(--color-success)]' 
                              : regularProfit < 0 
                                ? 'text-[var(--color-danger)]' 
                                : 'text-[var(--color-gray-400)]'
                          }`}>
                            {formatCurrency(regularProfit)}
                          </span>
                        </td>
                      </>
                    )}
                    
                    <td className="table-cell">
                      {isEditing ? (
                        <div className="flex gap-2">
                          <Button
                            variant="success"
                            size="sm"
                            onClick={onSave}
                            icon={<Save size={14} />}
                          >
                            Save
                          </Button>
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={onCancel}
                            icon={<X size={14} />}
                          >
                            Cancel
                          </Button>
                        </div>
                      ) : (
                        <Button
                          variant="primary"
                          size="sm"
                          onClick={() => onEdit(plan)}
                          icon={<Edit2 size={14} />}
                        >
                          Edit
                        </Button>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  );
}
