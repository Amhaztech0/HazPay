# 🔧 Firebase Integration - Implementation Examples

## Real-World Implementation Examples

This document shows practical examples of how to integrate error tracking and analytics into existing ZinChat services.

---

## 1. Authentication Service Integration

### File: `lib/services/auth_service.dart`

```dart
import 'analytics_service.dart' as analytics;
import 'error_tracking_service.dart' as error_tracking;

class AuthService {
  final _analytics = analytics.AnalyticsService();
  final _errorTracking = error_tracking.ErrorTrackingService();

  Future<AuthResponse?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // ✅ Track successful login
        await _analytics.logUserLogin(method: 'email');
        await _analytics.setUserId(response.user!.id);
        
        // ✅ Set user ID for crash reports
        await _errorTracking.setUserId(response.user!.id);
        
        // ✅ Log custom event
        await _analytics.logCustomEvent(
          eventName: 'user_authenticated',
          parameters: {
            'method': 'email',
            'provider': 'supabase',
          },
        );

        debugPrint('✅ User logged in: ${response.user!.email}');
      }

      return response;
    } catch (e, stack) {
      // ✅ Track auth errors
      await _errorTracking.logAuthError(
        errorDescription: e.toString(),
        userId: email,
      );
      
      debugPrint('❌ Login failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabaseClient.auth.signOut();
      
      // ✅ Track logout
      await _analytics.logCustomEvent(eventName: 'user_logout');
      
      debugPrint('✅ User logged out');
    } catch (e, stack) {
      // ✅ Track logout errors
      await _errorTracking.recordError(
        exception: e,
        stack: stack,
        context: 'User Logout',
      );
      
      debugPrint('❌ Logout failed: $e');
      rethrow;
    }
  }

  Future<bool> createAccount({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // ✅ Track signup
        await _analytics.logUserSignup(method: 'email');
        await _analytics.setUserId(response.user!.id);
        await _errorTracking.setUserId(response.user!.id);
        
        // ✅ Set user properties
        await _analytics.setUserProperties(
          properties: {
            'signup_method': 'email',
            'account_created_at': DateTime.now().toIso8601String(),
          },
        );
      }

      return response.user != null;
    } catch (e, stack) {
      // ✅ Track signup errors
      await _errorTracking.recordError(
        exception: e,
        stack: stack,
        context: 'User Signup',
        customData: {'email': email},
      );
      
      debugPrint('❌ Signup failed: $e');
      rethrow;
    }
  }
}
```

---

## 2. Chat Service Integration

### File: `lib/services/chat_service.dart`

```dart
import 'analytics_service.dart' as analytics;
import 'error_tracking_service.dart' as error_tracking;

class ChatService {
  final _analytics = analytics.AnalyticsService();
  final _errorTracking = error_tracking.ErrorTrackingService();

  Future<void> sendMessage({
    required String content,
    required String chatId,
    String? mediaUrl,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      
      // Insert message
      final response = await supabase.from('messages').insert({
        'content': content,
        'chat_id': chatId,
        'user_id': userId,
        'media_url': mediaUrl,
      }).select();

      if (response.isNotEmpty) {
        // ✅ Track message sent
        await _analytics.logMessageSent(
          messageType: 'direct_message',
          hasMedia: mediaUrl != null,
        );
        
        // ✅ Log custom event
        await _errorTracking.logUserAction(
          action: 'message_sent',
          details: 'Chat: $chatId',
        );
      }

      return true;
    } catch (e, stack) {
      // ✅ Track messaging errors
      await _errorTracking.logMessagingError(
        messageType: 'direct_message',
        errorDescription: e.toString(),
        recipientId: chatId,
      );
      
      debugPrint('❌ Failed to send message: $e');
      rethrow;
    }
  }

  Future<void> _sendNotification({
    required String recipientId,
    required String messageId,
    required String content,
  }) async {
    try {
      // Notification sending logic
      
      // ✅ Track notification
      await _errorTracking.logUserAction(
        action: 'notification_sent',
        details: 'Recipient: $recipientId',
      );
    } catch (e, stack) {
      // ✅ Track notification errors (non-fatal)
      await _errorTracking.recordError(
        exception: e,
        stack: stack,
        context: 'Notification Sending',
        customData: {
          'recipient_id': recipientId,
          'message_id': messageId,
        },
      );
      
      // Don't rethrow - notifications aren't critical
      debugPrint('⚠️  Notification failed: $e');
    }
  }

  Future<List<ChatMessage>> getMessages(String chatId) async {
    try {
      final messages = await supabase
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at', ascending: false)
          .limit(50);

      // ✅ Track message view
      await _analytics.logMessageViewed(
        messageType: 'direct_message',
      );

      return messages.map((m) => ChatMessage.fromJson(m)).toList();
    } catch (e, stack) {
      // ✅ Track retrieval errors
      await _errorTracking.recordError(
        exception: e,
        stack: stack,
        context: 'Messages Retrieval',
        customData: {'chat_id': chatId},
      );
      
      debugPrint('❌ Failed to get messages: $e');
      rethrow;
    }
  }
}
```

