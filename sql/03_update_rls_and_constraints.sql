-- ==========================================================
-- Migration 03: Constraints & Full CRUD Policies for Daily Use
-- ==========================================================

-- 1. Ensure Unique Constraint on (part_id, user_id) in part_results
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'part_results_part_id_user_id_key'
       OR (conrelid = 'public.part_results'::regclass AND contype = 'u')
  ) THEN
    ALTER TABLE public.part_results
    ADD CONSTRAINT part_results_part_id_user_id_key UNIQUE (part_id, user_id);
  END IF;
END $$;

-- 2. Drop existing Part Result policies to recreate with full CRUD support
DROP POLICY IF EXISTS "Clients can create own results" ON public.part_results;
DROP POLICY IF EXISTS "Clients can update own results" ON public.part_results;
DROP POLICY IF EXISTS "Clients can delete own results" ON public.part_results;
DROP POLICY IF EXISTS "Users can view results for assigned workouts" ON public.part_results;

-- 3. Recreate Part Results RLS policies
-- SELECT: athlete can view results if assigned to group or is coach of workout
CREATE POLICY "Users can view results for assigned workouts"
  ON public.part_results FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.can_user_view_workout(workout_id, auth.uid())
  );

-- INSERT: athlete can only record their own result
CREATE POLICY "Clients can create own results"
  ON public.part_results FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- UPDATE: athlete can only update their own result
CREATE POLICY "Clients can update own results"
  ON public.part_results FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- DELETE: athlete can only delete their own result
CREATE POLICY "Clients can delete own results"
  ON public.part_results FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- 4. Verify/Recreate Groups Delete & Update Policies for Coach
DROP POLICY IF EXISTS "Coach can update own groups" ON public.groups;
DROP POLICY IF EXISTS "Coach can delete own groups" ON public.groups;

CREATE POLICY "Coach can update own groups"
  ON public.groups FOR UPDATE
  TO authenticated
  USING (coach_id = auth.uid());

CREATE POLICY "Coach can delete own groups"
  ON public.groups FOR DELETE
  TO authenticated
  USING (coach_id = auth.uid());

-- 5. Verify/Recreate Group Members Delete Policy (Athletes can leave, Coaches can remove)
DROP POLICY IF EXISTS "Users or coaches can leave/remove from group" ON public.group_members;

CREATE POLICY "Users or coaches can leave/remove from group"
  ON public.group_members FOR DELETE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_group_coach(group_id, auth.uid())
  );

-- 6. Verify Workouts & Parts Policies for Coaches
DROP POLICY IF EXISTS "Coach can manage workouts" ON public.workouts;
CREATE POLICY "Coach can manage workouts"
  ON public.workouts FOR ALL
  TO authenticated
  USING (coach_id = auth.uid())
  WITH CHECK (coach_id = auth.uid());

DROP POLICY IF EXISTS "Coach can manage workout parts" ON public.workout_parts;
CREATE POLICY "Coach can manage workout parts"
  ON public.workout_parts FOR ALL
  TO authenticated
  USING (
    workout_id IN (SELECT id FROM public.workouts WHERE coach_id = auth.uid())
  )
  WITH CHECK (
    workout_id IN (SELECT id FROM public.workouts WHERE coach_id = auth.uid())
  );
