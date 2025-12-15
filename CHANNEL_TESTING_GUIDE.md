# Channel System Testing Guide

## Test Environment Setup

### Prerequisites
- ZinChat app running on Android device/emulator
- Supabase project connected with channel tables created
- At least 2 test user accounts (for multi-user testing)
- One user should be a server owner/admin
- One user should be a regular member

---

## Test Scenarios

### TEST 1: Basic Channel Creation ✅
**Goal**: Verify admin can create channels

**Steps**:
1. Open ZinChat and log in as server OWNER
2. Open a server (or create new one)
3. Click menu icon (3 dots) in top right
4. Select **"Manage Channels"**
5. Click **"New Channel"** FAB button
6. Fill in:
   - Channel name: `general`
   - Description: `General discussion`
   - Type: `Text`
7. Click **Create**

**Expected Result**:
- Dialog closes
- Green SnackBar shows: "Channel 'general' created!"
- You return to channel management screen
- New channel appears in list with tag icon (🏷️)

---

### TEST 2: Channel Dropdown Appears ✅
**Goal**: Verify channel selector in chat

**Steps**:
1. From server chat, look at AppBar (header)
2. Below server name, check for channel dropdown

**Expected Result**:
- Channel dropdown shows "general" channel
- Icon displays correctly (🏷️ for text)
- Clicking dropdown shows channel name

---

### TEST 3: Send Message to Channel ✅
**Goal**: Verify messages are tagged with channel_id

**Steps**:
1. In server chat with "general" channel selected
2. Type: "Hello, this is test message 1"
3. Send message
4. Wait 2 seconds
5. Message should appear in chat

**Expected Result**:
- Message appears below as sent
- User sees their own message with avatar
- Message shows in left-aligned Discord style

---

### TEST 4: Create Additional Channels ✅
**Goal**: Verify multiple channels work

**Steps**:
1. Go back to "Manage Channels"
2. Create second channel:
   - Name: `random`
   - Description: `Off-topic`
   - Type: `Text`
3. Create third channel:
   - Name: `announcements`
   - Description: `Important news`
   - Type: `Announcements` (🔔 icon)

**Expected Result**:
- All three channels appear in management screen
- Dropdown now shows 3 channels
- Each has correct icon

---

### TEST 5: Channel Switching & Message Filtering ✅
**Goal**: Verify messages filter correctly by channel

**Steps**:
1. In chat, select "random" from dropdown
2. Type: "This message is in random channel"
3. Send it
4. Switch to "general" from dropdown
5. Observe: Original message should NOT appear
6. Send: "Back in general"
7. Switch to "random"
8. Observe: Original "random" message shows, "Back in general" doesn't

**Expected Result**:
- Messages appear/disappear based on selected channel
- Switching channels instantly filters the message list
- Previous channel messages stay in their channel
- Clear separation between channels

---

### TEST 6: Edit Channel Details ✅
**Goal**: Verify admin can edit channels

**Steps**:
1. Go to "Manage Channels"
2. Long-press (or click menu) on "general" channel
3. Select **Edit**
4. Change description to: "General chat for everyone"
5. Change name to: "general-chat"
6. Click **Save**

**Expected Result**:
- Green SnackBar: "Channel updated!"
- Channel name changes in management screen
- Channel dropdown updates to show new name
- Description updates

---

### TEST 7: Delete Channel ✅
**Goal**: Verify channel deletion

**Steps**:
1. In "Manage Channels"
2. Click menu on "random" channel
3. Select **Delete**
4. Confirm in dialog

**Expected Result**:
- Orange SnackBar: "Channel deleted"
- "random" disappears from management list
- Dropdown no longer shows "random" option
- If "random" was selected, dropdown switches to next available

---

### TEST 8: Non-Admin Cannot Manage ✅
**Goal**: Verify permission restrictions

**Steps**:
1. Log out and log in as REGULAR MEMBER user
2. Open same server
3. Open "Manage Channels"

**Expected Result**:
- Channel list shows all channels (READ access ✅)
- NO **"New Channel"** FAB button
- NO Edit/Delete menu options
- Message: "You must be admin to manage channels" (or similar, if UI shows)

**Note**: UI restrictions are client-side. Database RLS is the true enforcer.

---

### TEST 9: Channel Dropdown Works for Members ✅
**Goal**: Verify all users can switch channels

**Steps**:
1. As REGULAR MEMBER, open server chat
2. Click channel dropdown
3. Select each channel

**Expected Result**:
- Dropdown works for all users
- Can switch between channels
- Messages filter correctly
- Can send messages in any channel (no message filtering)

---

### TEST 10: Real-Time Updates ✅
**Goal**: Verify changes sync in real-time

**Steps**:
1. Open app on DEVICE A (Admin)
2. Open app on DEVICE B (Member) - same server
3. On DEVICE A, create new channel "test-channel"
4. Look at DEVICE B immediately

