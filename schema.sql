-- ============================================================
-- Habit Tracker — Supabase Database Schema
-- ขั้นตอนที่ 2: Database Design
-- ============================================================

-- ============================================================
-- TABLE 1: profiles
-- ต่อจาก Supabase auth.users — เก็บข้อมูลเพิ่มเติมของผู้ใช้
-- ============================================================
CREATE TABLE public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  timezone    TEXT NOT NULL DEFAULT 'Asia/Bangkok',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-create profile เมื่อ user สมัครสมาชิก
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
-- รายการ Habit แต่ละตัว (สามารถเพิ่ม/ลบได้ในอนาคต)
-- ============================================================
CREATE TABLE public.habits (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,              -- ชื่อ habit เช่น "Exercise"
  icon       TEXT,                       -- emoji เช่น "🏋️"
  color      TEXT DEFAULT '#6366f1',     -- hex color สำหรับ UI
  is_active  BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INT NOT NULL DEFAULT 0,     -- ลำดับการแสดงผล
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE 3: daily_logs
-- บันทึกประจำวัน — 1 row ต่อ 1 วัน ต่อ 1 user
-- ============================================================
CREATE TABLE public.daily_logs (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  log_date            DATE NOT NULL,

  -- ตัวเลขที่วัดได้ (แสดงเป็นกราฟ)
  sleep_hours         NUMERIC(4, 1),          -- จำนวนชั่วโมงที่นอน เช่น 7.5
  read_pages          INT DEFAULT 0,          -- จำนวนหน้าที่อ่าน
  weight_kg           NUMERIC(5, 2),          -- น้ำหนัก เช่น 65.50
  meditate_minutes    INT DEFAULT 0,          -- นาทีที่ทำสมาธิ
  feelings            SMALLINT CHECK (feelings BETWEEN 1 AND 5), -- 1=Bad, 5=Best

  -- บันทึกข้อความ (Note)
  memorable_moments   TEXT,                   -- โน้ตสั้นๆ 1-3 บรรทัด
  thesis_notes        TEXT,                   -- บันทึก thesis 4-5 บรรทัด

  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (user_id, log_date)  -- 1 วัน = 1 row ต่อ user
);

-- Auto-update updated_at
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
-- บันทึกว่าแต่ละ habit ทำสำเร็จในวันนั้นหรือเปล่า
-- ============================================================
CREATE TABLE public.habit_completions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  habit_id   UUID NOT NULL REFERENCES public.habits(id) ON DELETE CASCADE,
  log_date   DATE NOT NULL,
  completed  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (user_id, habit_id, log_date)  -- กัน duplicate
);

-- ============================================================
-- INDEXES — เพิ่มความเร็วในการ query
-- ============================================================
CREATE INDEX idx_habits_user_id         ON public.habits(user_id);
CREATE INDEX idx_daily_logs_user_date   ON public.daily_logs(user_id, log_date DESC);
CREATE INDEX idx_habit_completions_date ON public.habit_completions(user_id, log_date DESC);

-- ============================================================
-- ROW LEVEL SECURITY (RLS) — แต่ละ user เห็นแค่ข้อมูลตัวเอง
-- ============================================================
ALTER TABLE public.profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.habits            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_logs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.habit_completions ENABLE ROW LEVEL SECURITY;

-- profiles
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- habits
CREATE POLICY "Users can manage own habits"
  ON public.habits FOR ALL USING (auth.uid() = user_id);

-- daily_logs
CREATE POLICY "Users can manage own daily logs"
  ON public.daily_logs FOR ALL USING (auth.uid() = user_id);

-- habit_completions
CREATE POLICY "Users can manage own habit completions"
  ON public.habit_completions FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- SEED DATA — Default habits สำหรับ user ใหม่
-- (เรียกใช้ใน trigger หรือ onboarding)
-- ============================================================
-- ตัวอย่าง: INSERT หลัง user สมัคร
--
-- INSERT INTO public.habits (user_id, name, icon, color, sort_order) VALUES
--   (NEW.id, 'No Caffeine',  '☕', '#8B5CF6', 1),
--   (NEW.id, 'Exercise',     '🏋️', '#EF4444', 2),
--   (NEW.id, 'Trade',        '📈', '#10B981', 3),
--   (NEW.id, 'Drink Water',  '💧', '#3B82F6', 4),
--   (NEW.id, 'Skills',       '🧠', '#F59E0B', 5),
--   (NEW.id, 'English',      '🇬🇧', '#6366F1', 6),
--   (NEW.id, 'Healthy',      '🥗', '#14B8A6', 7);
