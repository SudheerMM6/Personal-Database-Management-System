# Architecture Overview

## What This Is

A PostgreSQL 16+ database schema for managing personal life data: courses, finances, habits, tasks, and travel.

## Schema Structure

6 modular schemas:

| Schema | Purpose | Key Tables |
|--------|---------|------------|
| `course` | Learning & education | courses, course_topics, course_statuses |
| `finance` | Income & expenses | finances, finance_categories, finance_types |
| `habits` | Habit tracking | habits, habit_categories, habit_logs |
| `todo` | Task management | todos, todo_categories, task_statuses |
| `trips` | Travel planning | trips, trip_routes, trip_expenses |
| `user` | User management | users, user_roles |

## Source of Truth

**Authoritative:**
- `schema.sql` - English-clean schema DDL
- `tests/pgtap/*.pg` - 68 pgTAP unit tests
- `scripts/schema_smoke_tests.sql` - Additional validation

**Reference only:**
- `"Personal base.sql"` - Full dump with sample data (may contain Cyrillic)
- `ER.png` - Visual diagram (may drift; use pgTAP tests to verify structure)

## How Validation Works

```bash
bash scripts/validate_all.sh
```

Runs 4 steps:
1. Schema drift check (schema.sql matches generator)
2. PostgreSQL import test
3. Smoke tests
4. pgTAP unit tests (68 assertions)

## Extending Safely

1. Edit `"Personal base.sql"` (source dump)
2. Regenerate: `bash scripts/generate_schema.sh`
3. Test: `bash scripts/validate_all.sh`
4. Commit both files

CI will fail if schema.sql drifts from the generator.
