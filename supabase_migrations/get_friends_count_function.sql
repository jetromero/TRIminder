-- Migration: Create function to get friends count for any user
-- This function bypasses RLS to count friendships (but doesn't expose friend identities)
-- Run this in Supabase SQL Editor

-- Create function to get friends count for a specific user
-- Uses SECURITY DEFINER to bypass RLS for counting purposes only
CREATE OR REPLACE FUNCTION get_user_friends_count(target_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  friend_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO friend_count
  FROM friendships
  WHERE status = 'accepted'
    AND (user_a_id = target_user_id OR user_b_id = target_user_id);
  
  RETURN COALESCE(friend_count, 0);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_user_friends_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_friends_count(UUID) TO anon;

-- Add comment for documentation
COMMENT ON FUNCTION get_user_friends_count(UUID) IS 'Returns the count of accepted friendships for a user. Bypasses RLS to allow viewing friend counts without exposing friend identities.';

