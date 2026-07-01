-- ============================================================
-- DevOS Habit Tracker — Supabase Database Schema v2
-- ============================================================

-- ============================================================
-- TABLE 1: profiles
-- ============================================================
CREATE TABLE public.profiles (
  id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  timezone     TEXT NOT NULL DEFAULT 'Asia/Bangkok',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- TABLE 2: habits
-- Generic habit rows (used for Foundation + Growth checkboxes)
-- ============================================================
CREATE TABLE public.habits (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  icon       TEXT,
  color      TEXT DEFAULT '#6366f1',
  is_active  BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE 3: daily_logs
-- One row per user per day — metrics + journal + new fields
-- ============================================================
CREATE TABLE public.daily_logs (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  log_date             DATE NOT NULL,

  -- Core Metrics
  sleep_hours          NUMERIC(4,1),
  read_pages           INT DEFAULT 0,
  weight_kg            NUMERIC(5,2),
  meditate_minutes     INT DEFAULT 0,
  feelings             SMALLINT CHECK (feelings BETWEEN 1 AND 5),

  -- Growth: English type
  english_type         TEXT CHECK (english_type IN ('Listening','Grammar','Vocabulary','Reading')),

  -- Foundation: Workout type (checked via habit_completions, type stored per day here)
  workout_type         TEXT CHECK (workout_type IN ('Weight Training','Cardio','Other')),

  -- Trading: Mental / psychological notes (renamed from the old "1:10 RRR setup log")
  trading_special_log  TEXT,

  -- Wealth: Freelance AI usage
  freelance_used_ai    BOOLEAN DEFAULT FALSE,

  -- Deep Journal
  memorable_moments    TEXT,
  thesis_notes         TEXT,   -- kept for legacy; milestone tracker is separate

  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (user_id, log_date)
);

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER daily_logs_updated_at
  BEFORE UPDATE ON public.daily_logs
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLE 4: habit_completions
-- ============================================================
CREATE TABLE public.habit_completions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  habit_id   UUID NOT NULL REFERENCES public.habits(id) ON DELETE CASCADE,
  log_date   DATE NOT NULL,
  completed  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, habit_id, log_date)
);

-- ============================================================
-- TABLE 5: thesis_milestones
-- Persistent 6-step tracker (not daily) — one row per user per step
-- ============================================================
CREATE TABLE public.thesis_milestones (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  step_number  SMALLINT NOT NULL CHECK (step_number BETWEEN 1 AND 6),
  completed    BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, step_number)
);

-- ============================================================
-- TABLE 6: freelance_tasks
-- Project task list for Civil Engineering / BOQ modeling
-- ============================================================
CREATE TABLE public.freelance_tasks (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  task_text  TEXT NOT NULL,
  completed  BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE 6b: freelance_milestones
-- Persistent 12-step roadmap tracker (not daily) — encodes the
-- 4-week Freelance/Portfolio plan (setup -> structural/2D ->
-- architectural/3D -> portfolio & apply). Mirrors thesis_milestones.
-- ============================================================
CREATE TABLE public.freelance_milestones (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  step_number  SMALLINT NOT NULL CHECK (step_number BETWEEN 1 AND 12),
  completed    BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, step_number)
);

CREATE TRIGGER freelance_milestones_updated_at
  BEFORE UPDATE ON public.freelance_milestones
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLE 7: weekly_reviews
-- One row per ISO week per user
-- ============================================================
CREATE TABLE public.weekly_reviews (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  week_start           DATE NOT NULL,   -- Monday of that ISO week
  trading_reflection   TEXT,
  freelance_checkin    TEXT,
  thesis_progress      TEXT,
  blockers_solutions   TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, week_start)
);

CREATE TRIGGER weekly_reviews_updated_at
  BEFORE UPDATE ON public.weekly_reviews
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLE 8: monthly_reviews
-- One row per month per user (month_year format: YYYY-MM)
-- ============================================================
CREATE TABLE public.monthly_reviews (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  month_year        CHAR(7) NOT NULL,   -- e.g. '2026-07'
  highlights        TEXT,
  goal_adjustments  TEXT,
  next_month_focus  TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, month_year)
);

CREATE TRIGGER monthly_reviews_updated_at
  BEFORE UPDATE ON public.monthly_reviews
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_habits_user_id              ON public.habits(user_id);
CREATE INDEX idx_daily_logs_user_date        ON public.daily_logs(user_id, log_date DESC);
CREATE INDEX idx_habit_completions_date      ON public.habit_completions(user_id, log_date DESC);
CREATE INDEX idx_thesis_milestones_user      ON public.thesis_milestones(user_id);
CREATE INDEX idx_freelance_tasks_user        ON public.freelance_tasks(user_id);
CREATE INDEX idx_freelance_milestones_user   ON public.freelance_milestones(user_id);
CREATE INDEX idx_weekly_reviews_user         ON public.weekly_reviews(user_id, week_start DESC);
CREATE INDEX idx_monthly_reviews_user        ON public.monthly_reviews(user_id, month_year DESC);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE public.profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.habits            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_logs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.habit_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.thesis_milestones    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.freelance_tasks      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.freelance_milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_reviews       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_reviews      ENABLE ROW LEVEL SECURITY;

CREATE POLICY "own profile select"      ON public.profiles          FOR SELECT USING (auth.uid() = id);
CREATE POLICY "own profile update"      ON public.profiles          FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "own habits"              ON public.habits            FOR ALL    USING (auth.uid() = user_id);
CREATE POLICY "own daily_logs"          ON public.daily_logs        FOR ALL    USING (auth.uid() = user_id);
CREATE POLICY "own habit_completions"   ON public.habit_completions FOR ALL    USING (auth.uid() = user_id);
CREATE POLICY "own thesis_milestones"   ON public.thesis_milestones FOR ALL    USING (auth.uid() = user_id);
CREATE POLICY "own freelance_tasks"     ON public.freelance_tasks   FOR ALL    USING (auth.uid() = user_id);
CREATE POLICY "own freelance_milestones"ON public.freelance_milestones FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "own weekly_reviews"      ON public.weekly_reviews    FOR ALL    USING (auth.uid() = user_id);
CREATE POLICY "own monthly_reviews"     ON public.monthly_reviews   FOR ALL    USING (auth.uid() = user_id);

-- ============================================================
-- MIGRATION (run these if upgrading existing DB)
-- ============================================================
-- ALTER TABLE public.daily_logs ADD COLUMN IF NOT EXISTS english_type TEXT CHECK (english_type IN ('Listening','Grammar','Vocabulary','Reading'));
-- ALTER TABLE public.daily_logs ADD COLUMN IF NOT EXISTS trading_special_log TEXT;
-- ALTER TABLE public.daily_logs ADD COLUMN IF NOT EXISTS freelance_used_ai BOOLEAN DEFAULT FALSE;
-- ALTER TABLE public.daily_logs ADD COLUMN IF NOT EXISTS workout_type TEXT CHECK (workout_type IN ('Weight Training','Cardio','Other'));
-- (Create tables 5-8 above as new)
--
-- NOTE: Workout is now the 5th fixed row in `habits` (name = 'Workout', tracked daily via
-- habit_completions like the other habits). The app auto-inserts this habit for existing
-- users on next login (see HABIT_DEFS backfill in index.html) — no manual insert needed.
-- The old scheme of storing a 7-day matrix inside daily_logs.thesis_notes (prefixed
-- "__workout__") is no longer used; that column reverts to legacy/unused.
