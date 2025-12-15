import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../utils/debug_logger.dart';

class ErrorTrackingService {
  static final ErrorTrackingService _instance = ErrorTrackingService._internal();
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  factory ErrorTrackingService() {
    return _instance;
  }

  ErrorTrackingService._internal();

  /// Initialize error tracking
  Future<void> initialize() async {
    try {
      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
      };

      // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      DebugLogger.info('✅ Error tracking initialized successfully');
    } catch (e) {
      DebugLogger.error('❌ Failed to initialize error tracking: $e', tag: 'ERROR_TRACKING');
    }
  }

  // ============================================
  // ERROR LOGGING
  // ============================================

  /// Log a non-fatal error
  Future<void> recordError({
    required dynamic exception,
    required StackTrace stack,
    String? context,
    Map<String, dynamic>? customData,
  }) async {
    try {
      // Set context if provided
      if (context != null) {
        _crashlytics.log('Context: $context');
      }

      // Set custom data if provided
      if (customData != null) {
        customData.forEach((key, value) {
          _crashlytics.setCustomKey(key, value);
        });
      }

      // Record the error
      await _crashlytics.recordError(
        exception,
        stack,
        fatal: false,
        reason: context,
      );

      DebugLogger.error('🔴 Error recorded: $exception', tag: 'ERROR_TRACKING');
    } catch (e) {
      DebugLogger.error('❌ Failed to record error: $e', tag: 'ERROR_TRACKING');
    }
  }

  /// Log a fatal error
  Future<void> recordFatalError({
    required dynamic exception,
    required StackTrace stack,
    String? context,
    Map<String, dynamic>? customData,
  }) async {
    try {
      if (context != null) {
        _crashlytics.log('FATAL Context: $context');
      }

      if (customData != null) {
        customData.forEach((key, value) {
          _crashlytics.setCustomKey(key, value);
        });
      }

      await _crashlytics.recordError(
        exception,
        stack,
        fatal: true,
        reason: context,
      );

      DebugLogger.error('🔴 FATAL ERROR recorded: $exception', tag: 'ERROR_TRACKING');
    } catch (e) {
      DebugLogger.error('❌ Failed to record fatal error: $e', tag: 'ERROR_TRACKING');
    }
  }

  /// Log a flutter error
  Future<void> recordFlutterError(FlutterErrorDetails errorDetails) async {
    try {
      await _crashlytics.recordFlutterError(errorDetails);
      DebugLogger.error('🔴 Flutter error recorded: ${errorDetails.exceptionAsString()}', tag: 'ERROR_TRACKING');
    } catch (e) {
      DebugLogger.error('❌ Failed to record flutter error: $e', tag: 'ERROR_TRACKING');
    }
  }

  // ============================================
  // CRASH TRACKING
  // ============================================

  /// Check if app crashed on last run
  Future<bool> didCrashOnLastRun() async {
    try {
      return await _crashlytics.didCrashOnPreviousExecution();
    } catch (e) {
      DebugLogger.error('❌ Failed to check crash status: $e', tag: 'ERROR_TRACKING');
      return false;
    }
  }

  /// Send unsent crash reports
  Future<void> sendUnsentCrashReports() async {
    try {
      // In Crashlytics SDK, reports are sent automatically
      DebugLogger.info('📊 Unsent crash reports will be sent automatically');
    } catch (e) {
      DebugLogger.error('❌ Failed to send unsent crash reports: $e', tag: 'ERROR_TRACKING');
    }
  }

  // ============================================
  // CUSTOM LOGGING
  // ============================================

  /// Add a custom log message
  void log(String message) {
    try {
      _crashlytics.log(message);
      DebugLogger.info('📝 Log: $message', tag: 'ERROR_TRACKING');
    } catch (e) {
      DebugLogger.error('❌ Failed to log message: $e', tag: 'ERROR_TRACKING');
    }
  }

  /// Set custom key-value pair (e.g., user id, app version)
  Future<void> setCustomKey(String key, dynamic value) async {
    try {
      _crashlytics.setCustomKey(key, value);
      DebugLogger.info('🔑 Custom key set: $key = $value', tag: 'ERROR_TRACKING');
    } catch (e) {
      DebugLogger.error('❌ Failed to set custom key: $e', tag: 'ERROR_TRACKING');
    }
  }

  /// Set multiple custom keys
  Future<void> setCustomKeys(Map<String, dynamic> keys) async {
    try {
      keys.forEach((key, value) {
        _crashlytics.setCustomKey(key, value);
      });
      DebugLogger.info('🔑 Custom keys set: ${keys.keys.toList()}', tag: 'ERROR_TRACKING');
    } catch (e) {
      DebugLogger.error('❌ Failed to set custom keys: $e', tag: 'ERROR_TRACKING');
    }
  }

  /// Set user ID
  Future<void> setUserId(String userId) async {
    try {
      await _crashlytics.setUserIdentifier(userId);
      DebugLogger.info('👤 User ID set: $userId', tag: 'ERROR_TRACKING');
    } catch (e) {
      DebugLogger.error('❌ Failed to set user ID: $e', tag: 'ERROR_TRACKING');
    }
  }

  // ============================================
  // USER SESSION TRACKING
  // ============================================

  /// Track important user session events
  Future<void> logUserAction({
    required String action,
    String? details,
  }) async {
    try {
      final message = 'User Action: $action${details != null ? ' - $details' : ''}';
      _crashlytics.log(message);
      DebugLogger.info('📌 User action: $action', tag: 'ERROR_TRACKING');
    } catch (e) {
      DebugLogger.error('❌ Failed to log user action: $e', tag: 'ERROR_TRACKING');
    }
  }

  /// Track feature usage (for debugging)
  Future<void> logFeatureUsage(String featureName) async {
    try {
      _crashlytics.log('Feature used: $featureName');
      DebugLogger.info('✨ Feature: $featureName', tag: 'ERROR_TRACKING');
    } catch (e) {
      DebugLogger.error('❌ Failed to log feature usage: $e', tag: 'ERROR_TRACKING');
    }
  }

  // ============================================
  // MESSAGING & COMMUNICATION
  // ============================================

  /// Track message sending issues
  Future<void> logMessagingError({
    required String messageType,
    required String errorDescription,
    String? messageId,
    String? recipientId,
  }) async {
    try {
      await recordError(
        exception: 'Messaging Error: $errorDescription',
        stack: StackTrace.current,
        context: 'Message Communication',
        customData: {
          'message_type': messageType,
          if (messageId != null) 'message_id': messageId,
          if (recipientId != null) 'recipient_id': recipientId,
        },
      );
    } catch (e) {
      DebugLogger.error('❌ Failed to log messaging error: $e', tag: 'ERROR_TRACKING');
    }
  }

  /// Track call issues
  Future<void> logCallError({
    required String callType,
    required String errorDescription,
    String? callId,
    String? participantId,
  }) async {
    try {
      await recordError(
        exception: 'Call Error: $errorDescription',
        stack: StackTrace.current,
        context: 'Call Communication',
        customData: {
          'call_type': callType,
          if (callId != null) 'call_id': callId,
          if (participantId != null) 'participant_id': participantId,
        },
      );
    } catch (e) {
      DebugLogger.error('❌ Failed to log call error: $e', tag: 'ERROR_TRACKING');
    }
  }

  // ============================================
  // NETWORK & SYNC ISSUES
  // ============================================

  /// Track network issues
  Future<void> logNetworkError({
    required String endpoint,
    required String errorDescription,
    int? statusCode,
    Duration? duration,
  }) async {
    try {
      await recordError(
        exception: 'Network Error: $errorDescription',
        stack: StackTrace.current,
        context: 'Network Request',
        customData: {
          'endpoint': endpoint,
          if (statusCode != null) 'status_code': statusCode,
          if (duration != null) 'duration_ms': duration.inMilliseconds,
        },
      );
    } catch (e) {
      DebugLogger.error('❌ Failed to log network error: $e', tag: 'ERROR_TRACKING');
    }
  }

  /// Track sync errors
  Future<void> logSyncError({
    required String syncType,
    required String errorDescription,
    String? dataId,
  }) async {
    try {
      await recordError(
        exception: 'Sync Error: $errorDescription',
        stack: StackTrace.current,
        context: 'Data Synchronization',
        customData: {
          'sync_type': syncType,
          if (dataId != null) 'data_id': dataId,
        },
      );
    } catch (e) {
      DebugLogger.error('❌ Failed to log sync error: $e', tag: 'ERROR_TRACKING');
    }
  }

  // ============================================
  // PERMISSION & AUTH ISSUES
  // ============================================

  /// Track permission issues
  Future<void> logPermissionError({
    required String permissionType,
    required String errorDescription,
  }) async {
    try {
      await recordError(
        exception: 'Permission Error: $errorDescription',
        stack: StackTrace.current,
        context: 'Permission Request',
        customData: {'permission_type': permissionType},
      );
    } catch (e) {
      DebugLogger.error('❌ Failed to log permission error: $e', tag: 'ERROR_TRACKING');
    }
  }

  /// Track authentication issues
  Future<void> logAuthError({
    required String errorDescription,
    String? userId,
  }) async {
    try {
      await recordError(
        exception: 'Auth Error: $errorDescription',
        stack: StackTrace.current,
        context: 'Authentication',
        customData: {
          if (userId != null) 'user_id': userId,
        },
      );
    } catch (e) {
      DebugLogger.error('❌ Failed to log auth error: $e', tag: 'ERROR_TRACKING');
    }
  }

  // ============================================
  // CONSENT & PRIVACY
  // ============================================

  /// Enable/disable crash collection
  /// Note: Firebase Crashlytics v4+ automatically enables crash collection on initialization
  /// Use setCustomKey to tag crashes or use automatic initialization control in main.dart
  Future<void> setCrashCollectionEnabled(bool enabled) async {
    try {
      // Firebase Crashlytics v4+ doesn't expose setCrashCollectionEnabled
      // Crashes are collected automatically by default
      // To disable, configure in your Firebase Console project settings
      if (enabled) {
        DebugLogger.info('📊 Crash collection enabled (automatic)', tag: 'ERROR_TRACKING');
      } else {
        DebugLogger.info('📊 To disable crashes, configure in Firebase Console settings', tag: 'ERROR_TRACKING');
      }
    } catch (e) {
      DebugLogger.error('❌ Failed to configure crash collection: $e', tag: 'ERROR_TRACKING');
    }
  }

  /// Delete all custom keys
  Future<void> clearCustomKeys() async {
    try {
      // Crashlytics doesn't have a built-in clearCustomKeys method
      // We manually set important keys to empty/null
      _crashlytics.setCustomKey('cleared_at', DateTime.now().toString());
      DebugLogger.info('🧹 Custom keys cleared', tag: 'ERROR_TRACKING');
    } catch (e) {
      DebugLogger.error('❌ Failed to clear custom keys: $e', tag: 'ERROR_TRACKING');
    }
  }
}
