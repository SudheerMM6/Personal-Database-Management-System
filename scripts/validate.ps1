#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates that schema.sql imports cleanly into PostgreSQL.
.DESCRIPTION
    1. Starts PostgreSQL via docker-compose (if available)
    2. Creates temporary database
    3. Imports schema.sql with ON_ERROR_STOP=on (English-clean default)
    4. Runs schema smoke tests
    5. Reports PASS/FAIL
    
    Use -WithData to validate the original dump with sample data.
.NOTES
    Requires: psql, docker-compose (optional)
    Exit codes: 0 = PASS, 1 = FAIL
#>

[CmdletBinding()]
param(
    [string]$SqlFile = "schema.sql",
    [string]$DbName = "personalbase_ci",
    [string]$DbUser = "postgres",
    [string]$DbPassword = "postgres",
    [string]$DbHost = "localhost",
    [int]$DbPort = 5432,
    [switch]$SkipDocker,
    [switch]$Cleanup,
    [switch]$WithData
)

# If -WithData specified, use the original full dump
if ($WithData) {
    $SqlFile = "Personal base.sql"
}

$ErrorActionPreference = "Stop"
$script:DockerStarted = $false
$script:Passed = 0
$script:Failed = 0

function Write-Step($msg) {
    Write-Host "`n[STEP] $msg" -ForegroundColor Cyan
}

function Write-Pass($msg) {
    Write-Host "  [PASS] $msg" -ForegroundColor Green
    $script:Passed++
}

function Write-Fail($msg) {
    Write-Host "  [FAIL] $msg" -ForegroundColor Red
    $script:Failed++
}

