# Server Management & Moderation Guide

## Overview

This guide covers the server management and moderation features implemented in ZinChat, including the 2-server creation limit, server editing capabilities, and member moderation tools (ban, mute, timeout).

## Features Implemented

### 1. Server Creation Limit (2 per user)
- Users can only own up to 2 servers
- Enforced at database level via RLS policies
- Checked before server creation in UI
- Clear error message when limit reached

### 2. Server Editing (Owner/Admin only)
- Edit server name
- Edit server description
- Upload/change server icon
- Real-time change detection
- Save button enabled only when changes made

### 3. Member Moderation (Owner/Admin only)
- **Ban:** Permanently remove member and prevent rejoining
- **Mute:** Prevent member from sending messages (temporary or permanent)
- **Timeout:** Quick 5-minute restriction
- **Promote/Demote:** Change member roles (Owner only - coming soon)

## Database Setup

### Step 1: Run the Enhancement SQL

Execute the following SQL file in your Supabase SQL Editor:

```
db/SERVER_MANAGEMENT_ENHANCEMENTS.sql
```

**Prerequisites:** Must run after `SUPABASE_SERVERS_SETUP.sql`

### What This SQL Script Does:

#### Creates Table:
```sql
server_member_moderation (
  id UUID PRIMARY KEY,
  server_id UUID → servers(id),
  user_id UUID → auth.users(id),
  moderation_type TEXT ('ban', 'mute', 'timeout'),
  reason TEXT,
  moderator_id UUID → auth.users(id),
  expires_at TIMESTAMP (NULL = permanent),
  created_at TIMESTAMP
)
```

#### Helper Functions:
- `can_create_server(p_user_id)` - Returns true if user owns < 2 servers
- `is_user_banned(p_server_id, p_user_id)` - Check ban status
- `is_user_muted(p_server_id, p_user_id)` - Check mute status
- `is_user_in_timeout(p_server_id, p_user_id)` - Check timeout status

#### Moderation Functions:
- `ban_user_from_server()` - Removes from members, adds ban record
- `unban_user_from_server()` - Removes ban record
- `mute_user_in_server()` - Adds mute with optional duration
- `unmute_user_in_server()` - Removes mute
- `timeout_user_in_server()` - Adds 5-minute timeout
- `remove_timeout_from_user()` - Removes timeout
- `cleanup_expired_moderation()` - Deletes expired records (run periodically)

#### Updated RLS Policies:
- **servers INSERT:** Checks `can_create_server()` before allowing creation
- **server_members INSERT (join):** Checks `is_user_banned()` to prevent banned users from joining
- **server_messages INSERT:** Checks `is_user_muted()` and `is_user_in_timeout()` to prevent muted/timed-out users from messaging

## Code Structure

### New Files Created:

#### 1. **lib/models/server_moderation_model.dart**
Model for moderation records:
```dart
class ServerModerationModel {
  final String id;
  final String serverId;
  final String userId;
  final String moderationType; // 'ban', 'mute', 'timeout'
  final String? reason;
  final String moderatorId;
  final DateTime? expiresAt; // null = permanent
  final DateTime createdAt;
  
  // Getters:
  bool get isExpired
  bool get isPermanent
  String get formattedDuration
}
```

#### 2. **lib/screens/servers/edit_server_screen.dart**
Server editing UI (Owner/Admin only):
- Tap server icon to change image
- Edit name/description text fields
- Save button appears when changes detected
- Auto-navigation: Pass `ServerModel` to screen, returns `true` if updated

#### 3. **lib/screens/servers/server_member_management_screen.dart**
Member moderation UI (Owner/Admin only):
- **Members Tab:** List all members with role badges
- **Moderation Log Tab:** View all moderation actions
- **Member Actions Menu:** Ban/Mute/Timeout options
- **Dialogs:** Confirmation with optional reason input
- **Duration Selection:** Choose mute duration (10 min, 1 hour, 24 hours, permanent)

### Modified Files:

