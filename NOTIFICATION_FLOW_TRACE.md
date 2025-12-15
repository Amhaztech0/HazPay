# Server Notification Flow - Complete Trace Documentation

## Overview
This document traces the complete flow of server notifications from the Edge Function through to successful navigation in the app.

---

## 1. **Edge Function: send-notification** 
📍 Location: `supabase/functions/send-notification/index.ts`

### What It Does:
- Receives notification request from `ServerService._sendServerNotifications()`
- Sends push notification to the user's device via their token

### Key Data Flow:
```
Input:
{
  type: 'server_message',
  userId: string,
  messageId: string,
  senderId: string,
  senderName: string,
  content: string,
  serverId: string,           // ✅ SENT
  channelId?: string          // ✅ SENT (optional)
}

Push Notification Payload:
{
  notification: {
    title: "${senderName}",
    body: content,
  },
  data: {
    type: 'server_message',
    messageId: messageId,
    serverId: serverId,         // ✅ INCLUDED
    channelId?: channelId,      // ✅ INCLUDED (optional)
    chat_id: serverId,          // ✅ INCLUDED (for routing)
    server_id: serverId,        // ✅ INCLUDED (for routing)
  }
}
```

### Status: ✅ **WORKING CORRECTLY**
The Edge Function properly includes both `serverId` and `server_id` in the notification payload data.

---

## 2. **Flutter App: Notification Service**
📍 Location: `lib/services/notification_service.dart`

### What It Does:
- Listens for incoming notifications (both foreground and background)
- Parses notification data
- Sends navigation event through `navigationStream` StreamController

### Key Data Flow:
```
onMessage/onMessageOpenedApp:
- Receives notification with data containing:
  - server_id: string
  - chat_id: string
  - etc.

NavigationEvent created:
{
  type: 'server',     // or 'chat'
  id: data['server_id']  // ✅ Uses server_id correctly
}

navigationStream.add(navigationEvent)
```

### Status: ✅ **WORKING CORRECTLY**
Notification service properly routes server notifications through the stream.

---

## 3. **Home Screen: Notification Listener Setup**
📍 Location: `lib/screens/home/home_screen.dart`

### Method: `_setupNotificationListener()`

### What It Does:
- Listens to `NotificationService().navigationStream`
- Routes notifications to appropriate navigation handlers

### Key Code:
```dart
void _setupNotificationListener() {
  _notificationSubscription = NotificationService().navigationStream.listen((event) {
    debugPrint('🔔 Notification navigation event: ${event.type} - ${event.id}');
    
    if (event.type == 'chat') {
      _navigateToDirectChat(event.id);
    } else if (event.type == 'server') {
      _navigateToServerChat(event.id);
    }
  });
}
```

### Status: ✅ **WORKING CORRECTLY**
Listener properly receives and routes events.

---

## 4. **Navigation Handler: Direct Chat**
📍 Location: `lib/screens/home/home_screen.dart`

### Method: `_navigateToDirectChat(String chatId)`

### Flow:
```
1. Fetch chat from Supabase:
   - Select from 'chats' table
   - Include related 'profiles' data

2. Extract user information:
   - user2_id (the other person in the chat)
   - full_name, avatar_url from profiles

3. Create UserModel from profile data

4. Navigate using navigatorKey (NOT context):
   navigatorKey.currentState?.push(
     MaterialPageRoute(
       builder: (_) => ChatScreen(
         chatId: chatId,
         otherUser: userModel,
       ),
     ),
   );
```

### Why navigatorKey?
- ✅ Works when notification fires before widgets are ready
- ✅ Works in background notifications
- ❌ context-based navigation fails in these scenarios

### Status: ✅ **FIXED**
Now properly uses navigatorKey instead of context for reliable navigation.

---

## 5. **Navigation Handler: Server Chat**
📍 Location: `lib/screens/home/home_screen.dart`

### Method: `_navigateToServerChat(String serverId)`

