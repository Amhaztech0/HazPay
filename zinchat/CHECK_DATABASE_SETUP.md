# Database Setup Check

## Problem
Your calls are ending immediately because the database tables don't exist yet.

## Solution

### Step 1: Verify Tables Don't Exist
1. Go to Supabase Dashboard → SQL Editor
2. Run this query:
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('calls', 'call_participants', 'webrtc_signals', 'call_settings');
```

If you get 0 rows, the tables don't exist.

### Step 2: Deploy the Schema
1. Open `CALL_DATABASE_SCHEMA.sql` in this folder
2. Copy ALL the contents (Ctrl+A, Ctrl+C)
3. Go to Supabase Dashboard → SQL Editor
4. Paste and click **RUN**

You should see: `Success. No rows returned`

### Step 3: Verify Tables Exist
Run the query from Step 1 again. You should now see 4 tables:
- calls
- call_participants  
- call_settings
- webrtc_signals

### Step 4: Install New APK
Install `build\app\outputs\flutter-apk\app-release.apk` and test calls.

## How to Check Logs

To see the detailed error logs:
1. Connect your phone via USB
2. Enable USB Debugging
3. Run: `adb logcat | Select-String "DirectCallScreen|WebRTC"`

You'll see messages like:
- 🔵 = WebRTC service operations
- 📞 = Call screen operations  
- ❌ = Errors with stack traces

## Common Errors

### "relation 'calls' does not exist"
→ Database tables not deployed. Follow steps above.

### "permission denied for table calls"
→ RLS policies not deployed. Re-run CALL_DATABASE_SCHEMA.sql

### "null value in column 'caller_id'"
→ User not authenticated. Check login status.