#### 1. **lib/services/server_service.dart**
Added methods:
```dart
// Server Limits
Future<bool> canCreateServer()
Future<int> getUserOwnedServersCount()

// Server Editing
Future<bool> updateServerName(serverId, newName)
Future<bool> updateServerDescription(serverId, description)
Future<bool> updateServerIcon(serverId, iconFile)

// Member Moderation
Future<Map> banUser({serverId, userId, reason, permanent})
Future<Map> unbanUser({serverId, userId})
Future<Map> muteUser({serverId, userId, reason, durationMinutes})
Future<Map> unmuteUser({serverId, userId})
Future<Map> timeoutUser({serverId, userId, reason, durationMinutes})
Future<Map> removeTimeout({serverId, userId})

// Status Checks
Future<bool> isUserBanned(serverId, userId)
Future<bool> isUserMuted(serverId, userId)
Future<bool> isUserInTimeout(serverId, userId)

// Moderation Records
Future<List<ServerModerationModel>> getServerModeration(serverId)
Future<void> cleanupExpiredModeration()
```

#### 2. **lib/screens/servers/create_server_screen.dart**
Added server limit check:
```dart
Future<void> _createServer() async {
  // Check limit before creating
  final canCreate = await _serverService.canCreateServer();
  if (!canCreate) {
    // Show error: "You can only own up to 2 servers..."
    return;
  }
  // ... create server
}
```

#### 3. **lib/models/server_model.dart**
Enhanced ServerMemberModel:
```dart
class ServerMemberModel {
  // ... existing fields
  final UserProfile? user; // NEW: User profile information
}

class UserProfile { // NEW
  final String id;
  final String? fullName;
  final String? profilePhotoUrl;
}
```

## Usage Guide

### For Server Owners/Admins:

#### Edit Server Details:
1. Navigate to server
2. Open server settings/info
3. Tap "Edit Server" button
4. Change name, description, or tap icon to upload new image
5. Tap "Save" when done

**Navigation Example:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => EditServerScreen(server: myServer),
  ),
);
```

#### Manage Members:
1. Navigate to server
2. Open member list
3. Tap "Manage Members" button (if admin/owner)
4. See two tabs: **Members** | **Moderation Log**

**Navigation Example:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ServerMemberManagementScreen(
      server: myServer,
      isAdmin: true, // Pass admin status
    ),
  ),
);
```

#### Moderate a Member:
1. In Members tab, tap 3-dot menu next to member name
2. Choose action:
   - **Ban:** Remove permanently (requires confirmation + reason)
   - **Mute:** Prevent messaging (choose duration or permanent)
   - **Timeout:** Quick 5-minute restriction
3. Confirm action
4. Member immediately sees restriction applied

#### View Moderation History:
1. Switch to "Moderation Log" tab
2. See all actions: who was moderated, when, by whom, reason
3. See time remaining for temporary restrictions
4. Expired actions automatically hidden (cleaned up by backend)

### For Regular Members:

#### What Happens When Moderated:

**Banned:**
- Immediately removed from server
- Cannot rejoin using invite codes
- All messages remain (consider deletion feature later)

**Muted:**
- Can read messages but cannot send
- Send button disabled with "You are muted" tooltip
- Duration shown if temporary

**Timed Out:**
- Same as mute but typically shorter (5 minutes default)
- Quick cooling-off period
- Auto-expires after duration

### For Developers:

#### Check Moderation Status:
```dart
final serverService = ServerService();

// Check if user is banned
final isBanned = await serverService.isUserBanned(serverId, userId);

// Check if user is muted
final isMuted = await serverService.isUserMuted(serverId, userId);

// Check if user is in timeout
final isTimedOut = await serverService.isUserInTimeout(serverId, userId);

// Use in UI to disable send button, etc.
```

#### Apply Moderation:
```dart
// Ban user
final result = await serverService.banUser(
  serverId: 'server-uuid',
  userId: 'user-uuid',
  reason: 'Violating community guidelines',
  permanent: true,
);

if (result['success'] == true) {
  print('User banned successfully');
} else {
  print('Error: ${result['error']}');
}

// Mute for 1 hour
final muteResult = await serverService.muteUser(
  serverId: 'server-uuid',
  userId: 'user-uuid',
  reason: 'Spamming',
  durationMinutes: 60,
);

// Timeout (5 minutes)
final timeoutResult = await serverService.timeoutUser(
  serverId: 'server-uuid',
  userId: 'user-uuid',
);
```