function Test-Command($cmd) {
    $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Invoke-Psql($query, $database = $DbName) {
    $env:PGPASSWORD = $DbPassword
    $result = psql -h $DbHost -p $DbPort -U $DbUser -d $database -t -c $query 2>&1
    $env:PGPASSWORD = $null
    return $result
}

function Start-DockerPostgres {
    if ($SkipDocker) { return }
    
    Write-Step "Checking for docker-compose..."
    if (-not (Test-Command "docker-compose") -and -not (Test-Command "docker")) {
        Write-Host "  Docker not found. Assuming local PostgreSQL." -ForegroundColor Yellow
        return
    }
    
    Write-Step "Starting PostgreSQL via docker-compose..."
    try {
        docker-compose up -d postgres 2>&1 | Out-Null
        $script:DockerStarted = $true
        
        # Wait for Postgres to be ready
        Write-Host "  Waiting for PostgreSQL to be ready..."
        $maxAttempts = 30
        $attempt = 0
        while ($attempt -lt $maxAttempts) {
            $env:PGPASSWORD = $DbPassword
            $result = psql -h $DbHost -p $DbPort -U $DbUser -d postgres -c "SELECT 1" 2>&1
            $env:PGPASSWORD = $null
            if ($LASTEXITCODE -eq 0) {
                Write-Pass "PostgreSQL is ready"
                return
            }
            Start-Sleep -Seconds 1
            $attempt++
        }
        throw "PostgreSQL failed to start within $maxAttempts seconds"
    }
    catch {
        Write-Fail "Failed to start Docker PostgreSQL: $_"
        exit 1
    }
}

function Stop-DockerPostgres {
    if ($script:DockerStarted -and $Cleanup) {
        Write-Step "Stopping Docker containers..."
        docker-compose down 2>&1 | Out-Null
    }
}

function Test-DatabaseConnection {
    Write-Step "Testing database connection..."
    try {
        $result = Invoke-Psql "SELECT version();" "postgres"
        if ($result -match "PostgreSQL") {
            Write-Pass "Connected to PostgreSQL"
        } else {
            Write-Fail "Could not connect to PostgreSQL"
            exit 1
        }
    }
    catch {
        Write-Fail "Database connection failed: $_"
        exit 1
    }
}

function Initialize-TestDatabase {
    Write-Step "Creating test database '$DbName'..."
    Invoke-Psql "DROP DATABASE IF EXISTS $DbName;" "postgres" | Out-Null
    Invoke-Psql "CREATE DATABASE $DbName;" "postgres" | Out-Null
    $result = Invoke-Psql "SELECT datname FROM pg_database WHERE datname = '$DbName';" "postgres"
    if ($result -match $DbName) {
        Write-Pass "Test database created"
    } else {
        Write-Fail "Failed to create test database"
        exit 1
    }
}

function Import-SqlDump {
    Write-Step "Importing SQL dump (with ON_ERROR_STOP=on)..."
    
    if (-not (Test-Path $SqlFile)) {
        Write-Fail "SQL file not found: $SqlFile"
        exit 1
    }
    
    $env:PGPASSWORD = $DbPassword
    $env:ON_ERROR_STOP = "on"
    
    # Import with strict error handling
    psql --set ON_ERROR_STOP=on --single-transaction `
         -h $DbHost -p $DbPort -U $DbUser -d $DbName `
         -f "$SqlFile" 2>&1
    
    $exitCode = $LASTEXITCODE
    $env:PGPASSWORD = $null
    $env:ON_ERROR_STOP = $null
    
    if ($exitCode -eq 0) {
        Write-Pass "SQL dump imported successfully"
    } else {
        Write-Fail "SQL import failed with exit code $exitCode"
        exit 1
    }
}

function Invoke-SmokeTests {
    Write-Step "Running schema smoke tests..."
    
    $testFile = Join-Path $PSScriptRoot "schema_smoke_tests.sql"
    if (-not (Test-Path $testFile)) {
        Write-Fail "Smoke test file not found: $testFile"
        return
    }
    
    $env:PGPASSWORD = $DbPassword
    $output = psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -f "$testFile" 2>&1
    $env:PGPASSWORD = $null
    
    # Parse test results
    $lines = $output -split "`n"
    foreach ($line in $lines) {
        if ($line -match "^\s*\[PASS\]") {
            Write-Pass ($line -replace "^\s*\[PASS\]\s*", "")
        }
        elseif ($line -match "^\s*\[FAIL\]") {
            Write-Fail ($line -replace "^\s*\[FAIL\]\s*", "")
        }
    }
}

function Test-InvalidObjects {
    Write-Step "Checking for invalid database objects..."
    
    $query = @"
SELECT count(*) 
FROM pg_class c 
JOIN pg_namespace n ON n.oid = c.relnamespace 
WHERE c.relpersistence != 't' 
AND c.relkind IN ('r', 'v', 'm', 'S', 'f') 
AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
AND NOT c.relhasrules 
AND c.relfilenode = 0;
"@
    
    $result = Invoke-Psql $query
    if ($result -match "^\s*0\s*$") {
        Write-Pass "No invalid objects found"
    } else {
        Write-Fail "Found invalid objects: $result"
    }
}

# Main execution
try {
    $sourceType = if ($WithData) { "FULL DUMP (with data)" } else { "SCHEMA ONLY (English-clean)" }
    Write-Host "=== PersonalBase SQL Validation ===" -ForegroundColor White
    Write-Host "Source: $sourceType"
    Write-Host "SQL File: $SqlFile"
    Write-Host "Database: $DbName on $DbHost:$DbPort"
    
    Start-DockerPostgres
    Test-DatabaseConnection
    Initialize-TestDatabase
    Import-SqlDump
    Invoke-SmokeTests
    Test-InvalidObjects
    
    Write-Host "`n=== SUMMARY ===" -ForegroundColor White
    Write-Host "Passed: $script:Passed" -ForegroundColor Green
    Write-Host "Failed: $script:Failed" -ForegroundColor $(if ($script:Failed -gt 0) { "Red" } else { "Green" })
    
    if ($script:Failed -gt 0) {
        exit 1
    }
    
    Write-Host "`n[VALIDATION PASSED]" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "`n[ERROR] $_" -ForegroundColor Red
    exit 1
}
finally {
    Stop-DockerPostgres
}
