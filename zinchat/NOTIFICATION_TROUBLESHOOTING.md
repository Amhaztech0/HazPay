# Push Notifications Not Working - Troubleshooting Guide

## Quick Diagnosis

### Step 1: Run the Debug Screen
1. Open the app
2. Go to **Settings** → **Notification Debug**
3. Check the status and logs
4. Copy your FCM token for testing

### Step 2: Verify Database Setup

**CRITICAL**: Run this SQL in Supabase SQL Editor:

```sql
-- Check if user_tokens table exists
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_name = 'user_tokens'
);
```

If it returns `false`, **you MUST run the migration**:

1. Open Supabase Dashboard → SQL Editor
2. Paste content from `db/CREATE_USER_TOKENS_TABLE.sql`
3. Click **RUN**
4. Verify: `SELECT * FROM user_tokens;`

### Step 3: Check FCM Token Storage

Run this in Supabase SQL Editor:

```sql
-- Check if your token is saved
SELECT * FROM user_tokens 
WHERE user_id = (SELECT auth.uid());
```

**Expected Result**: Should show your FCM token

**If empty**: 
- App failed to save token
- Check RLS policies
- Check user is authenticated
- Re-run app and check debug logs

## Common Issues & Solutions

### Issue 1: "Table user_tokens doesn't exist"

**Cause**: Database migration not executed

**Solution**:
```bash
# In Supabase SQL Editor, run:
db/CREATE_USER_TOKENS_TABLE.sql
```

---

### Issue 2: "FCM Token is null"

**Causes**:
- Firebase not initialized
- google-services.json missing
- Permission denied

**Solutions**:

1. **Check google-services.json**:
   ```bash
   # Verify file exists:
   ls android/app/google-services.json
   ```
   
2. **Check Firebase initialization**:
   - Open app
   - Check Android Studio Logcat for: `Firebase initialized successfully`
   - If not, check `google-services.json` placement

3. **Rebuild app**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

---

### Issue 3: "Token saved but notifications not received"

**Cause**: No backend service sending notifications

**YOU NEED**: A Supabase Edge Function or backend service to send FCM messages

**Create Supabase Edge Function**:

1. Create `supabase/functions/send-notification/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const FIREBASE_SERVER_KEY = Deno.env.get('FIREBASE_SERVER_KEY')!

serve(async (req) => {
  try {
    const { fcmToken, title, body, data } = await req.json()

    const response = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${FIREBASE_SERVER_KEY}`
      },
      body: JSON.stringify({
        to: fcmToken,
        priority: 'high',
        notification: {
          title,
          body,
          sound: 'default',
          android_channel_id: 'zinchat_messages'
        },
        data
      })
    })

    const result = await response.json()
    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json' }
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
```

2. Deploy function:
```bash
supabase functions deploy send-notification --no-verify-jwt
```

3. Set Firebase Server Key secret:
   - Get from Firebase Console → Project Settings → Cloud Messaging → Server Key
   ```bash
   supabase secrets set FIREBASE_SERVER_KEY=your_server_key_here
   ```

4. **Create Database Trigger** to auto-send notifications:

```sql
-- Function to send notification when message is inserted
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS $$
DECLARE
  recipient_tokens RECORD;
  sender_name TEXT;
BEGIN
  -- Get sender name
  SELECT full_name INTO sender_name
  FROM profiles
  WHERE id = NEW.sender_id;

  -- Get recipient FCM tokens
  FOR recipient_tokens IN
    SELECT fcm_token
    FROM user_tokens
    WHERE user_id = NEW.receiver_id
  LOOP
    -- Call Edge Function to send notification
    PERFORM
      net.http_post(
        url := 'https://your-project.supabase.co/functions/v1/send-notification',
        headers := '{"Content-Type": "application/json"}'::jsonb,
        body := json_build_object(
          'fcmToken', recipient_tokens.fcm_token,
          'title', sender_name,
          'body', NEW.content,
          'data', json_build_object(
            'type', 'direct_message',
            'chat_id', NEW.chat_id,
            'sender_id', NEW.sender_id,
            'sender_name', sender_name
          )
        )::jsonb
      );
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on messages table
DROP TRIGGER IF EXISTS on_message_insert ON messages;
CREATE TRIGGER on_message_insert
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_message();
```

---

### Issue 4: "Notification permission denied"

**Solution**:
1. Go to Android Settings → Apps → Zinchat → Notifications
2. Enable "All Zinchat notifications"
3. Restart app

---

### Issue 5: "Works in foreground but not background"

**Cause**: Background handler not configured

**Check**:
1. Verify `_firebaseMessagingBackgroundHandler` in `main.dart`
2. Verify `@pragma('vm:entry-point')` annotation
3. Rebuild app completely:
   ```bash
   flutter clean
   flutter run --release
   ```

---

## Testing Notifications

### Method 1: Using FCM Test Console

1. Get FCM token from debug screen
2. Go to Firebase Console → Cloud Messaging
3. Click "Send test message"
4. Paste FCM token
5. Send

### Method 2: Using Postman/cURL

```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Content-Type: application/json" \
  -H "Authorization: key=YOUR_FIREBASE_SERVER_KEY" \
  -d '{
    "to": "YOUR_FCM_TOKEN",
    "priority": "high",
    "notification": {
      "title": "Test",
      "body": "This is a test notification",
      "sound": "default",
      "android_channel_id": "zinchat_messages"
    },
    "data": {
      "type": "direct_message",
      "sender_name": "Test User",
      "content": "Test message"
    }
  }'
