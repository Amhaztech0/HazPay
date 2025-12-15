# Enable Realtime in Supabase

## Check if Realtime is Enabled

1. Go to Supabase Dashboard
2. Click **Database** → **Replication**
3. Check if `calls` table has realtime enabled

## If Not Enabled, Run This:

Go to SQL Editor and run:

```sql
-- Enable realtime on calls table
ALTER PUBLICATION supabase_realtime ADD TABLE calls;

-- Verify it's enabled
SELECT schemaname, tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' 
AND tablename IN ('calls', 'webrtc_signals', 'call_participants');
```

You should see all 3 tables listed.

## Test the Connection

On the receiving device, check logs for:
```
📞 CallManager: Channel subscription status: SUBSCRIBED
```

If you see `CHANNEL_ERROR` or `TIMED_OUT`, realtime isn't working.

## Common Issues

### Issue: No logs appear
→ CallManager not initialized. Check main.dart has the initialization code.

### Issue: Channel subscription status: CLOSED
→ Realtime not enabled on table. Run the ALTER PUBLICATION command above.

### Issue: Received event but no notification
→ Notification permissions not granted. Check Android settings.
