import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../providers/theme_provider.dart';
import '../../services/server_service.dart';
import '../../models/server_model.dart';

class ServerInvitesScreen extends StatefulWidget {
  final String serverId;
  final String serverName;

  const ServerInvitesScreen({
    super.key,
    required this.serverId,
    required this.serverName,
  });

  @override
  State<ServerInvitesScreen> createState() => _ServerInvitesScreenState();
}

class _ServerInvitesScreenState extends State<ServerInvitesScreen> {
  final _serverService = ServerService();
  List<ServerInviteModel> _invites = [];
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    setState(() => _isLoading = true);
    final invites = await _serverService.getServerInvites(widget.serverId);
    if (mounted) {
      setState(() {
        _invites = invites;
        _isLoading = false;
      });
    }
  }

  Future<void> _createInvite() async {
    setState(() => _isCreating = true);

    final invite = await _serverService.createInvite(
      serverId: widget.serverId,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      maxUses: null, // Unlimited uses
    );

    if (mounted) {
      setState(() => _isCreating = false);

      if (invite != null) {
        _loadInvites();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite created!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create invite')),
        );
      }
    }
  }

  Future<void> _copyInviteCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invite code copied!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareInvite(String code) async {
    HapticFeedback.mediumImpact();
    // Fallback: Show dialog with invite text to copy
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Share Invite',
          style: TextStyle(color: Colors.white),
        ),
        content: SelectableText(
          'Join ${widget.serverName} on ZinChat!\nInvite code: $code',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppColors.electricTeal)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteInvite(ServerInviteModel invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invite'),
        content: const Text('Are you sure you want to deactivate this invite?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _serverService.deactivateInvite(invite.id);
      if (mounted) {
        if (success) {
          _loadInvites();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invite deactivated')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to deactivate invite')),
          );
        }
      }
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
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
            title: ShaderMask(
              shaderCallback: (bounds) =>
                  theme.primaryGradient.createShader(bounds),
              child: Text(
                'Server Invites',
                style: AppTextStyles.heading2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.add_circle_rounded, color: theme.primaryColor),
                onPressed: _isCreating ? null : _createInvite,
              ),
            ],
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                )
              : _invites.isEmpty
                  ? _buildEmptyState(theme)
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _invites.length,
                      itemBuilder: (context, index) {
                        return _buildInviteCard(theme, _invites[index]);
                      },
                    ),
        );
      },
    );
  }

  Widget _buildEmptyState(dynamic theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_rounded,
              size: 80,
              color: theme.primaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Active Invites',
              style: AppTextStyles.heading2.copyWith(
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create an invite link to let others join this server',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: _isCreating ? null : _createInvite,
              icon: _isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(_isCreating ? 'Creating...' : 'Create Invite'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: theme.background,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard(dynamic theme, ServerInviteModel invite) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Invite Code
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Text(
                  invite.inviteCode,
                  style: AppTextStyles.heading3.copyWith(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const Spacer(),
              // Copy Button
              IconButton(
                icon: Icon(Icons.copy_rounded, color: theme.textSecondary),
                onPressed: () => _copyInviteCode(invite.inviteCode),
                tooltip: 'Copy',
              ),
              // Share Button
              IconButton(
                icon: Icon(Icons.share_rounded, color: theme.textSecondary),
                onPressed: () => _shareInvite(invite.inviteCode),
                tooltip: 'Share',
              ),
              // Delete Button
              IconButton(
                icon: Icon(Icons.delete_rounded, color: Colors.red.shade400),
                onPressed: () => _deleteInvite(invite),
                tooltip: 'Delete',
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Invite Details
          Row(
            children: [
              Icon(Icons.people_rounded, size: 14, color: theme.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${invite.currentUses} uses',
                style: AppTextStyles.bodySmall.copyWith(
                  color: theme.textSecondary,
                ),
              ),
              if (invite.maxUses != null) ...[
                Text(
                  ' / ${invite.maxUses}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: theme.textSecondary,
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.md),
              Icon(Icons.schedule_rounded, size: 14, color: theme.textSecondary),
              const SizedBox(width: 4),
              Text(
                invite.expiresAt != null
                    ? 'Expires ${_formatExpiry(invite.expiresAt!)}'
                    : 'Never expires',
                style: AppTextStyles.bodySmall.copyWith(
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),

          // Status Badge
          if (!invite.isValid) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Text(
                invite.isExpired
                    ? 'EXPIRED'
                    : invite.isMaxedOut
                        ? 'MAX USES REACHED'
                        : 'INACTIVE',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatExpiry(DateTime expiresAt) {
    final now = DateTime.now();
    final difference = expiresAt.difference(now);

    if (difference.inDays > 0) {
      return 'in ${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return 'in ${difference.inMinutes}m';
    } else {
      return 'soon';
    }
  }
}
