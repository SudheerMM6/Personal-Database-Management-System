# Personal Database Management System

A fully‑structured PostgreSQL 16+ database designed to manage and analyze multiple aspects of personal life — from education and finances to habits, tasks, and travel — with automation, data integrity checks, and analytics views.

## 🗂️  Modular Schema Design

Organized into dedicated schemas for scalability and clarity:

- course – Managing courses and learning topics (tables: courses, course_topics, course_statuses).
- finance – Tracking income and expenses (tables: finances, finance_categories, finance_types, plus triggers for checking amounts).
- habits – Tracking habits and categories (tables: habits, habit_categories, habit_logs).
- todo – Managing tasks and task categories (tables: todos, todo_categories, task_statuses, task_priorities).
- trips – Planning trips, routes, and expenses (tables: trips, trip_routes, trip_expenses).

⚙️ Intelligent Features

Triggers and functions are used for automatic updates of statuses, data correctness, and dates:

- update_course_status: Updates the course status when topics change..
- check_finance_amount: Checks the correctness of the amount for income and expenses.
- set_completed_date: Automatically sets the completion date for tasks.
- update_updated_at: Updates updated_at on changes.

📊 Built‑In Analytics Views
- Course Progress – Monitor learning milestones (course_progress).
- Financial Summary – Monthly income/expense breakdown (financial_summary).
- Final Grades – Consolidated academic performance  (course_grades).
- Trip Costs – Expense tracking per trip (trip_costs).


## 🚀 Quick Start

1. Deploy the database in PostgreSQL version 16 or higher.
2. Run the SQL script:
   ```bash
   psql -U your_user -d your_db -f "Personal base.sql"
   ```

## Requirements

- PostgreSQL 16 or higher
- psql command-line tool

## ✅ One-Command Validation

Validate that the SQL imports cleanly:

**Windows:**
```powershell
powershell scripts/validate.ps1
```

**macOS/Linux:**
```bash
bash scripts/validate.sh
```

**With Docker (recommended):**
```bash
docker-compose up -d
bash scripts/validate.sh --cleanup
```

The validation script uses `ON_ERROR_STOP=on` so any SQL error fails fast.

## 🔒 CI Status

![CI](https://github.com/SudheerMM6/Personal-Database-Management-System/workflows/CI%20-%20Database%20Schema%20Validation/badge.svg)

CI automatically validates that the schema imports cleanly into PostgreSQL 16 on every push and PR.

## Documentation

- See `ER.png` for the Entity Relationship Diagram
- Schema documentation is embedded in the SQL file as comments
- See `scripts/schema_smoke_tests.sql` for automated validation queries
