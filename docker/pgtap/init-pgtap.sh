#!/bin/sh
# Initialize pgTAP extension in template1 so all new databases have it available

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname template1 <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS pgtap;
    COMMENT ON EXTENSION pgtap IS 'Unit testing framework for PostgreSQL';
EOSQL

echo "pgTAP extension installed in template1"
