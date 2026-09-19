-- ==========================================================
-- CrossFit WOD Fit: Initial Database Migration & Security
-- ==========================================================

-- 1. ENUM TYPES
CREATE TYPE public.user_role AS ENUM ('coach', 'client');
CREATE TYPE public.program_kind AS ENUM ('personal', 'group');
CREATE TYPE public.workout_part_type AS ENUM (
  'warmup',
  'weightlifting',
  'strength',
  'crossfitComplex',
  'cooldown',
  'stretch',
  'mobility'
);
CREATE TYPE public.workout_status AS ENUM ('draft', 'published');
CREATE TYPE public.result_status AS ENUM ('done', 'scaled', 'notDone');

-- 2. PROFILES TABLE
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  role public.user_role NOT NULL DEFAULT 'client',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3. PROGRAMS TABLE
CREATE TABLE public.programs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  kind public.program_kind NOT NULL DEFAULT 'group',
  description TEXT NOT NULL DEFAULT '',
  invite_code TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4. PROGRAM MEMBERS TABLE
CREATE TABLE public.program_members (
  program_id UUID NOT NULL REFERENCES public.programs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  PRIMARY KEY (program_id, user_id)
);

-- 5. WORKOUTS TABLE
CREATE TABLE public.workouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  scheduled_at TIMESTAMPTZ NOT NULL,
  status public.workout_status NOT NULL DEFAULT 'draft',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 6. WORKOUT PARTS TABLE
CREATE TABLE public.workout_parts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_id UUID NOT NULL REFERENCES public.workouts(id) ON DELETE CASCADE,
  type public.workout_part_type NOT NULL,
  score_type TEXT NOT NULL DEFAULT 'text',
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0
);

-- 7. WORKOUT ASSIGNMENTS TABLE
CREATE TABLE public.workout_assignments (
  workout_id UUID NOT NULL REFERENCES public.workouts(id) ON DELETE CASCADE,
  program_id UUID NOT NULL REFERENCES public.programs(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  PRIMARY KEY (workout_id, program_id)
);

-- 8. PART RESULTS TABLE
CREATE TABLE public.part_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_id UUID NOT NULL REFERENCES public.workouts(id) ON DELETE CASCADE,
  part_id UUID NOT NULL REFERENCES public.workout_parts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status public.result_status NOT NULL DEFAULT 'done',
  score_text TEXT NOT NULL DEFAULT '',
  note TEXT NOT NULL DEFAULT '',
  time_ms BIGINT,
  rounds INTEGER,
  reps INTEGER,
  weight_kg NUMERIC(6, 2),
  distance_m NUMERIC(8, 2),
  calories INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE (part_id, user_id)
);

-- Indexes for performance
CREATE INDEX idx_programs_coach ON public.programs(coach_id);
CREATE INDEX idx_program_members_program ON public.program_members(program_id);
CREATE INDEX idx_program_members_user ON public.program_members(user_id);
CREATE INDEX idx_workouts_coach ON public.workouts(coach_id);
CREATE INDEX idx_workout_parts_workout ON public.workout_parts(workout_id);
CREATE INDEX idx_workout_assignments_program ON public.workout_assignments(program_id);
CREATE INDEX idx_part_results_workout ON public.part_results(workout_id);
CREATE INDEX idx_part_results_part ON public.part_results(part_id);
CREATE INDEX idx_part_results_user ON public.part_results(user_id);

-- 9. TRIGGER FOR AUTOMATIC PROFILE CREATION
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Спортсмен'),
    COALESCE((NEW.raw_user_meta_data->>'role')::public.user_role, 'client'::public.user_role)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 10. RPC: JOIN PROGRAM BY INVITE CODE
CREATE OR REPLACE FUNCTION public.join_program_by_code(code TEXT)
RETURNS JSON AS $$
DECLARE
  v_program_id UUID;
  v_program_name TEXT;
  v_program_kind public.program_kind;
