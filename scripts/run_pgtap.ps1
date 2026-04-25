#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runs pgTAP unit tests against the database.
.DESCRIPTION
    1. Ensures pgTAP extension is available
    2. Runs all test files in tests/pgtap/
    3. Reports test results
.NOTES
    Requires: psql, pg_prove (optional but preferred)
    Exit codes: 0 = all tests passed, 1 = any test failed
#>

[CmdletBinding()]
param(
    [string]$DbName = "personalbase_ci",
    [string]$DbUser = "postgres",
    [string]$DbPassword = "postgres",
    [string]$DbHost = "localhost",
    [int]$DbPort = 5432,
    [string]$TestDir = "tests/pgtap"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
    Write-Host "`n[STEP] $msg" -ForegroundColor Cyan
}

function Write-Pass($msg) {
    Write-Host "  [PASS] $msg" -ForegroundColor Green
}

function Write-Fail($msg) {
    Write-Host "  [FAIL] $msg" -ForegroundColor Red
}

function Invoke-Psql($query, $database = $DbName) {
    $env:PGPASSWORD = $DbPassword
    $result = psql -h $DbHost -p $DbPort -U $DbUser -d $database -t -c $query 2>&1
    $env:PGPASSWORD = $null
    return $result
}

function Test-PgTapExtension {
    Write-Step "Checking pgTAP extension..."
    $result = Invoke-Psql "SELECT 1 FROM pg_extension WHERE extname = 'pgtap';"
    if ($result -match "1") {
        Write-Pass "pgTAP extension is installed"
    } else {
        Write-Step "Installing pgTAP extension..."
        $env:PGPASSWORD = $DbPassword
        psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -c "CREATE EXTENSION IF NOT EXISTS pgtap;" 2>&1 | Out-Null
        $env:PGPASSWORD = $null
        $result = Invoke-Psql "SELECT 1 FROM pg_extension WHERE extname = 'pgtap';"
        if ($result -match "1") {
            Write-Pass "pgTAP extension installed successfully"
        } else {
            Write-Fail "Failed to install pgTAP extension"
            exit 1
        }
    }
}

function Test-PgProve {
    $cmd = Get-Command "pg_prove" -ErrorAction SilentlyContinue
    return $null -ne $cmd
}

function Run-TestsWithPgProve {
    Write-Step "Running pgTAP tests with pg_prove..."
    $env:PGPASSWORD = $DbPassword
    $env:PGHOST = $DbHost
    $env:PGPORT = $DbPort
    $env:PGUSER = $DbUser
    $env:PGDATABASE = $DbName
    
    & pg_prove -d $DbName "$TestDir/*.pg" 2>&1
    $exitCode = $LASTEXITCODE
    
    $env:PGPASSWORD = $null
    
    return $exitCode
}

function Run-TestsWithPsql {
    Write-Step "Running pgTAP tests with psql (fallback)..."
    
    $testFiles = Get-ChildItem -Path $TestDir -Filter "*.pg" | Sort-Object Name
    $totalTests = 0
    $passedTests = 0
    $failedTests = 0
    
    foreach ($testFile in $testFiles) {
        Write-Host "`n  Running: $($testFile.Name)" -ForegroundColor Yellow
        $env:PGPASSWORD = $DbPassword
        $output = psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -f $testFile.FullName 2>&1
        $env:PGPASSWORD = $null
        
        # Parse TAP output
        foreach ($line in $output) {
            if ($line -match "^ok\s+\d+") {
                $passedTests++
                $totalTests++
            }
            elseif ($line -match "^not ok\s+\d+") {
                $failedTests++
                $totalTests++
                Write-Fail "Test failed in $($testFile.Name): $line"
            }
            elseif ($line -match "^1\.\.(\d+)") {
                Write-Host "    Planned tests: $($matches[1])" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host "`n=== pgTAP Results ===" -ForegroundColor White
    Write-Host "Total: $totalTests, Passed: $passedTests, Failed: $failedTests" -ForegroundColor White
    
    if ($failedTests -gt 0) {
        return 1
    }
    return 0
}

# Main execution
Write-Host "=== pgTAP Unit Tests ===" -ForegroundColor White
Write-Host "Database: $DbName on $DbHost:$DbPort"
Write-Host "Test directory: $TestDir"

# Check test directory exists
if (-not (Test-Path $TestDir)) {
    Write-Fail "Test directory not found: $TestDir"
    exit 1
}

# Check database connection
Write-Step "Testing database connection..."
$test = Invoke-Psql "SELECT 1;" "postgres"
if ($test -match "1") {
    Write-Pass "Database connection OK"
} else {
    Write-Fail "Cannot connect to database"
    exit 1
}

# Ensure pgTAP is available
Test-PgTapExtension

# Run tests
if (Test-PgProve) {
    Write-Host "`n(pg_prove available - using for better output)" -ForegroundColor Gray
    $exitCode = Run-TestsWithPgProve
} else {
    Write-Host "`n(pg_prove not found - using psql fallback)" -ForegroundColor Yellow
    $exitCode = Run-TestsWithPsql
}

if ($exitCode -eq 0) {
    Write-Host "`n[pgTAP TESTS PASSED]" -ForegroundColor Green
} else {
    Write-Host "`n[pgTAP TESTS FAILED]" -ForegroundColor Red
}

exit $exitCode
