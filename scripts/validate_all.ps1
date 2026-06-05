#!/usr/bin/env pwsh
<#
.SYNOPSIS
    One-command validation for PersonalBase database.
.DESCRIPTION
    Runs the complete validation suite and prints a clean PASS/FAIL summary.
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
    Write-Host "  OK: $msg" -ForegroundColor Green
}

function Write-Error($msg) {
    Write-Host "  FAIL: $msg" -ForegroundColor Red
}

function Test-Command($cmd) {
    $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

try {
    Write-Header "PersonalBase Database Validation"

    Write-Step "Checking schema.sql is up to date"
    & "$PSScriptRoot\check_schema_up_to_date.ps1"
    if ($LASTEXITCODE -ne 0) {
        $script:FailedStep = "Schema drift check"
        throw "Schema drift check failed"
    }
    Write-Success "schema.sql is current"

    Write-Step "Validating schema import and smoke tests"
    $validateArgs = @{}
    if ($WithData) { $validateArgs["WithData"] = $true }
    if ($SkipDocker) { $validateArgs["SkipDocker"] = $true }
    & "$PSScriptRoot\validate.ps1" @validateArgs
    if ($LASTEXITCODE -ne 0) {
        $script:FailedStep = "Schema import validation"
        throw "Schema import validation failed"
    }
    Write-Success "Schema import and smoke tests passed"

    Write-Step "Running pgTAP unit tests"
    & "$PSScriptRoot\run_pgtap.ps1"
    if ($LASTEXITCODE -ne 0) {
        $script:FailedStep = "pgTAP unit tests"
        throw "pgTAP unit tests failed"
    }
    Write-Success "pgTAP tests passed"

    $duration = (Get-Date) - $script:StartTime
    Write-Header "ALL CHECKS PASSED"
    Write-Host "Duration: $($duration.TotalSeconds.ToString('F1'))s" -ForegroundColor Green
    exit 0
}
catch {
    Write-Header "VALIDATION FAILED"
    Write-Error "Failed at: $script:FailedStep"
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
finally {
    if ($Cleanup -and -not $SkipDocker -and (Test-Command "docker-compose")) {
        docker-compose down 2>$null | Out-Null
    }
}
