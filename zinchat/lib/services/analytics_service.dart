import 'package:firebase_analytics/firebase_analytics.dart';
import '../utils/debug_logger.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  factory AnalyticsService() {
    return _instance;
  }

  AnalyticsService._internal();

  /// Initialize analytics service
  Future<void> initialize() async {
    try {
      // Enable or disable collection based on user preference
      await _analytics.setAnalyticsCollectionEnabled(true);
      DebugLogger.info('✅ Analytics initialized successfully');
    } catch (e) {
      DebugLogger.error('❌ Failed to initialize analytics: $e', tag: 'ANALYTICS');
    }
  }

  // ============================================
  // USER TRACKING
  // ============================================

  /// Log user login
  Future<void> logUserLogin({required String method}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
      DebugLogger.info('📊 User login tracked: $method');
    } catch (e) {
      DebugLogger.error('❌ Failed to log user login: $e', tag: 'ANALYTICS');
    }
  }

  /// Log user signup
  Future<void> logUserSignup({required String method}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
      DebugLogger.info('📊 User signup tracked: $method');
    } catch (e) {
      DebugLogger.error('❌ Failed to log user signup: $e', tag: 'ANALYTICS');
    }
  }

  /// Set user ID (after login/signup)
  Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
      DebugLogger.info('📊 User ID set: $userId');
    } catch (e) {
      DebugLogger.error('❌ Failed to set user ID: $e', tag: 'ANALYTICS');
    }
  }

  /// Set user properties (e.g., premium status, theme preference)
  Future<void> setUserProperties({required Map<String, String> properties}) async {
    try {
      for (var entry in properties.entries) {
        await _analytics.setUserProperty(name: entry.key, value: entry.value);
      }
      DebugLogger.info('📊 User properties set: ${properties.keys.toList()}');
    } catch (e) {
      DebugLogger.error('❌ Failed to set user properties: $e', tag: 'ANALYTICS');
    }
  }

  // ============================================
  // MESSAGING TRACKING
  // ============================================

  /// Track message sent
  Future<void> logMessageSent({
    required String messageType, // 'direct_message', 'server_message', etc.
    String? serverId,
    bool hasMedia = false,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'message_sent',
        parameters: {
          'message_type': messageType,
          'has_media': hasMedia,
          if (serverId != null) 'server_id': serverId,
        },
      );
      DebugLogger.info('📊 Message sent tracked: $messageType');
    } catch (e) {
      DebugLogger.error('❌ Failed to log message sent: $e', tag: 'ANALYTICS');
    }
  }

  /// Track message viewed
  Future<void> logMessageViewed({
    required String messageType,
    String? serverId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'message_viewed',
        parameters: {
          'message_type': messageType,
          if (serverId != null) 'server_id': serverId,
        },
      );
      DebugLogger.info('📊 Message viewed tracked: $messageType');
    } catch (e) {
      DebugLogger.error('❌ Failed to log message viewed: $e', tag: 'ANALYTICS');
    }
  }

  // ============================================
  // FEATURE USAGE TRACKING
  // ============================================

  /// Track feature usage
  Future<void> logFeatureUsage(String featureName) async {
    try {
      await _analytics.logEvent(
        name: 'feature_used',
        parameters: {'feature_name': featureName},
      );
      DebugLogger.info('📊 Feature used: $featureName');
    } catch (e) {
      DebugLogger.error('❌ Failed to log feature usage: $e', tag: 'ANALYTICS');
    }
  }

  /// Track call initiated
  Future<void> logCallInitiated({
    required String callType, // 'direct_call', 'group_call', 'server_call'
    String? participantCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'call_initiated',
        parameters: {
          'call_type': callType,
          if (participantCount != null) 'participant_count': participantCount,
        },
      );
      DebugLogger.info('📊 Call initiated: $callType');
    } catch (e) {
      DebugLogger.error('❌ Failed to log call initiated: $e', tag: 'ANALYTICS');
    }
  }

  /// Track call duration
  Future<void> logCallDuration({
    required String callType,
    required int durationSeconds,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'call_completed',
        parameters: {
          'call_type': callType,
          'duration_seconds': durationSeconds,
        },
      );
      DebugLogger.info('📊 Call completed: $callType (${durationSeconds}s)');
    } catch (e) {
      DebugLogger.error('❌ Failed to log call duration: $e', tag: 'ANALYTICS');
    }
  }

  /// Track server interaction
  Future<void> logServerInteraction({
    required String action, // 'join', 'leave', 'create', 'settings'
    String? serverId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'server_interaction',
        parameters: {
          'action': action,
          if (serverId != null) 'server_id': serverId,
        },
      );
      DebugLogger.info('📊 Server interaction: $action');
    } catch (e) {
      DebugLogger.error('❌ Failed to log server interaction: $e', tag: 'ANALYTICS');
    }
  }

  // ============================================
  // ENGAGEMENT TRACKING
  // ============================================

  /// Track screen view
  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
      );
      DebugLogger.info('📊 Screen viewed: $screenName');
    } catch (e) {
      DebugLogger.error('❌ Failed to log screen view: $e', tag: 'ANALYTICS');
    }
  }

  /// Track app opened
  Future<void> logAppOpened() async {
    try {
      await _analytics.logAppOpen();
      DebugLogger.info('📊 App opened');
    } catch (e) {
      DebugLogger.error('❌ Failed to log app open: $e', tag: 'ANALYTICS');
    }
  }

  /// Track search performed
  Future<void> logSearch({
    required String searchTerm,
    String? searchType, // 'user_search', 'server_search', etc.
    int? resultCount,
  }) async {
    try {
      await _analytics.logSearch(
        searchTerm: searchTerm,
      );
      
      // Additional custom parameters
      await _analytics.logEvent(
        name: 'search_performed',
        parameters: {
          'search_term': searchTerm,
          if (searchType != null) 'search_type': searchType,
          if (resultCount != null) 'result_count': resultCount,
        },
      );
      DebugLogger.info('📊 Search performed: $searchTerm');
    } catch (e) {
      DebugLogger.error('❌ Failed to log search: $e', tag: 'ANALYTICS');
    }
  }

  /// Track share
  Future<void> logShare({
    required String contentType,
    String? itemId,
  }) async {
    try {
      await _analytics.logShare(
        contentType: contentType,
        itemId: itemId ?? '',
        method: 'in_app',
      );
      DebugLogger.info('📊 Content shared: $contentType');
    } catch (e) {
      DebugLogger.error('❌ Failed to log share: $e', tag: 'ANALYTICS');
    }
  }

  // ============================================
  // AD TRACKING
  // ============================================

  /// Track ad impression
  Future<void> logAdImpression({
    required String adUnit,
    required String adFormat,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'ad_impression',
        parameters: {
          'ad_unit': adUnit,
          'ad_format': adFormat,
        },
      );
      DebugLogger.info('📊 Ad impression: $adUnit');
    } catch (e) {
      DebugLogger.error('❌ Failed to log ad impression: $e', tag: 'ANALYTICS');
    }
  }

  /// Track ad click
  Future<void> logAdClick({
    required String adUnit,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'ad_click',
        parameters: {
          'ad_unit': adUnit,
        },
      );
      DebugLogger.info('📊 Ad clicked: $adUnit');
    } catch (e) {
      DebugLogger.error('❌ Failed to log ad click: $e', tag: 'ANALYTICS');
    }
  }

  // ============================================
  // ERROR TRACKING (Integration with Crashlytics)
  // ============================================

  /// Track non-fatal error (analytics event)
  Future<void> logError({
    required String errorType,
    required String errorMessage,
    String? context,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'app_error',
        parameters: {
          'error_type': errorType,
          'error_message': errorMessage,
          if (context != null) 'context': context,
        },
      );
      DebugLogger.info('📊 Error tracked: $errorType - $errorMessage');
    } catch (e) {
      DebugLogger.error('❌ Failed to log error: $e', tag: 'ANALYTICS');
    }
  }

  /// Track permission denied
  Future<void> logPermissionDenied(String permissionType) async {
    try {
      await _analytics.logEvent(
        name: 'permission_denied',
        parameters: {'permission_type': permissionType},
      );
      DebugLogger.info('📊 Permission denied: $permissionType');
    } catch (e) {
      DebugLogger.error('❌ Failed to log permission denied: $e', tag: 'ANALYTICS');
    }
  }

  // ============================================
  // CUSTOM EVENTS
  // ============================================

  /// Log custom event
  Future<void> logCustomEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      // Convert all values to strings or int for Firebase Analytics
      final sanitizedParams = <String, Object>{};
      parameters?.forEach((key, value) {
        if (value is String || value is int || value is double || value is bool) {
          sanitizedParams[key] = value;
        } else {
          sanitizedParams[key] = value.toString();
        }
      });

      await _analytics.logEvent(
        name: eventName,
        parameters: sanitizedParams.isNotEmpty ? sanitizedParams : null,
      );
      DebugLogger.info('📊 Custom event: $eventName');
    } catch (e) {
      DebugLogger.error('❌ Failed to log custom event: $e', tag: 'ANALYTICS');
    }
  }

  // ============================================
  // CONSENT & PRIVACY
  // ============================================

  /// Set analytics collection enabled/disabled
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
      DebugLogger.info('📊 Analytics collection ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      DebugLogger.error('❌ Failed to set analytics collection: $e', tag: 'ANALYTICS');
    }
  }

  /// Set session timeout (milliseconds)
  Future<void> setSessionTimeoutDuration(Duration duration) async {
    try {
      await _analytics.setSessionTimeoutDuration(duration);
      DebugLogger.info('📊 Session timeout set to ${duration.inSeconds}s');
    } catch (e) {
      DebugLogger.error('❌ Failed to set session timeout: $e', tag: 'ANALYTICS');
    }
  }
}
