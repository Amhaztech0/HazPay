-- VERIFICATION SCRIPT
-- Run this AFTER applying FIX_CONTACTS_AND_MESSAGING.sql
-- This will tell you exactly what's fixed and what's not

-- ============================================
-- 1. CHECK CONTACTS TABLE
-- ============================================
SELECT 
    '1. CONTACTS TABLE STRUCTURE' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.check_constraints 
            WHERE constraint_schema = 'public' 
            AND constraint_name = 'contacts_user_order_check'
        ) THEN '✅ PASS: Check constraint exists (no duplicates possible)'
        ELSE '❌ FAIL: Check constraint missing (duplicates possible)'
    END as result;

-- ============================================
-- 2. CHECK YOUR CONTACTS
-- ============================================
SELECT 
    '2. YOUR CONTACTS' as check_name,
    COUNT(*) as total_contacts,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ You have ' || COUNT(*) || ' contact(s)'
        ELSE '⚠️ WARNING: You have no contacts (message sending will fail)'
    END as result
FROM public.contacts 
WHERE user_id_1 = auth.uid() OR user_id_2 = auth.uid();

-- ============================================
-- 3. CHECK CHATS WITHOUT CONTACTS
-- ============================================
WITH chat_contact_check AS (
    SELECT 
        c.id as chat_id,
        c.user1_id,
        c.user2_id,
        cnt.id as contact_id
    FROM public.chats c
    LEFT JOIN public.contacts cnt ON (
        cnt.user_id_1 = LEAST(c.user1_id, c.user2_id) AND
        cnt.user_id_2 = GREATEST(c.user1_id, c.user2_id)
    )
    WHERE c.user1_id = auth.uid() OR c.user2_id = auth.uid()
)
SELECT 
    '3. CHATS WITHOUT CONTACTS' as check_name,
    COUNT(*) FILTER (WHERE contact_id IS NULL) as chats_missing_contacts,
    COUNT(*) as total_chats,
    CASE 
        WHEN COUNT(*) FILTER (WHERE contact_id IS NULL) = 0 
        THEN '✅ PASS: All chats have contacts'
        ELSE '❌ FAIL: ' || COUNT(*) FILTER (WHERE contact_id IS NULL) || ' chat(s) missing contacts. Run ensure_chat_contacts() again.'
    END as result
FROM chat_contact_check;

-- ============================================
-- 4. CHECK CAN_SEND_MESSAGE FUNCTION
-- ============================================
SELECT 
    '4. CAN_SEND_MESSAGE FUNCTION' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public' 
            AND p.proname = 'can_send_message'
        ) THEN '✅ PASS: Function exists'
        ELSE '❌ FAIL: Function missing. Re-run MESSAGE_REQUEST_SYSTEM.sql'
    END as result;

-- ============================================
-- 5. CHECK RLS POLICY
-- ============================================
SELECT 
    '5. MESSAGES RLS POLICY' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE schemaname = 'public' 
            AND tablename = 'messages' 
            AND policyname = 'Users can insert messages if they are contacts'
        ) THEN '✅ PASS: Correct RLS policy exists'
        ELSE '❌ FAIL: RLS policy missing or wrong name'
    END as result;

-- ============================================
-- 6. TEST CAN_SEND_MESSAGE (requires another user)
-- ============================================
-- IMPORTANT: Replace 'other-user-id-here' with an actual user ID from your chats
-- SELECT 
--     '6. TEST CAN_SEND_MESSAGE' as check_name,
--     public.can_send_message(
--         auth.uid(), 
--         'other-user-id-here'::UUID
--     ) as can_send,
--     CASE 
--         WHEN public.can_send_message(auth.uid(), 'other-user-id-here'::UUID)
--         THEN '✅ PASS: You can send messages to this user'
--         ELSE '❌ FAIL: Cannot send messages (not contacts)'
--     END as result;

-- ============================================
-- 7. CHECK DUPLICATE CONTACTS (Should be 0)
-- ============================================
WITH duplicate_check AS (
    SELECT 
        user_id_1,
        user_id_2,
        COUNT(*) as duplicate_count
    FROM public.contacts
    GROUP BY user_id_1, user_id_2
    HAVING COUNT(*) > 1
)
SELECT 
    '7. DUPLICATE CONTACTS CHECK' as check_name,
    COUNT(*) as total_duplicates,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ PASS: No duplicate contacts'
        ELSE '❌ FAIL: Found ' || COUNT(*) || ' duplicate(s). Re-run cleanup part of FIX_CONTACTS_AND_MESSAGING.sql'
    END as result
FROM duplicate_check;

-- ============================================
-- SUMMARY OUTPUT
-- ============================================
-- If all checks show ✅ PASS, your system is fixed!
-- If any show ❌ FAIL, follow the instruction in the result column
