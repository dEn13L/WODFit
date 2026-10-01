-- Read-only inventory for the WOD Fit Supabase schema.
-- Run as a role that can read PostgreSQL catalogs. This script does not mutate data or DDL.

BEGIN TRANSACTION READ ONLY;

-- 1. Enum values in their declared order.
SELECT
  n.nspname AS schema_name,
  t.typname AS enum_name,
  e.enumsortorder,
  e.enumlabel
FROM pg_type AS t
JOIN pg_namespace AS n ON n.oid = t.typnamespace
JOIN pg_enum AS e ON e.enumtypid = t.oid
WHERE n.nspname = 'public'
ORDER BY t.typname, e.enumsortorder;

-- 2. Columns, nullability, defaults and underlying PostgreSQL types.
SELECT
  c.table_schema,
  c.table_name,
  c.ordinal_position,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default
FROM information_schema.columns AS c
WHERE c.table_schema = 'public'
  AND c.table_name IN (
    'profiles',
    'programs',
    'program_members',
    'workouts',
    'workout_parts',
    'workout_assignments',
    'part_results'
  )
ORDER BY c.table_name, c.ordinal_position;

-- 3. RPC signatures, owner, security mode, privileges and complete definitions.
SELECT
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS identity_arguments,
  pg_get_function_result(p.oid) AS result_type,
  pg_get_userbyid(p.proowner) AS owner_name,
  p.prosecdef AS security_definer,
  p.proconfig AS runtime_settings,
  has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_execute,
  pg_get_functiondef(p.oid) AS definition
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'join_program_by_code',
    'is_program_member',
    'is_program_coach',
    'can_user_view_workout',
    'handle_new_user'
  )
ORDER BY p.proname, identity_arguments;

-- 4. RLS state and every policy, including the roles to which it applies.
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS rls_forced
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'p')
ORDER BY c.relname;

SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- 5. Grants that can expose public tables, sequences or functions to anon/PUBLIC.
SELECT
  grantee,
  table_schema,
  table_name,
  privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN ('anon', 'PUBLIC')
ORDER BY table_name, grantee, privilege_type;

SELECT
  grantee,
  object_schema,
  object_name,
  privilege_type
FROM information_schema.role_usage_grants
WHERE object_schema = 'public'
  AND grantee IN ('anon', 'PUBLIC')
ORDER BY object_name, grantee, privilege_type;

SELECT
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS identity_arguments,
  has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_execute
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
ORDER BY p.proname, identity_arguments;

-- 6. Indexes and constraints (unique constraints and foreign-key delete actions included).
SELECT
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

SELECT
  conrelid::regclass AS table_name,
  conname AS constraint_name,
  contype AS constraint_type,
  confdeltype AS foreign_key_delete_action,
  pg_get_constraintdef(oid, true) AS definition
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
ORDER BY conrelid::regclass::text, conname;

COMMIT;