---

## 3. Server Service Integration

### File: `lib/services/server_service.dart`

```dart
import 'analytics_service.dart' as analytics;
import 'error_tracking_service.dart' as error_tracking;

class ServerService {
  final _analytics = analytics.AnalyticsService();
  final _errorTracking = error_tracking.ErrorTrackingService();

  Future<bool> joinServer(String serverId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      
      await supabase.from('server_members').insert({
        'server_id': serverId,
        'user_id': userId,
      });

      // ✅ Track server interaction
      await _analytics.logServerInteraction(
        action: 'join',
        serverId: serverId,
      );

      return true;
    } catch (e, stack) {
      // ✅ Track server join errors
      await _errorTracking.recordError(
        exception: e,
        stack: stack,
        context: 'Server Join',
        customData: {'server_id': serverId},
      );
      
      debugPrint('❌ Failed to join server: $e');
      return false;
    }
  }

  Future<bool> sendMessage({
    required String serverId,
    required String content,
  }) async {
    try {
      await supabase.from('server_messages').insert({
        'server_id': serverId,
        'user_id': supabase.auth.currentUser!.id,
        'content': content,
      });

      // ✅ Track server message
      await _analytics.logMessageSent(
        messageType: 'server_message',
        serverId: serverId,
      );

      return true;
    } catch (e, stack) {
      // ✅ Track server messaging errors
      await _errorTracking.logMessagingError(
        messageType: 'server_message',
        errorDescription: e.toString(),
        recipientId: serverId,
      );
      
      debugPrint('❌ Failed to send server message: $e');
      return false;
    }
  }

  Future<void> createServer({
    required String name,
    required String description,
  }) async {
    try {
      final response = await supabase.from('servers').insert({
        'name': name,
        'description': description,
        'owner_id': supabase.auth.currentUser!.id,
      }).select();

      if (response.isNotEmpty) {
        final newServerId = response[0]['id'];
        
        // ✅ Track server creation
        await _analytics.logServerInteraction(
          action: 'create',
          serverId: newServerId,
        );
        
        // ✅ Set custom property
        await _errorTracking.setCustomKey(
          'last_server_created',
          newServerId,
        );
      }
    } catch (e, stack) {
      // ✅ Track server creation errors
      await _errorTracking.recordError(
        exception: e,
        stack: stack,
        context: 'Server Creation',
        customData: {
          'server_name': name,
        },
      );
      
      debugPrint('❌ Failed to create server: $e');
      rethrow;
    }
  }
}
```

---

## 4. Call Manager Integration

### File: `lib/services/call_manager.dart`

```dart
import 'analytics_service.dart' as analytics;
import 'error_tracking_service.dart' as error_tracking;

class CallManager {
  final _analytics = analytics.AnalyticsService();
  final _errorTracking = error_tracking.ErrorTrackingService();
  final _callStopwatch = Stopwatch();

  Future<void> initiateCalls({
    required String callType, // 'direct_call', 'group_call'
    required List<String> participantIds,
  }) async {
    try {
      _callStopwatch.start();
      
      // Call initialization logic
      
      // ✅ Track call initiated
      await _analytics.logCallInitiated(
        callType: callType,
        participantCount: participantIds.length.toString(),
      );
      
      await _errorTracking.logUserAction(
        action: 'call_initiated',
        details: 'Type: $callType, Participants: ${participantIds.length}',
      );

    } catch (e, stack) {
      // ✅ Track call initiation errors
      await _errorTracking.logCallError(
        callType: callType,
        errorDescription: e.toString(),
        participantId: participantIds.firstOrNull,
      );
      
      debugPrint('❌ Failed to initiate call: $e');
      rethrow;
    }
  }

  Future<void> endCall() async {
    try {
      _callStopwatch.stop();
      final durationSeconds = _callStopwatch.elapsed.inSeconds;
      
      // Call cleanup logic
      
      // ✅ Track call duration
      await _analytics.logCallDuration(
        callType: 'direct_call', // Get actual type
        durationSeconds: durationSeconds,
      );
      
      // ✅ Log call end event
      await _errorTracking.logUserAction(
        action: 'call_ended',
        details: 'Duration: ${durationSeconds}s',
      );
      
      _callStopwatch.reset();

    } catch (e, stack) {
      // ✅ Track call ending errors
      await _errorTracking.recordError(
        exception: e,
        stack: stack,
        context: 'Call End',
      );
      
      debugPrint('❌ Error ending call: $e');
    }
  }

  Future<void> handleCallError(String errorDescription) async {
    // ✅ Track call errors
    await _errorTracking.logCallError(
      callType: 'direct_call', // Get actual type
      errorDescription: errorDescription,
    );
    
    debugPrint('❌ Call error: $errorDescription');
  }
}
```

---

## 5. Screen Navigation Integration

