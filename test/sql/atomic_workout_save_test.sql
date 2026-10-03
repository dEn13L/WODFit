-- Только одноразовая БД/CI после fixture, миграций 12/13/14 и security_hardening_test.sql.
-- Все данные этой проверки откатываются. test.assert_* созданы security_hardening_test.sql.
begin;
select test.assert_true(not has_function_privilege('anon',
  'public.save_workout(uuid,text,text,timestamptz,public.workout_status,jsonb,uuid[])','EXECUTE'), 'anonymous RPC denied');
select test.assert_true(not has_function_privilege('authenticated',
  'private.prevent_part_with_results_delete()','EXECUTE'), 'trigger cannot be directly invoked');
select test.assert_true((select not prosecdef from pg_proc where oid=
  'public.save_workout(uuid,text,text,timestamptz,public.workout_status,jsonb,uuid[])'::regprocedure), 'RPC uses invoker RLS');
select test.assert_true((select confdeltype='a' and condeferrable and condeferred and convalidated
  from pg_constraint where conrelid='public.part_results'::regclass and conname='part_results_part_workout_fkey'),
  'deferred no action FK protects concurrent insert/delete');
insert into auth.users(id,email,raw_user_meta_data) values
  ('10000000-0000-0000-0000-000000000001','atomic-coach@example.invalid','{"role":"coach","full_name":"Тренер"}'),
  ('10000000-0000-0000-0000-000000000002','atomic-client@example.invalid','{"role":"client","full_name":"Атлет"}'),
  ('10000000-0000-0000-0000-000000000003','other-coach@example.invalid','{"role":"coach","full_name":"Другой тренер"}');
insert into public.programs(id,coach_id,name,invite_code) values
  ('10000000-0000-0000-0000-000000003001','10000000-0000-0000-0000-000000000001','Программа','ATOMIC01'),
  ('10000000-0000-0000-0000-000000003002','10000000-0000-0000-0000-000000000003','Чужая программа','ATOMIC02');
insert into public.program_members(program_id,user_id) values
  ('10000000-0000-0000-0000-000000003001','10000000-0000-0000-0000-000000000002');

set local role authenticated;
set local request.jwt.claims = '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}';
-- RPC вернул готовую проекцию, публикация произошла вместе с заданиями/назначениями.
select set_config('test.atomic_workout_id', (public.save_workout(null,'Сессия','','2026-10-03 12:00Z','published',
  '[{"id":"10000000-0000-0000-0000-000000002001","title":"Силовая","description":"Вес"},
    {"id":"10000000-0000-0000-0000-000000002002","title":"Разминка","description":""}]',
  array['10000000-0000-0000-0000-000000003001']::uuid[])->>'id'), true);
select test.assert_true((select count(*)=2 from public.workout_parts
  where workout_id=current_setting('test.atomic_workout_id')::uuid), 'atomic create tasks');
select test.assert_true((select published_at is not null from public.workouts
  where id=current_setting('test.atomic_workout_id')::uuid), 'atomic publication timestamp');
reset role;
update public.workout_assignments set assigned_at='2026-09-01 12:00Z'
  where workout_id=current_setting('test.atomic_workout_id')::uuid;
set local role authenticated;
select set_config('test.assigned_at', (select assigned_at::text from public.workout_assignments
  where workout_id=current_setting('test.atomic_workout_id')::uuid), true);

-- Участник сохраняет результат через тот же RPC синхронизации, что использует клиент.
set local request.jwt.claims = '{"sub":"10000000-0000-0000-0000-000000000002","role":"authenticated"}';
select public.sync_part_result('10000000-0000-0000-0000-000000005001','10000000-0000-0000-0000-000000004001',
  current_setting('test.atomic_workout_id')::uuid,'10000000-0000-0000-0000-000000002001',
  '2026-10-03 13:00Z',false,'done','text','100');
select test.assert_denied($q$select public.save_workout(null,'','','2026-10-03 12:00Z','draft','[]','{}')$q$, '42501');

set local request.jwt.claims = '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}';
select test.assert_true(jsonb_array_length(public.save_workout(current_setting('test.atomic_workout_id')::uuid,
  'Изменено','','2026-10-04 12:00Z','published',
  '[{"id":"10000000-0000-0000-0000-000000002002","title":"Разминка","description":""},
    {"id":"10000000-0000-0000-0000-000000002001","title":"Силовая новая","description":"Вес новый"}]',
  array['10000000-0000-0000-0000-000000003001']::uuid[])->'workout_parts')=2, 'atomic update response');
