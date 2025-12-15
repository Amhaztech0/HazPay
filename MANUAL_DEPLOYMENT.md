# Manual Deployment Guide - Server Deletion Function

## ✅ File Created Successfully

The function code has been created at:
```
supabase/functions/execute_scheduled_server_deletions/index.ts
```

## Now Deploy It Manually (3 Steps)

### Step 1: Go to Supabase Dashboard

1. Open: https://supabase.com/dashboard
2. Select your **zinchat** project

### Step 2: Create the Edge Function

1. Go to **Edge Functions** section (left sidebar)
2. Click **Create a new function**
3. Name it: `execute_scheduled_server_deletions`
4. Choose **TypeScript**
5. Click **Create function**

### Step 3: Copy the Code

1. Your file location: `supabase/functions/execute_scheduled_server_deletions/index.ts`
2. Open that file and copy all the code
3. Paste it into the Supabase editor
4. Click **Deploy**

### Step 4: Set Up Cron Schedule

1. After deployment, click on the function name
2. Scroll down to find **Cron** or **Schedule** section
3. Set to: `0 * * * *` (runs every hour)
4. Click **Deploy/Save**

---

## ✅ What This Function Does

- Runs every hour automatically
- Looks for servers with `deletion_scheduled_at <= NOW()`
- Deletes servers that have passed their 24-hour countdown
- Reports how many servers were deleted

---

## Verification

After setup, test it:

1. In Supabase Dashboard → Edge Functions
2. Find `execute_scheduled_server_deletions`
3. Click **Test**
4. Should return:
```json
{
  "success": true,
  "message": "Scheduled server deletions executed",
  "deleted_count": 0
}
```

---

**That's it! Your automatic server deletion is now active.** ✅

Servers will be automatically deleted 24 hours after the owner schedules deletion.
