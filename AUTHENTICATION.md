# Authentication System

## Overview

The dashboard uses the `admins` table for authentication instead of the `profiles` table. This design decision was made to align with your existing database schema where admin accounts are stored separately.

## Why `admins` Table Instead of `profiles`?

### Original Design (Profiles Table)

- Used Supabase Auth (`auth.users`)
- Required users to exist in both `auth.users` and `profiles` tables
- Leveraged Supabase's built-in authentication features
- Worked well with RLS policies using `auth.uid()`

### Current Design (Admins Table)

- Uses the `admins` table directly
- No dependency on Supabase Auth
- Aligns with your existing schema structure
- Simpler setup (no need to create users in `auth.users`)

## How It Works

1. **Login**: User enters `username` and `password`
2. **Verification**: System queries `admins` table by username
3. **Password Check**: Compares provided password with stored password
4. **Session**: Stores admin info in localStorage
5. **Role Determination**:
   - `department_id = NULL` → `super_admin`
   - `department_id != NULL` → `sub_admin`

## Password Security

### Current Implementation

The current code does a simple password comparison:

```typescript
const passwordMatch = admin.password === password;
```

**This works if:**

- Passwords are stored as plain text (development/testing only)
- You implement client-side hashing

**This does NOT work securely if:**

- Passwords are hashed (e.g., bcrypt from Laravel)
- You need production-grade security

### Secure Password Verification

If your passwords are hashed (recommended for production), you have two options:

#### Option 1: Supabase Edge Function (Recommended)

Create a Supabase Edge Function that verifies passwords server-side:

```typescript
// supabase/functions/verify-admin/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { username, password } = await req.json()

  // Query admin
  const supabase = createClient(...)
  const { data: admin } = await supabase
    .from('admins')
    .select('*')
    .eq('username', username)
    .single()

  // Verify password using bcrypt or your hashing method
  const isValid = await verifyPassword(password, admin.password)

  if (isValid) {
    return new Response(JSON.stringify({ success: true, admin }))
  }

  return new Response(JSON.stringify({ success: false }))
})
```

#### Option 2: Supabase RPC Function

See `supabase/functions/verify-admin-password.sql` for a PostgreSQL function template.

#### Option 3: Client-Side Hashing (Less Secure)

If you must hash client-side, use a library like `bcryptjs`:

```bash
npm install bcryptjs @types/bcryptjs
```

```typescript
import bcrypt from "bcryptjs";

const passwordMatch = await bcrypt.compare(password, admin.password);
```

**Note:** Client-side hashing is less secure because the hash algorithm is exposed.

## Creating Admin Users

```sql
INSERT INTO admins (
  name,
  username,
  password,
  department_id,
  is_active
) VALUES (
  'Super Admin',
  'admin',
  'your_password',  -- Plain text or pre-hashed
  NULL,  -- NULL = super_admin
  true
);
```

## Session Management

- **Storage**: localStorage (key: `triminder_admin_session`)
- **Data Stored**: Admin ID, username, role, department_id
- **Persistence**: Survives page refresh
- **Logout**: Clears localStorage

## Migration from Profiles to Admins

If you were using the profiles table before:

1. Create admin users in the `admins` table
2. The code has already been updated to use `admins`
3. No migration needed - just create new admin accounts

## Security Considerations

1. **Password Storage**: Always hash passwords before storing
2. **Password Verification**: Use server-side verification (Edge Function/RPC)
3. **Session Security**: Consider using httpOnly cookies instead of localStorage
4. **HTTPS**: Always use HTTPS in production
5. **Rate Limiting**: Implement login attempt limits

## Troubleshooting

### "Invalid username or password"

- Check username spelling (case-sensitive)
- Verify admin exists and `is_active = true`
- If using hashed passwords, ensure verification is implemented

### Session not persisting

- Check browser localStorage is enabled
- Verify no browser extensions blocking localStorage
- Check console for errors

### Role not working correctly

- Verify `department_id` is NULL for super_admin
- Check role determination logic in `AuthContext.tsx`
