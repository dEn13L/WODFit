-- Шаг 3.3. Применять вручную после docs/12_security_hardening_preflight.sql.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- Условия опираются на серверный profiles.role, не на JWT user_metadata.
create or replace function private.is_program_coach(p_program_id uuid, p_coach_id uuid default auth.uid())
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$
  select p_coach_id = auth.uid() and exists (
    select 1 from public.programs p join public.profiles pr on pr.id = p.coach_id
    where p.id = p_program_id and p.coach_id = p_coach_id and pr.role = 'coach'
  );
$$;

create or replace function private.is_program_member(p_program_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$
  select p_user_id = auth.uid() and exists (
    select 1 from public.program_members where program_id = p_program_id and user_id = p_user_id
  );
$$;

create or replace function private.is_coach()
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'coach');
$$;

create or replace function private.can_manage_workout(p_workout_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$
  select private.is_coach() and exists (
    select 1 from public.workouts where id = p_workout_id and coach_id = auth.uid()
  );
$$;

create or replace function private.can_user_view_workout(p_workout_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$
  select p_user_id = auth.uid() and (
    private.can_manage_workout(p_workout_id) or exists (
      select 1 from public.workouts w
      join public.workout_assignments wa on wa.workout_id = w.id
      join public.program_members pm on pm.program_id = wa.program_id
      where w.id = p_workout_id and w.status = 'published' and pm.user_id = auth.uid()
    )
  );
$$;

create or replace function private.can_write_result(p_workout_id uuid, p_part_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.profiles pr
    join public.program_members pm on pm.user_id = pr.id
    join public.workout_assignments wa on wa.program_id = pm.program_id
    join public.workouts w on w.id = wa.workout_id
    join public.workout_parts wp on wp.workout_id = w.id
    where pr.id = auth.uid() and pr.role = 'client' and w.status = 'published'
      and w.id = p_workout_id and wp.id = p_part_id
  );
$$;

create or replace function private.can_read_result(p_workout_id uuid, p_result_user_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$
  select auth.uid() is not null and (
    p_result_user_id = auth.uid()
    or private.can_manage_workout(p_workout_id)
    or exists (
      select 1 from public.workouts w
      join public.workout_assignments wa on wa.workout_id = w.id
      join public.program_members mine on mine.program_id = wa.program_id
      join public.program_members theirs on theirs.program_id = mine.program_id
      where w.id = p_workout_id and w.status = 'published'
        and mine.user_id = auth.uid() and theirs.user_id = p_result_user_id
    )
  );
$$;

create or replace function private.can_read_profile(p_profile_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$
  select auth.uid() is not null and (
    p_profile_id = auth.uid()
    or exists (
      select 1 from public.programs p
      join public.program_members pm on pm.program_id = p.id
      where (p.coach_id = auth.uid() and private.is_coach() and pm.user_id = p_profile_id)
         or (pm.user_id = auth.uid() and p.coach_id = p_profile_id)
    )
    or exists (
      select 1 from public.program_members mine
      join public.program_members theirs on theirs.program_id = mine.program_id
      where mine.user_id = auth.uid() and theirs.user_id = p_profile_id
    )
    or exists (
      select 1 from public.part_results r join public.workouts w on w.id = r.workout_id
      where r.user_id = p_profile_id and w.coach_id = auth.uid() and private.is_coach()
    )
  );
$$;

-- Пересоздаём весь набор: дополнительные permissive ALL-политики не должны обходить ограничения.
do $$
declare p record;
begin
  for p in select tablename, policyname from pg_policies
    where schemaname = 'public' and tablename in (
      'profiles', 'part_results', 'programs', 'workouts', 'workout_parts', 'workout_assignments'
    )
  loop
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
  end loop;
end;
$$;

create policy "Related users can read profiles" on public.profiles
  for select to authenticated using (private.can_read_profile(id));
create policy "Users can update own name" on public.profiles
  for update to authenticated using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
-- Отзыв табличного UPDATE обязателен: иначе role/email остаются изменяемыми.
revoke update on public.profiles from public, anon, authenticated;
do $$
declare c record;
begin
  for c in select attname from pg_attribute
    where attrelid = 'public.profiles'::regclass and attnum > 0 and not attisdropped
  loop
    execute format('revoke update (%I) on public.profiles from public, anon, authenticated', c.attname);
  end loop;
end;
$$;
grant update (full_name) on public.profiles to authenticated;

create policy "Users can read permitted results" on public.part_results
  for select to authenticated using (private.can_read_result(workout_id, user_id));
create policy "Clients can create permitted results" on public.part_results
  for insert to authenticated
  with check (user_id = (select auth.uid()) and private.can_write_result(workout_id, part_id));
create policy "Clients can update permitted results" on public.part_results
  for update to authenticated
  using (user_id = (select auth.uid()) and private.can_write_result(workout_id, part_id))
  with check (user_id = (select auth.uid()) and private.can_write_result(workout_id, part_id));
create policy "Clients can delete permitted results" on public.part_results
  for delete to authenticated
  using (user_id = (select auth.uid()) and private.can_write_result(workout_id, part_id));

create policy "Coach and members can read programs" on public.programs
  for select to authenticated
  using (private.is_program_coach(id, (select auth.uid())) or private.is_program_member(id, (select auth.uid())));
create policy "Coaches can create own programs" on public.programs
  for insert to authenticated with check (coach_id = (select auth.uid()) and (select private.is_coach()));
create policy "Coaches can update own programs" on public.programs
  for update to authenticated
  using (private.is_program_coach(id, (select auth.uid())))
  with check (coach_id = (select auth.uid()) and (select private.is_coach()));
create policy "Coaches can delete own programs" on public.programs
  for delete to authenticated using (private.is_program_coach(id, (select auth.uid())));

create policy "Users can read visible workouts" on public.workouts
  for select to authenticated using (private.can_user_view_workout(id, (select auth.uid())));
create policy "Coaches can create own workouts" on public.workouts
  for insert to authenticated with check (coach_id = (select auth.uid()) and (select private.is_coach()));
create policy "Coaches can update own workouts" on public.workouts
  for update to authenticated
  using (private.can_manage_workout(id))
  with check (coach_id = (select auth.uid()) and (select private.is_coach()));
create policy "Coaches can delete own workouts" on public.workouts
  for delete to authenticated using (private.can_manage_workout(id));

create policy "Users can read visible workout parts" on public.workout_parts
  for select to authenticated using (private.can_user_view_workout(workout_id, (select auth.uid())));
create policy "Coaches can manage own workout parts" on public.workout_parts
  for all to authenticated
  using (private.can_manage_workout(workout_id)) with check (private.can_manage_workout(workout_id));

create policy "Users can read visible assignments" on public.workout_assignments
  for select to authenticated
  using (private.can_user_view_workout(workout_id, (select auth.uid()))
    and (private.can_manage_workout(workout_id) or private.is_program_member(program_id, (select auth.uid()))));
create policy "Coaches can create own assignments" on public.workout_assignments
  for insert to authenticated
  with check (private.can_manage_workout(workout_id) and private.is_program_coach(program_id, (select auth.uid())));
create policy "Coaches can delete own assignments" on public.workout_assignments
  for delete to authenticated using (private.can_manage_workout(workout_id));

-- Legacy остаётся недоступным клиенту; исправляем адресатов, не выдавая grants.
do $$
declare p record;
begin
  for p in select tablename, policyname from pg_policies
    where schemaname = 'public' and tablename in ('workout_templates', 'workout_template_parts')
  loop
    execute format('alter policy %I on public.%I to authenticated', p.policyname, p.tablename);
  end loop;
end;
$$;
revoke all on public.workout_templates, public.workout_template_parts from public, anon, authenticated;

-- RESTRICT по умолчанию: при новых зависимостях миграция остановится, CASCADE нет.
drop function if exists private.is_group_member(uuid, uuid);
drop function if exists private.is_group_coach(uuid, uuid);

alter function public.set_workout_published_at() set search_path = pg_catalog, public;
revoke all on function public.set_workout_published_at() from public, anon, authenticated;
revoke create on schema public from public, anon, authenticated;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;
revoke all on all functions in schema private from public, anon;
grant execute on function private.is_coach(), private.can_manage_workout(uuid),
  private.can_write_result(uuid, uuid), private.can_read_result(uuid, uuid),
  private.can_read_profile(uuid) to authenticated;

-- Будущие объекты postgres требуют явного allow-list; service_role сохраняется.
alter default privileges for role postgres revoke execute on functions from public;
alter default privileges for role postgres in schema public
  revoke all on functions from public, anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on tables from public, anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from public, anon, authenticated;
alter default privileges for role postgres in schema private
  revoke all on functions from public, anon, authenticated;

commit;
