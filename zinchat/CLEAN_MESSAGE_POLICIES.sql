-- Clean slate: drop all existing message policies and recreate with UUID-based functions
-- Run this ONCE, then the app should work

-- Drop ALL existing message policies
DROP POLICY IF EXISTS "Users can insert messages if they are contacts" ON public.messages;
DROP POLICY IF EXISTS "Users can read messages in their chats" ON public.messages;
DROP POLICY IF EXISTS "Users can only message non-blocked users" ON public.messages;
DROP POLICY IF EXISTS "Users can insert their own messages" ON public.messages;
DROP POLICY IF EXISTS "Users can send messages" ON public.messages;
DROP POLICY IF EXISTS "Users can view messages in their chats" ON public.messages;
DROP POLICY IF EXISTS "Users can update own messages" ON public.messages;
DROP POLICY IF EXISTS "Users can delete own messages" ON public.messages;

-- Recreate the two policies we need
CREATE POLICY "Users can insert messages if they are contacts"
ON public.messages
FOR INSERT
WITH CHECK (
    auth.uid() = sender_id AND
    public.can_send_message(
        auth.uid(), 
        (
            SELECT CASE 
                WHEN user1_id = auth.uid() THEN user2_id 
                ELSE user1_id 
            END
            FROM public.chats 
            WHERE id = chat_id
        )
    )
);

CREATE POLICY "Users can read messages in their chats"
ON public.messages
FOR SELECT
USING (
    chat_id IN (
        SELECT id FROM public.chats
        WHERE auth.uid() = user1_id OR auth.uid() = user2_id
    )
);

-- Add UPDATE and DELETE policies so users can edit/delete their own messages
CREATE POLICY "Users can update own messages"
ON public.messages
FOR UPDATE
USING (sender_id = auth.uid())
WITH CHECK (sender_id = auth.uid());

CREATE POLICY "Users can delete own messages"
ON public.messages
FOR DELETE
USING (sender_id = auth.uid());

-- Reload schema
NOTIFY pgrst, 'reload schema';
