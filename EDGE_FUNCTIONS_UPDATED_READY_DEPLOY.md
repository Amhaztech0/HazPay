# ✅ Edge Functions Updated - Ready to Deploy

## What Changed
Your Edge Functions (`send-status-reply-notification` and `send-reply-mention-notification`) have been updated to use your existing `FIREBASE_SERVICE_ACCOUNT` credential.

### Changes Made:
1. ✅ Added `generateAccessToken()` function to parse service account and generate Google JWT tokens
2. ✅ Updated credential retrieval to use `FIREBASE_SERVICE_ACCOUNT` (instead of missing `FIREBASE_URL` and `FIREBASE_MESSAGING_TOKEN`)
3. ✅ Updated FCM API endpoint to use Google's v1 API: `https://fcm.googleapis.com/v1/projects/{projectId}/messages:send`

---

## How to Deploy (Via Supabase Dashboard)

### Option 1: Using Supabase Web Console (Recommended)

1. Go to **Supabase Dashboard** → https://app.supabase.com/project/avaewzkgsilticrncqhe/functions
2. You should see your functions listed:
   - `send-status-reply-notification` (Updated 2 hours ago)
   - `send-reply-mention-notification` (Updated 2 hours ago)
3. For each function:
   - Click the three dots menu (⋮)
   - Select **Deploy** or **Redeploy**
   - Wait for confirmation

### Option 2: Using Supabase CLI (If installed)

```bash
cd c:\Users\Amhaz\Desktop\zinchat\zinchat
supabase functions deploy send-status-reply-notification
supabase functions deploy send-reply-mention-notification
```

---

## Verification

After deploying, test by:

1. **Create a status** from your app
2. **Reply to the status** from another account
3. **Check for push notification**
4. **Verify deep linking** - tapping the notification should take you to the replies

**If notifications arrive, your setup is complete!** 🎉

---

## Troubleshooting

### Error: "Firebase not configured"
- ✅ Check that `FIREBASE_SERVICE_ACCOUNT` is still in Supabase Secrets
- ✅ Re-deploy functions

### Error: "Invalid Firebase configuration"  
- ✅ Ensure the JSON in `FIREBASE_SERVICE_ACCOUNT` is valid
- ✅ Check Supabase function logs for parsing errors

### No notifications arriving
- ✅ Verify FCM tokens are being saved in `user_tokens` table
- ✅ Check Supabase function logs for FCM API errors
- ✅ Ensure your app has notification permissions granted

---

## Next Steps

Once deployed, proceed with:
1. ✅ Deploy both functions via Supabase Dashboard
2. ✅ Test notification flow end-to-end
3. ✅ Verify deep linking works correctly
