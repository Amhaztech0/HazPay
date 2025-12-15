import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../utils/debug_logger.dart';

/// Service for downloading and managing media files locally (WhatsApp-style)
/// - Downloads images, videos, documents from Supabase Storage
/// - Saves to app-specific directory for offline access
/// - Manages auto-download settings (WiFi only, cellular, never)
class MediaDownloadService {
  static final MediaDownloadService _instance = MediaDownloadService._internal();
  factory MediaDownloadService() => _instance;
  MediaDownloadService._internal();

  final _downloadingFiles = <String, bool>{};
  final _downloadedFiles = <String, String>{}; // mediaUrl -> localPath

  /// Auto-download settings
  String _autoDownloadPhotos = 'wifi'; // 'wifi', 'always', 'never'
  String _autoDownloadVideos = 'wifi';
  String _autoDownloadDocuments = 'wifi';

  String get autoDownloadPhotos => _autoDownloadPhotos;
  String get autoDownloadVideos => _autoDownloadVideos;
  String get autoDownloadDocuments => _autoDownloadDocuments;

  /// Get app-specific media directory
  Future<Directory> getMediaDirectory(String mediaType) async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/ZinChat/Media/$mediaType');
    
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    
    return mediaDir;
  }

  /// Check if file is already downloaded locally
  Future<String?> getLocalPath(String mediaUrl) async {
    // Check cache first
    if (_downloadedFiles.containsKey(mediaUrl)) {
      final path = _downloadedFiles[mediaUrl]!;
      if (await File(path).exists()) {
        return path;
      }
    }

    // Extract filename from URL
    final fileName = _getFileNameFromUrl(mediaUrl);
    if (fileName == null) return null;

    // Determine media type
    final mediaType = _getMediaType(fileName);
    final mediaDir = await getMediaDirectory(mediaType);
    final localFile = File('${mediaDir.path}/$fileName');

    if (await localFile.exists()) {
      _downloadedFiles[mediaUrl] = localFile.path;
      return localFile.path;
    }

    return null;
  }

  /// Download media file to local storage
  Future<String?> downloadMedia({
    required String mediaUrl,
    String? messageId,
    Function(double)? onProgress,
  }) async {
    try {
      // Check if already downloading
      if (_downloadingFiles[mediaUrl] == true) {
        DebugLogger.info('⏳ Already downloading: $mediaUrl', tag: 'MEDIA');
        return null;
      }

      // Check if already exists locally
      final existingPath = await getLocalPath(mediaUrl);
      if (existingPath != null) {
        DebugLogger.success('✅ File already exists locally: $existingPath', tag: 'MEDIA');
        return existingPath;
      }

      _downloadingFiles[mediaUrl] = true;
      DebugLogger.info('📥 Starting download: $mediaUrl', tag: 'MEDIA');

      // Extract filename
      final fileName = _getFileNameFromUrl(mediaUrl);
      if (fileName == null) {
        throw Exception('Could not extract filename from URL');
      }

      // Get target directory
      final mediaType = _getMediaType(fileName);
      final mediaDir = await getMediaDirectory(mediaType);
      final localFile = File('${mediaDir.path}/$fileName');

      // Download file
      final response = await http.get(Uri.parse(mediaUrl));
      
      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        
        _downloadedFiles[mediaUrl] = localFile.path;
        _downloadingFiles.remove(mediaUrl);
        
        DebugLogger.success('✅ Download complete: ${localFile.path}', tag: 'MEDIA');
        return localFile.path;
      } else {
        throw Exception('Download failed: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.error('❌ Download error: $e', tag: 'MEDIA');
      _downloadingFiles.remove(mediaUrl);
      return null;
    }
  }

  /// Auto-download media based on settings and connection type
  Future<void> autoDownloadIfNeeded({
    required String mediaUrl,
    required String mediaType,
    String? messageId,
  }) async {
    try {
      // Check if already exists
      final existingPath = await getLocalPath(mediaUrl);
      if (existingPath != null) return;

      // Get user's auto-download preference for this media type
      String setting;
      switch (mediaType.toLowerCase()) {
        case 'image':
        case 'photo':
          setting = _autoDownloadPhotos;
          break;
        case 'video':
          setting = _autoDownloadVideos;
          break;
        case 'document':
        case 'audio':
        case 'file':
          setting = _autoDownloadDocuments;
          break;
        default:
          setting = 'never';
      }

      // Check if should download
      if (setting == 'never') return;

      // TODO: Check actual connection type (WiFi vs cellular)
      // For now, assume 'wifi' setting means download always
      if (setting == 'wifi' || setting == 'always') {
        await downloadMedia(mediaUrl: mediaUrl, messageId: messageId);
      }
    } catch (e) {
      DebugLogger.error('❌ Auto-download error: $e', tag: 'MEDIA');
    }
  }

  /// Get auto-download settings as Map
  Future<Map<String, String>> getAutoDownloadSettings() async {
    return {
      'photos': _autoDownloadPhotos,
      'videos': _autoDownloadVideos,
      'documents': _autoDownloadDocuments,
      'audio': 'always', // Default for audio
    };
  }

  /// Update auto-download settings from named parameters
  Future<void> updateAutoDownloadSettings({
    String? photos,
    String? videos,
    String? documents,
    String? audio,
  }) async {
    if (photos != null) _autoDownloadPhotos = photos;
    if (videos != null) _autoDownloadVideos = videos;
    if (documents != null) _autoDownloadDocuments = documents;
    // audio parameter stored for future use

    // TODO: Persist to shared preferences
    DebugLogger.info('✅ Auto-download settings updated', tag: 'MEDIA');
  }

  /// Update auto-download settings from Map
  Future<void> updateAutoDownloadSettingsFromMap(Map<String, String> settings) async {
    await updateAutoDownloadSettings(
      photos: settings['photos'],
      videos: settings['videos'],
      documents: settings['documents'],
      audio: settings['audio'],
    );
  }

  /// Get media type from filename
  String _getMediaType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext)) {
      return 'Images';
    } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) {
      return 'Videos';
    } else if (['mp3', 'wav', 'ogg', 'm4a', 'aac'].contains(ext)) {
      return 'Audio';
    } else {
      return 'Documents';
    }
  }

  /// Extract filename from Supabase Storage URL
  String? _getFileNameFromUrl(String url) {
    try {
      // Extract from Supabase storage URL format
      // Example: https://xxx.supabase.co/storage/v1/object/public/bucket/path/file.jpg
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      
      if (segments.isNotEmpty) {
        return segments.last;
      }
      
      return null;
    } catch (e) {
      DebugLogger.error('❌ Error extracting filename: $e', tag: 'MEDIA');
      return null;
    }
  }

  /// Clear all cached media (for storage management)
  Future<void> clearAllMedia() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory('${appDir.path}/ZinChat/Media');
      
      if (await mediaDir.exists()) {
        await mediaDir.delete(recursive: true);
        _downloadedFiles.clear();
        DebugLogger.success('✅ All media cleared', tag: 'MEDIA');
      }
    } catch (e) {
      DebugLogger.error('❌ Error clearing media: $e', tag: 'MEDIA');
    }
  }

  /// Get total storage used by media
  Future<int> getTotalStorageUsed() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory('${appDir.path}/ZinChat/Media');
      
      if (!await mediaDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in mediaDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      DebugLogger.error('❌ Error calculating storage: $e', tag: 'MEDIA');
      return 0;
    }
  }

  /// Format bytes to human-readable size
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
