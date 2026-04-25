#!/usr/bin/env bash
#
# Generates schema.sql from "Personal base.sql" by stripping data sections.
# Removes all data sections while preserving all DDL.
#
# Usage:
#   ./scripts/generate_schema.sh
#
# Exit codes: 0 = success, 1 = error
#

set -euo pipefail

INPUT_FILE="${1:-Personal base.sql}"
OUTPUT_FILE="${2:-schema.sql}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Generating schema.sql from '$INPUT_FILE' ===${NC}"

# Check input file exists
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

# Count total lines
total_lines=$(wc -l < "$INPUT_FILE")
echo -e "${GRAY}Processing $total_lines lines...${NC}"

# Process file using awk to handle multi-line logic
awk '
    /^--.*Type: TABLE DATA/ { skip_section=1; data_sections++; next }
    /^--.*Type: SEQUENCE SET/ { skip_section=1; data_sections++; next }
    /^---/ && skip_section { skip_section=0; }
    skip_section {
        if (/^INSERT INTO/) inserts++
        if (/^SELECT pg_catalog\.setval/) setvals++
        next
    }
    /^INSERT INTO/ { inserts++; next }
    /^SELECT pg_catalog\.setval/ { setvals++; next }
    { print }
    
    END {
        print "DATA_SECTIONS:" data_sections > "/dev/stderr"
        print "INSERTS:" inserts > "/dev/stderr"
        print "SETVALS:" setvals > "/dev/stderr"
    }
' "$INPUT_FILE" > "$OUTPUT_FILE" 2> /tmp/stats.txt

# Read stats from stderr
data_sections=$(grep "^DATA_SECTIONS:" /tmp/stats.txt | cut -d: -f2 || echo "0")
inserts=$(grep "^INSERTS:" /tmp/stats.txt | cut -d: -f2 || echo "0")
setvals=$(grep "^SETVALS:" /tmp/stats.txt | cut -d: -f2 || echo "0")
rm -f /tmp/stats.txt

output_lines=$(wc -l < "$OUTPUT_FILE")

echo ""
echo -e "${GREEN}=== Generation Complete ===${NC}"
echo "Output: $OUTPUT_FILE"
echo "Lines: $total_lines → $output_lines"
echo -e "${YELLOW}Data sections removed: ${data_sections:-0}${NC}"
echo -e "${YELLOW}INSERT statements removed: ${inserts:-0}${NC}"
echo -e "${YELLOW}setval statements removed: ${setvals:-0}${NC}"

# Verify no Cyrillic in output
if grep -qP '[\x{0400}-\x{04FF}]' "$OUTPUT_FILE" 2>/dev/null; then
    echo "Warning: Cyrillic characters found in output!"
else
    echo -e "${GREEN}Verification: No Cyrillic characters in output${NC}"
fi

exit 0