select test.assert_true((select sort_order=1 and title='Силовая новая' from public.workout_parts
  where id='10000000-0000-0000-0000-000000002001'), 'reorder keeps task ID');
select test.assert_true((select score_text='100' from public.part_results
  where part_id='10000000-0000-0000-0000-000000002001'), 'edit keeps result');
select test.assert_true((select assigned_at::text=current_setting('test.assigned_at') from public.workout_assignments
  where workout_id=current_setting('test.atomic_workout_id')::uuid), 'unchanged assignment timestamp');

-- Ошибка удаления должна откатить заголовок, новые задания и назначения одновременно.
select test.assert_denied($q$select public.save_workout(current_setting('test.atomic_workout_id')::uuid,
  'Откат','','2026-10-05 12:00Z','draft',
  '[{"id":"10000000-0000-0000-0000-000000002003","title":"Новое","description":""}]','{}')$q$, 'W0001');
select test.assert_true((select title='Изменено' and status='published' and scheduled_at='2026-10-04 12:00Z'
  from public.workouts where id=current_setting('test.atomic_workout_id')::uuid), 'header rolled back');
select test.assert_true(not exists(select 1 from public.workout_parts
  where id='10000000-0000-0000-0000-000000002003'), 'new task rolled back');
select test.assert_true((select count(*)=1 from public.workout_assignments
  where workout_id=current_setting('test.atomic_workout_id')::uuid), 'assignments retained');
select test.assert_denied($q$delete from public.workout_parts
  where id='10000000-0000-0000-0000-000000002001'$q$, 'W0001');

-- Мягко удалённые результаты также защищают задание.
set local request.jwt.claims = '{"sub":"10000000-0000-0000-0000-000000000002","role":"authenticated"}';
select public.sync_part_result('10000000-0000-0000-0000-000000005002','10000000-0000-0000-0000-000000004001',
  current_setting('test.atomic_workout_id')::uuid,'10000000-0000-0000-0000-000000002001',
  '2026-10-03 14:00Z',true,'done','text','100');
set local request.jwt.claims = '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}';
select test.assert_denied($q$delete from public.workout_parts
  where id='10000000-0000-0000-0000-000000002001'$q$, 'W0001');
delete from public.workout_parts where id='10000000-0000-0000-0000-000000002002';
select test.assert_true(not exists(select 1 from public.workout_parts
  where id='10000000-0000-0000-0000-000000002002'), 'empty task can be deleted');

-- Чужие программы, несуществующие тренировки и пустая публикация отклоняются.
select test.assert_denied($q$select public.save_workout(null,'','','2026-10-03 12:00Z','draft','[]',
  array['10000000-0000-0000-0000-000000003002']::uuid[])$q$, '42501');
select test.assert_denied($q$select public.save_workout('10000000-0000-0000-0000-000000009999',
  '','','2026-10-03 12:00Z','draft','[]','{}')$q$, '42501');
select test.assert_denied($q$select public.save_workout(null,'','','2026-10-03 12:00Z','published','[]','{}')$q$, '22023');
select test.assert_denied($q$select public.save_workout(null,'','','2026-10-03 12:00Z','draft',
  '[{"id":"10000000-0000-0000-0000-000000002001","title":"Подмена","description":""}]','{}')$q$, '23505');
select test.assert_true((select count(*)=1 from public.workouts), 'failed creates leave no partial workout');

set local request.jwt.claims = '{"sub":"10000000-0000-0000-0000-000000000003","role":"authenticated"}';
select test.assert_denied($q$select public.save_workout(current_setting('test.atomic_workout_id')::uuid,
  'Подмена','','2026-10-03 12:00Z','draft','[]','{}')$q$, '42501');
set local role anon;
set local request.jwt.claims = '{}';
select test.assert_denied($q$select public.save_workout(null,'','','2026-10-03 12:00Z','draft','[]','{}')$q$, '42501');

-- Удаление всей тренировки сохраняет прежнюю каскадную семантику даже с tombstone.
set local role authenticated;
set local request.jwt.claims = '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}';
delete from public.workouts where id=current_setting('test.atomic_workout_id')::uuid;
reset role;
set constraints all immediate;
select test.assert_true(not exists(select 1 from public.part_results
  where workout_id=current_setting('test.atomic_workout_id')::uuid), 'whole workout delete cascades results');
select test.assert_true(not exists(select 1 from public.workout_parts
  where workout_id=current_setting('test.atomic_workout_id')::uuid), 'whole workout delete cascades tasks');
select 'atomic_workout_save_test: PASS' as result;
rollback;
