-- Run this in Supabase SQL Editor to verify tables were created
SELECT 
    table_name,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public'
AND table_name IN ('calls', 'call_participants', 'webrtc_signals', 'call_settings')
ORDER BY table_name;

-- Expected output:
-- call_participants    | 10
-- call_settings       | 9
-- calls               | 14
-- webrtc_signals      | 7
