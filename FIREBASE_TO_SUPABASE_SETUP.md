# Firebase Service Account → Supabase Setup

## Why This Is Needed
Your Edge Functions need to **authenticate with Firebase** to send push notifications. Currently, Firebase is enabled but **Supabase doesn't have the credentials yet**.

---

## Step 1: Get Firebase Service Account JSON

1. Go to **Firebase Console** → https://console.firebase.google.com
2. Select your **zinchat** project
3. Click **⚙️ Project Settings** (top left)
4. Go to **Service Accounts** tab
5. Click **Generate New Private Key** button
6. A JSON file will download — **keep this safe and secret**

---

## Step 2: Add Firebase Credentials to Supabase

### Option A: Via Supabase Dashboard (Recommended)

1. Go to **Supabase Dashboard** → https://app.supabase.com
2. Select your **zinchat** project
3. Go to **Settings** → **Edge Functions** (or **Functions**)
4. Look for **Environment Variables** section
5. Add a new variable:
   - **Name:** `FIREBASE_SERVICE_ACCOUNT`
   - **Value:** Paste the **entire JSON content** from the Firebase service account file you downloaded
6. Click **Save**

### Option B: Via Supabase CLI

```bash
# In your zinchat project directory
supabase secrets set FIREBASE_SERVICE_ACCOUNT --file path/to/firebase-service-account.json
```

---

## Step 3: Verify Setup

After adding the environment variable:

1. Go to Supabase Dashboard → **Settings** → **Edge Functions**
2. Confirm you see `FIREBASE_SERVICE_ACCOUNT` in the environment variables list
3. Deploy or re-deploy your Edge Functions:
   ```bash
   supabase functions deploy send-status-reply-notification
   supabase functions deploy send-reply-mention-notification
   ```

---

## What the Edge Functions Will Do

Once credentials are set, your Edge Functions will:
1. Read the `FIREBASE_SERVICE_ACCOUNT` environment variable
2. Authenticate with Google's API
3. Generate an access token
4. Send FCM notifications to user devices

---

## Troubleshooting

### Error: "Missing Firebase credentials"
- ✅ **Solution:** Make sure `FIREBASE_SERVICE_ACCOUNT` is set in Supabase environment variables

### Error: "Invalid service account JSON"
- ✅ **Solution:** Ensure you pasted the **entire JSON file** (not just a key), including the opening `{` and closing `}`

### Notifications still not arriving
- ✅ **Next steps:** 
  1. Check Supabase function logs
  2. Verify FCM tokens are being saved in `user_tokens` table
  3. Test with a simple FCM test message from Firebase Console

---

## Next Steps After Setup

1. ✅ Restart the app on your test device
2. ✅ Create a status and reply to it
3. ✅ Check if push notification appears
4. ✅ Tap notification to verify deep linking works

**Once this is done, your notification system should be fully operational!**
