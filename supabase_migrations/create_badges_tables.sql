-- Migration: Create badges and user_badges tables for badge system
-- Run this in Supabase SQL Editor
-- This migration creates the badges system tables matching the Flutter app's expectations

-- ============================================================================
-- BADGES TABLE
-- ============================================================================
-- Stores badge definitions (metadata about badges that can be earned)
CREATE TABLE IF NOT EXISTS public.badges (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  icon_url TEXT,
  category TEXT NOT NULL DEFAULT 'daily',
  rarity TEXT NOT NULL DEFAULT 'common',
  required_value INTEGER,
  xp_reward INTEGER NOT NULL DEFAULT 0,
  unlock_conditions JSONB,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Add missing columns if table already exists (for migration safety)
DO $$ 
BEGIN
  -- Add description column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'badges' 
    AND column_name = 'description'
  ) THEN
    ALTER TABLE public.badges ADD COLUMN description TEXT;
  END IF;

  -- Add icon_url column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'badges' 
    AND column_name = 'icon_url'
  ) THEN
    ALTER TABLE public.badges ADD COLUMN icon_url TEXT;
  END IF;

  -- Add category column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'badges' 
    AND column_name = 'category'
  ) THEN
    ALTER TABLE public.badges ADD COLUMN category TEXT NOT NULL DEFAULT 'daily';
  END IF;

  -- Add rarity column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'badges' 
    AND column_name = 'rarity'
  ) THEN
    ALTER TABLE public.badges ADD COLUMN rarity TEXT NOT NULL DEFAULT 'common';
  END IF;

  -- Add required_value column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'badges' 
    AND column_name = 'required_value'
  ) THEN
    ALTER TABLE public.badges ADD COLUMN required_value INTEGER;
  END IF;

  -- Add xp_reward column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'badges' 
    AND column_name = 'xp_reward'
  ) THEN
    ALTER TABLE public.badges ADD COLUMN xp_reward INTEGER NOT NULL DEFAULT 0;
  END IF;

  -- Add unlock_conditions column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'badges' 
    AND column_name = 'unlock_conditions'
  ) THEN
    ALTER TABLE public.badges ADD COLUMN unlock_conditions JSONB;
  END IF;

  -- Add created_at column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'badges' 
    AND column_name = 'created_at'
  ) THEN
    ALTER TABLE public.badges ADD COLUMN created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW();
  END IF;
END $$;

-- Add comments for documentation
COMMENT ON TABLE public.badges IS 'Badge definitions - metadata about badges that can be earned';
COMMENT ON COLUMN public.badges.id IS 'Unique badge identifier';
COMMENT ON COLUMN public.badges.name IS 'Badge name (e.g., "Digital Sage", "Week Warrior")';
COMMENT ON COLUMN public.badges.description IS 'Badge description explaining how to earn it';
COMMENT ON COLUMN public.badges.icon_url IS 'URL to badge icon image (stored in Supabase Storage or external URL)';
COMMENT ON COLUMN public.badges.category IS 'Badge category: daily, weekly, monthly, streak, milestone, social, special';
COMMENT ON COLUMN public.badges.rarity IS 'Badge rarity: common, rare, epic, legendary';
COMMENT ON COLUMN public.badges.required_value IS 'Required value to unlock badge (e.g., 120 for 120 minutes, 7 for 7 days)';
COMMENT ON COLUMN public.badges.xp_reward IS 'XP reward for earning this badge';
COMMENT ON COLUMN public.badges.unlock_conditions IS 'Additional unlock conditions stored as JSON (e.g., {"type": "level", "level": 10})';
COMMENT ON COLUMN public.badges.created_at IS 'Timestamp when badge was created';

-- Add check constraints for category and rarity enum-like values
-- Drop constraints if they exist (to allow re-running migration)
ALTER TABLE public.badges DROP CONSTRAINT IF EXISTS category_check;
ALTER TABLE public.badges DROP CONSTRAINT IF EXISTS rarity_check;

ALTER TABLE public.badges 
ADD CONSTRAINT category_check 
CHECK (category IN ('daily', 'weekly', 'monthly', 'streak', 'milestone', 'social', 'special'));

ALTER TABLE public.badges 
ADD CONSTRAINT rarity_check 
CHECK (rarity IN ('common', 'rare', 'epic', 'legendary'));

-- Add index for category (for filtering badges by category)
CREATE INDEX IF NOT EXISTS idx_badges_category ON public.badges(category);

-- Add index for rarity (for filtering by rarity)
CREATE INDEX IF NOT EXISTS idx_badges_rarity ON public.badges(rarity);

-- ============================================================================
-- USER_BADGES TABLE
-- ============================================================================
-- Stores badges earned by users (junction table linking users to badges)
-- Note: The app's local database generates composite IDs (userId_badgeId), but Supabase uses UUID
-- The app doesn't send an 'id' field when inserting, so Supabase will auto-generate UUID
CREATE TABLE IF NOT EXISTS public.user_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  badge_id INTEGER NOT NULL REFERENCES public.badges(id) ON DELETE CASCADE,
  awarded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- Ensure a user can only earn a badge once
  UNIQUE(user_id, badge_id)
);

