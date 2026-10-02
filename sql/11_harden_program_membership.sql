-- Security hardening step 3.2: program membership.
-- Apply manually only after docs/11_program_membership_preflight.sql is reviewed.

begin;

-- Joining is allowed only through the SECURITY DEFINER RPC below.
revoke insert on table public.program_members from authenticated;

-- Rebuild the policy set so no legacy INSERT/ALL policy can preserve direct joins.
do $$
declare
  policy_record record;
begin
  for policy_record in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'program_members'
  loop
    execute format(
      'drop policy if exists %I on public.program_members',
      policy_record.policyname
    );
  end loop;
end
$$;

create policy "Program members and coach can read membership"
  on public.program_members
  for select
  to authenticated
  using (
    private.is_program_coach(program_id, auth.uid())
    or private.is_program_member(program_id, auth.uid())
  );

create policy "Member can leave or coach can remove member"
  on public.program_members
  for delete
  to authenticated
  using (
    user_id = auth.uid()
    or private.is_program_coach(program_id, auth.uid())
  );

create or replace function public.join_program_by_code(code text)
returns json
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_user_role public.user_role;
  v_program_id uuid;
  v_program_name text;
  v_program_kind public.program_kind;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select role
  into v_user_role
  from public.profiles
  where id = v_user_id;

  if v_user_role is distinct from 'client'::public.user_role then
    raise exception 'Only clients can join programs' using errcode = '42501';
  end if;

  select id, name, kind
  into v_program_id, v_program_name, v_program_kind
  from public.programs
  where upper(invite_code) = upper(trim(code));

  if v_program_id is null then
    raise exception 'Программа с кодом % не найдена', code;
  end if;

  insert into public.program_members (program_id, user_id)
  values (v_program_id, v_user_id)
  on conflict (program_id, user_id) do nothing;

  return json_build_object(
    'id', v_program_id,
    'name', v_program_name,
    'kind', v_program_kind
  );
end;
$$;

revoke all on function public.join_program_by_code(text)
  from public, anon, authenticated;
grant execute on function public.join_program_by_code(text)
  to authenticated;

commit;
