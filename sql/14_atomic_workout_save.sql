-- После 13_result_integrity.sql. Применяется вручную, до выпуска клиента с RPC.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- Отложенный NO ACTION проверяется при коммите: удаление всей тренировки по-прежнему
-- каскадно удаляет результаты через workout_id, а отдельного задания — запрещено.
-- FK также закрывает гонку между удалением задания и вставкой результата.
alter table public.part_results drop constraint part_results_part_workout_fkey;
alter table public.part_results add constraint part_results_part_workout_fkey
  foreign key (part_id, workout_id) references public.workout_parts (id, workout_id)
  on delete no action deferrable initially deferred;

create or replace function private.prevent_part_with_results_delete()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if exists (select 1 from public.workouts where id = old.workout_id)
    and exists (select 1 from public.part_results where part_id = old.id) then
    raise exception 'Cannot delete a task with results' using errcode = 'W0001';
  end if;
  return old;
end;
$$;
revoke all on function private.prevent_part_with_results_delete() from public, anon, authenticated;
create trigger prevent_part_with_results_delete before delete on public.workout_parts
  for each row execute function private.prevent_part_with_results_delete();

-- Единственный запрос сохраняет всю форму и возвращает готовую проекцию.
-- SECURITY INVOKER сохраняет действующие RLS и табличные права.
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
    select v_id, id from unnest(p_program_ids) id on conflict do nothing;

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
