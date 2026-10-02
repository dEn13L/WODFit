-- Offline-first synchronization metadata for athlete results.
-- This migration is prepared for manual execution in Supabase SQL Editor.

alter table public.part_results
  add column if not exists client_updated_at timestamptz,
  add column if not exists last_operation_id uuid,
  add column if not exists deleted_at timestamptz;

update public.part_results
set client_updated_at = coalesce(client_updated_at, updated_at, created_at, now()),
    last_operation_id = coalesce(last_operation_id, gen_random_uuid())
where client_updated_at is null
   or last_operation_id is null;

alter table public.part_results
  alter column client_updated_at set default now(),
  alter column client_updated_at set not null,
  alter column last_operation_id set default gen_random_uuid(),
  alter column last_operation_id set not null;

create index if not exists idx_part_results_user_deleted
  on public.part_results(user_id, deleted_at);

create or replace function public.sync_part_result(
  p_operation_id uuid,
  p_result_id uuid,
  p_workout_id uuid,
  p_part_id uuid,
  p_client_updated_at timestamptz,
  p_deleted boolean,
  p_status public.result_status default 'done',
  p_score_type text default 'text',
  p_score_text text default '',
  p_time_ms bigint default null,
  p_rounds integer default null,
  p_reps integer default null,
  p_weight_kg numeric default null,
  p_distance_m numeric default null,
  p_calories integer default null,
  p_note text default ''
)
returns public.part_results
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_result public.part_results;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  insert into public.part_results (
    id, workout_id, part_id, user_id, status, score_type, score_text,
    time_ms, rounds, reps, weight_kg, distance_m, calories, note,
    client_updated_at, last_operation_id, deleted_at, updated_at
  ) values (
    p_result_id, p_workout_id, p_part_id, v_user_id, p_status, p_score_type,
    p_score_text, p_time_ms, p_rounds, p_reps, p_weight_kg, p_distance_m,
    p_calories, p_note, p_client_updated_at, p_operation_id,
    case when p_deleted then p_client_updated_at else null end, now()
  )
  on conflict (part_id, user_id) do update set
    status = excluded.status,
    score_type = excluded.score_type,
    score_text = excluded.score_text,
    time_ms = excluded.time_ms,
    rounds = excluded.rounds,
    reps = excluded.reps,
    weight_kg = excluded.weight_kg,
    distance_m = excluded.distance_m,
    calories = excluded.calories,
    note = excluded.note,
    client_updated_at = excluded.client_updated_at,
    last_operation_id = excluded.last_operation_id,
    deleted_at = excluded.deleted_at,
    updated_at = now()
  where (excluded.client_updated_at, excluded.last_operation_id::text) >
        (part_results.client_updated_at, part_results.last_operation_id::text);

  select * into v_result
  from public.part_results
  where part_id = p_part_id and user_id = v_user_id;

  return v_result;
end;
$$;

revoke all on function public.sync_part_result(
  uuid, uuid, uuid, uuid, timestamptz, boolean, public.result_status, text,
  text, bigint, integer, integer, numeric, numeric, integer, text
) from public;

grant execute on function public.sync_part_result(
  uuid, uuid, uuid, uuid, timestamptz, boolean, public.result_status, text,
  text, bigint, integer, integer, numeric, numeric, integer, text
) to authenticated;
