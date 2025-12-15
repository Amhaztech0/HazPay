-- ==============================================================================
-- MESSAGE REQUESTS SYSTEM: Search Method-Based Access
-- ==============================================================================
-- This system allows direct messaging only if searched by email
-- If searched by full name, message goes to pending (request) status

-- ==============================================================================
-- PART 1: Add tracking columns to messages table
-- ==============================================================================

ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS search_method TEXT DEFAULT 'name' CHECK (search_method IN ('email', 'name'));

ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS is_request BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_messages_search_method ON messages(search_method);
CREATE INDEX IF NOT EXISTS idx_messages_is_request ON messages(is_request);

-- ==============================================================================
-- PART 2: Update RLS policies to respect search method
-- ==============================================================================

DROP POLICY IF EXISTS "Users can view messages in chats" ON messages;
DROP POLICY IF EXISTS "Users can view messages based on search method" ON messages;
DROP POLICY IF EXISTS "Users can send messages" ON messages;
DROP POLICY IF EXISTS "Users can send messages via email or name search" ON messages;

CREATE POLICY "Users can view messages based on search method"
ON messages
FOR SELECT
USING (
    chat_id IN (
        SELECT id FROM chats
        WHERE auth.uid() = user1_id OR auth.uid() = user2_id
    )
    OR (
        is_request = TRUE 
        AND chat_id IN (
            SELECT id FROM chats
            WHERE auth.uid() = user2_id
        )
    )
);

CREATE POLICY "Users can send messages via email or name search"
ON messages
FOR INSERT
WITH CHECK (
    auth.uid() = sender_id
    AND (search_method = 'email' OR search_method = 'name')
);

-- ==============================================================================
-- PART 3: Helper function for inserting messages with search method
-- ==============================================================================

CREATE OR REPLACE FUNCTION insert_message_with_search_method(
    p_chat_id UUID,
    p_sender_id UUID,
    p_content TEXT,
    p_search_method TEXT DEFAULT 'name'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
    v_message_id UUID;
BEGIN
    INSERT INTO messages (
        chat_id,
        sender_id,
        content,
        message_type,
        search_method,
        is_request
    )
    VALUES (
        p_chat_id,
        p_sender_id,
        p_content,
        'text',
        p_search_method,
        (p_search_method = 'name')
    )
    RETURNING id INTO v_message_id;
    
    RETURN v_message_id;
END;
$func$;

-- ==============================================================================
-- PART 4: Verification queries (commented out - uncomment to test)
-- ==============================================================================

-- SELECT column_name, data_type FROM information_schema.columns 
-- WHERE table_name = 'messages' AND column_name IN ('search_method', 'is_request');

-- SELECT id, sender_id, content, search_method, is_request, created_at 
-- FROM messages ORDER BY created_at DESC LIMIT 10;

