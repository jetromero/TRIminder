-- Migration: Add badge leveling system
-- Run this in Supabase SQL Editor
-- This migration adds leveling support to the badge system

-- ============================================================================
-- UPDATE USER_BADGES TABLE
-- ============================================================================
-- Add level and completion_count columns to user_badges table
ALTER TABLE IF EXISTS public.user_badges
ADD COLUMN IF NOT EXISTS level INTEGER NOT NULL DEFAULT 1,
ADD COLUMN IF NOT EXISTS completion_count INTEGER NOT NULL DEFAULT 1;

-- Add comments for documentation
COMMENT ON COLUMN public.user_badges.level IS 'Current level of the badge (1-5 based on thresholds)';
COMMENT ON COLUMN public.user_badges.completion_count IS 'Total number of times this badge has been completed';

-- ============================================================================
-- UPDATE BADGES TABLE
-- ============================================================================
-- Add level_thresholds column to badges table
ALTER TABLE IF EXISTS public.badges
ADD COLUMN IF NOT EXISTS level_thresholds JSONB;

-- Add comment for documentation
COMMENT ON COLUMN public.badges.level_thresholds IS 'Array of completion counts required for each level (e.g., [1, 3, 7, 15, 30])';

-- ============================================================================
-- CREATE DAILY_CHALLENGE_COMPLETIONS TABLE
-- ============================================================================
-- Tracks individual daily challenge completions for leveling calculations
CREATE TABLE IF NOT EXISTS public.daily_challenge_completions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  badge_id INTEGER NOT NULL REFERENCES public.badges(id) ON DELETE CASCADE,
  completion_date DATE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- Ensure a user can only complete a badge once per day
  UNIQUE(user_id, badge_id, completion_date)
);

-- Add comments for documentation
COMMENT ON TABLE public.daily_challenge_completions IS 'Tracks individual daily challenge completions for badge leveling';
COMMENT ON COLUMN public.daily_challenge_completions.user_id IS 'Reference to the user who completed the challenge';
COMMENT ON COLUMN public.daily_challenge_completions.badge_id IS 'Reference to the badge that was completed';
COMMENT ON COLUMN public.daily_challenge_completions.completion_date IS 'Date when the challenge was completed';

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_daily_completions_user_badge ON public.daily_challenge_completions(user_id, badge_id);
CREATE INDEX IF NOT EXISTS idx_daily_completions_date ON public.daily_challenge_completions(completion_date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_completions_user_date ON public.daily_challenge_completions(user_id, completion_date DESC);

-- ============================================================================
-- UPDATE EXISTING BADGES WITH LEVEL THRESHOLDS
-- ============================================================================
-- Set level thresholds for existing daily badges
UPDATE public.badges
SET level_thresholds = CASE
  WHEN id = 1 THEN '[1, 3, 7, 15, 30]'::jsonb  -- Digital Sage (rare)
  WHEN id = 2 THEN '[1, 5, 10, 20, 40]'::jsonb  -- Mindful Master (common)
  WHEN id = 3 THEN '[1, 5, 10, 25, 50]'::jsonb  -- Balanced User (common)
  WHEN id = 4 THEN '[1, 5, 10, 25, 50]'::jsonb  -- Conscious User (common)
  ELSE level_thresholds
END
WHERE id IN (1, 2, 3, 4);

-- ============================================================================
-- UPDATE EXISTING USER_BADGES
-- ============================================================================
-- Set all existing badges to level 1 with completion_count 1
-- (This migration starts fresh - no historical calculation)
UPDATE public.user_badges
SET 
  level = 1,
  completion_count = 1
WHERE level IS NULL OR completion_count IS NULL;

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================
-- Enable RLS on daily_challenge_completions table
ALTER TABLE IF EXISTS public.daily_challenge_completions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own completions
DROP POLICY IF EXISTS "Users can view own completions" ON public.daily_challenge_completions;
CREATE POLICY "Users can view own completions"
ON public.daily_challenge_completions
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Policy: Users can insert their own completions
DROP POLICY IF EXISTS "Users can insert own completions" ON public.daily_challenge_completions;
CREATE POLICY "Users can insert own completions"
ON public.daily_challenge_completions
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Policy: Authenticated users can view any user's completions (for social features)
DROP POLICY IF EXISTS "Users can view completions publicly" ON public.daily_challenge_completions;
CREATE POLICY "Users can view completions publicly"
ON public.daily_challenge_completions
FOR SELECT
TO authenticated
USING (true);

-- Note: No UPDATE or DELETE policies - completions are immutable once created

