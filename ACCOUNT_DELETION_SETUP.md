# Account Deletion Setup Instructions

## Problem
The account deletion feature deletes user data from all tables, but the auth account in `auth.users` remains, allowing users to log back in.

## Solution
Create a database function in Supabase that can delete the auth account. This function uses `SECURITY DEFINER` to run with elevated privileges.

## Setup Steps

### 1. Open Supabase SQL Editor
1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor** in the left sidebar
3. Click **New Query**

### 2. Run the Migration SQL
Copy and paste the contents of `supabase_migrations/delete_user_account_function.sql` into the SQL Editor and click **Run**.

**Important**: If you already created this function before, you should re-run the SQL to update it with the latest version that handles edge cases better.

Alternatively, you can copy this SQL directly:

```sql
-- Create the function that deletes the auth user
CREATE OR REPLACE FUNCTION delete_user_account(user_id_to_delete UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER -- This allows the function to run with elevated privileges
AS $$
BEGIN
  -- Verify that the user is deleting their own account
  -- This prevents users from deleting other users' accounts
  IF auth.uid() != user_id_to_delete THEN
    RAISE EXCEPTION 'You can only delete your own account';
  END IF;

  -- Delete from auth.users (this requires SECURITY DEFINER)
  DELETE FROM auth.users WHERE id = user_id_to_delete;

  -- Return true if deletion was successful
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    -- Log the error and return false
    RAISE WARNING 'Error deleting auth user: %', SQLERRM;
    RETURN FALSE;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user_account(UUID) TO authenticated;

-- Add a comment explaining the function
COMMENT ON FUNCTION delete_user_account(UUID) IS 
'Deletes a user account including the auth.users entry. Users can only delete their own account.';
```

### 3. Verify the Function Was Created
After running the SQL, verify the function exists:
1. Go to **Database** → **Functions** in Supabase dashboard
2. You should see `delete_user_account` listed

### 4. Test Account Deletion
1. Try deleting an account from the app
2. Check that the user can no longer log in
3. Verify in Supabase dashboard that the user is removed from `auth.users`

## Security Notes

- The function uses `SECURITY DEFINER` to run with elevated privileges
- It includes a security check: `IF auth.uid() != user_id_to_delete` to prevent users from deleting other accounts
- Only authenticated users can execute this function
- The function will return an error if a user tries to delete someone else's account

## Troubleshooting

### Error: "function delete_user_account does not exist"
- Make sure you ran the SQL migration in the Supabase SQL Editor
- Check that the function appears in Database → Functions

### Error: "permission denied"
- Verify that `GRANT EXECUTE` was run successfully
- Check that the user is authenticated when calling the function

### User can still log in after deletion
- Check Supabase logs to see if the RPC call succeeded
- Verify the function is being called (check app logs)
- Manually check if the user exists in `auth.users` table

## Alternative: Manual Deletion
If you need to manually delete a user's auth account:
1. Go to Supabase Dashboard → Authentication → Users
2. Find the user
3. Click the three dots menu → Delete user