BEGIN
  SELECT id, name, kind INTO v_program_id, v_program_name, v_program_kind
  FROM public.programs
  WHERE UPPER(invite_code) = UPPER(TRIM(code));

  IF v_program_id IS NULL THEN
    RAISE EXCEPTION 'Программа с кодом % не найдена', code;
  END IF;

  INSERT INTO public.program_members (program_id, user_id)
  VALUES (v_program_id, auth.uid())
  ON CONFLICT (program_id, user_id) DO NOTHING;

  RETURN json_build_object(
    'id', v_program_id,
    'name', v_program_name,
    'kind', v_program_kind
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. HELPER SECURITY DEFINER FUNCTIONS (Prevents RLS infinite recursion)
CREATE OR REPLACE FUNCTION public.is_program_member(p_program_id UUID, p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.program_members WHERE program_id = p_program_id AND user_id = p_user_id
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.is_program_coach(p_program_id UUID, p_coach_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.programs WHERE id = p_program_id AND coach_id = p_coach_id
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.can_user_view_workout(p_workout_id UUID, p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.workouts WHERE id = p_workout_id AND coach_id = p_user_id
  ) OR EXISTS (
    SELECT 1 FROM public.workouts w
    JOIN public.workout_assignments wa ON wa.workout_id = w.id
    JOIN public.program_members pm ON pm.program_id = wa.program_id
    WHERE w.id = p_workout_id AND w.status = 'published' AND pm.user_id = p_user_id
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 12. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.program_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.part_results ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Authenticated users can read profiles"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- Programs policies
CREATE POLICY "Coach and members can read programs"
  ON public.programs FOR SELECT
  TO authenticated
  USING (
    coach_id = auth.uid()
    OR public.is_program_member(id, auth.uid())
  );

CREATE POLICY "Coach can create programs"
  ON public.programs FOR INSERT
  TO authenticated
  WITH CHECK (coach_id = auth.uid());

CREATE POLICY "Coach can update own programs"
  ON public.programs FOR UPDATE
  TO authenticated
  USING (coach_id = auth.uid())
  WITH CHECK (coach_id = auth.uid());

CREATE POLICY "Coach can delete own programs"
  ON public.programs FOR DELETE
  TO authenticated
  USING (coach_id = auth.uid());

-- Program members policies
CREATE POLICY "Members and coaches can view program members"
  ON public.program_members FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_program_coach(program_id, auth.uid())
  );

CREATE POLICY "Users can join programs"
  ON public.program_members FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users or coaches can leave or remove from program"
  ON public.program_members FOR DELETE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_program_coach(program_id, auth.uid())
  );

-- Workouts policies
CREATE POLICY "Coach can manage workouts"
  ON public.workouts FOR ALL
  TO authenticated
  USING (coach_id = auth.uid())
  WITH CHECK (coach_id = auth.uid());

CREATE POLICY "Clients can read published workouts assigned to their programs"
  ON public.workouts FOR SELECT
  TO authenticated
  USING (
    public.can_user_view_workout(id, auth.uid())
  );

-- Workout parts policies
CREATE POLICY "Users can view workout parts of visible workouts"
  ON public.workout_parts FOR SELECT
  TO authenticated
  USING (
    public.can_user_view_workout(workout_id, auth.uid())
  );

CREATE POLICY "Coach can manage workout parts"
  ON public.workout_parts FOR ALL
  TO authenticated
  USING (
    workout_id IN (SELECT id FROM public.workouts WHERE coach_id = auth.uid())
  )
  WITH CHECK (
    workout_id IN (SELECT id FROM public.workouts WHERE coach_id = auth.uid())
  );

-- Workout assignments policies
CREATE POLICY "Coach or members can view workout assignments"
  ON public.workout_assignments FOR SELECT
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.workouts w WHERE w.id = workout_id AND w.coach_id = auth.uid())
    OR public.is_program_member(program_id, auth.uid())
  );

CREATE POLICY "Coach can assign workout to own program"
  ON public.workout_assignments FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.workouts w WHERE w.id = workout_id AND w.coach_id = auth.uid())
    AND public.is_program_coach(program_id, auth.uid())
  );

CREATE POLICY "Coach can delete workout assignments"
  ON public.workout_assignments FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.workouts w WHERE w.id = workout_id AND w.coach_id = auth.uid())
  );

-- Part results policies
CREATE POLICY "Users can view results for assigned workouts"
  ON public.part_results FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.can_user_view_workout(workout_id, auth.uid())
  );

CREATE POLICY "Clients can create own results"
  ON public.part_results FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Clients can update own results"
  ON public.part_results FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Clients can delete own results"
  ON public.part_results FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- 9. WORKOUT TEMPLATES TABLE
CREATE TABLE IF NOT EXISTS public.workout_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 10. WORKOUT TEMPLATE PARTS TABLE
CREATE TABLE IF NOT EXISTS public.workout_template_parts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID NOT NULL REFERENCES public.workout_templates(id) ON DELETE CASCADE,
  type public.workout_part_type NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0
);

-- Indexes for templates
CREATE INDEX IF NOT EXISTS idx_workout_templates_coach ON public.workout_templates(coach_id);
CREATE INDEX IF NOT EXISTS idx_workout_template_parts_template ON public.workout_template_parts(template_id);

-- Helper function to check template ownership
CREATE OR REPLACE FUNCTION public.is_template_coach(template_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.workout_templates
    WHERE id = template_uuid
      AND coach_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Template RLS
ALTER TABLE public.workout_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_template_parts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Coach can view own templates"
  ON public.workout_templates FOR SELECT
  USING (coach_id = auth.uid());

CREATE POLICY "Coach can create own templates"
  ON public.workout_templates FOR INSERT
  WITH CHECK (coach_id = auth.uid());

CREATE POLICY "Coach can update own templates"
  ON public.workout_templates FOR UPDATE
  USING (coach_id = auth.uid());

CREATE POLICY "Coach can delete own templates"
  ON public.workout_templates FOR DELETE
  USING (coach_id = auth.uid());

CREATE POLICY "Coach can view own template parts"
  ON public.workout_template_parts FOR SELECT
  USING (public.is_template_coach(template_id));

CREATE POLICY "Coach can create own template parts"
  ON public.workout_template_parts FOR INSERT
  WITH CHECK (public.is_template_coach(template_id));

CREATE POLICY "Coach can update own template parts"
  ON public.workout_template_parts FOR UPDATE
  USING (public.is_template_coach(template_id));

CREATE POLICY "Coach can delete own template parts"
  ON public.workout_template_parts FOR DELETE
  USING (public.is_template_coach(template_id));
