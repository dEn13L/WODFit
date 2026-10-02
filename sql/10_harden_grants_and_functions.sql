-- Security hardening step 3.1: grants and functions.
-- Apply manually only after docs/10_grants_functions_preflight.sql is reviewed.

begin;

-- Anonymous clients must not have table-level access, even when RLS would reject rows.
revoke all privileges on table
  public.profiles,
  public.programs,
  public.program_members,
  public.workouts,
  public.workout_parts,
  public.workout_assignments,
  public.workout_views,
  public.part_results,
  public.workout_templates,
  public.workout_template_parts
from public, anon;

-- Replace authenticated table grants with the operations used by the application.
revoke all privileges on table
  public.profiles,
  public.programs,
  public.program_members,
  public.workouts,
  public.workout_parts,
  public.workout_assignments,
  public.workout_views,
  public.part_results,
  public.workout_templates,
  public.workout_template_parts
from authenticated;

grant select, update on table public.profiles to authenticated;
grant select, insert, update, delete on table public.programs to authenticated;
grant select, insert, delete on table public.program_members to authenticated;
grant select, insert, update, delete on table public.workouts to authenticated;
grant select, insert, update, delete on table public.workout_parts to authenticated;
grant select, insert, delete on table public.workout_assignments to authenticated;
grant select, insert, update on table public.workout_views to authenticated;
grant select, insert, update, delete on table public.part_results to authenticated;

-- Helper functions remain available to RLS but leave PostgREST's exposed public schema.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

alter function public.is_program_member(uuid, uuid) set schema private;
alter function public.is_program_coach(uuid, uuid) set schema private;
alter function public.can_user_view_workout(uuid, uuid) set schema private;
alter function public.is_template_coach(uuid) set schema private;
alter function public.is_group_member(uuid, uuid) set schema private;
alter function public.is_group_coach(uuid, uuid) set schema private;

alter function private.is_program_member(uuid, uuid)
  set search_path = pg_catalog, public;
alter function private.is_program_coach(uuid, uuid)
  set search_path = pg_catalog, public;
alter function private.can_user_view_workout(uuid, uuid)
  set search_path = pg_catalog, public;
alter function private.is_template_coach(uuid)
  set search_path = pg_catalog, public;
alter function private.is_group_member(uuid, uuid)
  set search_path = pg_catalog, public;
alter function private.is_group_coach(uuid, uuid)
  set search_path = pg_catalog, public;

revoke all on function private.is_program_member(uuid, uuid) from public, anon;
revoke all on function private.is_program_coach(uuid, uuid) from public, anon;
revoke all on function private.can_user_view_workout(uuid, uuid) from public, anon;
revoke all on function private.is_template_coach(uuid) from public, anon;
revoke all on function private.is_group_member(uuid, uuid) from public, anon;
revoke all on function private.is_group_coach(uuid, uuid) from public, anon;

grant execute on function private.is_program_member(uuid, uuid) to authenticated;
grant execute on function private.is_program_coach(uuid, uuid) to authenticated;
grant execute on function private.can_user_view_workout(uuid, uuid) to authenticated;
grant execute on function private.is_template_coach(uuid) to authenticated;
grant execute on function private.is_group_member(uuid, uuid) to authenticated;
grant execute on function private.is_group_coach(uuid, uuid) to authenticated;

-- Trigger and public RPC functions receive an explicit safe search_path.
alter function public.handle_new_user() set search_path = pg_catalog, public;
alter function public.join_program_by_code(text) set search_path = pg_catalog, public;
alter function public.sync_part_result(
  uuid, uuid, uuid, uuid, timestamptz, boolean, public.result_status, text,
  text, bigint, integer, integer, numeric, numeric, integer, text
) set search_path = pg_catalog, public;

revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.join_program_by_code(text) from public, anon, authenticated;
revoke all on function public.sync_part_result(
  uuid, uuid, uuid, uuid, timestamptz, boolean, public.result_status, text,
  text, bigint, integer, integer, numeric, numeric, integer, text
) from public, anon, authenticated;

grant execute on function public.join_program_by_code(text) to authenticated;
grant execute on function public.sync_part_result(
  uuid, uuid, uuid, uuid, timestamptz, boolean, public.result_status, text,
  text, bigint, integer, integer, numeric, numeric, integer, text
) to authenticated;

commit;
