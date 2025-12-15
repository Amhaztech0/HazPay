# ⚡ Server Notifications - Quick Setup Guide

## 30-Second Overview
Enable/disable notifications for each server individually. Users can mute noisy servers while staying connected to important ones.

---

## 🚀 Setup Steps

### Step 1: Execute SQL (Supabase Dashboard)
```bash
1. Open Supabase Dashboard → SQL Editor
2. Copy contents of: db/CREATE_SERVER_NOTIFICATION_SETTINGS.sql
3. Click "Run"
4. Verify: "Success. No rows returned"
```

### Step 2: Verify Installation
```sql
-- Run in SQL Editor
SELECT * FROM server_notification_settings LIMIT 5;
```

### Step 3: Run the App
```bash
cd C:\Users\Amhaz\Desktop\zinchat\zinchat
flutter run -d 2A201FDH3005XZ
```

---

## ✅ Quick Test (2 minutes)

### Test 1: Mute Server
1. Open any server
2. Click **3-dot menu** (top right)
3. Select **"Mute/Unmute"**
4. See: "Notifications muted" ✅

### Test 2: Unmute Server
1. Click **3-dot menu** again
2. Select **"Mute/Unmute"**
3. See: "Notifications enabled" ✅

### Test 3: Settings Screen
1. Click **3-dot menu**
2. Select **"Notification Settings"**
3. Toggle the switch
4. See visual feedback ✅

### Test 4: Notification Filtering
1. Mute a server (Server A)
2. Have someone send a message in Server A
3. Verify: NO notification received ✅
4. Unmute Server A
5. Have someone send another message
6. Verify: Notification received ✅

---

## 📋 Features

| Feature | How to Access | What It Does |
|---------|---------------|--------------|
| **Quick Mute** | Menu → Mute/Unmute | Instantly toggle notifications |
| **Settings** | Menu → Notification Settings | Detailed control panel |
| **Status** | Automatic | Shows current notification state |
| **Filtering** | Automatic | Blocks notifications when muted |

---

## 🎯 User Flow

```
User Opens Server Chat
        ↓
Clicks 3-Dot Menu
        ↓
Selects "Mute/Unmute"
        ↓
Notifications Disabled
        ↓
No more notifications from this server
        ↓
Click "Mute/Unmute" again
        ↓
Notifications Enabled
```

---

## 🔧 Menu Options

### Server Chat Screen → 3-Dot Menu
1. 🏷️ **Manage Channels** - Create/edit/delete channels
2. 🔕 **Mute/Unmute** - Quick notification toggle
3. ⚙️ **Notification Settings** - Detailed settings screen
4. ✏️ **Edit Server** - Server management

---

## 💡 Tips

### For Users
- **Muted servers** still show messages, just no notifications
- **Default state** is "enabled" (you'll get notifications)
- **Toggle anytime** - instant effect
- **No limit** on how many servers you can mute

### For Developers
- Settings persist in database
- Real-time synchronization
- RLS security enabled
- Stream-based updates available

---

## 📊 What Was Changed

| File | Type | Purpose |
|------|------|---------|
| `CREATE_SERVER_NOTIFICATION_SETTINGS.sql` | NEW | Database schema |
| `server_notification_settings_screen.dart` | NEW | Settings UI |
| `server_service.dart` | MODIFIED | Added 7 methods |
| `notification_service.dart` | MODIFIED | Added filtering |
| `server_chat_screen.dart` | MODIFIED | Added menu items |

---

## ⚠️ Important Notes

### Before Testing
- ✅ Execute SQL migration first
- ✅ Restart app after SQL execution
- ✅ Ensure you're logged in
- ✅ Join at least one server

### Default Behavior
- **New users**: All servers enabled by default
- **Existing servers**: Notifications enabled by default
- **New servers joined**: Notifications enabled by default
- **Error state**: Defaults to enabled (safe fallback)

---

## 🐛 Troubleshooting

### "Mute/Unmute" option not in menu?
→ Update to latest code version
→ Restart the app

### Toggle doesn't work?
→ Check if SQL migration was executed
→ Verify table exists in Supabase
→ Check user is logged in

### Still receiving notifications after mute?
→ Wait 5-10 seconds for settings to sync
→ Try toggling again
→ Check notification service logs

### Settings screen blank?
→ Check internet connection
→ Verify Supabase connection
→ Check RLS policies are applied

---

## 📖 Documentation

- **Full Documentation**: `SERVER_NOTIFICATIONS_COMPLETE.md`
- **Channel System**: `CHANNEL_SYSTEM_COMPLETE.md`
- **Bug Fixes**: `CHANNEL_BUGS_FIXED.md`
- **Testing Guide**: `CHANNEL_TESTING_GUIDE.md`

---

## ✨ What's Next?

After successful testing:
1. Deploy to production
2. Monitor user feedback
3. Consider future enhancements:
   - Mute duration (1h, 8h, 1d)
   - Per-channel muting
   - Quiet hours
   - Smart notifications (@mentions only)

---

**Ready to test! 🚀**

Execute SQL → Run app → Test mute/unmute → Done!
