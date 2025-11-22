'use client';

import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
import { Wallet } from '@/types';
import { Search, Plus, Minus } from 'lucide-react';

interface WalletWithUser extends Wallet {
  user_email?: string;
  user_name?: string;
  total_transactions?: number;
}

export default function WalletsPage() {
  const [wallets, setWallets] = useState<WalletWithUser[]>([]);
  const [filteredWallets, setFilteredWallets] = useState<WalletWithUser[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedWallet, setSelectedWallet] = useState<WalletWithUser | null>(null);
  const [adjustmentAmount, setAdjustmentAmount] = useState('');
  const [adjustmentType, setAdjustmentType] = useState<'add' | 'subtract'>('add');

  useEffect(() => {
    fetchWallets();
  }, []);

  const fetchWallets = async () => {
    try {
      const { data, error } = await supabase
        .from('hazpay_wallets')
        .select('*')
        .order('balance', { ascending: false });

      if (error) throw error;
      setWallets(data || []);
    } catch (error) {
      console.error('Failed to fetch wallets:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleAdjustment = async () => {
    if (!selectedWallet || !adjustmentAmount) return;

    const amount = parseFloat(adjustmentAmount);
    if (isNaN(amount) || amount <= 0) {
      alert('Please enter a valid amount');
      return;
    }

    const newBalance =
      adjustmentType === 'add'
        ? selectedWallet.balance + amount
        : Math.max(0, selectedWallet.balance - amount);

    try {
      const { error } = await supabase
        .from('hazpay_wallets')
        .update({ balance: newBalance })
        .eq('id', selectedWallet.id);

      if (error) throw error;

      // Update local state
      setWallets(
        wallets.map((w) =>
          w.id === selectedWallet.id ? { ...w, balance: newBalance } : w
        )
      );

      setSelectedWallet(null);
      setAdjustmentAmount('');
      alert('Wallet adjusted successfully');
    } catch (error) {
      alert('Failed to adjust wallet');
      console.error(error);
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-lg text-gray-600">Loading wallets...</div>
      </div>
    );
  }

  const totalWalletBalance = wallets.reduce((sum, w) => sum + w.balance, 0);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Wallet Management</h1>
        <p className="text-gray-600 mt-2">View and manage user wallet balances</p>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white rounded-lg shadow p-6 border-l-4 border-blue-600">
          <p className="text-gray-600 text-sm font-medium">Total Wallets</p>
          <p className="text-3xl font-bold text-gray-900 mt-2">{wallets.length}</p>
        </div>
        <div className="bg-white rounded-lg shadow p-6 border-l-4 border-green-600">
          <p className="text-gray-600 text-sm font-medium">Total Balance</p>
          <p className="text-3xl font-bold text-gray-900 mt-2">₦{totalWalletBalance.toLocaleString()}</p>
        </div>
        <div className="bg-white rounded-lg shadow p-6 border-l-4 border-purple-600">
          <p className="text-gray-600 text-sm font-medium">Average Balance</p>
          <p className="text-3xl font-bold text-gray-900 mt-2">
            ₦{(totalWalletBalance / wallets.length).toLocaleString()}
          </p>
        </div>
      </div>

      {/* Search */}
      <div className="bg-white rounded-lg shadow p-4">
        <div className="relative">
          <Search size={18} className="absolute left-3 top-3 text-gray-400" />
          <input
            type="text"
            placeholder="Search by user ID, email..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
          />
        </div>
      </div>

      {/* Wallets Table */}
      <div className="bg-white rounded-lg shadow overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-50 border-b">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">User ID</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Balance (₦)</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Transactions</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Updated</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y">
            {filteredWallets.map((wallet) => (
              <tr key={wallet.id} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 font-medium">
                  {wallet.user_id.substring(0, 8)}...
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm font-semibold text-gray-900">
                  ₦{(wallet.balance || 0).toLocaleString()}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {wallet.total_transactions || 0}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600">
                  {wallet.updated_at ? new Date(wallet.updated_at).toLocaleDateString() : 'N/A'}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm">
                  <button
                    onClick={() => setSelectedWallet(wallet)}
                    className="px-3 py-1 bg-blue-600 text-white rounded hover:bg-blue-700 text-xs font-medium"
                  >
                    Adjust
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Adjustment Modal */}
      {selectedWallet && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-lg max-w-md w-full p-6">
            <h2 className="text-xl font-bold text-gray-900 mb-4">Adjust Wallet Balance</h2>

            <div className="space-y-4">
              <div>
                <p className="text-sm text-gray-600">Current Balance</p>
                <p className="text-2xl font-bold text-gray-900 mt-1">
                  ₦{selectedWallet.balance.toLocaleString()}
                </p>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <button
                  onClick={() => setAdjustmentType('add')}
                  className={`flex items-center justify-center gap-2 py-2 rounded-lg font-medium transition-colors ${
                    adjustmentType === 'add'
                      ? 'bg-green-600 text-white'
                      : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                  }`}
                >
                  <Plus size={18} /> Add
                </button>
                <button
                  onClick={() => setAdjustmentType('subtract')}
                  className={`flex items-center justify-center gap-2 py-2 rounded-lg font-medium transition-colors ${
                    adjustmentType === 'subtract'
                      ? 'bg-red-600 text-white'
                      : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                  }`}
                >
                  <Minus size={18} /> Subtract
                </button>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Amount (₦)
                </label>
                <input
                  type="number"
                  value={adjustmentAmount}
                  onChange={(e) => setAdjustmentAmount(e.target.value)}
                  placeholder="Enter amount"
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                />
              </div>

              <div className="flex gap-4">
                <button
                  onClick={handleAdjustment}
                  className="flex-1 bg-blue-600 text-white py-2 rounded-lg font-medium hover:bg-blue-700"
                >
                  Confirm
                </button>
                <button
                  onClick={() => {
                    setSelectedWallet(null);
                    setAdjustmentAmount('');
                  }}
                  className="flex-1 bg-gray-300 text-gray-900 py-2 rounded-lg font-medium hover:bg-gray-400"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {filteredWallets.length === 0 && (
        <div className="text-center py-12">
          <p className="text-gray-600">No wallets found</p>
        </div>
      )}
    </div>
  );
}
