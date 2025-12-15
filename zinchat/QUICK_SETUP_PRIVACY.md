# Quick Setup: Privacy Controls & Blocking

## 🚀 Setup Steps (5 minutes)

### 1. Run Database Script
```bash
# In Supabase SQL Editor, run:
db/PRIVACY_AND_BLOCKING.sql
```

### 2. Enable Realtime (Optional but Recommended)
```
Supabase Dashboard → Database → Replication
Enable for: message_requests
```

### 3. Test the Features
```bash
# Hot restart your app
flutter run
```

## 🎯 What You Get

### In Settings Screen:
1. **Who can message me** - Toggle between Everyone / Approved only
2. **Message Requests** - View and manage pending requests (with badge)
3. **Blocked Contacts** - View and unblock users

### In Chat Screen:
1. **Block/Unblock Menu** - Tap ⋮ in top-right
2. **Dynamic Status** - Shows Block or Unblock based on current state

### Moved to Settings:
- Theme selection (from Profile page)
- Chat wallpaper (from Profile page)
- Better organization and UX

## 🧪 Quick Test

### Test Message Requests (Discord-style)
1. Create two test users
2. User A: Settings → Who can message me → "Approved only"
3. User B: Send message to User A
4. User A: Settings → Message Requests → Accept or Reject

### Test Blocking (WhatsApp-style)
1. Open any chat
2. Tap ⋮ → Block User → Confirm
3. Try sending message → Should fail
4. Settings → Blocked Contacts → Unblock

## 📋 Files Added
- `db/PRIVACY_AND_BLOCKING.sql` - Database setup
- `lib/models/message_request_model.dart` - Message request model
- `lib/models/blocked_user_model.dart` - Blocked user model
- `lib/services/privacy_service.dart` - Privacy operations service
- `lib/screens/settings/blocked_users_screen.dart` - Blocked users UI
- `lib/screens/settings/message_requests_screen.dart` - Message requests UI
- `PRIVACY_AND_BLOCKING_GUIDE.md` - Full documentation

## 📝 Files Modified
- `lib/models/user.dart` - Added `messagingPrivacy` field
- `lib/services/chat_service.dart` - Added privacy checks before sending
- `lib/screens/chat/chat_screen.dart` - Added block/unblock menu
- `lib/screens/settings/settings_screen.dart` - Enhanced with privacy controls

## ⚠️ Important Notes

1. **Database First**: Must run SQL script before using features
2. **Realtime Optional**: Works without Realtime but updates may delay
3. **RLS Protected**: All privacy operations secured by Row Level Security
4. **Backwards Compatible**: Existing users default to "everyone" privacy

## 🐛 Troubleshooting

### Can't send messages
- Check if blocked: Settings → Blocked Contacts
- Check privacy: Other user may have "Approved only" setting
- Check requests: Settings → Message Requests

### Requests not showing
- Verify SQL script ran successfully
- Check RLS policies: `SELECT * FROM pg_policies WHERE tablename = 'message_requests'`

### Block not working
- Check messages RLS policies were updated
- Grant function permissions: `GRANT EXECUTE ON FUNCTION is_user_blocked TO authenticated`

## 📞 Need More Help?

See `PRIVACY_AND_BLOCKING_GUIDE.md` for:
- Detailed architecture
- Database schema explanations
- User flow diagrams
- Advanced troubleshooting
- Security best practices

---

## ✅ Quick Verification

After setup, verify:
```sql
-- In Supabase SQL Editor:

-- 1. Check tables exist
SELECT tablename FROM pg_tables 
WHERE tablename IN ('blocked_users', 'message_requests');

-- 2. Check functions exist
SELECT proname FROM pg_proc 
WHERE proname IN ('is_user_blocked', 'can_message_user');

-- 3. Check RLS enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('blocked_users', 'message_requests');
```

All queries should return results. If any fail, re-run the SQL script.

---

**Ready to go!** 🎉 Your app now has enterprise-level privacy controls.
