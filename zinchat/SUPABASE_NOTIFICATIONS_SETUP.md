# Supabase Push Notification Setup Guide

## Overview
This guide explains how to configure Supabase to send FCM (Firebase Cloud Messaging) push notifications when new messages are inserted into the database.

## Prerequisites
- Supabase project with PostgreSQL database
- Firebase project with FCM enabled
- FCM Server Key from Firebase Console

## Database Setup

### 1. Create user_tokens Table

```sql
-- Table to store FCM tokens for each user
CREATE TABLE user_tokens (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL, -- 'android' or 'ios'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, fcm_token)
);

-- Enable RLS
ALTER TABLE user_tokens ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only manage their own tokens
CREATE POLICY "Users can manage own tokens"
  ON user_tokens
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Index for faster lookups
CREATE INDEX idx_user_tokens_user_id ON user_tokens(user_id);
```

### 2. Enable HTTP Extension

```sql
-- Required for making HTTP requests to FCM
CREATE EXTENSION IF NOT EXISTS http;
```

### 3. Create FCM Notification Function

```sql
-- Function to send push notification via FCM
CREATE OR REPLACE FUNCTION send_fcm_notification(
  p_user_id UUID,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_fcm_token TEXT;
  v_fcm_server_key TEXT := 'YOUR_FCM_SERVER_KEY_HERE'; -- Replace with actual key
  v_fcm_url TEXT := 'https://fcm.googleapis.com/fcm/send';
  v_payload JSONB;
  v_response http_response;
BEGIN
  -- Get user's FCM token
  SELECT fcm_token INTO v_fcm_token
  FROM user_tokens
  WHERE user_id = p_user_id
  ORDER BY updated_at DESC
  LIMIT 1;

  -- Exit if no token found
  IF v_fcm_token IS NULL THEN
    RAISE NOTICE 'No FCM token found for user %', p_user_id;
    RETURN;
  END IF;

  -- Build FCM payload
  v_payload := jsonb_build_object(
    'to', v_fcm_token,
    'notification', jsonb_build_object(
      'title', p_title,
      'body', p_body,
      'sound', 'default',
      'priority', 'high'
    ),
    'data', p_data,
    'priority', 'high'
  );

  -- Send HTTP POST to FCM
  SELECT * INTO v_response
  FROM http((
    'POST',
    v_fcm_url,
    ARRAY[
      http_header('Authorization', 'key=' || v_fcm_server_key),
      http_header('Content-Type', 'application/json')
    ],
    'application/json',
    v_payload::text
  )::http_request);

  -- Log response
  RAISE NOTICE 'FCM Response Status: %', v_response.status;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error sending FCM notification: %', SQLERRM;
END;
$$;
```

### 4. Create Database Trigger for New Messages

```sql
-- Trigger function to send notification on new message
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_recipient_id UUID;
  v_sender_name TEXT;
  v_chat_id TEXT;
BEGIN
  -- Get chat details
  SELECT 
    CASE 
      WHEN NEW.sender_id = c.user1_id THEN c.user2_id
      ELSE c.user1_id
    END,
    NEW.chat_id
  INTO v_recipient_id, v_chat_id
  FROM chats c
  WHERE c.id = NEW.chat_id;

  -- Get sender's name
  SELECT display_name INTO v_sender_name
  FROM users
  WHERE id = NEW.sender_id;

  -- Don't notify if message is from the user themselves (shouldn't happen, but safety check)
  IF v_recipient_id != NEW.sender_id THEN
    -- Send notification asynchronously
    PERFORM send_fcm_notification(
      v_recipient_id,
      v_sender_name || ' sent you a message',
      CASE 
        WHEN NEW.message_type = 'text' THEN NEW.content
        WHEN NEW.message_type = 'image' THEN '📷 Photo'
        WHEN NEW.message_type = 'video' THEN '🎥 Video'
        WHEN NEW.message_type = 'audio' THEN '🎵 Voice message'
        ELSE '📎 File'
      END,
      jsonb_build_object(
        'chat_id', v_chat_id,
        'message_id', NEW.id,
        'sender_id', NEW.sender_id,
        'type', 'new_message'
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Attach trigger to messages table
DROP TRIGGER IF EXISTS trigger_notify_new_message ON messages;
CREATE TRIGGER trigger_notify_new_message
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_message();
```

