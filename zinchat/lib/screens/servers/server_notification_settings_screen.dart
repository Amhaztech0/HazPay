import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../providers/theme_provider.dart';
import '../../models/server_model.dart';
import '../../services/server_service.dart';

class ServerNotificationSettingsScreen extends StatefulWidget {
  final ServerModel server;

  const ServerNotificationSettingsScreen({
    super.key,
    required this.server,
  });

  @override
  State<ServerNotificationSettingsScreen> createState() =>
      _ServerNotificationSettingsScreenState();
}

class _ServerNotificationSettingsScreenState
    extends State<ServerNotificationSettingsScreen> {
  final _serverService = ServerService();
  bool _notificationsEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
  }

  Future<void> _loadNotificationStatus() async {
    setState(() => _isLoading = true);
    final enabled = await _serverService.areNotificationsEnabled(widget.server.id);
    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _isLoading = true);

    final success = value
        ? await _serverService.enableServerNotifications(widget.server.id)
        : await _serverService.disableServerNotifications(widget.server.id);

    if (mounted) {
      setState(() {
        if (success) {
          _notificationsEnabled = value;
        }
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Notifications ${value ? 'enabled' : 'disabled'}'
                : 'Failed to update notification settings',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.currentTheme;

        return Scaffold(
          backgroundColor: theme.chatBackground,
          appBar: AppBar(
            backgroundColor: theme.cardBackground,
            elevation: 0,
            title: Text(
              'Notification Settings',
              style: AppTextStyles.heading3.copyWith(color: theme.textPrimary),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    // Server info card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: theme.cardBackground,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(
                          color: theme.primaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: theme.primaryGradient,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.squircle),
                            ),
                            child: const Icon(
                              Icons.dns_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.server.name,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: theme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.server.memberCount} members',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: theme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Notifications toggle
                    Container(
                      decoration: BoxDecoration(
                        color: theme.cardBackground,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(
                          color: theme.primaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: SwitchListTile(
                        value: _notificationsEnabled,
                        onChanged: _toggleNotifications,
                        title: Text(
                          'Server Notifications',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _notificationsEnabled
                              ? 'You will receive notifications from this server'
                              : 'You will not receive notifications from this server',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: theme.textSecondary,
                          ),
                        ),
                        activeColor: theme.primaryColor,
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _notificationsEnabled
                                ? theme.primaryColor.withOpacity(0.2)
                                : theme.textSecondary.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(AppRadius.small),
                          ),
                          child: Icon(
                            _notificationsEnabled
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_rounded,
                            color: _notificationsEnabled
                                ? theme.primaryColor
                                : theme.textSecondary,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Information card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(
                          color: theme.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: theme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'About Server Notifications',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: theme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'When enabled, you\'ll receive notifications for:\n'
                                  '• New messages in server channels\n'
                                  '• @mentions and replies\n'
                                  '• Server announcements\n\n'
                                  'When disabled, you won\'t receive any notifications from this server.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: theme.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Quick actions
                    Text(
                      'Quick Actions',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Mute for time period (future feature)
                    Container(
                      decoration: BoxDecoration(
                        color: theme.cardBackground,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(
                          color: theme.primaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.textSecondary.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(AppRadius.small),
                          ),
                          child: Icon(
                            Icons.schedule_rounded,
                            color: theme.textSecondary,
                          ),
                        ),
                        title: Text(
                          'Mute for...',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: theme.textSecondary,
                          ),
                        ),
                        subtitle: Text(
                          'Coming soon',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: theme.textSecondary.withOpacity(0.7),
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: theme.textSecondary,
                        ),
                        enabled: false,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
