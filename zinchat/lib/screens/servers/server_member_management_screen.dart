import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../providers/theme_provider.dart';
import '../../services/server_service.dart';
import '../../models/server_model.dart';
import '../../models/server_moderation_model.dart';

class ServerMemberManagementScreen extends StatefulWidget {
  final ServerModel server;
  final bool isAdmin;

  const ServerMemberManagementScreen({
    super.key,
    required this.server,
    required this.isAdmin,
  });

  @override
  State<ServerMemberManagementScreen> createState() => _ServerMemberManagementScreenState();
}

class _ServerMemberManagementScreenState extends State<ServerMemberManagementScreen> with SingleTickerProviderStateMixin {
  final _serverService = ServerService();
  late TabController _tabController;
  
  List<ServerMemberModel> _members = [];
  List<ServerModerationModel> _moderationRecords = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final members = await _serverService.getServerMembers(widget.server.id);
      final moderation = await _serverService.getServerModeration(widget.server.id);
      
      if (mounted) {
        setState(() {
          _members = members;
          _moderationRecords = moderation;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  Future<void> _showMemberActions(ServerMemberModel member) async {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    
    // Can't moderate the owner or yourself
    final currentUserId = _serverService.supabase.auth.currentUser?.id;
    if (member.role == 'owner' || member.userId == currentUserId) {
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.textLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Member Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.primaryColor.withOpacity(0.2),
                    backgroundImage: member.user?.profilePhotoUrl != null
                        ? NetworkImage(member.user!.profilePhotoUrl!)
                        : null,
                    child: member.user?.profilePhotoUrl == null
                        ? Text(
                            member.user?.fullName?.substring(0, 1).toUpperCase() ?? 'U',
                            style: AppTextStyles.heading3.copyWith(color: theme.primaryColor),
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.user?.fullName ?? 'Unknown User',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          _getRoleBadge(member.role),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _getRoleColor(member.role, theme),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.lg),
            const Divider(height: 1),
            
            // Moderation Actions
            if (widget.isAdmin) ...[
              _buildActionTile(
                icon: Icons.block_rounded,
                title: 'Ban Member',
                subtitle: 'Permanently remove from server',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _showBanDialog(member);
                },
              ),
              _buildActionTile(
                icon: Icons.volume_off_rounded,
                title: 'Mute Member',
                subtitle: 'Prevent from sending messages',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _showMuteDialog(member);
                },
              ),
              _buildActionTile(
                icon: Icons.timer_rounded,
                title: 'Timeout Member',
                subtitle: 'Temporary restriction (5 minutes)',
                color: Colors.amber,
                onTap: () {
                  Navigator.pop(context);
                  _timeoutMember(member);
                },
              ),
              if (member.role == 'member' && widget.server.ownerId == currentUserId)
                _buildActionTile(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Promote to Admin',
                  subtitle: 'Grant admin privileges',
                  color: theme.primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    _promoteToAdmin(member);
                  },
                ),
              if (member.role == 'admin' && widget.server.ownerId == currentUserId)
                _buildActionTile(
                  icon: Icons.remove_moderator_rounded,
                  title: 'Demote to Member',
                  subtitle: 'Remove admin privileges',
                  color: theme.textSecondary,
                  onTap: () {
                    Navigator.pop(context);
                    _demoteToMember(member);
                  },
                ),
            ],
            
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall.copyWith(
          color: theme.textSecondary,
        ),
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }

  Future<void> _showBanDialog(ServerMemberModel member) async {
    final reasonController = TextEditingController();
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        title: Text(
          'Ban ${member.user?.fullName ?? 'this member'}?',
          style: AppTextStyles.heading3.copyWith(color: theme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This will permanently remove them from the server and prevent them from rejoining.',
              style: AppTextStyles.bodyMedium.copyWith(color: theme.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              style: AppTextStyles.bodyMedium.copyWith(color: theme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Reason (optional)',
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: theme.textLight),
                filled: true,
                fillColor: theme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ban', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _serverService.banUser(
        serverId: widget.server.id,
        userId: member.userId,
        reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member banned successfully')),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to ban member: ${result['error']}')),
          );
        }
      }
    }
  }

  Future<void> _showMuteDialog(ServerMemberModel member) async {
    final reasonController = TextEditingController();
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    int? selectedDuration;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          title: Text(
            'Mute ${member.user?.fullName ?? 'this member'}?',
            style: AppTextStyles.heading3.copyWith(color: theme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This will prevent them from sending messages.',
                style: AppTextStyles.bodyMedium.copyWith(color: theme.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Duration options
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: const Text('10 min'),
                    selected: selectedDuration == 10,
                    onSelected: (selected) => setDialogState(() => selectedDuration = selected ? 10 : null),
                  ),
                  ChoiceChip(
                    label: const Text('1 hour'),
                    selected: selectedDuration == 60,
                    onSelected: (selected) => setDialogState(() => selectedDuration = selected ? 60 : null),
                  ),
                  ChoiceChip(
                    label: const Text('24 hours'),
                    selected: selectedDuration == 1440,
                    onSelected: (selected) => setDialogState(() => selectedDuration = selected ? 1440 : null),
                  ),
                  ChoiceChip(
                    label: const Text('Permanent'),
                    selected: selectedDuration == null,
                    onSelected: (selected) => setDialogState(() => selectedDuration = null),
                  ),
                ],
              ),
              
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: reasonController,
                style: AppTextStyles.bodyMedium.copyWith(color: theme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Reason (optional)',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: theme.textLight),
                  filled: true,
                  fillColor: theme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Mute', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final result = await _serverService.muteUser(
        serverId: widget.server.id,
        userId: member.userId,
        reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
        durationMinutes: selectedDuration,
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member muted successfully')),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to mute member: ${result['error']}')),
          );
        }
      }
    }
  }

  Future<void> _timeoutMember(ServerMemberModel member) async {
    final result = await _serverService.timeoutUser(
      serverId: widget.server.id,
      userId: member.userId,
      durationMinutes: 5,
    );

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member timed out for 5 minutes')),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to timeout member: ${result['error']}')),
        );
      }
    }
  }

  Future<void> _promoteToAdmin(ServerMemberModel member) async {
    // TODO: Implement promote to admin (needs server function)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Promotion feature coming soon!')),
    );
  }

  Future<void> _demoteToMember(ServerMemberModel member) async {
    // TODO: Implement demote to member (needs server function)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demotion feature coming soon!')),
    );
  }

  String _getRoleBadge(String role) {
    switch (role) {
      case 'owner':
        return '👑 Owner';
      case 'admin':
        return '⭐ Admin';
      default:
        return '👤 Member';
    }
  }

  Color _getRoleColor(String role, theme) {
    switch (role) {
      case 'owner':
        return Colors.amber;
      case 'admin':
        return theme.primaryColor;
      default:
        return theme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.currentTheme;

        return Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            backgroundColor: theme.background,
            title: ShaderMask(
              shaderCallback: (bounds) => theme.primaryGradient.createShader(bounds),
              child: Text(
                'Manage Members',
                style: AppTextStyles.heading2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: theme.primaryColor,
              labelColor: theme.primaryColor,
              unselectedLabelColor: theme.textSecondary,
              tabs: const [
                Tab(text: 'Members'),
                Tab(text: 'Moderation Log'),
              ],
            ),
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMembersTab(theme),
                    _buildModerationTab(theme),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildMembersTab(theme) {
    if (_members.isEmpty) {
      return Center(
        child: Text(
          'No members found',
          style: AppTextStyles.bodyMedium.copyWith(color: theme.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _members.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final member = _members[index];
        final currentUserId = _serverService.supabase.auth.currentUser?.id;
        final canModerate = widget.isAdmin && member.role != 'owner' && member.userId != currentUserId;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.primaryColor.withOpacity(0.2),
            backgroundImage: member.user?.profilePhotoUrl != null
                ? NetworkImage(member.user!.profilePhotoUrl!)
                : null,
            child: member.user?.profilePhotoUrl == null
                ? Text(
                    member.user?.fullName?.substring(0, 1).toUpperCase() ?? 'U',
                    style: AppTextStyles.bodyLarge.copyWith(color: theme.primaryColor),
                  )
                : null,
          ),
          title: Text(
            member.user?.fullName ?? 'Unknown User',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.textPrimary,
            ),
          ),
          subtitle: Text(
            _getRoleBadge(member.role),
            style: AppTextStyles.bodySmall.copyWith(
              color: _getRoleColor(member.role, theme),
            ),
          ),
          trailing: canModerate
              ? IconButton(
                  icon: Icon(Icons.more_vert_rounded, color: theme.textSecondary),
                  onPressed: () => _showMemberActions(member),
                )
              : null,
        );
      },
    );
  }

  Widget _buildModerationTab(theme) {
    if (_moderationRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: theme.textLight),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No moderation actions yet',
              style: AppTextStyles.bodyMedium.copyWith(color: theme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _moderationRecords.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final record = _moderationRecords[index];
        IconData icon;
        Color color;

        switch (record.moderationType) {
          case 'ban':
            icon = Icons.block_rounded;
            color = Colors.red;
            break;
          case 'mute':
            icon = Icons.volume_off_rounded;
            color = Colors.orange;
            break;
          case 'timeout':
            icon = Icons.timer_rounded;
            color = Colors.amber;
            break;
          default:
            icon = Icons.info_outline;
            color = theme.textSecondary;
        }

        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    record.moderationType.toUpperCase(),
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const Spacer(),
                  if (!record.isPermanent && !record.isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Text(
                        record.formattedDuration,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
              if (record.reason != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  record.reason!,
                  style: AppTextStyles.bodyMedium.copyWith(color: theme.textPrimary),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                'User ID: ${record.userId.substring(0, 8)}...',
                style: AppTextStyles.bodySmall.copyWith(color: theme.textSecondary),
              ),
              Text(
                'Created: ${_formatDate(record.createdAt)}',
                style: AppTextStyles.bodySmall.copyWith(color: theme.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