### File: `lib/screens/home/home_screen.dart`

```dart
import 'services/analytics_service.dart' as analytics;

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _analytics = analytics.AnalyticsService();

  @override
  void initState() {
    super.initState();
    
    // ✅ Track screen view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analytics.logScreenView('HomeScreen');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ZinChat')),
      body: Column(
        children: [
          // Chat list
          ElevatedButton(
            onPressed: () {
              // ✅ Track feature usage
              _analytics.logFeatureUsage('open_chats');
              // Navigate...
            },
            child: Text('Chats'),
          ),
          
          // Servers
          ElevatedButton(
            onPressed: () {
              _analytics.logFeatureUsage('open_servers');
              // Navigate...
            },
            child: Text('Servers'),
          ),
          
          // Voice call
          ElevatedButton(
            onPressed: () {
              _analytics.logFeatureUsage('voice_call_button');
              // Start call...
            },
            child: Text('Start Call'),
          ),
        ],
      ),
    );
  }
}
```

---

## 6. Search Integration

### File: `lib/screens/search_screen.dart`

```dart
import 'services/analytics_service.dart' as analytics;
import 'services/error_tracking_service.dart' as error_tracking;

class SearchScreen extends StatefulWidget {
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _analytics = analytics.AnalyticsService();
  final _errorTracking = error_tracking.ErrorTrackingService();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _analytics.logScreenView('SearchScreen');
  }

  void _onSearch(String query) async {
    try {
      if (query.isEmpty) return;

      final results = await performSearch(query);

      // ✅ Track search
      await _analytics.logSearch(
        searchTerm: query,
        searchType: 'global_search',
        resultCount: results.length,
      );

      // Update UI with results
    } catch (e, stack) {
      // ✅ Track search errors
      await _errorTracking.recordError(
        exception: e,
        stack: stack,
        context: 'Search Operation',
        customData: {
          'search_term': query,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      controller: _searchController,
      onChanged: _onSearch,
    );
  }
}
```

---

## 7. Share Integration

### File: `lib/screens/chat/message_detail_screen.dart`

```dart
import 'services/analytics_service.dart' as analytics;

class MessageDetailScreen extends StatefulWidget {
  final Message message;

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  final _analytics = analytics.AnalyticsService();

  void _shareMessage() async {
    try {
      // ✅ Track share
      await _analytics.logShare(
        contentType: 'message',
        itemId: widget.message.id,
      );

      // Actual share logic
      Share.share(widget.message.content);
    } catch (e) {
      debugPrint('❌ Share failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.share),
      onPressed: _shareMessage,
    );
  }
}
```

---

## 8. Ad Integration

### File: `lib/widgets/ad_widget.dart`

```dart
import 'services/analytics_service.dart' as analytics;
import 'services/error_tracking_service.dart' as error_tracking;

class AdWidget extends StatefulWidget {
  @override
  State<AdWidget> createState() => _AdWidgetState();
}

class _AdWidgetState extends State<AdWidget> {
  final _analytics = analytics.AnalyticsService();
  final _errorTracking = error_tracking.ErrorTrackingService();

  void _onAdLoaded() {
    // ✅ Track ad impression
    _analytics.logAdImpression(
      adUnit: 'banner_home',
      adFormat: 'banner',
    );
  }

  void _onAdClicked() {
    // ✅ Track ad click
    _analytics.logAdClick(adUnit: 'banner_home');
  }

  void _onAdError(String error) {
    // ✅ Track ad errors
    _errorTracking.recordError(
      exception: Exception('Ad Error: $error'),
      stack: StackTrace.current,
      context: 'Ad Loading',
      customData: {
        'ad_unit': 'banner_home',
        'error': error,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BannerAdWidget(
      onAdLoaded: _onAdLoaded,
      onAdClicked: _onAdClicked,
      onAdError: _onAdError,
    );
  }
}
```

---

## Testing the Integration

### Test Script

```dart
// Add to main.dart for testing (remove in production)
void _testAnalyticsAndCrashlytics() async {
  final analytics = AnalyticsService();
  final errorTracking = ErrorTrackingService();

  // Test Analytics
  await analytics.setUserId('test-user-123');
  await analytics.logCustomEvent(
    eventName: 'test_event',
    parameters: {'test': 'value'},
  );

  // Test Error Tracking
  await errorTracking.setUserId('test-user-123');
  await errorTracking.logUserAction(
    action: 'test_action',
    details: 'Testing error tracking',
  );

  debugPrint('✅ Analytics and Error Tracking Test Complete');
}
```

---

## Summary

The integration provides:
- ✅ Automatic crash detection and reporting
- ✅ User behavior tracking
- ✅ Feature usage analytics
- ✅ Error context and debugging info
- ✅ User session tracking
- ✅ Custom event logging

All with minimal code modifications to existing services!

---

**Next Steps:**
1. Copy these examples into your actual services
2. Update your Firebase project configuration
3. Test in release build
4. Monitor Firebase Console for data
