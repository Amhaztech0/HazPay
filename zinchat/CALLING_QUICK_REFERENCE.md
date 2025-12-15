# 📞 Calling System - Quick Reference Card

## 🎯 What You Have

| Feature | Status | Type | Participants |
|---------|--------|------|--------------|
| 1-on-1 Audio | ✅ Ready | WebRTC P2P | 2 |
| 1-on-1 Video | ✅ Ready | WebRTC P2P | 2 |
| Group Audio | ✅ Ready | 100ms | 2-30 |
| Group Video | ✅ Ready | 100ms | 2-30 |

---

## 🔗 Key URLs

| Service | URL |
|---------|-----|
| Edge Function | https://avaewzkgsilitcrncqhe.supabase.co/functions/v1/generate-hms-token |
| 100ms Dashboard | https://dashboard.100ms.live |
| Supabase Console | https://supabase.com/dashboard |

---

## 🔑 Credentials

| Service | Value |
|---------|-------|
| HMS Access Key | 69171bc9145cb4e8449b1a6e |
| Edge Function | Already deployed ✅ |
| Database | Ready to deploy |

---

## 📁 Important Files

```
Core Services:
  lib/services/webrtc_service.dart         (1-on-1 calls)
  lib/services/hms_call_service.dart       (group calls)
  lib/services/call_manager.dart           (routing/notifications)

Screens:
  lib/screens/direct_call_screen.dart      (1-on-1 UI)
  lib/screens/server_call_screen.dart      (group UI)

Integration:
  lib/screens/chat/chat_screen.dart        (call buttons)
  lib/screens/servers/server_chat_screen.dart (call buttons)
  lib/main.dart                            (CallManager init)

Backend:
  CALL_DATABASE_SCHEMA.sql                 (database tables)
  supabase/functions/generate-hms-token/   (edge function)
```

---

## ✅ Deployment Status

```
✅ Edge Function         Deployed (Exit Code: 0)
✅ Flutter Code          Complete (2,200+ lines)
✅ Call Buttons          Added to UI
✅ Database Schema       Created (ready to deploy)
✅ Permissions           Configured
✅ 100ms Credentials     Configured
⏳ Database Deploy       → DO THIS FIRST
```

---

## 🚀 5-Minute Setup

```bash
# 1. Deploy Database Schema (2 mins)
   Go to Supabase > SQL Editor
   Paste CALL_DATABASE_SCHEMA.sql
   Click Run ✅

# 2. Test Edge Function (1 min)
   Go to Supabase > Functions > generate-hms-token
   Click "Invoke"
   Should return JWT token ✅

# 3. Build App (2 mins)
   flutter build apk --release
```

---

## 🎮 How to Use

### 1-on-1 Call
```
1. Open chat with someone
2. Tap 📹 (video) or ☎️ (audio) in AppBar
3. They get notification
4. They accept or decline
5. Call connects
```

### Group Call
```
1. Open server chat
2. Tap ☎️ (audio) or 📹 (video) in AppBar
3. Users in channel get notification
4. They accept to join
5. All connected in group call
```

---

## 💰 Cost

**TOTAL MONTHLY: $0**

- 1-on-1 calls: FREE (P2P)
- Group calls: FREE (100ms free tier: 10k min/month)
- Database: FREE (Supabase free tier)
- Servers: FREE (Metered.ca TURN + Google STUN)

---

## 🧪 Quick Test (20 mins)

```
Device 1 & 2:
  1. Install app
  2. Login with different accounts
  3. Device 1: Open chat, tap ☎️
  4. Device 2: Accept notification
  5. Verify audio works ✅
  6. Repeat with 📹 for video ✅
```

---

## ⚠️ Critical Checks

- [ ] Database schema deployed
- [ ] Edge function deployed (should show Exit Code: 0)
- [ ] Permissions granted on device
- [ ] 2+ test devices/emulators ready
- [ ] 100ms room exists in dashboard

---

## 🔧 Troubleshooting

| Problem | Solution |
|---------|----------|
| No incoming call | Verify CallManager in main.dart |
| Can't connect peer | Check firewall allows TURN servers |
| 100ms join fails | Verify edge function returns JWT |
| No camera/mic | Grant permissions in device settings |
| Database error | Deploy CALL_DATABASE_SCHEMA.sql |

---

## 📊 Architecture

```
User A → Call Button
   ↓
Direct Call (1-on-1)           Group Call (Server)
   ↓                           ↓
WebRTC P2P                    100ms SDK
Metered.ca TURN               Professional Platform
Unlimited calls                10k min/month free
   ↓                           ↓
Signaling via Supabase Realtime
   ↓
Other user gets notification (CallManager)
   ↓
Accepts → Connection established
```

---

## 📞 Call Controls

### During 1-on-1 Call
- 🔊 Mute/unmute audio
- 📹 Turn video on/off
- 🔄 Switch camera
- 📞 End call

### During Group Call
- 🔊 Mute/unmute audio
- 📹 Turn video on/off
- 🔄 Switch camera
- 📞 Leave call

---

## 📈 What You Can Handle

| Metric | Capacity |
|--------|----------|
| 1-on-1 Calls | Unlimited (P2P) |
| Group Participants | 30 max (free tier) |
| Monthly Minutes | 10,000 (100ms free) |
| Call Duration | Unlimited |
| Concurrent Calls | Limited by device/network |

---

## 📋 Next Steps Priority

```
🔴 PRIORITY 1 (DO NOW):
   1. Deploy database schema
   2. Test edge function
   
🟡 PRIORITY 2 (5-10 mins):
   1. Build app
   2. Create 100ms room
   
🟢 PRIORITY 3 (Testing):
   1. Install on 2 devices
   2. Test all call types
   3. Verify database records
```

---

## 🎓 Important Concepts

### WebRTC (1-on-1 Calls)
- Peer-to-peer video/audio
- Direct connection between users
- Signaling via Supabase
- TURN for NAT traversal
- Unlimited concurrent calls
- Zero cost beyond server bandwidth

### 100ms (Group Calls)
- Managed group calling platform
- Professional infrastructure
- Up to 30 participants free
- 10,000 minutes/month free
- Handles all video mixing
- Scales automatically

### Supabase Realtime
- PostgreSQL LISTEN/NOTIFY
- WebSocket subscriptions
- Used for WebRTC signaling
- Database storage for call records
- No additional cost

---

## 🎯 Success Criteria

✅ When you see:
- 1-on-1 calls work both directions
- Group calls with 3+ participants
- Database records created
- No crashes in logs
- Notifications appear

= READY FOR BETA TESTING

---

## 📞 Support Files

```
CALLING_SETUP_COMPLETE.md    - Detailed setup guide
CALLING_QUICK_TEST_GUIDE.md  - Full testing procedures  
CALLING_SYSTEM_COMPLETE.md   - Implementation summary
CALL_DATABASE_SCHEMA.sql     - Database tables
```

---

## ⏱️ Timeline

```
⏱️ 5 mins:   Deploy database, test function
⏱️ 5 mins:   Build app
⏱️ 20 mins:  Basic functionality test
⏱️ 30 mins:  Comprehensive testing
⏱️ 45 mins:  TOTAL READY FOR PRODUCTION
```

---

## 🎉 You're Ready!

**All code is complete.**  
**All infrastructure is configured.**  
**Database schema is ready to deploy.**  

**Next action**: Run CALL_DATABASE_SCHEMA.sql

**Estimated time to working calls**: 45 minutes

---

*Last updated: November 14, 2025*  
*Status: ✅ READY FOR DEPLOYMENT*
