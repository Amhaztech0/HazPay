# Server Deletion - Setup Later

## Status
✅ Edge Function: **DEPLOYED** (execute_scheduled_server_deletions)
⏳ Cron Automation: **READY TO SETUP** (GitHub Actions)

## Your Service Role Key
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2YWV3emtnc2lsaXRjcm5jcWhlIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjQ1MjY3NywiZXhwIjoyMDc4MDI4Njc3fQ.xdjNyCH_QfWlRa0ACC3YjmIsA-IZHYg2bOeab9lsmJc
```

## When You're Ready - 3 Simple Steps

### Step 1: Go to GitHub
https://github.com/YOUR_USERNAME/zinchat/settings/secrets/actions

### Step 2: Add Secret
- Click "New repository secret"
- **Name**: `SUPABASE_SERVICE_ROLE_KEY`
- **Value**: Paste the key above ↑
- Click "Add secret"

### Step 3: Push Workflow File
File is already created at: `.github/workflows/server-deletion-cron.yml`

Run these commands:
```powershell
cd C:\Users\Amhaz\Desktop\zinchat
git add .github/workflows/server-deletion-cron.yml
git commit -m "Add automatic server deletion cron job"
git push
```

## That's It!
After these 3 steps:
- ✅ Edge Function runs every hour automatically
- ✅ Servers delete after 24-hour countdown
- ✅ No manual work needed

## Links
- Edge Function: https://supabase.com/dashboard/project/avaewzkgsilitcrncqhe/functions
- GitHub Secrets: https://github.com/YOUR_USERNAME/zinchat/settings/secrets/actions

---

**Note**: Until you complete this setup, the 24-hour countdown will show but servers won't actually delete.
