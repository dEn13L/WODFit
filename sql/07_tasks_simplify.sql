-- Migration: 07_tasks_simplify.sql
-- Simplifies workout_parts and adds score_type directly to part_results

ALTER TABLE public.workout_parts ALTER COLUMN type DROP NOT NULL;
ALTER TABLE public.workout_parts ALTER COLUMN score_type DROP NOT NULL;

ALTER TABLE public.part_results ADD COLUMN IF NOT EXISTS score_type public.score_type;

UPDATE public.part_results
SET score_type = workout_parts.score_type
FROM public.workout_parts
WHERE part_results.part_id = workout_parts.id
  AND part_results.score_type IS NULL
  AND workout_parts.score_type IS NOT NULL;

UPDATE public.part_results
SET score_type = 'text'
WHERE score_type IS NULL;
