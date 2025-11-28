-- Migration: Create challenges table and seed default challenge + badge data
-- Run in Supabase SQL editor

-- ============================================================================
-- Ensure default badges exist (used by challenges)
-- ============================================================================
INSERT INTO public.badges (id, name, description, category, rarity, required_value, xp_reward, unlock_conditions)
VALUES
  (1, 'Digital Sage', 'Keep screen time under 2 hours today', 'daily', 'rare', 120, 50, '{"type": "daily", "threshold": 120}'),
  (2, 'Mindful Master', 'Keep screen time under 4 hours today', 'daily', 'common', 240, 25, '{"type": "daily", "threshold": 240}'),
  (3, 'Balanced User', 'Keep screen time under 6 hours today', 'daily', 'common', 360, 15, '{"type": "daily", "threshold": 360}'),
  (4, 'Conscious User', 'Keep screen time under 8 hours today', 'daily', 'common', 480, 10, '{"type": "daily", "threshold": 480}'),
  (10, 'Week Warrior', 'Maintain healthy screen time for 7 consecutive days', 'streak', 'rare', 7, 100, '{"type": "streak", "days": 7}'),
  (11, 'Month Master', 'Maintain healthy screen time for 30 consecutive days', 'streak', 'epic', 30, 500, '{"type": "streak", "days": 30}'),
  (20, 'Level 10 Champion', 'Reach level 10', 'milestone', 'common', 10, 200, '{"type": "level", "level": 10}'),
  (21, 'Level 25 Hero', 'Reach level 25', 'milestone', 'rare', 25, 500, '{"type": "level", "level": 25}')
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  rarity = EXCLUDED.rarity,
  required_value = EXCLUDED.required_value,
  xp_reward = EXCLUDED.xp_reward,
  unlock_conditions = EXCLUDED.unlock_conditions;

-- ============================================================================
-- CHALLENGES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.challenges (
  id INTEGER PRIMARY KEY,
  badge_id INTEGER NOT NULL REFERENCES public.badges(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL,
  reset_interval TEXT NOT NULL,
  target_value INTEGER,
  metadata JSONB,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Add/check constraints for consistency
ALTER TABLE public.challenges DROP CONSTRAINT IF EXISTS challenges_category_check;
ALTER TABLE public.challenges ADD CONSTRAINT challenges_category_check
CHECK (category IN ('daily', 'weekly', 'monthly', 'streak', 'milestone', 'social', 'special'));

ALTER TABLE public.challenges DROP CONSTRAINT IF EXISTS challenges_reset_interval_check;
ALTER TABLE public.challenges ADD CONSTRAINT challenges_reset_interval_check
CHECK (reset_interval IN ('daily', 'weekly', 'monthly', 'streak', 'milestone', 'social', 'special'));

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_challenges_category ON public.challenges(category);
CREATE INDEX IF NOT EXISTS idx_challenges_badge_id ON public.challenges(badge_id);
CREATE INDEX IF NOT EXISTS idx_challenges_active ON public.challenges(is_active);

-- ============================================================================
-- Seed default challenges (linked to seeded badges above)
-- ============================================================================
INSERT INTO public.challenges (id, badge_id, title, description, category, reset_interval, target_value, metadata, sort_order)
VALUES
  (1, 1, 'Stay under 2 hours today', 'Keep total screen time under 120 minutes before the daily reset', 'daily', 'daily', 120, '{"type": "screen_time", "threshold": 120}', 1),
  (2, 2, 'Stay under 4 hours today', 'Keep total screen time under 240 minutes before the daily reset', 'daily', 'daily', 240, '{"type": "screen_time", "threshold": 240}', 2),
  (3, 3, 'Stay under 6 hours today', 'Keep total screen time under 360 minutes before the daily reset', 'daily', 'daily', 360, '{"type": "screen_time", "threshold": 360}', 3),
  (4, 4, 'Stay under 8 hours today', 'Keep total screen time under 480 minutes before the daily reset', 'daily', 'daily', 480, '{"type": "screen_time", "threshold": 480}', 4),
  (10, 10, 'Healthy Week Streak', 'Maintain healthy screen time for seven consecutive days', 'streak', 'streak', 7, '{"type": "streak", "days": 7}', 10),
  (11, 11, 'Healthy Month Streak', 'Maintain healthy screen time for thirty consecutive days', 'streak', 'streak', 30, '{"type": "streak", "days": 30}', 11),
  (20, 20, 'Reach Level 10', 'Earn enough XP to reach player level 10', 'milestone', 'milestone', 10, '{"type": "level", "level": 10}', 20),
  (21, 21, 'Reach Level 25', 'Earn enough XP to reach player level 25', 'milestone', 'milestone', 25, '{"type": "level", "level": 25}', 21)
ON CONFLICT (id) DO UPDATE
SET
  badge_id = EXCLUDED.badge_id,
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  reset_interval = EXCLUDED.reset_interval,
  target_value = EXCLUDED.target_value,
  metadata = EXCLUDED.metadata,
  sort_order = EXCLUDED.sort_order,
  is_active = TRUE;

-- ============================================================================
-- Verification helpers
-- ============================================================================
-- SELECT * FROM public.challenges ORDER BY sort_order;
-- SELECT c.id, c.title, b.name AS badge_name FROM public.challenges c JOIN public.badges b ON c.badge_id = b.id;

