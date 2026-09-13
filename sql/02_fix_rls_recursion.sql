-- ==========================================================
-- Migration 02: Fix Infinite Recursion in RLS Policies (42P17)
-- ==========================================================

-- 1. Helper SECURITY DEFINER functions (bypasses RLS recursion on internal queries)
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

-- 2. Drop previous policies that caused recursion
DROP POLICY IF EXISTS "Coach and members can read groups" ON public.groups;
DROP POLICY IF EXISTS "Members and coaches can view group members" ON public.group_members;
DROP POLICY IF EXISTS "Users can join groups" ON public.group_members;
DROP POLICY IF EXISTS "Users or coaches can leave/remove from group" ON public.group_members;
DROP POLICY IF EXISTS "Clients can read published workouts assigned to their groups" ON public.workouts;
DROP POLICY IF EXISTS "Users can view workout parts of visible workouts" ON public.workout_parts;
DROP POLICY IF EXISTS "Users can view assignments of visible workouts/groups" ON public.workout_assignments;
DROP POLICY IF EXISTS "Coach can manage assignments" ON public.workout_assignments;
DROP POLICY IF EXISTS "Users can view results for assigned workouts" ON public.part_results;

-- 3. Re-create non-recursive policies
CREATE POLICY "Coach and members can read groups"
  ON public.groups FOR SELECT
  TO authenticated
  USING (
    coach_id = auth.uid()
    OR public.is_group_member(id, auth.uid())
  );

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

CREATE POLICY "Clients can read published workouts assigned to their groups"
  ON public.workouts FOR SELECT
  TO authenticated
  USING (
    public.can_user_view_workout(id, auth.uid())
  );

CREATE POLICY "Users can view workout parts of visible workouts"
  ON public.workout_parts FOR SELECT
  TO authenticated
  USING (
    public.can_user_view_workout(workout_id, auth.uid())
  );

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

CREATE POLICY "Users can view results for assigned workouts"
  ON public.part_results FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.can_user_view_workout(workout_id, auth.uid())
  );
