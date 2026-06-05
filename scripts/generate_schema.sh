#!/usr/bin/env bash
#
# Generates schema.sql from "Personal base.sql" by stripping data sections.
#
# Usage:
#   ./scripts/generate_schema.sh

set -euo pipefail

INPUT_FILE="${1:-Personal base.sql}"
OUTPUT_FILE="${2:-schema.sql}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

echo -e "${CYAN}=== Generating schema.sql from '$INPUT_FILE' ===${NC}"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

total_lines=$(wc -l < "$INPUT_FILE")
echo -e "${GRAY}Processing $total_lines lines...${NC}"

awk '
BEGIN {
    in_section = 0
    skip_section = 0
    data_sections = 0
    inserts = 0
    setvals = 0
    copy_blocks = 0
    in_copy = 0
}

/^-- Name:.*Type:.*Schema:.*Owner:/ {
    in_section = 1
    skip_section = 0

    if (match($0, /Type: ([^;]+)/, arr)) {
        section_type = arr[1]
        if (section_type == "TABLE DATA" || section_type == "SEQUENCE SET") {
            skip_section = 1
            data_sections++
        }
    }
}

/^COPY / {
    in_copy = 1
    copy_blocks++
    next
}

/^\\\.$/ && in_copy {
    in_copy = 0
    next
}

in_copy { next }

/^INSERT INTO/ { inserts++; next }
/^SELECT pg_catalog\.setval/ { setvals++; next }

/^---$/ {
    if (in_section) {
        in_section = 0
        skip_section = 0
    }
}

!skip_section { print }

END {
    print "DATA_SECTIONS:" data_sections > "/dev/stderr"
    print "INSERTS:" inserts > "/dev/stderr"
    print "SETVALS:" setvals > "/dev/stderr"
    print "COPY_BLOCKS:" copy_blocks > "/dev/stderr"
}
' "$INPUT_FILE" 2> /tmp/stats.txt > "$OUTPUT_FILE.tmp"

if command -v sed >/dev/null 2>&1; then
    sed '1s/^\xEF\xBB\xBF//' "$OUTPUT_FILE.tmp" > "$OUTPUT_FILE"
else
    if head -c3 "$OUTPUT_FILE.tmp" | od -An -tx1 2>/dev/null | grep -q "ef bb bf"; then
        tail -c +4 "$OUTPUT_FILE.tmp" > "$OUTPUT_FILE"
    else
        mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    fi
fi
rm -f "$OUTPUT_FILE.tmp"

data_sections=$(grep "^DATA_SECTIONS:" /tmp/stats.txt | cut -d: -f2 || echo "0")
inserts=$(grep "^INSERTS:" /tmp/stats.txt | cut -d: -f2 || echo "0")
setvals=$(grep "^SETVALS:" /tmp/stats.txt | cut -d: -f2 || echo "0")
copy_blocks=$(grep "^COPY_BLOCKS:" /tmp/stats.txt | cut -d: -f2 || echo "0")
rm -f /tmp/stats.txt

output_lines=$(wc -l < "$OUTPUT_FILE")

echo ""
echo -e "${GREEN}=== Generation Complete ===${NC}"
echo "Output: $OUTPUT_FILE"
echo "Lines: $total_lines -> $output_lines"
echo -e "${YELLOW}Data sections removed: ${data_sections:-0}${NC}"
echo -e "${YELLOW}INSERT statements removed: ${inserts:-0}${NC}"
echo -e "${YELLOW}setval statements removed: ${setvals:-0}${NC}"
echo -e "${YELLOW}COPY blocks removed: ${copy_blocks:-0}${NC}"

if grep -qP '[\x{0400}-\x{04FF}]' "$OUTPUT_FILE" 2>/dev/null; then
    echo "Warning: Cyrillic characters found in output."
else
    echo -e "${GREEN}Verification: No Cyrillic characters in output${NC}"
fi

exit 0
