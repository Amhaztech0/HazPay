# Privacy Features - End-to-End Verification Guide

This guide provides a comprehensive checklist to verify all privacy features are working correctly.

## Prerequisites

✅ Database script executed (`db/PRIVACY_AND_BLOCKING.sql`)
✅ App hot restarted after database setup
✅ Two test user accounts available for testing

---

## Test Setup

### Create Test Users

You'll need **two accounts** to test properly:

- **User A** (Your main test account)
- **User B** (Secondary account - can use another device/emulator or browser)

### Database Verification (Run in Supabase SQL Editor)

```sql
-- 1. Verify tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('blocked_users', 'message_requests');

-- 2. Verify messaging_privacy column exists
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'profiles' 
  AND column_name = 'messaging_privacy';

-- 3. Verify helper functions exist
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name IN ('is_user_blocked', 'can_message_user', 'get_pending_requests_count');

-- 4. Check RLS policies on messages table
SELECT tablename, policyname 
FROM pg_policies 
WHERE tablename = 'messages';
```

**Expected Results:**
- 2 tables found (blocked_users, message_requests)
- messaging_privacy column exists with default 'everyone'
- 3 functions found
- Multiple RLS policies on messages table

---

## 1. Settings Screen Verification

### Test: Navigate to Settings

**Steps:**
1. Open app and login as User A
2. Tap the hamburger menu (☰)
3. Tap "Settings"

**Expected:**
- ✅ Settings screen opens (not "Coming soon!")
- ✅ See sections: Privacy, Account, Notifications, Storage, Help
- ✅ See Logout button at bottom

### Test: Settings Sections Present

**Verify all sections exist:**
- ✅ **Privacy** section at top
  - Who can message me
  - Message Requests (with badge if pending)
  - Blocked Contacts
- ✅ **Account** section
  - Change number
  - Delete account
- ✅ **Notifications** section
  - Message notifications
  - Group notifications
- ✅ **Storage and data** section
  - Storage usage
- ✅ **Help** section
  - Help
  - About

---

## 2. Messaging Privacy Settings

### Test: Change Privacy Setting to "Everyone"

**Steps:**
1. Settings → Privacy section
2. Tap "Who can message me"
3. Dialog opens with two options
4. Select "Everyone"

**Expected:**
- ✅ Dialog shows "Everyone" and "Approved users only"
- ✅ "Everyone" is selected (if default)
- ✅ Toast: "Everyone can now message you"
- ✅ Subtitle updates to "Everyone"

**Database Check:**
```sql
SELECT id, username, messaging_privacy 
FROM profiles 
WHERE id = 'USER_A_ID';
```
- ✅ `messaging_privacy` = 'everyone'

### Test: Change Privacy Setting to "Approved Only"

**Steps:**
1. Settings → "Who can message me"
2. Select "Approved users only"

**Expected:**
- ✅ Toast: "Only approved users can message you"
- ✅ Subtitle updates to "Only approved users"

**Database Check:**
```sql
SELECT id, username, messaging_privacy 
FROM profiles 
WHERE id = 'USER_A_ID';
```
- ✅ `messaging_privacy` = 'approved_only'

---

## 3. Message Request System (Discord-style)

### Test: Create Message Request

**Setup:**
1. User A: Set privacy to "Approved users only"
2. User B: Go to New Chat → Select User A
3. User B: Send a message (e.g., "Hey, can we chat?")

**Expected for User B:**
- ✅ Message appears to send
- ✅ No error shown

**Expected for User A:**
- ✅ Settings → Message Requests shows badge with "1"
- ✅ Tap Message Requests
- ✅ See card with User B's info
- ✅ Shows message "View message requests"
- ✅ See "Accept" and "Reject" buttons

**Database Check:**
```sql
SELECT sender_id, receiver_id, status, created_at
FROM message_requests
WHERE receiver_id = 'USER_A_ID' AND sender_id = 'USER_B_ID';
```
- ✅ Request exists with status = 'pending'

### Test: Accept Message Request

**Steps:**
1. User A: Settings → Message Requests
2. Tap "Accept" on User B's request

**Expected:**
- ✅ Opens chat with User B immediately
- ✅ Can see User B's first message
- ✅ Request disappears from list
- ✅ Badge count decreases (or badge disappears if no more requests)

**Database Check:**
```sql
SELECT status FROM message_requests
WHERE receiver_id = 'USER_A_ID' AND sender_id = 'USER_B_ID';
```
- ✅ Status = 'accepted'

