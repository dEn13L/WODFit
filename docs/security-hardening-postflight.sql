-- Только чтение после 10/11/12/13. Все checks должны вернуть PASS.
-- Дополнительно вручную проверить Data API exposed schemas: private отсутствует.
begin transaction read only;
select current_database(), current_user, now() as audited_at;

with tables as (
  select c.oid,c.relname,c.relrowsecurity from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind in ('r','p')
), functions as (
  select p.*,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','private') and p.prokind='f'
), checks as (
  select 'ten app tables with RLS' as check_name,
    count(*)=10 and bool_and(relrowsecurity) as passed from tables
  union all
  select 'no effective anon table/column privileges',not exists (
    select 1 from tables where has_table_privilege('anon',oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
      or has_any_column_privilege('anon',oid,'SELECT,INSERT,UPDATE,REFERENCES'))
  union all
  select 'membership grants SELECT/DELETE only',
    has_table_privilege('authenticated','public.program_members','SELECT')
    and has_table_privilege('authenticated','public.program_members','DELETE')
    and not has_table_privilege('authenticated','public.program_members','INSERT,UPDATE,TRUNCATE,REFERENCES,TRIGGER')
    and not has_any_column_privilege('authenticated','public.program_members','INSERT,UPDATE,REFERENCES')
  union all
  select 'profile UPDATE limited to full_name',
    not has_table_privilege('authenticated','public.profiles','UPDATE,INSERT,DELETE')
    and has_column_privilege('authenticated','public.profiles','full_name','UPDATE')
    and not exists (select 1 from pg_attribute where attrelid='public.profiles'::regclass
      and attnum>0 and not attisdropped and attname<>'full_name'
      and has_column_privilege('authenticated',attrelid,attname,'UPDATE'))
  union all
  select 'only two authenticated public RPCs',
    count(*)=2 and bool_and(proname in ('join_program_by_code','sync_part_result'))
    from functions where nspname='public' and has_function_privilege('authenticated',oid,'EXECUTE')
  union all
  select 'no anon EXECUTE',not exists (
    select 1 from functions where has_function_privilege('anon',oid,'EXECUTE'))
  union all
  select 'safe search_path on all app functions',
    count(*)>=11 and bool_and(coalesce(proconfig @> array['search_path=pg_catalog, public'],false)) from functions
  union all
  select 'private schema USAGE only',
    has_schema_privilege('authenticated','private','USAGE')
    and not has_schema_privilege('authenticated','private','CREATE')
    and not has_schema_privilege('anon','private','USAGE,CREATE')
    and not has_schema_privilege('authenticated','public','CREATE')
  union all
  select 'no public helpers or legacy group helpers',not exists (
    select 1 from functions where proname in ('is_group_member','is_group_coach')
      or (nspname='public' and proname in ('is_program_member','is_program_coach','can_user_view_workout','is_template_coach')))
  union all
  select 'membership has exactly SELECT/DELETE policies',
    count(*)=2 and bool_and(cmd in ('SELECT','DELETE') and roles=array['authenticated']::name[])
    from pg_policies where schemaname='public' and tablename='program_members'
  union all
  select 'no PUBLIC policies',not exists (
    select 1 from pg_policies where schemaname='public' and roles @> array['public']::name[])
  union all
  select 'new profile/result policies only',
    (select count(*)=2 and bool_and(policyname in ('Related users can read profiles','Users can update own name'))
      from pg_policies where schemaname='public' and tablename='profiles')
    and (select count(*)=4 and bool_and(policyname in ('Users can read permitted results','Clients can create permitted results',
      'Clients can update permitted results','Clients can delete permitted results'))
      from pg_policies where schemaname='public' and tablename='part_results')
  union all
  select 'legacy tables inaccessible',not exists (
    select 1 from tables where relname in ('workout_templates','workout_template_parts')
      and (has_table_privilege('authenticated',oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
        or has_any_column_privilege('authenticated',oid,'SELECT,INSERT,UPDATE,REFERENCES')))
  union all
  select 'validated composite result FK',exists (
    select 1 from pg_constraint where conrelid='public.part_results'::regclass
      and conname='part_results_part_workout_fkey' and contype='f' and convalidated
      and confrelid='public.workout_parts'::regclass and array_length(conkey,1)=2 and confdeltype='c')
  union all
  select 'score enum and no legacy default',
    (select udt_name='score_type' from information_schema.columns
      where table_schema='public' and table_name='part_results' and column_name='score_type')
    and (select column_default is null from information_schema.columns
      where table_schema='public' and table_name='workout_parts' and column_name='score_type')
  union all
  select 'no mismatched result/workout',not exists (
    select 1 from public.part_results r left join public.workout_parts p on p.id=r.part_id
      where r.workout_id is distinct from p.workout_id)
  union all
  select 'join RPC code TEXT to JSON DEFINER',exists (
    select 1 from functions where nspname='public' and proname='join_program_by_code'
      and proargnames[1]='code' and oidvectortypes(proargtypes)='text'
      and prorettype='json'::regtype and prosecdef)
  union all
  select 'sync RPC INVOKER keeps TEXT score parameter',exists (
    select 1 from functions where nspname='public' and proname='sync_part_result'
      and not prosecdef and proargnames[8]='p_score_type' and proargtypes[7]='text'::regtype)
  union all
  select 'both triggers enabled',(
    select count(*)=2 and bool_and(tgenabled<>'D') from pg_trigger
    where not tgisinternal and tgname in ('on_auth_user_created','set_workout_published_at'))
)
select case when passed is true then 'PASS' else 'FAIL' end as status,check_name
from checks order by check_name;

-- Проверить USING/WITH CHECK и тела функций: одних имён политик недостаточно.
select tablename,policyname,roles,cmd,qual,with_check
from pg_policies where schemaname='public' order by tablename,policyname;
select n.nspname,p.oid::regprocedure::text as function_name,p.prosecdef,p.proconfig,
  pg_get_userbyid(p.proowner) as owner,pg_get_functiondef(p.oid) as definition
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','private') and p.prokind='f'
order by n.nspname,p.oid::regprocedure::text;
select pg_get_userbyid(defaclrole) as creator,defaclnamespace::regnamespace as schema,
  defaclobjtype,defaclacl from pg_default_acl order by creator,defaclnamespace::regnamespace::text,defaclobjtype;
rollback;
