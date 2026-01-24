'use client';

import { useEffect, useState, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { DataPlan } from '@/types';
import { Edit2, Save, X } from 'lucide-react';
import {
  Card, CardHeader, CardContent, EmptyState,
  PageHeader, RefreshButton, PageSection, BackButton,
  Button, Input, Badge,
  Alert, InfoBox, Toast,
  TableSkeleton,
} from '@/components/ui';
import { formatCurrency, getNetworkStyles } from '@/lib/theme';

interface NetworkGroup {
  id: number;
  name: string;
  plans: DataPlan[];
}

export default function PricingPage() {
  const [plans, setPlans] = useState<DataPlan[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editValues, setEditValues] = useState<Partial<DataPlan>>({});
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  const fetchPlans = useCallback(async () => {
    try {
      setError('');
      const { data, error: fetchError } = await supabase
        .from('pricing')
        .select('*')
        .order('network_id', { ascending: true })
        .order('plan_id', { ascending: true });

      if (fetchError) throw fetchError;
      setPlans(data || []);
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
    setEditValues(plan);
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
      if (!editingId || !editValues.sell_price || !editValues.cost_price) {
        setError('Please fill in all required fields');
        return;
      }

      const sell = Number(editValues.sell_price);
      const cost = Number(editValues.cost_price);

      const { error: updateError } = await (supabase as any)
        .from('pricing')
        .update({
          sell_price: sell,
          cost_price: cost,
        })
        .eq('id', editingId);

      if (updateError) throw updateError;

      // Update local state
      setPlans(
        plans.map((p) =>
          p.id === editingId
            ? {
                ...p,
                sell_price: sell,
                cost_price: cost,
                profit: sell - cost,
              }
            : p
        )
      );

      setSuccess('Plan updated successfully');
      setEditingId(null);
      setEditValues({});
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError('Failed to save changes');
      console.error(err);
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
          title="Pricing Management"
          description="Manage data plan pricing and margins"
        />
        <Card>
          <TableSkeleton rows={8} columns={5} />
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex items-center gap-4">
        <BackButton />
        <PageHeader
          title="Pricing Management"
          description="Manage data plan pricing and margins"
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
        <Alert variant="danger" title="Error" onDismiss={() => setError('')}>
          {error}
        </Alert>
      )}

      {success && (
        <Toast message={success} onClose={() => setSuccess('')} />
      )}

      {/* Info Box */}
      <InfoBox title="Pricing Tips">
        Edit the <strong>sell price</strong> to change what users are charged.
        <strong> Cost price</strong> is what Payscribe charges you.
        <strong> Profit</strong> is automatically calculated.
      </InfoBox>

      {/* Network Plans */}
      {networkGroups.map((group) => (
        <PageSection key={group.id}>
          <PlanTable
            title={`${group.name} Data Plans`}
            data={group.plans}
            networkName={group.name}
            editingId={editingId}
            editValues={editValues}
            setEditValues={setEditValues}
            onEdit={handleEdit}
            onSave={handleSave}
            onCancel={handleCancel}
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

interface PlanTableProps {
  title: string;
  data: DataPlan[];
  networkName: string;
  editingId: string | null;
  editValues: Partial<DataPlan>;
  setEditValues: (values: Partial<DataPlan>) => void;
  onEdit: (plan: DataPlan) => void;
  onSave: () => void;
  onCancel: () => void;
}

function PlanTable({ 
  title, 
  data, 
  networkName,
  editingId, 
  editValues, 
  setEditValues,
  onEdit, 
  onSave, 
  onCancel 
}: PlanTableProps) {
  const networkStyles = getNetworkStyles(networkName);

  return (
    <div>
      <div className="flex items-center gap-3 mb-4">
        <Badge 
          variant="default" 
          className={`${networkStyles.bg} ${networkStyles.text} border-transparent`}
        >
          {networkName}
        </Badge>
        <h2 className="text-xl font-semibold text-gray-900">
          {title}
        </h2>
        <span className="text-sm text-gray-500">
          ({data.length} plans)
        </span>
      </div>

      <Card noPadding>
        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th className="table-header">Data Size</th>
                <th className="table-header">Cost Price (₦)</th>
                <th className="table-header">Sell Price (₦)</th>
                <th className="table-header">Profit (₦)</th>
                <th className="table-header">Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.map((plan) => {
                const isEditing = editingId === plan.id;
                const currentProfit = isEditing 
                  ? (editValues.sell_price || 0) - (editValues.cost_price || 0)
                  : plan.profit;
                
                return (
                  <tr key={plan.id} className="table-row">
                    <td className="table-cell font-medium">
                      {plan.data_size}
                    </td>
                    <td className="table-cell">
                      {isEditing ? (
                        <Input
                          type="number"
                          aria-label={`Cost price for plan ${plan.data_size}`}
                          value={editValues.cost_price || ''}
                          onChange={(e) => setEditValues({ 
                            ...editValues, 
                            cost_price: parseFloat(e.target.value) 
                          })}
                          className="w-28"
                        />
                      ) : (
                        <span className="text-[var(--color-text-secondary)]">
                          {formatCurrency(plan.cost_price)}
                        </span>
                      )}
                    </td>
                    <td className="table-cell">
                      {isEditing ? (
                        <Input
                          type="number"
                          aria-label={`Sell price for plan ${plan.data_size}`}
                          value={editValues.sell_price || ''}
                          onChange={(e) => setEditValues({ 
                            ...editValues, 
                            sell_price: parseFloat(e.target.value) 
                          })}
                          className="w-28"
                        />
                      ) : (
                        <span className="font-medium">
                          {formatCurrency(plan.sell_price)}
                        </span>
                      )}
                    </td>
                    <td className="table-cell">
                      <span className={`font-semibold ${
                        currentProfit > 0 
                          ? 'text-[var(--color-success)]' 
                          : currentProfit < 0 
                            ? 'text-[var(--color-danger)]' 
                            : 'text-[var(--color-text-muted)]'
                      }`}>
                        {formatCurrency(currentProfit)}
                      </span>
                    </td>
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
