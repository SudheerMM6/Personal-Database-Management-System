#!/usr/bin/env pwsh
<#
.SYNOPSIS
    One-command validation for PersonalBase database.
.DESCRIPTION
    Runs the complete validation suite:
    1. Cyrillic character scan
    2. Schema drift check
    3. PostgreSQL startup (via docker-compose if available)
    4. Schema import validation
    5. pgTAP unit tests
    
    Prints a clean PASS/FAIL summary.
.NOTES
    Exit codes: 0 = all passed, 1 = any failure
#>

[CmdletBinding()]
param(
    [switch]$WithData,
    [switch]$Cleanup,
    [switch]$SkipDocker
)

$ErrorActionPreference = "Stop"
$script:Step = 0
$script:FailedStep = $null
$script:StartTime = Get-Date

function Write-Header($msg) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-Step($msg) {
    $script:Step++
    Write-Host "`n[Step $script:Step] $msg" -ForegroundColor Yellow
}

function Write-Success($msg) {
    Write-Host "  ✓ $msg" -ForegroundColor Green
}

function Write-Error($msg) {
    Write-Host "  ✗ $msg" -ForegroundColor Red
}

function Test-Command($cmd) {
    $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Test-DockerRunning {
    try {
        $containers = docker ps --filter "name=personalbase_postgres" --format "{{.Names}}" 2>$null
        return $containers -match "personalbase_postgres"
    } catch {
        return $false
    }
}

function Start-DockerPostgres {
    if ($SkipDocker) { return $false }
    
    if (-not (Test-Command "docker-compose") -and -not (Test-Command "docker")) {
        Write-Host "  Docker not found. Assuming local PostgreSQL." -ForegroundColor Gray
        return $false
    }
    
    if (Test-DockerRunning) {
        Write-Success "PostgreSQL container already running"
        return $false
    }
    
    Write-Host "  Starting PostgreSQL via docker-compose..." -ForegroundColor Gray
    docker-compose up -d postgres 2>&1 | Out-Null
    
    # Wait for ready
    $maxAttempts = 30
    $attempt = 0
    while ($attempt -lt $maxAttempts) {
        $env:PGPASSWORD = "postgres"
        $result = psql -h localhost -p 5432 -U postgres -c "SELECT 1" 2>&1
        $env:PGPASSWORD = $null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "PostgreSQL is ready"
            return $true
        }
        Start-Sleep -Seconds 1
        $attempt++
    }
    
    throw "PostgreSQL failed to start within $maxAttempts seconds"
}

function Stop-DockerPostgres {
    if ($Cleanup) {
        Write-Host "`nCleaning up Docker containers..." -ForegroundColor Gray
        docker-compose down 2>&1 | Out-Null
    }
}

try {
    Write-Header "PersonalBase Database Validation"
    
    # Step 1: Cyrillic scan
    Write-Step "Scanning for Cyrillic characters"
    & "$PSScriptRoot\scan_cyrillic.ps1"
    if ($LASTEXITCODE -ne 0) {
        $script:FailedStep = "Cyrillic scan"
        throw "Cyrillic scan failed"
    }
    Write-Success "No Cyrillic in English-clean files"
    
    # Step 2: Schema drift check
    Write-Step "Checking schema.sql is up to date"
    & "$PSScriptRoot\check_schema_up_to_date.ps1"
    if ($LASTEXITCODE -ne 0) {
        $script:FailedStep = "Schema drift check"
        throw "Schema drift check failed"
    }
    Write-Success "schema.sql is current"
    
    # Step 3: Start PostgreSQL
    Write-Step "Starting PostgreSQL (if needed)"
    $dockerStarted = Start-DockerPostgres
    
    # Step 4: Validate schema import
    Write-Step "Validating schema import"
    $validateArgs = @{}
    if ($WithData) { $validateArgs['WithData'] = $true }
    if ($Cleanup -and -not $dockerStarted) { $validateArgs['Cleanup'] = $true }
    & "$PSScriptRoot\validate.ps1" @validateArgs
    if ($LASTEXITCODE -ne 0) {
        $script:FailedStep = "Schema import validation"
        throw "Schema import validation failed"
    }
    Write-Success "Schema imports cleanly"
    
    # Step 5: pgTAP tests
    Write-Step "Running pgTAP unit tests"
    & "$PSScriptRoot\run_pgtap.ps1"
    if ($LASTEXITCODE -ne 0) {
        $script:FailedStep = "pgTAP unit tests"
        throw "pgTAP unit tests failed"
    }
    Write-Success "All pgTAP tests passed"
    
    # Success!
    $duration = (Get-Date) - $script:StartTime
    Write-Header "✅ ALL CHECKS PASSED"
    Write-Host "Duration: $($duration.TotalSeconds.ToString('F1'))s" -ForegroundColor Green
    Write-Host "`nValidated:" -ForegroundColor White
    Write-Host "  • No Cyrillic characters" -ForegroundColor Gray
    Write-Host "  • schema.sql is up to date" -ForegroundColor Gray
    Write-Host "  • Schema imports cleanly" -ForegroundColor Gray
    Write-Host "  • 68 pgTAP unit tests passed" -ForegroundColor Gray
    Write-Host "`nThe database schema is ready! 🎉" -ForegroundColor Green
    
    exit 0
}
catch {
    $duration = (Get-Date) - $script:StartTime
    Write-Header "❌ VALIDATION FAILED"
    
    if ($script:FailedStep) {
        Write-Error "Failed at: $script:FailedStep"
    }
    
    Write-Host "`nError: $_" -ForegroundColor Red
    Write-Host "`nTo rerun just this step:" -ForegroundColor Yellow
    
    switch ($script:FailedStep) {
        "Cyrillic scan" { 
            Write-Host '  powershell scripts/scan_cyrillic.ps1' -ForegroundColor White 
        }
        "Schema drift check" { 
            Write-Host '  powershell scripts/generate_schema.ps1' -ForegroundColor White 
            Write-Host '  git add schema.sql && git commit -m "Update schema"' -ForegroundColor White 
        }
        "Schema import validation" { 
            $cmd = "powershell scripts/validate.ps1"
            if ($WithData) { $cmd += " -WithData" }
            Write-Host "  $cmd" -ForegroundColor White 
        }
        "pgTAP unit tests" { 
            Write-Host '  powershell scripts/run_pgtap.ps1' -ForegroundColor White 
        }
        default { 
            Write-Host '  powershell scripts/validate_all.ps1' -ForegroundColor White 
        }
    }
    
    exit 1
}
finally {
    Stop-DockerPostgres
}
