# Server Deletion Feature - Setup Guide

## What Was Added

### 1. Server Members Display Fix
- **Fixed**: Server members list now shows user names instead of UUIDs
- Location: `lib/screens/servers/server_members_screen.dart`

### 2. Server Deletion with 24-Hour Timer
- **Owners only** can schedule server deletion
- 24-hour countdown before actual deletion
- Can cancel deletion anytime before the timer expires
- All members see the deletion warning banner with countdown

## Database Setup

### Run this SQL in your Supabase SQL Editor:

```sql
-- File: SERVER_DELETION.sql
```

This creates:
- `deletion_scheduled_at` column on servers table
- `deletion_scheduled_by` column on servers table  
- `schedule_server_deletion()` function
- `cancel_server_deletion()` function
- `execute_scheduled_server_deletions()` function (for cron job)

## Features

### For Server Owners:
1. **Delete Server Button** - Appears at bottom of server details screen
2. **Schedule Deletion** - Sets a 24-hour countdown
3. **Cancel Deletion** - Button appears in warning banner to cancel

### For All Members:
1. **Warning Banner** - Shows at top of server screen when deletion is scheduled
2. **Countdown Timer** - Updates every second showing time remaining
3. **Visual Alert** - Red banner with warning icon

## How It Works

1. **Owner schedules deletion** → Timer starts (24 hours)
2. **Banner appears** for all members with countdown
3. **Owner can cancel** anytime before timer expires
4. **After 24 hours** → Server needs to be deleted (requires cron setup)

## Important: Cron Job Setup

The actual deletion requires a scheduled job. You have two options:

### Option 1: Supabase Edge Function (Recommended)
Create an Edge Function that runs hourly:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  const { data, error } = await supabase.rpc('execute_scheduled_server_deletions')
  
  return new Response(
    JSON.stringify(data),
    { headers: { "Content-Type": "application/json" } },
  )
})
```

Then set up a cron trigger in Supabase Dashboard → Edge Functions → Cron Jobs

### Option 2: External Cron Service
Use services like:
- GitHub Actions (scheduled workflow)
- Vercel Cron
- AWS EventBridge
- Any server with crontab

Call the Supabase RPC function hourly:
```bash
curl -X POST 'https://your-project.supabase.co/rest/v1/rpc/execute_scheduled_server_deletions' \
  -H "apikey: YOUR_SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY"
```

## Testing

1. Create a test server
2. As owner, click "Delete Server"
3. Confirm deletion → Timer starts
4. Check that banner appears with countdown
5. Click "Cancel Deletion" → Timer stops
6. Schedule again if needed

## UI Updates

- `lib/models/server_model.dart` - Added deletion fields
- `lib/services/server_service.dart` - Added deletion methods
- `lib/screens/servers/server_detail_screen.dart` - Added deletion UI
- `lib/screens/servers/server_members_screen.dart` - Fixed name display

