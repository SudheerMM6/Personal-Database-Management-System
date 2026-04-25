# Reviewer Quickstart

## Start Here

One command validates everything:

```bash
bash scripts/validate_all.sh
```

## What Gets Tested

### pgTAP Unit Tests (68 assertions)
- **01_schemas** - All 6 schemas exist
- **02_tables** - Anchor tables present
- **03_columns** - Critical columns + data types
- **04_constraints** - Primary keys, foreign keys
- **05_indexes** - Indexes on key tables
- **06_functions** - Trigger functions + triggers
- **07_views** - Analytics views exist and are queryable

### Smoke Tests
- Table count >= 20
- FK constraints >= 10
- No invalid objects
- Functions, views, triggers present

### Static Checks
- `schema.sql` up to date with generator

## ER Diagram

`ER.png` is a visual aid for understanding relationships. It may drift from the actual schema.

**Authoritative source:**
- `schema.sql` - DDL
- pgTAP tests - Structure assertions

## CI Pipeline

GitHub Actions runs the same validation as `validate_all` on every PR:
1. Schema drift check
2. PostgreSQL import
3. Smoke tests
4. pgTAP tests

All must pass before merge.
