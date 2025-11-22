'use client';

import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
import { DataPlan } from '@/types';
import { Edit2, Save, X, AlertCircle } from 'lucide-react';

export default function PricingPage() {
  const [plans, setPlans] = useState<DataPlan[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editValues, setEditValues] = useState<Partial<DataPlan>>({});
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    fetchPlans();
  }, []);

  const fetchPlans = async () => {
    try {
      setError('');
      const { data, error: fetchError } = await supabase
        .from('pricing')
        .select('*')
        .order('network_id', { ascending: true })
        .order('plan_id', { ascending: true });

      if (fetchError) throw fetchError;
      setPlans(data || []);
    } catch (err) {
      setError('Failed to fetch pricing plans');
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleEdit = (plan: DataPlan) => {
    setEditingId(plan.id);
    setEditValues(plan);
  };

  const handleCancel = () => {
    setEditingId(null);
    setEditValues({});
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

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-lg text-gray-600">Loading pricing plans...</div>
      </div>
    );
  }

  // Group by network
  const mtnPlans = plans.filter((p) => p.network_id === 1);
  const gloPlans = plans.filter((p) => p.network_id === 2);

  const PlanTable = ({ title, data }: { title: string; data: DataPlan[] }) => (
    <div>
      <h2 className="text-2xl font-bold text-gray-900 mb-4">{title}</h2>
      <div className="bg-white rounded-lg shadow overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-50 border-b">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Data Size</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Cost Price (₦)</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Sell Price (₦)</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Profit (₦)</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y">
            {data.map((plan) => (
              <tr key={plan.id} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  {plan.data_size}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {editingId === plan.id ? (
                    <input
                      type="number"
                      aria-label={`Cost price for plan ${plan.data_size}`}
                      value={editValues.cost_price}
                      onChange={(e) => setEditValues({ ...editValues, cost_price: parseFloat(e.target.value) })}
                      className="w-full px-2 py-1 border border-gray-300 rounded"
                    />
                  ) : (
                    `₦${plan.cost_price.toLocaleString()}`
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {editingId === plan.id ? (
                    <input
                      type="number"
                      aria-label={`Sell price for plan ${plan.data_size}`}
                      value={editValues.sell_price}
                      onChange={(e) => setEditValues({ ...editValues, sell_price: parseFloat(e.target.value) })}
                      className="w-full px-2 py-1 border border-gray-300 rounded"
                    />
                  ) : (
                    `₦${plan.sell_price.toLocaleString()}`
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-green-600">
                  ₦
                  {editingId === plan.id
                    ? ((editValues.sell_price || 0) - (editValues.cost_price || 0)).toLocaleString()
                    : plan.profit.toLocaleString()}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm">
                  {editingId === plan.id ? (
                    <div className="flex gap-2">
                      <button
                        onClick={handleSave}
                        className="flex items-center gap-1 px-3 py-1 bg-green-600 text-white rounded hover:bg-green-700"
                      >
                        <Save size={16} /> Save
                      </button>
                      <button
                        onClick={handleCancel}
                        className="flex items-center gap-1 px-3 py-1 bg-gray-400 text-white rounded hover:bg-gray-500"
                      >
                        <X size={16} /> Cancel
                      </button>
                    </div>
                  ) : (
                    <button
                      onClick={() => handleEdit(plan)}
                      className="flex items-center gap-1 px-3 py-1 bg-blue-600 text-white rounded hover:bg-blue-700"
                    >
                      <Edit2 size={16} /> Edit
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Pricing Management</h1>
        <p className="text-gray-600 mt-2">Manage data plan pricing and margins</p>
      </div>

      {/* Alerts */}
      {error && (
        <div className="p-4 bg-red-50 border border-red-200 rounded-lg flex gap-3">
          <AlertCircle className="text-red-600 shrink-0" size={20} />
          <p className="text-red-700">{error}</p>
        </div>
      )}

      {success && (
        <div className="p-4 bg-green-50 border border-green-200 rounded-lg flex gap-3">
          <AlertCircle className="text-green-600 shrink-0" size={20} />
          <p className="text-green-700">{success}</p>
        </div>
      )}

      {/* Info Box */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <p className="text-blue-900 text-sm">
          💡 <strong>Tip:</strong> Edit the sell_price to change what users are charged. Cost price is what Amigo charges you. Profit is automatically calculated.
        </p>
      </div>

      {/* MTN Plans */}
      <PlanTable title="MTN Data Plans" data={mtnPlans} />

      {/* GLO Plans */}
      <div className="mt-8">
        <PlanTable title="GLO Data Plans" data={gloPlans} />
      </div>
    </div>
  );
}
