#!/usr/bin/env bash
#
# Validates that schema.sql imports cleanly into PostgreSQL.
#
# Usage:
#   ./scripts/validate.sh                    # Validate schema.sql (default)
#   ./scripts/validate.sh --with-data        # Validate full dump with sample data
#   ./scripts/validate.sh --cleanup          # Cleanup containers after
#   DB_PASSWORD=mysecret ./validate.sh     # Custom password
#
# Exit codes: 0 = PASS, 1 = FAIL
#

set -euo pipefail

# Configuration with defaults
SQL_FILE="${SQL_FILE:-schema.sql}"
DB_NAME="${DB_NAME:-personalbase_ci}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
CLEANUP="${CLEANUP:-false}"
SKIP_DOCKER="${SKIP_DOCKER:-false}"
WITH_DATA="${WITH_DATA:-false}"

# Counters
PASSED=0
FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

step() {
    echo -e "${CYAN}\n[STEP] $1${NC}"
}

pass() {
    echo -e "${GREEN}  [PASS] $1${NC}"
    ((PASSED++))
}

fail() {
    echo -e "${RED}  [FAIL] $1${NC}"
    ((FAILED++))
}

cleanup() {
    if [[ "$DOCKER_STARTED" == "true" && "$CLEANUP" == "true" ]]; then
        step "Stopping Docker containers..."
        docker-compose down 2>/dev/null || true
    fi
}

trap cleanup EXIT

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

psql_cmd() {
    local db="${2:-$DB_NAME}"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$db" -t -c "$1" 2>/dev/null
}

start_docker() {
    if [[ "$SKIP_DOCKER" == "true" ]]; then
        return
    fi
    
    step "Checking for docker-compose..."
    if ! command_exists docker-compose && ! command_exists docker; then
        echo -e "${YELLOW}  Docker not found. Assuming local PostgreSQL.${NC}"
        return
    fi
    
    step "Starting PostgreSQL via docker-compose..."
    if docker-compose up -d postgres 2>/dev/null; then
        export DOCKER_STARTED="true"
        
        echo "  Waiting for PostgreSQL to be ready..."
        local attempt=0
        local max_attempts=30
        while [[ $attempt -lt $max_attempts ]]; do
            if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "SELECT 1" 2>/dev/null; then
                pass "PostgreSQL is ready"
                return
            fi
            sleep 1
            ((attempt++))
        done
        fail "PostgreSQL failed to start within $max_attempts seconds"
        exit 1
    else
        echo -e "${YELLOW}  docker-compose failed to start. Assuming local PostgreSQL.${NC}"
    fi
}

test_connection() {
    step "Testing database connection..."
    if result=$(psql_cmd "SELECT version();" postgres 2>&1); then
        if [[ "$result" == *"PostgreSQL"* ]]; then
            pass "Connected to PostgreSQL"
        else
            fail "Unexpected response from database"
            exit 1
        fi
    else
        fail "Database connection failed"
        exit 1
    fi
}

init_database() {
    step "Creating test database '$DB_NAME'..."
    psql_cmd "DROP DATABASE IF EXISTS $DB_NAME;" postgres >/dev/null 2>&1 || true
    psql_cmd "CREATE DATABASE $DB_NAME;" postgres >/dev/null 2>&1
    
    if psql_cmd "SELECT datname FROM pg_database WHERE datname = '$DB_NAME';" postgres | grep -q "$DB_NAME"; then
        pass "Test database created"
    else
        fail "Failed to create test database"
        exit 1
    fi
}

import_sql() {
    step "Importing SQL dump (with ON_ERROR_STOP=on)..."
    
    if [[ ! -f "$SQL_FILE" ]]; then
        fail "SQL file not found: $SQL_FILE"
        exit 1
    fi
    
    if PGPASSWORD="$DB_PASSWORD" psql --set ON_ERROR_STOP=on --single-transaction \
         -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
         -f "$SQL_FILE" 2>&1; then
        pass "SQL dump imported successfully"
    else
        fail "SQL import failed"
        exit 1
    fi
}

run_smoke_tests() {
    step "Running schema smoke tests..."
    
    local test_file="$(dirname "$0")/schema_smoke_tests.sql"
    if [[ ! -f "$test_file" ]]; then
        fail "Smoke test file not found: $test_file"
        return
    fi
    
    local output
    output=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$test_file" 2>&1) || true
    
    # Parse test results
    while IFS= read -r line; do
        if [[ "$line" =~ ^\s*\[PASS\] ]]; then
            pass "${line#*\[PASS\] }"
        elif [[ "$line" =~ ^\s*\[FAIL\] ]]; then
            fail "${line#*\[FAIL\] }"
        fi
    done <<< "$output"
}

test_invalid_objects() {
    step "Checking for invalid database objects..."
    
    local query="SELECT count(*) FROM pg_class c 
JOIN pg_namespace n ON n.oid = c.relnamespace 
WHERE c.relpersistence != 't' 
AND c.relkind IN ('r', 'v', 'm', 'S', 'f') 
AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
AND NOT c.relhasrules 
AND c.relfilenode = 0;"
    
    local result
    result=$(psql_cmd "$query" | xargs)
    
    if [[ "$result" == "0" ]]; then
        pass "No invalid objects found"
    else
        fail "Found invalid objects: $result"
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cleanup)
            CLEANUP="true"
            shift
            ;;
        --skip-docker)
            SKIP_DOCKER="true"
            shift
            ;;
        --with-data)
            WITH_DATA="true"
            SQL_FILE="Personal base.sql"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Main execution
if [[ "$WITH_DATA" == "true" ]]; then
    SOURCE_TYPE="FULL DUMP (with data)"
else
    SOURCE_TYPE="SCHEMA ONLY (English-clean)"
fi

echo -e "${WHITE}=== PersonalBase SQL Validation ===${NC}"
echo "Source: $SOURCE_TYPE"
echo "SQL File: $SQL_FILE"
echo "Database: $DB_NAME on $DB_HOST:$DB_PORT"

start_docker
test_connection
init_database
import_sql
run_smoke_tests
test_invalid_objects

echo -e "${WHITE}\n=== SUMMARY ===${NC}"
echo -e "${GREEN}Passed: $PASSED${NC}"
if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $FAILED${NC}"
else
    echo -e "${GREEN}Failed: $FAILED${NC}"
fi

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

echo -e "${GREEN}\n[VALIDATION PASSED]${NC}"
exit 0
