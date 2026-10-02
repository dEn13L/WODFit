# Аудит схемы и безопасности Supabase

Дата аудита: 1 октября 2026 года.

> Результаты ниже фиксируют состояние до применения шага 3.1. Миграция
> `10_harden_grants_and_functions.sql` применена 2 октября 2026 года; её итоговое
> состояние должно быть подтверждено повторным read-only аудитом.

## Метод и границы

Живая база проверена результатами read-only запросов из
[`database-security-audit.sql`](database-security-audit.sql): enum, колонки,
функции, RLS, политики, grants, индексы и ограничения. Скрипт читает только
системные каталоги внутри `READ ONLY`-транзакции. Пользовательские данные не
выгружались, изменения в живую базу не вносились.

## Итоговая классификация

| Область | Живая база | Миграции / Dart | Результат |
|---|---|---|---|
| `user_role` | `coach`, `client` | совпадает | совпадает |
| `program_kind` | `personal`, `group` | совпадает | совпадает |
| `workout_status` | `draft`, `published` | совпадает | совпадает |
| `result_status` | `done`, `scaled`, `notDone` | совпадает | совпадает |
| `workout_part_type` | семь значений; `practice` отсутствует | миграции и Dart содержат те же семь | совпадает; `practice` не требуется без продуктового решения |
| `score_type` | enum отсутствует; `part_results.score_type` — nullable `text` без default | Dart поддерживает 8 строк; `07` ошибочно ссылается на `public.score_type` | отсутствует в живой базе и миграциях; требует миграции |
| `workout_parts.type` | nullable `workout_part_type`, без default | соответствует модели | совпадает |
| `workout_parts.score_type` | nullable `text`, default `'text'` | UI поле не заполняет | default расходится с правилом; требует миграции |
| RPC | `join_program_by_code(code text) RETURNS json` | клиент и миграции используют `code`; проектный контракт — `p_invite_code` | требует согласования миграцией и клиентом |
| RLS | включён на всех 9 public-таблицах, `FORCE` выключен | политики в основном повторяют миграции | включён; политики требуют hardening |
| Анонимный доступ | `anon` имеет все табличные grants и `EXECUTE` всех public-функций; RLS блокирует строки основных таблиц | явных revoke нет | избыточные права; требует миграции |
| Индексы | базовые индексы есть; три пары дублей; двух заявленных составных индексов нет | миграции создают часть дублей после rename | требует отдельной миграции после `EXPLAIN` |
| Уникальность результата | `UNIQUE (part_id, user_id)` | совпадает | совпадает |
| Каскадное удаление | все 13 FK имеют `ON DELETE CASCADE` | совпадает | совпадает |
| Dart-модели | см. отдельный раздел | есть несовпадения nullable/колонок | требует точечных изменений вместе с миграцией |

## Подтверждённая живая схема

### Enum

- `user_role`: `coach`, `client`.
- `program_kind`: `personal`, `group`.
- `result_status`: `done`, `scaled`, `notDone`.
- `workout_status`: `draft`, `published`.
- `workout_part_type`: `warmup`, `weightlifting`, `strength`,
  `crossfitComplex`, `cooldown`, `stretch`, `mobility`.
- `score_type` отсутствует. Формат результата хранится в nullable text-колонке
  `part_results.score_type` без default.

### Nullable, default и отсутствующие колонки

- `workout_parts.type` — nullable, без default: соответствует продуктовой модели.
- `workout_parts.score_type` — nullable, но default `'text'` сохранился. При
  отсутствии поля база продолжает заполнять legacy-колонку.
- `part_results.score_type` — nullable `text`, без default. Dart fallback на
  `text` сохраняет чтение старых строк, но тип базы не соответствует заявленному
  enum `score_type`.
- `workouts.title` и `workouts.description` — `NOT NULL`; актуальное описание
  схемы объявляет их nullable.
- `programs.description` — `NOT NULL DEFAULT ''`; актуальное описание объявляет
  nullable.
- `profiles.updated_at` и `workout_parts.created_at`, указанные в актуальном
  описании схемы, в живой базе отсутствуют.

### Ограничения

- Подтверждены `UNIQUE (part_id, user_id)` и уникальность
  `programs.invite_code`.
- Все 13 внешних ключей используют `ON DELETE CASCADE`, включая legacy-таблицы
  шаблонов.
- Составные PK подтверждены для `program_members(program_id, user_id)` и
  `workout_assignments(workout_id, program_id)`.
- Legacy-префикс `group_` в именах части ограничений косметический: определения
  ссылаются на актуальные таблицы и колонки, переименование не требуется.
- Нет ограничения, гарантирующего, что `part_results.part_id` принадлежит
  тренировке из `part_results.workout_id`.

## RPC и функции

- Фактическая сигнатура — `join_program_by_code(code text) RETURNS json`, а не
  задокументированная `p_invite_code text`. Текущий Dart-клиент совместим с live.
- Все восемь public-функций доступны `anon` и `authenticated`; пять проверенных
  функций имеют `SECURITY DEFINER` и пустой `runtime_settings`, то есть безопасный
  `search_path` не закреплён.
- `anon` может вызывать helper-функции с произвольным UUID пользователя.
  `is_program_member`, `is_program_coach` и `can_user_view_workout` становятся
  каналом проверки связей, обходящим RLS.
