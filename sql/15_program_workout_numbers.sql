-- После 14_atomic_workout_save.sql. Применить вручную до выпуска клиента.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
lock table public.workout_assignments in access exclusive mode;

alter table public.workout_assignments add column workout_number integer;
-- Исторические назначения получают номера по дате, затем по UUID для равных дат.
with numbered as (
  select a.workout_id, a.program_id,
    row_number() over (partition by a.program_id order by w.scheduled_at, w.created_at, w.id)::integer as number
  from public.workout_assignments a join public.workouts w on w.id = a.workout_id
)
update public.workout_assignments a set workout_number = n.number
from numbered n where n.workout_id = a.workout_id and n.program_id = a.program_id;
alter table public.workout_assignments alter column workout_number set not null;
alter table public.workout_assignments add constraint workout_number_positive check (workout_number > 0);
alter table public.workout_assignments add constraint program_workout_number_unique unique (program_id, workout_number);

-- Внутренний счётчик не доступен через Data API, не зависит от удаления тренировок.
create table private.program_workout_counters (
  program_id uuid primary key references public.programs(id) on delete cascade,
  last_number integer not null check (last_number > 0)
);
alter table private.program_workout_counters enable row level security;
revoke all on private.program_workout_counters from public, anon, authenticated;
insert into private.program_workout_counters (program_id, last_number)
select program_id, max(workout_number) from public.workout_assignments group by program_id;

-- SECURITY DEFINER нужен только для закрытого счётчика; оба владельца проверяются
-- явно. RLS самого INSERT назначения продолжает действовать после BEFORE trigger.
create function private.assign_program_workout_number()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.programs p join public.workouts w on w.id = new.workout_id
    join public.profiles u on u.id = auth.uid()
    where p.id = new.program_id and p.coach_id = auth.uid()
      and w.coach_id = auth.uid() and u.role = 'coach'
  ) then
    raise exception 'Program or workout is unavailable' using errcode = '42501';
  end if;
  if tg_op = 'UPDATE' then
    if new.program_id <> old.program_id or new.workout_id <> old.workout_id
      or new.workout_number <> old.workout_number then
      raise exception 'Workout number is immutable' using errcode = '22023';
    end if;
    return new;
  end if;
  -- ON CONFLICT DO NOTHING в save_workout не расходует номер повторно.
  select a.workout_number into new.workout_number from public.workout_assignments a
    where a.program_id = new.program_id and a.workout_id = new.workout_id;
  if new.workout_number is not null then return new; end if;
  insert into private.program_workout_counters (program_id, last_number)
    values (new.program_id, 1)
    on conflict (program_id) do update
      set last_number = private.program_workout_counters.last_number + 1
    returning last_number into new.workout_number;
  return new;
end;
$$;
revoke all on function private.assign_program_workout_number() from public, anon, authenticated;
create trigger assign_program_workout_number before insert or update on public.workout_assignments
  for each row execute function private.assign_program_workout_number();

