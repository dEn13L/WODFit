-- Шаг 3.4. Применять после 12 и проверки docs/12_security_hardening_preflight.sql.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
-- Блокируем новые несовместимые записи между проверкой и ALTER; данные не исправляем.
lock table public.workout_parts, public.part_results in share row exclusive mode;
do $$
begin
  if exists (select 1 from public.part_results r join public.workout_parts p on p.id = r.part_id
    where r.workout_id is distinct from p.workout_id) then
    raise exception 'Mismatched part/workout: review preflight; no automatic data repair';
  end if;
  if exists (select 1 from public.part_results where score_type is not null
    and score_type::text not in ('none','text','time','rounds_reps','weight','reps','distance','calories')) then
    raise exception 'Unknown score_type: review preflight; no automatic data repair';
  end if;
  if to_regtype('public.score_type') is null then
    create type public.score_type as enum ('none','text','time','rounds_reps','weight','reps','distance','calories');
  elsif (select array_agg(e.enumlabel::text order by e.enumsortorder) from pg_enum e
    where e.enumtypid = 'public.score_type'::regtype) is distinct from
    array['none','text','time','rounds_reps','weight','reps','distance','calories']::text[] then
    raise exception 'Existing score_type enum differs from the application contract';
  end if;
end;
$$;

-- Nullable сохраняется для старых строк; Dart по-прежнему применяет fallback text.
alter table public.part_results alter column score_type drop default;
alter table public.part_results alter column score_type type public.score_type
  using score_type::text::public.score_type;
alter table public.workout_parts alter column score_type drop default;

alter table public.workout_parts add constraint workout_parts_id_workout_id_key unique (id, workout_id);
alter table public.part_results add constraint part_results_part_workout_fkey
  foreign key (part_id, workout_id) references public.workout_parts (id, workout_id) on delete cascade
  not valid;
alter table public.part_results validate constraint part_results_part_workout_fkey;
-- Составной FK заменяет одиночный, чтобы PostgREST видел единственную связь с заданием.
do $$
declare fk record;
begin
  for fk in select c.conname from pg_constraint c
    where c.conrelid = 'public.part_results'::regclass and c.contype = 'f'
      and c.confrelid = 'public.workout_parts'::regclass
      and c.conkey = array[(select attnum from pg_attribute
        where attrelid = 'public.part_results'::regclass and attname = 'part_id')]::smallint[]
  loop
    execute format('alter table public.part_results drop constraint %I', fk.conname);
  end loop;
end;
$$;

-- Сохраняем TEXT-параметр RPC для совместимости с развёрнутым клиентом.
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
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_result public.part_results;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not private.can_write_result(p_workout_id, p_part_id) then
    raise exception 'Result is not writable for this workout' using errcode = '42501';
  end if;

  insert into public.part_results (
    id, workout_id, part_id, user_id, status, score_type, score_text,
    time_ms, rounds, reps, weight_kg, distance_m, calories, note,
    client_updated_at, last_operation_id, deleted_at, updated_at
  ) values (
    p_result_id, p_workout_id, p_part_id, v_user_id, p_status, p_score_type::public.score_type,
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
) from public, anon, authenticated;

grant execute on function public.sync_part_result(
  uuid, uuid, uuid, uuid, timestamptz, boolean, public.result_status, text,
  text, bigint, integer, integer, numeric, numeric, integer, text
) to authenticated;

commit;
