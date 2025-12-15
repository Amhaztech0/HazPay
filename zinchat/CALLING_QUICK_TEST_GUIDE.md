# 🧪 Calling System - Quick Test Guide

## Before Testing

### ✅ Prerequisites Checklist
- [ ] Flutter dependencies installed (`flutter pub get` done)
- [ ] Database schema deployed to Supabase
- [ ] Edge function deployed to Supabase (`Exit Code: 0`)
- [ ] 100ms room created (test-room)
- [ ] 2+ test devices/emulators available
- [ ] Permissions granted (Camera, Microphone)

---

## 🔴 Test 1: 1-on-1 Audio Call (5 mins)

### Setup
1. Install app on 2 devices
2. Login with 2 different accounts on each device
3. Open Direct Messages and create a chat between User A and User B

### Test Steps

**On User A's device:**
1. Open chat with User B
2. Tap ☎️ (audio call icon) in top-right
3. DirectCallScreen should open
4. Wait for connection (should show "Connecting..." then peers)

**On User B's device:**
1. Should see incoming call notification
2. Tap the notification or dialog to answer
3. After accepting, audio connection should establish

**Verification:**
- [ ] Both users hear each other
- [ ] Mute button works (tap 🔊 icon, audio stops)
- [ ] Audio unmutes (tap 🔊 again)
- [ ] End call button (red 📞) stops the call
- [ ] Call is logged in Supabase `calls` table

### Expected Behavior
```
Call created in DB
Offer sent via Realtime
User B receives notification
User B answers
Answer sent back
ICE candidates exchanged
Peer connection established
Audio flows
```

---

## 📹 Test 2: 1-on-1 Video Call (5 mins)

### Setup
- Same 2 devices from Test 1
- Same chat window

### Test Steps

**On User A's device:**
1. Tap 📹 (video call icon) in top-right
2. DirectCallScreen should open with local video preview
3. Wait for connection

**On User B's device:**
1. Should see incoming call notification
2. Accept the call
3. Video connection should establish

**Verification:**
- [ ] User A sees their own video preview
- [ ] User B's video appears on User A's screen
- [ ] User A's video appears on User B's screen
- [ ] Camera switch button (🔄) works
- [ ] Video toggle button (📹) works
- [ ] Mute button (🔊) still works
- [ ] End call button stops video and call

### Expected Behavior
```
Similar to audio call, but with RTCVideoView widgets
showing video streams from both peers
```

---

## 👥 Test 3: Group Call (Audio) (8 mins)

### Setup
1. Create a server in the app (if not existing)
2. Create a channel in that server
3. Add User A, User B, and User C to the server
4. Open the server chat

### Test Steps

**On User A's device:**
1. In server chat, tap ☎️ (audio call icon)
2. Should join 100ms room
3. Should see "Joined call" indication

**On User B's device:**
1. Should see incoming call notification
2. Tap to answer/join
3. Should see User A in the call

**On User C's device:**
1. Should see incoming call notification
2. Tap to join
3. Should see User A and User B

**Verification:**
- [ ] All 3 users can hear each other
- [ ] Participant list shows all users
- [ ] Mute works for each user individually
- [ ] Can leave call (red 📞 button)
- [ ] Others can still see remaining participants

### Expected Behavior
```
User A creates call → joins 100ms room with JWT token
User B gets notification → joins same room
User C gets notification → joins same room
All users' audio streams are mixed by 100ms
Everyone can communicate
```

---

## 📹 Test 4: Group Call (Video) (8 mins)

### Setup
- Same server and channel from Test 3
- 3 devices with 3 different users

### Test Steps

**On User A's device:**
1. In server chat, tap 📹 (video call icon)
2. Video should show and connect

**On User B & C's devices:**
1. Accept notifications
2. Video grid should show all 3 participants

**Verification:**
- [ ] All users see video grid with 3 videos
- [ ] Participant names visible under each video
- [ ] Camera switch works
- [ ] Video toggle works
- [ ] Mute works independently per user
- [ ] Leave call button works
- [ ] Grid updates when someone leaves

### Expected Behavior
```
100ms manages video streaming for multiple participants
Each user sees a grid of participant videos
Controls work independently per user
```

---

## 🚨 Edge Cases to Test

### Test 5: Call Rejection (3 mins)
1. User A initiates call to User B
2. User B rejects the call (swipe away notification or decline button)
3. Verify: User A's call screen closes, shows "Call rejected"

