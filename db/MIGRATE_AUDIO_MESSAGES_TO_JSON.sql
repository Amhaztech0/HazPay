-- Migration: Convert existing audio messages to the `{duration, waveform}` JSON payload
-- so the client can render stored waveforms even for historic voice notes.
-- Run this in Supabase (psql or SQL editor) after backing up the `messages` table.

DO $$
DECLARE
  rec RECORD;
  default_waveform float8[] := array_fill(0.25::float8, ARRAY[28]);
  parsed_seconds integer;
BEGIN
  FOR rec IN
    SELECT id, content
    FROM messages
    WHERE message_type = 'audio'
      AND (content IS NULL OR content NOT LIKE '%"duration"%')
  LOOP
    parsed_seconds := CASE
      WHEN rec.content IS NULL OR trim(rec.content) = '' THEN 0
      WHEN rec.content ~ '^[0-9]+$' THEN trim(rec.content)::int
      WHEN rec.content ~ '^[0-9]+:[0-9]{2}$' THEN
        (split_part(rec.content, ':', 1)::int * 60)
        + split_part(rec.content, ':', 2)::int
      ELSE 0
    END;

    UPDATE messages
    SET content = jsonb_build_object(
          'duration', parsed_seconds,
          'waveform', array_to_json(default_waveform)
        )::text
    WHERE id = rec.id;
  END LOOP;
END
$$;