-- ==========================================================
-- Migration 06: Rename Groups to Training Programs
-- ==========================================================

-- 1. Rename tables
ALTER TABLE IF EXISTS public.groups RENAME TO programs;
ALTER TABLE IF EXISTS public.group_members RENAME TO program_members;

-- 2. Rename foreign key columns
ALTER TABLE IF EXISTS public.program_members RENAME COLUMN group_id TO program_id;
ALTER TABLE IF EXISTS public.workout_assignments RENAME COLUMN group_id TO program_id;

-- 3. Create program_kind enum if not exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'program_kind') THEN
    CREATE TYPE public.program_kind AS ENUM ('personal', 'group');
  END IF;
END $$;

-- 4. Add new columns to programs table
ALTER TABLE public.programs ADD COLUMN IF NOT EXISTS kind public.program_kind NOT NULL DEFAULT 'group';
ALTER TABLE public.programs ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT '';
ALTER TABLE public.programs ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now());

-- 5. Helper security definer functions
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

-- 6. Drop old RLS policies dynamically
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('programs', 'program_members', 'workout_assignments')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', pol.policyname, pol.schemaname, pol.tablename);
  END LOOP;
END $$;

-- 7. Enable RLS and create new policies

-- Programs policies
ALTER TABLE public.programs ENABLE ROW LEVEL SECURITY;

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
ALTER TABLE public.program_members ENABLE ROW LEVEL SECURITY;

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

-- Workout assignments policies
ALTER TABLE public.workout_assignments ENABLE ROW LEVEL SECURITY;

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

-- 8. RPC: join_program_by_code (replacing join_group_by_code)
DROP FUNCTION IF EXISTS public.join_group_by_code(text);

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

GRANT EXECUTE ON FUNCTION public.join_program_by_code(TEXT) TO authenticated;

-- 9. Create indexes
CREATE INDEX IF NOT EXISTS idx_programs_coach ON public.programs(coach_id);
CREATE INDEX IF NOT EXISTS idx_program_members_program ON public.program_members(program_id);
CREATE INDEX IF NOT EXISTS idx_program_members_user ON public.program_members(user_id);
CREATE INDEX IF NOT EXISTS idx_workout_assignments_program ON public.workout_assignments(program_id);
