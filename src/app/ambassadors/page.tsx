'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '../../lib/supabase';

interface AmbassadorApplication {
  id: string;
  user_id: string;
  full_name: string;
  location: string;
  promotion_method: string;
  estimated_reach: string;
  additional_info: string | null;
  status: 'pending' | 'approved' | 'rejected';
  rejection_reason: string | null;
  created_at: string;
  profiles?: {
    username: string;
    email: string;
  };
}

interface Ambassador {
  id: string;
  user_id: string;
  ambassador_code: string;
  status: 'active' | 'suspended' | 'revoked';
  suspended_reason: string | null;
  total_referred_users: number;
  total_transaction_volume: number;
  total_commission_earned: number;
  pending_payout: number;
  total_paid_out: number;
  created_at: string;
  profiles?: {
    username: string;
    email: string;
    full_name: string;
  };
}

interface AmbassadorSettings {
  id: string;
  commission_percentage: number;
  min_payout_amount: number;
  program_active: boolean;
}

export default function AmbassadorsPage() {
  const router = useRouter();
  const [tab, setTab] = useState<'applications' | 'ambassadors' | 'settings'>('applications');
  const [applications, setApplications] = useState<AmbassadorApplication[]>([]);
  const [ambassadors, setAmbassadors] = useState<Ambassador[]>([]);
  const [settings, setSettings] = useState<AmbassadorSettings | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedAmbassador, setSelectedAmbassador] = useState<Ambassador | null>(null);
  const [showRejectModal, setShowRejectModal] = useState<string | null>(null);
  const [showPayoutModal, setShowPayoutModal] = useState<Ambassador | null>(null);
  const [rejectReason, setRejectReason] = useState('');

  const fetchApplications = useCallback(async () => {
    try {
      // Fetch applications without profile join
      const { data: appsData, error: fetchError } = await supabase
        .from('ambassador_applications')
        .select('*')
        .order('created_at', { ascending: false });

      if (fetchError) throw fetchError;

      if (!appsData || appsData.length === 0) {
        setApplications([]);
        return;
      }

      // Fetch profiles for all user_ids
      const userIds = [...new Set(appsData.map((app: Record<string, unknown>) => app.user_id as string))];
      const { data: profilesData } = await supabase
        .from('profiles')
        .select('id, username, display_name, email')
        .in('id', userIds);

      // Create profiles map
      const profilesMap = new Map<string, Record<string, unknown>>(
        (profilesData || []).map((p: Record<string, unknown>) => [p.id as string, p])
      );

      // Transform data with profile info
      const transformedData = appsData.map((app: Record<string, unknown>) => {
        const profile = profilesMap.get(app.user_id as string);
        return {
          ...app,
          profiles: {
            username: (profile?.username || profile?.display_name || 'Unknown') as string,
            email: (profile?.email || '') as string,
          },
        };
      });

      setApplications(transformedData);
    } catch (e: unknown) {
      const error = e as Error;
      console.error('Error fetching applications:', error);
      setError(error.message);
    }
  }, []);

  const fetchAmbassadors = useCallback(async () => {
    try {
      // Fetch ambassadors without profile join
      const { data: ambData, error: fetchError } = await supabase
        .from('ambassadors')
        .select('*')
        .order('created_at', { ascending: false });

      if (fetchError) throw fetchError;

      if (!ambData || ambData.length === 0) {
        setAmbassadors([]);
        return;
      }

      // Fetch profiles for all user_ids
      const userIds = [...new Set(ambData.map((amb: Record<string, unknown>) => amb.user_id as string))];
      const { data: profilesData } = await supabase
        .from('profiles')
        .select('id, username, display_name, email, full_name')
        .in('id', userIds);

      // Create profiles map
      const profilesMap = new Map<string, Record<string, unknown>>(
        (profilesData || []).map((p: Record<string, unknown>) => [p.id as string, p])
      );

      // Transform data with profile info
      const transformedData = ambData.map((amb: Record<string, unknown>) => {
        const profile = profilesMap.get(amb.user_id as string);
        return {
          ...amb,
          profiles: {
            username: (profile?.username || profile?.display_name || 'Unknown') as string,
            email: (profile?.email || '') as string,
            full_name: (profile?.full_name || profile?.display_name || '') as string,
          },
        };
      });

      setAmbassadors(transformedData);
    } catch (e: unknown) {
      const error = e as Error;
      console.error('Error fetching ambassadors:', error);
      setError(error.message);
    }
  }, []);

  const fetchSettings = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from('ambassador_settings')
        .select('*')
        .single();

      if (error) throw error;
      setSettings(data);
    } catch (e: unknown) {
      const error = e as Error;
      console.error('Error fetching settings:', error);
    }
  }, []);

  useEffect(() => {
    const loadData = async () => {
      setLoading(true);
      await Promise.all([fetchApplications(), fetchAmbassadors(), fetchSettings()]);
      setLoading(false);
    };
    loadData();
  }, [fetchApplications, fetchAmbassadors, fetchSettings]);

  const approveApplication = async (applicationId: string) => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const { error } = await supabase.rpc('approve_ambassador_application', {
        p_application_id: applicationId,
        p_admin_id: user.id,
      });

      if (error) throw error;

      alert('Application approved! Ambassador created.');
      fetchApplications();
      fetchAmbassadors();
    } catch (e: unknown) {
      const error = e as Error;
      alert(`Error: ${error.message}`);
    }
  };

  const rejectApplication = async () => {
    if (!showRejectModal || !rejectReason.trim()) {
      alert('Please provide a rejection reason');
      return;
    }

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const { error } = await supabase.rpc('reject_ambassador_application', {
        p_application_id: showRejectModal,
        p_admin_id: user.id,
        p_reason: rejectReason,
      });

      if (error) throw error;

      alert('Application rejected');
      setShowRejectModal(null);
      setRejectReason('');
      fetchApplications();
    } catch (e: unknown) {
      const error = e as Error;
      alert(`Error: ${error.message}`);
    }
  };

  const updateAmbassadorStatus = async (ambassadorId: string, status: string, reason?: string) => {
    try {
      const { error } = await supabase
        .from('ambassadors')
        .update({
          status,
          suspended_reason: reason || null,
          updated_at: new Date().toISOString(),
        })
        .eq('id', ambassadorId);

      if (error) throw error;
      alert(`Ambassador ${status}`);
      fetchAmbassadors();
    } catch (e: unknown) {
      const error = e as Error;
      alert(`Error: ${error.message}`);
    }
  };

  const updateSettings = async (newSettings: Partial<AmbassadorSettings>) => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      
      const { error } = await supabase
        .from('ambassador_settings')
        .update({
          ...newSettings,
          updated_by: user?.id,
          updated_at: new Date().toISOString(),
        })
        .eq('id', settings?.id);

      if (error) throw error;
      alert('Settings updated');
      fetchSettings();
    } catch (e: unknown) {
      const error = e as Error;
      alert(`Error: ${error.message}`);
    }
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-NG', {
      style: 'currency',
      currency: 'NGN',
      minimumFractionDigits: 0,
    }).format(amount);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="p-6">
      {/* Back Button */}
      <button
        onClick={() => router.push('/dashboard')}
        className="flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-4"
      >
        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
        Back
      </button>

      <h1 className="text-2xl font-bold mb-6">Ambassador Program</h1>

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          {error}
        </div>
      )}

      {/* Tabs */}
      <div className="flex space-x-4 mb-6">
        <button
          onClick={() => setTab('applications')}
          className={`px-4 py-2 rounded-lg font-medium ${
            tab === 'applications'
              ? 'bg-blue-600 text-white'
              : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
          }`}
        >
          Applications ({applications.filter(a => a.status === 'pending').length})
        </button>
        <button
          onClick={() => setTab('ambassadors')}
          className={`px-4 py-2 rounded-lg font-medium ${
            tab === 'ambassadors'
              ? 'bg-blue-600 text-white'
              : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
          }`}
        >
          Ambassadors ({ambassadors.length})
        </button>
        <button
          onClick={() => setTab('settings')}
          className={`px-4 py-2 rounded-lg font-medium ${
            tab === 'settings'
              ? 'bg-blue-600 text-white'
              : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
          }`}
        >
          Settings
        </button>
      </div>

      {/* Applications Tab */}
      {tab === 'applications' && (
        <div className="bg-white rounded-lg shadow overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Applicant</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Location</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Method</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Reach</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {applications.map((app) => (
                <tr key={app.id}>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="font-medium text-gray-900">{app.full_name}</div>
                    <div className="text-sm text-gray-500">@{app.profiles?.username || 'N/A'}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {app.location}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {app.promotion_method.toUpperCase()}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {app.estimated_reach}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`px-2 py-1 text-xs rounded-full ${
                      app.status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                      app.status === 'approved' ? 'bg-green-100 text-green-800' :
                      'bg-red-100 text-red-800'
                    }`}>
                      {app.status.toUpperCase()}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm">
                    {app.status === 'pending' && (
                      <div className="flex space-x-2">
                        <button
                          onClick={() => approveApplication(app.id)}
                          className="bg-green-600 text-white px-3 py-1 rounded hover:bg-green-700"
                        >
                          Approve
                        </button>
                        <button
                          onClick={() => setShowRejectModal(app.id)}
                          className="bg-red-600 text-white px-3 py-1 rounded hover:bg-red-700"
                        >
                          Reject
                        </button>
                      </div>
                    )}
                    {app.status === 'rejected' && app.rejection_reason && (
                      <span className="text-red-600 text-xs">Reason: {app.rejection_reason}</span>
                    )}
                  </td>
                </tr>
              ))}
              {applications.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-6 py-8 text-center text-gray-500">
                    No applications found
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Ambassadors Tab */}
      {tab === 'ambassadors' && (
        <div className="bg-white rounded-lg shadow overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Ambassador</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Code</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Referrals</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Volume</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Earned</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Pending</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {ambassadors.map((amb) => (
                <tr key={amb.id} className="hover:bg-gray-50 cursor-pointer">
                  <td className="px-6 py-4 whitespace-nowrap" onClick={() => setSelectedAmbassador(amb)}>
                    <div className="font-medium text-gray-900">{amb.profiles?.full_name || 'N/A'}</div>
                    <div className="text-sm text-gray-500">@{amb.profiles?.username || 'N/A'}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className="font-mono bg-gray-100 px-2 py-1 rounded">{amb.ambassador_code}</span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {amb.total_referred_users}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {formatCurrency(amb.total_transaction_volume)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-green-600 font-medium">
                    {formatCurrency(amb.total_commission_earned)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-orange-600 font-medium">
                    {formatCurrency(amb.pending_payout)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`px-2 py-1 text-xs rounded-full ${
                      amb.status === 'active' ? 'bg-green-100 text-green-800' :
                      amb.status === 'suspended' ? 'bg-yellow-100 text-yellow-800' :
                      'bg-red-100 text-red-800'
                    }`}>
                      {amb.status.toUpperCase()}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm">
                    <div className="flex space-x-2">
                      <button
                        onClick={() => setSelectedAmbassador(amb)}
                        className="bg-blue-600 text-white px-3 py-1 rounded hover:bg-blue-700"
                      >
                        View
                      </button>
                      {amb.pending_payout > 0 && (
                        <button
                          onClick={() => setShowPayoutModal(amb)}
                          className="bg-green-600 text-white px-3 py-1 rounded hover:bg-green-700"
                        >
                          Payout
                        </button>
                      )}
                      {amb.status === 'active' && (
                        <button
                          onClick={() => {
                            const reason = prompt('Reason for suspension:');
                            if (reason) updateAmbassadorStatus(amb.id, 'suspended', reason);
                          }}
                          className="bg-yellow-600 text-white px-3 py-1 rounded hover:bg-yellow-700"
                        >
                          Suspend
                        </button>
                      )}
                      {amb.status === 'suspended' && (
                        <button
                          onClick={() => updateAmbassadorStatus(amb.id, 'active')}
                          className="bg-green-600 text-white px-3 py-1 rounded hover:bg-green-700"
                        >
                          Activate
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
              {ambassadors.length === 0 && (
                <tr>
                  <td colSpan={8} className="px-6 py-8 text-center text-gray-500">
                    No ambassadors found
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Settings Tab */}
      {tab === 'settings' && settings && (
        <div className="bg-white rounded-lg shadow p-6 max-w-lg">
          <h2 className="text-lg font-semibold mb-4">Commission Settings</h2>
          
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Commission Percentage (%)
              </label>
              <input
                type="number"
                step="0.1"
                min="0"
                max="100"
                value={settings.commission_percentage}
                onChange={(e) => setSettings({ ...settings, commission_percentage: parseFloat(e.target.value) })}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"
                aria-label="Commission Percentage"
              />
              <p className="text-xs text-gray-500 mt-1">
                Current: {settings.commission_percentage}% - Changes apply to future transactions only
              </p>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Minimum Payout Amount (₦)
              </label>
              <input
                type="number"
                min="0"
                aria-label="Minimum Payout Amount"
                value={settings.min_payout_amount}
                onChange={(e) => setSettings({ ...settings, min_payout_amount: parseFloat(e.target.value) })}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"
              />
            </div>

            <div className="flex items-center">
              <input
                type="checkbox"
                id="programActive"
                checked={settings.program_active}
                onChange={(e) => setSettings({ ...settings, program_active: e.target.checked })}
                className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label htmlFor="programActive" className="ml-2 block text-sm text-gray-900">
                Program Active
              </label>
            </div>

            <button
              onClick={() => updateSettings({
                commission_percentage: settings.commission_percentage,
                min_payout_amount: settings.min_payout_amount,
                program_active: settings.program_active,
              })}
              className="w-full bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
            >
              Save Settings
            </button>
          </div>
        </div>
      )}

      {/* Reject Modal */}
      {showRejectModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-md">
            <h3 className="text-lg font-semibold mb-4">Reject Application</h3>
            <textarea
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
              placeholder="Enter rejection reason..."
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500 mb-4"
              rows={3}
            />
            <div className="flex space-x-3">
              <button
                onClick={() => {
                  setShowRejectModal(null);
                  setRejectReason('');
                }}
                className="flex-1 bg-gray-200 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-300"
              >
                Cancel
              </button>
              <button
                onClick={rejectApplication}
                className="flex-1 bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700"
              >
                Reject
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Payout Modal */}
      {showPayoutModal && (
        <PayoutModal
          ambassador={showPayoutModal}
          onClose={() => setShowPayoutModal(null)}
          onSuccess={() => {
            setShowPayoutModal(null);
            fetchAmbassadors();
          }}
          formatCurrency={formatCurrency}
        />
      )}

      {/* Ambassador Detail Modal */}
      {selectedAmbassador && (
        <AmbassadorDetailModal
          ambassador={selectedAmbassador}
          onClose={() => setSelectedAmbassador(null)}
          formatCurrency={formatCurrency}
        />
      )}
    </div>
  );
}

// Payout Modal Component
function PayoutModal({
  ambassador,
  onClose,
  onSuccess,
  formatCurrency,
}: {
  ambassador: Ambassador;
  onClose: () => void;
  onSuccess: () => void;
  formatCurrency: (amount: number) => string;
}) {
  const [amount, setAmount] = useState(ambassador.pending_payout);
  const [paymentMethod, setPaymentMethod] = useState('Bank Transfer');
  const [paymentReference, setPaymentReference] = useState('');
  const [notes, setNotes] = useState('');
  const [loading, setLoading] = useState(false);

  const processPayout = async () => {
    if (amount <= 0 || amount > ambassador.pending_payout) {
      alert('Invalid amount');
      return;
    }

    setLoading(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const { error } = await supabase.rpc('mark_commissions_paid', {
        p_ambassador_id: ambassador.id,
        p_admin_id: user.id,
        p_amount: amount,
        p_payment_method: paymentMethod,
        p_payment_reference: paymentReference,
        p_notes: notes,
      });

      if (error) throw error;
      alert('Payout recorded successfully!');
      onSuccess();
    } catch (e: unknown) {
      const error = e as Error;
      alert(`Error: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-6 w-full max-w-md">
        <h3 className="text-lg font-semibold mb-4">Process Payout</h3>
        <p className="text-sm text-gray-600 mb-4">
          Ambassador: {ambassador.profiles?.full_name || ambassador.ambassador_code}
        </p>
        <p className="text-sm font-medium text-orange-600 mb-4">
          Pending: {formatCurrency(ambassador.pending_payout)}
        </p>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Amount (₦)
            </label>
            <input
              type="number"
              min="0"
              max={ambassador.pending_payout}
              value={amount}
              onChange={(e) => setAmount(parseFloat(e.target.value))}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg"
              aria-label="Payout Amount"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Payment Method
            </label>
            <select
              value={paymentMethod}
              onChange={(e) => setPaymentMethod(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg"
              aria-label="Payment Method"
            >
              <option>Bank Transfer</option>
              <option>Cash</option>
              <option>Mobile Money</option>
              <option>Other</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Payment Reference
            </label>
            <input
              type="text"
              value={paymentReference}
              onChange={(e) => setPaymentReference(e.target.value)}
              placeholder="Transaction ID, etc."
              className="w-full px-3 py-2 border border-gray-300 rounded-lg"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Notes
            </label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Optional notes..."
              className="w-full px-3 py-2 border border-gray-300 rounded-lg"
              rows={2}
            />
          </div>
        </div>

        <div className="flex space-x-3 mt-6">
          <button
            onClick={onClose}
            className="flex-1 bg-gray-200 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-300"
          >
            Cancel
          </button>
          <button
            onClick={processPayout}
            disabled={loading}
            className="flex-1 bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 disabled:opacity-50"
          >
            {loading ? 'Processing...' : 'Confirm Payout'}
          </button>
        </div>
      </div>
    </div>
  );
}

// Ambassador Detail Modal Component
function AmbassadorDetailModal({
  ambassador,
  onClose,
  formatCurrency,
}: {
  ambassador: Ambassador;
  onClose: () => void;
  formatCurrency: (amount: number) => string;
}) {
  interface AmbassadorReferral {
    id: string;
    referred_user_id: string;
    transaction_count: number;
    transaction_volume: number;
    total_transactions: number;
    total_transaction_amount: number;
    total_commission_generated: number;
    profiles?: {
      username: string;
      full_name: string;
      user_role: string;
      is_agent?: boolean;
    };
  }
  const [referrals, setReferrals] = useState<AmbassadorReferral[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchReferrals = async () => {
      try {
        // Fetch referrals without profile join
        const { data: refData, error: refError } = await supabase
          .from('ambassador_referrals')
          .select('*')
          .eq('ambassador_id', ambassador.id)
          .order('referred_at', { ascending: false });

        if (refError) throw refError;

        if (!refData || refData.length === 0) {
          setReferrals([]);
          setLoading(false);
          return;
        }

        // Fetch profiles for referred users
        const userIds = [...new Set(refData.map((r: Record<string, unknown>) => r.referred_user_id as string))];
        const { data: profilesData } = await supabase
          .from('profiles')
          .select('id, username, display_name, full_name, is_agent, user_role')
          .in('id', userIds);

        // Create profiles map
        const profilesMap = new Map<string, Record<string, unknown>>(
          (profilesData || []).map((p: Record<string, unknown>) => [p.id as string, p])
        );

        // Transform data with profile info
        const transformedData = refData.map((ref: Record<string, unknown>) => {
          const profile = profilesMap.get(ref.referred_user_id as string);
          return {
            ...ref,
            profiles: {
              username: (profile?.username || profile?.display_name || 'Unknown') as string,
              full_name: (profile?.full_name || profile?.display_name || '') as string,
              user_role: (profile?.user_role || 'user') as string,
              is_agent: (profile?.is_agent || profile?.user_role === 'agent') as boolean,
            },
          };
        });

        setReferrals(transformedData);
      } catch (e) {
        console.error('Error fetching referrals:', e);
      } finally {
        setLoading(false);
      }
    };

    fetchReferrals();
  }, [ambassador.id]);

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg w-full max-w-4xl max-h-[90vh] overflow-hidden">
        <div className="p-6 border-b">
          <div className="flex justify-between items-start">
            <div>
              <h3 className="text-xl font-semibold">{ambassador.profiles?.full_name || 'Ambassador'}</h3>
              <p className="text-sm text-gray-500">@{ambassador.profiles?.username} • {ambassador.ambassador_code}</p>
            </div>
            <button type="button" onClick={onClose} className="text-gray-400 hover:text-gray-600" aria-label="Close">
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          {/* Stats Summary */}
          <div className="grid grid-cols-4 gap-4 mt-4">
            <div className="bg-blue-50 rounded-lg p-4 text-center">
              <p className="text-2xl font-bold text-blue-600">{ambassador.total_referred_users}</p>
              <p className="text-xs text-gray-500">Total Referrals</p>
            </div>
            <div className="bg-green-50 rounded-lg p-4 text-center">
              <p className="text-lg font-bold text-green-600">{formatCurrency(ambassador.total_transaction_volume)}</p>
              <p className="text-xs text-gray-500">Transaction Volume</p>
            </div>
            <div className="bg-purple-50 rounded-lg p-4 text-center">
              <p className="text-lg font-bold text-purple-600">{formatCurrency(ambassador.total_commission_earned)}</p>
              <p className="text-xs text-gray-500">Total Earned</p>
            </div>
            <div className="bg-orange-50 rounded-lg p-4 text-center">
              <p className="text-lg font-bold text-orange-600">{formatCurrency(ambassador.pending_payout)}</p>
              <p className="text-xs text-gray-500">Pending Payout</p>
            </div>
          </div>
        </div>

        {/* Referred Users List */}
        <div className="p-6 overflow-y-auto max-h-[50vh]">
          <h4 className="font-semibold mb-4">Referred Users ({referrals.length})</h4>
          {loading ? (
            <div className="text-center py-8">Loading...</div>
          ) : referrals.length === 0 ? (
            <div className="text-center py-8 text-gray-500">No referrals yet</div>
          ) : (
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">User</th>
                  <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Role</th>
                  <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Transactions</th>
                  <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Volume</th>
                  <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Commission</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {referrals.map((ref) => (
                  <tr key={ref.id}>
                    <td className="px-4 py-3">
                      <div className="font-medium">{ref.profiles?.full_name || 'N/A'}</div>
                      <div className="text-sm text-gray-500">@{ref.profiles?.username || 'N/A'}</div>
                    </td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-1 text-xs rounded-full ${
                        ref.profiles?.user_role === 'agent'
                          ? 'bg-orange-100 text-orange-800'
                          : 'bg-blue-100 text-blue-800'
                      }`}>
                        {ref.profiles?.user_role === 'agent' ? 'AGENT' : 'USER'}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-sm">{ref.total_transactions}</td>
                    <td className="px-4 py-3 text-sm">{formatCurrency(ref.total_transaction_amount)}</td>
                    <td className="px-4 py-3 text-sm text-green-600 font-medium">
                      {formatCurrency(ref.total_commission_generated)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}