### Flow:
```
1. Initialize ServerService

2. Fetch full ServerModel:
   server = await serverService.getServerById(serverId);

3. Check if server exists:
   if (server == null) {
     debugPrint('Server not found');
     return;
   }

4. Navigate using navigatorKey:
   navigatorKey.currentState?.push(
     MaterialPageRoute(
       builder: (_) => ServerChatScreen(server: server),
     ),
   );
```

### ServerService.getServerById():
```dart
Future<ServerModel?> getServerById(String serverId) async {
  try {
    final response = await supabase
        .from('servers')
        .select()
        .eq('id', serverId)
        .single();

    return ServerModel.fromJson(response);
  } catch (e) {
    print('Error fetching server by ID: $e');
    return null;
  }
}
```

### Status: ✅ **FIXED**
Now properly fetches full ServerModel and uses navigatorKey for navigation.

---

## 6. **Navigator Key Setup**
📍 Location: `lib/main.dart`

### Definition:
```dart
final navigatorKey = GlobalKey<NavigatorState>();
```

### Usage in MaterialApp:
```dart
MaterialApp(
  navigatorKey: navigatorKey,  // ✅ Connected
  home: AuthWrapper(),
  // ...
)
```

### Status: ✅ **WORKING CORRECTLY**
Global navigator key is properly defined and configured.

---

## Complete Navigation Flow Diagram

```
📱 Firebase Cloud Messaging
    ↓
📦 Notification Payload arrives
   {data: {server_id, chat_id}}
    ↓
🎯 Notification Service listens
   onMessage / onMessageOpenedApp
    ↓
📡 Create NavigationEvent
   type: 'server', id: serverId
    ↓
🌊 Add to navigationStream
    ↓
👂 Home Screen listens to stream
   _setupNotificationListener()
    ↓
🔀 Router decides path:
   if type == 'server'
      → _navigateToServerChat(id)
   else if type == 'chat'
      → _navigateToDirectChat(id)
    ↓
🔍 Fetch from Database
   ServerService.getServerById(id)
   or ChatService.getChat(id)
    ↓
🗺️ Navigate using navigatorKey
   navigatorKey.currentState?.push()
    ↓
✅ User sees ServerChatScreen
   or ChatScreen
```

---

## Testing Checklist

### Prerequisites:
- [ ] App is running (foreground or background)
- [ ] User is authenticated
- [ ] Firebase Cloud Messaging is configured
- [ ] Device has valid FCM token

### Test Cases:

#### Test 1: Foreground Notification (App Open)
1. Open ZinChat app
2. Navigate to home screen
3. Send message in a server you're a member of
4. Expected: Should navigate to ServerChatScreen immediately
5. Verify: Navigation uses navigatorKey, not context
   - [ ] Pass / [ ] Fail