**Test Continued Messaging:**
1. User B: Send another message to User A
2. User A: Should receive message without new request

**Expected:**
- ✅ Messages flow normally both ways
- ✅ No new message request created

### Test: Reject Message Request

**Setup:**
1. User A: Set privacy to "Approved only"
2. User C: Try to message User A (creates new request)

**Steps:**
1. User A: Settings → Message Requests
2. Tap "Reject" on User C's request

**Expected:**
- ✅ Confirmation dialog: "Are you sure you want to reject this message request?"
- ✅ After confirming, request disappears
- ✅ Badge count updates

**Database Check:**
```sql
SELECT status FROM message_requests
WHERE receiver_id = 'USER_A_ID' AND sender_id = 'USER_C_ID';
```
- ✅ Status = 'rejected'

**Test Messaging After Rejection:**
1. User C: Try sending another message to User A

**Expected:**
- ✅ Error message shown to User C
- ✅ Message does not send
- ✅ No new request created

---

## 4. Block/Unblock Functionality (WhatsApp-style)

### Test: Block User from Chat Screen

**Steps:**
1. User A: Open chat with User B
2. Tap menu (⋮) in app bar
3. Select "Block [User B's name]"
4. Confirm in dialog

**Expected:**
- ✅ Menu shows "Block" option
- ✅ Confirmation dialog appears
- ✅ After confirming: Toast "User blocked"
- ✅ Menu now shows "Unblock [User B's name]"

**Database Check:**
```sql
SELECT blocker_id, blocked_id, created_at
FROM blocked_users
WHERE blocker_id = 'USER_A_ID' AND blocked_id = 'USER_B_ID';
```
- ✅ Block record exists

### Test: Messaging Prevention After Blocking

**User B tries to message User A:**

**Expected:**
- ✅ Error message shown
- ✅ Message does not send
- ✅ Toast or snackbar: "Cannot send message"

**User A tries to message User B:**

**Expected:**
- ✅ Error message shown
- ✅ Message does not send
- ✅ Both directions blocked

### Test: Blocked Users List

**Steps:**
1. User A: Settings → Blocked Contacts

**Expected:**
- ✅ Shows list of blocked users
- ✅ User B appears in list with avatar and name
- ✅ Shows timestamp of when blocked
- ✅ "Unblock" button visible for each user

**Database Check:**
```sql
SELECT COUNT(*) as blocked_count
FROM blocked_users
WHERE blocker_id = 'USER_A_ID';
```
- ✅ Count matches UI list

### Test: Unblock User from Settings

**Steps:**
1. User A: Settings → Blocked Contacts
2. Find User B in list
3. Tap "Unblock" button
4. Confirm in dialog

**Expected:**
- ✅ Confirmation dialog appears
- ✅ After confirming: Toast "User unblocked"
- ✅ User B disappears from list
- ✅ If no more blocked users, shows "No blocked users" message

**Database Check:**
```sql
SELECT COUNT(*) FROM blocked_users
WHERE blocker_id = 'USER_A_ID' AND blocked_id = 'USER_B_ID';
```
- ✅ Count = 0 (record deleted)

### Test: Unblock User from Chat Screen

**Steps:**
1. User A: Open chat with User B (who is blocked)
2. Tap menu (⋮) in app bar
3. Select "Unblock [User B's name]"
4. Confirm in dialog

**Expected:**
- ✅ Menu shows "Unblock" option (not "Block")
- ✅ After unblocking: Toast "User unblocked"
- ✅ Menu switches to "Block" option

### Test: Messaging After Unblocking

**Both directions:**

**Expected:**
- ✅ Both User A and User B can send messages
- ✅ Messages deliver successfully
- ✅ No errors or restrictions

---

## 5. Combined Scenarios

### Test: Block User with Pending Message Request

**Setup:**
1. User A: Privacy set to "Approved only"
2. User D: Send message to User A (creates request)

**Steps:**
1. User A: Don't accept request yet
2. User A: Navigate to User D's profile or chat
3. Block User D

**Expected:**
- ✅ User D gets blocked successfully
- ✅ Message request remains in database but becomes irrelevant
- ✅ User D cannot message User A at all

**Database Check:**
```sql
SELECT * FROM message_requests WHERE sender_id = 'USER_D_ID' AND receiver_id = 'USER_A_ID';
SELECT * FROM blocked_users WHERE blocker_id = 'USER_A_ID' AND blocked_id = 'USER_D_ID';
```
- ✅ Both records exist
- ✅ Block takes precedence

