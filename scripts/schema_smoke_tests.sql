--
-- Schema smoke tests for PersonalBase
-- Run via: psql -d personalbase_ci -f scripts/schema_smoke_tests.sql
--
-- Output format: [PASS] message or [FAIL] message
-- Exit code: non-zero if any smoke check fails
--

\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

CREATE TEMP TABLE smoke_results (
    test_name text NOT NULL,
    passed boolean NOT NULL,
    details text NOT NULL
);

DO $$
BEGIN
    RAISE NOTICE 'Starting schema smoke tests...';
END $$;

-- Expected application schemas.
WITH expected(schema_name) AS (
    VALUES
        ('course'),
        ('finance'),
        ('habits'),
        ('todo'),
        ('trips'),
        ('user')
),
missing AS (
    SELECT schema_name FROM expected
    EXCEPT
    SELECT nspname FROM pg_namespace
)
INSERT INTO smoke_results
SELECT
    'expected schemas',
    NOT EXISTS (SELECT 1 FROM missing),
    COALESCE('Missing: ' || string_agg(schema_name, ', ' ORDER BY schema_name), 'All expected schemas exist')
FROM missing;

-- Exact tables that make up the public schema contract.
WITH expected(table_schema, table_name) AS (
    VALUES
        ('course', 'course_statuses'),
        ('course', 'course_topics'),
        ('course', 'courses'),
        ('finance', 'finance_categories'),
        ('finance', 'finance_types'),
        ('finance', 'finances'),
        ('habits', 'habit_categories'),
        ('habits', 'habit_frequencies'),
        ('habits', 'habit_logs'),
        ('habits', 'habits'),
        ('todo', 'task_priorities'),
        ('todo', 'task_statuses'),
        ('todo', 'todo_categories'),
        ('todo', 'todos'),
        ('trips', 'expense_categories'),
        ('trips', 'transportation_types'),
        ('trips', 'trip_expenses'),
        ('trips', 'trip_routes'),
        ('trips', 'trips'),
        ('user', 'user_roles'),
        ('user', 'users')
),
missing AS (
    SELECT table_schema, table_name FROM expected
    EXCEPT
    SELECT table_schema, table_name
    FROM information_schema.tables
    WHERE table_type = 'BASE TABLE'
)
INSERT INTO smoke_results
SELECT
    'expected tables',
    NOT EXISTS (SELECT 1 FROM missing),
    COALESCE(
        'Missing: ' || string_agg(table_schema || '.' || table_name, ', ' ORDER BY table_schema, table_name),
        'All expected tables exist'
    )
FROM missing;

-- Exact trigger/helper functions used by constraints and audit columns.
WITH expected(function_schema, function_name) AS (
    VALUES
        ('course', 'update_course_status'),
        ('finance', 'check_finance_amount'),
        ('public', 'update_updated_at'),
        ('todo', 'set_completed_date')
),
actual AS (
    SELECT n.nspname AS function_schema, p.proname AS function_name
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE (n.nspname, p.proname) IN (
        ('course', 'update_course_status'),
        ('finance', 'check_finance_amount'),
        ('public', 'update_updated_at'),
        ('todo', 'set_completed_date')
    )
),
missing AS (
    SELECT function_schema, function_name FROM expected
    EXCEPT
    SELECT function_schema, function_name FROM actual
)
INSERT INTO smoke_results
SELECT
    'expected functions',
    NOT EXISTS (SELECT 1 FROM missing),
    COALESCE(
        'Missing: ' || string_agg(function_schema || '.' || function_name || '()', ', ' ORDER BY function_schema, function_name),
        'All expected functions exist'
    )
FROM missing;

-- Exact views used for reporting examples.
WITH expected(table_schema, table_name) AS (
    VALUES
        ('course', 'course_grades'),
        ('course', 'course_progress'),
        ('finance', 'financial_summary'),
        ('trips', 'trip_costs')
),
missing AS (
    SELECT table_schema, table_name FROM expected
    EXCEPT
    SELECT table_schema, table_name
    FROM information_schema.views
)
INSERT INTO smoke_results
SELECT
    'expected views',
    NOT EXISTS (SELECT 1 FROM missing),
    COALESCE(
        'Missing: ' || string_agg(table_schema || '.' || table_name, ', ' ORDER BY table_schema, table_name),
        'All expected views exist'
    )
FROM missing;

