# Privacy Controls & Message Requests Implementation Guide

## 📋 Overview

This implementation adds comprehensive privacy and blocking features to ZinChat, similar to WhatsApp and Discord:

✅ **Messaging Privacy Controls** - Control who can message you (everyone or approved only)
✅ **Message Request System** - Discord-like message request functionality
✅ **Block/Unblock Users** - WhatsApp-style blocking with full restriction
✅ **Blocked Users Management** - Dedicated screen to manage blocked contacts
✅ **Enhanced Settings Page** - Moved profile customization features to settings

## 🗄️ Database Schema

### 1. Setup Database
Run the SQL file to create tables and policies:

```bash
# Location: db/PRIVACY_AND_BLOCKING.sql
```

**What it creates:**
- `messaging_privacy` column in `profiles` table
- `blocked_users` table for blocking functionality
- `message_requests` table for Discord-like message requests
- Helper functions: `is_user_blocked()`, `can_message_user()`, `get_pending_requests_count()`
- Updated RLS policies on `messages` table to enforce privacy

### 2. Key Tables

#### **profiles** (Modified)
```sql
messaging_privacy TEXT DEFAULT 'everyone' 
  -- 'everyone' | 'approved_only'
```

#### **blocked_users**
```sql
id UUID PRIMARY KEY
blocker_id UUID (who blocked)
blocked_id UUID (who was blocked)
created_at TIMESTAMP
```

#### **message_requests**
```sql
id UUID PRIMARY KEY
sender_id UUID
receiver_id UUID
first_message_id UUID
status TEXT -- 'pending' | 'accepted' | 'rejected'
created_at TIMESTAMP
updated_at TIMESTAMP
```

## 📦 Files Created

### Models
- `lib/models/message_request_model.dart` - Message request data model
- `lib/models/blocked_user_model.dart` - Blocked user data model
- `lib/models/user.dart` - Updated with `messagingPrivacy` field

### Services
- `lib/services/privacy_service.dart` - Handles all privacy operations:
  - Block/unblock users
  - Manage message requests
  - Check messaging permissions
  - Update privacy settings

### Screens
- `lib/screens/settings/settings_screen.dart` - Enhanced with privacy controls
- `lib/screens/settings/blocked_users_screen.dart` - Manage blocked contacts
- `lib/screens/settings/message_requests_screen.dart` - View/accept/reject requests

### Database
- `db/PRIVACY_AND_BLOCKING.sql` - Complete database setup script

## 📝 Files Modified

### `lib/models/user.dart`
- Added `messagingPrivacy` field
- Updated `fromJson`, `copyWith` methods

### `lib/services/chat_service.dart`
- Added privacy checks before sending messages
- Integration with `PrivacyService`
- Error handling for blocked users and rejected requests

### `lib/screens/chat/chat_screen.dart`
- Added block/unblock menu option in app bar
- Shows current block status
- Handles blocking/unblocking with confirmation dialogs

### `lib/screens/profile/profile_screen.dart`
- Kept lightweight (profile info and photo only)
- Moved theme and wallpaper settings to Settings

## 🚀 Features Implemented

### 1. Messaging Privacy Control

Users can control who can message them:

**Everyone (Default)**
- Anyone can send messages without restrictions
- Works like traditional messaging apps

**Approved Users Only**
- Only users you've approved can message you
- Similar to Discord's message request system
- First-time senders must send a message request

### 2. Message Request System

When a user with "approved_only" privacy receives a first message:

1. **Sender**: Message goes through, but marked as request
2. **Receiver**: Sees pending request in Settings > Message Requests
3. **Receiver Options**:
   - ✅ **Accept** - Opens chat, allows future messages
   - ❌ **Reject** - Sender cannot send more messages

### 3. Block/Unblock Functionality

**Blocking a User:**
- Navigate to chat screen
- Tap ⋮ menu → "Block User"
- Confirm blocking
- User is blocked instantly

**Effects of Blocking:**
- Cannot send or receive messages from blocked user
- Blocked user disappears from chat list
- All message attempts fail for both parties

**Unblocking:**
- Go to Settings → Blocked Contacts
- Tap "Unblock" next to user
- Confirm unblocking
- Can message again

**Alternative Unblock:**
- From chat screen → ⋮ menu → "Unblock User"

### 4. Enhanced Settings Page

New sections in Settings:

**Privacy Section**
- Who can message me (Everyone / Approved only)
- Message Requests (with badge showing pending count)
- Blocked Contacts

**Profile Customization** (Moved from Profile page)
- Theme selection
- Chat wallpaper
- These are now in Settings for better UX

**Account Section**
- Change number (Coming soon)
- Delete account

## 🔐 Security & RLS Policies