-- Add comments for documentation
COMMENT ON TABLE public.user_badges IS 'Badges earned by users - tracks when users unlock badges';
COMMENT ON COLUMN public.user_badges.id IS 'Unique identifier for user badge record';
COMMENT ON COLUMN public.user_badges.user_id IS 'Reference to the user who earned the badge';
COMMENT ON COLUMN public.user_badges.badge_id IS 'Reference to the badge that was earned';
COMMENT ON COLUMN public.user_badges.awarded_at IS 'Timestamp when the badge was awarded/earned';
COMMENT ON COLUMN public.user_badges.created_at IS 'Timestamp when record was created (same as awarded_at typically)';

-- Add indexes for common queries
CREATE INDEX IF NOT EXISTS idx_user_badges_user_id ON public.user_badges(user_id);
CREATE INDEX IF NOT EXISTS idx_user_badges_badge_id ON public.user_badges(badge_id);
CREATE INDEX IF NOT EXISTS idx_user_badges_awarded_at ON public.user_badges(awarded_at DESC);

-- Composite index for querying user badges ordered by date
CREATE INDEX IF NOT EXISTS idx_user_badges_user_awarded ON public.user_badges(user_id, awarded_at DESC);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on badges table
-- Badges are public (anyone can view badge definitions)
ALTER TABLE public.badges ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone (including unauthenticated users) can view badge definitions
DROP POLICY IF EXISTS "Anyone can view badges" ON public.badges;
CREATE POLICY "Anyone can view badges"
ON public.badges
FOR SELECT
TO public
USING (true);

-- Note: Only admins should be able to insert/update/delete badges
-- Add admin policies if you have an admin role system
-- For now, badges will be inserted via SQL or admin panel

-- Enable RLS on user_badges table
ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own earned badges
DROP POLICY IF EXISTS "Users can view own badges" ON public.user_badges;
CREATE POLICY "Users can view own badges"
ON public.user_badges
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Policy: Users can view badges of their friends
-- (This requires checking the friendships table - uncomment if needed)
-- CREATE POLICY "Users can view friend badges"
-- ON public.user_badges
-- FOR SELECT
-- TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1 FROM public.friendships
--     WHERE status = 'accepted'
--     AND (
--       (user_a_id = auth.uid() AND user_b_id = user_badges.user_id)
--       OR (user_b_id = auth.uid() AND user_a_id = user_badges.user_id)
--     )
--   )
-- );

-- Policy: Users can insert their own badges (when earned)
DROP POLICY IF EXISTS "Users can insert own badges" ON public.user_badges;
CREATE POLICY "Users can insert own badges"
ON public.user_badges
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Policy: Users cannot update their badges (badges are immutable once earned)
-- No UPDATE policy needed - badges are permanent

-- Policy: Users cannot delete their badges (badges are permanent achievements)
-- No DELETE policy needed - badges should not be deleted

-- ============================================================================
-- HELPER FUNCTIONS (Optional)
-- ============================================================================

-- Function to get user's badge count (can be used in views/queries)
CREATE OR REPLACE FUNCTION get_user_badge_count(user_uuid UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM public.user_badges
    WHERE user_id = user_uuid
  );
END;
$$;

COMMENT ON FUNCTION get_user_badge_count IS 'Returns the total number of badges earned by a user';

-- ============================================================================
-- INITIAL BADGE DATA (Optional - can be inserted separately)
-- ============================================================================
-- Uncomment and run this section to insert default badges
-- Or insert badges via the Flutter app's badge_definitions.dart

/*
-- Daily Badges
INSERT INTO public.badges (id, name, description, category, rarity, required_value, xp_reward, unlock_conditions) VALUES
(1, 'Digital Sage', 'Keep screen time under 2 hours today', 'daily', 'rare', 120, 50, '{"type": "daily", "threshold": 120}'),
(2, 'Mindful Master', 'Keep screen time under 4 hours today', 'daily', 'common', 240, 25, '{"type": "daily", "threshold": 240}'),
(3, 'Balanced User', 'Keep screen time under 6 hours today', 'daily', 'common', 360, 15, '{"type": "daily", "threshold": 360}'),
(4, 'Conscious User', 'Keep screen time under 8 hours today', 'daily', 'common', 480, 10, '{"type": "daily", "threshold": 480}')

-- Streak Badges
(10, 'Week Warrior', 'Maintain healthy screen time for 7 consecutive days', 'streak', 'rare', 7, 100, '{"type": "streak", "days": 7}'),
(11, 'Month Master', 'Maintain healthy screen time for 30 consecutive days', 'streak', 'epic', 30, 500, '{"type": "streak", "days": 30}')

-- Milestone Badges
(20, 'Level 10 Champion', 'Reach level 10', 'milestone', 'common', 10, 200, '{"type": "level", "level": 10}'),
(21, 'Level 25 Hero', 'Reach level 25', 'milestone', 'rare', 25, 500, '{"type": "level", "level": 25}')

ON CONFLICT (id) DO NOTHING;
*/

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- Run these queries to verify the tables were created correctly:

-- Check badges table structure
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'badges' AND table_schema = 'public'
-- ORDER BY ordinal_position;

-- Check user_badges table structure
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'user_badges' AND table_schema = 'public'
-- ORDER BY ordinal_position;

-- Check RLS policies
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
-- FROM pg_policies
-- WHERE tablename IN ('badges', 'user_badges');

