# Architecture Overview

## Purpose

PersonalBase is a PostgreSQL schema for organizing personal life data across learning, finance, habits, tasks, trips, and users. The project is designed as a database-first system with repeatable validation.

## Schema Layout

| Schema | Purpose | Main Tables |
| --- | --- | --- |
| `course` | Learning and education | `courses`, `course_topics`, `course_statuses` |
| `finance` | Income and expenses | `finances`, `finance_categories`, `finance_types` |
| `habits` | Habit tracking | `habits`, `habit_categories`, `habit_logs` |
| `todo` | Task management | `todos`, `todo_categories`, `task_statuses`, `task_priorities` |
| `trips` | Travel planning | `trips`, `trip_routes`, `trip_expenses` |
| `user` | Users and roles | `users`, `user_roles` |

## Source Files

Authoritative files:

- `schema.sql`: clean schema DDL without seed data
- `tests/pgtap/*.pg`: pgTAP structure tests
- `scripts/schema_smoke_tests.sql`: SQL smoke tests

Reference files:

- `Personal base.sql`: full dump with seed data
- `ER.png`: visual diagram

## Validation Flow

```bash
bash scripts/validate_all.sh
```

Validation runs four checks:

1. Compare `schema.sql` against the generated schema.
2. Import the schema into PostgreSQL.
3. Run smoke tests against database objects.
4. Run pgTAP tests for schemas, tables, columns, constraints, indexes, functions, triggers, and views.

## Making Schema Changes

1. Edit `Personal base.sql`.
2. Regenerate `schema.sql`.
3. Run validation.
4. Commit both SQL files if the generated schema changed.

```bash
bash scripts/generate_schema.sh
bash scripts/validate_all.sh
```
