# Real-time Messages & Online Status Fix

## Issues Fixed
1. ✅ **Status Caption Display** - Captions now show as overlay at bottom (WhatsApp style)
2. ✅ **Last Seen Tracking** - Presence service updates every 1 minute
3. ✅ **Real-time Messages** - Already implemented with `.stream()` but needs Realtime enabled

---

## Setup Required

### Step 1: Run SQL Migrations

**A. Online Status (if not done yet):**
Run `ADD_ONLINE_STATUS.sql` in Supabase SQL Editor

**B. Storage Policies (if not done yet):**
Run `PROFILE_PHOTOS_POLICIES.sql` in Supabase SQL Editor

### Step 2: Enable Realtime for Messages Table

Go to **Supabase Dashboard** → **Database** → **Replication**

Enable Realtime for these tables:
- ✅ `messages` (for real-time chat)
- ✅ `chats` (for chat list updates)
- ✅ `profiles` (for online status updates)

**How to enable:**
1. Find the table in the list
2. Toggle the "Realtime" switch to ON
3. Click "Save changes"

---

## What's Been Fixed

### 1. Status Caption Display ✅
**File:** `lib/screens/status/status_viewer_screen.dart`

**Change:** Added caption overlay at bottom of image/video statuses (like WhatsApp)
```dart
// Caption appears at bottom with gradient background
if (status.content != null && status.content!.isNotEmpty && status.mediaType != 'text')
  Positioned(
    bottom: 0,
    child: Container with gradient overlay
  )
```

### 2. Last Seen Tracking ✅
**Files:** 
- `lib/services/presence_service.dart` - Updates every 1 minute
- `lib/models/user.dart` - `isOnline` checks if last_seen < 2 minutes ago
- `lib/screens/home/home_screen.dart` - Starts presence service

**How it works:**
- Every 60 seconds, updates `profiles.last_seen` to current timestamp
- Users are "online" if last_seen < 2 minutes ago
- Displays "online", "last seen X ago", or "last seen recently"

### 3. Real-time Messages ✅ (Already Implemented)
**File:** `lib/services/chat_service.dart`

**Already using Supabase Realtime:**
```dart
Stream<List<MessageModel>> getMessagesStream(String chatId) {
  return supabase
      .from('messages')
      .stream(primaryKey: ['id'])  // ← Real-time stream
      .eq('chat_id', chatId)
      .order('created_at', ascending: true)
      .map((data) => data.map((json) => MessageModel.fromJson(json)).toList());
}
```

**Why messages might not update in real-time:**
- Realtime replication might not be enabled for `messages` table in Supabase
- Need to enable in Dashboard → Database → Replication

---

## Testing Checklist

### Test Status Captions:
1. Create a new status with an image
2. Add a caption in the caption screen
3. View the status - caption should appear at bottom with dark gradient

### Test Online Status:
1. Have two devices/accounts
2. Open app on Device A - should show as "online"
3. Close app on Device A - within 2 minutes should show "last seen X ago"
4. Wait 3+ minutes - should show "last seen X minutes ago"

### Test Real-time Messages:
1. Have two devices/accounts
2. Open chat between them on both devices
3. Send message from Device A
4. Message should appear immediately on Device B without refresh
5. If not working:
   - Check Realtime is enabled for `messages` table
   - Check console for Realtime connection errors

---

## Troubleshooting

### Messages not updating in real-time:
- ✅ Enable Realtime for `messages` table in Supabase Dashboard
- ✅ Check Supabase console logs for Realtime errors
- ✅ Verify RLS policies allow reading messages
- ✅ Check internet connection

### Online status shows "last seen recently" for everyone:
- ❌ SQL migration not run - run `ADD_ONLINE_STATUS.sql`
- ❌ Presence service not started - should auto-start in HomeScreen
- ❌ App not open long enough - presence updates every 60 seconds

### Profile photo upload still failing:
- ❌ Storage policies not applied - run `PROFILE_PHOTOS_POLICIES.sql`
- ❌ Bucket doesn't exist - create in Supabase Dashboard → Storage
- ❌ Bucket not public - toggle "Public bucket" ON in settings

---

## Code Changes Summary

### Modified Files:
1. `lib/screens/status/status_viewer_screen.dart`
   - Added caption overlay with gradient at bottom
   - Only shows for image/video statuses (not text-only)
   
2. `lib/models/user.dart` (already modified earlier)
   - Added `lastSeen` field
   - Added `isOnline` getter (< 2 minutes)
   - Added `lastSeenText` getter for formatting

3. `lib/services/presence_service.dart` (already created earlier)
   - Timer-based presence updates every 60 seconds
   - Updates `profiles.last_seen` in database

4. `lib/screens/home/home_screen.dart` (already modified earlier)
   - Integrated PresenceService
   - Starts in initState(), stops in dispose()

### No Changes Needed For Messages:
- Real-time already implemented with `.stream()`
- Just needs Realtime enabled in Supabase Dashboard

---

## Next Steps

1. ✅ Run SQL migrations if not done
2. ✅ Enable Realtime replication for tables
3. ✅ Test status captions
4. ✅ Test online status
5. ✅ Test real-time messages
6. ✅ Enjoy your fully functional chat app! 🎉
