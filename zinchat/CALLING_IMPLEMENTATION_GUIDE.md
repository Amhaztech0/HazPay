# 🚀 Voice & Video Calling Implementation Guide

Complete implementation of 1-on-1 WebRTC calls and server group calls using 100ms.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Quick Setup](#quick-setup)
3. [Database Setup](#database-setup)
4. [100ms Setup](#100ms-setup)
5. [TURN Server Setup](#turn-server-setup)
6. [Flutter Integration](#flutter-integration)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

### Architecture

**1-on-1 Calls:**
- ✅ flutter_webrtc for peer-to-peer connections
- ✅ Supabase Realtime for signaling
- ✅ Free TURN servers (Metered.ca)
- ✅ Direct database signaling (no external services)

**Server Group Calls:**
- ✅ 100ms SDK for group video/audio
- ✅ 10,000 minutes/month free tier
- ✅ Automatic scalability
- ✅ Built-in recording support

---

## ⚡ Quick Setup

### Step 1: Install Dependencies

```bash
cd zinchat
flutter pub get
```

Dependencies added:
- `flutter_webrtc: ^0.11.7` - WebRTC for 1-on-1 calls
- `sdp_transform: ^0.3.2` - SDP parsing
- `hmssdk_flutter: ^1.10.4` - 100ms SDK for group calls
- `uuid: ^4.5.1` - UUID generation

### Step 2: Setup Database

Run the SQL schema in Supabase SQL Editor:

```bash
# Open Supabase Dashboard > SQL Editor
# Copy and run: CALL_DATABASE_SCHEMA.sql
```

This creates:
- `calls` table - All call records
- `call_participants` table - Group call participants
- `webrtc_signals` table - WebRTC signaling
- `call_settings` table - User preferences
- RLS policies, triggers, and helper functions

### Step 3: Android Permissions

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
    <!-- Add inside <manifest> tag -->
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <application>
        <!-- ... existing code ... -->
    </application>
</manifest>
```

### Step 4: iOS Permissions

Add to `ios/Runner/Info.plist`:

```xml
<dict>
    <!-- Add these keys -->
    <key>NSCameraUsageDescription</key>
    <string>We need camera access for video calls</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>We need microphone access for voice and video calls</string>
</dict>
```

---

## 💾 Database Setup

### Run Database Schema

1. Open Supabase Dashboard
2. Go to SQL Editor
3. Copy entire content from `CALL_DATABASE_SCHEMA.sql`
4. Execute the SQL

### Verify Tables Created

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('calls', 'call_participants', 'webrtc_signals', 'call_settings');
```

You should see all 4 tables.

---

## 🎥 100ms Setup

### 1. Create 100ms Account

1. Go to https://dashboard.100ms.live/
2. Sign up for free account (10,000 minutes/month)
3. Create a new project

### 2. Create Templates

Create two templates:

**Video Call Template:**
- Template name: `zinchat-video`
- Enable: Video, Audio, Screen share
- Roles: `host`, `guest`

**Audio Call Template:**
- Template name: `zinchat-audio`
- Enable: Audio only
- Roles: `host`, `guest`

### 3. Get Credentials

From 100ms Dashboard:
- App Access Key
- App Secret
- Template IDs

### 4. Configure in App

Update `lib/services/hms_call_service.dart`:

```dart
// Replace with your endpoint
static const String _hmsEndpoint = 'YOUR_HMS_ENDPOINT';
```

### 5. Deploy Edge Function

```bash
# Set secrets
supabase secrets set HMS_APP_ACCESS_KEY=your_access_key
supabase secrets set HMS_APP_SECRET=your_secret
supabase secrets set HMS_TEMPLATE_ID=your_template_id

# Deploy function
supabase functions deploy generate-hms-token
```

---

## 🔄 TURN Server Setup

### Option 1: Metered.ca (Recommended - Free)

Already configured in `webrtc_service.dart`:

```dart
'turn:openrelay.metered.ca:80'
'turn:openrelay.metered.ca:443'
```

**Free tier:** 50GB/month

For higher limits, sign up at https://www.metered.ca/

### Option 2: Twilio TURN (Free Tier)

1. Sign up at https://www.twilio.com/
2. Get credentials from Twilio Console
3. Update `webrtc_service.dart`:

```dart
{
  'urls': 'turn:global.turn.twilio.com:3478?transport=tcp',
  'username': 'YOUR_TWILIO_USERNAME',
  'credential': 'YOUR_TWILIO_CREDENTIAL',
}
```

### Option 3: Self-hosted (coturn)

```bash
# Install coturn
sudo apt-get install coturn

# Configure /etc/turnserver.conf
listening-port=3478
fingerprint
lt-cred-mech
user=username:password
realm=yourdomain.com
```

---

## 📱 Flutter Integration

### Initialize CallManager

In your `main.dart`:

```dart
import 'package:zinchat/services/call_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          // Initialize call manager after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            CallManager().initialize(context);
          });
          return HomeScreen();
        },
      ),
    );
  }
}
```

### Start a 1-on-1 Call

```dart
import 'package:zinchat/services/call_manager.dart';

// Audio call
CallManager().startDirectCall(
  context: context,
  receiverId: 'user-uuid',
  receiverName: 'John Doe',
  isVideo: false,
);

// Video call
CallManager().startDirectCall(
  context: context,
  receiverId: 'user-uuid',
  receiverName: 'John Doe',
  isVideo: true,
);
```

### Start a Server Group Call

```dart
import 'package:zinchat/services/call_manager.dart';

CallManager().startServerCall(
  context: context,
  serverId: 'server-uuid',
  serverName: 'My Server',
  channelId: 'channel-uuid',
  channelName: 'voice-chat',
  userName: 'Your Name',
  isVideo: true,
);
```

### Add Call Buttons to Chat

```dart
// In your chat screen
Row(
  children: [
    IconButton(
      icon: Icon(Icons.call),
      onPressed: () {
        CallManager().startDirectCall(
          context: context,
          receiverId: otherUserId,
          receiverName: otherUserName,
          isVideo: false,
        );
      },
    ),
    IconButton(
      icon: Icon(Icons.videocam),
      onPressed: () {
        CallManager().startDirectCall(
          context: context,
          receiverId: otherUserId,
          receiverName: otherUserName,
          isVideo: true,
        );
      },
    ),
  ],
)
```

---

## 🧪 Testing

### Test 1-on-1 Calls

1. **Run on two devices/emulators:**
   ```bash
   flutter run -d device1
   flutter run -d device2
   ```

2. **Sign in as different users** on each device

3. **Start a call** from one device

4. **Accept on the other device**

5. **Test features:**
   - ✅ Audio/video streaming
   - ✅ Mute/unmute
   - ✅ Video on/off
   - ✅ Camera switch
   - ✅ End call

### Test Server Calls

1. **Join same server** on multiple devices

2. **Start voice/video call** in a channel

3. **Join from other devices**

4. **Test features:**
   - ✅ Multiple participants
   - ✅ Grid layout
   - ✅ Mute/unmute
   - ✅ Video toggle
   - ✅ Participant list
   - ✅ Leave call

### Debug WebRTC Issues

Enable logging:

```dart
// In webrtc_service.dart
_peerConnection?.onIceConnectionState = (state) {
  print('ICE Connection State: $state');
};

_peerConnection?.onSignalingState = (state) {
  print('Signaling State: $state');
};
```

---

## 🔧 Troubleshooting

### Issue: Calls not connecting

**Check:**
- ✅ Database tables created
- ✅ RLS policies enabled
- ✅ Supabase Realtime enabled
- ✅ TURN servers accessible
- ✅ Internet connection stable

**Solution:**
```sql
-- Check if realtime is enabled
SELECT * FROM pg_publication;

-- Should see: supabase_realtime

-- Re-enable if needed
ALTER PUBLICATION supabase_realtime ADD TABLE calls;
ALTER PUBLICATION supabase_realtime ADD TABLE webrtc_signals;
```

### Issue: No audio/video

**Check:**
- ✅ Permissions granted (camera/microphone)
- ✅ Permissions added to AndroidManifest.xml / Info.plist
- ✅ Device has camera/microphone
- ✅ Not already in use by another app

**Solution (Android):**
```bash
# Check permissions
adb shell pm list permissions -d -g
```

**Solution (iOS):**
```bash
# Reset permissions
Settings > Privacy > Camera/Microphone > Your App
```

### Issue: 100ms room not joining

**Check:**
- ✅ 100ms credentials correct
- ✅ Edge function deployed
- ✅ Secrets set correctly
- ✅ Room/template exists

**Test edge function:**
```bash
curl -X POST \
  'https://YOUR_PROJECT.supabase.co/functions/v1/generate-hms-token' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"room_id": "test-room", "user_name": "Test User"}'
```

### Issue: Poor call quality

**Solutions:**
1. **Use better TURN servers** (upgrade Metered.ca plan)
2. **Reduce video resolution** in webrtc_service.dart:
   ```dart
   'video': {
     'width': {'ideal': 640},
     'height': {'ideal': 480},
   }
   ```
3. **Enable adaptive bitrate** in 100ms dashboard

### Issue: Notifications not working

**Check:**
- ✅ Firebase setup complete
- ✅ Notification permissions granted
- ✅ CallManager initialized

**Solution:**
```dart
// Request permissions explicitly
await FirebaseMessaging.instance.requestPermission(
  alert: true,
  badge: true,
  sound: true,
);
```

---

## 📊 Cost Analysis

### Free Tier Limits

**WebRTC (1-on-1):**
- ✅ Unlimited calls
- ✅ Metered.ca: 50GB/month free
- ✅ Supabase: Included in free tier

**100ms (Group calls):**
- ✅ 10,000 minutes/month free
- ✅ ~166 hours/month
- ✅ ~5.5 hours/day

**Cost After Free Tier:**

| Service | Free Tier | Paid Pricing |
|---------|-----------|--------------|
| Metered.ca TURN | 50GB | $0.50/GB |
| 100ms | 10K mins | $0.01/min |
| Supabase DB | 500MB | $0.125/GB |

### Scaling Strategy

1. **Start with free tiers** (0-100 users)
2. **Optimize calls** (reduce resolution, audio-only)
3. **Monitor usage** (Supabase dashboard)
4. **Upgrade selectively** (100ms first, then TURN)
5. **Consider self-hosting** (if >$100/month)

---

## 🎉 What's Been Implemented

✅ **Database Schema** - Complete tables with RLS
✅ **WebRTC Service** - 1-on-1 calls with signaling
✅ **100ms Integration** - Group video/audio calls
✅ **Call Screens** - UI for both call types
✅ **Call Manager** - Incoming call handling
✅ **Notifications** - FCM + local notifications
✅ **Edge Function** - 100ms token generation
✅ **Free TURN Servers** - Configured and ready

---

## 🚀 Next Steps

1. **Run Database Schema:**
   ```bash
   # Copy CALL_DATABASE_SCHEMA.sql to Supabase SQL Editor
   ```

2. **Get Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Setup 100ms:**
   - Create account: https://dashboard.100ms.live/
   - Get credentials
   - Deploy edge function

4. **Add Permissions:**
   - Update AndroidManifest.xml
   - Update Info.plist

5. **Test Calls:**
   ```bash
   flutter run
   ```

6. **Monitor & Optimize:**
   - Check Supabase logs
   - Monitor 100ms usage
   - Optimize based on metrics

---

## 📚 Resources

- [flutter_webrtc Documentation](https://pub.dev/packages/flutter_webrtc)
- [100ms Flutter SDK](https://www.100ms.live/docs/flutter/v2/foundation/basics)
- [Metered.ca TURN Servers](https://www.metered.ca/tools/openrelay/)
- [Supabase Realtime](https://supabase.com/docs/guides/realtime)

---

## 💬 Support

Having issues? Check:
1. Database schema is complete
2. Permissions are granted
3. 100ms credentials are correct
4. TURN servers are accessible
5. Supabase Realtime is enabled

---

**Built with ❤️ using Flutter, WebRTC, and 100ms**

*Free tier supports ~100+ users with moderate usage*
