# Supabase Storage Setup Guide

This guide will help you set up the required Supabase Storage buckets for the TRIminder app's profile features (avatars and cover photos).

## Prerequisites

- Access to your Supabase project dashboard
- Admin access to configure storage buckets

## Step 0: Add Database Columns (IMPORTANT!)

**Before setting up storage, you must add the new columns to your `profiles` table.**

1. Go to **SQL Editor** in your Supabase dashboard
2. Click **New Query**
3. Copy and paste the SQL from `supabase_migrations/add_profile_fields.sql`:

```sql
-- Add avatar_url column
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Add cover_photo_url column
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS cover_photo_url TEXT;

-- Add bio column (max 500 characters)
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS bio TEXT;

-- Optional: Add check constraint for bio length
-- (The app validates this in code, so this is optional)
-- ALTER TABLE profiles 
-- ADD CONSTRAINT bio_length_check 
-- CHECK (bio IS NULL OR LENGTH(bio) <= 500);
```

4. Click **Run** (or press Ctrl+Enter)

**If you skip this step, you'll get "failed to update profile" errors!**

## Step 1: Create Storage Buckets

1. **Log in to Supabase Dashboard**
   - Go to https://app.supabase.com
   - Select your TRIminder project

2. **Navigate to Storage**
   - Click on "Storage" in the left sidebar
   - You should see the Storage management interface

3. **Create the `avatars` Bucket**
   - Click "New bucket" button
   - Bucket name: `avatars` (exactly as shown, lowercase)
   - Make it **Public**: ✅ Check the "Public bucket" checkbox
   - Click "Create bucket"

4. **Create the `cover-photos` Bucket**
   - Click "New bucket" button again
   - Bucket name: `cover-photos` (exactly as shown, lowercase with hyphen)
   - Make it **Public**: ✅ Check the "Public bucket" checkbox
   - Click "Create bucket"

## Step 2: Configure Bucket Policies (RLS)

**IMPORTANT:** Use the Supabase SQL Editor to run these policies, NOT the policy form editor.

1. Go to **SQL Editor** in your Supabase dashboard (left sidebar)
2. Click **New Query**
3. Copy and paste the SQL below
4. Click **Run** (or press Ctrl+Enter)

### For `avatars` bucket:

Run this SQL in the SQL Editor:

```sql
-- Allow authenticated users to upload their own avatar
CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars' AND 
  name = (auth.uid()::text || '.jpg')
);

-- Allow everyone to read avatars (public bucket)
CREATE POLICY "Public avatar access"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- Allow users to update their own avatar
CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'avatars' AND 
  name = (auth.uid()::text || '.jpg')
);

-- Allow users to delete their own avatar
CREATE POLICY "Users can delete own avatar"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'avatars' AND 
  name = (auth.uid()::text || '.jpg')
);
```

### For `cover-photos` bucket:

Run this SQL in the SQL Editor:

```sql
-- Allow authenticated users to upload their own cover photo
CREATE POLICY "Users can upload own cover photo"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'cover-photos' AND 
  name = (auth.uid()::text || '.jpg')
);

-- Allow everyone to read cover photos (public bucket)
CREATE POLICY "Public cover photo access"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'cover-photos');

-- Allow users to update their own cover photo
CREATE POLICY "Users can update own cover photo"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'cover-photos' AND 
  name = (auth.uid()::text || '.jpg')
);

-- Allow users to delete their own cover photo
CREATE POLICY "Users can delete own cover photo"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'cover-photos' AND 
  name = (auth.uid()::text || '.jpg')
);
```

## Alternative: Simplified Public Access (For Testing)

If you want to simplify for testing purposes, you can create policies that allow all authenticated users to upload/update/delete any file. **Run this in the SQL Editor:**

**For `avatars` bucket:**
```sql
-- Allow all authenticated users full access (for testing)
CREATE POLICY "Authenticated users full access avatars"
ON storage.objects
FOR ALL
TO authenticated
USING (bucket_id = 'avatars')
WITH CHECK (bucket_id = 'avatars');

-- Allow public read access
CREATE POLICY "Public read avatars"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'avatars');
```

**For `cover-photos` bucket:**
```sql
-- Allow all authenticated users full access (for testing)
CREATE POLICY "Authenticated users full access cover photos"
ON storage.objects
FOR ALL
TO authenticated
USING (bucket_id = 'cover-photos')
WITH CHECK (bucket_id = 'cover-photos');

-- Allow public read access
CREATE POLICY "Public read cover photos"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'cover-photos');
```

**Note:** The simplified version is easier to set up but less secure. Use it only for testing. For production, use the user-specific policies above.

## Step 3: Verify Setup

After creating the buckets and policies:

1. Try uploading an avatar in the app
2. Try uploading a cover photo in the app
3. Check that images appear correctly in profiles

## Troubleshooting

### "Bucket not found" error
- Verify bucket names are exactly: `avatars` and `cover-photos` (case-sensitive)
- Ensure buckets are created in the correct Supabase project

### "Permission denied" error
- Check that RLS policies are created correctly
- Verify the user is authenticated
- Check that policies allow the operation (INSERT, SELECT, UPDATE, DELETE)

### Images not displaying
- Ensure buckets are set to **Public**
- Check that the SELECT policy allows public access
- Verify the image URLs are being generated correctly

## File Naming Convention

The app uses the following naming convention:
- Avatar: `{userId}.jpg`
- Cover Photo: `{userId}.jpg`

Where `{userId}` is the Supabase Auth user ID (UUID format).

## Notes

- Buckets must be **public** for images to display without authentication
- File size limit: 2MB per image (enforced by the app)
- Images are automatically compressed and resized:
  - Avatars: 400x400 pixels
  - Cover photos: 1200x400 pixels
- Format: All images are converted to JPEG format

