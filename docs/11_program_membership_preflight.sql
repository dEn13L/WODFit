-- Preflight for sql/11_harden_program_membership.sql.
-- Run in Supabase SQL Editor before the migration and save the result.

begin transaction read only;

-- Current grants and policies must be reviewed before they are replaced.
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name = 'program_members'
  and grantee in ('PUBLIC', 'anon', 'authenticated')
order by grantee, privilege_type;

select policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename = 'program_members'
order by policyname;

-- Confirm the RPC and private helpers used by the replacement policies.
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  p.prosecdef as security_definer,
  p.proconfig as runtime_settings,
  has_function_privilege('anon', p.oid, 'EXECUTE') as anon_can_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_can_execute,
  pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where (n.nspname = 'public' and p.proname = 'join_program_by_code')
   or (n.nspname = 'private' and p.proname in ('is_program_member', 'is_program_coach'))
order by n.nspname, p.proname;

-- Existing rows that conflict with the client-only join rule are reported, not changed.
select
  count(*) filter (where member_profile.id is null) as missing_profiles,
  count(*) filter (where member_profile.role <> 'client'::public.user_role) as non_client_members,
  count(*) filter (where p.coach_id = pm.user_id) as coaches_joined_to_own_programs
from public.program_members pm
join public.programs p on p.id = pm.program_id
left join public.profiles member_profile on member_profile.id = pm.user_id;

-- The primary key should make this empty; retain the check for live-schema drift.
select program_id, user_id, count(*) as duplicate_count
from public.program_members
group by program_id, user_id
having count(*) > 1;

rollback;