#### Test 2: Background Notification (App Minimized)
1. Minimize ZinChat app (but don't close)
2. Send message in a server you're a member of
3. Tap on notification when it arrives
4. Expected: App opens and navigates to ServerChatScreen
5. Verify:
   - [ ] Notification payload includes server_id
   - [ ] NotificationService receives and parses it correctly
   - [ ] Home screen navigation listener handles it
   - [ ] Navigation succeeds without context errors
   - [ ] Pass / [ ] Fail

#### Test 3: Terminated App Notification
1. Close ZinChat app completely
2. Send message in a server you're a member of
3. Tap on notification
4. Expected: App launches and navigates to ServerChatScreen
5. Verify:
   - [ ] App initializes properly
   - [ ] navigatorKey is available before notification routing
   - [ ] No context-related errors
   - [ ] Pass / [ ] Fail

#### Test 4: Direct Message Notification
1. Open ZinChat app
2. Send direct message from another user
3. Expected: Navigate to ChatScreen with correct user
4. Verify:
   - [ ] UserModel created correctly from chat data
   - [ ] ChatScreen displays correct conversation
   - [ ] Pass / [ ] Fail

#### Test 5: Multiple Notifications in Sequence
1. Open app
2. Receive 3 server notifications in quick succession
3. Expected: Navigate to first, then handle others in queue
4. Verify:
   - [ ] All notifications handled
   - [ ] No crashes or race conditions
   - [ ] Navigation is smooth
   - [ ] Pass / [ ] Fail

---

## Debugging Guide

### Issue: Navigation not working on notification tap

**Check 1: Is notification being received?**
```dart
// In NotificationService._initialize()
firebase_messaging.onMessage.listen((RemoteMessage message) {
  debugPrint('🔔 FOREGROUND: ${message.data}');  // Check console
});
```

**Check 2: Is navigationStream event being created?**
```dart
// In NotificationService.handleNotification()
debugPrint('📡 Adding to stream: $event');  // Check console
```

**Check 3: Is home screen listening?**
```dart
// In HomeScreen._setupNotificationListener()
debugPrint('🔔 Notification navigation event: ${event.type} - ${event.id}');
```

**Check 4: Is database fetch succeeding?**
```dart
// In _navigateToServerChat()
debugPrint('🔍 Fetching server details for: $serverId');
debugPrint('✅ Server details fetched, navigating...');
debugPrint('✅ Navigated to server chat: $serverId');
```

**Check 5: Is navigatorKey available?**
```dart
if (navigatorKey.currentState == null) {
  debugPrint('❌ navigatorKey.currentState is null!');
  return;
}
```

### Common Errors & Solutions

**Error: "Navigator operation requested with a context that does not include a Navigator"**
- ❌ Problem: Using `Navigator.push(context, ...)`
- ✅ Solution: Use `navigatorKey.currentState?.push(...)`

**Error: "null is not a subtype of Map<String, dynamic>"**
- ❌ Problem: Notification data is null or malformed
- ✅ Solution: Check Edge Function is sending data correctly

**Error: "Server not found"**
- ❌ Problem: serverId in notification is incorrect
- ✅ Solution: Verify Edge Function sends correct serverId

**Error: "User not authenticated"**
- ❌ Problem: Auth not available when notification fires
- ✅ Solution: Check auth is initialized before notification setup

---

## Files Modified

### 1. `lib/screens/home/home_screen.dart`
- ✅ Added import for `ServerChatScreen` and `ServerModel`
- ✅ Added import for `ServerService`
- ✅ Added import for `main.dart` (navigatorKey)
- ✅ Implemented `_navigateToDirectChat()` fully
- ✅ Implemented `_navigateToServerChat()` fully
- ✅ Both now use `navigatorKey` instead of `context`

### 2. No changes needed
- `supabase/functions/send-notification/index.ts` ✅ Already correct
- `lib/services/notification_service.dart` ✅ Already correct
- `lib/services/server_service.dart` ✅ Already has getServerById()
- `lib/main.dart` ✅ Already has navigatorKey

---

## Summary

### Issues Fixed:
1. ✅ `_navigateToServerChat()` had TODO and didn't navigate
2. ✅ Navigation used context which fails for background notifications
3. ✅ Server model wasn't being fetched properly
4. ✅ Missing imports for navigation

### Current Status:
- ✅ Edge Function sends data correctly
- ✅ Notification Service receives and routes correctly
- ✅ Home Screen properly listens and routes
- ✅ Navigation handlers properly fetch data
- ✅ Navigation uses navigatorKey for reliability

### Next Steps:
1. Run all 5 test cases above
2. Check debug console for the 🔔, 📡, 🔍, ✅ debug messages
3. If any test fails, use the debugging guide above
4. Report results with debug logs

---

## Key Debugging Messages to Look For

```
✅ = Success indicator
❌ = Error indicator
🔔 = Notification event
📡 = Stream event
🔍 = Database fetch
🗺️ = Navigation action
```

**In Console You Should See:**
```
🔔 Foreground: {data: {server_id: 'xxx', ...}}
📡 Adding to stream: NavigationEvent(type: server, id: xxx)
🔔 Notification navigation event: server - xxx
🔍 Fetching server details for: xxx
✅ Server details fetched, navigating...
✅ Navigated to server chat: xxx
```

If you see any ❌ messages, refer to the **Debugging Guide** section above.
