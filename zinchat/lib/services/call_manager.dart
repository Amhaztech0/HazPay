import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zinchat/screens/direct_call_screen.dart';
import 'package:zinchat/screens/server_call_screen.dart';
import 'package:zinchat/services/chat_service.dart';
import '../utils/debug_logger.dart';

/// Call Manager - Handles incoming calls, notifications, and call routing
class CallManager {
  static final CallManager _instance = CallManager._internal();
  factory CallManager() => _instance;
  CallManager._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  RealtimeChannel? _callChannel;
  GlobalKey<NavigatorState>? _navigatorKey;
  StreamSubscription<AuthState>? _authSubscription;

  bool _notificationsInitialized = false;
  bool _isDialogVisible = false;
  String? _activeCallId;
  final Map<String, String> _callerNameCache = {};
  final ChatService _chatService = ChatService();
  final Set<String> _callStatusNotified = {};

  NavigatorState? get _navigator => _navigatorKey?.currentState;
  BuildContext? get _currentContext =>
      _navigatorKey?.currentContext ??
      _navigatorKey?.currentState?.overlay?.context;

  /// Initialize call manager
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    if (!_notificationsInitialized) {
      await _initializeNotifications();
      _notificationsInitialized = true;
    }

    _authSubscription ??= _supabase.auth.onAuthStateChange.listen((
      AuthState data,
    ) {
      final userId = data.session?.user.id;
      if (userId != null) {
        _listenForIncomingCalls(userId);
      } else {
        _callChannel?.unsubscribe();
        _callChannel = null;
      }
    });

    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null && _callChannel == null) {
      _listenForIncomingCalls(currentUser.id);
    }
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels
    const androidChannel = AndroidNotificationChannel(
      'calls',
      'Calls',
      description: 'Incoming call notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  void _listenForIncomingCalls(String userId) {
    DebugLogger.call('Setting up incoming call listener for user: $userId');

    _callChannel = _supabase
        .channel('incoming_calls_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            DebugLogger.call('Received INSERT event: ${payload.newRecord}');
            _handleIncomingCall(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            DebugLogger.call('Received UPDATE event: ${payload.newRecord}');
            _handleCallUpdate(payload.newRecord);
          },
        )
        .subscribe((status, error) {
          DebugLogger.call('Channel subscription status: $status');
          if (error != null) {
            DebugLogger.error(
              'Channel subscription error: $error',
              tag: 'CALL',
            );
          }
        });
  }

  Future<void> _handleIncomingCall(Map<String, dynamic> callData) async {
    DebugLogger.call('Processing incoming call: $callData');

    try {
      final callId = callData['id'];
      final callType = callData['call_type'];
      final mediaType = callData['media_type'];
      final status = callData['status'];

      if (callId == null || callId.toString().isEmpty) {
        DebugLogger.error('Invalid callId in _handleIncomingCall', tag: 'CALL');
        return;
      }

      DebugLogger.call('Call status: $status');

      // Only handle initiated/ringing calls
      if (status != 'initiated' && status != 'ringing') {
        DebugLogger.call('Ignoring call with status: $status');
        return;
      }

      // Get caller info
      final callerId = callData['caller_id'];
      if (callerId == null || callerId.toString().isEmpty) {
        DebugLogger.error('Invalid callerId in _handleIncomingCall', tag: 'CALL');
        return;
      }

      DebugLogger.call('Fetching caller info for: $callerId');

      try {
        final callerInfo = await _supabase
            .from('profiles')
            .select('display_name')
            .eq('id', callerId.toString())
            .single();

        final callerName =
            (callerInfo['display_name'] as String?)?.trim().isNotEmpty == true
            ? callerInfo['display_name'] as String
            : 'Unknown';
        DebugLogger.call('Incoming call from: $callerName');

        if (callType == 'direct') {
          _showIncomingCallNotification(
            callId: callId.toString(),
            callerName: callerName,
            callerId: callerId.toString(),
            isVideo: mediaType == 'video',
          );

          // If app is in foreground, show in-app dialog
          _showInAppCallDialog(
            callId: callId.toString(),
            callerName: callerName,
            callerId: callerId.toString(),
            isVideo: mediaType == 'video',
          );
        } else if (callType == 'server') {
          // Handle server call notification
          final serverId = callData['server_id'];
          final channelId = callData['channel_id'];

          if (serverId == null || channelId == null) {
            DebugLogger.error(
              'Missing serverId or channelId in server call',
              tag: 'CALL',
            );
            return;
          }

          try {
            final serverInfo = await _supabase
                .from('servers')
                .select('name')
                .eq('id', serverId.toString())
                .single();

            final channelInfo = await _supabase
                .from('channels')
                .select('name')
                .eq('id', channelId.toString())
                .single();

            _showServerCallNotification(
              callId: callId.toString(),
              serverName: serverInfo['name'] ?? 'Unknown Server',
              channelName: channelInfo['name'] ?? 'Unknown Channel',
              callerName: callerName,
              isVideo: mediaType == 'video',
            );
          } catch (e) {
            DebugLogger.error(
              'Error fetching server/channel info: $e',
              tag: 'CALL',
            );
          }
        }
      } catch (e) {
        DebugLogger.error(
          'Error fetching caller info: $e',
          tag: 'CALL',
        );
      }
    } catch (e) {
      DebugLogger.error('Error in _handleIncomingCall: $e', tag: 'CALL');
    }
  }

  Future<void> _handleCallUpdate(Map<String, dynamic> callData) async {
    final callId = callData['id']?.toString() ?? '';
    final status = callData['status'] as String? ?? '';

    final callerName = _callerNameCache[callId];
    final callType = callData['call_type'] as String? ?? 'direct';
    final shouldStopRinging =
        status == 'ended' ||
        status == 'rejected' ||
        status == 'cancelled' ||
        status == 'missed' ||
        (status == 'active' && _activeCallId != callId);

    if (shouldStopRinging) {
      _notifications.cancel(callId.hashCode);
      _callerNameCache.remove(callId);

      if (_isDialogVisible) {
        final navigator = _navigator;
        if (navigator?.canPop() ?? false) {
          navigator!.pop();
        }
        _isDialogVisible = false;
      }

      if (_activeCallId == callId) {
        final navigator = _navigator;
        if (navigator?.canPop() ?? false) {
          navigator!.pop();
        }
        _activeCallId = null;
      }
    }

    if ((status == 'missed' || status == 'ended') && callType == 'direct') {
      await _maybeSendCallStatusMessage(
        callId: callId,
        callData: callData,
        callerName: callerName,
        status: status,
      );
    }
  }

  Future<void> _showIncomingCallNotification({
    required String callId,
    required String callerName,
    required String callerId,
    required bool isVideo,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'calls',
      'Calls',
      channelDescription: 'Incoming call notifications',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      actions: [
        AndroidNotificationAction('answer', 'Answer', showsUserInterface: true),
        AndroidNotificationAction(
          'decline',
          'Decline',
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      callId.hashCode,
      'Incoming ${isVideo ? 'Video' : 'Audio'} Call',
      '$callerName is calling...',
      details,
      payload: 'call:$callId:$callerId:$isVideo',
    );
  }

  Future<void> _showServerCallNotification({
    required String callId,
    required String serverName,
    required String channelName,
    required String callerName,
    required bool isVideo,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'calls',
      'Calls',
      channelDescription: 'Server call notifications',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      actions: [
        AndroidNotificationAction('join', 'Join', showsUserInterface: true),
        AndroidNotificationAction(
          'dismiss',
          'Dismiss',
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      callId.hashCode,
      'Server Call Started',
      '$callerName started a ${isVideo ? 'video' : 'voice'} call in #$channelName',
      details,
      payload: 'server_call:$callId',
    );
  }

  void _showInAppCallDialog({
    required String callId,
    required String callerName,
    required String callerId,
    required bool isVideo,
  }) {
    final context = _currentContext;
    if (context == null) return;

    _isDialogVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isVideo ? Icons.videocam : Icons.call,
              color: Colors.blue,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text('Incoming ${isVideo ? 'Video' : 'Audio'} Call'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
            const SizedBox(height: 16),
            Text(
              callerName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'is calling you...',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              _isDialogVisible = false;
              Navigator.pop(dialogContext);
              _declineCall(callId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.call_end),
            label: const Text('Decline'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _isDialogVisible = false;
              Navigator.pop(dialogContext);
              _answerCall(callId, callerId, callerName, isVideo);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.call),
            label: const Text('Answer'),
          ),
        ],
      ),
    ).whenComplete(() {
      _isDialogVisible = false;
    });
  }

  Future<void> _answerCall(
    String callId,
    String callerId,
    String callerName,
    bool isVideo,
  ) async {
    final navigator = _navigator;
    if (navigator == null) return;

    if (callId.isEmpty || callerId.isEmpty) {
      DebugLogger.error('Invalid callId or callerId in _answerCall', tag: 'CALL');
      return;
    }

    try {
      _activeCallId = callId;
      _notifications.cancel(callId.hashCode);

      await navigator.push(
        MaterialPageRoute(
          builder: (context) => DirectCallScreen(
            callId: callId,
            otherUserId: callerId,
            otherUserName: callerName,
            isIncoming: true,
            isVideo: isVideo,
          ),
        ),
      );

      _activeCallId = null;
    } catch (e) {
      DebugLogger.error('Error in _answerCall: $e', tag: 'CALL');
      _activeCallId = null;
    }
  }

  Future<void> _declineCall(String callId) async {
    _notifications.cancel(callId.hashCode);
    _callerNameCache.remove(callId);

    await _supabase
        .from('calls')
        .update({
          'status': 'rejected',
          'ended_at': DateTime.now().toIso8601String(),
        })
        .eq('id', callId);
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;

    final parts = response.payload!.split(':');
    if (parts.isEmpty) return;

    if (parts[0] == 'call' && parts.length >= 4) {
      final callId = parts[1];
      final callerId = parts[2];
      final isVideo = parts[3] == 'true';
      final callerName = _callerNameCache[callId] ?? 'Unknown';

      if (response.actionId == 'decline') {
        _declineCall(callId);
      } else {
        // Default tap or answer action both open the in-app screen
        _answerCall(callId, callerId, callerName, isVideo);
      }
    } else if (parts[0] == 'server_call' && parts.length >= 2) {
      final callId = parts[1];

      if (response.actionId == 'dismiss') {
        _notifications.cancel(callId.hashCode);
      } else {
        _joinServerCall(callId);
      }
    }
  }

  Future<void> _maybeSendCallStatusMessage({
    required String callId,
    required Map<String, dynamic> callData,
    required String? callerName,
    required String status,
  }) async {
    if (callId.isEmpty || _callStatusNotified.contains(callId)) return;

    final callerId = callData['caller_id']?.toString();
    if (callerId == null || callerId.isEmpty) return;

    if (status != 'missed' && status != 'ended') return;

    try {
      final chat = await _chatService.getOrCreateChat(callerId);
      final metadata = {
        'event': status,
        'isVideo': (callData['media_type'] as String?) == 'video',
        'duration_seconds': _calculateCallDurationSeconds(callData),
        'otherUserId': callerId,
        'otherUserName': callerName ?? 'Friend',
        'callId': callId,
        'callerId': callerId,
      };

      final inserted = await _chatService.sendCallStatusMessage(
        chatId: chat.id,
        metadata: metadata,
      );

      if (inserted != null) {
        _callStatusNotified.add(callId);
      }
    } catch (e) {
      DebugLogger.error('Error creating call status message: $e', tag: 'CALL');
    }
  }

  int _calculateCallDurationSeconds(Map<String, dynamic> callData) {
    final startedAt = callData['started_at'] as String?;
    final endedAt = callData['ended_at'] as String?;
    if (startedAt == null || endedAt == null) return 0;

    try {
      final start = DateTime.parse(startedAt);
      final end = DateTime.parse(endedAt);
      final diff = end.difference(start).inSeconds;
      return diff < 0 ? 0 : diff;
    } catch (e) {
      DebugLogger.error('Error parsing call duration: $e', tag: 'CALL');
      return 0;
    }
  }

  Future<void> _joinServerCall(String callId) async {
    final navigator = _navigator;
    if (navigator == null) return;

    try {
      if (callId.isEmpty) {
        DebugLogger.error('Invalid callId in _joinServerCall', tag: 'CALL');
        return;
      }

      final call = await _supabase
          .from('calls')
          .select('server_id, channel_id, media_type')
          .eq('id', callId)
          .maybeSingle();

      if (call == null) {
        DebugLogger.error('Call not found: $callId', tag: 'CALL');
        return;
      }

      final serverId = call['server_id'];
      final channelId = call['channel_id'];

      if (serverId == null || channelId == null) {
        DebugLogger.error('Missing serverId or channelId', tag: 'CALL');
        return;
      }

      try {
        final server = await _supabase
            .from('servers')
            .select('name')
            .eq('id', serverId.toString())
            .maybeSingle();

        final channel = await _supabase
            .from('channels')
            .select('name')
            .eq('id', channelId.toString())
            .maybeSingle();

        if (server == null || channel == null) {
          DebugLogger.error('Server or channel not found', tag: 'CALL');
          return;
        }

        final currentUserId = _supabase.auth.currentUser?.id;
        if (currentUserId == null) {
          DebugLogger.error('User not authenticated', tag: 'CALL');
          return;
        }

        final userProfile = await _supabase
            .from('profiles')
            .select('display_name')
            .eq('id', currentUserId)
            .maybeSingle();

        if (userProfile == null) {
          DebugLogger.error('User profile not found', tag: 'CALL');
          return;
        }

        await navigator.push(
          MaterialPageRoute(
            builder: (context) => ServerCallScreen(
              callId: callId,
              serverName: server['name'] ?? 'Unknown Server',
              channelName: channel['name'] ?? 'Unknown Channel',
              userName: userProfile['display_name'] ?? 'You',
              isVideo: call['media_type'] == 'video',
            ),
          ),
        );
      } catch (e) {
        DebugLogger.error('Error fetching server/channel/user data: $e', tag: 'CALL');
      }
    } catch (e) {
      DebugLogger.error('Error in _joinServerCall: $e', tag: 'CALL');
    }
  }

  /// Start an outgoing 1-on-1 call
  Future<void> startDirectCall({
    required BuildContext context,
    required String receiverId,
    required String receiverName,
    required bool isVideo,
  }) async {
    // Import WebRTC service here to avoid circular dependency
    // You'll need to create the call ID first, then navigate
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DirectCallScreen(
          callId: '', // Will be created in the screen
          otherUserId: receiverId,
          otherUserName: receiverName,
          isIncoming: false,
          isVideo: isVideo,
        ),
      ),
    );
  }

  /// Start a server call
  Future<void> startServerCall({
    required BuildContext context,
    required String serverId,
    required String serverName,
    required String channelId,
    required String channelName,
    required String userName,
    required bool isVideo,
  }) async {
    // Create call record first
    final nav = _navigator ?? Navigator.of(context);
    final messenger = ScaffoldMessenger.of(nav.context);
    try {
      final response = await _supabase
          .from('calls')
          .insert({
            'call_type': 'server',
            'media_type': isVideo ? 'video' : 'audio',
            'server_id': serverId,
            'channel_id': channelId,
            'caller_id': _supabase.auth.currentUser!.id,
            'status': 'active',
          })
          .select()
          .single();

      await nav.push(
        MaterialPageRoute(
          builder: (context) => ServerCallScreen(
            callId: response['id'],
            serverName: serverName,
            channelName: channelName,
            userName: userName,
            isVideo: isVideo,
          ),
        ),
      );
    } catch (e) {
      DebugLogger.error('Error starting server call: $e', tag: 'CALL');
      messenger.showSnackBar(SnackBar(content: Text('Failed to start call: $e')));
    }
  }

  void dispose() {
    _callChannel?.unsubscribe();
    _authSubscription?.cancel();
    _authSubscription = null;
  }
}