**Expected Result**:
- DEVICE B dropdown updates automatically
- New channel appears without refresh
- Both devices show same channel list

---

### TEST 11: Real-Time Messages ✅
**Goal**: Verify messages sync across users

**Steps**:
1. DEVICE A: Admin in "general" channel
2. DEVICE B: Member in "general" channel (same server)
3. DEVICE A: Send message "Hello from admin"
4. Check DEVICE B

**Expected Result**:
- Message appears on DEVICE B instantly
- Sender avatar, name, and timestamp visible
- Correct Discord-style layout

---

### TEST 12: Voice Channel Creation ✅
**Goal**: Verify voice channel type

**Steps**:
1. Go to "Manage Channels"
2. Create channel:
   - Name: `voice-chat`
   - Type: `Voice Channel`
3. Check dropdown

**Expected Result**:
- Channel appears with volume icon (🔊)
- Can send messages in voice channel (for now)
- Icon distinguishes it from text channels

---

### TEST 13: Announcement Channel ✅
**Goal**: Verify announcement channel type

**Steps**:
1. Create channel:
   - Name: `updates`
   - Type: `Announcements`
2. Check dropdown and management screen

**Expected Result**:
- Channel shows bell icon (🔔)
- Marked as "announcements" type
- Messages send normally (special features for future)

---

### TEST 14: Message Persistence ✅
**Goal**: Verify messages saved correctly with channel_id

**Steps**:
1. In "general" channel, send: "Test message A"
2. Close app completely
3. Reopen app
4. Open server, select "general"

**Expected Result**:
- "Test message A" still visible
- Message not lost
- Channel still selected

---

### TEST 15: Channel Position/Ordering ✅
**Goal**: Verify channels maintain order

**Steps**:
1. Go to "Manage Channels"
2. Create 3 channels in this order:
   - first
   - second
   - third
3. Check dropdown order

**Expected Result**:
- Dropdown shows channels in creation order (position 0, 1, 2)
- Order matches management screen
- Consistent across sessions

---

## Known Limitations (Future Features)

❌ Drag-to-reorder channels (position field exists, UI not implemented)
❌ Voice channel audio (placeholder type only)
❌ Private channels (RLS foundation ready)
❌ Channel permissions per user
❌ Channel pinned messages
❌ Channel topics/banners
❌ Archive old channels

---

## Debugging Tips

### If dropdown shows "No channels":
- Check that `server_channels` table has data in Supabase
- Verify user is member of server
- Check RLS policies allow SELECT

### If messages don't filter by channel:
- Open browser DevTools (if web) or logcat (if mobile)
- Look for `_selectedChannelId` value
- Verify messages have `channel_id` in database

### If channel creation fails:
- Check "server-media" bucket exists (for uploads)
- Verify user has admin role in server_members
- Check Supabase logs for RLS violations

### To Test Database Directly:
1. Go to Supabase Dashboard → SQL Editor
2. Run: `SELECT * FROM server_channels;`
3. Run: `SELECT id, server_id, channel_id, content FROM server_messages LIMIT 10;`
4. Verify channel_id is NOT NULL for new messages

---

## Success Criteria

✅ All 15 tests pass
✅ No compilation errors
✅ Dropdown appears in chat header
✅ Can create/edit/delete channels (as admin)
✅ Messages filter by channel correctly
✅ Real-time updates work across devices
✅ Non-admins cannot modify channels (UI + RLS)
✅ Message persistence verified
✅ No data loss on app restart

---

## Test Report Template

```
Test Date: [DATE]
Tester: [NAME]
Device: [DEVICE MODEL]
Build Version: [VERSION]

Test Results:
[ ] TEST 1: Channel Creation - PASS/FAIL - Notes: ___
[ ] TEST 2: Dropdown Appears - PASS/FAIL - Notes: ___
[ ] TEST 3: Message to Channel - PASS/FAIL - Notes: ___
[ ] TEST 4: Multiple Channels - PASS/FAIL - Notes: ___
[ ] TEST 5: Channel Switching - PASS/FAIL - Notes: ___
[ ] TEST 6: Edit Channel - PASS/FAIL - Notes: ___
[ ] TEST 7: Delete Channel - PASS/FAIL - Notes: ___
[ ] TEST 8: Non-Admin Access - PASS/FAIL - Notes: ___
[ ] TEST 9: Member Dropdown - PASS/FAIL - Notes: ___
[ ] TEST 10: Real-Time Updates - PASS/FAIL - Notes: ___
[ ] TEST 11: Real-Time Messages - PASS/FAIL - Notes: ___
[ ] TEST 12: Voice Channel - PASS/FAIL - Notes: ___
[ ] TEST 13: Announcement Channel - PASS/FAIL - Notes: ___
[ ] TEST 14: Persistence - PASS/FAIL - Notes: ___
[ ] TEST 15: Channel Order - PASS/FAIL - Notes: ___

Overall Result: PASS / FAIL
Issues Found: [List any issues]
Recommendations: [Future improvements]
```
