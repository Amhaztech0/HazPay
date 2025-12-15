import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/debug_logger.dart';

class VersionInfo {
  final String latestVersion;
  final String currentVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool isRequired; // Force update or optional
  final bool isUpdateAvailable;

  VersionInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isRequired,
    required this.isUpdateAvailable,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json, String currentVersion) {
    final latestVersion = json['version'] as String? ?? '1.0.0';
    final isUpdateAvailable = _compareVersions(currentVersion, latestVersion) < 0;
    
    return VersionInfo(
      latestVersion: latestVersion,
      currentVersion: currentVersion,
      downloadUrl: json['download_url'] as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? 'New version available',
      isRequired: json['is_required'] as bool? ?? false,
      isUpdateAvailable: isUpdateAvailable,
    );
  }

  // Compare versions: -1 if current < latest, 0 if equal, 1 if current > latest
  static int _compareVersions(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      // Pad with zeros if lengths differ
      while (currentParts.length < latestParts.length) currentParts.add(0);
      while (latestParts.length < currentParts.length) latestParts.add(0);

      for (int i = 0; i < currentParts.length; i++) {
        if (currentParts[i] < latestParts[i]) return -1;
        if (currentParts[i] > latestParts[i]) return 1;
      }
      return 0;
    } catch (e) {
      DebugLogger.error('Error comparing versions: $e', tag: 'VERSION_SERVICE');
      return 0; // Assume equal if parsing fails
    }
  }
}

class VersionService {
  static final VersionService _instance = VersionService._internal();
  final supabase = Supabase.instance.client;

  factory VersionService() {
    return _instance;
  }

  VersionService._internal();

  // Get current app version
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      DebugLogger.error('Error getting current version: $e', tag: 'VERSION_SERVICE');
      return '1.0.0';
    }
  }

  // Check for new version from Supabase
  Future<VersionInfo?> checkForUpdate() async {
    try {
      final currentVersion = await getCurrentVersion();
      
      // Fetch latest version from Supabase
      final response = await supabase
          .from('app_versions')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        DebugLogger.info('No version info found in database', tag: 'VERSION_SERVICE');
        return null;
      }

      final versionInfo = VersionInfo.fromJson(response, currentVersion);
      
      DebugLogger.info(
        'Current: ${versionInfo.currentVersion}, Latest: ${versionInfo.latestVersion}, Available: ${versionInfo.isUpdateAvailable}',
        tag: 'VERSION_SERVICE',
      );

      return versionInfo;
    } catch (e) {
      DebugLogger.error('Error checking for update: $e', tag: 'VERSION_SERVICE');
      return null;
    }
  }

  // Log version check event
  Future<void> logVersionCheck(String currentVersion, String? latestVersion, bool updateAvailable) async {
    try {
      await supabase.from('version_check_logs').insert({
        'current_version': currentVersion,
        'latest_version': latestVersion,
        'update_available': updateAvailable,
        'checked_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      DebugLogger.error('Error logging version check: $e', tag: 'VERSION_SERVICE');
    }
  }
}