### Message Policies
```sql
-- Users can only view messages if not blocked
"Users can view messages in their chats"
  - Checks chat membership
  - Verifies not blocked by other user

-- Users can only send if permission granted
"Users can send messages"
  - Checks chat membership
  - Verifies can_message_user() (not blocked + privacy check)
```

### Blocked Users Policies
```sql
-- Users can block anyone
"Users can block others"
  - Authenticated user = blocker

-- Users can view their blocks
"Users can view their blocks"
  - Shows only your blocked list

-- Users can unblock
"Users can unblock"
  - Can delete your own blocks
```

### Message Requests Policies
```sql
-- Users can create requests
"Users can create message requests"
  - Authenticated user = sender

-- Users can view their requests
"Users can view their requests"
  - Sender or receiver only

-- Receivers can update status
"Receivers can update request status"
  - Only receiver can accept/reject
```

## 🧪 Testing Guide

### Test Messaging Privacy

1. **Setup Two Accounts**
   - User A: Set privacy to "Approved only"
   - User B: Normal user

2. **Test Message Request Flow**
   ```
   User B → Sends first message to User A
   User A → Sees request in Settings > Message Requests
   User A → Taps "Accept" or "Reject"
   
   If Accepted:
   - User B can continue messaging
   - Chat opens normally
   
   If Rejected:
   - User B sees error: "This user has rejected your message request"
   - Cannot send more messages
   ```

### Test Blocking

1. **Block User**
   ```
   User A → Opens chat with User B
   User A → Taps ⋮ → "Block User" → Confirm
   User B → Tries to send message → Error
   User A → Cannot receive messages from User B
   ```

2. **Verify Block List**
   ```
   User A → Settings → Blocked Contacts
   Should see User B in list
   ```

3. **Unblock User**
   ```
   User A → Settings → Blocked Contacts → Tap "Unblock" on User B
   User A → Can now message User B again
   ```

### Test Message Request System

1. **Create Request**
   ```sql
   -- User B sends message to User A (privacy = approved_only)
   SELECT * FROM message_requests WHERE receiver_id = 'user_a_id';
   -- Should show pending request
   ```

2. **Accept Request**
   ```sql
   -- User A accepts
   SELECT status FROM message_requests WHERE id = 'request_id';
   -- Should be 'accepted'
   ```

3. **Test Messaging After Acceptance**
   ```
   User B → Sends another message
   Should work without creating new request
   ```

## 📊 Database Verification

### Check Policies
```sql
-- View blocked_users policies
SELECT tablename, policyname, cmd 
FROM pg_policies 
WHERE tablename = 'blocked_users';

-- View message_requests policies
SELECT tablename, policyname, cmd 
FROM pg_policies 
WHERE tablename = 'message_requests';

-- View updated messages policies
SELECT tablename, policyname, cmd 
FROM pg_policies 
WHERE tablename = 'messages';
```

### Check Functions
```sql
-- Test is_user_blocked function
SELECT is_user_blocked('blocker_id', 'blocked_id');

-- Test can_message_user function
SELECT can_message_user('sender_id', 'receiver_id');

-- Test pending requests count
SELECT get_pending_requests_count('user_id');
```

## 🎯 User Flow Diagrams

### Message Request Flow
```
┌─────────────────────────────────────────────────────────────┐
│ User B wants to message User A (privacy = approved_only)   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │ User B sends message  │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────────┐
         │ Message request created   │
         │ Status: pending           │
         └───────────┬───────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
┌────────────────┐      ┌────────────────┐
│ User A Accepts │      │ User A Rejects │
└───────┬────────┘      └───────┬────────┘
        │                       │
        ▼                       ▼
┌────────────────┐      ┌────────────────────┐
│ Status: accepted│      │ Status: rejected   │
│ Chat opens     │      │ User B blocked     │
│ Can message ✓  │      │ Cannot message ✗   │
└────────────────┘      └────────────────────┘
```

### Blocking Flow
```
┌──────────────────────────────────────────────────┐
│ User A blocks User B from chat screen           │
└─────────────────┬────────────────────────────────┘
                  │
                  ▼
    ┌─────────────────────────┐
    │ Confirm block dialog    │
    └──────────┬──────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │ Insert into blocked_users│
    │ blocker: User A          │
    │ blocked: User B          │
    └──────────┬───────────────┘
               │
               ▼
    ┌──────────────────────────────┐
    │ Effects:                     │
    │ - Messages fail for both     │
    │ - Cannot see each other      │
    │ - RLS policies enforce block │
    └──────────────────────────────┘
```

## 💡 Best Practices

### Performance
- **Indexes**: All foreign keys indexed for fast lookups
- **RLS Functions**: `STABLE` keyword for query optimization
- **Caching**: Block status cached in UI state