### Test: Change Privacy After Accepting Requests

**Scenario:**
1. User A: Has "Approved only" privacy
2. User A: Accepts User B's request
3. User A: Changes privacy to "Everyone"

**Expected:**
- ✅ User B can still message User A (was already approved)
- ✅ New users can now message without requests
- ✅ Existing accepted requests remain valid

### Test: Change Privacy After Blocking

**Scenario:**
1. User A: Blocks User B
2. User A: Changes privacy from "Everyone" to "Approved only"

**Expected:**
- ✅ User B remains blocked (blocking is independent)
- ✅ User B cannot send message request while blocked
- ✅ After unblocking, User B would need to send message request

---

## 6. UI/UX Verification

### Test: Badge Count Accuracy

**Steps:**
1. User A: Have 0 pending requests
2. Check Settings screen

**Expected:**
- ✅ No badge shown on "Message Requests"

**Steps:**
1. Create 3 pending message requests
2. Check Settings screen

**Expected:**
- ✅ Badge shows "3"
- ✅ Subtitle says "3 pending requests"

**Steps:**
1. Accept 1 request
2. Return to Settings

**Expected:**
- ✅ Badge updates to "2"
- ✅ Subtitle says "2 pending requests"

### Test: Empty States

**No Message Requests:**
- ✅ Shows message: "No pending message requests"
- ✅ Shows icon and helpful text

**No Blocked Users:**
- ✅ Shows message: "You haven't blocked anyone"
- ✅ Shows icon and helpful text

### Test: Loading States

**Settings Screen:**
- ✅ Shows loading spinner on first load
- ✅ Data loads and displays correctly

**Message Requests Screen:**
- ✅ Shows loading indicator while fetching
- ✅ Transitions smoothly to content

**Blocked Users Screen:**
- ✅ Shows loading indicator
- ✅ Displays list after loading

### Test: Confirmation Dialogs

**All these actions should show confirmation:**
- ✅ Blocking a user
- ✅ Unblocking a user
- ✅ Rejecting a message request
- ✅ Logout
- ✅ Delete account (shows dialog but disabled)

### Test: Toast Notifications

**Verify toasts appear for:**
- ✅ Privacy setting changed
- ✅ User blocked
- ✅ User unblocked
- ✅ Message request accepted
- ✅ Message request rejected

---

## 7. Performance & Error Handling

### Test: Network Errors

**Steps:**
1. Turn off internet/wifi
2. Try to change privacy setting
3. Try to block user
4. Try to load message requests

**Expected:**
- ✅ Error message shown to user
- ✅ App doesn't crash
- ✅ Can retry when connection restored

### Test: Rapid Actions

**Steps:**
1. Quickly tap block/unblock multiple times
2. Rapidly accept multiple message requests

**Expected:**
- ✅ No duplicate operations
- ✅ UI updates correctly
- ✅ Database stays consistent

### Test: Concurrent Blocking

**Scenario:**
1. User A blocks User B
2. Simultaneously, User B blocks User A

**Expected:**
- ✅ Both blocks succeed
- ✅ Both users see each other in blocked list
- ✅ Neither can message the other

---

## 8. Regression Testing

### Test: Existing Features Still Work

**Chats:**
- ✅ Can create new chats with unblocked users
- ✅ Can send messages normally
- ✅ Can receive messages normally
- ✅ Voice notes work
- ✅ Image/file sharing works

**Status:**
- ✅ Can post status updates
- ✅ Can view others' statuses
- ✅ Privacy settings don't affect status

**Profile:**
- ✅ Can view own profile
- ✅ Can view others' profiles
- ✅ Can edit profile information

**Servers:**
- ✅ Server messaging unaffected by privacy
- ✅ Can create/join servers

---

## 9. Security Verification

### Test: RLS Policy Enforcement

**Direct database queries (as User B attempting to bypass UI):**

```sql
-- Try to delete User A's block record (should fail)
DELETE FROM blocked_users 
WHERE blocker_id = 'USER_A_ID' AND blocked_id = 'USER_B_ID';

-- Try to accept message request on User A's behalf (should fail)
UPDATE message_requests 
SET status = 'accepted' 
WHERE receiver_id = 'USER_A_ID';

-- Try to change User A's privacy setting (should fail)
UPDATE profiles 
SET messaging_privacy = 'everyone' 
WHERE id = 'USER_A_ID';
```

**Expected:**
- ✅ All operations fail with RLS policy violation
- ✅ Error message about insufficient permissions

### Test: SQL Function Security

