-- Migration: Split full_name into first_name and last_name, and add new signup fields
-- Run this in Supabase SQL Editor

-- Step 1: Split full_name column into first_name and last_name
-- Add new columns first
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS first_name TEXT;

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS last_name TEXT;

-- Migrate existing data: Split full_name by space (first word = first_name, rest = last_name)
UPDATE profiles
SET 
  first_name = CASE 
    WHEN full_name IS NOT NULL AND full_name != '' THEN
      SPLIT_PART(full_name, ' ', 1)
    ELSE NULL
  END,
  last_name = CASE 
    WHEN full_name IS NOT NULL AND full_name != '' AND POSITION(' ' IN full_name) > 0 THEN
      SUBSTRING(full_name FROM POSITION(' ' IN full_name) + 1)
    ELSE NULL
  END
WHERE first_name IS NULL OR last_name IS NULL;

-- Set NOT NULL constraint after migration (handle any NULLs by setting defaults)
UPDATE profiles
SET first_name = COALESCE(first_name, 'User')
WHERE first_name IS NULL;

UPDATE profiles
SET last_name = COALESCE(last_name, '')
WHERE last_name IS NULL;

-- Now add NOT NULL constraints
ALTER TABLE profiles 
ALTER COLUMN first_name SET NOT NULL;

ALTER TABLE profiles 
ALTER COLUMN last_name SET NOT NULL;

-- Drop the old full_name column (after ensuring all data is migrated)
-- Note: This will fail if there are views or functions depending on full_name
-- In that case, update those first, then drop the column
-- Uncomment the line below to remove the full_name column after verifying no dependencies exist
ALTER TABLE profiles DROP COLUMN IF EXISTS full_name;

-- Step 2: Add new signup fields
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS student_id TEXT;

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS gender TEXT;

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS year_level TEXT;

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS date_of_birth DATE;

-- Add comments for documentation
COMMENT ON COLUMN profiles.first_name IS 'User first name (required)';
COMMENT ON COLUMN profiles.last_name IS 'User last name (required)';
COMMENT ON COLUMN profiles.student_id IS 'Student ID in format YYYY-XXXXX (e.g., 2020-30041)';
COMMENT ON COLUMN profiles.gender IS 'User gender: Male, Female, Other, or Prefer not to say';
COMMENT ON COLUMN profiles.year_level IS 'Academic year level: 1st Year, 2nd Year, 3rd Year, or 4th Year';
COMMENT ON COLUMN profiles.date_of_birth IS 'User date of birth (DATE format)';

-- Optional: Add check constraints for data validation
-- Note: These may fail if existing data violates constraints, so review data first

-- Check constraint for gender values (optional - uncomment if desired)
-- ALTER TABLE profiles 
-- ADD CONSTRAINT gender_check 
-- CHECK (gender IS NULL OR gender IN ('Male', 'Female', 'Other', 'Prefer not to say'));

-- Check constraint for year_level values (optional - uncomment if desired)
-- ALTER TABLE profiles 
-- ADD CONSTRAINT year_level_check 
-- CHECK (year_level IS NULL OR year_level IN ('1st Year', '2nd Year', '3rd Year', '4th Year'));

-- Check constraint for date_of_birth range (optional - uncomment if desired)
-- Ensures age is between 16 and 100 years
-- ALTER TABLE profiles 
-- ADD CONSTRAINT date_of_birth_check 
-- CHECK (date_of_birth IS NULL OR (date_of_birth <= CURRENT_DATE - INTERVAL '16 years' AND date_of_birth >= CURRENT_DATE - INTERVAL '100 years'));

-- Check constraint for student_id format (optional - uncomment if desired)
-- Format: YYYY-XXXXX (4 digits, hyphen, 5 digits)
-- ALTER TABLE profiles 
-- ADD CONSTRAINT student_id_format_check 
-- CHECK (student_id IS NULL OR student_id ~ '^\d{4}-\d{5}$');