### Privacy
- **Row Level Security**: All tables protected by RLS
- **No Leaks**: Blocked users can't infer block status
- **Secure Functions**: Helper functions respect RLS

### User Experience
- **Clear Feedback**: Toast messages confirm actions
- **Confirmation Dialogs**: Prevent accidental blocks
- **Badge Counts**: Shows pending request count
- **Smooth Navigation**: Opens chat after accepting request

## 🔧 Troubleshooting

### Messages Not Sending
```
Error: "You cannot send messages to this user"

Possible causes:
1. User has blocked you
2. You have blocked the user
3. User's privacy = approved_only and no accepted request

Solution:
- Check if blocked: Settings → Blocked Contacts
- Check privacy setting: User profile
- Check request status: Settings → Message Requests
```

### Message Requests Not Showing
```
Request created but not visible

Possible causes:
1. RLS policies not applied
2. Realtime not enabled on message_requests table

Solution:
1. Run SQL script again
2. Enable Realtime in Supabase Dashboard:
   - Go to Database → Replication
   - Enable for message_requests table
```

### Block Not Working
```
User still receiving messages after block

Possible causes:
1. Messages table RLS not updated
2. Function not granted to authenticated

Solution:
1. Drop old messages policies
2. Recreate with blocking checks
3. Grant execute on functions:
   GRANT EXECUTE ON FUNCTION is_user_blocked TO authenticated;
   GRANT EXECUTE ON FUNCTION can_message_user TO authenticated;
```

## 📱 UI Components

### Settings Screen
- **Privacy Section**: Messaging controls at top
- **Badge**: Shows pending request count
- **Block List**: Quick access to blocked contacts

### Message Requests Screen
- **Card Layout**: Each request in card format
- **User Info**: Profile photo, name, about, timestamp
- **Actions**: Accept (green) / Reject (red) buttons
- **Empty State**: Friendly message when no requests

### Blocked Users Screen
- **List View**: Shows all blocked users
- **Unblock Button**: Per-user unblock action
- **Timestamp**: Shows when blocked
- **Empty State**: Helpful message

### Chat Screen
- **Menu Option**: Block/Unblock in ⋮ menu
- **Dynamic**: Shows "Block" or "Unblock" based on status
- **Confirmation**: Dialog before blocking/unblocking

## 🚦 Feature Flags

Currently all features are enabled. To disable:

### Disable Message Requests
```dart
// In PrivacyService
Future<bool> canMessageUser(String receiverId) async {
  // Comment out privacy check
  return true; // Always allow
}
```

### Disable Blocking UI
```dart
// In ChatScreen appBar actions
// Comment out PopupMenuButton with block/unblock
```

## 📞 Support & Maintenance

### Adding New Privacy Options

1. **Add to Database**
   ```sql
   ALTER TABLE profiles ADD COLUMN new_setting TEXT;
   ```

2. **Update Model**
   ```dart
   // In UserModel
   final String newSetting;
   ```

3. **Add to Service**
   ```dart
   // In PrivacyService
   Future<bool> updateNewSetting(String value) async { }
   ```

4. **Update UI**
   ```dart
   // In SettingsScreen
   _buildNewSettingTile() { }
   ```

### Monitoring

```sql
-- Check block activity
SELECT COUNT(*) as total_blocks 
FROM blocked_users;

-- Check message request stats
SELECT status, COUNT(*) 
FROM message_requests 
GROUP BY status;

-- Most blocked users
SELECT blocked_id, COUNT(*) as block_count
FROM blocked_users
GROUP BY blocked_id
ORDER BY block_count DESC
LIMIT 10;
```

## ✅ Verification Checklist

Before deploying:

- [ ] SQL script executed successfully
- [ ] All RLS policies show in `pg_policies`
- [ ] Functions granted to authenticated role
- [ ] Privacy setting saves in database
- [ ] Message requests appear in UI
- [ ] Accept request opens chat
- [ ] Reject request blocks messaging
- [ ] Block user prevents messaging
- [ ] Unblock user restores messaging
- [ ] Blocked list shows blocked users
- [ ] Badge count updates in realtime
- [ ] Error messages are user-friendly
- [ ] UI is responsive on all screens

## 🎉 Conclusion

You now have a complete privacy and messaging control system similar to Discord and WhatsApp. Users can:

✅ Control who messages them
✅ Approve or reject message requests
✅ Block unwanted contacts
✅ Manage blocked users easily

All features are secure with Row Level Security and provide excellent UX with clear feedback and intuitive navigation.

---

**Need Help?** Check the troubleshooting section or review the SQL policies for detailed behavior.
