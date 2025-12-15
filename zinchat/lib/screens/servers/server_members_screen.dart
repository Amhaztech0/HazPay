import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/server_model.dart';
import '../../services/server_service.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import '../../main.dart';

class ServerMembersScreen extends StatefulWidget {
  final ServerModel server;

  const ServerMembersScreen({
    super.key,
    required this.server,
  });

  @override
  State<ServerMembersScreen> createState() => _ServerMembersScreenState();
}

class _ServerMembersScreenState extends State<ServerMembersScreen> {
  final _serverService = ServerService();
  List<ServerMemberModel> _members = [];
  bool _isLoading = true;
  bool _isCurrentUserAdmin = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _loadMembers();
    _checkAdminStatus();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    final members = await _serverService.getServerMembers(widget.server.id);
    if (mounted) {
      setState(() {
        _members = members;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _serverService.isUserAdmin(widget.server.id);
    if (mounted) {
      setState(() => _isCurrentUserAdmin = isAdmin);
    }
  }

  Future<void> _viewUserProfile(ServerMemberModel member) async {
    if (member.user == null) return;
    
    // Show member details in a dialog
    showDialog(
      context: context,
      builder: (context) {
        final theme = Provider.of<ThemeProvider>(context).currentTheme;
        return AlertDialog(
          backgroundColor: theme.cardBackground,
          title: Text(
            member.user?.fullName ?? 'Unknown User',
            style: AppTextStyles.heading3.copyWith(color: theme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (member.user?.profilePhotoUrl != null) ...[
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(member.user!.profilePhotoUrl!),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                'Role: ${member.role.toUpperCase()}',
                style: AppTextStyles.bodyMedium.copyWith(color: theme.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Joined: ${_formatDate(member.joinedAt)}',
                style: AppTextStyles.bodySmall.copyWith(color: theme.textSecondary),
              ),
              if (member.user?.about != null && member.user!.about!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Bio:',
                  style: AppTextStyles.caption.copyWith(
                    color: theme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  member.user!.about!,
                  style: AppTextStyles.bodySmall.copyWith(color: theme.textPrimary),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeMember(ServerMemberModel member) async {
    // Don't allow removing yourself or the owner
    if (member.userId == _currentUserId) {
      _showMessage('You cannot remove yourself. Use "Leave Server" instead.');
      return;
    }

    if (member.role == 'owner') {
      _showMessage('Cannot remove the server owner.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove this member from the server?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _serverService.removeMember(
        widget.server.id,
        member.userId,
      );

      if (mounted) {
        if (success) {
          _showMessage('Member removed successfully');
          _loadMembers(); // Refresh the list
        } else {
          _showMessage('Failed to remove member');
        }
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Server Members',
          style: AppTextStyles.heading3.copyWith(color: theme.textPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Text(
                '${_members.length} member${_members.length != 1 ? 's' : ''}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: theme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: theme.primaryColor),
            )
          : _members.isEmpty
              ? Center(
                  child: Text(
                    'No members found',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: theme.textSecondary,
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: theme.primaryColor,
                  onRefresh: _loadMembers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final isCurrentUser = member.userId == _currentUserId;
                      final canRemove = _isCurrentUserAdmin &&
                          !isCurrentUser &&
                          member.role != 'owner';

                      return _buildMemberTile(
                        theme,
                        member,
                        isCurrentUser,
                        canRemove,
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildMemberTile(
    dynamic theme,
    ServerMemberModel member,
    bool isCurrentUser,
    bool canRemove,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        leading: GestureDetector(
          onTap: () => _viewUserProfile(member),
          child: CircleAvatar(
            backgroundColor: theme.primaryColor.withOpacity(0.2),
            backgroundImage: member.user?.profilePhotoUrl != null
                ? NetworkImage(member.user!.profilePhotoUrl!)
                : null,
            child: member.user?.profilePhotoUrl == null
                ? Icon(
                    Icons.person,
                    color: theme.primaryColor,
                  )
                : null,
          ),
        ),
        onTap: () => _viewUserProfile(member),
        title: Row(
          children: [
            Expanded(
              child: Text(
                member.user?.fullName ?? 'Unknown User',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: theme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  'You',
                  style: AppTextStyles.caption.copyWith(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Row(
            children: [
              _buildRoleBadge(theme, member.role),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Joined ${_formatDate(member.joinedAt)}',
                style: AppTextStyles.caption.copyWith(
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        trailing: canRemove
            ? IconButton(
                icon: const Icon(Icons.person_remove, color: Colors.red),
                onPressed: () => _removeMember(member),
                tooltip: 'Remove member',
              )
            : null,
      ),
    );
  }

  Widget _buildRoleBadge(dynamic theme, String role) {
    Color badgeColor;
    IconData icon;

    switch (role) {
      case 'owner':
        badgeColor = Colors.amber;
        icon = Icons.star;
        break;
      case 'admin':
        badgeColor = Colors.blue;
        icon = Icons.shield;
        break;
      default:
        badgeColor = theme.textSecondary;
        icon = Icons.person;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks != 1 ? 's' : ''} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months != 1 ? 's' : ''} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years != 1 ? 's' : ''} ago';
    }
  }
}
