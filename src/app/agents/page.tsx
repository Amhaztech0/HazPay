'use client';

import { AdminProtection } from '@/components/AdminProtection';
import { useEffect, useState, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import Link from 'next/link';
import { CheckCircle, XCircle, User, MapPin, Building, Calendar, Users, DollarSign, FileText, Eye } from 'lucide-react';
import {
  Card, CardContent, EmptyState,
  PageHeader, RefreshButton, BackButton,
  Button, Badge, Input,
  Alert, Toast,
  TableSkeleton,
} from '@/components/ui';

interface AgentApplication {
  id: string;
  user_id: string;
  full_name: string;
  phone_number: string | null;
  email: string | null;
  state: string;
  town: string;
  street: string;
  business_location: string | null;
  business_description: string | null;
  estimated_daily_customers: number;
  business_name: string | null;
  status: 'pending' | 'approved' | 'rejected' | 'suspended';
  rejection_reason: string | null;
  reviewed_by: string | null;
  reviewed_at: string | null;
  created_at: string;
  updated_at: string;
  // Joined profile data
  username?: string;
  avatar_url?: string;
}

export default function AgentApplicationsPage() {
  const [applications, setApplications] = useState<AgentApplication[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [selectedApplication, setSelectedApplication] = useState<AgentApplication | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [rejectionReason, setRejectionReason] = useState('');
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState('');

  const fetchApplications = useCallback(async () => {
    try {
      setError('');
      
      // First fetch applications without profile join
      let query = supabase
        .from('agent_applications')
        .select('*')
        .order('created_at', { ascending: false });

      if (filterStatus !== 'all') {
        query = query.eq('status', filterStatus);
      }

      const { data: appsData, error: fetchError } = await query;

      // Handle RLS permission errors gracefully
      if (fetchError) {
        console.error('Fetch error:', fetchError);
        const errorMsg = fetchError.message?.toLowerCase() || '';
        if (errorMsg.includes('permission') || errorMsg.includes('policy') || fetchError.code === 'PGRST301') {
          console.warn('Agent applications: Admin access not configured. Please run CLEAN_RLS_FIX.sql');
          setError('⚠️ Database access restricted. Please run CLEAN_RLS_FIX.sql in Supabase SQL Editor.');
          setApplications([]);
          setLastUpdated(new Date());
          return;
        }
        setError(`Failed to load applications: ${fetchError.message}`);
        setApplications([]);
        setLastUpdated(new Date());
        return;
      }

      if (!appsData || appsData.length === 0) {
        setApplications([]);
        setLastUpdated(new Date());
        return;
      }

      // Now fetch profiles for all user_ids
      const userIds = [...new Set(appsData.map((app: Record<string, unknown>) => app.user_id as string))];
      const { data: profilesData } = await supabase
        .from('profiles')
        .select('id, username, avatar_url, display_name, email')
        .in('id', userIds);

      // Create a map of profiles by id
      const profilesMap = new Map<string, Record<string, unknown>>(
        (profilesData || []).map((p: Record<string, unknown>) => [p.id as string, p])
      );
      
      // Transform data to include profile info
      const transformedData = appsData.map((app: Record<string, unknown>) => {
        const profile = profilesMap.get(app.user_id as string);
        return {
          ...app,
          username: (profile?.username || profile?.display_name || 'Unknown') as string,
          avatar_url: profile?.avatar_url as string | undefined,
        };
      }) as AgentApplication[];
      
      setApplications(transformedData);
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
  }, [filterStatus]);

  useEffect(() => {
    fetchApplications();
  }, [fetchApplications]);

  const handleRefresh = () => {
    setIsLoading(true);
    fetchApplications();
  };

  const handleApprove = async (application: AgentApplication) => {
    if (!confirm(`Are you sure you want to approve ${application.full_name}'s application?`)) return;
    
    setIsProcessing(true);
    try {
      // Update application status
      const { error: updateError } = await supabase
        .from('agent_applications')
        .update({
          status: 'approved',
          reviewed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', application.id);

      if (updateError) throw updateError;

      // Create or update agent record (upsert to handle reapplications)
      const { error: insertError } = await supabase
        .from('agents')
        .upsert({
          user_id: application.user_id,
          application_id: application.id,
          full_name: application.full_name,
          phone_number: application.phone_number,
          email: application.email,
          state: application.state,
          town: application.town,
          business_name: application.business_name,
          status: 'active',
          tier: 'standard',
        }, {
          onConflict: 'user_id',
          ignoreDuplicates: false,
        });

      if (insertError) throw insertError;

      setSuccess(`${application.full_name} has been approved as an agent!`);
      setSelectedApplication(null);
      fetchApplications();
      setTimeout(() => setSuccess(''), 5000);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to approve application';
      setError(message);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleReject = async (application: AgentApplication) => {
    if (!rejectionReason.trim()) {
      setError('Please provide a rejection reason');
      return;
    }

    setIsProcessing(true);
    try {
      const { error: updateError } = await supabase
        .from('agent_applications')
        .update({
          status: 'rejected',
          rejection_reason: rejectionReason.trim(),
          reviewed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', application.id);

      if (updateError) throw updateError;

      setSuccess(`Application from ${application.full_name} has been rejected.`);
      setSelectedApplication(null);
      setRejectionReason('');
      fetchApplications();
      setTimeout(() => setSuccess(''), 5000);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to reject application';
      setError(message);
    } finally {
      setIsProcessing(false);
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'pending':
        return <Badge variant="warning" dot>Pending</Badge>;
      case 'approved':
        return <Badge variant="success" dot>Approved</Badge>;
      case 'rejected':
        return <Badge variant="danger" dot>Rejected</Badge>;
      case 'suspended':
        return <Badge variant="default" dot>Suspended</Badge>;
      default:
        return <Badge variant="default">{status}</Badge>;
    }
  };

  const filteredApplications = applications.filter(app => {
    if (!searchQuery) return true;
    const query = searchQuery.toLowerCase();
    return (
      app.full_name.toLowerCase().includes(query) ||
      app.state.toLowerCase().includes(query) ||
      app.town.toLowerCase().includes(query) ||
      (app.phone_number?.includes(query)) ||
      (app.email?.toLowerCase().includes(query)) ||
      (app.username?.toLowerCase().includes(query))
    );
  });

  const pendingCount = applications.filter(a => a.status === 'pending').length;

  if (isLoading && !lastUpdated) {
    return (
      <div className="space-y-8">
        <PageHeader
          title="Agent Applications"
          description="Review and manage agent applications"
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
          className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all bg-[var(--color-primary)] text-white"
        >
          <FileText size={16} />
          Applications
          {pendingCount > 0 && (
            <span className="px-2 py-0.5 bg-white/20 text-xs rounded-full">
              {pendingCount}
            </span>
          )}
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

      {/* Filters */}
      <Card>
        <CardContent className="py-4">
          <div className="flex flex-col md:flex-row gap-4">
            <div className="flex-1">
              <Input
                placeholder="Search by name, email, location..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full"
              />
            </div>
            <div className="flex gap-2">
              {['all', 'pending', 'approved', 'rejected'].map((status) => (
                <button
                  key={status}
                  onClick={() => setFilterStatus(status)}
                  className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${
                    filterStatus === status
                      ? 'bg-[var(--color-primary)] text-white'
                      : 'bg-[var(--color-gray-700)] text-[var(--color-gray-300)] hover:bg-[var(--color-gray-600)]'
                  }`}
                >
                  {status.charAt(0).toUpperCase() + status.slice(1)}
                  {status === 'pending' && pendingCount > 0 && (
                    <span className="ml-2 px-2 py-0.5 bg-[var(--color-warning)] text-black text-xs rounded-full">
                      {pendingCount}
                    </span>
                  )}
                </button>
              ))}
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Applications List */}
      <div className="grid gap-4">
        {filteredApplications.length === 0 ? (
          <Card>
            <EmptyState
              title="No applications found"
              description={filterStatus === 'all' 
                ? "There are no agent applications yet." 
                : `No ${filterStatus} applications found.`}
              icon={<User size={48} />}
            />
          </Card>
        ) : (
          filteredApplications.map((application) => (
            <Card key={application.id} className="hover:border-[var(--color-primary)]/30 transition-all">
              <CardContent className="p-6">
                <div className="flex flex-col lg:flex-row lg:items-center gap-4">
                  {/* User Info */}
                  <div className="flex items-center gap-4 flex-1">
                    <div className="w-12 h-12 rounded-full bg-[var(--color-primary)]/20 flex items-center justify-center">
                      {application.avatar_url ? (
                        <img 
                          src={application.avatar_url} 
                          alt={application.full_name}
                          className="w-12 h-12 rounded-full object-cover"
                        />
                      ) : (
                        <User size={24} className="text-[var(--color-primary)]" />
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <h3 className="font-semibold text-[var(--color-text-primary)] truncate">
                          {application.full_name}
                        </h3>
                        {getStatusBadge(application.status)}
                      </div>
                      <p className="text-sm text-[var(--color-gray-400)]">
                        @{application.username || 'unknown'} • {application.email || application.phone_number || 'No contact'}
                      </p>
                    </div>
                  </div>

                  {/* Location */}
                  <div className="flex items-center gap-2 text-sm text-[var(--color-gray-400)]">
                    <MapPin size={14} />
                    <span>{application.town}, {application.state}</span>
                  </div>

                  {/* Business Info */}
                  {application.business_name && (
                    <div className="flex items-center gap-2 text-sm text-[var(--color-gray-400)]">
                      <Building size={14} />
                      <span>{application.business_name}</span>
                    </div>
                  )}

                  {/* Date */}
                  <div className="flex items-center gap-2 text-sm text-[var(--color-gray-400)]">
                    <Calendar size={14} />
                    <span>{new Date(application.created_at).toLocaleDateString()}</span>
                  </div>

                  {/* Actions */}
                  <div className="flex items-center gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setSelectedApplication(application)}
                    >
                      <Eye size={14} className="mr-1" />
                      View
                    </Button>
                    {application.status === 'pending' && (
                      <>
                        <Button
                          variant="success"
                          size="sm"
                          onClick={() => handleApprove(application)}
                          disabled={isProcessing}
                        >
                          <CheckCircle size={14} className="mr-1" />
                          Approve
                        </Button>
                        <Button
                          variant="danger"
                          size="sm"
                          onClick={() => setSelectedApplication(application)}
                          disabled={isProcessing}
                        >
                          <XCircle size={14} className="mr-1" />
                          Reject
                        </Button>
                      </>
                    )}
                  </div>
                </div>

                {/* Rejection Reason */}
                {application.status === 'rejected' && application.rejection_reason && (
                  <div className="mt-4 p-3 bg-[var(--color-danger)]/10 rounded-lg border border-[var(--color-danger)]/20">
                    <p className="text-sm text-[var(--color-danger-light)]">
                      <strong>Rejection Reason:</strong> {application.rejection_reason}
                    </p>
                  </div>
                )}
              </CardContent>
            </Card>
          ))
        )}
      </div>

      {/* Application Detail Modal */}
      {selectedApplication && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
          <div className="bg-[var(--color-gray-800)] rounded-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="p-6 border-b border-[var(--color-gray-700)]">
              <div className="flex items-center justify-between">
                <h2 className="text-xl font-bold text-[var(--color-text-primary)]">
                  Application Details
                </h2>
                <button 
                  onClick={() => {
                    setSelectedApplication(null);
                    setRejectionReason('');
                  }}
                  className="text-[var(--color-gray-400)] hover:text-[var(--color-text-primary)]"
                >
                  ✕
                </button>
              </div>
            </div>
            
            <div className="p-6 space-y-6">
              {/* Personal Info */}
              <div>
                <h3 className="text-sm font-semibold text-[var(--color-gray-400)] uppercase tracking-wide mb-3">
                  Personal Information
                </h3>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="text-xs text-[var(--color-gray-500)]">Full Name</label>
                    <p className="text-[var(--color-text-primary)]">{selectedApplication.full_name}</p>
                  </div>
                  <div>
                    <label className="text-xs text-[var(--color-gray-500)]">Username</label>
                    <p className="text-[var(--color-text-primary)]">@{selectedApplication.username || 'N/A'}</p>
                  </div>
                  <div>
                    <label className="text-xs text-[var(--color-gray-500)]">Phone</label>
                    <p className="text-[var(--color-text-primary)]">{selectedApplication.phone_number || 'N/A'}</p>
                  </div>
                  <div>
                    <label className="text-xs text-[var(--color-gray-500)]">Email</label>
                    <p className="text-[var(--color-text-primary)]">{selectedApplication.email || 'N/A'}</p>
                  </div>
                </div>
              </div>

              {/* Location */}
              <div>
                <h3 className="text-sm font-semibold text-[var(--color-gray-400)] uppercase tracking-wide mb-3">
                  Location
                </h3>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="text-xs text-[var(--color-gray-500)]">State</label>
                    <p className="text-[var(--color-text-primary)]">{selectedApplication.state}</p>
                  </div>
                  <div>
                    <label className="text-xs text-[var(--color-gray-500)]">Town</label>
                    <p className="text-[var(--color-text-primary)]">{selectedApplication.town}</p>
                  </div>
                  <div className="col-span-2">
                    <label className="text-xs text-[var(--color-gray-500)]">Street Address</label>
                    <p className="text-[var(--color-text-primary)]">{selectedApplication.street}</p>
                  </div>
                  {selectedApplication.business_location && (
                    <div className="col-span-2">
                      <label className="text-xs text-[var(--color-gray-500)]">Business Location</label>
                      <p className="text-[var(--color-text-primary)]">{selectedApplication.business_location}</p>
                    </div>
                  )}
                </div>
              </div>

              {/* Business Info */}
              <div>
                <h3 className="text-sm font-semibold text-[var(--color-gray-400)] uppercase tracking-wide mb-3">
                  Business Information
                </h3>
                <div className="grid grid-cols-2 gap-4">
                  {selectedApplication.business_name && (
                    <div>
                      <label className="text-xs text-[var(--color-gray-500)]">Business Name</label>
                      <p className="text-[var(--color-text-primary)]">{selectedApplication.business_name}</p>
                    </div>
                  )}
                  <div>
                    <label className="text-xs text-[var(--color-gray-500)]">Est. Daily Customers</label>
                    <p className="text-[var(--color-text-primary)]">{selectedApplication.estimated_daily_customers || 0}</p>
                  </div>
                  {selectedApplication.business_description && (
                    <div className="col-span-2">
                      <label className="text-xs text-[var(--color-gray-500)]">Business Description</label>
                      <p className="text-[var(--color-text-primary)]">{selectedApplication.business_description}</p>
                    </div>
                  )}
                </div>
              </div>

              {/* Application Status */}
              <div>
                <h3 className="text-sm font-semibold text-[var(--color-gray-400)] uppercase tracking-wide mb-3">
                  Application Status
                </h3>
                <div className="flex items-center gap-4">
                  {getStatusBadge(selectedApplication.status)}
                  <span className="text-sm text-[var(--color-gray-400)]">
                    Submitted on {new Date(selectedApplication.created_at).toLocaleString()}
                  </span>
                </div>
                {selectedApplication.reviewed_at && (
                  <p className="text-sm text-[var(--color-gray-400)] mt-2">
                    Reviewed on {new Date(selectedApplication.reviewed_at).toLocaleString()}
                  </p>
                )}
              </div>

              {/* Rejection Input (for pending applications) */}
              {selectedApplication.status === 'pending' && (
                <div>
                  <h3 className="text-sm font-semibold text-[var(--color-gray-400)] uppercase tracking-wide mb-3">
                    Rejection Reason (if rejecting)
                  </h3>
                  <textarea
                    value={rejectionReason}
                    onChange={(e) => setRejectionReason(e.target.value)}
                    placeholder="Enter reason for rejection..."
                    className="w-full p-3 bg-[var(--color-gray-700)] border border-[var(--color-gray-600)] rounded-lg text-[var(--color-text-primary)] placeholder-[var(--color-gray-500)] focus:ring-2 focus:ring-[var(--color-primary)] focus:border-transparent"
                    rows={3}
                  />
                </div>
              )}
            </div>

            {/* Actions */}
            {selectedApplication.status === 'pending' && (
              <div className="p-6 border-t border-[var(--color-gray-700)] flex gap-3 justify-end">
                <Button
                  variant="outline"
                  onClick={() => {
                    setSelectedApplication(null);
                    setRejectionReason('');
                  }}
                >
                  Cancel
                </Button>
                <Button
                  variant="danger"
                  onClick={() => handleReject(selectedApplication)}
                  disabled={isProcessing || !rejectionReason.trim()}
                  loading={isProcessing}
                >
                  <XCircle size={14} className="mr-1" />
                  Reject Application
                </Button>
                <Button
                  variant="success"
                  onClick={() => handleApprove(selectedApplication)}
                  disabled={isProcessing}
                  loading={isProcessing}
                >
                  <CheckCircle size={14} className="mr-1" />
                  Approve Application
                </Button>
              </div>
            )}
          </div>
        </div>
      )}
      </div>
    </AdminProtection>
  );
}
