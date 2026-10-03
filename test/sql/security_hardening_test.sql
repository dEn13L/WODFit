-- Только одноразовая локальная БД / CI. Искусственные пользователи; запись в production запрещена.
create schema test;
grant usage on schema test to authenticated, anon;
create function test.assert_true(ok boolean, label text) returns void language plpgsql as $$
begin
  if ok is distinct from true then raise exception 'FAIL: %', label; end if;
end;
$$;
create function test.assert_denied(statement text, expected_state text) returns void language plpgsql as $$
begin
  begin
    execute statement;
  exception when others then
    if sqlstate = expected_state then return; end if;
    raise;
  end;
  raise exception 'Expected denial %, query succeeded: %', expected_state, statement;
end;
$$;
create function test.assert_no_rows_changed(statement text) returns void language plpgsql as $$
declare affected bigint;
begin
  execute statement;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Unauthorized rows changed: %', statement; end if;
end;
$$;

grant execute on all functions in schema test to authenticated, anon;

insert into auth.users(id, email, raw_user_meta_data) values
('00000000-0000-0000-0000-000000000001','coach-a@example.invalid','{"role":"coach","full_name":"Coach A"}'),
('00000000-0000-0000-0000-000000000002','client-a1@example.invalid','{"role":"client","full_name":"Client A1"}'),
('00000000-0000-0000-0000-000000000003','client-a2@example.invalid','{"role":"client","full_name":"Client A2"}'),
('00000000-0000-0000-0000-000000000004','coach-b@example.invalid','{"role":"coach","full_name":"Coach B"}'),
('00000000-0000-0000-0000-000000000005','client-b@example.invalid','{"role":"client","full_name":"Client B"}'),
('00000000-0000-0000-0000-000000000006','outsider@example.invalid','{"role":"client","full_name":"Outsider"}');
insert into public.programs(id, coach_id, name, invite_code) values
('00000000-0000-0000-0000-000000003001','00000000-0000-0000-0000-000000000001','A','CODEAA'),
('00000000-0000-0000-0000-000000003002','00000000-0000-0000-0000-000000000004','B','CODEBB');
insert into public.program_members(program_id,user_id) values
('00000000-0000-0000-0000-000000003001','00000000-0000-0000-0000-000000000002'),
('00000000-0000-0000-0000-000000003001','00000000-0000-0000-0000-000000000003'),
('00000000-0000-0000-0000-000000003002','00000000-0000-0000-0000-000000000005');
insert into public.workouts(id,coach_id,title,scheduled_at,status) values
('00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000000001','A',now(),'published'),
('00000000-0000-0000-0000-000000001002','00000000-0000-0000-0000-000000000004','B',now(),'published'),
('00000000-0000-0000-0000-000000001003','00000000-0000-0000-0000-000000000001','Draft',now(),'draft'),
('00000000-0000-0000-0000-000000001004','00000000-0000-0000-0000-000000000001','Shared',now(),'published'),
('00000000-0000-0000-0000-000000001005','00000000-0000-0000-0000-000000000001','History',now(),'published');
insert into public.workout_parts(id,workout_id,title) values
('00000000-0000-0000-0000-000000002001','00000000-0000-0000-0000-000000001001','A part'),
('00000000-0000-0000-0000-000000002002','00000000-0000-0000-0000-000000001002','B part'),
('00000000-0000-0000-0000-000000002003','00000000-0000-0000-0000-000000001003','Draft part'),
('00000000-0000-0000-0000-000000002004','00000000-0000-0000-0000-000000001004','Shared part'),
('00000000-0000-0000-0000-000000002005','00000000-0000-0000-0000-000000001005','History part');
insert into public.workout_assignments(workout_id,program_id) values
('00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000003001'),
('00000000-0000-0000-0000-000000001002','00000000-0000-0000-0000-000000003002'),
('00000000-0000-0000-0000-000000001003','00000000-0000-0000-0000-000000003001'),
('00000000-0000-0000-0000-000000001004','00000000-0000-0000-0000-000000003001'),
('00000000-0000-0000-0000-000000001004','00000000-0000-0000-0000-000000003002');
insert into public.part_results(id,part_id,workout_id,user_id,score_type) values
('00000000-0000-0000-0000-000000004001','00000000-0000-0000-0000-000000002004','00000000-0000-0000-0000-000000001004','00000000-0000-0000-0000-000000000003','text'),
('00000000-0000-0000-0000-000000004002','00000000-0000-0000-0000-000000002004','00000000-0000-0000-0000-000000001004','00000000-0000-0000-0000-000000000005','text'),
('00000000-0000-0000-0000-000000004003','00000000-0000-0000-0000-000000002005','00000000-0000-0000-0000-000000001005','00000000-0000-0000-0000-000000000002',null);

