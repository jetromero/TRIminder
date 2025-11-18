-- Migration: Add avatar_url, cover_photo_url, and bio columns to profiles table
-- Run this in Supabase SQL Editor

-- Add avatar_url column
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Add cover_photo_url column
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS cover_photo_url TEXT;

-- Add bio column (max 500 characters)
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS bio TEXT;

-- Add check constraint for bio length (optional, but recommended)
-- Note: If this fails with "constraint already exists", you can safely ignore it
-- The app validates bio length in code, so this constraint is optional
-- ALTER TABLE profiles 
-- ADD CONSTRAINT bio_length_check 
-- CHECK (bio IS NULL OR LENGTH(bio) <= 500);

-- Add comment to columns for documentation
COMMENT ON COLUMN profiles.avatar_url IS 'URL to user avatar image stored in Supabase Storage';
COMMENT ON COLUMN profiles.cover_photo_url IS 'URL to user cover photo image stored in Supabase Storage';
COMMENT ON COLUMN profiles.bio IS 'User bio/about section (max 500 characters)';

