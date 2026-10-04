-- Одноразовая БД после security_hardening_test.sql и миграции 15.
begin;
select test.assert_true(not exists (
 select 1 from public.workout_assignments a
 join (
  select a.workout_id, a.program_id,
   row_number() over (partition by a.program_id order by w.scheduled_at,w.created_at,w.id) as expected
  from public.workout_assignments a join public.workouts w on w.id=a.workout_id
 ) n using(workout_id,program_id)
 where a.workout_number<>n.expected
), 'historical backfill has deterministic numbers');
select test.assert_true(not has_table_privilege('authenticated',
  'private.program_workout_counters','SELECT'), 'counter is private');
select test.assert_true(not has_function_privilege('authenticated',
  'private.assign_program_workout_number()','EXECUTE'), 'number trigger is not an RPC');
insert into auth.users(id,email,raw_user_meta_data) values
 ('20000000-0000-0000-0000-000000000001','number-coach@example.invalid','{"role":"coach"}'),
 ('20000000-0000-0000-0000-000000000002','number-client@example.invalid','{"role":"client"}'),
 ('20000000-0000-0000-0000-000000000003','number-other@example.invalid','{"role":"coach"}');
insert into public.programs(id,coach_id,name,invite_code) values
 ('20000000-0000-0000-0000-000000003001','20000000-0000-0000-0000-000000000001','A','NUMBER01'),
 ('20000000-0000-0000-0000-000000003002','20000000-0000-0000-0000-000000000001','B','NUMBER02'),
 ('20000000-0000-0000-0000-000000003003','20000000-0000-0000-0000-000000000003','Other','NUMBER03');
set local role authenticated;
set local request.jwt.claims = '{"sub":"20000000-0000-0000-0000-000000000001","role":"authenticated"}';
select set_config('test.number_first', (public.save_workout(null,'','','2026-10-03 12:00Z','draft','[]',
 array['20000000-0000-0000-0000-000000003001']::uuid[])->>'id'),true);
select test.assert_true((select workout_number=1 from public.workout_assignments
 where workout_id=current_setting('test.number_first')::uuid), 'first number is one');
select public.save_workout(current_setting('test.number_first')::uuid,'','','2026-11-03 12:00Z','draft','[]',
 array['20000000-0000-0000-0000-000000003001']::uuid[]);
select test.assert_true((select workout_number=1 from public.workout_assignments
 where workout_id=current_setting('test.number_first')::uuid), 'edit retains number');
select set_config('test.number_second', (public.save_workout(null,'','','2026-10-01 12:00Z','draft','[]',
 array['20000000-0000-0000-0000-000000003002','20000000-0000-0000-0000-000000003001']::uuid[])->>'id'),true);
select test.assert_true((select workout_number=2 from public.workout_assignments
 where workout_id=current_setting('test.number_second')::uuid and program_id='20000000-0000-0000-0000-000000003001'), 'no counter consumed by unchanged save');
select test.assert_true((select workout_number=1 from public.workout_assignments
 where workout_id=current_setting('test.number_second')::uuid and program_id='20000000-0000-0000-0000-000000003002'), 'independent numbering in B');
delete from public.workouts where id=current_setting('test.number_second')::uuid;
select set_config('test.number_third', (public.save_workout(null,'','','2026-09-01 12:00Z','draft','[]',
 array['20000000-0000-0000-0000-000000003001','20000000-0000-0000-0000-000000003002']::uuid[])->>'id'),true);
select test.assert_true((select workout_number=3 from public.workout_assignments
 where workout_id=current_setting('test.number_third')::uuid and program_id='20000000-0000-0000-0000-000000003001'), 'deleted number not reused in A');
select test.assert_true((select workout_number=2 from public.workout_assignments
 where workout_id=current_setting('test.number_third')::uuid and program_id='20000000-0000-0000-0000-000000003002'), 'deleted last number not reused in B');
select test.assert_denied($q$select public.save_workout(null,'','','2026-10-01 12:00Z','draft','[]',
 array['20000000-0000-0000-0000-000000003003']::uuid[])$q$, '42501');
reset role;
select test.assert_denied($q$update public.workout_assignments set workout_number=99
 where workout_id=current_setting('test.number_first')::uuid$q$, '22023');
set local role authenticated;
set local request.jwt.claims = '{"sub":"20000000-0000-0000-0000-000000000002","role":"authenticated"}';
select test.assert_denied($q$insert into public.workout_assignments(workout_id,program_id,workout_number)
 values(current_setting('test.number_first')::uuid,'20000000-0000-0000-0000-000000003002',99)$q$, '42501');
reset role;
rollback;
