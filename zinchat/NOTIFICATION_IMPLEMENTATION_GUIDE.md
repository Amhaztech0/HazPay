## 🔔 WhatsApp/Telegram-Style Notifications Implementation Guide

### Overview
This guide shows you how to implement instant, high-priority notifications like WhatsApp and Telegram in your Flutter app.

### Key Features Implemented

1. **Smart Notification Routing**
   - If chat is open → show in-app notification (no interruption)
   - If app is in background → show in system tray + sound
   - If app is terminated → queue and show when app opens

2. **High-Priority Display**
   - Android: Importance.max + Priority.max + Vibration + Custom Sound
   - iOS: time-sensitive banner + sound + badge + thread grouping

3. **Message Grouping**
   - Notifications grouped by sender
   - Shows message preview (not generic "New message")
   - Unread count on app badge

4. **Instant Delivery**
   - Sends from Supabase Edge Function
   - Triggered on message insert
   - Retry logic for failed deliveries

---

## 📋 Implementation Checklist

### Step 1: Database Setup ✅
Execute `db/CREATE_USER_TOKENS_TABLE.sql` in Supabase:
```
- Creates user_tokens table for storing FCM tokens
- Adds notification_sent column to messages tables
- Sets up RLS policies
```

**Status**: Ready to execute

---

### Step 2: Enhanced Notification Service ✅
Updated `lib/services/notification_service.dart` with:

**New Features**:
- `setActiveChatId()` - Track when chat screen is open
- `setActiveServerChatId()` - Track when server chat is open
- Smart foreground message handling
- High-priority Android notification with vibration + sound
- iOS time-sensitive notifications
- Message grouping by chat ID
- Notification tap routing

**How to Use**:

In `chat_screen.dart`:
```dart
@override
void initState() {
  super.initState();
  // Tell notification service this chat is open
  NotificationService.setActiveChatId(widget.chatId);
  _markMessagesAsRead();
  _checkBlockStatus();
}

@override
void dispose() {
  // Clear active chat when leaving
  NotificationService.setActiveChatId(null);
  _messageController.dispose();
  _scrollController.dispose();
  super.dispose();
}
```

In `server_chat_screen.dart`:
```dart
@override
void initState() {
  super.initState();
  // Tell notification service this server chat is open
  NotificationService.setActiveServerChatId(widget.server.id);
  _loadMembers();
  _setupMessageStream();
}

@override
void dispose() {
  // Clear active server chat when leaving
  NotificationService.setActiveServerChatId(null);
  _messageController.dispose();
  _scrollController.dispose();
  super.dispose();
}
```

**Status**: Ready to implement in chat screens

---

### Step 3: Firebase Setup (CRITICAL)

#### Android Setup:
1. Go to Firebase Console → Project Settings
2. Download `google-services.json`
3. Place in: `android/app/google-services.json`
4. Update `android/app/build.gradle`:
```gradle
dependencies {
  // ... other dependencies
  implementation 'com.google.firebase:firebase-messaging'
}

apply plugin: 'com.google.gms.google-services'
```

5. Update `android/build.gradle`:
```gradle
buildscript {
  dependencies {
    classpath 'com.google.gms:google-services:4.3.15'
  }
}
```

6. Update `android/app/src/main/AndroidManifest.xml`:
```xml
<!-- Add within <application> tag -->
<service
    android:name=".NotificationService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>

<!-- High-priority notification channel -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="zinchat_messages" />
```

#### iOS Setup:
1. Go to Firebase Console → Project Settings
2. Download `GoogleService-Info.plist`
3. Add to Xcode: Right-click `ios/Runner` → Add Files
4. In Xcode, select Runner target → Capabilities
5. Enable: Push Notifications
6. Enable: Background Modes (Background fetch, Remote notifications)

---

### Step 4: Notification Sounds

#### Android:
1. Create: `android/app/src/main/res/raw/notification_sound.mp3`
2. Use a short notification sound (1-2 seconds)
3. Recommended: Download from freesound.org or use WhatsApp's sound

#### iOS:
1. Create sound file: `notification_sound.aiff` (max 30 seconds, max 5 MB)
2. In Xcode: Drag into Runner → Copy if needed
3. Build Settings → Search "Bluetooth" → set to Yes

---

### Step 5: Call from Chat Screens

Update your chat screens to track active chat:

