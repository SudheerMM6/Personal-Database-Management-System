#!/usr/bin/env bash
#
# Runs pgTAP unit tests against the database.
#
# Usage:
#   ./scripts/run_pgtap.sh
#
# Exit codes: 0 = all tests passed, 1 = any test failed
#

set -euo pipefail

# Configuration
DB_NAME="${DB_NAME:-personalbase_ci}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
TEST_DIR="${TEST_DIR:-tests/pgtap}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

step() {
    echo -e "${CYAN}\n[STEP] $1${NC}"
}

pass() {
    echo -e "${GREEN}  [PASS] $1${NC}"
}

fail() {
    echo -e "${RED}  [FAIL] $1${NC}"
}

psql_cmd() {
    local db="${2:-$DB_NAME}"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$db" -t -c "$1" 2>/dev/null
}

check_pgtap_extension() {
    step "Checking pgTAP extension..."
    local result
    result=$(psql_cmd "SELECT 1 FROM pg_extension WHERE extname = 'pgtap';")
    if [[ "$result" == *"1"* ]]; then
        pass "pgTAP extension is installed"
    else
        step "Installing pgTAP extension..."
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
            -c "CREATE EXTENSION IF NOT EXISTS pgtap;" 2>/dev/null || true
        result=$(psql_cmd "SELECT 1 FROM pg_extension WHERE extname = 'pgtap';")
        if [[ "$result" == *"1"* ]]; then
            pass "pgTAP extension installed successfully"
        else
            fail "Failed to install pgTAP extension"
            exit 1
        fi
    fi
}

check_pg_prove() {
    command -v pg_prove >/dev/null 2>&1
}

run_tests_with_pg_prove() {
    step "Running pgTAP tests with pg_prove..."
    
    export PGPASSWORD="$DB_PASSWORD"
    export PGHOST="$DB_HOST"
    export PGPORT="$DB_PORT"
    export PGUSER="$DB_USER"
    export PGDATABASE="$DB_NAME"
    
    pg_prove -d "$DB_NAME" "$TEST_DIR"/*.pg
    local exit_code=$?
    
    unset PGPASSWORD PGHOST PGPORT PGUSER PGDATABASE
    
    return $exit_code
}

run_tests_with_psql() {
    step "Running pgTAP tests with psql (fallback)..."
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    for test_file in "$TEST_DIR"/*.pg; do
        if [[ -f "$test_file" ]]; then
            local basename
            basename=$(basename "$test_file")
            echo -e "\n  ${YELLOW}Running: $basename${NC}"
            
            local output
            output=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$test_file" 2>&1) || true
            
            # Parse TAP output
            while IFS= read -r line; do
                if [[ "$line" =~ ^ok\ [0-9]+ ]]; then
                    ((passed_tests++))
                    ((total_tests++))
                elif [[ "$line" =~ ^not\ ok\ [0-9]+ ]]; then
                    ((failed_tests++))
                    ((total_tests++))
                    fail "Test failed in $basename: $line"
                elif [[ "$line" =~ ^1\.\.([0-9]+) ]]; then
                    echo -e "${GRAY}    Planned tests: ${BASH_REMATCH[1]}${NC}"
                fi
            done <<< "$output"
        fi
    done
    
    echo -e "${CYAN}\n=== pgTAP Results ===${NC}"
    echo "Total: $total_tests, Passed: $passed_tests, Failed: $failed_tests"
    
    if [[ $failed_tests -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Main execution
echo -e "${CYAN}=== pgTAP Unit Tests ===${NC}"
echo "Database: $DB_NAME on $DB_HOST:$DB_PORT"
echo "Test directory: $TEST_DIR"

# Check test directory exists
if [[ ! -d "$TEST_DIR" ]]; then
    fail "Test directory not found: $TEST_DIR"
    exit 1
fi

# Check database connection
step "Testing database connection..."
if psql_cmd "SELECT 1;" postgres | grep -q "1"; then
    pass "Database connection OK"
else
    fail "Cannot connect to database"
    exit 1
fi

# Ensure pgTAP is available
check_pgtap_extension

# Run tests
exit_code=0
if check_pg_prove; then
    echo -e "\n${GRAY}(pg_prove available - using for better output)${NC}"
    run_tests_with_pg_prove
    exit_code=$?
else
    echo -e "\n${YELLOW}(pg_prove not found - using psql fallback)${NC}"
    run_tests_with_psql
    exit_code=$?
fi

if [[ $exit_code -eq 0 ]]; then
    echo -e "${GREEN}\n[pgTAP TESTS PASSED]${NC}"
else
    echo -e "${RED}\n[pgTAP TESTS FAILED]${NC}"
fi

exit $exit_code