-- Единый порядок блокировки счётчиков при назначении нескольким программам.
create or replace function public.save_workout(
  p_workout_id uuid,
  p_title text,
  p_description text,
  p_scheduled_at timestamptz,
  p_status public.workout_status,
  p_parts jsonb,
  p_program_ids uuid[]
)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  v_id uuid;
  v_part_ids uuid[];
  v_workout public.workouts;
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles where id = auth.uid() and role = 'coach'
  ) then
    raise exception 'Coach authentication required' using errcode = '42501';
  end if;
  if p_scheduled_at is null or p_status is null or p_title is null
    or p_description is null or p_program_ids is null
    or p_parts is null or jsonb_typeof(p_parts) <> 'array' then
    raise exception 'Invalid workout form' using errcode = '22023';
  end if;
  if exists (select 1 from jsonb_array_elements(p_parts) t
    where jsonb_typeof(t) <> 'object' or t->>'id' is null
      or jsonb_typeof(t->'title') is distinct from 'string'
      or jsonb_typeof(t->'description') is distinct from 'string') then
    raise exception 'Invalid tasks' using errcode = '22023';
  end if;
  select coalesce(array_agg((t->>'id')::uuid), '{}'::uuid[])
    into v_part_ids from jsonb_array_elements(p_parts) t;
  if cardinality(v_part_ids) <> (select count(distinct id) from unnest(v_part_ids) id)
    or cardinality(p_program_ids) <> (select count(distinct id) from unnest(p_program_ids) id) then
    raise exception 'Duplicate or null IDs' using errcode = '22023';
  end if;
  if p_status = 'published' and (cardinality(p_program_ids) = 0
    or cardinality(v_part_ids) = 0 or exists (
      select 1 from jsonb_array_elements(p_parts) t where btrim(t->>'title') = ''
    )) then
    raise exception 'Published workout requires programs and named tasks' using errcode = '22023';
  end if;
  if cardinality(p_program_ids) <> (select count(*) from public.programs
    where id = any(p_program_ids) and coach_id = auth.uid()) then
    raise exception 'Program is unavailable' using errcode = '42501';
  end if;

  if p_workout_id is null then
    -- SELECT-policy использует STABLE helper: INSERT RETURNING ещё не видит
    -- новую строку через helper. UUID назначаем до INSERT; читаем следующим запросом.
    v_id := gen_random_uuid();
    insert into public.workouts (id, coach_id, title, description, scheduled_at, status)
      values (v_id, auth.uid(), btrim(p_title), btrim(p_description), p_scheduled_at, p_status);
  else
    -- Сериализация параллельных сохранений одной тренировки.
    select id into v_id from public.workouts
      where id = p_workout_id and coach_id = auth.uid() for update;
    if v_id is null then
      raise exception 'Workout is unavailable' using errcode = '42501';
    end if;
    update public.workouts set title = btrim(p_title), description = btrim(p_description),
      scheduled_at = p_scheduled_at, status = p_status, updated_at = now() where id = v_id;
  end if;

  -- Существующие UUID сохраняются; чужие UUID не перемещаются и не перезаписываются.
  -- Невидимая RLS коллизия приводит к ошибке PK и откату всей транзакции.
  update public.workout_parts p set title = btrim(t.value->>'title'),
    description = btrim(t.value->>'description'), sort_order = t.ordinality::integer - 1
    from jsonb_array_elements(p_parts) with ordinality t(value, ordinality)
    where p.id = (t.value->>'id')::uuid and p.workout_id = v_id;
  insert into public.workout_parts (id, workout_id, title, description, sort_order)
    select (t.value->>'id')::uuid, v_id, btrim(t.value->>'title'),
      btrim(t.value->>'description'), t.ordinality::integer - 1
    from jsonb_array_elements(p_parts) with ordinality t(value, ordinality)
    where not exists (select 1 from public.workout_parts p
      where p.id = (t.value->>'id')::uuid and p.workout_id = v_id);
  delete from public.workout_parts where workout_id = v_id and not (id = any(v_part_ids));

  -- Сохраняем assigned_at неизменённых назначений.
  delete from public.workout_assignments
    where workout_id = v_id and not (program_id = any(p_program_ids));
  insert into public.workout_assignments (workout_id, program_id)
    select v_id, id from unnest(p_program_ids) id order by id on conflict do nothing;

  select * into v_workout from public.workouts where id = v_id;
  return to_jsonb(v_workout) || jsonb_build_object(
    'workout_parts', (select coalesce(jsonb_agg(to_jsonb(p) order by p.sort_order), '[]'::jsonb)
      from public.workout_parts p where p.workout_id = v_id),
    'workout_assignments', (select coalesce(jsonb_agg(to_jsonb(a) ||
      jsonb_build_object('programs', jsonb_build_object('name', p.name)) order by a.program_id), '[]'::jsonb)
      from public.workout_assignments a join public.programs p on p.id = a.program_id
      where a.workout_id = v_id)
  );
end;
$$;
revoke all on function public.save_workout(uuid, text, text, timestamptz, public.workout_status, jsonb, uuid[])
  from public, anon, authenticated;
grant execute on function public.save_workout(uuid, text, text, timestamptz, public.workout_status, jsonb, uuid[])
  to authenticated;
commit;
