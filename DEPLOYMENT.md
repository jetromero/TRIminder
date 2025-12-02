# Deployment Guide

## Prerequisites

- Supabase project with database schema set up
- Netlify account
- Git repository (GitHub, GitLab, or Bitbucket)

## Step 1: Supabase Configuration

### 1.1 Get Your Supabase Credentials

1. Go to your Supabase project dashboard
2. Navigate to Settings > API
3. Copy the following:
   - **Project URL** (e.g., `https://xxxxx.supabase.co`)
   - **anon/public key** (starts with `eyJ...`)

### 1.2 Set Up Row Level Security (RLS) - OPTIONAL

> **Note:** RLS is optional and can be skipped for now. The dashboard will work without RLS policies. However, RLS provides important security by restricting data access based on user roles. It's recommended to set up RLS before deploying to production.

If you want to set up RLS for additional security, execute the following SQL policies in your Supabase SQL Editor:

#### Enable RLS on Tables

```sql
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_usage_daily ENABLE ROW LEVEL SECURITY;
ALTER TABLE screen_time_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE xp_award_history ENABLE ROW LEVEL SECURITY;
```

#### Profiles Policies

```sql
-- Super admins can access all profiles
CREATE POLICY "super_admin_all_profiles"
ON profiles FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  )
);

-- Department admins can access students in their department
CREATE POLICY "dept_admin_department_students"
ON profiles FOR SELECT
TO authenticated
USING (
  role = 'student' AND
  department_id = (
    SELECT department_id FROM profiles
    WHERE id = auth.uid() AND role IN ('sub_admin', 'super_admin')
  )
);
```

#### User Usage Daily Policies

```sql
-- Super admins can access all usage
CREATE POLICY "super_admin_all_usage"
ON user_usage_daily FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  )
);

-- Department admins can access department usage
CREATE POLICY "dept_admin_department_usage"
ON user_usage_daily FOR SELECT
TO authenticated
USING (
  user_id IN (
    SELECT id FROM profiles
    WHERE role = 'student' AND department_id = (
      SELECT department_id FROM profiles
      WHERE id = auth.uid() AND role IN ('sub_admin', 'super_admin')
    )
  )
);
```

#### Screen Time Logs Policies

```sql
-- Super admins can access all logs
CREATE POLICY "super_admin_all_logs"
ON screen_time_logs FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  )
);

-- Department admins can access department logs
CREATE POLICY "dept_admin_department_logs"
ON screen_time_logs FOR SELECT
TO authenticated
USING (
  user_id IN (
    SELECT id FROM profiles
    WHERE role = 'student' AND department_id = (
      SELECT department_id FROM profiles
      WHERE id = auth.uid() AND role IN ('sub_admin', 'super_admin')
    )
  )
);
```

#### Admins Table Policies

```sql
-- Only super admins can manage admins
CREATE POLICY "super_admin_manage_admins"
ON admins FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  )
);
```

#### Departments Table Policies

```sql
-- Only super admins can manage departments
CREATE POLICY "super_admin_manage_departments"
ON departments FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  )
);

-- All authenticated admins can read departments
CREATE POLICY "admins_read_departments"
ON departments FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role IN ('sub_admin', 'super_admin')
  )
);
```

### 1.3 Create Admin Users

Admin users must:

1. Exist in Supabase Auth (created via Flutter app or manually)
2. Have a corresponding entry in the `profiles` table with `role = 'super_admin'` or `role = 'sub_admin'`

To create an admin user manually:

```sql
-- First, create the user in Supabase Auth (via dashboard or API)
-- Then, insert into profiles table:

INSERT INTO profiles (
  id,
  email,
  role,
  department_id,
  first_name,
  last_name,
  user_tag,
  xp
) VALUES (
  'user-uuid-from-auth',
  'admin@example.com',
  'super_admin',  -- or 'sub_admin'
  NULL,  -- NULL for super_admin, department_id for sub_admin
  'Admin',
  'User',
  'admin001',
  0
);
```

## Step 2: Local Environment Setup

### 2.1 Create `.env` File