#### For Direct Messages (`chat_screen.dart`):
```dart
import '../services/notification_service.dart';

class ChatScreen extends StatefulWidget {
  final ContactModel otherUser;
  final String chatId;
  
  const ChatScreen({
    required this.otherUser,
    required this.chatId,
  });
  
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // Notify service this chat is now active
    NotificationService.setActiveChatId(widget.chatId);
  }

  @override
  void dispose() {
    // Notify service chat is closed
    NotificationService.setActiveChatId(null);
    super.dispose();
  }
}
```

#### For Server Messages (`server_chat_screen.dart`):
```dart
import '../services/notification_service.dart';

class ServerChatScreen extends StatefulWidget {
  final ServerModel server;
  
  const ServerChatScreen({required this.server});
  
  @override
  State<ServerChatScreen> createState() => _ServerChatScreenState();
}

class _ServerChatScreenState extends State<ServerChatScreen> {
  @override
  void initState() {
    super.initState();
    // Notify service this server chat is now active
    NotificationService.setActiveServerChatId(widget.server.id);
  }

  @override
  void dispose() {
    // Notify service server chat is closed
    NotificationService.setActiveServerChatId(null);
    super.dispose();
  }
}
```

---

### Step 6: Supabase Edge Function (Optional but Recommended)

For automatic notifications, create a Supabase Edge Function:

1. Create function:
```bash
supabase functions new send-notification
```

2. Copy code from: `supabase/functions/send-notification/index.ts`

3. Set environment variables:
```bash
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY=your-private-key
FIREBASE_CLIENT_EMAIL=your-client-email
```

4. Deploy:
```bash
supabase functions deploy send-notification
```

5. Call from server_service.dart when sending message:
```dart
Future<bool> sendMessageWithNotification({
  required String serverId,
  required String content,
}) async {
  // Send message
  final success = await sendMessage(
    serverId: serverId,
    content: content,
  );

  if (success) {
    // Trigger notification function
    try {
      await supabase.functions.invoke('send-notification', body: {
        'type': 'server_message',
        'serverId': serverId,
        'senderId': supabase.auth.currentUser!.id,
        'content': content,
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  return success;
}
```

---

### Step 7: Test Notifications

#### Test from Firebase Console:
1. Firebase Console → Cloud Messaging
2. Send test message to specific FCM token
3. Watch device for notification

#### Test from your app:
1. Send message in chat
2. Minimize app (see system notification)
3. Close app completely (see notification on lock screen)

---

## 🎯 Expected Behavior

### Scenario 1: Message while chat is open
✅ **Result**: In-app notification banner (no system notification)

### Scenario 2: Message while app in background
✅ **Result**: System notification with sound + vibration

### Scenario 3: Message while app terminated
✅ **Result**: Notification on lock screen, appears when app opens

### Scenario 4: Multiple messages from same sender
✅ **Result**: Grouped notifications, latest message shown

### Scenario 5: Notification tapped
✅ **Result**: App opens and navigates to correct chat

---

## 🔧 Troubleshooting

**Notifications not appearing?**
1. Check FCM token is saved in `user_tokens` table
2. Verify notification permission granted
3. Check notification channel is configured
4. Test with Firebase Console first

**Sound not playing?**
1. Verify sound files exist and correct format
2. Check notification channel volume settings
3. Test on physical device (emulator might not support)

**Notifications delayed?**
1. Check Firebase config is correct
2. Verify Edge Function credentials
3. Increase retry timeout

---

## 📚 Files Modified/Created

✅ **Created**:
- `db/CREATE_USER_TOKENS_TABLE.sql`
- `supabase/functions/send-notification/index.ts`
- `WHATSAPP_NOTIFICATIONS_SETUP.md` (this file)

✅ **Enhanced**:
- `lib/services/notification_service.dart` (WhatsApp-style features)

📝 **To Update**:
- `lib/screens/chat/chat_screen.dart` - Add notification tracking
- `lib/screens/servers/server_chat_screen.dart` - Add notification tracking
- `lib/services/server_service.dart` - Trigger notifications on message send

---

## 🚀 Next Steps

1. Execute `db/CREATE_USER_TOKENS_TABLE.sql` in Supabase
2. Update chat screens with `setActiveChatId()` / `setActiveServerChatId()`
3. Set up Firebase Android/iOS credentials
4. Test notifications
5. Deploy Edge Function (optional but recommended)

---

## 💡 Tips

- Use notification icons that match your app branding
- Test on real device (not emulator)
- Monitor Firebase quota and costs
- Consider notification frequency limits (avoid spam)
- Use message preview instead of generic "New message"

**Questions?** Check Firebase Cloud Messaging documentation or Flutter Local Notifications plugin docs.
