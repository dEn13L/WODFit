-- Только чтение. Сохранить результаты перед 12/13; ненулевые счётчики разобрать вручную.
begin transaction read only;
select current_database(), current_user, version(), now() as audited_at;

select r.workout_id is distinct from p.workout_id as mismatched,
  count(*) as result_count
from public.part_results r left join public.workout_parts p on p.id = r.part_id
group by r.workout_id is distinct from p.workout_id;
select score_type::text, count(*) from public.part_results group by score_type::text order by 1;
select count(*) filter (where pr.id is null) as missing_profiles,
  count(*) filter (where pr.role <> 'client') as non_client_members,
  count(*) filter (where p.coach_id = pm.user_id) as coaches_joined_to_own_programs
from public.program_members pm join public.programs p on p.id = pm.program_id
left join public.profiles pr on pr.id = pm.user_id;
select count(*) as invalid_program_owners from public.programs p
join public.profiles pr on pr.id = p.coach_id where pr.role <> 'coach';
select count(*) as invalid_workout_owners from public.workouts w
join public.profiles pr on pr.id = w.coach_id where pr.role <> 'coach';

select tablename, policyname, roles, cmd, qual, with_check
from pg_policies where schemaname = 'public' order by tablename, policyname;
select table_name, grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and grantee in ('PUBLIC', 'anon', 'authenticated')
order by table_name, grantee, privilege_type;
select table_name, column_name, grantee, privilege_type
from information_schema.column_privileges
where table_schema = 'public' and grantee in ('PUBLIC', 'anon', 'authenticated')
order by table_name, column_name, grantee, privilege_type;

select n.nspname, p.oid::regprocedure::text as function_name,
  pg_get_userbyid(p.proowner) as owner, p.prosecdef, p.proconfig,
  has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_execute,
  pg_get_functiondef(p.oid) as definition
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private') and p.prokind = 'f'
order by n.nspname, p.oid::regprocedure::text;

-- RESTRICT должен остановить удаление при любой новой зависимости.
select p.oid::regprocedure::text as legacy_function, d.deptype,
  pg_describe_object(d.classid, d.objid, d.objsubid) as dependent_object
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
left join pg_depend d on d.refclassid = 'pg_proc'::regclass and d.refobjid = p.oid
where n.nspname in ('public', 'private') and p.proname in ('is_group_member', 'is_group_coach')
order by p.oid::regprocedure::text, d.deptype;

select conrelid::regclass::text as table_name, conname, convalidated,
  pg_get_constraintdef(oid) as definition
from pg_constraint where connamespace = 'public'::regnamespace
order by conrelid::regclass::text, conname;
select table_name, column_name, udt_name, is_nullable, column_default
from information_schema.columns where table_schema = 'public'
  and ((table_name = 'part_results' and column_name = 'score_type')
    or (table_name = 'workout_parts' and column_name = 'score_type'))
order by table_name;
rollback;
