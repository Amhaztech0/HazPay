-- Emergency Fix for Message Sending and Type Issues
-- Run this IMMEDIATELY in Supabase SQL Editor

-- 1. First drop the policy that depends on the function
DROP POLICY IF EXISTS "Users can insert messages if they are contacts" ON public.messages;

-- 2. Now drop and recreate can_send_message with better error handling
DROP FUNCTION IF EXISTS public.can_send_message(UUID, UUID) CASCADE;
CREATE OR REPLACE FUNCTION public.can_send_message(
    p_sender_id UUID,
    p_receiver_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Simple contact check without bigint casting issues
    RETURN EXISTS (
        SELECT 1
        FROM public.contacts
        WHERE
            (user_id_1::TEXT = p_sender_id::TEXT AND user_id_2::TEXT = p_receiver_id::TEXT) OR
            (user_id_1::TEXT = p_receiver_id::TEXT AND user_id_2::TEXT = p_sender_id::TEXT)
    );
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return false to prevent message send
        RAISE WARNING 'can_send_message error: %', SQLERRM;
        RETURN FALSE;
END;
$$;

-- 3. Recreate the RLS policy to handle type conversion properly
CREATE POLICY "Users can insert messages if they are contacts"
ON public.messages
FOR INSERT
WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
        SELECT 1 FROM public.contacts
        WHERE
            (user_id_1 = auth.uid() AND user_id_2 = (
                SELECT CASE 
                    WHEN user1_id = auth.uid() THEN user2_id 
                    ELSE user1_id 
                END
                FROM public.chats 
                WHERE id = messages.chat_id
            ))
            OR
            (user_id_2 = auth.uid() AND user_id_1 = (
                SELECT CASE 
                    WHEN user1_id = auth.uid() THEN user2_id 
                    ELSE user1_id 
                END
                FROM public.chats 
                WHERE id = messages.chat_id
            ))
    )
);

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.can_send_message TO authenticated;

-- Test the function with real UUIDs (replace with actual user IDs to test)
-- SELECT public.can_send_message(
--     'your-sender-uuid'::UUID, 
--     'your-receiver-uuid'::UUID
-- );
