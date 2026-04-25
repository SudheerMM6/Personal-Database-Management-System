#!/usr/bin/env bash
#
# Checks if schema.sql is up to date with Personal base.sql.
# Fails with clear error message if they differ.
#
# Usage:
#   ./scripts/check_schema_up_to_date.sh
#
# Exit codes: 0 = up to date, 1 = out of date
#

set -euo pipefail

SOURCE_FILE="${1:-Personal base.sql}"
EXPECTED_FILE="${2:-schema.sql}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Checking if $EXPECTED_FILE is up to date ===${NC}"

# Check source file exists
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Error: Source file not found: $SOURCE_FILE"
    exit 1
fi

# Check expected file exists
if [[ ! -f "$EXPECTED_FILE" ]]; then
    echo "Error: Expected file not found: $EXPECTED_FILE (needs to be generated)"
    exit 1
fi

# Create temp file
temp_file=$(mktemp)
trap "rm -f $temp_file" EXIT

echo -e "${GRAY}Generating temporary schema from '$SOURCE_FILE'...${NC}"

# Generate temp schema (same logic as generate_schema.sh)
awk '
    /^--.*Type: TABLE DATA/ { skip_section=1; next }
    /^--.*Type: SEQUENCE SET/ { skip_section=1; next }
    /^---/ && skip_section { skip_section=0; }
    skip_section { next }
    /^INSERT INTO/ { next }
    /^SELECT pg_catalog\.setval/ { next }
    { print }
' "$SOURCE_FILE" > "$temp_file"

echo -e "${GRAY}Normalizing and comparing...${NC}"

# Create normalized versions (strip UTF-8 BOM if present)
normalized_temp="${temp_file}.norm"
normalized_expected="${temp_file}.exp.norm"
trap "rm -f $temp_file $normalized_temp $normalized_expected" EXIT

# Strip BOM (EF BB BF at start) if present
if command -v sed >/dev/null 2>&1; then
    sed '1s/^\xEF\xBB\xBF//' "$temp_file" > "$normalized_temp"
    sed '1s/^\xEF\xBB\xBF//' "$EXPECTED_FILE" > "$normalized_expected"
else
    # Fallback: use tail to skip first 3 bytes if file starts with BOM
    head -c3 "$temp_file" | od -An -tx1 | grep -q "ef bb bf" && tail -c +4 "$temp_file" > "$normalized_temp" || cp "$temp_file" "$normalized_temp"
    head -c3 "$EXPECTED_FILE" | od -An -tx1 | grep -q "ef bb bf" && tail -c +4 "$EXPECTED_FILE" > "$normalized_expected" || cp "$EXPECTED_FILE" "$normalized_expected"
fi

# Compare normalized files
if diff -q "$normalized_temp" "$normalized_expected" > /dev/null 2>&1; then
    echo ""
    echo -e "${GREEN}[CHECK PASSED] $EXPECTED_FILE is up to date${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}[CHECK FAILED] $EXPECTED_FILE is out of date!${NC}"
    echo ""
    echo -e "${YELLOW}The following differences were found:${NC}"
    diff "$normalized_temp" "$normalized_expected" | head -30
    echo ""
    echo -e "${CYAN}To fix this, run:${NC}"
    echo "  bash scripts/generate_schema.sh"
    echo "Then commit the updated $EXPECTED_FILE"
    exit 1
fi
