-- Migration: Create function to delete user account including auth.users entry
-- This function allows users to delete their own account
-- Run this in your Supabase SQL Editor

-- Create the function that deletes the auth user
CREATE OR REPLACE FUNCTION delete_user_account(user_id_to_delete UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER -- This allows the function to run with elevated privileges
AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  -- Verify that the user is deleting their own account
  -- This prevents users from deleting other users' accounts
  -- Note: auth.uid() might be null if called after profile deletion, so we check it first
  IF auth.uid() IS NOT NULL AND auth.uid() != user_id_to_delete THEN
    RAISE EXCEPTION 'You can only delete your own account';
  END IF;

  -- Check if user exists before attempting deletion
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = user_id_to_delete) THEN
    -- User doesn't exist, consider it already deleted
    RETURN TRUE;
  END IF;

  -- Delete from auth.users (this requires SECURITY DEFINER)
  DELETE FROM auth.users WHERE id = user_id_to_delete;
  
  -- Get the number of rows deleted
  GET DIAGNOSTICS deleted_count = ROW_COUNT;

  -- Return true if deletion was successful (at least one row deleted)
  IF deleted_count > 0 THEN
    RETURN TRUE;
  ELSE
    -- No rows deleted, user might not exist
    RETURN FALSE;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    -- Log the error and return false
    RAISE WARNING 'Error deleting auth user %: %', user_id_to_delete, SQLERRM;
    RETURN FALSE;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user_account(UUID) TO authenticated;

-- Add a comment explaining the function
COMMENT ON FUNCTION delete_user_account(UUID) IS 
'Deletes a user account including the auth.users entry. Users can only delete their own account.';

