# Step 3 & 4: Verify Firebase & Test Notifications

Great! Both Edge Functions are deployed. ✅ Now let's verify Firebase and test the notifications.

---

## Step 3: Verify Firebase Cloud Messaging Setup (5 minutes)

### Check if Firebase Cloud Messaging is Enabled

**In Firebase Console**:

1. Go to https://console.firebase.google.com
2. Select your **ZinChat** project
3. Look for **Cloud Messaging** in the left sidebar (under "Grow")
4. You should see:
   - ✅ Messaging API enabled
   - ✅ Server API Key displayed
   - ✅ Sender ID visible

**If you see all three** → Firebase is ready! ✅ Continue to Step 4.

### If Cloud Messaging is NOT Enabled

1. Click **Enable** on the Cloud Messaging section
2. Click **Create** and confirm
3. Wait for API to activate (2-3 minutes)
4. Once enabled, note the **Sender ID** - you might need it

---

### Check Supabase Firebase Integration

**In Supabase**:

1. Go to https://app.supabase.com → Select **zinchat** project
2. Click **Settings** (bottom left)
3. Look for **Firebase Integration** section
4. If configured, you should see:
   - ✅ Firebase Project ID
   - ✅ Firebase API Key
   - ✅ Status: Connected

**If everything is connected** → Perfect! Continue to Step 4.

**If NOT connected** → Add the credentials:
1. Get from Firebase Console:
   - Project ID
   - Web API Key
   - Sender ID
2. Paste into Supabase Firebase Integration
3. Click **Save**

---

## Step 4: Test the Notifications (10 minutes)

### What We're Testing

✅ App receives FCM tokens
✅ FCM tokens saved to database
✅ Reply notification sent
✅ Notification tap opens app
✅ Navigation goes to correct status replies

### Test Setup

**You need 2 devices/users**:
- **Device A**: Your test account (status owner)
- **Device B**: Another test account (replier)

Both should be logged into the app.

---

### Test Case 1: Basic Status Reply Notification

**Steps**:

1. **Device A** (Status Owner):
   - Open the app
   - Go to Home screen
   - View a status or create one

2. **Device B** (Replier):
   - Open the app
   - Find and view the same status
   - Click the reply button
   - Type a message: "Testing status reply! 🎉"
   - Send the reply

3. **Device A** (Status Owner):
   - Wait 3-5 seconds
   - Look for notification:
     - **Title**: "[Username] replied to your status"
     - **Body**: "Testing status reply! 🎉"
   - If you see it → Notification is working! ✅

4. **Tap the notification**:
   - Notification should open the app
   - Should navigate to StatusRepliesScreen
   - Should show the reply you just sent
   - If all this happens → Deep linking works! ✅

---

### Test Case 2: Threading Notifications (Reply to Reply)

**Steps**:

1. **Device A** (Status Owner):
   - Still viewing the status from Test Case 1
   - See the reply from Device B

