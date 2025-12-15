-- Server Deletion with 24-hour Timer
-- This allows server owners to schedule server deletion with a 24-hour countdown

-- 1. Add deletion_scheduled_at column to servers table
ALTER TABLE servers 
ADD COLUMN IF NOT EXISTS deletion_scheduled_at TIMESTAMPTZ;

-- 2. Add deletion_scheduled_by column to track who scheduled the deletion
ALTER TABLE servers 
ADD COLUMN IF NOT EXISTS deletion_scheduled_by UUID REFERENCES auth.users(id);

-- 3. Create function to schedule server deletion
CREATE OR REPLACE FUNCTION schedule_server_deletion(p_server_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_deletion_time TIMESTAMPTZ;
BEGIN
  -- Get current user
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  -- Check if user is server owner
  SELECT role INTO v_user_role
  FROM server_members
  WHERE server_id = p_server_id AND user_id = v_user_id;

  IF v_user_role != 'owner' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Only server owners can delete servers');
  END IF;

  -- Calculate deletion time (24 hours from now)
  v_deletion_time := NOW() + INTERVAL '24 hours';

  -- Update server with deletion schedule
  UPDATE servers
  SET 
    deletion_scheduled_at = v_deletion_time,
    deletion_scheduled_by = v_user_id,
    updated_at = NOW()
  WHERE id = p_server_id;

  RETURN jsonb_build_object(
    'success', true, 
    'message', 'Server deletion scheduled',
    'deletion_at', v_deletion_time
  );
END;
$$;

-- 4. Create function to cancel server deletion
CREATE OR REPLACE FUNCTION cancel_server_deletion(p_server_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
BEGIN
  -- Get current user
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  -- Check if user is server owner
  SELECT role INTO v_user_role
  FROM server_members
  WHERE server_id = p_server_id AND user_id = v_user_id;

  IF v_user_role != 'owner' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Only server owners can cancel deletion');
  END IF;

  -- Remove deletion schedule
  UPDATE servers
  SET 
    deletion_scheduled_at = NULL,
    deletion_scheduled_by = NULL,
    updated_at = NOW()
  WHERE id = p_server_id;

  RETURN jsonb_build_object('success', true, 'message', 'Server deletion cancelled');
END;
$$;

-- 5. Create function to execute scheduled deletions (should be run by a cron job)
CREATE OR REPLACE FUNCTION execute_scheduled_server_deletions()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_count INTEGER := 0;
  v_server RECORD;
BEGIN
  -- Find all servers scheduled for deletion that are past their deletion time
  FOR v_server IN 
    SELECT id 
    FROM servers 
    WHERE deletion_scheduled_at IS NOT NULL 
    AND deletion_scheduled_at <= NOW()
  LOOP
    -- Delete server members first (foreign key constraint)
    DELETE FROM server_members WHERE server_id = v_server.id;
    
    -- Delete server invites
    DELETE FROM server_invites WHERE server_id = v_server.id;
    
    -- Delete server messages
    DELETE FROM server_messages WHERE server_id = v_server.id;
    
    -- Delete the server itself
    DELETE FROM servers WHERE id = v_server.id;
    
    v_deleted_count := v_deleted_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true, 
    'deleted_count', v_deleted_count
  );
END;
$$;

-- 6. Grant execute permissions
GRANT EXECUTE ON FUNCTION schedule_server_deletion TO authenticated;
GRANT EXECUTE ON FUNCTION cancel_server_deletion TO authenticated;
GRANT EXECUTE ON FUNCTION execute_scheduled_server_deletions TO service_role;

-- Note: You need to set up a Supabase Edge Function or external cron job 
-- to call execute_scheduled_server_deletions() periodically (e.g., every hour)
