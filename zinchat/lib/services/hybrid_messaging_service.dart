import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to manage hybrid messaging: FCM notifications + Supabase realtime updates
/// Simplified wrapper around existing message streaming from ChatRepository
class HybridMessagingService {
  static final HybridMessagingService _instance = HybridMessagingService._internal();
  factory HybridMessagingService() => _instance;
  HybridMessagingService._internal();

  final Supabase _supabase = Supabase.instance;
  Supabase get supabase => _supabase;

  // Track active subscriptions per chat
  final Map<String, bool> _activeSubscriptions = {};

  /// Subscribe to realtime messages for a specific chat
  /// Note: Actual message streaming comes from ChatRepository.getMessagesStream()
  /// This method just tracks the subscription state
  Future<void> subscribeToRealtimeMessages(String chatId) async {
    debugPrint('📡 Subscribing to realtime messages for chat: $chatId');
    _activeSubscriptions[chatId] = true;
    debugPrint('✅ Successfully subscribed to realtime for chat: $chatId');
  }

  /// Unsubscribe from realtime messages for a specific chat
  Future<void> unsubscribeFromRealtimeMessages(String chatId) async {
    try {
      _activeSubscriptions.remove(chatId);
      debugPrint('✅ Unsubscribed from realtime for chat: $chatId');
    } catch (e) {
      debugPrint('❌ Error unsubscribing: $e');
    }
  }

  /// Get subscription status for a chat
  bool isSubscribed(String chatId) => _activeSubscriptions[chatId] ?? false;

  /// Get all active subscription chat IDs
  List<String> getActiveSubscriptions() => _activeSubscriptions.keys.toList();

  // Notification payload helpers
  static const String messageType = 'chat_message';
  static const String payloadKeyChatId = 'chat_id';
  static const String payloadKeySenderId = 'sender_id';
  static const String payloadKeyType = 'type';
  static const String payloadKeySenderName = 'sender_name';
  static const String payloadKeyContent = 'content';

  /// Create a notification payload for FCM
  static Map<String, String> createNotificationPayload({
    required String chatId,
    required String senderId,
    required String senderName,
    String type = messageType,
    String content = '',
  }) {
    return {
      payloadKeyChatId: chatId,
      payloadKeySenderId: senderId,
      payloadKeyType: type,
      payloadKeySenderName: senderName,
      payloadKeyContent: content,
    };
  }

  /// Handle notification click - navigate to correct screen
  /// Called from unified notification handler
  static Future<void> handleNotificationClick(
    String chatId, {
    String? senderId,
  }) async {
    debugPrint('🔔 Notification clicked for chat: $chatId');
    // Navigation is handled by UnifiedNotificationHandler
    // This is just for logging and additional handling if needed
  }

  /// Cleanup all subscriptions
  Future<void> unsubscribeAll() async {
    debugPrint('🧹 Disposing HybridMessagingService');
    try {
      for (final chatId in _activeSubscriptions.keys.toList()) {
        await unsubscribeFromRealtimeMessages(chatId);
      }
    } catch (e) {
      debugPrint('❌ Error during cleanup: $e');
    }
  }
}
