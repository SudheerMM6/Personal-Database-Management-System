# Translation Notes

## Overview

This repository provides two SQL artifacts:

| File | Purpose | Content |
|------|---------|---------|
| `schema.sql` | **Default / Production** | Schema only (DDL) - English clean |
| `Personal base.sql` | **Reference / Full dump** | Schema + sample data (multilingual) |

## Cyrillic Content

The original dump file (`Personal base.sql`) contains one Cyrillic word in sample data:
- Line 2911: `'Фитнес'` (Russian for "Fitness") in `habits.habit_categories`

This is **sample data only** and does not affect the schema structure.

## Default Import Path (Recommended)

Recruiters and new users should use the English-clean schema:

```bash
psql -U your_user -d your_db -f schema.sql
```

## Full Dump with Sample Data (Optional)

For personal use with sample data (includes Cyrillic):

```bash
psql -U your_user -d your_db -f "Personal base.sql"
```

## Validation

All validation scripts and CI use `schema.sql` by default:
- `scripts/validate.sh` / `scripts/validate.ps1`
- GitHub Actions CI

The Cyrillic guard script (`scripts/scan_cyrillic.*`) ensures no Cyrillic text enters the default English-clean files.
