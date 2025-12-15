# Server Management - Quick Start

## 🚀 Setup (5 minutes)

### 1. Run Database Script
```sql
-- In Supabase SQL Editor, run:
db/SERVER_MANAGEMENT_ENHANCEMENTS.sql
```

### 2. Verify Installation
```sql
-- Check functions exist:
SELECT routine_name FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name LIKE '%server%';

-- Should see:
-- can_create_server
-- ban_user_from_server
-- unban_user_from_server
-- mute_user_in_server
-- unmute_user_in_server
-- timeout_user_in_server
-- remove_timeout_from_user
-- cleanup_expired_moderation
-- is_user_banned
-- is_user_muted
-- is_user_in_timeout
```

### 3. Run App
```bash
flutter pub get
flutter run
```

---

## 📖 Quick Usage

### Open Edit Server Screen
```dart
import '../screens/servers/edit_server_screen.dart';

// From your server settings page:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => EditServerScreen(server: currentServer),
  ),
);
```

### Open Member Management Screen
```dart
import '../screens/servers/server_member_management_screen.dart';

// From your server page:
final isAdmin = await ServerService().isUserAdmin(serverId);
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ServerMemberManagementScreen(
      server: currentServer,
      isAdmin: isAdmin,
    ),
  ),
);
```

### Check Server Limit Before Creation
```dart
final serverService = ServerService();

// Check if user can create more servers
final canCreate = await serverService.canCreateServer();
if (!canCreate) {
  // Show error message
  return;
}

// Create server
final server = await serverService.createServer(/*...*/);
```

### Ban a User
```dart
final result = await ServerService().banUser(
  serverId: 'uuid',
  userId: 'uuid',
  reason: 'Violating rules',
  permanent: true,
);

if (result['success'] == true) {
  // Success
} else {
  print('Error: ${result['error']}');
}
```

### Mute a User (1 hour)
```dart
final result = await ServerService().muteUser(
  serverId: 'uuid',
  userId: 'uuid',
  reason: 'Spamming',
  durationMinutes: 60,
);
```

### Timeout a User (5 minutes)
```dart
final result = await ServerService().timeoutUser(
  serverId: 'uuid',
  userId: 'uuid',
);
```

### Check Moderation Status
```dart
final serverService = ServerService();

final isBanned = await serverService.isUserBanned(serverId, userId);
final isMuted = await serverService.isUserMuted(serverId, userId);
final isTimedOut = await serverService.isUserInTimeout(serverId, userId);

// Use in UI:
if (isMuted || isTimedOut) {
  // Disable send button
}
```

---

## 🎯 Common Tasks

### Task 1: Add "Edit Server" Button
```dart
// In your server settings screen:
if (isOwnerOrAdmin) {
  ListTile(
    leading: Icon(Icons.edit_rounded),
    title: Text('Edit Server'),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditServerScreen(server: server),
        ),
      );
    },
  ),
}
```

### Task 2: Add "Manage Members" Button
```dart
// In your server screen:
if (isOwnerOrAdmin) {
  IconButton(
    icon: Icon(Icons.admin_panel_settings_rounded),
    onPressed: () async {
      final isAdmin = await ServerService().isUserAdmin(server.id);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ServerMemberManagementScreen(
            server: server,
            isAdmin: isAdmin,
          ),
        ),
      );
    },
  ),
}
```

### Task 3: Disable Send for Muted Users
```dart
// In your message input widget:
bool _canSendMessages = true;

@override
void initState() {
  super.initState();
  _checkMuteStatus();
}

Future<void> _checkMuteStatus() async {
  final serverService = ServerService();
  final userId = serverService.supabase.auth.currentUser?.id;
  if (userId == null) return;
  
  final isMuted = await serverService.isUserMuted(widget.serverId, userId);
  final isTimedOut = await serverService.isUserInTimeout(widget.serverId, userId);
  
  setState(() {
    _canSendMessages = !isMuted && !isTimedOut;
  });
}

// In your send button:
ElevatedButton(
  onPressed: _canSendMessages ? _sendMessage : null,
  child: Text(_canSendMessages ? 'Send' : 'Muted'),
)
```

---

## 🔧 Testing Checklist

### Server Limit
- [ ] Create 1st server → Success
- [ ] Create 2nd server → Success
- [ ] Try 3rd server → Shows error
- [ ] Delete 1 server → Can create again

### Edit Server
- [ ] Change name → Saves correctly
- [ ] Upload icon → Displays new icon
- [ ] Change description → Saves correctly
- [ ] Non-admin → Cannot access

### Ban User
- [ ] Ban member → Removed from list
- [ ] Banned user tries join → Rejected
- [ ] Unban → Can rejoin

### Mute User
- [ ] Mute for 10 min → Cannot send
- [ ] Wait 10 min → Auto-expires
- [ ] Unmute early → Immediately restored

### Timeout
- [ ] Timeout → 5 min restriction
- [ ] Auto-expires after 5 min
- [ ] Remove early → Restored

---

## 🐛 Troubleshooting

### "Failed to create server" (when < 2)
```sql
-- Check function exists:
SELECT can_create_server('YOUR-USER-ID');
-- Should return true/false

-- Check owned servers:
SELECT * FROM servers WHERE owner_id = 'YOUR-USER-ID';
```

### Banned user can still join
```sql
-- Check ban record:
SELECT * FROM server_member_moderation 
WHERE server_id = 'SERVER-ID' 
AND user_id = 'USER-ID' 
AND moderation_type = 'ban';

-- Check function:
SELECT is_user_banned('SERVER-ID', 'USER-ID');
```

### Edit button not showing
```dart
// Check admin status:
final isAdmin = await ServerService().isUserAdmin(serverId);
print('Is admin: $isAdmin');

// Check server owner:
print('Server owner: ${server.ownerId}');
print('Current user: ${ServerService().supabase.auth.currentUser?.id}');
```

---

## 📚 Documentation

- **Full Guide:** `SERVER_MANAGEMENT_GUIDE.md` (500+ lines)
- **Implementation Summary:** `SERVER_MANAGEMENT_IMPLEMENTATION_SUMMARY.md`
- **This File:** `SERVER_MANAGEMENT_QUICK_START.md`

---

## 🆘 Need Help?

1. Check database functions installed: `\df` in psql
2. Check RLS policies active: `\dp` in psql
3. Check app logs for errors
4. Test SQL functions directly in Supabase Editor

---

## ✅ Summary

**You now have:**
- ✅ 2-server creation limit
- ✅ Edit server (name, description, icon)
- ✅ Ban/Mute/Timeout members
- ✅ Member management UI
- ✅ Moderation log
- ✅ Database-enforced security

**Ready to use!** Just add navigation buttons to your existing screens.
