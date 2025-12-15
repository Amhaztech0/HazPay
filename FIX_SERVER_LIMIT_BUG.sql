-- ============================================================================
-- FIX: Server Creation Limit Per-User Issue
-- ============================================================================
-- The issue: can_create_server() function doesn't account for authentication
-- context properly across multiple users on the same device
-- 
-- Root Cause: The RPC function checks owner_id correctly, but may have 
-- caching issues when called from same device with different auth sessions

-- ============================================================================
-- STEP 1: Verify Current Function Logic (CORRECT)
-- ============================================================================
-- The function logic is CORRECT:
-- - It counts servers where owner_id = p_user_id
-- - Returns TRUE if count < 2 (can create more)
-- - Returns FALSE if count >= 2 (cannot create more)

-- ============================================================================
-- STEP 2: Verify RPC is Receiving Correct User ID
-- ============================================================================
-- Add this test to verify the user_id being passed is correct:

-- Test query to see server counts per user:
SELECT 
  owner_id,
  COUNT(*) as server_count,
  CASE 
    WHEN COUNT(*) < 2 THEN 'Can create'
    ELSE 'Cannot create'
  END as can_create_status
FROM servers
GROUP BY owner_id
ORDER BY owner_id;

-- ============================================================================
-- STEP 3: Real Issue - Authentication Token Caching
-- ============================================================================
-- SOLUTION: The issue is likely that:
-- 1. Same device uses cached HTTP session
-- 2. Device ID might be cached in Supabase auth headers
-- 3. The auth.uid() context isn't refreshing properly

-- FIX: Ensure you're FULLY logging out before switching accounts:
-- Don't just switch accounts - completely sign out, clear app cache, then log in

-- ============================================================================
-- STEP 4: Improved Function with Explicit User Validation
-- ============================================================================
-- Replace the existing function with this safer version:

DROP FUNCTION IF EXISTS can_create_server(UUID) CASCADE;

CREATE OR REPLACE FUNCTION can_create_server(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_server_count INTEGER;
    v_user_exists BOOLEAN;
BEGIN
    -- First, verify the user exists and is authenticated
    SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = p_user_id)
    INTO v_user_exists;
    
    IF NOT v_user_exists THEN
        -- User doesn't exist - deny server creation
        RETURN FALSE;
    END IF;
    
    -- Count OWNED servers (not member of, but owner_id = user)
    SELECT COUNT(*) INTO v_server_count
    FROM servers
    WHERE owner_id = p_user_id
      AND deleted_at IS NULL;  -- Exclude soft-deleted servers
    
    -- Return TRUE if less than 2, FALSE if 2 or more
    RETURN v_server_count < 2;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION can_create_server(UUID) TO authenticated;

-- ============================================================================
-- STEP 5: Test the Fixed Function
-- ============================================================================
-- Test with a specific user ID:
-- SELECT can_create_server('YOUR-USER-ID-HERE');

-- Test all users:
SELECT 
  auth.users.id as user_id,
  auth.users.email,
  COUNT(servers.id) as owned_servers,
  can_create_server(auth.users.id) as can_create_new
FROM auth.users
LEFT JOIN servers ON servers.owner_id = auth.users.id AND servers.deleted_at IS NULL
GROUP BY auth.users.id, auth.users.email
ORDER BY auth.users.email;

-- ============================================================================
-- STEP 6: Dart-Side Fix - Force Fresh Auth Check
-- ============================================================================
-- In create_server_screen.dart, ensure you're getting fresh auth state:
-- 
-- BEFORE calling canCreateServer(), add:
-- await supabase.auth.refreshSession();  // Refresh auth token
--
-- This ensures the RPC receives the correct user_id

-- ============================================================================
-- DEPLOYMENT
-- ============================================================================
-- 1. Run SQL above (steps 4+)
-- 2. Update Dart code with refreshSession() before canCreateServer()
-- 3. Test: Log out completely, Log in with second account, Try creating server
-- 4. Verify can_create_server() receives correct p_user_id parameter