### Test 6: No Answer / Timeout (3 mins)
1. User A initiates call to User B
2. User B doesn't answer for 30 seconds
3. Verify: Call auto-closes on User A's end

### Test 7: Network Reconnection (3 mins)
1. Start 1-on-1 call between User A and B
2. Kill WiFi on User A's device
3. Re-enable WiFi after 5 seconds
4. Verify: Call reconnects automatically

### Test 8: Background/Resume (3 mins)
1. During active call, press home button on User A's device
2. App goes to background
3. Press app again to resume
4. Verify: Call continues, audio/video resumes

### Test 9: Call Records in Database (2 mins)
1. Complete a call
2. Open Supabase Dashboard > SQL Editor
3. Run: `SELECT * FROM calls ORDER BY created_at DESC LIMIT 1;`
4. Verify: Latest call record shows correct participants, duration, call_type

---

## ✅ Success Criteria

### All Tests Pass When:
- ✅ 1-on-1 calls work (audio & video)
- ✅ Group calls work (audio & video)
- ✅ Call controls work (mute, camera, etc.)
- ✅ Notifications work (incoming calls shown)
- ✅ Call records saved to database
- ✅ Can switch between calls/chats
- ✅ No crashes or errors

### Known Limitations (OK to skip):
- Screen sharing in group calls (100ms free tier)
- Recording group calls (100ms paid feature)
- More than 30 group participants (100ms plan limit)
- 1-on-1 calls through some corporate firewalls (TURN server limitation)

---

## 🐛 Common Issues During Testing

### Issue: "No incoming call notification"
**Solution:**
1. Check notification settings on device
2. Verify CallManager is initialized in main.dart
3. Check Firebase/push notifications are setup
4. Try force-closing and reopening app

### Issue: "No peer connection established"
**Solution:**
1. Check network connectivity (cellular vs WiFi)
2. Verify TURN servers are accessible (check firewall)
3. Check both users have valid camera/mic permissions
4. Try restarting app on both devices

### Issue: "100ms room join fails"
**Solution:**
1. Verify room exists in 100ms dashboard
2. Check room code is correct in code
3. Verify edge function returns valid JWT token
4. Check HMS credentials are correct

### Issue: "Call screen shows but no video"
**Solution:**
1. Grant camera permission on device
2. Check device doesn't have camera disabled
3. Try switching camera (tap 🔄 button)
4. Restart app

### Issue: "Audio/video is very laggy"
**Solution:**
1. Check network bandwidth (try WiFi if on cellular)
2. Reduce video quality (lower resolution)
3. Close other bandwidth-intensive apps
4. Try peer with better network connection

---

## 📊 Performance Expectations

### 1-on-1 Calls
- Connection time: 2-5 seconds
- Latency: 100-500ms typically
- Bandwidth: ~1-2 Mbps audio, ~2-4 Mbps video
- Works over cellular (4G+) and WiFi

### Group Calls (3 participants)
- Connection time: 3-7 seconds
- Latency: 100-500ms
- Bandwidth: ~1 Mbps per participant
- 100ms SDK handles all video mixing

---

## 🎬 Test Session Example

```
TIME    EVENT
0:00    Start app, login User A
0:05    Login User B on second device
0:10    Open chat between A and B
0:15    User A taps audio call icon
0:20    User B sees notification, accepts
0:25    ✅ Audio call active, test mute (works!)
0:30    User A ends call ✅
0:35    User A taps video call icon
0:40    User B accepts video call
0:45    ✅ Video shows both users, test camera switch
0:50    End video call ✅
0:55    Login User C on third device
1:00    User A starts group call in server
1:05    Users B and C accept
1:10    ✅ Group call with 3 users, test mute per user
1:15    All users end call ✅
```

**If you get through this without errors: YOU'RE DONE! 🎉**

---

## 📞 Test Results Template

```
TEST 1: 1-on-1 Audio Call
Status: [ ] PASS [ ] FAIL
Issues: _______________

TEST 2: 1-on-1 Video Call
Status: [ ] PASS [ ] FAIL
Issues: _______________

TEST 3: Group Audio Call
Status: [ ] PASS [ ] FAIL
Issues: _______________

TEST 4: Group Video Call
Status: [ ] PASS [ ] FAIL
Issues: _______________

TEST 5: Call Rejection
Status: [ ] PASS [ ] FAIL
Issues: _______________

Overall: [ ] READY FOR PRODUCTION [ ] NEEDS FIXES
```

---

**Estimated Total Test Time: 40-50 minutes**

Good luck! 📞🎉
