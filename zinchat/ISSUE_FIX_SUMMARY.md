# Critical Issues - Root Cause Analysis & Fixes

## Issue #1: Media & Voice Messages Failing (RLS 42501 Error)

### Root Cause
The app was doing a **double-check** for contacts:
1. First check in `sendMediaMessage()` using `_canSendMessageDirectly()` 
2. Second check by Supabase RLS policy at INSERT time using `can_send_message()` function

**The problem**: Race conditions! If the RPC function fails/times out between the app check and the database insert, or if PostgREST's schema cache is stale, the RLS policy blocks the insert even though the app thinks users are contacts.

### The Fix
**Removed the pre-check** in `sendMediaMessage()` and let RLS handle it directly:
- RLS policy is the single source of truth
- If users aren't contacts, you get a clear error message with "Add Contact" button
- No more race conditions between app logic and database enforcement

**Files Changed:**
- `lib/services/chat_service.dart` - Removed `_canSendMessageDirectly()` call before media insert
- `lib/screens/chat/chat_screen.dart` - Added user-friendly error handling with "Add Contact" action button

---

## Issue #2: Voice Notes Taking Forever to Load

### Root Cause
The `audio_service.dart` was using `UrlSource` to play audio files from HTTP URLs:
```dart
await _audioPlayer.play(UrlSource(filePath)); // Downloads EVERY TIME
```

This meant **every voice note playback re-downloaded the entire file** from Supabase Storage, with:
- No caching
- Network latency every time
- Wasted bandwidth
- Poor user experience (spinning loader, delays)

### The Fix
**Implemented local file caching**:
1. First playback: Download from Supabase → Save to local cache → Play from cache
2. Subsequent playbacks: Check cache → Play instantly from local file
3. Uses `http` package to download and `DeviceFileSource` for cached playback

**Technical Details:**
- Cache directory: `{tempDir}/audio_cache/`
- Cache key: URL hash + `.m4a` extension
- Fallback: If download fails, streams directly (original behavior)

**Files Changed:**
- `lib/services/audio_service.dart` - Added `_getCachedAudioFile()` and `_downloadAndCacheAudio()` methods

---

## Issue #3: Status Reply Layout Unorganized

### Root Cause
The `status_replies_screen.dart` AppBar had no centering, making the title left-aligned (default Flutter behavior).

### The Fix
Added `centerTitle: true` to the AppBar widget.

**Files Changed:**
- `lib/screens/status/status_replies_screen.dart` - Line 99

---

## SQL Database State

### Current Supabase Setup
You should have run **CLEAN_MESSAGE_POLICIES.sql** which:
1. Drops all conflicting message RLS policies
2. Creates 4 clean policies:
   - INSERT: Users can send if they're contacts (checks `can_send_message()`)
   - SELECT: Users can read messages in their chats
   - UPDATE: Users can edit own messages
   - DELETE: Users can delete own messages

### The `can_send_message()` Function
Located in `MESSAGE_REQUEST_SYSTEM.sql`:
```sql
CREATE OR REPLACE FUNCTION public.can_send_message(
    p_sender_id UUID,
    p_receiver_id UUID
)
RETURNS BOOLEAN
```
- Checks if two users exist in the `contacts` table (bidirectional)
- Used by RLS policy to enforce contact-only messaging
- Must accept UUID parameters (not BIGINT!)

---

## Testing Checklist

After hot reload/restart:

### ✅ Voice Notes
1. Record a voice note (hold mic button)
2. Send to a contact
3. **First playback**: Should download and cache (slight delay)
4. **Second playback**: Should play instantly from cache
5. Check terminal logs for "Playing cached audio" message

### ✅ Media Sending (Images/Video)
1. Send image to a **contact** → Should work ✅
2. Send image to a **non-contact** → Should show error: "Cannot send image. Add [Name] as a contact first." with "Add Contact" button

### ✅ Status Reply Screen
1. Open any status
2. Tap to view replies
3. Check AppBar title is **centered**

---

## Debugging Commands

### Check if SQL policies are correct:
```sql
SELECT policyname, cmd, qual, with_check 
FROM pg_policies 
WHERE tablename = 'messages';
```

### Check if can_send_message function exists:
```sql
SELECT proname, proargtypes 
FROM pg_proc 
WHERE proname = 'can_send_message';
```

### Clear audio cache (for testing):
```powershell
Remove-Item "$env:TEMP\audio_cache\*" -Force
```

---

## Known Limitations

1. **Contact Management**: Currently no UI to add contacts directly from the chat error message (marked as TODO)
2. **Cache Size**: Audio cache grows indefinitely - consider implementing cache cleanup based on size/time
3. **Network Handling**: If user goes offline mid-download, voice note will fallback to streaming (which will also fail offline)

---

## Next Steps (If Issues Persist)

1. **Verify Supabase State**:
   - Check PostgREST schema cache is fresh (NOTIFY should have reloaded it)
   - Verify `can_send_message` function signature uses UUID not BIGINT
   
2. **Check Contacts Table**:
   ```sql
   SELECT * FROM contacts WHERE user_id_1 = 'YOUR_USER_ID' OR user_id_2 = 'YOUR_USER_ID';
   ```

3. **Enable Debug Logging**:
   - Terminal logs now show detailed RLS error messages
   - Look for "🚫 RLS Policy Violation" messages

4. **Nuclear Option**:
   - Run `MESSAGE_REQUEST_SYSTEM.sql` fresh
   - Then run `CLEAN_MESSAGE_POLICIES.sql`
   - Do a full app restart (not just hot reload)
