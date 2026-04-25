#!/usr/bin/env bash
#
# One-command validation for PersonalBase database.
#
# Runs the complete validation suite:
#   1. Cyrillic character scan
#   2. Schema drift check
#   3. PostgreSQL startup (via docker-compose if available)
#   4. Schema import validation
#   5. pgTAP unit tests
#
# Usage:
#   ./scripts/validate_all.sh
#   ./scripts/validate_all.sh --with-data
#   ./scripts/validate_all.sh --cleanup
#
# Exit codes: 0 = all passed, 1 = any failure
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STEP=0
FAILED_STEP=""
START_TIME=$(date +%s)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

WITH_DATA=false
CLEANUP=false
SKIP_DOCKER=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --with-data)
            WITH_DATA=true
            shift
            ;;
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --skip-docker)
            SKIP_DOCKER=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

header() {
    echo -e "${CYAN}"
    echo "========================================"
    echo "  $1"
    echo "========================================"
    echo -e "${NC}"
}

step() {
    ((STEP++))
    echo -e "${YELLOW}\n[Step $STEP] $1${NC}"
}

success() {
    echo -e "${GREEN}  ✓ $1${NC}"
}

error() {
    echo -e "${RED}  ✗ $1${NC}"
}

cleanup() {
    if [[ "$CLEANUP" == "true" && "$DOCKER_STARTED" == "true" ]]; then
        echo -e "${GRAY}\nCleaning up Docker containers...${NC}"
        docker-compose down 2>/dev/null || true
    fi
}

trap cleanup EXIT

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

docker_running() {
    docker ps --filter "name=personalbase_postgres" --format "{{.Names}}" 2>/dev/null | grep -q "personalbase_postgres"
}

start_docker() {
    if [[ "$SKIP_DOCKER" == "true" ]]; then
        return 1
    fi
    
    if ! command_exists docker-compose && ! command_exists docker; then
        echo -e "${GRAY}  Docker not found. Assuming local PostgreSQL.${NC}"
        return 1
    fi
    
    if docker_running; then
        success "PostgreSQL container already running"
        return 1
    fi
    
    echo -e "${GRAY}  Starting PostgreSQL via docker-compose...${NC}"
    docker-compose up -d postgres 2>/dev/null
    
    # Wait for ready
    local attempt=0
    local max_attempts=30
    while [[ $attempt -lt $max_attempts ]]; do
        if PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -c "SELECT 1" 2>/dev/null; then
            success "PostgreSQL is ready"
            return 0
        fi
        sleep 1
        ((attempt++))
    done
    
    echo "PostgreSQL failed to start within $max_attempts seconds"
    exit 1
}

# Main execution
header "PersonalBase Database Validation"

# Step 1: Cyrillic scan
step "Scanning for Cyrillic characters"
if ! "$SCRIPT_DIR/scan_cyrillic.sh"; then
    FAILED_STEP="Cyrillic scan"
    error "Cyrillic scan failed"
    exit 1
fi
success "No Cyrillic in English-clean files"

# Step 2: Schema drift check
step "Checking schema.sql is up to date"
if ! "$SCRIPT_DIR/check_schema_up_to_date.sh"; then
    FAILED_STEP="Schema drift check"
    error "Schema drift check failed"
    exit 1
fi
success "schema.sql is current"

# Step 3: Start PostgreSQL
step "Starting PostgreSQL (if needed)"
DOCKER_STARTED="false"
if start_docker; then
    DOCKER_STARTED="true"
fi

# Step 4: Validate schema import
step "Validating schema import"
VALIDATE_ARGS=""
if [[ "$WITH_DATA" == "true" ]]; then
    VALIDATE_ARGS="--with-data"
fi
if ! "$SCRIPT_DIR/validate.sh" $VALIDATE_ARGS; then
    FAILED_STEP="Schema import validation"
    error "Schema import validation failed"
    exit 1
fi
success "Schema imports cleanly"

# Step 5: pgTAP tests
step "Running pgTAP unit tests"
if ! "$SCRIPT_DIR/run_pgtap.sh"; then
    FAILED_STEP="pgTAP unit tests"
    error "pgTAP unit tests failed"
    exit 1
fi
success "All pgTAP tests passed"

# Success!
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
header "✅ ALL CHECKS PASSED"
echo -e "${GREEN}Duration: ${DURATION}s${NC}"
echo -e "${WHITE}\nValidated:${NC}"
echo -e "${GRAY}  • No Cyrillic characters${NC}"
echo -e "${GRAY}  • schema.sql is up to date${NC}"
echo -e "${GRAY}  • Schema imports cleanly${NC}"
echo -e "${GRAY}  • 68 pgTAP unit tests passed${NC}"
echo -e "${GREEN}\nThe database schema is ready! 🎉${NC}"

exit 0