set role authenticated;
set request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000002","role":"authenticated"}';
select test.assert_true((select count(*) = 2 from public.program_members), 'client sees peers without results');
select test.assert_true((select count(*) = 3 from public.profiles), 'only self, coach and program peers');
select test.assert_true((select count(*) = 2 from public.workouts), 'published assigned workouts only');
select test.assert_true((select count(*) = 2 from public.workout_parts), 'only visible parts');
select test.assert_true((select count(*) = 1 from public.part_results where workout_id = '00000000-0000-0000-0000-000000001004'), 'shared workout does not leak other program results');
select test.assert_true((select count(*) = 1 from public.part_results where id = '00000000-0000-0000-0000-000000004003'), 'own historical result remains readable');
select test.assert_true(not private.is_program_member('00000000-0000-0000-0000-000000003002','00000000-0000-0000-0000-000000000005'), 'helper cannot probe arbitrary identity');
select test.assert_denied($q$update public.profiles set role = 'coach' where id = auth.uid()$q$, '42501');
select test.assert_denied($q$update public.profiles set email = 'changed@example.invalid' where id = auth.uid()$q$, '42501');
update public.profiles set full_name = 'Updated client' where id = auth.uid();
select test.assert_no_rows_changed($q$update public.profiles set full_name = 'forged' where id = '00000000-0000-0000-0000-000000000003'$q$);
select test.assert_denied($q$insert into public.program_members(program_id,user_id) values ('00000000-0000-0000-0000-000000003002',auth.uid())$q$, '42501');
select test.assert_denied($q$insert into public.programs(coach_id,name,invite_code) values (auth.uid(),'Forged','FORGED')$q$, '42501');
select test.assert_denied($q$insert into public.workouts(coach_id,title,scheduled_at) values (auth.uid(),'Forged',now())$q$, '42501');
select test.assert_denied($q$insert into public.part_results(workout_id,part_id,user_id) values ('00000000-0000-0000-0000-000000001003','00000000-0000-0000-0000-000000002003',auth.uid())$q$, '42501');
select test.assert_denied($q$insert into public.part_results(workout_id,part_id,user_id) values ('00000000-0000-0000-0000-000000001002','00000000-0000-0000-0000-000000002002',auth.uid())$q$, '42501');
select test.assert_denied($q$insert into public.part_results(workout_id,part_id,user_id) values ('00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000002004',auth.uid())$q$, '42501');
select test.assert_denied($q$insert into public.part_results(workout_id,part_id,user_id) values ('00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000002001','00000000-0000-0000-0000-000000000003')$q$, '42501');
select test.assert_no_rows_changed($q$update public.part_results set note = 'forged' where id = '00000000-0000-0000-0000-000000004001'$q$);
select test.assert_no_rows_changed($q$delete from public.part_results where id = '00000000-0000-0000-0000-000000004001'$q$);
select test.assert_denied($q$select * from public.workout_templates$q$, '42501');
select test.assert_denied($q$select * from public.workout_template_parts$q$, '42501');
select test.assert_denied($q$select public.join_program_by_code('BADCODE')$q$, 'P0001');

select public.sync_part_result('00000000-0000-0000-0000-000000005001','00000000-0000-0000-0000-000000004010',
  '00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000002001','2026-10-03 01:00Z',false,'done','reps','10');
select public.sync_part_result('00000000-0000-0000-0000-000000005001','00000000-0000-0000-0000-000000004010',
  '00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000002001','2026-10-03 01:00Z',false,'done','reps','10');
select test.assert_true((select count(*) = 1 from public.part_results where part_id='00000000-0000-0000-0000-000000002001'), 'RPC retry is idempotent');
select public.sync_part_result('00000000-0000-0000-0000-000000005002','00000000-0000-0000-0000-000000004010',
  '00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000002001','2026-10-03 02:00Z',false,'done','reps','20');
select public.sync_part_result('00000000-0000-0000-0000-000000005001','00000000-0000-0000-0000-000000004010',
  '00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000002001','2026-10-03 01:00Z',false,'done','reps','10');
select test.assert_true((select score_text = '20' from public.part_results where id='00000000-0000-0000-0000-000000004010'), 'stale RPC cannot overwrite newer result');
select public.sync_part_result('00000000-0000-0000-0000-000000005003','00000000-0000-0000-0000-000000004010',
  '00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000002001','2026-10-03 03:00Z',true,'done','reps','20');
