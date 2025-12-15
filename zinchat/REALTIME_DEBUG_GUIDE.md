# Real-time Unread Count Debug Guide

## What Was Implemented

The chat list now uses a **hybrid streaming approach** that combines:
1. **Supabase Realtime** - Instant updates when enabled (requires Realtime replication)
2. **Periodic Polling** - Automatic refresh every 5 seconds as backup
3. **Immediate Load** - Fetches data instantly when you open the home screen

This ensures unread counts update within 5 seconds maximum, even if Realtime isn't enabled.

## Debug Steps

### 1. Check Console Logs

After hot restarting the app, you should see these logs:

**On App Start:**
```
🔴 getUserChatsStream: Setting up stream listener with hybrid approach
� Initial chat list loaded. Count: X
```

**Every 5 Seconds (Polling):**
```
🔵 Polling chat list...
```

**If Realtime is Enabled:**
```
🟢 Realtime event! Refreshing chat list...
🟢 Chat list refreshed via Realtime. Count: X
```

**When You Read Messages:**
```
🔵 Marking messages as read for chat: [chat_id]
🔵 Marked X messages as read
� Polling chat list...  (or 🟢 Realtime event)
```

### 2. Verify Supabase Realtime is Enabled

1. Go to your Supabase Dashboard
2. Navigate to **Database** → **Replication**
3. Make sure the `messages` table has replication enabled
4. If not, click the toggle to enable it

### 3. Check Network Tab

If you're testing on web, open DevTools → Network tab and filter for "realtime":
- You should see a WebSocket connection to Supabase
- Look for messages being sent/received

### 4. Test the Feature

**Test Scenario:**
1. Device A sends 5 messages to Device B
2. On Device B, you should see "5" unread badge on home screen
3. Open the chat on Device B (this calls `markMessagesAsRead`)
4. Watch the console logs - you should see "Marked 5 messages as read"
5. **Stay in the chat or go back to home screen**
6. Within 5 seconds (or instantly if Realtime is enabled), the badge should update to "0"

**Expected Behavior:**
- With Realtime: Updates instantly (< 1 second)
- Without Realtime: Updates within 5 seconds (polling)
- You should see either 🟢 (Realtime) or 🔵 (polling) log messages

**If Not Working:**
- Check console for 🔴 error messages
- Wait at least 5 seconds (polling cycle)
- Verify internet connection

## Common Issues

### Issue 1: Stream Never Emits
**Symptom:** Only see "🔴 getUserChatsStream: Setting up stream listener", no 🟢 messages

**Solution:** 
- Realtime is not enabled on `messages` table
- Go to Supabase Dashboard → Database → Replication
- Enable replication for `messages` table

### Issue 2: "Error refreshing chat list from stream"
**Symptom:** See 🔴 error messages

**Solution:**
- Check the error details in console
- May be a database query issue or permission problem

### Issue 3: Stream Emits but Count Doesn't Update
**Symptom:** See 🟢 messages but badge stays the same

**Solution:**
- The `getUserChats()` function may not be calculating unread counts correctly
- Check if `is_read` field is being updated in database
- Verify the SQL query in `getUserChats()` method

## Manual Database Check

You can manually verify in Supabase Dashboard → Table Editor:

1. Go to `messages` table
2. Find messages where `is_read = false`
3. Note the count
4. Open the chat in app
5. Refresh the table - `is_read` should now be `true`
6. The unread count should match

## How It Works Now

The hybrid approach means:

1. **Instant Updates (If Realtime Enabled)**: The moment `markMessagesAsRead` updates the database, Realtime detects the change and triggers a refresh.

2. **Guaranteed Updates (Polling Backup)**: Even if Realtime fails or isn't enabled, the app polls every 5 seconds to check for updates.

3. **No Configuration Required**: This just works out of the box. Enabling Realtime in Supabase will make it faster, but it's not required.

## Performance Notes

- **Polling every 5 seconds** is minimal overhead (1 query every 5s)
- **Realtime is more efficient** - enable it in Supabase Dashboard for better performance
- **Both work together** - you get instant updates via Realtime + guaranteed updates via polling
