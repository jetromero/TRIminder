-- Migration: Allow authenticated users to view anyone's badges
-- Run in Supabase SQL editor after running create_badges_tables.sql

-- Ensure RLS is enabled (safe to re-run)
ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;

-- Drop old visitor policy if it exists to keep migration idempotent
DROP POLICY IF EXISTS "Users can view public badges" ON public.user_badges;

-- Allow all authenticated users to view badge data for any profile
CREATE POLICY "Users can view public badges"
ON public.user_badges
FOR SELECT
TO authenticated
USING (true);

-- Existing owner-only insert policy remains unchanged; this migration only expands read access.