select test.assert_true((select deleted_at is not null from public.part_results where id='00000000-0000-0000-0000-000000004010'), 'RPC soft delete works');
select test.assert_denied($q$select public.sync_part_result('00000000-0000-0000-0000-000000005004','00000000-0000-0000-0000-000000004010',
  '00000000-0000-0000-0000-000000001003','00000000-0000-0000-0000-000000002003',now(),false)$q$, '42501');

-- Коуч читает все результаты своей тренировки, но не вводит собственные.
set request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';
select test.assert_true((select count(*) = 2 from public.part_results where workout_id='00000000-0000-0000-0000-000000001004'), 'coach sees all assigned-program results');
select test.assert_true((select count(*) = 4 from public.workouts), 'coach sees own drafts too');
select test.assert_denied($q$select public.join_program_by_code('CODEAA')$q$, '42501');
select test.assert_denied($q$insert into public.part_results(workout_id,part_id,user_id) values ('00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000002001',auth.uid())$q$, '42501');
insert into public.workouts(id,coach_id,title,scheduled_at,status)
 values ('00000000-0000-0000-0000-000000001006',auth.uid(),'New published',now(),'published');
select test.assert_true((select published_at is not null from public.workouts where id='00000000-0000-0000-0000-000000001006'), 'trigger works without direct EXECUTE');
select test.assert_no_rows_changed($q$update public.workouts set title='forged' where id='00000000-0000-0000-0000-000000001002'$q$);
select test.assert_no_rows_changed($q$delete from public.program_members where program_id='00000000-0000-0000-0000-000000003002'$q$);
delete from public.program_members where program_id='00000000-0000-0000-0000-000000003001' and user_id='00000000-0000-0000-0000-000000000003';

-- Посторонний клиент до RPC не видит программу или чужие профили.
set request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000006","role":"authenticated"}';
select test.assert_true((select count(*)=0 from public.program_members), 'outsider cannot read membership');
select test.assert_true((select count(*)=1 from public.profiles), 'outsider sees only self');
select public.join_program_by_code(' codeaa ');
select public.join_program_by_code('CODEAA');
select test.assert_true((select count(*)=1 from public.program_members where user_id=auth.uid()), 'join trims code and is idempotent');
select test.assert_no_rows_changed($q$delete from public.program_members where user_id='00000000-0000-0000-0000-000000000002'$q$);
delete from public.program_members where user_id=auth.uid();
select test.assert_true((select count(*)=0 from public.workouts), 'leave revokes read access');
set request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000007","role":"authenticated"}';
select test.assert_denied($q$select public.join_program_by_code('CODEAA')$q$, '42501');

set role anon;
set request.jwt.claims = '{}';
select test.assert_denied($q$select * from public.program_members$q$, '42501');
select test.assert_denied($q$select * from public.profiles$q$, '42501');
select test.assert_denied($q$select public.join_program_by_code('CODEAA')$q$, '42501');
select test.assert_denied($q$select * from public.part_results$q$, '42501');

reset role;
select test.assert_denied($q$insert into public.part_results(workout_id,part_id,user_id) values ('00000000-0000-0000-0000-000000001002','00000000-0000-0000-0000-000000002001','00000000-0000-0000-0000-000000000006')$q$, '23503');
select test.assert_denied($q$update public.workout_parts set workout_id='00000000-0000-0000-0000-000000001002' where id='00000000-0000-0000-0000-000000002001'$q$, '23503');
select test.assert_denied($q$insert into public.part_results(workout_id,part_id,user_id,score_type) values ('00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000002001','00000000-0000-0000-0000-000000000006','invalid')$q$, '22P02');
select test.assert_true(not has_function_privilege('anon','public.set_workout_published_at()','EXECUTE'), 'anon cannot execute trigger');
select test.assert_true(not has_column_privilege('authenticated','public.profiles','role','UPDATE'), 'no column-level role mutation');
select test.assert_true(not has_table_privilege('authenticated','public.program_members','INSERT'), 'no direct membership insert');
select test.assert_true(to_regprocedure('private.is_group_member(uuid,uuid)') is null, 'legacy helper removed');
select test.assert_true(not exists(select 1 from pg_policies where schemaname='public' and roles @> array['public']::name[]), 'no PUBLIC RLS policy remains');
select test.assert_true((select count(*)=1 from pg_constraint where conrelid='public.part_results'::regclass and confrelid='public.workout_parts'::regclass and contype='f'), 'unambiguous PostgREST part relationship');
select 'security_hardening_test: PASS' as result;
