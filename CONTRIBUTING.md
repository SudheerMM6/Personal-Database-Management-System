# Contributing

## Before Submitting a PR

1. **Run full validation:**
   ```bash
   bash scripts/validate_all.sh
   ```

2. **If you modified the source dump:**
   ```bash
   bash scripts/generate_schema.sh  # regenerate schema.sql
   bash scripts/validate_all.sh     # verify both files
   ```

## CI Requirements

- All 68 pgTAP tests must pass
- Schema drift check must pass
- No Cyrillic in English-clean files

## Questions?

See `docs/REVIEWER_NOTES.md` for what's tested.
See `docs/ARCHITECTURE.md` for schema design.