- В live остались `is_group_member` и `is_group_coach`. Это legacy-функции,
  отсутствующие в актуальной модели; их зависимости и вызовы нужно проверить
  перед удалением отдельной миграцией.
- `join_program_by_code` доступна `anon`, хотя вставка с `auth.uid() = NULL`
  должна завершаться ошибкой ограничения. Полагаться на ошибку вместо явного
  revoke нельзя.

## RLS и анонимный доступ

RLS включён на всех основных и legacy-таблицах. `FORCE ROW LEVEL SECURITY` нигде
не включён, что штатно для Supabase owner/service operations.

Подтверждённые проблемы:

1. `program_members` разрешает аутентифицированному пользователю прямой `INSERT`
   своей строки. Это обходит invite-код и правило «вступление только через RPC».
2. `part_results` при INSERT/UPDATE проверяет только `user_id = auth.uid()` и не
   проверяет участие, публикацию тренировки и соответствие `part_id`/`workout_id`.
3. Участник не может прочитать строки других участников в `program_members`, хотя
   матрица результатов должна включать всех участников программы.
4. Любой аутентифицированный пользователь может читать все строки `profiles`.
5. Восемь политик legacy-таблиц шаблонов адресованы роли `public`, а не
   `authenticated`. Условия с `auth.uid()` обычно блокируют анонимные строки, но
   это не соответствует принципу явного запрета и оставляет лишнюю поверхность.
6. `anon` имеет `SELECT/INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER` на всех
   девяти public-таблицах. RLS блокирует строковые операции без подходящей
   политики, однако grants шире минимально необходимых и должны быть отозваны.
7. `anon` имеет `EXECUTE` всех public-функций; SECURITY DEFINER helpers позволяют
   получать сведения, которые RLS должен скрывать.

Итог: прямой анонимный доступ к строкам основных таблиц политиками не разрешён,
но требование «анонимный доступ запрещён» не выполнено на уровне grants/functions.

## Индексы

Подтверждены индексы по основным одиночным фильтрам и PK. Выявлены:

- отсутствует `workouts(coach_id, scheduled_at)`;
- отсутствует `part_results(workout_id, user_id)`;
- `idx_groups_coach` и `idx_programs_coach` дублируют `programs(coach_id)`;
- `idx_group_members_user` и `idx_program_members_user` дублируют
  `program_members(user_id)`;
- `idx_workout_assignments_group` и `idx_workout_assignments_program` дублируют
  `workout_assignments(program_id)`;
- отдельный `idx_program_members_program` избыточен для запросов по одному
  `program_id`, поскольку составной PK начинается с `program_id`;
- отдельный `idx_part_results_part` избыточен для запросов по одному `part_id`,
  поскольку unique index начинается с `part_id`;
- отдельный индекс `workout_assignments(workout_id)` не нужен: составной PK
  начинается с `workout_id`.

Удалять дубли и добавлять составные индексы следует отдельной миграцией только
после `EXPLAIN (ANALYZE, BUFFERS)` основных запросов.

## Соответствие Dart-моделям

- `WorkoutPartModel` корректно допускает `null` для `type` и legacy
  `score_type`.
- `PartResultModel` корректно принимает nullable text `score_type` и применяет
  fallback `text`; после перехода БД на enum строковая сериализация останется
  совместимой.
- `CrossfitWorkoutModel` требует ненулевой `title`, что совпадает с live, но не с
  актуальным описанием схемы.
- `TrainingProgramModel` превращает nullable `description` в пустую строку; live
  гарантирует `NOT NULL DEFAULT ''`.
- Модели не ожидают отсутствующие `profiles.updated_at` и
  `workout_parts.created_at`, поэтому текущий клиент не падает, но описание схемы
  расходится с live.
- RPC-клиент передаёт `code`, что совпадает с live, но расходится с утверждённым
  контрактом `p_invite_code`.

## Требуемые отдельные миграции

Для первого шага подготовлены read-only preflight
[`10_grants_functions_preflight.sql`](10_grants_functions_preflight.sql) и миграция
[`10_harden_grants_and_functions.sql`](../sql/10_harden_grants_and_functions.sql).
Миграция применена к живой базе 2 октября 2026 года: отозваны анонимные табличные
права, права `authenticated` заменены явным allow-list, helper-функции перенесены
в неэкспонируемую схему `private`, закреплён `search_path`, а публичными оставлены
только необходимые RPC. Legacy `is_group_*` не удалены. Повторный read-only аудит
и coach/client smoke-тест после применения ещё не зафиксированы.

1. **Security hardening:** закрыть прямой INSERT в `program_members`, ограничить
   result writes, исправить чтение состава программы и профилей, заменить
   template-политики `public` на `authenticated`.
2. **Function hardening:** закрепить безопасный `search_path`, отозвать EXECUTE у
   `PUBLIC`/`anon`, выдать точечные grants, согласовать параметр RPC и удалить
   legacy group helpers после проверки зависимостей.
3. **Schema alignment:** создать `score_type`, проверить фактические значения,
   преобразовать `part_results.score_type`, убрать default legacy
   `workout_parts.score_type`, решить nullable и недостающие timestamps.
4. **Data integrity:** гарантировать соответствие `part_id` и `workout_id` без
   потери существующих результатов.
5. **Indexes:** удалить доказанные дубли и добавить только индексы, подтверждённые
   планами запросов.

Каждая миграция требует отдельного подтверждения и предварительных запросов на
валидность существующих данных. До подтверждения живую базу не изменять.
