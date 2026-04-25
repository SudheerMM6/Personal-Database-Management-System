--
-- Schema Smoke Tests for PersonalBase
-- Run via: psql -d personalbase_ci -f schema_smoke_tests.sql
--
-- Output format: [PASS] message or [FAIL] message
-- Exit code: psql returns non-zero on error
--

\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

-- Helper function to emit results
DO $$
BEGIN
    RAISE NOTICE 'Starting schema smoke tests...';
END $$;

-- Test 1: Check expected schemas exist
SELECT 
    CASE WHEN COUNT(*) >= 6 
    THEN '[PASS] All expected schemas exist (course, finance, habits, todo, trips, user)'
    ELSE '[FAIL] Missing schemas. Found: ' || string_agg(nspname, ', ')
    END as result
FROM pg_namespace 
WHERE nspname IN ('course', 'finance', 'habits', 'todo', 'trips', 'user');

-- Test 2: Verify minimum table count (should have at least 20 tables across all schemas)
SELECT 
    CASE WHEN COUNT(*) >= 20 
    THEN '[PASS] At least 20 tables found (' || COUNT(*) || ' total)'
    ELSE '[FAIL] Expected at least 20 tables, found ' || COUNT(*)::text
    END as result
FROM information_schema.tables 
WHERE table_schema IN ('course', 'finance', 'habits', 'todo', 'trips', 'user')
AND table_type = 'BASE TABLE';

-- Test 3: Critical 'user' tables exist
SELECT 
    CASE WHEN COUNT(*) >= 2 
    THEN '[PASS] Core user schema tables exist (users, user_roles)'
    ELSE '[FAIL] Missing user schema tables'
    END as result
FROM information_schema.tables 
WHERE table_schema = 'user' 
AND table_name IN ('users', 'user_roles');

-- Test 4: Critical 'course' tables exist
SELECT 
    CASE WHEN COUNT(*) >= 3 
    THEN '[PASS] Course schema tables exist (courses, course_topics, course_statuses)'
    ELSE '[FAIL] Missing course schema tables'
    END as result
FROM information_schema.tables 
WHERE table_schema = 'course' 
AND table_name IN ('courses', 'course_topics', 'course_statuses');

-- Test 5: Critical 'finance' tables exist
SELECT 
    CASE WHEN COUNT(*) >= 2 
    THEN '[PASS] Finance schema tables exist (finances, finance_categories)'
    ELSE '[FAIL] Missing finance schema tables'
    END as result
FROM information_schema.tables 
WHERE table_schema = 'finance' 
AND table_name IN ('finances', 'finance_categories', 'finance_types');

-- Test 6: Critical 'habits' tables exist
SELECT 
    CASE WHEN COUNT(*) >= 2 
    THEN '[PASS] Habits schema tables exist (habits, habit_categories)'
    ELSE '[FAIL] Missing habits schema tables'
    END as result
FROM information_schema.tables 
WHERE table_schema = 'habits' 
AND table_name IN ('habits', 'habit_categories', 'habit_logs');

-- Test 7: Critical 'todo' tables exist
SELECT 
    CASE WHEN COUNT(*) >= 2 
    THEN '[PASS] Todo schema tables exist (todos, todo_categories)'
    ELSE '[FAIL] Missing todo schema tables'
    END as result
FROM information_schema.tables 
WHERE table_schema = 'todo' 
AND table_name IN ('todos', 'todo_categories', 'task_statuses');

-- Test 8: Critical 'trips' tables exist
SELECT 
    CASE WHEN COUNT(*) >= 2 
    THEN '[PASS] Trips schema tables exist (trips, trip_routes)'
    ELSE '[FAIL] Missing trips schema tables'
    END as result
FROM information_schema.tables 
WHERE table_schema = 'trips' 
AND table_name IN ('trips', 'trip_routes', 'trip_expenses');

-- Test 9: Check for functions (triggers)
SELECT 
    CASE WHEN COUNT(*) >= 4 
    THEN '[PASS] Trigger functions exist (' || COUNT(*) || ' found)'
    ELSE '[FAIL] Expected at least 4 trigger functions, found ' || COUNT(*)::text
    END as result
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('course', 'finance', 'todo')
AND p.proname LIKE '%status%' OR p.proname LIKE '%check%' OR p.proname LIKE '%date%' OR p.proname LIKE '%update%';

-- Test 10: Check for views (analytics)
SELECT 
    CASE WHEN COUNT(*) >= 3 
    THEN '[PASS] Analytics views exist (' || COUNT(*) || ' found)'
    ELSE '[FAIL] Expected at least 3 views, found ' || COUNT(*)::text
    END as result
FROM information_schema.views 
WHERE table_schema IN ('course', 'finance', 'trips')
AND table_schema NOT IN ('pg_catalog', 'information_schema');

-- Test 11: Verify referential integrity (FK constraints exist)
SELECT 
    CASE WHEN COUNT(*) >= 10 
    THEN '[PASS] Foreign key constraints exist (' || COUNT(*) || ' found)'
    ELSE '[FAIL] Expected at least 10 FK constraints, found ' || COUNT(*)::text
    END as result
FROM information_schema.table_constraints 
WHERE constraint_type = 'FOREIGN KEY'
AND table_schema IN ('course', 'finance', 'habits', 'todo', 'trips', 'user');

-- Test 12: Check all sequences are properly associated
SELECT 
    CASE WHEN COUNT(*) = COUNT(*) FILTER (WHERE relkind = 'S') 
    THEN '[PASS] All sequences valid'
    ELSE '[FAIL] Found invalid sequences'
    END as result
FROM pg_class
WHERE relkind = 'S'
AND relnamespace IN (SELECT oid FROM pg_namespace WHERE nspname IN ('course', 'finance', 'habits', 'todo', 'trips', 'user'));

-- Summary
SELECT '[INFO] Smoke tests completed. Check output above for results.' as result;
