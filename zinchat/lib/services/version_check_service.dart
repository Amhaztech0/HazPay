import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/debug_logger.dart';

/// Service for checking app version and prompting updates
class VersionCheckService {
  static final VersionCheckService _instance = VersionCheckService._internal();

  factory VersionCheckService() {
    return _instance;
  }

  VersionCheckService._internal();

  late PackageInfo _packageInfo;
  bool _initialized = false;

  /// Initialize the version check service
  Future<void> initialize() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
      _initialized = true;
      DebugLogger.info('VersionCheckService initialized. Current version: ${_packageInfo.version}');
    } catch (e) {
      DebugLogger.error('Failed to initialize VersionCheckService: $e', tag: 'VERSION');
    }
  }

  /// Get current app version
  String getCurrentVersion() {
    if (!_initialized) {
      DebugLogger.info('VersionCheckService not initialized');
      return '0.0.0';
    }
    return _packageInfo.version;
  }

  /// Get current build number
  String getCurrentBuildNumber() {
    if (!_initialized) {
      DebugLogger.info('VersionCheckService not initialized');
      return '0';
    }
    return _packageInfo.buildNumber;
  }

  /// Check for app updates from Supabase
  /// Returns null if no update available, otherwise returns update info
  Future<Map<String, dynamic>?> checkForUpdate({
    bool showLogging = true,
  }) async {
    try {
      if (!_initialized) {
        if (showLogging) DebugLogger.info('VersionCheckService not initialized');
        return null;
      }

      if (showLogging) DebugLogger.info('Checking for updates...');

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('app_versions')
          .select()
          .order('version_order', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        if (showLogging) DebugLogger.info('No version info found in database');
        return null;
      }

      final latestVersion = response['version'] as String;
      final isUpdateRequired = response['force_update'] as bool? ?? false;
      final updateUrl = response['download_url'] as String?;
      final updateNotes = response['release_notes'] as String?;
      final minSupportedVersion = response['min_supported_version'] as String?;

      if (showLogging) {
        DebugLogger.info('Latest version: $latestVersion');
        DebugLogger.info('Force update: $isUpdateRequired');
        DebugLogger.info('Current version: ${_packageInfo.version}');
      }

      // Compare versions
      if (_isNewerVersion(latestVersion, _packageInfo.version)) {
        return {
          'available': true,
          'current_version': _packageInfo.version,
          'latest_version': latestVersion,
          'force_update': isUpdateRequired,
          'download_url': updateUrl,
          'release_notes': updateNotes,
          'min_supported_version': minSupportedVersion,
        };
      }

      if (showLogging) DebugLogger.info('App is up to date');
      return null;
    } catch (e) {
      DebugLogger.error('Failed to check for update: $e', tag: 'VERSION');
      return null;
    }
  }

  /// Compare two semantic versions
  /// Returns true if version1 > version2
  bool _isNewerVersion(String version1, String version2) {
    try {
      final v1Parts = version1.split('.').map(int.parse).toList();
      final v2Parts = version2.split('.').map(int.parse).toList();

      // Pad with zeros if needed
      while (v1Parts.length < v2Parts.length) v1Parts.add(0);
      while (v2Parts.length < v1Parts.length) v2Parts.add(0);

      for (int i = 0; i < v1Parts.length; i++) {
        if (v1Parts[i] > v2Parts[i]) return true;
        if (v1Parts[i] < v2Parts[i]) return false;
      }

      return false; // Versions are equal
    } catch (e) {
      DebugLogger.error('Failed to compare versions: $e', tag: 'VERSION');
      return false;
    }
  }

  /// Show update dialog to user
  Future<void> showUpdateDialog(
    BuildContext context, {
    required Map<String, dynamic> updateInfo,
    VoidCallback? onUpdateNow,
    VoidCallback? onLater,
  }) async {
    final forceUpdate = updateInfo['force_update'] as bool? ?? false;
    final currentVersion = updateInfo['current_version'] as String;
    final latestVersion = updateInfo['latest_version'] as String;
    final releaseNotes = updateInfo['release_notes'] as String?;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: !forceUpdate, // Force update can't be dismissed
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current version: $currentVersion'),
              Text('Latest version: $latestVersion'),
              const SizedBox(height: 16),
              if (releaseNotes != null) ...[
                const Text(
                  'What\'s New:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(releaseNotes),
                const SizedBox(height: 16),
              ],
              if (forceUpdate)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This update is required to continue using ZinChat.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onLater?.call();
              },
              child: const Text('Later'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onUpdateNow?.call();
              _launchUpdateUrl(updateInfo['download_url'] as String?);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  /// Launch the update URL
  Future<void> _launchUpdateUrl(String? url) async {
    if (url == null || url.isEmpty) {
      DebugLogger.info('No update URL provided');
      return;
    }

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        DebugLogger.info('Launched update URL: $url');
      } else {
        DebugLogger.info('Could not launch update URL: $url');
      }
    } catch (e) {
      DebugLogger.error('Failed to launch update URL: $e', tag: 'VERSION');
    }
  }

  /// Check version on app startup
  /// Automatically shows update dialog if update is available
  Future<void> checkVersionOnStartup(BuildContext context) async {
    try {
      final updateInfo = await checkForUpdate(showLogging: false);

      if (updateInfo != null && context.mounted) {
        final forceUpdate = updateInfo['force_update'] as bool? ?? false;

        // Log update check
        DebugLogger.info(
          'Update available: ${updateInfo['latest_version']} (forced: $forceUpdate)',
        );

        // Show dialog
        await showUpdateDialog(
          context,
          updateInfo: updateInfo,
          onUpdateNow: () {
            DebugLogger.info('User clicked "Update Now"');
          },
          onLater: () {
            DebugLogger.info('User clicked "Later"');
          },
        );
      }
    } catch (e) {
      DebugLogger.error('Failed to check version on startup: $e', tag: 'VERSION');
    }
  }

  /// Get version info for display in app settings
  Map<String, String> getVersionInfo() {
    return {
      'app_version': getCurrentVersion(),
      'build_number': getCurrentBuildNumber(),
      'package_name': _initialized ? _packageInfo.packageName : 'unknown',
      'app_name': _initialized ? _packageInfo.appName : 'ZinChat',
    };
  }

  /// Check if current version is supported
  /// Returns false if version is below minimum supported version
  bool isVersionSupported(String? minSupportedVersion) {
    if (minSupportedVersion == null) return true;

    try {
      return !_isNewerVersion(minSupportedVersion, _packageInfo.version);
    } catch (e) {
      DebugLogger.error('Failed to check version support: $e', tag: 'VERSION');
      return true; // Assume supported on error
    }
  }

  /// Log version information
  void logVersionInfo() {
    if (!_initialized) {
      DebugLogger.info('VersionCheckService not initialized');
      return;
    }

    DebugLogger.info('=== Version Information ===');
    DebugLogger.info('App Name: ${_packageInfo.appName}');
    DebugLogger.info('Package Name: ${_packageInfo.packageName}');
    DebugLogger.info('Version: ${_packageInfo.version}');
    DebugLogger.info('Build Number: ${_packageInfo.buildNumber}');
    DebugLogger.info('==========================');
  }
}
