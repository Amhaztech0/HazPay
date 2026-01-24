'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@supabase/supabase-js';
import { Spinner, PageLoading } from '@/components/ui/Loading';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

interface AdminEmail {
  id: number;
  email: string;
  is_active: boolean;
  added_at: string;
  added_by: string | null;
}

interface SignupAttempt {
  created_at: string;
  email: string;
  status: string;
}

export function AdminManagement() {
  const [adminEmails, setAdminEmails] = useState<AdminEmail[]>([]);
  const [signupAttempts, setSignupAttempts] = useState<SignupAttempt[]>([]);
  const [newEmail, setNewEmail] = useState('');
  const [loading, setLoading] = useState(true);
  const [adding, setAdding] = useState(false);
  const [message, setMessage] = useState('');
  const [messageType, setMessageType] = useState<'success' | 'error'>('success');

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);

      // Load admin emails
      const { data: emails, error: emailsError } = await supabase
        .from('admin_emails')
        .select('*')
        .order('added_at', { ascending: false });

      if (emailsError) throw emailsError;
      setAdminEmails(emails || []);

      // Load signup attempts
      const { data: attempts, error: attemptsError } = await supabase
        .from('audit_log')
        .select('created_at, details')
        .eq('action', 'signup_attempt')
        .order('created_at', { ascending: false })
        .limit(10);

      if (attemptsError) throw attemptsError;

      interface AuditAttempt {
        created_at: string;
        details: { email?: string; status?: string } | null;
      }

      const formattedAttempts = (attempts || []).map((a: AuditAttempt) => ({
        created_at: a.created_at,
        email: a.details?.email || 'Unknown',
        status: a.details?.status || 'unknown',
      }));

      setSignupAttempts(formattedAttempts);
    } catch (error) {
      console.error('Error loading data:', error);
      setMessage('Failed to load admin data');
      setMessageType('error');
    } finally {
      setLoading(false);
    }
  };

  const handleAddAdmin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newEmail.trim()) return;

    try {
      setAdding(true);

      const { data, error } = await supabase.rpc('add_admin_email', {
        admin_email: newEmail.toLowerCase(),
      });

      if (error) throw error;

      if (data && data[0]?.success) {
        setMessage(`✅ ${data[0].message}`);
        setMessageType('success');
        setNewEmail('');
        loadData();
      } else {
        setMessage(data?.[0]?.message || 'Failed to add admin');
        setMessageType('error');
      }
    } catch (error) {
      console.error('Error adding admin:', error);
      const errorMessage = error instanceof Error ? error.message : 'Failed to add admin email';
      setMessage(errorMessage);
      setMessageType('error');
    } finally {
      setAdding(false);
    }
  };

  const handleRemoveAdmin = async (email: string) => {
    if (email === 'yyounghaz@gmail.com') {
      setMessage('❌ Cannot remove the primary admin');
      setMessageType('error');
      return;
    }

    if (!confirm(`Are you sure you want to remove ${email} as an admin?`)) return;

    try {
      const { data, error } = await supabase.rpc('remove_admin_email', {
        admin_email: email,
      });

      if (error) throw error;

      if (data && data[0]?.success) {
        setMessage(`✅ ${data[0].message}`);
        setMessageType('success');
        loadData();
      } else {
        setMessage(data?.[0]?.message || 'Failed to remove admin');
        setMessageType('error');
      }
    } catch (error) {
      console.error('Error removing admin:', error);
      const errorMessage = error instanceof Error ? error.message : 'Failed to remove admin';
      setMessage(errorMessage);
      setMessageType('error');
    }
  };

  if (loading) {
    return <PageLoading message="Loading admin management..." />;
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-white rounded-lg shadow p-6">
        <h1 className="text-2xl font-bold text-gray-900 mb-2">Admin Management</h1>
        <p className="text-gray-600">Manage admin email whitelist for system access control</p>
      </div>

      {/* Message */}
      {message && (
        <div
          className={`p-4 rounded-lg ${
            messageType === 'success'
              ? 'bg-green-50 border border-green-200 text-green-800'
              : 'bg-red-50 border border-red-200 text-red-800'
          }`}
        >
          {message}
        </div>
      )}

      {/* Add New Admin */}
      <div className="bg-white rounded-lg shadow p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Add New Admin</h2>
        <form onSubmit={handleAddAdmin} className="flex gap-2">
          <input
            type="email"
            value={newEmail}
            onChange={(e) => setNewEmail(e.target.value)}
            placeholder="Enter admin email"
            className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none"
            required
            disabled={adding}
          />
          <button
            type="submit"
            disabled={adding}
            className="bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white font-medium px-6 py-2 rounded-lg transition flex items-center gap-2"
          >
            {adding && <Spinner size="sm" />}
            {adding ? 'Adding...' : 'Add Admin'}
          </button>
        </form>
      </div>

      {/* Admin Emails List */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        <div className="p-6 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">Admin Emails ({adminEmails.length})</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Email</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Status</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Added At</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {adminEmails.map((admin) => (
                <tr key={admin.id} className="hover:bg-gray-50">
                  <td className="px-6 py-3 text-sm text-gray-900 font-medium">{admin.email}</td>
                  <td className="px-6 py-3 text-sm">
                    {admin.is_active ? (
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                        Active
                      </span>
                    ) : (
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                        Inactive
                      </span>
                    )}
                  </td>
                  <td className="px-6 py-3 text-sm text-gray-600">
                    {new Date(admin.added_at).toLocaleDateString()}
                  </td>
                  <td className="px-6 py-3 text-sm">
                    {admin.email !== 'yyounghaz@gmail.com' && admin.is_active ? (
                      <button
                        onClick={() => handleRemoveAdmin(admin.email)}
                        className="text-red-600 hover:text-red-700 font-medium"
                      >
                        Remove
                      </button>
                    ) : (
                      <span className="text-gray-400">—</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Signup Attempts */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        <div className="p-6 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">Recent Signup Attempts</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Email</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Status</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Attempt Time</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {signupAttempts.map((attempt, idx) => (
                <tr key={idx} className="hover:bg-gray-50">
                  <td className="px-6 py-3 text-sm text-gray-900 font-medium">{attempt.email}</td>
                  <td className="px-6 py-3 text-sm">
                    {attempt.status === 'rejected' ? (
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                        ❌ Rejected
                      </span>
                    ) : (
                      <span className="text-gray-500">{attempt.status}</span>
                    )}
                  </td>
                  <td className="px-6 py-3 text-sm text-gray-600">
                    {new Date(attempt.created_at).toLocaleString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
