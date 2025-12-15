# 🚀 100ms Edge Function Setup Guide

## Your 100ms Credentials

✅ **App Access Key:** `69171bc9145cb4e8449b1a6e`
✅ **App Secret:** (stored securely)
✅ **Management Token:** (valid until Nov 21, 2025)

## Deploy Edge Function

### Step 1: Set Secrets in Supabase

Go to **Supabase Dashboard > Settings > Edge Functions > Secrets**

Add these secrets:

```
HMS_APP_ACCESS_KEY=69171bc9145cb4e8449b1a6e
HMS_APP_SECRET=ibgzGtbFbko5Fkn8MV0rZ0e3oyU46hvZpG-_PEPH75-f40D2zewJo4foqslX1ILrdRed5mOnricZd7fjKBsenQXxNPBX1Xx2RCJZ8FSNuIRu609wE9bDXW_n2VpqO127HqUT2jF_B848MQNzMzKVHBsrzm0UhYlCla_aw6YOgoU=
```

### Step 2: Create Function Directory

```bash
cd supabase/functions
supabase functions new generate-hms-token
```

### Step 3: Deploy

```bash
supabase functions deploy generate-hms-token
```

### Step 4: Test Function

```bash
curl -X POST \
  'https://YOUR_PROJECT.supabase.co/functions/v1/generate-hms-token' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "room_id": "test-room",
    "user_name": "Test User"
  }'
```

Expected response:
```json
{
  "token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "room_id": "test-room",
  "user_id": "user-uuid"
}
```

## Create 100ms Rooms

### Option 1: Via Dashboard

1. Go to https://dashboard.100ms.live/rooms
2. Create new room
3. Note the `room_id` and `template_id`

### Option 2: Via API

```bash
# Get management token
TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3NjMxMjI3MjksImV4cCI6MTc2MzcyNzUyOSwianRpIjoiNzcyZWNmOTMtNDQ0MC00ODcwLWJkMWQtMzQ0OTQwMTVmMjIzIiwidHlwZSI6Im1hbmFnZW1lbnQiLCJ2ZXJzaW9uIjoyLCJuYmYiOjE3NjMxMjI3MjksImFjY2Vzc19rZXkiOiI2OTE3MWJjOTE0NWNiNGU4NDQ5YjFhNmUifQ.31_aJMKVuF9Haw7UNl0J1dLKcWvbesJNo9Q-yZQcEII"

# Create room
curl -X POST https://api.100ms.live/v2/rooms \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "zinchat-voice-1",
    "template_id": "YOUR_TEMPLATE_ID"
  }'
```

## Integration Steps

### 1. Initialize HMS Service

In your `main.dart`:

```dart
import 'package:zinchat/services/hms_call_service.dart';

void initState() {
  super.initState();
  HMSCallService().initialize();
}
```

### 2. Start Server Call

```dart
import 'package:zinchat/services/call_manager.dart';

CallManager().startServerCall(
  context: context,
  serverId: 'server-id',
  serverName: 'My Server',
  channelId: 'channel-id',
  channelName: 'voice-chat',
  userName: userName,
  isVideo: true,
);
```

### 3. Join Call

User will be prompted to join the room created in 100ms.

## Troubleshooting

### Token Generation Fails

**Check:**
- ✅ HMS_APP_ACCESS_KEY set in Supabase secrets
- ✅ HMS_APP_SECRET set correctly
- ✅ Edge function deployed
- ✅ Supabase project URL and anon key are correct

**Debug:**
```bash
# Check function logs
supabase functions list
supabase functions download generate-hms-token
```

### Can't Join Room

**Check:**
- ✅ Room exists in 100ms dashboard
- ✅ Room is not full
- ✅ User has correct role permissions
- ✅ Token is valid (not expired)

### No Audio/Video

**Check:**
- ✅ Permissions granted (camera/microphone)
- ✅ Network connection stable
- ✅ Device speakers/microphone working

## Notes

- **Management Token expires:** Nov 21, 2025 - Regenerate before expiry
- **Free tier:** 10,000 minutes/month (refresh monthly)
- **Room codes:** Enabled for security
- **SIP Interconnect:** Available (preview)

## Next Steps

1. ✅ Credentials configured
2. ✅ Deploy edge function
3. ✅ Create test rooms
4. ✅ Test with two devices
5. 🚀 Ship to production!

---

**Support:** https://www.100ms.live/docs