#### Cleanup Expired Records (Backend Job):
```dart
// Run periodically (e.g., hourly)
await serverService.cleanupExpiredModeration();
```

## Testing Checklist

### Server Limit:
- [ ] Create 1st server - should succeed
- [ ] Create 2nd server - should succeed
- [ ] Try to create 3rd server - should fail with clear message
- [ ] Delete 1 server
- [ ] Create server again - should succeed

### Edit Server:
- [ ] Open edit screen as owner - should work
- [ ] Open edit screen as admin - should work
- [ ] Open edit screen as member - should be hidden/disabled
- [ ] Change server name - should save and reflect immediately
- [ ] Change description - should save
- [ ] Upload server icon - should upload and display
- [ ] Leave without saving - changes should be discarded

### Ban User:
- [ ] Ban member as admin - should work
- [ ] Banned user tries to rejoin - should fail
- [ ] Banned user removed from member list
- [ ] Unban user - can rejoin again

### Mute User:
- [ ] Mute member with 10-minute duration
- [ ] Muted user cannot send messages
- [ ] Muted user can still read messages
- [ ] After 10 minutes, mute expires automatically
- [ ] Permanent mute - never expires
- [ ] Unmute user - can send messages again

### Timeout User:
- [ ] Timeout member (5 minutes)
- [ ] Member cannot send messages
- [ ] After 5 minutes, timeout expires
- [ ] Remove timeout manually - works immediately

### Moderation Log:
- [ ] All actions appear in log
- [ ] Reason displayed if provided
- [ ] Time remaining shown for temporary restrictions
- [ ] Expired actions eventually cleaned up

## Security Notes

### RLS Enforcement:
- All moderation functions check if caller is admin/owner via database RLS
- Cannot bypass limits/moderation by calling database directly
- User IDs verified using `auth.uid()` in SQL

### Permission Checks:
- UI checks `isUserAdmin()` before showing moderation options
- Backend verifies permissions again in SQL functions
- Double-layer security (UI + database)

### Owner vs Admin:
- Only owner can promote/demote admins (coming soon)
- Both owner and admin can ban/mute/timeout
- Cannot moderate the server owner
- Cannot moderate yourself

## Future Enhancements

### Planned Features:
- [ ] Promote member to admin (owner only)
- [ ] Demote admin to member (owner only)
- [ ] Appeal system for banned users
- [ ] Delete all messages from banned user
- [ ] Kick (remove without ban)
- [ ] Warning system (strikes before ban)
- [ ] Custom timeout durations
- [ ] Scheduled unmute/unban
- [ ] Export moderation logs
- [ ] Audit trail for admin actions

## Troubleshooting

### Issue: "Failed to create server" even though I have < 2 servers
**Solution:** 
- Check if `can_create_server()` function exists in database
- Run `db/SERVER_MANAGEMENT_ENHANCEMENTS.sql`
- Verify RLS policy on `servers` table includes check

### Issue: Banned user can still join
**Solution:**
- Check `is_user_banned()` function exists
- Verify RLS policy on `server_members` INSERT checks ban status
- Run SQL script again

### Issue: Muted user can still send messages
**Solution:**
- Check `is_user_muted()` and `is_user_in_timeout()` functions
- Verify RLS policy on `server_messages` INSERT checks mute/timeout
- Update UI to disable send button for muted users

### Issue: Edit server button not appearing
**Solution:**
- Check `isUserAdmin()` returns true for owner/admin
- Verify user role in `server_members` table
- Owner ID matches server `owner_id`

## Support

For issues or questions:
1. Check database functions are installed (`\df` in psql)
2. Verify RLS policies are active (`\dp` in psql)
3. Check application logs for error messages
4. Test with Supabase SQL Editor directly

## Summary

The server management and moderation system provides comprehensive tools for server owners and admins to:
- Maintain organized servers (2-server limit prevents spam)
- Customize server appearance (name, description, icon)
- Moderate member behavior (ban/mute/timeout)
- Track moderation history (audit log)
- Enforce community guidelines

All features are secured with Row Level Security and permission checks at both UI and database levels.
