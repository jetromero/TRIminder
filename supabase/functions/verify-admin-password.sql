-- Supabase RPC Function to verify admin password securely
-- This function should be created in your Supabase SQL Editor
-- It allows secure password verification without exposing the password hash

CREATE OR REPLACE FUNCTION verify_admin_password(
  p_username TEXT,
  p_password TEXT
)
RETURNS TABLE (
  id BIGINT,
  name TEXT,
  username TEXT,
  department_id INTEGER,
  is_active BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  admin_record RECORD;
BEGIN
  -- Find admin by username
  SELECT * INTO admin_record
  FROM admins
  WHERE username = p_username
    AND is_active = true;
  
  -- If admin not found, return empty
  IF NOT FOUND THEN
    RETURN;
  END IF;
  
  -- Verify password (assuming bcrypt hash)
  -- You'll need to install pgcrypto extension: CREATE EXTENSION IF NOT EXISTS pgcrypto;
  -- Then use: IF crypt(p_password, admin_record.password) = admin_record.password THEN
  -- For now, this is a placeholder - adjust based on your password hashing method
  
  -- If passwords match (you'll need to implement proper hashing comparison)
  -- For Laravel-style bcrypt, you might need a different approach
  -- This is a template - adjust based on your actual password storage method
  
  RETURN QUERY
  SELECT 
    admin_record.id,
    admin_record.name,
    admin_record.username,
    admin_record.department_id,
    admin_record.is_active
  WHERE admin_record.password = crypt(p_password, admin_record.password);
  
  -- Update last login on successful verification
  IF FOUND THEN
    UPDATE admins
    SET last_login_at = NOW()
    WHERE id = admin_record.id;
  END IF;
END;
$$;

-- Note: If your passwords are stored with Laravel's bcrypt, you may need to:
-- 1. Use a Supabase Edge Function (JavaScript) instead
-- 2. Or create a custom comparison function
-- 3. Or use a different approach based on your password hashing method

