# 🔔 Server Message Notifications Fix

## Problem Identified
Server message notifications were not being sent because the `sendMessage` method in `server_service.dart` was **not calling the send-notification edge function** after inserting a message.

Direct messages had this functionality implemented in `chat_service.dart`, but server messages were missing it.

## Solution Implemented

### Changes Made

#### File: `lib/services/server_service.dart`

**1. Updated `sendMessage()` method:**
- Now captures the `messageId` from the inserted message
- Calls `_sendServerNotifications()` after successfully inserting the message
- Runs notification sending as fire-and-forget (non-blocking)

**2. Added `_sendServerNotifications()` method:**
This new private method:
- Gets the sender's name from the profiles table
- Retrieves all server members (except the sender)
- Checks notification preferences in `server_notification_settings` table
- Respects user notification settings (enabled/disabled per server)
- Calls the `send-notification` edge function for each member
- Gracefully handles failures for individual members
- Logs all operations via `DebugLogger`

### How It Works

```
User sends server message
    ↓
sendMessage() inserts message into database
    ↓
messageId captured from response
    ↓
_sendServerNotifications() called (fire-and-forget)
    ↓
For each server member (except sender):
  - Check if notifications are enabled
  - If enabled, call send-notification edge function
  - Edge function sends FCM notification to recipient's devices
```

### Key Features

✅ **Notification Preferences Respected**
- Checks `server_notification_settings.notifications_enabled` for each user
- Default to `true` if no settings exist (first time)

✅ **Fire-and-Forget**
- Non-blocking: message sends while notifications are queued
- One member's notification failure doesn't affect others

✅ **Comprehensive Logging**
- Uses `DebugLogger` for detailed tracking
- Easy debugging via debug console

✅ **Error Handling**
- Silently fails (notifications aren't critical)
- Errors logged but don't break message sending

### Database Requirements

The implementation depends on:
1. **`server_notification_settings` table** - stores per-user, per-server notification preferences
2. **`server_members` table** - gets list of recipients
3. **`profiles` table** - gets sender's display name
4. **`send-notification` edge function** - handles FCM sending

All of these already exist in the project.

### Testing the Fix

#### 1. Manual Testing:
1. Create a server with multiple members
2. Send a message as one user
3. Check that other members receive notifications
4. Disable notifications for a server
5. Send another message
6. Verify no notifications are received

#### 2. Debug Logs:
Watch the debug console for messages like:
```
🔔 Preparing to send server notifications for message: xyz
🔔 Found 5 members to notify (excluding sender)
🔔 Notification sent to member: abc123
✅ Server notification batch complete
```

#### 3. Firebase Console:
- Go to Firebase Console → Cloud Messaging → All messages
- See notifications being sent and delivery status

## Deployment

1. **No database changes needed** - all required tables exist
2. **Deploy app update** with the `server_service.dart` changes
3. **Verify edge function is deployed**: `supabase functions list`
4. **Test in staging first** before production

## Fallback (If Edge Function Issues)

If notifications fail, users can still:
- See messages arrive in real-time via RealtimeSubscription
- Manually refresh the chat to see new messages
- Messages are never lost; only notifications might fail

## Related Files
- `lib/services/send-notification/index.ts` - Edge function
- `lib/services/chat_service.dart` - Similar implementation for direct messages
- `lib/services/notification_service.dart` - Notification handling
- `SERVER_NOTIFICATIONS_COMPLETE.md` - Notification settings system

## Next Steps (Optional)

1. **Notification Sounds**: Customize per server
2. **Notification Channels**: Different for mentions vs regular messages
3. **Batch Notifications**: When server is very active
4. **Notification Preview**: Show channel name in notification
