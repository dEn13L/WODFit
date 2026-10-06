# Архитектура и инженерный контракт

Текущие нормы: Clean Architecture, Flutter/Bloc/go_router, Supabase; Hive — кэш и очередь, не серверный источник истины. presentation не обращается к Supabase напрямую. Детальный инженерный контракт сохранён ниже; сверяйте пути и зависимости точечно с кодом задачи. Числа строк и старые ограничения SDK из истории не описывают текущую среду.

Сохранённые блоки ниже — первоисточник, а не самостоятельные текущие инструкции. Нормативный приоритет — корневой AGENTS и явная задача.

## Исходник: строки 10–29

```text
<!-- BEGIN source-010-029 -->
## 1. Паспорт проекта
- Продукт: WOD Fit — приложение кроссфит-тренировок для тренера и атлетов.
- Клиент: Flutter (Dart), таргеты Android / iOS / Web (адаптив).
- Состояние: flutter_bloc. Навигация: go_router.
- Бэкенд: Supabase (PostgreSQL, Auth, RLS, RPC; Storage не используется).
- Локально: Hive — кэш: settings_box (тема), workouts_box (черновик формы),
  result_sync_box (локальная проекция результатов и очередь синхронизации).
  Источник истины после подтверждения синхронизации — Supabase.
- Логирование: AppLogger (core).
- Архитектура: Clean Architecture:
  lib/core (router, theme, config, errors, utils, logger),
  lib/domain (entities, repositories-интерфейсы),
  lib/data (models, datasources, repositories-реализации),
  lib/presentation (screens, widgets, bloc/cubit).
- Зависимости: flutter_bloc, go_router, supabase_flutter, hive/hive_flutter,
  intl, uuid, equatable. Новые зависимости — только с явным обоснованием в ответе.
- freezed/json_serializable НЕ использовать: модели — обычные Dart-классы
  с fromJson / toJson / toDb.
- Переменные окружения: SUPABASE_URL, SUPABASE_ANON_KEY через --dart-define.
  service_role key в клиенте запрещён навсегда.
<!-- END source-010-029 -->
```

## Исходник: строки 179–199

```text
<!-- BEGIN source-179-199 -->
## 5. Правила кода
- presentation НЕ импортирует supabase_flutter: все запросы через репозитории
  data-слоя за интерфейсами из domain.
- Экран = свой Cubit/Bloc; состояние — sealed/enum-статусы (initial/loading/loaded/error).
- Ошибки Supabase ловить явно: AuthException, PostgrestException (логировать message,
  details, hint, code через AppLogger), показывать пользователю понятным текстом.
  Молчаливых catch не должно быть вообще.
- Списки с данными из нескольких таблиц брать одним запросом и джойнить в памяти;
  N+1-запросы запрещены.
- Deprecated API не использовать: вместо withOpacity — withValues(alpha:).
- Идентификаторы кода — английские; UI-строки — русские; комментарии — русские допустимы.
- Не рефакторить код вне задачи. Не переписывать целые файлы без необходимости:
  точечные правки. Крупные виджеты выносить в отдельные файлы.
- Любое изменение схемы БД = файл миграции sql/NN_slug.sql (следующий номер)
  ПЛЮС тот же SQL в ответе. Переименования — через ALTER ... RENAME
  (сохранение данных), не пересозданием таблиц.
- После переименований сущностей обновлять ВСЕ места: модели, репозитории, cubit,
  экраны, роуты, тексты, empty-состояния.
- Маршруты по существующим паттернам app_router.dart: /coach/..., /client/...;
  ролевая изоляция маршрутов обязательна.

<!-- END source-179-199 -->
```
