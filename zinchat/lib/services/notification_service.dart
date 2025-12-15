import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'server_service.dart';
import '../screens/chat/chat_screen.dart';
import '../models/user.dart';
import '../screens/servers/server_chat_screen.dart';
import 'unified_notification_handler.dart';

/// Handles FCM token management and push notification display
/// Implements high-priority messaging notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  // Native method channel for notification taps
  static const _notificationChannel = MethodChannel('com.example.zinchat/notification');

  // Stream controller for navigation events
  final _navigationController = StreamController<NotificationNavigationEvent>.broadcast();
  Stream<NotificationNavigationEvent> get navigationStream => _navigationController.stream;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Store initial notification for cold start
  RemoteMessage? _pendingInitialMessage;
  NotificationNavigationEvent? _pendingNavigationEvent;
  
  // Track recently handled message IDs to prevent duplicates
  final Set<String> _recentlyHandledMessages = {};
  static const int _handledMessageCacheDuration = 5000; // 5 seconds

  /// Track which chat screen is currently open
  static String? _activeChatId;
  static String? get activeChatId => _activeChatId;
  
  /// Track which server chat is currently open
  static String? _activeServerChatId;
  static String? get activeServerChatId => _activeServerChatId;

  /// Set active chat (call when opening 1-on-1 chat)
  static void setActiveChatId(String? chatId) {
    _activeChatId = chatId;
  }

  /// Set active server chat (call when opening server chat)
  static void setActiveServerChatId(String? serverId) {
    _activeServerChatId = serverId;
  }

  /// Initialize Firebase and notification services
  Future<void> initialize() async {
    try {
      // Initialize Firebase
      await Firebase.initializeApp();

      // Request notification permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('✅ Notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Initialize local notifications
        await _initializeLocalNotifications();

        // Get FCM token
        await _getFCMToken();

        // Setup message handlers
        _setupMessageHandlers();
        
        // Setup native notification tap handler
        _setupNativeNotificationHandler();
      }
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }
  
  /// Setup native method channel listener for notification taps
  void _setupNativeNotificationHandler() {
    debugPrint('🔔 Setting up native notification handler');
    
    _notificationChannel.setMethodCallHandler((call) async {
      debugPrint('🔔 Native method call received: ${call.method}');
      
      if (call.method == 'onNotificationTapped') {
        final payload = call.arguments as String?;
        debugPrint('🔔 ✅ Native notification tap detected with payload: $payload');
        
        if (payload != null && payload.isNotEmpty) {
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            _handleNotificationPayload(data);
          } catch (e) {
            debugPrint('🔔 ❌ Error parsing native notification payload: $e');
          }
        }
      }
      
      return null;
    });
    
    // Check for pending notification from cold start
    _checkPendingNativeNotification();
  }
  
  /// Check if there's a pending notification from cold start
  Future<void> _checkPendingNativeNotification() async {
    try {
      final payload = await _notificationChannel.invokeMethod<String>('getPendingNotificationPayload');
      debugPrint('🔔 Pending native notification payload: $payload');
      
      if (payload != null && payload.isNotEmpty) {
        debugPrint('🔔 ✅ Processing pending native notification');
        final data = jsonDecode(payload) as Map<String, dynamic>;
        _handleNotificationPayload(data);
      }
    } catch (e) {
      debugPrint('🔔 Error checking pending native notification: $e');
    }
  }
  
  /// Handle notification payload from either source
  void _handleNotificationPayload(Map<String, dynamic> data) {
    debugPrint('🔔 Processing notification payload: $data');
    
    final messageType = data['type']?.toString() ?? 'direct_message';
    final chatId = data['chat_id']?.toString() ?? '';
    final serverId = data['server_id']?.toString() ?? '';
    final statusId = data['status_id']?.toString() ?? '';
    
    debugPrint('🔔 Extracted: type=$messageType, chatId=$chatId, serverId=$serverId, statusId=$statusId');
    
    if (messageType == 'status_reply' && statusId.isNotEmpty) {
      debugPrint('🔔 ✅ Navigating to status replies: $statusId');
      _navigateToStatusReplies(statusId);
    } else if (messageType == 'server_message' && serverId.isNotEmpty) {
      debugPrint('🔔 ✅ Navigating to server: $serverId');
      _navigateToServerChat(serverId);
    } else if (chatId.isNotEmpty) {
      debugPrint('🔔 ✅ Navigating to chat: $chatId');
      _navigateToChat(chatId);
    } else {
      debugPrint('🔔 ❌ No valid ID in payload');
    }
  }

  /// Initialize flutter_local_notifications with high-priority setup
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'message_notification',
          actions: [
            DarwinNotificationAction.plain(
              'open',
              'Open',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'reply',
              'Reply',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
      ],
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initialized = await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    
    debugPrint('🔔 Local notifications initialized: $initialized');
    debugPrint('🔔 Notification tap callback has been registered');
  }

  /// Get FCM token and save to Supabase
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('📱 FCM Token: $_fcmToken');

      if (_fcmToken != null) {
        await _saveFCMTokenToSupabase(_fcmToken!);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFCMTokenToSupabase(newToken);
      });
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Save FCM token to Supabase user_tokens table
  Future<void> _saveFCMTokenToSupabase(String token) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('⚠️ No user logged in, cannot save FCM token');
        return;
      }

      // Upsert token to user_tokens table
      await supabase.from('user_tokens').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': 'android', // or 'ios' based on platform
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ FCM token saved to Supabase for user: $userId');
    } catch (e) {
      debugPrint('❌ Error saving FCM token to Supabase: $e');
    }
  }

  /// Public method to save FCM token after login
  /// Call this after successful authentication
  Future<void> saveTokenAfterLogin() async {
    debugPrint('🔄 Attempting to save FCM token after login...');
    
    if (_fcmToken != null) {
      debugPrint('📱 Found existing FCM token: $_fcmToken');
      await _saveFCMTokenToSupabase(_fcmToken!);
    } else {
      debugPrint('🔄 No FCM token yet, requesting new one...');
      await _getFCMToken();
    }
  }

  /// Setup message handlers for foreground and background
  void _setupMessageHandlers() {
    // Foreground messages - Handle in-app
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📬 Foreground message received: ${message.messageId}');
      _handleForegroundMessage(message);
    });

    // Background message tap - THIS IS THE MAIN HANDLER FOR NAVIGATION
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 Notification tapped (background): ${message.messageId}');
      _handleNotificationTap(message);
    });

    // Check if app was opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('🔔 App opened from notification (terminated): ${message.messageId}');
        // Store it for later handling when HomeScreen is ready
        _pendingInitialMessage = message;
      }
    });
    
    // Local notification tap handler - route to FCM handler for consistency
    _localNotifications.getNotificationAppLaunchDetails().then((details) {
      if (details?.didNotificationLaunchApp == true) {
        debugPrint('🔔 App launched from local notification');
        // The actual payload handling is done in onDidReceiveNotificationResponse
      }
    });
  }

  /// Call this from HomeScreen to handle any pending notification navigation
  Future<void> handlePendingNavigation() async {
    debugPrint('🔔 Checking for pending notification...');
    var handled = false;

    // Check if app was launched from a notification tap
    try {
      final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
      debugPrint('🔔 Launch details: didLaunch=${launchDetails?.didNotificationLaunchApp}, payload=${launchDetails?.notificationResponse?.payload}');
      
      if (launchDetails?.didNotificationLaunchApp == true) {
        final response = launchDetails!.notificationResponse;
        if (response != null && response.payload != null) {
          debugPrint('🔔 ✅ App launched from notification, processing payload...');
          _onNotificationTap(response);
          handled = true;
        }
      }
    } catch (e) {
      debugPrint('🔔 ❌ Error checking launch details: $e');
    }

    if (_pendingInitialMessage != null) {
      debugPrint('🔔 ✅ Found pending FCM notification: ${_pendingInitialMessage!.messageId}');
      debugPrint('🔔 Data: ${_pendingInitialMessage!.data}');
      _handleNotificationTap(_pendingInitialMessage!);
      _pendingInitialMessage = null; // Clear it after handling
      handled = true;
    }

    if (_pendingNavigationEvent != null) {
      debugPrint('🔔 ✅ Delivering pending navigation event: ${_pendingNavigationEvent!.type}-${_pendingNavigationEvent!.id}');
      if (_navigationController.hasListener) {
        _navigationController.add(_pendingNavigationEvent!);
        _pendingNavigationEvent = null;
        handled = true;
      } else {
        debugPrint('🔔 ⏳ No navigation listeners yet; keeping pending event until listener registers');
      }
    }

    if (!handled) {
      debugPrint('🔔 No pending notification to handle');
    }
  }

  /// Handle foreground messages intelligently
  /// If chat is open, show in-app notification. Otherwise, show system notification.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final messageType = data['type']; // 'direct_message', 'server_message', or 'status_reply'
    final chatId = data['chat_id']; // For direct messages
    final serverId = data['server_id']; // For server messages
    final statusId = data['status_id']; // For status replies
    final messageContent = data['content'] ?? 'New message';
    final senderName = data['sender_name'] ?? data['replier_name'] ?? 'Someone';

    debugPrint('📬 Message data received:');
    debugPrint('   - type: $messageType');
    debugPrint('   - chat_id: $chatId');
    debugPrint('   - server_id: $serverId');
    debugPrint('   - status_id: $statusId');
    debugPrint('   - content: $messageContent');
    debugPrint('   - sender: $senderName');

    // Check if server notifications are enabled (if it's a server message)
    if (messageType == 'server_message' && serverId != null) {
      final serverService = ServerService();
      final notificationsEnabled = await serverService.areNotificationsEnabled(serverId);
      
      if (!notificationsEnabled) {
        debugPrint('🔕 Server notifications disabled for server: $serverId');
        return; // Don't show notification
      }
    }

    // Check if the relevant chat is open
    bool isChatOpen = false;
    
    if (messageType == 'direct_message' && chatId == _activeChatId) {
      isChatOpen = true;
      debugPrint('💬 Direct chat is open: $chatId');
    } else if (messageType == 'server_message' && serverId == _activeServerChatId) {
      isChatOpen = true;
      debugPrint('💬 Server chat is open: $serverId');
    } else if (messageType == 'status_reply') {
      // Status reply notifications are always shown (not suppressed like chat)
      debugPrint('📸 Status reply notification - always show');
    }

    if (isChatOpen && messageType != 'status_reply') {
      // Chat is open (and not a status reply) - show in-app notification banner
      _showInAppNotification(senderName, messageContent);
    } else {
      // Chat is not open or this is a status reply - show system notification
      debugPrint('📱 Showing system notification...');
      await _showLocalNotification(message);
    }
  }

  /// Show in-app notification banner (doesn't interrupt user)
  void _showInAppNotification(String senderName, String messageContent) {
    // This would typically show an overlay notification
    // For now, just log it - implement in main.dart with OverlayEntry
    debugPrint('💬 In-app notification: $senderName: $messageContent');
  }

  /// Display high-priority notification in system tray
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final data = message.data;
      final senderName = data['sender_name'] ?? notification?.title ?? 'New Message';
      final messagePreview = notification?.body ?? data['content'] ?? '';
      final chatId = data['chat_id'] ?? data['server_id'] ?? '';
      final serverId = data['server_id'];
      final messageType = data['type'];

      debugPrint('📱 _showLocalNotification called:');
      debugPrint('   - senderName: $senderName');
      debugPrint('   - messagePreview: $messagePreview');
      debugPrint('   - chatId: $chatId');
      debugPrint('   - serverId: $serverId');

      // Check if server notifications are enabled (if it's a server message)
      if (messageType == 'server_message' && serverId != null) {
        final serverService = ServerService();
        final notificationsEnabled = await serverService.areNotificationsEnabled(serverId);
        
        if (!notificationsEnabled) {
          debugPrint('🔕 Server notifications disabled, skipping notification for server: $serverId');
          return; // Don't show notification
        }
      }

      if (notification != null || messagePreview.isNotEmpty) {
        // Android: High-priority notification
        final androidDetails = AndroidNotificationDetails(
          'zinchat_messages', // channel ID
          'Messages', // channel name
          channelDescription: 'New message notifications',
          importance: Importance.max, // Highest priority
          priority: Priority.max, // Show on lock screen
          showWhen: true,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF00CED1), // App primary color
          enableVibration: true,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('notification_sound'),
          // Big text notification
          styleInformation: BigTextStyleInformation(
            messagePreview,
            htmlFormatBigText: true,
            contentTitle: senderName,
            htmlFormatContentTitle: true,
          ),
          // Threading/grouping (Android 7+)
          groupKey: 'zinchat_messages',
          setAsGroupSummary: false,
          autoCancel: true,
          ongoing: false,
          silent: false,
          // Vibration pattern
          vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
        );

        // iOS: Critical alert + rich notifications
        final iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification_sound.aiff',
          categoryIdentifier: 'message_notification',
          threadIdentifier: chatId,
          // For iOS 15+, show as time-sensitive banner
          interruptionLevel: InterruptionLevel.timeSensitive,
        );

        final details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        // Use a hash of chatId to group similar notifications
        final notificationId = chatId.hashCode;
        
        // Build payload with all necessary data
        // This payload will be used if user taps local notification
        final payloadData = {
          'type': messageType ?? 'direct_message',
          'chat_id': data['chat_id'] ?? '',
          'server_id': data['server_id'] ?? '',
          'status_id': data['status_id'] ?? '',
          'sender_name': senderName,
          'message_id': data['message_id'] ?? '',
        };
        final payloadJson = jsonEncode(payloadData);

        await _localNotifications.show(
          notificationId,
          senderName,
          messagePreview,
          details,
          payload: payloadJson,
        );

        debugPrint('✅ Notification shown: $senderName - $messagePreview');
        debugPrint('📦 Payload: $payloadJson');
      } else {
        debugPrint('⚠️ No notification title or body to display');
      }
    } catch (e) {
      debugPrint('❌ Error showing local notification: $e');
      debugPrint('❌ Stack trace: $e');
    }
  }

  /// Handle notification tap (from local notification)
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('🔔 Flutter local notification tapped: ${response.payload}');
    
    try {
      final payload = response.payload;
      if (payload == null || payload.isEmpty) {
        debugPrint('⚠️ Local notification payload is empty!');
        return;
      }

      final data = jsonDecode(payload) as Map<String, dynamic>;
      debugPrint('📦 Decoded Payload: $data');
      _handleNotificationPayload(data);

    } catch (e, stackTrace) {
      debugPrint('❌ Error handling local notification tap: $e');
      debugPrint('❌ Stack trace: $stackTrace');
    }
  }

  /// Handle notification tap (from FCM) - PRIMARY NAVIGATION HANDLER
  /// This is called when user taps notification from any state:
  /// - Background app
  /// - Terminated app  
  /// - Foreground (if tap reaches here)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('🔔 FCM notification tapped!');
    debugPrint('🔔 Message ID: ${message.messageId}');
    debugPrint('🔔 Data: ${message.data}');
    
    // Check if we've already handled this message recently (deduplication)
    if (_isRecentlyHandled(message.messageId ?? '')) {
      debugPrint('⏭️ Skipping duplicate notification handling');
      return;
    }
    
    final data = message.data;
    final messageType = data['type']; // 'direct_message' or 'server_message'
    final chatId = data['chat_id'];
    final serverId = data['server_id'];

    debugPrint('🔔 Message type: $messageType');
    debugPrint('🔔 Chat ID: $chatId');
    debugPrint('🔔 Server ID: $serverId');

    if (messageType == 'server_message' && serverId != null && serverId.isNotEmpty) {
      debugPrint('🔔 ✅ Navigating to server chat: $serverId');
      _navigateToServerChat(serverId);
    } else if ((messageType == 'direct_message' || messageType == null) && chatId != null && chatId.isNotEmpty) {
      debugPrint('🔔 ✅ Navigating to direct chat: $chatId');
      _navigateToChat(chatId);
    } else {
      debugPrint('❌ No valid chat_id or server_id found in notification data!');
      debugPrint('❌ Data received: $data');
    }
  }

  /// Navigate to direct message chat
  void _navigateToChat(String chatId) {
    debugPrint('📍 Navigating to chat: $chatId');
    // Try to perform navigation immediately using Supabase and navigatorKey.
    // This handles taps that open the app from terminated/background states
    // where HomeScreen might not yet be ready to handle events.
    (() async {
      try {
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          final response = await supabase
              .from('chats')
              .select()
              .eq('id', chatId)
              .single();

          final otherUserId = response['user1_id'] == userId
              ? response['user2_id']
              : response['user1_id'];

          final profileResponse = await supabase
              .from('profiles')
              .select()
              .eq('id', otherUserId)
              .single();

          final userModel = UserModel.fromJson(profileResponse);

          // If navigator is available, push the chat screen directly
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatId: chatId,
                  otherUser: userModel,
                ),
              ),
            );
            debugPrint('✅ Directly navigated to chat via navigatorKey: $chatId');
            return;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Direct navigation attempt failed: $e');
      }

      // Fallback: emit navigation event for HomeScreen to handle
      _emitNavigationEvent(NotificationNavigationEvent(
        type: 'chat',
        id: chatId,
      ));
    })();
  }

  /// Navigate to server chat
  void _navigateToServerChat(String serverId) {
    debugPrint('📍 Navigating to server chat: $serverId');
    (() async {
      try {
        final serverService = ServerService();
        final server = await serverService.getServerById(serverId);
        if (server != null && navigatorKey.currentState != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ServerChatScreen(server: server),
            ),
          );
          debugPrint('✅ Directly navigated to server chat via navigatorKey: $serverId');
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Direct server navigation attempt failed: $e');
      }

      // Fallback to emitting an event for HomeScreen to handle
      _emitNavigationEvent(NotificationNavigationEvent(
        type: 'server',
        id: serverId,
      ));
    })();
  }

  /// Navigate to status replies screen
  void _navigateToStatusReplies(String statusId) {
    debugPrint('📍 Navigating to status replies: $statusId');
    // Emit navigation event for HomeScreen to handle
    // Status replies are shown in a modal/screen that needs proper context
    _emitNavigationEvent(NotificationNavigationEvent(
      type: 'status_reply',
      statusId: statusId,
    ));
  }

  void _emitNavigationEvent(NotificationNavigationEvent event) {
    debugPrint('🔔 _emitNavigationEvent called: ${event.type} - ${event.id ?? event.statusId}');
    debugPrint('🔔 Has listeners: ${_navigationController.hasListener}');
    
    if (_navigationController.hasListener) {
      debugPrint('🔔 ✅ Emitting event to listeners');
      _navigationController.add(event);
    } else {
      debugPrint('🔔 ⏳ No navigation listeners yet, storing pending event');
      _pendingNavigationEvent = event;
    }
  }
  
  /// Check if message was recently handled (deduplication)
  bool _isRecentlyHandled(String messageId) {
    if (messageId.isEmpty) {
      return false;
    }
    final isRecent = _recentlyHandledMessages.contains(messageId);
    if (isRecent) {
      debugPrint('⚠️ Message already handled recently: $messageId');
      return true;
    }
    
    // Add to cache
    _recentlyHandledMessages.add(messageId);
    debugPrint('✅ Added to handled cache: $messageId');
    
    // Remove from cache after delay
    Future.delayed(const Duration(milliseconds: _handledMessageCacheDuration), () {
      _recentlyHandledMessages.remove(messageId);
      debugPrint('🧹 Removed from cache: $messageId');
    });
    
    return false;
  }

  /// Delete FCM token from Supabase on logout
  Future<void> deleteTokenOnLogout() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null && _fcmToken != null) {
        await supabase
            .from('user_tokens')
            .delete()
            .eq('user_id', userId)
            .eq('fcm_token', _fcmToken!);
        
        debugPrint('✅ FCM token deleted from Supabase');
      }
    } catch (e) {
      debugPrint('❌ Error deleting FCM token: $e');
    }
  }

  /// Cleanup on app close
  void dispose() {
    _activeChatId = null;
    _activeServerChatId = null;
    _navigationController.close();
  }
}