**Test functions respect user context:**

```sql
-- As User B, check if User A blocked them
SELECT is_user_blocked('USER_A_ID');

-- As User B, check if can message User A
SELECT can_message_user('USER_A_ID');
```

**Expected:**
- ✅ Functions return correct results
- ✅ Only return data for authenticated user

---

## 10. Quick Smoke Test (5 Minutes)

**Run this quick test to verify everything works:**

1. ✅ Navigate to Settings from drawer
2. ✅ Change messaging privacy to "Approved only"
3. ✅ From another account, send a message (creates request)
4. ✅ Accept the message request
5. ✅ Block the user from chat screen
6. ✅ Verify they appear in Blocked Contacts
7. ✅ Unblock the user
8. ✅ Send a message successfully
9. ✅ Change privacy back to "Everyone"
10. ✅ Verify new users can message without requests

---

## Troubleshooting Common Issues

### Badge Count Not Updating

**Check:**
```sql
SELECT get_pending_requests_count();
```

**Solution:**
- Refresh Settings screen (pull down)
- Hot restart app
- Verify Realtime is enabled on message_requests table

### Block Not Working

**Check:**
```sql
SELECT * FROM blocked_users WHERE blocker_id = 'USER_ID';
SELECT policyname FROM pg_policies WHERE tablename = 'messages';
```

**Solution:**
- Verify RLS policies on messages table
- Check helper function exists: `is_user_blocked()`
- Restart app after database changes

### Message Request Not Created

**Check:**
```sql
SELECT * FROM message_requests WHERE sender_id = 'USER_ID' OR receiver_id = 'USER_ID';
```

**Solution:**
- Verify receiver has "approved_only" privacy
- Check RLS policies allow insert
- Verify PrivacyService.createMessageRequest() is being called

### Privacy Setting Not Saving

**Check:**
```sql
SELECT id, messaging_privacy FROM profiles WHERE id = 'USER_ID';
```

**Solution:**
- Verify column exists with correct name
- Check RLS policies allow update
- Verify no typos in column name

---

## Success Criteria

All features pass when:

✅ **Settings Navigation**
- Settings screen accessible from drawer
- All sections display correctly

✅ **Privacy Settings**
- Can change between "Everyone" and "Approved only"
- Setting persists across app restarts
- Database reflects the setting

✅ **Message Requests**
- Requests created for first message when privacy is "Approved only"
- Badge shows accurate count
- Can accept requests (opens chat, allows future messages)
- Can reject requests (prevents messaging)

✅ **Blocking**
- Can block users from chat screen
- Can view blocked users in Settings
- Can unblock from both Settings and chat screen
- Blocking prevents all messaging (bidirectional)
- Block status persists

✅ **Security**
- RLS policies prevent unauthorized access
- Helper functions respect user context
- Direct database manipulation fails appropriately

✅ **UX**
- Loading states show appropriately
- Toast messages provide feedback
- Confirmation dialogs prevent mistakes
- Empty states guide users
- Badge counts update in real-time

---

## Test Results Template

Copy and fill this out after testing:

```
Test Date: ___________
Tester: ___________
App Version: 1.0.0

1. Settings Navigation: ☐ Pass ☐ Fail
2. Privacy Settings: ☐ Pass ☐ Fail
3. Message Requests: ☐ Pass ☐ Fail
4. Blocking: ☐ Pass ☐ Fail
5. UI/UX: ☐ Pass ☐ Fail
6. Security: ☐ Pass ☐ Fail

Issues Found:
- 
- 

Notes:
- 
```

---

## Automated Test Execution

You can also run the integration tests:

```bash
# Run all tests
flutter test

# Run only integration tests
flutter test test/integration/

# Run settings navigation test specifically
flutter test test/integration/settings_navigation_test.dart

# Run with verbose output
flutter test --verbose
```

**Note:** Integration tests verify UI navigation and components but don't test actual Supabase interactions. Manual testing is still required for full end-to-end verification with real database operations.

---

## Next Steps After Verification

Once all tests pass:

1. ✅ Document any issues found
2. ✅ Fix critical bugs before production
3. ✅ Consider enabling Realtime on `message_requests` table for instant badge updates
4. ✅ Monitor error logs after deployment
5. ✅ Collect user feedback on UX
6. ✅ Plan additional features (mute, report, etc.)

---

**Status:** Ready for comprehensive testing
**Estimated Test Time:** 30-45 minutes for full manual testing
**Quick Smoke Test Time:** 5 minutes
