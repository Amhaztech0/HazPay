-- Align messages table with UUID-based chat IDs
-- 1. Converts chat_id and sender_id columns to UUID
-- 2. Recreates foreign keys to chats and profiles (user table)
-- Run this in Supabase SQL editor.

BEGIN;

-- Ensure uuid extension is available (usually enabled by default)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop old constraints to allow type change
ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_chat_id_fkey;
ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_sender_id_fkey;

-- Convert chat_id to UUID (safe even if table empty)
ALTER TABLE public.messages
    ALTER COLUMN chat_id TYPE uuid USING (chat_id::text)::uuid;

-- Convert sender_id to UUID (already UUID in app, but ensure DB matches)
ALTER TABLE public.messages
    ALTER COLUMN sender_id TYPE uuid USING (sender_id::text)::uuid;

-- Recreate constraints
ALTER TABLE public.messages
    ADD CONSTRAINT messages_chat_id_fkey FOREIGN KEY (chat_id)
        REFERENCES public.chats(id) ON DELETE CASCADE;

ALTER TABLE public.messages
    ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id)
        REFERENCES public.profiles(id) ON DELETE CASCADE;

COMMIT;
