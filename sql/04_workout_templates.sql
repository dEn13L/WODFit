-- ==========================================================
-- CrossFit WOD Fit: Workout Templates Migration & Security
-- ==========================================================

-- 1. WORKOUT TEMPLATES TABLE
CREATE TABLE IF NOT EXISTS public.workout_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. WORKOUT TEMPLATE PARTS TABLE
CREATE TABLE IF NOT EXISTS public.workout_template_parts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID NOT NULL REFERENCES public.workout_templates(id) ON DELETE CASCADE,
  type public.workout_part_type NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_workout_templates_coach ON public.workout_templates(coach_id);
CREATE INDEX IF NOT EXISTS idx_workout_template_parts_template ON public.workout_template_parts(template_id);

-- Helper function to check template ownership safely without recursive queries
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

-- 3. ROW LEVEL SECURITY
ALTER TABLE public.workout_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_template_parts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Coach can view own templates" ON public.workout_templates;
DROP POLICY IF EXISTS "Coach can create own templates" ON public.workout_templates;
DROP POLICY IF EXISTS "Coach can update own templates" ON public.workout_templates;
DROP POLICY IF EXISTS "Coach can delete own templates" ON public.workout_templates;

DROP POLICY IF EXISTS "Coach can view own template parts" ON public.workout_template_parts;
DROP POLICY IF EXISTS "Coach can create own template parts" ON public.workout_template_parts;
DROP POLICY IF EXISTS "Coach can update own template parts" ON public.workout_template_parts;
DROP POLICY IF EXISTS "Coach can delete own template parts" ON public.workout_template_parts;

-- Policies for workout_templates (only coach owns and sees them)
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

-- Policies for workout_template_parts
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