## Configuration Steps

### 1. Get FCM Server Key

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Project Settings** (gear icon)
4. Navigate to **Cloud Messaging** tab
5. Copy the **Server key** (under Cloud Messaging API - Legacy)

### 2. Update Supabase Function

Replace `YOUR_FCM_SERVER_KEY_HERE` in the `send_fcm_notification` function with your actual FCM server key:

```sql
-- Update the function with your key
CREATE OR REPLACE FUNCTION send_fcm_notification(...)
...
DECLARE
  v_fcm_server_key TEXT := 'AAAA1234567:AaBbCc...'; -- Your actual key
...
```

### 3. Security Considerations

**⚠️ IMPORTANT**: The FCM server key is sensitive. For production:

1. **Option A - Environment Variables** (Recommended):
   - Store the key in Supabase Vault (when available)
   - Or use environment variables if your Supabase plan supports it

2. **Option B - Secure Database Table**:
   ```sql
   CREATE TABLE app_secrets (
     key TEXT PRIMARY KEY,
     value TEXT NOT NULL
   );
   
   -- Restrict access
   ALTER TABLE app_secrets ENABLE ROW LEVEL SECURITY;
   CREATE POLICY "No public access" ON app_secrets FOR ALL USING (false);
   
   -- Insert key
   INSERT INTO app_secrets (key, value) 
   VALUES ('fcm_server_key', 'YOUR_FCM_KEY_HERE');
   
   -- Update function to read from table
   SELECT value INTO v_fcm_server_key FROM app_secrets WHERE key = 'fcm_server_key';
   ```

3. **Option C - Supabase Edge Function** (Most Secure):
   - Create a Supabase Edge Function that handles FCM calls
   - Store the key as an environment variable in the Edge Function
   - Call the Edge Function from the database trigger

## Testing

### Test FCM Token Storage

```sql
-- Check if tokens are being saved
SELECT * FROM user_tokens;
```

### Test Manual Notification

```sql
-- Send a test notification
SELECT send_fcm_notification(
  'USER_UUID_HERE'::uuid,
  'Test Notification',
  'This is a test message from Supabase',
  '{"test": true}'::jsonb
);
```

### Test Trigger

```sql
-- Insert a test message (will trigger notification)
INSERT INTO messages (chat_id, sender_id, content, message_type)
VALUES ('CHAT_UUID', 'SENDER_UUID', 'Test message', 'text');
```

## Monitoring

### Check Trigger Execution

```sql
-- View recent messages and their notifications
SELECT 
  m.id,
  m.content,
  m.created_at,
  u.display_name as sender
FROM messages m
JOIN users u ON u.id = m.sender_id
ORDER BY m.created_at DESC
LIMIT 10;
```

### Debug Logs

Check Supabase logs for:
- `NOTICE` messages from the notification function
- HTTP response status codes
- Any errors in trigger execution

## Troubleshooting

### Notifications Not Sending

1. **Check FCM Token**: Verify token is saved in `user_tokens` table
2. **Verify Server Key**: Ensure FCM server key is correct
3. **Check HTTP Extension**: Confirm `CREATE EXTENSION http` succeeded
4. **Review Permissions**: Ensure RLS policies allow token access
5. **Test FCM Manually**: Use Postman/curl to test FCM endpoint directly
6. **Check Supabase Logs**: Look for errors in the logs panel

### Sample cURL Test

```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_FCM_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "FCM_TOKEN_HERE",
    "notification": {
      "title": "Test",
      "body": "Test message"
    }
  }'
```

## Alternative: Supabase Webhooks

Instead of database triggers, you can use Supabase Database Webhooks:

1. Go to Supabase Dashboard → Database → Webhooks
2. Create new webhook on `messages` table for INSERT events
3. Set webhook URL to your own server that handles FCM sending
4. Your server receives the webhook payload and sends FCM notification

This approach is more flexible but requires maintaining a separate service.

## Client-Side Integration

The Flutter app automatically:
1. Gets FCM token on login
2. Saves token to `user_tokens` table
3. Displays notifications in system tray (via `flutter_local_notifications`)
4. Handles notification taps to open specific chats

See `lib/services/notification_service.dart` for implementation details.
