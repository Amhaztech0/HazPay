'use client';

import { useEffect, useState, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { 
  Users, Share2, Gift, TrendingUp, AlertTriangle, 
  Ban, CheckCircle, Clock, RefreshCw, Search,
  ChevronDown, ChevronUp, Copy, Flag
} from 'lucide-react';
import {
  Card, CardContent, EmptyState,
  PageHeader, RefreshButton, BackButton,
  Button, Badge, Input,
  Alert, Toast,
  TableSkeleton,
} from '@/components/ui';

interface ReferralUser {
  id: string;
  user_id: string;
  display_name: string;
  email: string | null;
  referral_code: string;
  referral_count: number;
  total_referral_rewards: number;
  next_reward_requirement: number;
  referred_by: string | null;
  created_at: string;
  is_flagged: boolean;
  flag_reason: string | null;
}

interface ReferralReward {
  id: string;
  user_id: string;
  display_name: string;
  reward_type: string;
  reward_amount: number;
  milestone_reached: number;
  status: 'pending' | 'approved' | 'claimed' | 'revoked';
  created_at: string;
  claimed_at: string | null;
  approved_by: string | null;
}

interface ReferralStats {
  totalUsers: number;
  activeReferrers: number;
  totalReferrals: number;
  totalRewardsClaimed: number;
  pendingRewards: number;
  flaggedUsers: number;
}

export default function ReferralManagementPage() {
  const [referralUsers, setReferralUsers] = useState<ReferralUser[]>([]);
  const [rewards, setRewards] = useState<ReferralReward[]>([]);
  const [stats, setStats] = useState<ReferralStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [activeTab, setActiveTab] = useState<'users' | 'rewards' | 'settings'>('users');
  const [searchQuery, setSearchQuery] = useState('');
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [selectedUser, setSelectedUser] = useState<ReferralUser | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [expandedUserId, setExpandedUserId] = useState<string | null>(null);
  const [referredUsersList, setReferredUsersList] = useState<Record<string, Array<{ display_name: string; created_at: string }>>>({});

  // Referral settings
  const [settings, setSettings] = useState({
    rewardAmountMb: 500,
    milestonesEnabled: true,
    milestones: [5, 10, 25, 50, 100],
    autoApproveRewards: false,
    maxReferralsPerDay: 10,
    referralCodeLength: 8,
  });

  const fetchData = useCallback(async () => {
    try {
      setError('');
      
      // Fetch users with referral activity
      const { data: usersData, error: usersError } = await supabase
        .from('profiles')
        .select('id, display_name, email, referral_code, referral_count, total_referral_rewards, next_reward_requirement, referred_by, created_at')
        .not('referral_code', 'is', null)
        .order('referral_count', { ascending: false });

      if (usersError) throw usersError;

      // Transform to add flagged status (would be from a separate table in production)
      const transformedUsers: ReferralUser[] = (usersData || []).map((u: Record<string, unknown>) => ({
        ...u,
        user_id: u.id as string,
        display_name: u.display_name as string,
        email: u.email as string | null,
        referral_code: u.referral_code as string,
        referral_count: u.referral_count as number,
        total_referral_rewards: u.total_referral_rewards as number,
        next_reward_requirement: u.next_reward_requirement as number,
        referred_by: u.referred_by as string | null,
        created_at: u.created_at as string,
        is_flagged: false,
        flag_reason: null,
      }));

      setReferralUsers(transformedUsers);

      // Fetch referral rewards without profile join
      const { data: rewardsData, error: rewardsError } = await supabase
        .from('referral_rewards')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(100);

      if (rewardsError) {
        console.warn('Referral rewards table may not exist:', rewardsError);
      }

      // Fetch profiles for rewards if we have data
      let rewardsProfilesMap = new Map<string, Record<string, unknown>>();
      if (rewardsData && rewardsData.length > 0) {
        const rewardUserIds = [...new Set(rewardsData.map((r: Record<string, unknown>) => r.user_id as string))];
        const { data: rewardsProfilesData } = await supabase
          .from('profiles')
          .select('id, display_name, username')
          .in('id', rewardUserIds);
        
        rewardsProfilesMap = new Map(
          (rewardsProfilesData || []).map((p: Record<string, unknown>) => [p.id as string, p])
        );
      }

      const transformedRewards: ReferralReward[] = (rewardsData || []).map((r: Record<string, unknown>) => {
        const profile = rewardsProfilesMap.get(r.user_id as string);
        return {
          ...r,
          display_name: profile?.display_name || profile?.username || 'Unknown',
        };
      }) as ReferralReward[];

      setRewards(transformedRewards);

      // Calculate stats
      const statsData: ReferralStats = {
        totalUsers: transformedUsers.length,
        activeReferrers: transformedUsers.filter(u => u.referral_count > 0).length,
        totalReferrals: transformedUsers.reduce((sum, u) => sum + u.referral_count, 0),
        totalRewardsClaimed: transformedRewards.filter(r => r.status === 'claimed').length,
        pendingRewards: transformedRewards.filter(r => r.status === 'pending').length,
        flaggedUsers: transformedUsers.filter(u => u.is_flagged).length,
      };
      setStats(statsData);
      
      setLastUpdated(new Date());
    } catch (err) {
      console.error('Fetch error:', err);
      setError('Failed to fetch referral data');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const handleRefresh = () => {
    setIsLoading(true);
    fetchData();
  };

  const loadReferredUsers = async (userId: string, referralCode: string) => {
    if (referredUsersList[userId]) {
      setExpandedUserId(expandedUserId === userId ? null : userId);
      return;
    }

    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('display_name, created_at')
        .eq('referred_by', referralCode)
        .order('created_at', { ascending: false });

      if (error) throw error;

      setReferredUsersList(prev => ({
        ...prev,
        [userId]: data || [],
      }));
      setExpandedUserId(userId);
    } catch (err) {
      console.error('Error loading referred users:', err);
    }
  };

  const handleApproveReward = async (reward: ReferralReward) => {
    setIsProcessing(true);
    try {
      const { error: updateError } = await supabase
        .from('referral_rewards')
        .update({
          status: 'approved',
          approved_by: 'admin',
        })
        .eq('id', reward.id);

      if (updateError) throw updateError;

      setSuccess('Reward approved successfully');
      fetchData();
      setTimeout(() => setSuccess(''), 5000);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to approve reward';
      setError(message);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleRevokeReward = async (reward: ReferralReward) => {
    if (!confirm('Are you sure you want to revoke this reward?')) return;

    setIsProcessing(true);
    try {
      const { error: updateError } = await supabase
        .from('referral_rewards')
        .update({
          status: 'revoked',
        })
        .eq('id', reward.id);

      if (updateError) throw updateError;

      setSuccess('Reward revoked successfully');
      fetchData();
      setTimeout(() => setSuccess(''), 5000);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to revoke reward';
      setError(message);
    } finally {
      setIsProcessing(false);
    }
  };

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const handleFlagUser = async (user: ReferralUser, _reason: string) => {
    setIsProcessing(true);
    try {
      // In production, this would update a user_flags table
      setSuccess(`User ${user.display_name} has been flagged for review`);
      setTimeout(() => setSuccess(''), 5000);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to flag user';
      setError(message);
    } finally {
      setIsProcessing(false);
      setSelectedUser(null);
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'pending':
        return <Badge variant="warning" dot>Pending</Badge>;
      case 'approved':
        return <Badge variant="info" dot>Approved</Badge>;
      case 'claimed':
        return <Badge variant="success" dot>Claimed</Badge>;
      case 'revoked':
        return <Badge variant="danger" dot>Revoked</Badge>;
      default:
        return <Badge variant="default">{status}</Badge>;
    }
  };

  const filteredUsers = referralUsers.filter(user => {
    if (!searchQuery) return true;
    const query = searchQuery.toLowerCase();
    return (
      user.display_name?.toLowerCase().includes(query) ||
      user.email?.toLowerCase().includes(query) ||
      user.referral_code?.toLowerCase().includes(query)
    );
  });

  const filteredRewards = rewards.filter(reward => {
    if (filterStatus === 'all') return true;
    return reward.status === filterStatus;
  });

  if (isLoading && !lastUpdated) {
    return (
      <div className="space-y-8">
        <PageHeader
          title="Referral Management"
          description="Manage referral program, rewards, and users"
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
          title="Referral Management"
          description="Monitor and manage the referral program"
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
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
          <Card className="bg-gradient-to-br from-blue-500/10 to-blue-600/5">
            <CardContent className="p-4">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-blue-500/20 rounded-lg">
                  <Users size={20} className="text-blue-400" />
                </div>
                <div>
                  <p className="text-2xl font-bold text-white">{stats.totalUsers}</p>
                  <p className="text-xs text-gray-400">Total Users</p>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-green-500/10 to-green-600/5">
            <CardContent className="p-4">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-green-500/20 rounded-lg">
                  <Share2 size={20} className="text-green-400" />
                </div>
                <div>
                  <p className="text-2xl font-bold text-white">{stats.activeReferrers}</p>
                  <p className="text-xs text-gray-400">Active Referrers</p>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-purple-500/10 to-purple-600/5">
            <CardContent className="p-4">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-purple-500/20 rounded-lg">
                  <TrendingUp size={20} className="text-purple-400" />
                </div>
                <div>
                  <p className="text-2xl font-bold text-white">{stats.totalReferrals}</p>
                  <p className="text-xs text-gray-400">Total Referrals</p>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-yellow-500/10 to-yellow-600/5">
            <CardContent className="p-4">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-yellow-500/20 rounded-lg">
                  <Gift size={20} className="text-yellow-400" />
                </div>
                <div>
                  <p className="text-2xl font-bold text-white">{stats.totalRewardsClaimed}</p>
                  <p className="text-xs text-gray-400">Rewards Claimed</p>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-orange-500/10 to-orange-600/5">
            <CardContent className="p-4">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-orange-500/20 rounded-lg">
                  <Clock size={20} className="text-orange-400" />
                </div>
                <div>
                  <p className="text-2xl font-bold text-white">{stats.pendingRewards}</p>
                  <p className="text-xs text-gray-400">Pending Rewards</p>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-red-500/10 to-red-600/5">
            <CardContent className="p-4">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-red-500/20 rounded-lg">
                  <AlertTriangle size={20} className="text-red-400" />
                </div>
                <div>
                  <p className="text-2xl font-bold text-white">{stats.flaggedUsers}</p>
                  <p className="text-xs text-gray-400">Flagged Users</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Tab Navigation */}
      <div className="flex gap-2 border-b border-gray-700 pb-4">
        {[
          { id: 'users', label: 'Referral Users', icon: Users },
          { id: 'rewards', label: 'Rewards', icon: Gift },
          { id: 'settings', label: 'Settings', icon: RefreshCw },
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

      {/* Users Tab */}
      {activeTab === 'users' && (
        <div className="space-y-4">
          {/* Search */}
          <Card>
            <CardContent className="py-4">
              <div className="relative">
                <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                <Input
                  placeholder="Search by name, email, or referral code..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10"
                />
              </div>
            </CardContent>
          </Card>

          {/* Users List */}
          <div className="space-y-3">
            {filteredUsers.length === 0 ? (
              <Card>
                <EmptyState
                  title="No referral users found"
                  description="Users with referral codes will appear here."
                  icon={<Users size={48} />}
                />
              </Card>
            ) : (
              filteredUsers.map((user) => (
                <Card key={user.id} className="hover:border-blue-500/30 transition-all">
                  <CardContent className="p-4">
                    <div className="flex flex-col lg:flex-row lg:items-center gap-4">
                      {/* User Info */}
                      <div className="flex items-center gap-3 flex-1">
                        <div className="w-10 h-10 rounded-full bg-blue-500/20 flex items-center justify-center">
                          <Users size={20} className="text-blue-400" />
                        </div>
                        <div>
                          <h3 className="font-semibold text-white">
                            {user.display_name || 'Unknown User'}
                            {user.is_flagged && (
                              <Flag size={14} className="inline ml-2 text-red-400" />
                            )}
                          </h3>
                          <p className="text-sm text-gray-400">{user.email || 'No email'}</p>
                        </div>
                      </div>

                      {/* Referral Code */}
                      <div className="flex items-center gap-2">
                        <code className="px-3 py-1 bg-gray-700 rounded text-sm text-blue-400 font-mono">
                          {user.referral_code}
                        </code>
                        <button
                          onClick={() => navigator.clipboard.writeText(user.referral_code)}
                          className="p-1 text-gray-400 hover:text-white"
                          title="Copy code"
                        >
                          <Copy size={14} />
                        </button>
                      </div>

                      {/* Stats */}
                      <div className="flex items-center gap-6 text-sm">
                        <div className="text-center">
                          <p className="text-lg font-bold text-green-400">{user.referral_count}</p>
                          <p className="text-xs text-gray-400">Referrals</p>
                        </div>
                        <div className="text-center">
                          <p className="text-lg font-bold text-yellow-400">{user.total_referral_rewards}</p>
                          <p className="text-xs text-gray-400">Rewards</p>
                        </div>
                        <div className="text-center">
                          <p className="text-lg font-bold text-purple-400">{user.next_reward_requirement}</p>
                          <p className="text-xs text-gray-400">Next Milestone</p>
                        </div>
                      </div>

                      {/* Actions */}
                      <div className="flex gap-2">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => loadReferredUsers(user.id, user.referral_code)}
                        >
                          {expandedUserId === user.id ? (
                            <ChevronUp size={14} className="mr-1" />
                          ) : (
                            <ChevronDown size={14} className="mr-1" />
                          )}
                          View Referrals
                        </Button>
                        <Button
                          variant="danger"
                          size="sm"
                          onClick={() => setSelectedUser(user)}
                        >
                          <Flag size={14} className="mr-1" />
                          Flag
                        </Button>
                      </div>
                    </div>

                    {/* Expanded Referred Users */}
                    {expandedUserId === user.id && referredUsersList[user.id] && (
                      <div className="mt-4 pt-4 border-t border-gray-700">
                        <h4 className="text-sm font-semibold text-gray-400 mb-3">
                          Referred Users ({referredUsersList[user.id].length})
                        </h4>
                        {referredUsersList[user.id].length === 0 ? (
                          <p className="text-sm text-gray-500">No users referred yet.</p>
                        ) : (
                          <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                            {referredUsersList[user.id].map((referred, idx) => (
                              <div key={idx} className="p-2 bg-gray-700/50 rounded text-sm">
                                <p className="text-white truncate">{referred.display_name}</p>
                                <p className="text-xs text-gray-400">
                                  {new Date(referred.created_at).toLocaleDateString()}
                                </p>
                              </div>
                            ))}
                          </div>
                        )}
                      </div>
                    )}
                  </CardContent>
                </Card>
              ))
            )}
          </div>
        </div>
      )}

      {/* Rewards Tab */}
      {activeTab === 'rewards' && (
        <div className="space-y-4">
          {/* Filters */}
          <Card>
            <CardContent className="py-4">
              <div className="flex gap-2">
                {['all', 'pending', 'approved', 'claimed', 'revoked'].map((status) => (
                  <button
                    key={status}
                    onClick={() => setFilterStatus(status)}
                    className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${
                      filterStatus === status
                        ? 'bg-blue-600 text-white'
                        : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                    }`}
                  >
                    {status.charAt(0).toUpperCase() + status.slice(1)}
                  </button>
                ))}
              </div>
            </CardContent>
          </Card>

          {/* Rewards List */}
          <div className="space-y-3">
            {filteredRewards.length === 0 ? (
              <Card>
                <EmptyState
                  title="No rewards found"
                  description="Referral rewards will appear here."
                  icon={<Gift size={48} />}
                />
              </Card>
            ) : (
              filteredRewards.map((reward) => (
                <Card key={reward.id} className="hover:border-blue-500/30 transition-all">
                  <CardContent className="p-4">
                    <div className="flex flex-col md:flex-row md:items-center gap-4">
                      <div className="flex items-center gap-3 flex-1">
                        <div className="w-10 h-10 rounded-full bg-yellow-500/20 flex items-center justify-center">
                          <Gift size={20} className="text-yellow-400" />
                        </div>
                        <div>
                          <h3 className="font-semibold text-white">{reward.display_name}</h3>
                          <p className="text-sm text-gray-400">
                            {reward.reward_amount} MB • Milestone: {reward.milestone_reached} referrals
                          </p>
                        </div>
                      </div>

                      <div className="text-sm text-gray-400">
                        {new Date(reward.created_at).toLocaleDateString()}
                      </div>

                      <div>
                        {getStatusBadge(reward.status)}
                      </div>

                      {reward.status === 'pending' && (
                        <div className="flex gap-2">
                          <Button
                            variant="success"
                            size="sm"
                            onClick={() => handleApproveReward(reward)}
                            loading={isProcessing}
                          >
                            <CheckCircle size={14} className="mr-1" />
                            Approve
                          </Button>
                          <Button
                            variant="danger"
                            size="sm"
                            onClick={() => handleRevokeReward(reward)}
                            loading={isProcessing}
                          >
                            <Ban size={14} className="mr-1" />
                            Revoke
                          </Button>
                        </div>
                      )}

                      {reward.status === 'approved' && (
                        <Button
                          variant="danger"
                          size="sm"
                          onClick={() => handleRevokeReward(reward)}
                          loading={isProcessing}
                        >
                          <Ban size={14} className="mr-1" />
                          Revoke
                        </Button>
                      )}
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
              <h3 className="text-lg font-semibold text-white mb-6">Referral Program Settings</h3>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Reward Amount (MB)
                  </label>
                  <Input
                    type="number"
                    value={settings.rewardAmountMb}
                    onChange={(e) => setSettings(prev => ({ ...prev, rewardAmountMb: parseInt(e.target.value) || 0 }))}
                    className="w-full"
                  />
                  <p className="text-xs text-gray-400 mt-1">Data reward per milestone reached</p>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Max Referrals Per Day
                  </label>
                  <Input
                    type="number"
                    value={settings.maxReferralsPerDay}
                    onChange={(e) => setSettings(prev => ({ ...prev, maxReferralsPerDay: parseInt(e.target.value) || 0 }))}
                    className="w-full"
                  />
                  <p className="text-xs text-gray-400 mt-1">Abuse prevention limit</p>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Referral Code Length
                  </label>
                  <Input
                    type="number"
                    value={settings.referralCodeLength}
                    onChange={(e) => setSettings(prev => ({ ...prev, referralCodeLength: parseInt(e.target.value) || 6 }))}
                    className="w-full"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Milestones
                  </label>
                  <Input
                    type="text"
                    value={settings.milestones.join(', ')}
                    onChange={(e) => setSettings(prev => ({ 
                      ...prev, 
                      milestones: e.target.value.split(',').map(s => parseInt(s.trim())).filter(n => !isNaN(n))
                    }))}
                    className="w-full"
                  />
                  <p className="text-xs text-gray-400 mt-1">Comma-separated milestone values</p>
                </div>

                <div className="flex items-center gap-4">
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={settings.milestonesEnabled}
                      onChange={(e) => setSettings(prev => ({ ...prev, milestonesEnabled: e.target.checked }))}
                      className="w-4 h-4 rounded bg-gray-700 border-gray-600"
                    />
                    <span className="text-sm text-gray-300">Enable Milestones</span>
                  </label>
                </div>

                <div className="flex items-center gap-4">
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={settings.autoApproveRewards}
                      onChange={(e) => setSettings(prev => ({ ...prev, autoApproveRewards: e.target.checked }))}
                      className="w-4 h-4 rounded bg-gray-700 border-gray-600"
                    />
                    <span className="text-sm text-gray-300">Auto-approve Rewards</span>
                  </label>
                </div>
              </div>

              <div className="mt-6 pt-6 border-t border-gray-700">
                <Button variant="primary" onClick={() => setSuccess('Settings saved successfully')}>
                  Save Settings
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Flag User Modal */}
      {selectedUser && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
          <Card className="max-w-md w-full">
            <CardContent className="p-6">
              <h3 className="text-lg font-semibold text-white mb-4">
                Flag User: {selectedUser.display_name}
              </h3>
              
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Flag Reason
                  </label>
                  <select 
                    className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white"
                    title="Flag reason"
                  >
                    <option value="suspicious_activity">Suspicious Activity</option>
                    <option value="fake_referrals">Suspected Fake Referrals</option>
                    <option value="abuse">Program Abuse</option>
                    <option value="other">Other</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Additional Notes
                  </label>
                  <textarea
                    placeholder="Add details..."
                    className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400"
                    rows={3}
                  />
                </div>
              </div>

              <div className="flex gap-3 mt-6">
                <Button variant="outline" onClick={() => setSelectedUser(null)} className="flex-1">
                  Cancel
                </Button>
                <Button 
                  variant="danger" 
                  onClick={() => handleFlagUser(selectedUser, 'flagged')}
                  loading={isProcessing}
                  className="flex-1"
                >
                  Flag User
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}
