import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../utils/constants.dart';
import '../../services/privacy_service.dart';
import '../../models/blocked_user_model.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _privacyService = PrivacyService();
  List<BlockedUser> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _isLoading = true);
    
    try {
      final blockedUsers = await _privacyService.getBlockedUsers();
      if (mounted) {
        setState(() {
          _blockedUsers = blockedUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load blocked users: $e')),
        );
      }
    }
  }

  Future<void> _unblockUser(BlockedUser blockedUser) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User'),
        content: Text(
          'Do you want to unblock ${blockedUser.blockedUser?.displayName ?? 'this user'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _privacyService.unblockUser(blockedUser.blockedId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unblocked ${blockedUser.blockedUser?.displayName ?? 'user'}',
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
        _loadBlockedUsers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Contacts'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadBlockedUsers,
                  color: AppColors.primaryGreen,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _blockedUsers.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final blockedUser = _blockedUsers[index];
                      final user = blockedUser.blockedUser;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primaryLight,
                          backgroundImage: user?.profilePhotoUrl != null
                              ? NetworkImage(user!.profilePhotoUrl!)
                              : null,
                          child: user?.profilePhotoUrl == null
                              ? Text(
                                  user?.displayName.isNotEmpty == true
                                      ? user!.displayName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          user?.displayName ?? 'Unknown User',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          'Blocked ${timeago.format(blockedUser.createdAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _unblockUser(blockedUser),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                          ),
                          child: const Text('Unblock'),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Blocked Users',
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Users you block will appear here',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
