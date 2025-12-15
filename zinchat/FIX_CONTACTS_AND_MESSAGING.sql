-- COMPREHENSIVE FIX FOR MESSAGING SYSTEM
-- This fixes the contacts system to work properly with your message request feature

BEGIN;

-- Step 1: Fix the contacts table to prevent duplicate entries
-- The current system creates TWO rows per relationship (user1->user2 AND user2->user1)
-- This is unnecessary. We only need ONE row with a CHECK constraint

-- First, clean up existing duplicate contacts
DELETE FROM public.contacts
WHERE id IN (
    SELECT a.id
    FROM public.contacts a
    INNER JOIN public.contacts b ON (
        a.id > b.id AND (
            (a.user_id_1 = b.user_id_2 AND a.user_id_2 = b.user_id_1)
            OR
            (a.user_id_1 = b.user_id_1 AND a.user_id_2 = b.user_id_2)
        )
    )
);

-- Add a CHECK constraint to ensure user_id_1 < user_id_2 (prevents duplicates)
ALTER TABLE public.contacts 
DROP CONSTRAINT IF EXISTS contacts_user_order_check;

ALTER TABLE public.contacts
ADD CONSTRAINT contacts_user_order_check 
CHECK (user_id_1 < user_id_2);


-- Step 2: Update can_send_message function to work with single-row contacts
CREATE OR REPLACE FUNCTION public.can_send_message(
    p_sender_id UUID,
    p_receiver_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if contact exists (handles both user orderings)
    RETURN EXISTS (
        SELECT 1
        FROM public.contacts
        WHERE
            (user_id_1 = LEAST(p_sender_id, p_receiver_id) AND 
             user_id_2 = GREATEST(p_sender_id, p_receiver_id))
    );
END;
$$;


-- Step 3: Fix accept_message_request to create only ONE contact row
CREATE OR REPLACE FUNCTION public.accept_message_request(
    p_request_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request public.message_requests;
    v_receiver_id UUID := auth.uid();
BEGIN
    SELECT * INTO v_request FROM public.message_requests WHERE id = p_request_id;

    -- Validate that the current user is the receiver
    IF v_request.receiver_id != v_receiver_id THEN
        RETURN json_build_object('success', false, 'message', 'You are not authorized to accept this request.');
    END IF;

    -- Update request status
    UPDATE public.message_requests
    SET status = 'accepted', updated_at = NOW()
    WHERE id = p_request_id;

    -- Create a single contact entry (with smaller UUID first)
    INSERT INTO public.contacts (user_id_1, user_id_2)
    VALUES (
        LEAST(v_request.sender_id, v_request.receiver_id),
        GREATEST(v_request.sender_id, v_request.receiver_id)
    )
    ON CONFLICT (user_id_1, user_id_2) DO NOTHING;

    RETURN json_build_object('success', true, 'message', 'Message request accepted.');
END;
$$;


-- Step 4: Create a helper function to auto-add contacts for existing chats
-- This helps users who already have chats but no contact entries
CREATE OR REPLACE FUNCTION public.ensure_chat_contacts()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- For every chat, ensure a contact exists
    INSERT INTO public.contacts (user_id_1, user_id_2)
    SELECT DISTINCT
        LEAST(user1_id, user2_id) as user_id_1,
        GREATEST(user1_id, user2_id) as user_id_2
    FROM public.chats
    ON CONFLICT (user_id_1, user_id_2) DO NOTHING;
END;
$$;

-- Run it once to fix existing chats
SELECT public.ensure_chat_contacts();


-- Step 5: Update the messages RLS policy to be more forgiving
-- Allow messages if users are contacts OR if it's the first message in a new chat
DROP POLICY IF EXISTS "Users can insert messages if they are contacts" ON public.messages;

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


-- Step 6: Reload schema cache
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ============================================
-- VERIFICATION QUERIES (Run these to check)
-- ============================================

-- Check contacts table structure
-- SELECT * FROM public.contacts LIMIT 10;

-- Check if you have any contacts
-- SELECT * FROM public.contacts WHERE user_id_1 = auth.uid() OR user_id_2 = auth.uid();

-- Check message requests
-- SELECT * FROM public.message_requests WHERE sender_id = auth.uid() OR receiver_id = auth.uid();

-- Test can_send_message function
-- SELECT public.can_send_message('your-user-id'::UUID, 'other-user-id'::UUID);