```

### Method 3: From Supabase

```sql
-- Test notification send (requires Edge Function setup)
SELECT
  net.http_post(
    url := 'https://your-project.supabase.co/functions/v1/send-notification',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := json_build_object(
      'fcmToken', 'YOUR_FCM_TOKEN_HERE',
      'title', 'Test',
      'body', 'Test notification from Supabase',
      'data', json_build_object('type', 'test')
    )::jsonb
  ) as request_id;
```

---

## Complete Setup Checklist

### Android Configuration ✅
- [ ] `google-services.json` in `android/app/`
- [ ] `build.gradle.kts` has Google Services plugin
- [ ] `app/build.gradle.kts` has Firebase dependency
- [ ] `AndroidManifest.xml` has `POST_NOTIFICATIONS` permission
- [ ] `AndroidManifest.xml` has FCM service metadata
- [ ] `MainActivity.kt` creates notification channel
- [ ] Notification sound file: `android/app/src/main/res/raw/notification_sound.mp3`

### Flutter Code ✅
- [ ] Firebase initialized in `main.dart`
- [ ] NotificationService initialized
- [ ] Background handler registered
- [ ] Chat screens call `setActiveChatId()`
- [ ] Server chat screens call `setActiveServerChatId()`

### Database ✅
- [ ] `user_tokens` table created
- [ ] RLS policies set up
- [ ] FCM token saved for current user
- [ ] Edge Function deployed (optional but recommended)
- [ ] Database trigger created (optional but recommended)

### Testing ✅
- [ ] Test on **real Android device** (not emulator)
- [ ] Notification permission granted
- [ ] FCM token visible in debug screen
- [ ] Token saved in `user_tokens` table
- [ ] Send test notification from Firebase Console
- [ ] App receives notification in background
- [ ] App receives notification in foreground
- [ ] Tapping notification opens correct chat

---

## Still Not Working?

### Check Android Logcat

```bash
# Filter for notification logs
adb logcat | grep -i "notification\|fcm\|firebase"
```

Look for:
- `Firebase initialized successfully` ✅
- `FCM Token: xyz...` ✅
- `FCM token saved to Supabase` ✅
- Error messages ❌

### Check Flutter Logs

```bash
flutter run -v
```

Look for:
- `✅ Notification permission: authorized`
- `📱 FCM Token: xyz...`
- `✅ FCM token saved to Supabase`
- `📬 Foreground message received`

### Common Log Errors

**"Table user_tokens doesn't exist"**
→ Run database migration

**"Permission denied for table user_tokens"**
→ Check RLS policies in Supabase

**"Firebase not configured"**
→ Check `google-services.json` placement

**"Failed to get FCM token"**
→ Rebuild app after adding `google-services.json`

---

## Get Firebase Server Key

Required for sending notifications from backend:

1. Go to Firebase Console
2. Project Settings (gear icon)
3. Cloud Messaging tab
4. Copy **Server key** (legacy)
5. Store in Supabase secrets or environment

---

## Next Steps After Setup

1. **Test end-to-end flow**:
   - User A sends message to User B
   - User B receives notification
   - User B taps notification
   - App opens to correct chat

2. **Monitor delivery**:
   - Check Firebase Console → Cloud Messaging → Reports
   - Check delivery success rate
   - Debug failed deliveries

3. **Optimize**:
   - Add notification batching for multiple messages
   - Add notification categories (messages, servers, mentions)
   - Add notification actions (reply, mark read)

---

## Need Help?

1. Run debug screen and copy logs
2. Check `user_tokens` table in Supabase
3. Test with Firebase Console first
4. Check Android Logcat for errors
5. Verify all files are in correct locations
