-- Migration: Allow authenticated users to view any user's badges
-- Run in Supabase SQL editor after the original badge tables migration.

-- Enable RLS just in case this file runs before create_badges_tables.sql
ALTER TABLE IF EXISTS public.user_badges ENABLE ROW LEVEL SECURITY;

-- Public view policy: authenticated users can read badge awards for any profile.
-- This is required for showing earned badges on other users' profile pages.
DROP POLICY IF EXISTS "Users can view badges publicly" ON public.user_badges;
CREATE POLICY "Users can view badges publicly"
ON public.user_badges
FOR SELECT
TO authenticated
USING (true);

-- Retain owner-only insert policy for safety (idempotent re-definition)
DROP POLICY IF EXISTS "Users can insert own badges" ON public.user_badges;
CREATE POLICY "Users can insert own badges"
ON public.user_badges
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- NOTE:
-- - No UPDATE/DELETE policies are added; badges remain immutable.
-- - If you need to restrict visibility (e.g., friends only), replace the USING clause
--   with the desired condition referencing friendships or profile privacy flags.

