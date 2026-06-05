# Personal Database Management System

A PostgreSQL database schema for tracking courses, finances, habits, tasks, trips, and users in one structured personal data system.

## Project Overview

This project focuses on database design, data integrity, and repeatable validation. It includes a schema-only SQL file, an optional full dump with seed data, pgTAP tests, Docker setup for PostgreSQL, and CI checks for schema validation.

## What It Covers

| Area | Purpose | Main Tables |
| --- | --- | --- |
| `course` | Courses, topics, statuses, and progress | `courses`, `course_topics`, `course_statuses` |
| `finance` | Income and expense tracking | `finances`, `finance_categories`, `finance_types` |
| `habits` | Habit definitions and logs | `habits`, `habit_categories`, `habit_logs` |
| `todo` | Tasks, priorities, and statuses | `todos`, `todo_categories`, `task_statuses`, `task_priorities` |
| `trips` | Trips, routes, and trip expenses | `trips`, `trip_routes`, `trip_expenses` |
| `user` | Users and roles | `users`, `user_roles` |

## Database Features

- PostgreSQL schemas grouped by domain
- Primary keys, foreign keys, checks, indexes, functions, triggers, and views
- Trigger logic for course status updates, task completion dates, amount validation, and `updated_at` timestamps
- Analytics views for course progress, financial summaries, grades, and trip costs
- Schema-only setup file for clean installs
- Optional full dump with seed data for local exploration

## Repository Structure

```text
PersonalBase.sgl/
  schema.sql              Clean schema DDL, no seed data
  Personal base.sql       Full dump with seed data
  tests/pgtap/            pgTAP structure tests
  scripts/                Validation and schema generation scripts
  docker/pgtap/           PostgreSQL image setup for pgTAP
  docs/                   Architecture and validation notes
  ER.png                  ER diagram reference
```

## Requirements

- PostgreSQL 16 or higher
- `psql`
- Docker, optional but recommended for local validation
- Bash or PowerShell, depending on your OS

## Quick Start

Create a database and import the schema:

```bash
psql -U your_user -d your_db -f schema.sql
```

Import the optional full dump with seed data:

```bash
psql -U your_user -d your_db -f "Personal base.sql"
```

## Validation

Run all checks on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate_all.ps1
```

Run all checks on macOS or Linux:

```bash
bash scripts/validate_all.sh
```

The validation flow checks:

1. `schema.sql` is in sync with `Personal base.sql`
2. The schema imports into PostgreSQL with `ON_ERROR_STOP=on`
3. Smoke tests pass
4. pgTAP structure tests pass

## Schema Generation

`schema.sql` is generated from `Personal base.sql` by removing data sections and sequence resets while keeping DDL, constraints, functions, triggers, indexes, views, and comments.

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/generate_schema.ps1
```

macOS or Linux:

```bash
bash scripts/generate_schema.sh
```

Check whether `schema.sql` is current:

```bash
bash scripts/check_schema_up_to_date.sh
```

## Tests

The pgTAP tests verify schema structure:

- Schemas exist
- Main tables exist
- Important columns use expected data types
- Primary keys and foreign keys exist
- Indexes exist on key tables
- Trigger functions and triggers are installed
- Analytics views are present and queryable

Run pgTAP tests directly:

```bash
bash scripts/run_pgtap.sh
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pgtap.ps1
```

## Docker Setup

Start PostgreSQL with pgTAP support:

```bash
docker-compose up -d postgres
```

Stop it after testing:

```bash
docker-compose down
```

## CI

GitHub Actions runs validation on pushes and pull requests:

- Schema drift check
- PostgreSQL import
- Smoke tests
- pgTAP tests

## ER Diagram

`ER.png` is included as a visual reference.

![ER Diagram](ER.png)

The SQL files and pgTAP tests are the source of truth if the diagram ever differs from the schema.

## Notes

- `schema.sql` is the recommended starting point for a clean database.
- `Personal base.sql` is useful for local demos because it includes seed data.
- The project is focused on database design and validation, not on an application UI.
