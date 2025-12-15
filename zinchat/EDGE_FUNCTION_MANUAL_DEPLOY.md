# 🚀 Manual Edge Function Deployment Guide

## Step 1: Open Browser & Login

Go to your Supabase project dashboard:
https://app.supabase.com/

## Step 2: Find Your Project Details

In Supabase Dashboard:
- **Project URL**: Settings > API > Project URL (copy this)
- **Anon Key**: Settings > API > Project API Keys > anon key (copy this)

Example:
```
Project URL: https://abcdefg.supabase.co
Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

## Step 3: Set Secrets

Go to **Settings > Functions > Secrets** and add:

```
HMS_APP_ACCESS_KEY = 69171bc9145cb4e8449b1a6e

HMS_APP_SECRET = ibgzGtbFbko5Fkn8MV0rZ0e3oyU46hvZpG-_PEPH75-f40D2zewJo4foqslX1ILrdRed5mOnricZd7fjKBsenQXxNPBX1Xx2RCJZ8FSNuIRu609wE9bDXW_n2VpqO127HqUT2jF_B848MQNzMzKVHBsrzm0UhYlCla_aw6YOgoU=
```

## Step 4: Deploy Function via CLI

Open PowerShell in your project directory:

```powershell
cd c:\Users\Amhaz\Desktop\zinchat\zinchat

# Login to Supabase
npx supabase login

# Deploy the function
npx supabase functions deploy generate-hms-token

# List functions to verify
npx supabase functions list
```

## Step 5: Test the Function

Replace `YOUR_PROJECT`, `YOUR_ANON_KEY` with your actual values:

```bash
curl -X POST \
  'https://YOUR_PROJECT.supabase.co/functions/v1/generate-hms-token' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "room_id": "test-room",
    "user_name": "Test User"
  }'
```

Expected response:
```json
{
  "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "room_id": "test-room",
  "user_id": "user-uuid"
}
```

## Step 6: Update Flutter App

Update `lib/services/hms_call_service.dart`:

```dart
static const String HMS_API_URL = 'https://YOUR_PROJECT.supabase.co/functions/v1/generate-hms-token';
```

## ✅ Deployment Complete!

Your edge function is now live and ready to generate 100ms tokens for your app.

---

## 🆘 Troubleshooting

### Can't login with `npx supabase login`

Try the web-based approach:
```bash
# Clear login cache
npx supabase logout

# Login again
npx supabase login
```

### Function deployment fails

Check:
- ✅ You're in the correct project directory
- ✅ `supabase/functions/generate-hms-token/index.ts` exists
- ✅ Secrets are set in Supabase Dashboard
- ✅ Run with `--debug` flag for more info:
  ```bash
  npx supabase functions deploy generate-hms-token --debug
  ```

### Test function returns error

Check:
- ✅ Project URL is correct
- ✅ Anon key is correct (not service role key)
- ✅ Authorization header format: `Bearer YOUR_KEY`
- ✅ Content-Type is `application/json`

---

**Done! Your edge function is deployed and ready for production.** 🎉