-- Exact triggers that protect derived fields and updated_at values.
WITH expected(event_object_schema, event_object_table, trigger_name) AS (
    VALUES
        ('course', 'course_topics', 'course_topics_status_trigger'),
        ('course', 'course_topics', 'course_topics_updated_at_trigger'),
        ('course', 'courses', 'courses_updated_at_trigger'),
        ('finance', 'finance_categories', 'finance_categories_updated_at_trigger'),
        ('finance', 'finances', 'finances_amount_trigger'),
        ('finance', 'finances', 'finances_updated_at_trigger'),
        ('habits', 'habit_categories', 'habit_categories_updated_at_trigger'),
        ('habits', 'habit_logs', 'habit_logs_updated_at_trigger'),
        ('habits', 'habits', 'habits_updated_at_trigger'),
        ('todo', 'todo_categories', 'todo_categories_updated_at_trigger'),
        ('todo', 'todos', 'todos_completed_date_trigger'),
        ('todo', 'todos', 'todos_updated_at_trigger'),
        ('trips', 'trip_expenses', 'trip_expenses_updated_at_trigger'),
        ('trips', 'trip_routes', 'trip_routes_updated_at_trigger'),
        ('trips', 'trips', 'trips_updated_at_trigger'),
        ('user', 'users', 'users_updated_at_trigger')
),
missing AS (
    SELECT event_object_schema, event_object_table, trigger_name FROM expected
    EXCEPT
    SELECT event_object_schema, event_object_table, trigger_name
    FROM information_schema.triggers
)
INSERT INTO smoke_results
SELECT
    'expected triggers',
    NOT EXISTS (SELECT 1 FROM missing),
    COALESCE(
        'Missing: ' || string_agg(event_object_schema || '.' || event_object_table || ':' || trigger_name, ', ' ORDER BY event_object_schema, event_object_table, trigger_name),
        'All expected triggers exist'
    )
FROM missing;

-- Foreign keys that show the schema is relational, not just loose tables.
WITH expected(table_schema, constraint_name) AS (
    VALUES
        ('course', 'course_topics_course_id_fkey'),
        ('course', 'course_topics_user_id_fkey'),
        ('course', 'courses_user_id_fkey'),
        ('course', 'fk_courses_status'),
        ('finance', 'finance_categories_user_id_fkey'),
        ('finance', 'finances_category_id_fkey'),
        ('finance', 'finances_user_id_fkey'),
        ('finance', 'fk_finance_categories_type'),
        ('habits', 'fk_habits_frequency'),
        ('habits', 'habit_categories_user_id_fkey'),
        ('habits', 'habit_logs_habit_id_fkey'),
        ('habits', 'habits_category_id_fkey'),
        ('habits', 'habits_user_id_fkey'),
        ('todo', 'fk_todos_task_priority'),
        ('todo', 'todo_categories_user_id_fkey'),
        ('todo', 'todos_category_id_fkey'),
        ('todo', 'todos_user_id_fkey'),
        ('trips', 'fk_trip_expenses_category'),
        ('trips', 'fk_trip_routes_transportation_type'),
        ('trips', 'trip_expenses_route_id_fkey'),
        ('trips', 'trip_routes_trip_id_fkey'),
        ('trips', 'trips_user_id_fkey'),
        ('user', 'fk_users_role')
),
missing AS (
    SELECT table_schema, constraint_name FROM expected
    EXCEPT
    SELECT table_schema, constraint_name
    FROM information_schema.table_constraints
    WHERE constraint_type = 'FOREIGN KEY'
)
INSERT INTO smoke_results
SELECT
    'expected foreign keys',
    NOT EXISTS (SELECT 1 FROM missing),
    COALESCE(
        'Missing: ' || string_agg(table_schema || '.' || constraint_name, ', ' ORDER BY table_schema, constraint_name),
        'All expected foreign keys exist'
    )
FROM missing;

-- Sequence ownership catches serial/id columns that were dumped incompletely.
WITH app_sequences AS (
    SELECT c.oid, n.nspname AS sequence_schema, c.relname AS sequence_name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'S'
    AND n.nspname IN ('course', 'finance', 'habits', 'todo', 'trips', 'user')
),
unowned AS (
    SELECT sequence_schema, sequence_name
    FROM app_sequences s
    WHERE NOT EXISTS (
        SELECT 1
        FROM pg_depend d
        WHERE d.objid = s.oid
        AND d.deptype = 'a'
    )
)
INSERT INTO smoke_results
SELECT
    'owned sequences',
    NOT EXISTS (SELECT 1 FROM unowned),
    COALESCE(
        'Unowned: ' || string_agg(sequence_schema || '.' || sequence_name, ', ' ORDER BY sequence_schema, sequence_name),
        'All application sequences are owned by table columns'
    )
FROM unowned;

SELECT
    CASE WHEN passed THEN '[PASS] ' ELSE '[FAIL] ' END || test_name || ': ' || details AS result
FROM smoke_results
ORDER BY test_name;

DO $$
DECLARE
    failed_count integer;
BEGIN
    SELECT COUNT(*) INTO failed_count FROM smoke_results WHERE NOT passed;

    IF failed_count > 0 THEN
        RAISE EXCEPTION 'Smoke tests failed: % check(s)', failed_count;
    END IF;

    RAISE NOTICE 'Smoke tests completed successfully.';
END $$;
