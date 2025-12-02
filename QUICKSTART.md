# Quick Start Guide

## 🚀 Get Started in 5 Minutes

### Step 1: Install Dependencies

```bash
npm install
```

### Step 2: Set Up Environment Variables

Create a `.env` file in the root directory:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
```

**Where to find these:**

- Go to your Supabase project dashboard
- Navigate to Settings > API
- Copy the Project URL and anon/public key

### Step 3: Create an Admin User

> **Note:** RLS (Row Level Security) is optional and can be skipped for now. The app will work without RLS policies, though they provide additional security. You can set them up later if needed (see `DEPLOYMENT.md`).

The dashboard uses the `admins` table for authentication. Create an admin user:

**Insert into admins table:**

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
  'your_password_here',  -- Note: If using hashed passwords, hash it first
  NULL,  -- NULL = super_admin, set department_id for sub_admin
  true
);
```

**Important:**

- If your passwords are stored as plain text, the current implementation will work
- If passwords are hashed (e.g., bcrypt from Laravel), you'll need to implement secure password verification using a Supabase Edge Function (see `supabase/functions/verify-admin-password.sql`)
- For production, always use hashed passwords and server-side verification

### Step 4: Run the App

```bash
npm run dev
```

Visit `http://localhost:5173` and log in with your admin credentials!

## 📋 Checklist

- [ ] Dependencies installed (`npm install`)
- [ ] `.env` file created with Supabase credentials
- [ ] At least one admin user created
- [ ] App running locally (`npm run dev`)
- [ ] (Optional) RLS policies set up in Supabase

## 🔧 Common Issues

### "Missing Supabase environment variables"

- Check that `.env` file exists in root directory
- Verify variable names start with `VITE_`
- Restart dev server after creating `.env`

### "Access denied" on login

- Verify admin exists in `admins` table
- Check that `username` matches exactly (case-sensitive)
- Ensure `is_active` is `true`
- Verify password matches (if using hashed passwords, ensure proper verification)

### "Failed to fetch data"

- Check Supabase project URL and key are correct
- Verify tables exist and are accessible
- Check browser console for specific errors

## 📚 Next Steps

- Read `README.md` for full documentation
- Check `DEPLOYMENT.md` for production deployment
- Explore the codebase structure in `README.md`

## 🆘 Need Help?

1. Check browser console for errors
2. Verify Supabase connection
3. Check environment variables
4. Ensure admin user is properly set up
