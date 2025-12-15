# Quick Deploy Guide - Server Deletion Edge Function

## For Windows Users (Recommended)

### Step 1: Install Supabase CLI
```powershell
npm install -g supabase
```

### Step 2: Run the deployment script
```powershell
cd C:\Users\Amhaz\Desktop\zinchat
.\deploy_edge_function.ps1
```

This will:
- ✓ Create the function directory structure
- ✓ Copy the Edge Function code
- ✓ Link your Supabase project
- ✓ Deploy the function automatically

### Step 3: Set up the Cron Schedule

After deployment, you need to set up the hourly schedule:

#### Option A: Supabase Dashboard (Easiest)
1. Go to: https://supabase.com/dashboard/project/YOUR_PROJECT_ID/functions
2. Find `execute_scheduled_server_deletions`
3. Click on it
4. Scroll down and find "Cron" or "Schedule"
5. Enter cron expression: `0 * * * *`
6. Save/Deploy

#### Option B: GitHub Actions (Automatic)
1. In your zinchat GitHub repo, create this file: `.github/workflows/delete-servers.yml`
2. Paste this content:

```yaml
name: Execute Scheduled Server Deletions

on:
  schedule:
    # Run every hour at the top of the hour (UTC)
    - cron: '0 * * * *'

jobs:
  delete-servers:
    runs-on: ubuntu-latest
    steps:
      - name: Execute server deletions
        run: |
          curl -X POST \
            "https://YOUR_PROJECT_ID.functions.supabase.co/execute_scheduled_server_deletions" \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_ANON_KEY }}" \
            -H "Content-Type: application/json"
```

3. Replace `YOUR_PROJECT_ID` with your actual Supabase project ID
4. Commit and push - GitHub will run it automatically every hour

### Step 4: Verify It's Working

1. In Supabase Dashboard → Functions → `execute_scheduled_server_deletions`
2. Click the **Test** button
3. Should show response like:
```json
{
  "success": true,
  "message": "Scheduled server deletions executed",
  "deleted_count": 0
}
```

If it returns `deleted_count: 0`, that's normal - means no servers are scheduled for deletion yet.

### Step 5: Test with Real Data

To test the actual deletion:

1. **Create a test server** in the app
2. **Schedule deletion** (24-hour timer)
3. **Set deletion time to NOW** using this SQL in Supabase:
   ```sql
   UPDATE servers 
   SET deletion_scheduled_at = NOW()
   WHERE id = 'YOUR_TEST_SERVER_ID';
   ```
4. **Run the Edge Function** (click Test in dashboard)
5. **Check if server was deleted** in your app

---

## For Mac/Linux Users

Run the bash script instead:
```bash
cd ~/Desktop/zinchat  # or your path
chmod +x deploy_edge_function.sh
./deploy_edge_function.sh
```

---

## Finding Your Supabase Project ID

Your Edge Function URL will be:
```
https://YOUR_PROJECT_ID.functions.supabase.co/execute_scheduled_server_deletions
```

To find your project ID:
1. Go to Supabase Dashboard
2. Click **Settings** (gear icon)
3. Go to **General** tab
4. Copy the **Project ID**

---

## Troubleshooting

### "Supabase CLI not found"
Install it: `npm install -g supabase`

### Deployment fails with "unauthorized"
- Run `supabase login` first
- Make sure you have a Supabase project created

### Function runs but returns error
- Check Edge Function logs in Supabase Dashboard
- Verify `execute_scheduled_server_deletions()` SQL function exists (run SERVER_DELETION.sql if not)
- Check database logs for RLS or constraint errors

### Cron not running
- Verify the cron schedule is set to `0 * * * *` in dashboard
- Check Edge Function logs for any errors
- For GitHub Actions: verify the workflow file is in `.github/workflows/` directory

---

**That's it! Your server deletion system is now automated.** 🎉

Servers will automatically delete 24 hours after the owner schedules deletion.
