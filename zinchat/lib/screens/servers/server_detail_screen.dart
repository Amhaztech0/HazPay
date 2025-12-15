import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../providers/theme_provider.dart';
import '../../models/server_model.dart';
import '../../services/server_service.dart';
import '../../main.dart';
import 'server_chat_screen.dart';
import 'server_invites_screen.dart';
import 'server_members_screen.dart';
import 'edit_server_screen.dart';

class ServerDetailScreen extends StatefulWidget {
  final ServerModel server;
  
  const ServerDetailScreen({
    super.key,
    required this.server,
  });

  @override
  State<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends State<ServerDetailScreen> {
  late ServerModel _currentServer;
  final _serverService = ServerService();
  Timer? _countdownTimer;
  Duration? _remainingTime;

  @override
  void initState() {
    super.initState();
    _currentServer = widget.server;
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    if (_currentServer.deletionScheduledAt != null) {
      _updateRemainingTime();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _updateRemainingTime();
      });
    }
  }

  void _updateRemainingTime() {
    if (_currentServer.deletionScheduledAt == null) {
      _countdownTimer?.cancel();
      setState(() => _remainingTime = null);
      return;
    }

    final now = DateTime.now();
    final deletion = _currentServer.deletionScheduledAt!;
    
    if (deletion.isBefore(now)) {
      setState(() => _remainingTime = Duration.zero);
      _countdownTimer?.cancel();
    } else {
      setState(() => _remainingTime = deletion.difference(now));
    }
  }

  Future<void> _refreshServerData() async {
    try {
      final freshServer = await _serverService.getServerById(_currentServer.id);
      if (freshServer != null && mounted) {
        setState(() => _currentServer = freshServer);
        _startCountdownTimer(); // Restart timer with new data
      }
    } catch (e) {
      debugPrint('Error refreshing server: $e');
    }
  }

  Future<void> _navigateToEdit() async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditServerScreen(server: _currentServer),
      ),
    );
    
    // Refresh server data if changes were made
    if (result == true && mounted) {
      await _refreshServerData();
    }
  }

  bool _isOwner() {
    final currentUserId = supabase.auth.currentUser?.id;
    return currentUserId == _currentServer.ownerId;
  }

  Future<void> _scheduleServerDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Server'),
        content: const Text(
          'Are you sure you want to delete this server?\n\n'
          'The server will be deleted in 24 hours. You can cancel the deletion anytime before then.\n\n'
          'All members will be notified about the scheduled deletion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Schedule Deletion'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final result = await _serverService.scheduleServerDeletion(_currentServer.id);
      
      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Server deletion scheduled for 24 hours from now'),
              backgroundColor: Colors.orange,
            ),
          );
          await _refreshServerData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to schedule deletion'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelServerDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Server Deletion'),
        content: const Text('Are you sure you want to cancel the scheduled deletion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel Deletion'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final result = await _serverService.cancelServerDeletion(_currentServer.id);
      
      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Server deletion cancelled'),
              backgroundColor: Colors.green,
            ),
          );
          await _refreshServerData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to cancel deletion'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatTimeRemaining(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
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
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
            title: Text(
              _currentServer.name,
              style: AppTextStyles.heading2.copyWith(
                color: theme.textPrimary,
              ),
            ),
            actions: [
              // Edit button for admins/owners
              IconButton(
                icon: Icon(Icons.edit_rounded, color: theme.primaryColor),
                onPressed: _navigateToEdit,
              ),
            ],
          ),
          body: Column(
            children: [
              // Deletion Warning Banner
              if (_currentServer.deletionScheduledAt != null && _remainingTime != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    border: Border(
                      bottom: BorderSide(color: Colors.red.shade700, width: 2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'This server will be deleted in:',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _formatTimeRemaining(_remainingTime!),
                        style: AppTextStyles.heading2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_isOwner()) ...[
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _cancelServerDeletion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red.shade900,
                            ),
                            child: const Text('Cancel Deletion'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Server Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: _currentServer.iconUrl == null ? theme.primaryGradient : null,
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withOpacity(0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _currentServer.iconUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.large),
                            child: Image.network(
                              _currentServer.iconUrl!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: theme.primaryGradient,
                                  ),
                                  child: const Icon(
                                    Icons.dns_rounded,
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          )
                        : const Icon(
                            Icons.dns_rounded,
                            size: 64,
                            color: Colors.white,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    _currentServer.name,
                    style: AppTextStyles.heading1.copyWith(
                      color: theme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_currentServer.description != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _currentServer.description!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: theme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_rounded,
                        size: 20,
                        color: theme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_currentServer.memberCount} members',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl * 2),
                  
                  // Action Buttons
                  Column(
                    children: [
                      // Open Chat Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ServerChatScreen(server: _currentServer),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.medium),
                            ),
                            elevation: 8,
                            shadowColor: theme.primaryColor.withOpacity(0.4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_rounded, size: 20),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Open Server Chat',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: AppSpacing.md),
                      
                      // View Members Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ServerMembersScreen(server: _currentServer),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.primaryColor,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            side: BorderSide(
                              color: theme.primaryColor.withOpacity(0.5),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.medium),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people_rounded, size: 20),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'View Members',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: AppSpacing.md),
                      
                      // Manage Invites Button (only for owner)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ServerInvitesScreen(
                                  serverId: _currentServer.id,
                                  serverName: _currentServer.name,
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.primaryColor,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            side: BorderSide(
                              color: theme.primaryColor.withOpacity(0.5),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.medium),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_add_rounded, size: 20),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Manage Invites',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Delete Server Button (only for owner)
                      if (_isOwner() && _currentServer.deletionScheduledAt == null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _scheduleServerDeletion,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              side: const BorderSide(
                                color: Colors.red,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.medium),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.delete_forever_rounded, size: 20),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Delete Server',
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ], // End Action Buttons Column children
                  ), // End Action Buttons Column
                ], // End inner Column (mainAxisAlignment: center) children
              ), // End inner Column
            ), // End Padding
          ), // End Center
        ), // End Expanded
      ], // End body Column children
    ) // End body Column
    ); // End Scaffold
      }, // End Consumer builder
    ); // End Consumer
  } // End build
} // End _ServerDetailScreenState