2. **Device A** (Now as Replier to Device B's Reply):
   - Click the **Reply** button on Device B's reply
   - Type: "Great question! Here's my answer."
   - Send the reply

3. **Device B** (Now as Reply Author):
   - Wait 3-5 seconds
   - Look for a NEW notification:
     - **Title**: "[Your Name] replied to your reply"
     - **Body**: "Great question! Here's my answer."
   - This should be DIFFERENT from the first notification

4. **Tap the notification**:
   - Should open to the same status replies
   - Should show the threading/indentation
   - Should show Device A's reply to Device B's reply

---

### Test Case 3: Cold Start (Optional but Important)

**Steps**:

1. **Device A**: Close the app completely
   - Swipe it away from recent apps
   - Or kill the process

2. **Device B**: Send another reply to the status

3. **Device A**: 
   - Look at the lock screen
   - You should see the notification banner
   - Tap the notification
   - App should open FROM SCRATCH (cold start)
   - Should navigate directly to StatusRepliesScreen
   - If it does → Cold start navigation works! ✅

---

## ✅ Success Criteria

| Test | Status | What to Expect |
|------|--------|-----------------|
| Notification Arrives | ✅ | See banner/notification after reply sent |
| Notification Tap Opens App | ✅ | App launches on notification tap |
| Navigation Works | ✅ | Opens to StatusRepliesScreen with correct status |
| Threading Works | ✅ | Second notification says "replied to your reply" |
| Cold Start Works | ✅ | Can tap notification when app is closed |

---

## Troubleshooting During Testing

### Problem: No notification arrives

**Check 1**: FCM Token Saved?
```
1. Open app
2. Check console logs - look for: "✅ FCM Token: xxx"
3. If you see it, token is being fetched
```

**Check 2**: FCM Token in Database?
```
1. Go to Supabase Dashboard
2. Query: SELECT * FROM user_tokens
3. You should see a row with your user's FCM token
4. If no rows → Token isn't being saved
```

**Check 3**: Edge Functions Running?
```
1. Go to Supabase → Edge Functions
2. Click on send-status-reply-notification
3. Look at the logs (bottom of editor)
4. You should see recent invocations with "200" status
5. If you see errors → Check function code/environment
```

**Check 4**: Firebase Configured?
```
1. Go to Firebase Console
2. Verify Cloud Messaging is ENABLED
3. Verify Supabase has credentials
4. If not → Complete Firebase setup first
```

### Problem: Notification arrives but tap doesn't open app

**Check 1**: MethodChannel configured?
```
In Android:
- Check MainActivity has notification channel setup
- Verify intent filters for notification taps

In iOS:
- Check APNs certificate configured
- Verify notification delegation working
```

**Check 2**: NotificationService listener active?
```
1. In HomeScreen, check _setupNotificationListener() is called
2. Check _navigationController has listeners
3. If not called → Add call to initState()
```

### Problem: Opens app but goes to wrong screen

**Check 1**: Notification payload correct?
```
1. Check Edge Function sends "type": "status_reply"
2. Check Edge Function sends "status_id" in data
3. Verify payload structure matches notification format
```

**Check 2**: Status exists in database?
```
1. Query: SELECT * FROM status_updates WHERE id = 'xxx'
2. Check status hasn't expired (created < 24 hours ago)
3. If status not found → Shows error message
```

---

## What Happens Under the Hood

### When a Reply is Sent

```
1. User sends reply
2. StatusReplyService.sendReply() called
3. Reply saved to database
4. Fetches status owner's FCM token from user_tokens
5. Calls Edge Function: send-status-reply-notification
6. Edge Function sends to Firebase
7. Firebase sends to device via FCM
8. Device receives notification
```

### When User Taps Notification

```
1. Notification received
2. User taps notification
3. MethodChannel routes to app
4. NotificationService._handleNotificationTap()
5. Extracts status_id from payload
6. Emits NotificationNavigationEvent
7. HomeScreen listener receives event
8. Calls _navigateToStatusReplies(statusId)
9. Fetches status from database
10. Navigates to StatusRepliesScreen
11. Displays all replies to that status
```

---

## Expected Notifications

### Format 1: Status Reply
```
Title: "John replied to your status"
Body: "Great work on this feature!"
Tap → Opens StatusRepliesScreen showing John's reply
```

### Format 2: Reply Mention (Threading)
```
Title: "John replied to your reply"
Body: "I completely agree with you!"
Tap → Opens same StatusRepliesScreen showing the threading
```

---

## Common Questions

**Q: How often do notifications arrive?**
A: Every time someone replies (including emoji replies).

**Q: Do I get notified on my own replies?**
A: No, you only get notified if someone replies to YOUR status or YOUR reply.

**Q: Do notifications work if app is open?**
A: Yes! When app is in foreground, shows a high-priority banner notification. When minimized, shows system notification.

**Q: What if I don't want to receive notifications?**
A: Future enhancement: per-status notification settings. For now, all replies notify.

**Q: Can I test on emulator?**
A: Emulators don't support FCM push notifications. Must use real devices.

---

## Next Steps After Testing

✅ **If all tests pass:**
1. Notifications are working perfectly
2. Code is production-ready
3. You can launch to production

⚠️ **If any test fails:**
1. Check troubleshooting section above
2. Verify Firebase is properly configured
3. Check console logs for errors
4. Re-deploy Edge Functions if needed

---

## Summary

You've completed:
- ✅ Step 1: Created user_tokens table
- ✅ Step 2: Deployed Edge Functions
- ✅ Step 3: Verified Firebase setup
- ⏳ Step 4: Test notifications (DO THIS NOW!)

**Once you verify all 4 test cases pass → Status Reply Notifications are complete and production-ready!** 🚀

Report back once you've tested and let me know if everything works! 🎉
