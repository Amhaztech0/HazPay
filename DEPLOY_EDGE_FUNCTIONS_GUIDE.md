# 🚀 Deploy Edge Functions via Supabase Dashboard

Since the Supabase CLI isn't installed on your machine, you can deploy the Edge Functions directly through the Supabase web dashboard. Here's how:

## Option 1: Deploy via Supabase Dashboard (Recommended - 5 minutes)

### Step 1: Navigate to Edge Functions

1. Go to [app.supabase.com](https://app.supabase.com)
2. Open your **zinchat** project
3. Click **Edge Functions** in the left sidebar
4. Click **Create a new function**

### Step 2: Create First Function - `send-status-reply-notification`

1. Enter function name: `send-status-reply-notification`
2. Click **Create function**
3. Copy the entire content from: `supabase/functions/send-status-reply-notification/index.ts`
4. Paste it into the editor
5. Click **Deploy** (top right)
6. Wait for deployment confirmation ✅

### Step 3: Create Second Function - `send-reply-mention-notification`

1. Click **Create a new function** again
2. Enter function name: `send-reply-mention-notification`
3. Click **Create function**
4. Copy the entire content from: `supabase/functions/send-reply-mention-notification/index.ts`
5. Paste it into the editor
6. Click **Deploy**
7. Wait for deployment confirmation ✅

### ✅ Both Functions Deployed!

---

## Option 2: Install Supabase CLI and Deploy (Alternative)

If you want to use the CLI:

### Install Supabase CLI

**On Windows (PowerShell as Admin)**:
```powershell
# Using npm
npm install -g supabase

# Or using scoop
scoop install supabase
```

**Then deploy**:
```powershell
cd C:\Users\Amhaz\Desktop\zinchat\zinchat
supabase functions deploy send-status-reply-notification
supabase functions deploy send-reply-mention-notification
```

---

## Verify Deployment

After deploying both functions (via dashboard or CLI):

1. Go to **Edge Functions** in Supabase dashboard
2. You should see:
   - ✅ send-status-reply-notification
   - ✅ send-reply-mention-notification
3. Both should show status as "Active"

---

## Configure Environment Variables (if needed)

If the functions need Firebase configuration:

1. Go to **Edge Functions** → **Settings** (or Project Settings)
2. Add environment variables:
   - `FIREBASE_URL`: Your Firebase Cloud Messaging URL
   - `FIREBASE_MESSAGING_TOKEN`: Your Firebase service account token

---

## Test the Functions

After deployment:

1. Go to each function in the dashboard
2. Click **Test** button
3. Send a test payload:

```json
{
  "fcm_token": "test_token_here",
  "status_id": "test-status-id",
  "replier_name": "Test User",
  "content": "Test message"
}
```

4. Should get response: `{"success": true, "message": "Notification sent"}`

---

## Next Steps

After deploying:

1. ✅ Edge Functions deployed
2. ⏳ Add `_updateFcmTokenInDatabase()` to NotificationService
3. ⏳ Create user_tokens table
4. ⏳ Test notifications end-to-end

---

## Troubleshooting

### "Function not found" error
- Wait 1-2 minutes for deployment to complete
- Refresh the browser page
- Check that function name matches exactly

### "Permission denied" error
- Verify you have admin access to the Supabase project
- Check your Supabase credentials are correct

### Deployment stuck
- Try redeploying the function
- Check the function logs for errors
- Contact Supabase support if issue persists

---

**Once both functions are deployed and showing "Active", continue to Step 2! ✅**
