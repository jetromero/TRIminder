# TRIminder Admin Dashboard

A modern, compact web dashboard for managing TRIminder mobile app data. Built with React, TypeScript, TailwindCSS, and Supabase.

## Features

- 🔐 **Authentication** - Secure admin login with Supabase Auth
- 👥 **Role-Based Access** - Super Admin and Department Admin roles
- 📊 **Analytics Dashboard** - Comprehensive insights and metrics
- 👤 **Student Management** - View and manage student profiles
- 🏢 **Department Management** - CRUD operations for departments (Super Admin only)
- 👨‍💼 **Admin Management** - CRUD operations for admin accounts (Super Admin only)
- 📈 **Charts & Visualizations** - Usage trends, XP distribution, and more

## Tech Stack

- **Frontend**: React 18 + TypeScript
- **Styling**: TailwindCSS (no Bootstrap)
- **Backend**: Supabase
- **Charts**: Recharts
- **Routing**: React Router v6
- **Build Tool**: Vite
- **Deployment**: Netlify

## Project Structure

```
src/
├── components/
│   ├── layout/
│   │   ├── Sidebar.tsx
│   │   └── Topbar.tsx
│   └── ui/
│       ├── Button.tsx
│       ├── Input.tsx
│       ├── Select.tsx
│       ├── Table.tsx
│       ├── CardStat.tsx
│       ├── Modal.tsx
│       ├── ChartLine.tsx
│       └── ChartBar.tsx
├── contexts/
│   └── AuthContext.tsx
├── hooks/
│   └── useAuth.ts
├── lib/
│   ├── supabaseClient.ts
│   └── api/
│       ├── admins.ts
│       ├── departments.ts
│       ├── students.ts
│       └── analytics.ts
├── pages/
│   ├── Login.tsx
│   ├── Dashboard.tsx
│   ├── Admins.tsx
│   ├── Departments.tsx
│   ├── Students.tsx
│   ├── StudentDetail.tsx
│   └── Analytics.tsx
├── types/
│   ├── database.ts
│   └── auth.ts
├── App.tsx
├── main.tsx
└── index.css
```

## Setup

### Prerequisites

- Node.js 18+ and npm
- Supabase account and project
- Netlify account (for deployment)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd triminder-web-dashboard
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env` file in the root directory:
```env
VITE_SUPABASE_URL=your_supabase_project_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

4. Start the development server:
```bash
npm run dev
```

The app will be available at `http://localhost:5173`

## Supabase Setup

### Database Schema

The dashboard uses the following Supabase tables:
- `profiles` - User profiles with roles (student, sub_admin, super_admin)
- `admins` - Admin accounts
- `departments` - Department information
- `user_usage_daily` - Daily screen time usage
- `screen_time_logs` - Detailed screen time logs
- `user_badges` - User badge assignments
- `xp_award_history` - XP award history
- `badges` - Badge definitions

### Row Level Security (RLS) Policies - OPTIONAL

> **Note:** RLS is optional and can be skipped for now. The dashboard will work without RLS policies. However, RLS provides important security by restricting data access based on user roles. It's recommended to set up RLS before deploying to production.

If you want to set up RLS for additional security, create the following RLS policies in Supabase:

#### Profiles Table
```sql
-- Super admins can access all profiles
CREATE POLICY "Super admins can access all profiles"
ON profiles FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  )
);

-- Department admins can only access students in their department
CREATE POLICY "Department admins can access their department students"
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

#### User Usage Daily Table
```sql
-- Super admins can access all usage data
CREATE POLICY "Super admins can access all usage"
ON user_usage_daily FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  )
);

-- Department admins can access usage for their department students
CREATE POLICY "Department admins can access department usage"
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

#### Screen Time Logs Table
```sql
-- Similar policies as user_usage_daily
CREATE POLICY "Super admins can access all screen time logs"
ON screen_time_logs FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  )
);

CREATE POLICY "Department admins can access department screen time logs"
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

#### Admins Table
```sql
-- Only super admins can manage admins
CREATE POLICY "Super admins can manage admins"
ON admins FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  )
);
```

#### Departments Table
```sql
-- Only super admins can manage departments
CREATE POLICY "Super admins can manage departments"
ON departments FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  )
);
```

### Authentication Setup

1. In Supabase Dashboard, go to Authentication > Settings
2. Enable Email provider
3. Configure email templates if needed
4. Create admin users in the `profiles` table with `role = 'super_admin'` or `role = 'sub_admin'`
5. Ensure these users exist in Supabase Auth (they should be created when they sign up via the Flutter app)

## Deployment to Netlify

### Method 1: Netlify CLI

1. Install Netlify CLI:
```bash
npm install -g netlify-cli
```

2. Build the project:
```bash
npm run build
```

3. Deploy:
```bash
netlify deploy --prod
```

### Method 2: Netlify Dashboard

1. Push your code to a Git repository (GitHub, GitLab, or Bitbucket)

2. Go to [Netlify Dashboard](https://app.netlify.com)

3. Click "Add new site" > "Import an existing project"

4. Connect your Git repository

5. Configure build settings:
   - **Build command**: `npm run build`
   - **Publish directory**: `dist`
   - **Node version**: 18 (or latest LTS)

6. Add environment variables:
   - Go to Site settings > Environment variables
   - Add:
     - `VITE_SUPABASE_URL` = your Supabase project URL
     - `VITE_SUPABASE_ANON_KEY` = your Supabase anon key

7. Deploy!

### Netlify Configuration

The `netlify.toml` file is already configured with:
- Build command: `npm run build`
- Publish directory: `dist`
- Redirect rules for SPA routing (all routes redirect to `index.html`)

## Usage

### Super Admin

- Access to all features
- Can manage admins and departments
- Can view all students across all departments
- Can view global analytics

### Department Admin

- Limited to their assigned department
- Can view students in their department only
- Can view department-level analytics
- Cannot manage admins or departments

## Development

### Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run preview` - Preview production build
- `npm run lint` - Run ESLint

### Code Style

- TypeScript strict mode enabled
- TailwindCSS for all styling (no Bootstrap)
- Compact, minimal UI design
- Reusable components in `components/ui/`
- API utilities in `lib/api/`

## Troubleshooting

### Authentication Issues

- Verify admin users have the correct role in the `profiles` table (`super_admin` or `sub_admin`)
- Check that users exist in Supabase Auth
- Ensure user email matches between Auth and profiles table
- (If using RLS) Ensure RLS policies are correctly set up

### Build Issues

- Ensure all environment variables are set
- Check Node.js version (18+ required)
- Clear `node_modules` and reinstall if needed

### Deployment Issues

- Verify environment variables in Netlify dashboard
- Check build logs for errors
- Ensure `netlify.toml` is in the root directory

## License

[Your License Here]

