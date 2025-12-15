# ⚠️ IMPORTANT: Complete These Steps Now

## 🔴 Step 1: Run Database Migration (CRITICAL)

**You MUST do this or notifications will NOT work!**

1. Go to **Supabase Dashboard** → **SQL Editor**
2. Click **New Query**
3. Copy and paste this entire SQL script:

```sql
-- Create user_tokens table to store FCM tokens
CREATE TABLE IF NOT EXISTS user_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL, -- 'android' or 'ios'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Ensure one token per device
  UNIQUE(user_id, fcm_token)
);

-- Create index for faster token lookups
CREATE INDEX IF NOT EXISTS idx_user_tokens_user_id ON user_tokens(user_id);

-- Enable RLS
ALTER TABLE user_tokens ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only see their own tokens
CREATE POLICY "Users can view their own tokens" ON user_tokens
  FOR SELECT USING (auth.uid() = user_id);

-- RLS Policy: Users can insert their own tokens
CREATE POLICY "Users can insert their own tokens" ON user_tokens
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can update their own tokens
CREATE POLICY "Users can update their own tokens" ON user_tokens
  FOR UPDATE USING (auth.uid() = user_id);

-- RLS Policy: Users can delete their own tokens
CREATE POLICY "Users can delete their own tokens" ON user_tokens
  FOR DELETE USING (auth.uid() = user_id);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON user_tokens TO authenticated;

-- Add notification_sent column to messages (optional, for tracking)
ALTER TABLE server_messages ADD COLUMN IF NOT EXISTS notification_sent BOOLEAN DEFAULT FALSE;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS notification_sent BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_server_messages_notification_sent ON server_messages(notification_sent);
CREATE INDEX IF NOT EXISTS idx_messages_notification_sent ON messages(notification_sent);
```

4. Click **RUN** (or press F5)
5. Verify success: Run this query to check:
   ```sql
   SELECT * FROM user_tokens LIMIT 1;
   ```
   (It should return empty result, not an error)

---

## 🟡 Step 2: Test the App

1. **Rebuild the app**:
   ```bash
   cd C:\Users\Amhaz\Desktop\zinchat\zinchat
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Check notification setup**:
   - Open the app
   - Go to **Settings** → **Notification Debug**
   - Check the status (should show ✅ All setup complete)
   - Copy your FCM token

3. **Verify token is saved**:
   - Go to Supabase → SQL Editor
   - Run: `SELECT * FROM user_tokens;`
   - You should see your FCM token

---

## 🟢 Step 3: Send Test Notification

### Option A: Firebase Console (Easiest)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **zinchat-f8d78**
3. Go to **Cloud Messaging** (left sidebar)
4. Click **Send your first message** or **New campaign**
5. Message title: "Test"
6. Message text: "This is a test notification"
7. Click **Send test message**
8. Paste your FCM token (from debug screen)
9. Click **Test**

### Option B: Using cURL

```bash
# Replace YOUR_FCM_TOKEN with your actual token
# Replace YOUR_SERVER_KEY with Firebase Server Key (get from Firebase Console → Project Settings → Cloud Messaging)

curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Content-Type: application/json" \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -d '{
    "to": "YOUR_FCM_TOKEN",
    "priority": "high",
    "notification": {
      "title": "Test Notification",
      "body": "If you see this, notifications are working!",
      "sound": "default",
      "android_channel_id": "zinchat_messages"
    }
  }'
```

---

## ⚡ Why Notifications Might Not Work

### Common Issue: No Backend Service

**Important**: The app is configured to receive notifications, but you need a **backend service** to actually SEND them when messages arrive.

You have 3 options:

### Option 1: Supabase Edge Function (Recommended)

Create `supabase/functions/send-notification/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const FIREBASE_SERVER_KEY = Deno.env.get('FIREBASE_SERVER_KEY')!

serve(async (req) => {
  const { recipientId, title, body, data } = await req.json()

  // Get recipient FCM tokens
  const { data: tokens } = await supabase
    .from('user_tokens')
    .select('fcm_token')
    .eq('user_id', recipientId)

  for (const token of tokens || []) {
    await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${FIREBASE_SERVER_KEY}`
      },
      body: JSON.stringify({
        to: token.fcm_token,
        priority: 'high',
        notification: { title, body, sound: 'default', android_channel_id: 'zinchat_messages' },
        data
      })
    })
  }

  return new Response('OK')
})
```

Deploy:
```bash
supabase functions deploy send-notification
```

### Option 2: Database Trigger (Automatic)

Add this trigger in Supabase SQL Editor:

```sql
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS $$
DECLARE
  recipient_tokens RECORD;
  sender_name TEXT;
BEGIN
  -- Get sender name
  SELECT full_name INTO sender_name FROM profiles WHERE id = NEW.sender_id;

  -- Get recipient FCM tokens and send notification
  FOR recipient_tokens IN
    SELECT fcm_token FROM user_tokens WHERE user_id = NEW.receiver_id
  LOOP
    PERFORM net.http_post(
      url := 'https://YOUR_PROJECT.supabase.co/functions/v1/send-notification',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := json_build_object(
        'recipientId', NEW.receiver_id,
        'title', sender_name,
        'body', NEW.content,
        'data', json_build_object('type', 'direct_message', 'chat_id', NEW.chat_id)
      )::jsonb
    );
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_message_insert
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_message();
```

### Option 3: Manual Testing Only

For now, just test manually using Firebase Console or cURL as shown in Step 3.

---

## ✅ Quick Checklist

**Before testing, verify**:
- [ ] Database migration executed (user_tokens table exists)
- [ ] App rebuilt (`flutter clean && flutter pub get && flutter run`)
- [ ] Logged in to the app
- [ ] FCM token visible in debug screen
- [ ] Token saved in Supabase user_tokens table
- [ ] Test on **real Android device** (not emulator)

**If notifications still don't work**:
1. Check debug screen logs
2. Read `NOTIFICATION_TROUBLESHOOTING.md`
3. Check Android Logcat: `adb logcat | grep -i "fcm\|firebase"`
4. Verify Firebase Console shows your app

---

## 🎯 Expected Behavior

Once everything is set up:

1. **In foreground** (app open):
   - If chat is open → In-app banner (no system notification)
   - If chat is closed → System notification

2. **In background** (app minimized):
   - Always shows system notification
   - High priority (pops on screen)
   - Plays sound
   - Shows in notification tray

3. **Tap notification**:
   - Opens app to correct chat
   - Marks message as read

---

## Need Help?

1. Run the **Notification Debug** screen in Settings
2. Copy the logs
3. Check if FCM token is saved in Supabase
4. Send test notification from Firebase Console
5. Check `NOTIFICATION_TROUBLESHOOTING.md` for detailed solutions
