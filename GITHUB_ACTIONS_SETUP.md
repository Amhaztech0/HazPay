# GitHub Actions Cron Setup for Server Deletion

## ✅ Workflow File Created

File location: `.github/workflows/server-deletion-cron.yml`

This file will automatically run your Edge Function every hour.

## Setup Instructions

### Step 1: Get Your Service Role Key

1. Go to Supabase Dashboard → **Settings** (gear icon)
2. Click **API** tab
3. Copy your **Service Role Key** (secret_*)
   - ⚠️ Keep this SECRET! Never share it.

### Step 2: Add GitHub Secret

1. Go to your GitHub repository
2. Click **Settings** (top menu)
3. Click **Secrets and variables** → **Actions**
4. Click **New repository secret**
5. Name: `SUPABASE_SERVICE_ROLE_KEY`
6. Value: Paste your Service Role Key
7. Click **Add secret**

### Step 3: Push the Workflow File

1. Commit the file to your repository:
```bash
git add .github/workflows/server-deletion-cron.yml
git commit -m "Add automatic server deletion cron job"
git push
```

### Step 4: Verify It's Working

1. Go to your GitHub repo
2. Click **Actions** tab
3. You should see "Execute Scheduled Server Deletions" workflow
4. It will run automatically every hour
5. You can also click **Run workflow** to test it manually

## How It Works

- **Schedule**: Every hour at the top of the hour (UTC)
- **Action**: Calls your Edge Function: `execute_scheduled_server_deletions`
- **Result**: Servers past their 24-hour deletion countdown are deleted

## Testing

To test manually:

1. Go to GitHub → **Actions** tab
2. Click "Execute Scheduled Server Deletions"
3. Click **Run workflow** → **Run workflow**
4. Wait for it to complete (should see green checkmark)

## Monitoring

Check the workflow logs:

1. GitHub → **Actions** tab
2. Click on any workflow run
3. Click the job to see detailed logs
4. Should see curl output with the response

## ✅ That's It!

Your server deletion system is now fully automated! 🎉

Servers will be deleted automatically 24 hours after deletion is scheduled.
