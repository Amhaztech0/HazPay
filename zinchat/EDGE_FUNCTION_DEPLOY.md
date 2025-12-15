# Deploy Supabase Edge Function for Notifications

## Prerequisites

✅ Supabase CLI installed
✅ Firebase Server Key ready
✅ Supabase project created

---

## Step 1: Install Supabase CLI (if not installed)

**Option A: Use npx (No installation needed - Recommended)**
```powershell
# Test it works:
npx supabase --version
```

**Option B: Install via npm**
```powershell
npm install -g supabase
```

**Note**: Replace `supabase` with `npx supabase` in all commands below if using Option A.

---

## Step 2: Login to Supabase

```powershell
cd C:\Users\Amhaz\Desktop\zinchat\zinchat
supabase login
```

This will open a browser - authorize the CLI.

---

## Step 3: Link to Your Project

```powershell
supabase link --project-ref YOUR_PROJECT_REF
```

To find your project ref:
1. Go to Supabase Dashboard
2. URL looks like: `https://supabase.com/dashboard/project/YOUR_PROJECT_REF`
3. Copy the `YOUR_PROJECT_REF` part

---

## Step 4: Get Firebase Server Key

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: **zinchat-f8d78**
3. Go to **Project Settings** (gear icon)
4. Click **Cloud Messaging** tab
5. Scroll to **Cloud Messaging API (Legacy)**
6. Copy the **Server key**

**Important**: Keep this key safe!

---

## Step 5: Set Environment Variable in Supabase

### Option A: Via Dashboard (Recommended)

1. Go to Supabase Dashboard
2. Click **Edge Functions** (left sidebar)
3. Click **Configuration** tab
4. Click **Add secret**
5. Name: `FIREBASE_SERVER_KEY`
6. Value: Paste your Firebase Server Key
7. Click **Save**

### Option B: Via CLI

```powershell
supabase secrets set FIREBASE_SERVER_KEY=YOUR_FIREBASE_SERVER_KEY_HERE
```

---

## Step 6: Deploy the Function

```powershell
cd C:\Users\Amhaz\Desktop\zinchat\zinchat
supabase functions deploy send-notification --no-verify-jwt
```

You should see:
```
Deploying Function send-notification (project: zinchat-f8d78)
✓ Deployed!
```

---

## Step 7: Test the Function

### Test via cURL (PowerShell):

```powershell
# Replace YOUR_PROJECT with your Supabase project URL
# Replace YOUR_ANON_KEY with your Supabase anon key
# Replace recipient-user-id with actual user ID from your database

$url = "https://YOUR_PROJECT.supabase.co/functions/v1/send-notification"
$headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer YOUR_ANON_KEY"
}
$body = @{
    type = "direct_message"
    userId = "recipient-user-id"
    messageId = "test-123"
    senderId = "your-user-id"
    senderName = "Test User"
    content = "Hello! This is a test notification"
    chatId = "chat-123"
} | ConvertTo-Json

Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body
```

---

## Step 8: Integrate into Flutter App

Now you need to call this function when sending messages.

### Where to integrate:

**For Direct Messages**: `lib/services/chat_service.dart`
**For Server Messages**: `lib/services/server_service.dart`

I'll update these files next to automatically call the Edge Function.

---

## Troubleshooting

### Function not found
```
supabase functions deploy send-notification --no-verify-jwt
```

### Check logs
```
supabase functions logs send-notification
```

### Environment variable not set
Go to Dashboard → Edge Functions → Configuration → Add `FIREBASE_SERVER_KEY`

### CORS errors
The function already has CORS headers configured.

---

## Next Step

After deploying, I'll update your Flutter code to automatically call this function when sending messages.
