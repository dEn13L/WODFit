-- ==========================================================
-- CrossFit WOD Fit: Score Types & Structured Results Migration
-- ==========================================================

-- 1. Add score_type to workout_parts
-- Available values: none, text, time, rounds_reps, weight, reps, distance, calories
ALTER TABLE public.workout_parts 
ADD COLUMN IF NOT EXISTS score_type TEXT NOT NULL DEFAULT 'text';

-- 2. Add score_type to workout_template_parts
ALTER TABLE public.workout_template_parts 
ADD COLUMN IF NOT EXISTS score_type TEXT NOT NULL DEFAULT 'text';

-- 3. Add distance_m and calories to part_results
ALTER TABLE public.part_results 
ADD COLUMN IF NOT EXISTS distance_m NUMERIC(8, 2);

ALTER TABLE public.part_results 
ADD COLUMN IF NOT EXISTS calories INTEGER;
