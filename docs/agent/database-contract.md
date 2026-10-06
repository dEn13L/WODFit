# Контракт БД и RLS

Инварианты доступа из исходника сохраняются: собственные данные тренера, результаты только своего client, связность part/workout, неизменяемость роли/email/id, отсутствие anonymous доступа и прямого INSERT membership. Enum ↔ Dart — единый core-маппер + миграция. Таблица/enum/RPC в сохранённом описании НЕ являются свежим live-аудитом: см. [статус](live-db-status.md). Старое описание title как уточнения и подпись group «Группа» не отменяют текущего UI-контракта. practice не подтверждён. Список разрешённых EXECUTE из старого блока не считать исчерпывающим после миграции 14. Новые индексы — после EXPLAIN.

Сохранённые блоки ниже — первоисточник, а не самостоятельные текущие инструкции. Нормативный приоритет — корневой AGENTS и явная задача.

## Исходник: строки 61–123

```text
<!-- BEGIN source-061-123 -->
## 3. Схема данных (актуальная)
profiles(id pk→auth.users, email, full_name, role user_role, created_at)
programs(id, coach_id→profiles, name, kind program_kind, description not null default '',
invite_code unique, created_at, updated_at)
program_members(program_id, user_id, joined_at; PK(program_id, user_id))
workouts(id, coach_id, title not null — уточнение сессии, description not null —
не используется, scheduled_at timestamptz, status workout_status, published_at timestamptz,
created_at, updated_at)
workout_parts(id, workout_id, type nullable legacy, title, description, sort_order,
score_type nullable legacy)
workout_assignments(workout_id, program_id, assigned_at; PK(workout_id, program_id))
workout_views(workout_id, user_id, viewed_at; PK(workout_id, user_id))
part_results(id, workout_id, part_id, user_id, status result_status,
score_type nullable enum score_type — формат записи (fallback 'text'),
score_text, time_ms, rounds, reps, weight_kg, distance_m, calories,
note, client_updated_at, last_operation_id, deleted_at, created_at, updated_at;
UNIQUE(part_id, user_id))
legacy: workout_templates, workout_template_parts — таблицы сохранены, фича удалена,
код их не использует; новых зависимостей от них не создавать.

Enum'ы и подписи UI (строковые значения БД↔Dart живут в ЕДИНОМ маппере в core;
при добавлении значения обновляй маппер И миграцию одновременно):
- user_role: coach, client.
- program_kind: personal → «Персональная», group → «Группа».
- workout_status: draft → «Черновик», published → бейдж НЕ показывается.
- workout_part_type: legacy, в UI не выбирается и не заполняется;
  значения по sql/01: warmup, weightlifting, strength, crossfitComplex, cooldown,
  stretch, mobility; practice по истории добавлялся, но в миграциях его нет —
  наличие в живой БД не проверено.
- score_type: выбирается атлетом в форме ввода результата, хранится в
  part_results.score_type: none «Без фиксации (статус)», text «Текст (произвольно)»,
  time «Время», rounds_reps «Раунды + повторы», weight «Вес», reps «Повторы»,
  distance «Дистанция», calories «Калории».
- result_status: done «Выполнено», scaled «Масштабировано», notDone «Не выполнено».

RPC: join_program_by_code(code text) — security definer, вступление по коду;
sync_part_result(...) — security invoker, идемпотентная LWW-синхронизация результатов.
Helper-функции RLS находятся в неэкспонируемой схеме private. Публичный
EXECUTE доступен authenticated только для join_program_by_code и sync_part_result;
прямой EXECUTE у set_workout_published_at() закрыт, trigger включён.
Миграция 14 добавляет save_workout; до её применения RPC отсутствует в live.
RLS-принципы (не нарушать):
- тренер CRUD только свои programs/workouts и их детей;
- участник программы читает свою программу, назначенные published-тренировки,
  их задания и результаты участников своей программы;
- part_results: insert/update/delete только свои (user_id = auth.uid());
  только client в назначенной published-тренировке с соответствующим заданием;
  соответствие part_id/workout_id дополнительно гарантирует составной FK.
  Собственные исторические результаты остаются читаемыми; результаты других —
  только общей назначенной программе или тренеру своей тренировки.
- profiles читаются только связанными пользователями; UPDATE клиенту
  разрешён только для full_name своего профиля, роль/email/id неизменяемы.
- тренер читает результаты своих тренировок;
- анонимный доступ запрещён ко всем таблицам;
- вступление в программу — только через RPC.
  У authenticated нет INSERT на program_members; участник читает состав общих
  программ, удаляет только собственное членство, тренер исключает участников
  только из собственных программ.
  Индексы существуют: programs(coach_id), program_members(program_id/user_id),
  workout_assignments(program_id/workout_id), part_results(workout_id/user_id),
  workouts(coach_id). Составные workouts(coach_id, scheduled_at) и
  part_results(workout_id, user_id) в live отсутствуют; добавлять только после EXPLAIN.

<!-- END source-061-123 -->
```
