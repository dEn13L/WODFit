-- Preflight for sql/10_harden_grants_and_functions.sql.
-- Run in Supabase SQL Editor before the migration and save the result.

begin transaction read only;

-- The migration expects exactly these application tables to exist.
select expected.table_name,
       to_regclass(format('public.%I', expected.table_name)) is not null as exists
from unnest(array[
  'profiles',
  'programs',
  'program_members',
  'workouts',
  'workout_parts',
  'workout_assignments',
  'workout_views',
  'part_results',
  'workout_templates',
  'workout_template_parts'
]) as expected(table_name)
order by expected.table_name;

-- Confirm signatures, owners, security mode, search_path and current EXECUTE.
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  pg_get_userbyid(p.proowner) as owner_name,
  p.prosecdef as security_definer,
  p.proconfig as runtime_settings,
  coalesce((
    select bool_or(acl.grantee = 0 and acl.privilege_type = 'EXECUTE')
    from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) as acl
  ), false) as public_can_execute,
  has_function_privilege('anon', p.oid, 'EXECUTE') as anon_can_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_can_execute
from pg_proc as p
join pg_namespace as n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'handle_new_user',
    'join_program_by_code',
    'sync_part_result',
    'is_program_member',
    'is_program_coach',
    'can_user_view_workout',
    'is_template_coach',
    'is_group_member',
    'is_group_coach'
  )
order by p.proname, identity_arguments;

-- Dependencies of legacy helpers must be reviewed before any later deletion.
-- Step 3.1 moves them to a non-exposed schema but deliberately does not delete them.
select
  p.oid::regprocedure as legacy_function,
  d.deptype,
  case d.classid
    when 'pg_proc'::regclass then d.objid::regprocedure::text
    when 'pg_rewrite'::regclass then (
      select format('%I.%I', n2.nspname, c.relname)
      from pg_rewrite r
      join pg_class c on c.oid = r.ev_class
      join pg_namespace n2 on n2.oid = c.relnamespace
      where r.oid = d.objid
    )
    else d.objid::text
  end as dependent_object
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
left join pg_depend d
  on d.refclassid = 'pg_proc'::regclass
 and d.refobjid = p.oid
where n.nspname = 'public'
  and p.proname in ('is_group_member', 'is_group_coach')
order by legacy_function::text, d.deptype, dependent_object;

select schemaname, tablename, policyname, qual, with_check
from pg_policies
where schemaname = 'public'
  and (coalesce(qual, '') ~ 'is_group_(member|coach)'
       or coalesce(with_check, '') ~ 'is_group_(member|coach)')
order by tablename, policyname;

-- Snapshot current table grants before replacing them with the allow-list.
select grantee, table_name, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('PUBLIC', 'anon', 'authenticated')
order by table_name, grantee, privilege_type;

rollback;
