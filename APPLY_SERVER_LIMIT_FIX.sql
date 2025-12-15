-- ============================================================================
-- FIX: Server Creation Limit Per-User Issue
-- ============================================================================
-- Apply the improved can_create_server() function with explicit user validation

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

-- Verification query to check server counts per user
SELECT 
  auth.users.id as user_id,
  auth.users.email,
  COUNT(servers.id) as owned_servers,
  can_create_server(auth.users.id) as can_create_new
FROM auth.users
LEFT JOIN servers ON servers.owner_id = auth.users.id AND servers.deleted_at IS NULL
GROUP BY auth.users.id, auth.users.email
ORDER BY auth.users.email;
