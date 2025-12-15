import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../services/auth_service.dart';
import '../../services/privacy_service.dart';
import '../../services/media_download_service.dart';
import '../auth/login_screen.dart';
import 'blocked_users_screen.dart';
import 'message_requests_screen.dart';
import 'notification_debug_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _privacyService = PrivacyService();
  final _mediaService = MediaDownloadService();
  
  String _messagingPrivacy = 'everyone';
  bool _isLoading = true;
  int _pendingRequestsCount = 0;
  String _storageUsed = 'Calculating...';
  Map<String, String> _autoDownloadSettings = {
    'photos': 'wifi',
    'videos': 'wifi',
    'documents': 'always',
    'audio': 'always',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final privacy = await _privacyService.getMessagingPrivacy();
      final requestsCount = await _privacyService.getPendingRequestsCount();
      final storageUsed = await _mediaService.getTotalStorageUsed();
      final settings = await _mediaService.getAutoDownloadSettings();
      
      if (mounted) {
        setState(() {
          _messagingPrivacy = privacy;
          _pendingRequestsCount = requestsCount;
          _storageUsed = _formatStorageSize(storageUsed);
          _autoDownloadSettings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatStorageSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _updateMessagingPrivacy(String privacy) async {
    final success = await _privacyService.updateMessagingPrivacy(privacy);
    if (success && mounted) {
      setState(() {
        _messagingPrivacy = privacy;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            privacy == 'everyone'
                ? 'Everyone can now message you'
                : 'Only approved users can message you',
          ),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Privacy section
          _buildSectionHeader('Privacy'),
          
          // Messaging Privacy
          _buildMessagingPrivacyTile(),

          // Message Requests
          _buildSettingTile(
            icon: Icons.message_outlined,
            title: 'Message Requests',
            subtitle: _pendingRequestsCount > 0
                ? '$_pendingRequestsCount pending request${_pendingRequestsCount > 1 ? 's' : ''}'
                : 'View message requests',
            trailing: _pendingRequestsCount > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _pendingRequestsCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MessageRequestsScreen(),
              ),
            ).then((_) => _loadData()),
          ),

          // Blocked Users
          _buildSettingTile(
            icon: Icons.block,
            title: 'Blocked Contacts',
            subtitle: 'Manage blocked users',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BlockedUsersScreen(),
              ),
            ),
          ),

          // Notification Debug (for testing)
          _buildSettingTile(
            icon: Icons.bug_report,
            title: 'Notification Debug',
            subtitle: 'Test push notifications',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationDebugScreen(),
              ),
            ),
          ),

          const Divider(height: 32),

          // Account section
          _buildSectionHeader('Account'),
          _buildSettingTile(
            icon: Icons.key,
            title: 'Change number',
            subtitle: 'Change your phone number',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon!')),
              );
            },
          ),
          _buildSettingTile(
            icon: Icons.delete_forever,
            title: 'Delete account',
            subtitle: 'Permanently delete your account',
            textColor: AppColors.saturatedMagenta,
            onTap: () => _showDeleteAccountDialog(),
          ),

          const Divider(height: 32),

          // Notifications section
          _buildSectionHeader('Notifications'),
          _buildSettingTile(
            icon: Icons.notifications,
            title: 'Message notifications',
            subtitle: 'Sound, vibration, popup',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon!')),
              );
            },
          ),
          _buildSettingTile(
            icon: Icons.group,
            title: 'Group notifications',
            subtitle: 'Sound, vibration, popup',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon!')),
              );
            },
          ),

          const Divider(height: 32),

          // Storage section
          _buildSectionHeader('Storage and data'),
          _buildSettingTile(
            icon: Icons.storage,
            title: 'Storage usage',
            subtitle: _storageUsed,
            onTap: () => _showStorageManagementDialog(),
          ),
          
          // Auto-download settings
          _buildSettingTile(
            icon: Icons.download,
            title: 'Auto-download',
            subtitle: 'Photos, videos, documents',
            onTap: () => _showAutoDownloadDialog(),
          ),

          const Divider(height: 32),

          // Help section
          _buildSectionHeader('Help'),
          _buildSettingTile(
            icon: Icons.help,
            title: 'Help',
            subtitle: 'FAQ, contact us',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon!')),
              );
            },
          ),
          _buildSettingTile(
            icon: Icons.info,
            title: 'About',
            subtitle: 'Version 1.0.0',
            onTap: () => _showAboutDialog(),
          ),

          const SizedBox(height: 32),

          // Logout button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: ElevatedButton.icon(
              onPressed: () => _showLogoutDialog(),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.saturatedMagenta,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? AppColors.grey),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(subtitle),
      onTap: onTap,
      trailing: trailing ?? const Icon(Icons.chevron_right),
    );
  }

  Widget _buildMessagingPrivacyTile() {
    return ListTile(
      leading: Icon(Icons.privacy_tip, color: AppColors.primaryGreen),
      title: const Text(
        'Who can message me',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _messagingPrivacy == 'everyone'
            ? 'Everyone'
            : 'Only approved users',
      ),
      onTap: () => _showMessagingPrivacyDialog(),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  void _showMessagingPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        title: const Text('Who can message you?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Everyone'),
              subtitle: const Text(
                'Anyone can send you messages',
                style: TextStyle(fontSize: 12),
              ),
              value: 'everyone',
              groupValue: _messagingPrivacy,
              activeColor: AppColors.primaryGreen,
              onChanged: (value) {
                Navigator.pop(context);
                if (value != null) {
                  _updateMessagingPrivacy(value);
                }
              },
            ),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: const Text('Approved users only'),
              subtitle: const Text(
                'Only users you approve can message you (like Discord)',
                style: TextStyle(fontSize: 12),
              ),
              value: 'approved_only',
              groupValue: _messagingPrivacy,
              activeColor: AppColors.primaryGreen,
              onChanged: (value) {
                Navigator.pop(context);
                if (value != null) {
                  _updateMessagingPrivacy(value);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _authService.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feature coming soon!')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About ZinChat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ZinChat',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Version 1.0.0'),
            const SizedBox(height: 16),
            Text(
              'Zance da abokai - Chat with friends!',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Built by Amhaztech'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showStorageManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        title: const Text('Storage Management'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Storage Used:'),
                Text(
                  _storageUsed,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'This includes:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Profile photos'),
                  Text('• Chat media (images, videos)'),
                  Text('• Document attachments'),
                  Text('• Voice messages'),
                  Text('• Status content'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Show confirmation
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All Media'),
                    content: const Text(
                      'This will delete all downloaded media files from your device. You can re-download them later.\n\nContinue?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            await _mediaService.clearAllMedia();
                            if (mounted) {
                              setState(() {
                                _storageUsed = '0 B';
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ All media cleared'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('❌ Error: $e')),
                              );
                            }
                          }
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All Media'),
          ),
        ],
      ),
    );
  }

  void _showAutoDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
          title: const Text('Auto-Download Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAutoDownloadOption(
                setDialogState,
                'Photos',
                'photos',
                _autoDownloadSettings['photos'] ?? 'wifi',
              ),
              const SizedBox(height: 16),
              _buildAutoDownloadOption(
                setDialogState,
                'Videos',
                'videos',
                _autoDownloadSettings['videos'] ?? 'wifi',
              ),
              const SizedBox(height: 16),
              _buildAutoDownloadOption(
                setDialogState,
                'Documents',
                'documents',
                _autoDownloadSettings['documents'] ?? 'always',
              ),
              const SizedBox(height: 16),
              _buildAutoDownloadOption(
                setDialogState,
                'Audio',
                'audio',
                _autoDownloadSettings['audio'] ?? 'always',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '• WiFi Only: Download only when connected to WiFi\n• Always: Download on any connection\n• Never: Don\'t auto-download',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _mediaService.updateAutoDownloadSettingsFromMap(_autoDownloadSettings);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Settings saved'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoDownloadOption(
    StateSetter setDialogState,
    String label,
    String key,
    String currentValue,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: ['wifi', 'always', 'never'].map((option) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton(
                  onPressed: () {
                    setDialogState(() {
                      _autoDownloadSettings[key] = option;
                    });
                    setState(() {
                      _autoDownloadSettings[key] = option;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: currentValue == option
                        ? AppColors.primaryGreen
                        : Colors.transparent,
                    foregroundColor: currentValue == option
                        ? Colors.white
                        : AppColors.primaryGreen,
                    side: BorderSide(
                      color: currentValue == option
                          ? AppColors.primaryGreen
                          : Colors.grey,
                    ),
                  ),
                  child: Text(
                    option == 'wifi' ? 'WiFi' : (option == 'always' ? 'Always' : 'Never'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