Create a `.env` file in the project root:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
```

### 2.2 Test Locally

```bash
npm install
npm run dev
```

Visit `http://localhost:5173` and test the login functionality.

## Step 3: Deploy to Netlify

### Option A: Deploy via Netlify Dashboard (Recommended)

1. **Push to Git Repository**

   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin <your-repo-url>
   git push -u origin main
   ```

2. **Connect to Netlify**

   - Go to [Netlify Dashboard](https://app.netlify.com)
   - Click "Add new site" > "Import an existing project"
   - Connect your Git provider (GitHub, GitLab, Bitbucket)
   - Select your repository

3. **Configure Build Settings**

   - **Build command**: `npm run build`
   - **Publish directory**: `dist`
   - **Node version**: 18 (or latest LTS)

4. **Add Environment Variables**

   - Go to Site settings > Environment variables
   - Click "Add variable"
   - Add:
     - Key: `VITE_SUPABASE_URL`
     - Value: Your Supabase project URL
   - Add:
     - Key: `VITE_SUPABASE_ANON_KEY`
     - Value: Your Supabase anon key

5. **Deploy**
   - Click "Deploy site"
   - Wait for build to complete
   - Your site will be live at `https://your-site.netlify.app`

### Option B: Deploy via Netlify CLI

1. **Install Netlify CLI**

   ```bash
   npm install -g netlify-cli
   ```

2. **Login to Netlify**

   ```bash
   netlify login
   ```

3. **Initialize Netlify**

   ```bash
   netlify init
   ```

   - Choose "Create & configure a new site"
   - Select your team
   - Choose a site name (or use default)

4. **Set Environment Variables**

   ```bash
   netlify env:set VITE_SUPABASE_URL "https://your-project.supabase.co"
   netlify env:set VITE_SUPABASE_ANON_KEY "your-anon-key"
   ```

5. **Build and Deploy**
   ```bash
   npm run build
   netlify deploy --prod
   ```

## Step 4: Post-Deployment

### 4.1 Verify Deployment

1. Visit your Netlify site URL
2. Test login with an admin account
3. Verify all pages load correctly
4. Test role-based access (super admin vs department admin)

### 4.2 Configure Custom Domain (Optional)

1. Go to Site settings > Domain management
2. Add your custom domain
3. Follow Netlify's DNS configuration instructions

### 4.3 Set Up Continuous Deployment

Netlify automatically deploys when you push to your main branch. To configure:

1. Go to Site settings > Build & deploy
2. Configure branch settings:
   - Production branch: `main` (or your default branch)
   - Build command: `npm run build`
   - Publish directory: `dist`

## Step 5: Troubleshooting

### Build Fails

- Check build logs in Netlify dashboard
- Verify Node.js version (should be 18+)
- Ensure all dependencies are in `package.json`
- Check for TypeScript errors: `npm run build` locally

### Environment Variables Not Working

- Verify variables are set in Netlify dashboard
- Ensure variable names start with `VITE_`
- Redeploy after adding/changing variables

### Authentication Issues

- Check admin user exists in both Auth and profiles table
- Ensure user role is `super_admin` or `sub_admin`
- Verify user email matches between Auth and profiles table
- (If using RLS) Verify RLS policies are set up correctly

### Routing Issues (404 on Refresh)

- Verify `netlify.toml` exists in root directory
- Check redirect rules are configured:
  ```toml
  [[redirects]]
    from = "/*"
    to = "/index.html"
    status = 200
  ```

### CORS Issues

- Supabase automatically handles CORS for web apps
- If issues occur, check Supabase project settings
- Verify allowed origins in Supabase dashboard

## Security Checklist

- [ ] Environment variables are set in Netlify (not committed to Git)
- [ ] Admin users have correct roles in database
- [ ] `.env` file is in `.gitignore`
- [ ] Supabase anon key is safe to expose (it's public by design)
- [ ] Custom domain has SSL enabled (automatic with Netlify)
- [ ] (Optional but recommended) RLS policies are enabled on all tables

## Support

For issues:

1. Check Netlify build logs
2. Check browser console for errors
3. Verify Supabase connection
4. Check environment variables
5. Verify admin user setup
6. (If using RLS) Review RLS policies
