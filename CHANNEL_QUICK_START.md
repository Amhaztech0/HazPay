# Quick Start: Testing Channel System

## What You Just Got

✅ **Multi-Channel Support** for servers
✅ **Channel Management UI** for admins
✅ **Real-time message filtering** by channel
✅ **Complete CRUD operations** (Create, Read, Update, Delete)
✅ **Role-based access control** (RLS enforced)
✅ **Three channel types**: Text, Voice, Announcements

---

## Quick Test Flow (5 minutes)

### Step 1: Start the App
```powershell
cd C:\Users\Amhaz\Desktop\zinchat\zinchat
flutter run -d 2A201FDH3005XZ  # or your device ID
```

### Step 2: Navigate to a Server
1. Login if needed
2. Go to home screen
3. Open ANY server you're owner/admin of

### Step 3: Access Channel Management
1. Click the **3-dot menu** icon in app bar (top right)
2. Select **"Manage Channels"**

### Step 4: Create Your First Channel
1. Click **"+ New Channel"** floating button
2. Fill in:
   ```
   Name: general
   Description: Main channel
   Type: Text
   ```
3. Click **Create**
4. You should see: `✅ Channel 'general' created!`

### Step 5: Test in Chat
1. Go back to server chat (back button)
2. Look at app bar - should see **dropdown with "general"**
3. Type a test message
4. Send it
5. Message appears in chat ✅

### Step 6: Create Another Channel
1. Open "Manage Channels" again
2. Create: `announcements` (Type: Announcements)
3. Go back to chat

### Step 7: Test Channel Switching
1. Click channel dropdown (in app bar)
2. Select **"announcements"** 
3. Type: "Test in announcements"
4. Send message
5. Switch back to **"general"**
6. Original message NOT visible ✅
7. Switch to **"announcements"**
8. Your announcement message visible ✅

---

## What to Look For ✓

| Feature | How to Verify |
|---------|---------------|
| **Dropdown Appears** | See channel list in app bar |
| **Channel Icons** | 🏷️ text, 🔊 voice, 🔔 announcements |
| **Message Filtering** | Messages change when switching channels |
| **Create Works** | Green SnackBar appears |
| **Edit Works** | Channel name updates |
| **Delete Works** | Channel disappears from dropdown |
| **Real-time** | Multiple devices see changes instantly |

---

## Troubleshooting

### "Manage Channels" button not visible?
→ You might not be owner/admin of this server
→ Try creating a new server first

### No channels in dropdown?
→ Go to "Manage Channels" and create one
→ Reload the chat screen

### Messages not filtering?
→ Check that different messages were sent to different channels
→ Try reopening the app

### App crashes?
→ Check logcat output: `flutter run ... 2>&1`
→ Report the error

---

## Files Modified

These are the new/updated files:
- `lib/models/server_channel_model.dart` (NEW)
- `lib/screens/servers/channel_management_screen.dart` (NEW)
- `lib/screens/servers/server_chat_screen.dart` (UPDATED)
- `lib/services/server_service.dart` (UPDATED)
- `lib/models/server_model.dart` (UPDATED - added channelId)
- `db/CREATE_SERVER_CHANNELS.sql` (EXECUTED)

---

## Next Steps

After confirming everything works:

1. **Test with 2 users** - Open same server on 2 devices
2. **Test permissions** - Regular member shouldn't see "Manage Channels" options
3. **Test persistence** - Close app and reopen, messages should still be there
4. **Check database** - Go to Supabase, verify `server_channels` table has data

---

## Questions?

If something doesn't work:
1. Check the error output in terminal
2. Verify Supabase table exists: `server_channels`
3. Make sure you ran the SQL migration
4. Check RLS policies are applied (Supabase Dashboard)

---

**You're all set! Start testing! 🚀**
