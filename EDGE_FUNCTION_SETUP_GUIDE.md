# Supabase Edge Function Setup: Automatic Server Deletion

## Overview
This Edge Function automatically executes scheduled server deletions every hour. When a server owner schedules deletion, the server will be automatically deleted after 24 hours.

## Files
- **EDGE_FUNCTION_SERVER_DELETION.ts** - The TypeScript Edge Function code
- **SERVER_DELETION.sql** - The RPC function it calls

## Deployment Steps

### Step 1: Create the Edge Function in Supabase Dashboard

1. Go to your **Supabase Dashboard** → **Edge Functions**
2. Click **Create a new function**
3. Name it: `execute_scheduled_server_deletions`
4. Choose **TypeScript** as the language
5. Replace the default code with the contents of `EDGE_FUNCTION_SERVER_DELETION.ts`
6. Click **Deploy**

### Step 2: Set Up Cron Job

After the function is deployed, you need to schedule it to run hourly:

#### Option A: Supabase Cron (Built-in)
1. In the **Edge Functions** page, find your function
2. Click the function name to open details
3. Look for **Cron** or **Schedule** settings
4. Add a cron expression: `0 * * * *` (runs every hour at the top of the hour)
5. Save

#### Option B: GitHub Actions (If Supabase Cron not available)
1. Create `.github/workflows/delete-servers.yml`:

```yaml
name: Execute Scheduled Server Deletions

on:
  schedule:
    # Run every hour at the top of the hour (UTC)
    - cron: '0 * * * *'
  workflow_dispatch:  # Allow manual trigger

jobs:
  delete-servers:
    runs-on: ubuntu-latest
    steps:
      - name: Execute server deletions
        run: |
          curl -X POST \
            "https://${{ secrets.SUPABASE_PROJECT_ID }}.functions.supabase.co/execute_scheduled_server_deletions" \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_ANON_KEY }}" \
            -H "Content-Type: application/json"
```

2. Add to your GitHub Secrets:
   - `SUPABASE_PROJECT_ID` - Your project ID from Supabase
   - `SUPABASE_ANON_KEY` - Your anon key

#### Option C: External Service (Vercel Cron, AWS EventBridge, etc.)

Use the Edge Function URL and call it periodically:
```
POST https://YOUR_PROJECT_ID.functions.supabase.co/execute_scheduled_server_deletions
Header: Authorization: Bearer YOUR_ANON_KEY
```

### Step 3: Test the Function

1. In Supabase Dashboard → **Edge Functions**
2. Click your function
3. Click **Test**
4. Should return:
```json
{
  "success": true,
  "message": "Scheduled server deletions executed",
  "deleted_count": 0
}
```

If no servers are scheduled for deletion, `deleted_count` will be 0 (expected).

### Step 4: Test with Real Data

1. Create a test server
2. Schedule deletion (24-hour timer)
3. Manually update the deletion time to NOW - 1 second in SQL:
   ```sql
   UPDATE servers 
   SET deletion_scheduled_at = NOW() - INTERVAL '1 second'
   WHERE id = 'YOUR-SERVER-ID';
   ```
4. Call the Edge Function (or wait for next scheduled run)
5. Verify the server was deleted

## Monitoring

Check Edge Function logs in Supabase Dashboard:
1. **Edge Functions** → Select function → **Logs** tab
2. See execution history and any errors

## How It Works

1. **User schedules deletion** → Sets `deletion_scheduled_at` to NOW() + 24 hours
2. **Cron job runs hourly** → Calls `execute_scheduled_server_deletions()`
3. **Function finds expired servers** → Where `deletion_scheduled_at <= NOW()`
4. **Deletes in order**:
   - Server members (foreign key constraint)
   - Server invites
   - Server messages
   - Server itself
5. **Returns count** of deleted servers

## Troubleshooting

### Function not running:
- Verify cron schedule is set correctly
- Check Edge Function logs for errors
- Ensure SUPABASE_SERVICE_ROLE_KEY is set

### RPC function errors:
- Verify `execute_scheduled_server_deletions()` RPC function exists (from SERVER_DELETION.sql)
- Check database logs for foreign key constraint issues

### Deletion not happening:
- Verify `deletion_scheduled_at` is set in database
- Check that current time is past the scheduled deletion time
- Check database logs for errors

## Disabling Automatic Deletion

If you want to disable automatic deletions:
1. In Supabase Dashboard → **Edge Functions**
2. Click your function → **Settings**
3. Click **Delete** to remove the function or disable its cron schedule

Users can still schedule deletions manually, but they won't be automatically executed.
