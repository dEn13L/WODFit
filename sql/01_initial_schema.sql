-- ==========================================================
-- CrossFit WOD Fit: Initial Database Migration & Security
-- ==========================================================

-- 1. ENUM TYPES
CREATE TYPE public.user_role AS ENUM ('coach', 'client');
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

-- 3. GROUPS TABLE
CREATE TABLE public.groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  invite_code TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4. GROUP MEMBERS TABLE
CREATE TABLE public.group_members (
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  PRIMARY KEY (group_id, user_id)
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
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0
);

-- 7. WORKOUT ASSIGNMENTS TABLE
CREATE TABLE public.workout_assignments (
  workout_id UUID NOT NULL REFERENCES public.workouts(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  PRIMARY KEY (workout_id, group_id)
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
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE (part_id, user_id)
);

-- Indexes for performance
CREATE INDEX idx_groups_coach ON public.groups(coach_id);
CREATE INDEX idx_group_members_user ON public.group_members(user_id);
CREATE INDEX idx_workouts_coach ON public.workouts(coach_id);
CREATE INDEX idx_workout_parts_workout ON public.workout_parts(workout_id);
CREATE INDEX idx_workout_assignments_group ON public.workout_assignments(group_id);
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

-- 10. RPC: JOIN GROUP BY INVITE CODE
CREATE OR REPLACE FUNCTION public.join_group_by_code(code TEXT)
RETURNS JSON AS $$
DECLARE
  v_group_id UUID;
  v_group_name TEXT;
BEGIN
  SELECT id, name INTO v_group_id, v_group_name
  FROM public.groups
  WHERE UPPER(invite_code) = UPPER(TRIM(code));

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Группа с кодом % не найдена', code;
  END IF;

  INSERT INTO public.group_members (group_id, user_id)
  VALUES (v_group_id, auth.uid())
  ON CONFLICT (group_id, user_id) DO NOTHING;

  RETURN json_build_object('id', v_group_id, 'name', v_group_name);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. HELPER SECURITY DEFINER FUNCTIONS (Prevents RLS infinite recursion)
CREATE OR REPLACE FUNCTION public.is_group_member(p_group_id UUID, p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.group_members WHERE group_id = p_group_id AND user_id = p_user_id
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.is_group_coach(p_group_id UUID, p_coach_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.groups WHERE id = p_group_id AND coach_id = p_coach_id
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.can_user_view_workout(p_workout_id UUID, p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.workouts WHERE id = p_workout_id AND coach_id = p_user_id
  ) OR EXISTS (
    SELECT 1 FROM public.workouts w
    JOIN public.workout_assignments wa ON wa.workout_id = w.id
    JOIN public.group_members gm ON gm.group_id = wa.group_id
    WHERE w.id = p_workout_id AND w.status = 'published' AND gm.user_id = p_user_id
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 12. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
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

-- Groups policies
CREATE POLICY "Coach can create groups"
  ON public.groups FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = coach_id);

CREATE POLICY "Coach and members can read groups"
  ON public.groups FOR SELECT
  TO authenticated
  USING (
    coach_id = auth.uid()
    OR public.is_group_member(id, auth.uid())
  );

CREATE POLICY "Coach can update own groups"
  ON public.groups FOR UPDATE
  TO authenticated
  USING (coach_id = auth.uid());

CREATE POLICY "Coach can delete own groups"
  ON public.groups FOR DELETE
  TO authenticated
  USING (coach_id = auth.uid());

-- Group members policies
CREATE POLICY "Members and coaches can view group members"
  ON public.group_members FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_group_coach(group_id, auth.uid())
    OR public.is_group_member(group_id, auth.uid())
  );

CREATE POLICY "Users can join groups"
  ON public.group_members FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid() OR public.is_group_coach(group_id, auth.uid()));

CREATE POLICY "Users or coaches can leave/remove from group"
  ON public.group_members FOR DELETE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_group_coach(group_id, auth.uid())
  );

-- Workouts policies
CREATE POLICY "Coach can manage workouts"
  ON public.workouts FOR ALL
  TO authenticated
  USING (coach_id = auth.uid())
  WITH CHECK (coach_id = auth.uid());

CREATE POLICY "Clients can read published workouts assigned to their groups"
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
CREATE POLICY "Users can view assignments of visible workouts/groups"
  ON public.workout_assignments FOR SELECT
  TO authenticated
  USING (
    public.is_group_coach(group_id, auth.uid())
    OR public.is_group_member(group_id, auth.uid())
  );

CREATE POLICY "Coach can manage assignments"
  ON public.workout_assignments FOR ALL
  TO authenticated
  USING (
    public.is_group_coach(group_id, auth.uid())
  )
  WITH CHECK (
    public.is_group_coach(group_id, auth.uid())
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
