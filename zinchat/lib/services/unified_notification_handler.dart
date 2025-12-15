import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'hybrid_messaging_service.dart';

/// Navigation event for notifications
class NotificationNavigationEvent {
  final String type; // 'chat', 'server', or 'status_reply'
  final String? id; // chatId or serverId
  final String? statusId; // For status_reply type
  
  NotificationNavigationEvent({
    required this.type,
    this.id,
    this.statusId,
  });
}

/// Unified notification handling service
/// Handles all three Firebase messaging states:
/// - Terminated: getInitialMessage()
/// - Background: onMessageOpenedApp()
/// - Foreground: onMessage()
class UnifiedNotificationHandler {
  static final UnifiedNotificationHandler _instance =
      UnifiedNotificationHandler._internal();
  factory UnifiedNotificationHandler() => _instance;
  UnifiedNotificationHandler._internal();

  // Stream controller for navigation events
  final _navigationController = StreamController<NotificationNavigationEvent>.broadcast();
  Stream<NotificationNavigationEvent> get navigationStream => _navigationController.stream;

  // Store pending notification from terminated state
  NotificationNavigationEvent? _pendingEvent;
  bool _hasListener = false;

  /// Initialize all notification handlers
  /// Call this once in main.dart after Firebase is initialized
  Future<void> initialize() async {
    try {
      debugPrint('🔔 Initializing Unified Notification Handler');

      // Handle app terminated → notification tap
      _setupTerminatedStateHandler();

      // Handle app in background → notification tap
      _setupBackgroundStateHandler();

      // Handle app in foreground → notification received
      _setupForegroundStateHandler();

      // Monitor when listeners are added
      _navigationController.onListen = () {
        debugPrint('✅ Navigation stream listener added');
        _hasListener = true;
        
        // Emit pending event if any
        if (_pendingEvent != null) {
          debugPrint('🚀 Emitting pending notification event');
          _navigationController.add(_pendingEvent!);
          _pendingEvent = null;
        }
      };

      debugPrint('✅ Notification handlers initialized');
    } catch (e) {
      debugPrint('❌ Error initializing notification handlers: $e');
    }
  }

  /// App was terminated → user taps notification
  /// getInitialMessage() returns the message that started the app
  void _setupTerminatedStateHandler() {
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message == null) {
        debugPrint('📭 No initial message (app not started from notification)');
        return;
      }

      debugPrint('💀 Terminated state → ${message.messageId}');
      _handleNotificationTap(message);
    });
  }

  /// App was in background → user taps notification
  /// onMessageOpenedApp is called when user taps a notification
  void _setupBackgroundStateHandler() {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('🔖 Background state → ${message.messageId}');
      _handleNotificationTap(message);
    });
  }

  /// App in foreground → notification is displayed
  /// onMessage is called when the app receives a message while in foreground
  void _setupForegroundStateHandler() {
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('📱 Foreground state → ${message.messageId}');
      
      // The notification will be displayed by the notification service
      // But we can add custom handling here if needed
      
      // Optional: Handle special cases for foreground notifications
      final data = message.data;
      final type = data['type'];
      
      if (type == HybridMessagingService.messageType) {
        debugPrint('💬 Chat message received in foreground');
        // Notification service handles display and routing
      }
    });
  }

  /// Central handler for all notification taps
  /// Extracts data payload and routes to correct screen
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    try {
      final data = message.data;

      debugPrint('📩 Notification payload: $data');

      // Extract payload
      final chatId = data[HybridMessagingService.payloadKeyChatId];
      final senderId = data[HybridMessagingService.payloadKeySenderId];

      if (chatId == null) {
        debugPrint('⚠️ Missing chatId in notification payload');
        return;
      }

      debugPrint('✅ Routing to chat: $chatId');

      // Determine notification type
      final notifType = data['notification_type'] ?? data['type'] ?? 'chat';
      
      if (notifType == 'status_reply') {
        // Status reply notification
        final statusId = data['status_id'] ?? data['statusId'];
        if (statusId != null) {
          debugPrint('📢 Emitting status_reply navigation event');
          final event = NotificationNavigationEvent(
            type: 'status_reply',
            statusId: statusId,
          );
          
          if (_hasListener) {
            _navigationController.add(event);
          } else {
            _pendingEvent = event;
          }
        }
      } else if (notifType == 'server' || data['server_id'] != null) {
        // Server notification
        final serverId = data['server_id'] ?? chatId;
        debugPrint('📢 Emitting server navigation event');
        final event = NotificationNavigationEvent(
          type: 'server',
          id: serverId,
        );
        
        if (_hasListener) {
          _navigationController.add(event);
        } else {
          _pendingEvent = event;
        }
      } else {
        // Direct chat notification
        debugPrint('📢 Emitting chat navigation event');
        final event = NotificationNavigationEvent(
          type: 'chat',
          id: chatId,
        );
        
        // If listener not ready, store for later
        if (_hasListener) {
          _navigationController.add(event);
        } else {
          debugPrint('⏳ Storing pending event - listener not ready yet');
          _pendingEvent = event;
        }
      }

      // Also call hybrid messaging service for tracking
      await HybridMessagingService.handleNotificationClick(
        chatId,
        senderId: senderId,
      );
    } catch (e) {
      debugPrint('❌ Error handling notification tap: $e');
    }
  }
  
  /// Dispose resources
  void dispose() {
    _navigationController.close();
  }
}
