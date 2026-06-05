# Validation Notes

Run the full validation suite:

```bash
bash scripts/validate_all.sh
```

On Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate_all.ps1
```

## What Gets Tested

pgTAP tests:

- `01_schemas`: all six schemas exist
- `02_tables`: anchor tables exist
- `03_columns`: important columns and data types match expectations
- `04_constraints`: primary keys and foreign keys exist
- `05_indexes`: indexes exist on key tables
- `06_functions`: trigger functions and triggers are installed
- `07_views`: analytics views exist and can be queried

Smoke tests:

- Table count check
- Foreign key count check
- Function, view, and trigger checks
- Invalid object check

Static check:

- `schema.sql` is current with the generated schema from `Personal base.sql`

## ER Diagram

`ER.png` is a reference diagram. Use `schema.sql` and the pgTAP tests as the source of truth.
