#!/usr/bin/env bash
#
# Scans repository files for Cyrillic characters.
# Fails (exit 1) if Cyrillic is found in English-clean files.
#
# Usage:
#   ./scripts/scan_cyrillic.sh
#
# Exit codes: 0 = PASS, 1 = FAIL
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

FOUND_CYRILLIC=false
SCANNED_COUNT=0
CYRILLIC_FILES=()

# Files to scan directly
FILES_TO_SCAN=(
    "README.md"
    "schema.sql"
)

# Directories to scan
DIRS_TO_SCAN=(
    "docs"
    "scripts"
    ".github/workflows"
)

echo -e "${CYAN}=== Cyrillic Character Scan ===${NC}"
echo ""

# Function to check a file for Cyrillic
check_file() {
    local file="$1"
    local relative_path="${file#./}"
    
    if [[ ! -f "$file" ]]; then
        return
    fi
    
    ((SCANNED_COUNT++))
    
    # Check for Cyrillic characters (|| true prevents set -e from exiting when no matches)
    if grep -qP '[\x{0400}-\x{04FF}]' "$file" 2>/dev/null || false; then
        FOUND_CYRILLIC=true
        CYRILLIC_FILES+=("$relative_path")
        
        echo -e "${RED}[FAIL] $relative_path${NC}"
        
        # Show lines with Cyrillic
        local line_num=0
        while IFS= read -r line; do
            ((line_num++))
            if echo "$line" | grep -qP '[\x{0400}-\x{04FF}]' 2>/dev/null || false; then
                local found_text
                found_text=$(echo "$line" | grep -oP '[\x{0400}-\x{04FF}]+' | tr '\n' ' ')
                echo -e "${RED}  Line ${line_num}: ${found_text}${NC}"
            fi
        done < "$file"
    fi
}

# Check specific files
for file in "${FILES_TO_SCAN[@]}"; do
    if [[ -f "$file" ]]; then
        check_file "$file"
    fi
done

# Check directories
for dir in "${DIRS_TO_SCAN[@]}"; do
    if [[ -d "$dir" ]]; then
        while IFS= read -r -d '' file; do
            check_file "$file"
        done < <(find "$dir" -type f ! -name "*.png" ! -name "*.jpg" ! -name "*.jpeg" ! -name "*.gif" ! -name "*.ico" ! -name "*.pdf" -print0 2>/dev/null)
    fi
done

echo ""
echo -e "Scanned ${SCANNED_COUNT} files"

if [[ "$FOUND_CYRILLIC" == "true" ]]; then
    echo ""
    echo -e "${RED}[SCAN FAILED] Cyrillic characters found in:${NC}"
    for file in "${CYRILLIC_FILES[@]}"; do
        echo -e "${RED}  - $file${NC}"
    done
    echo ""
    echo -e "${YELLOW}Note: Cyrillic is allowed only in 'Personal base.sql' (original dump file)${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}[SCAN PASSED] No Cyrillic characters found in English-clean files${NC}"
    echo ""
    echo -e "${GREEN}All files are English-only (schema.sql, docs, scripts, README)${NC}"
    exit 0
fi
