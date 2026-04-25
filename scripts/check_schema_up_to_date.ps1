#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Checks if schema.sql is up to date with Personal base.sql.
.DESCRIPTION
    Generates a fresh schema.sql from Personal base.sql and compares it to the committed version.
    Fails with clear error message if they differ.
.NOTES
    Exit codes: 0 = up to date, 1 = out of date
#>

[CmdletBinding()]
param(
    [string]$SourceFile = "Personal base.sql",
    [string]$ExpectedFile = "schema.sql"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Checking if $ExpectedFile is up to date ===" -ForegroundColor Cyan

# Check source file exists
if (-not (Test-Path $SourceFile)) {
    Write-Error "Source file not found: $SourceFile"
    exit 1
}

# Check expected file exists
if (-not (Test-Path $ExpectedFile)) {
    Write-Error "Expected file not found: $ExpectedFile (needs to be generated)"
    exit 1
}

# Generate temp file
$tempFile = [System.IO.Path]::GetTempFileName()

try {
    Write-Host "Generating temporary schema from '$SourceFile'..." -ForegroundColor Gray
    
    # Read and process
    $lines = Get-Content $SourceFile
    $output = New-Object System.Collections.ArrayList
    $inDataSection = $false
    
    foreach ($line in $lines) {
        # Check for data section headers
        if ($line -match "^--.*Type: TABLE DATA") {
            $inDataSection = $true
            continue
        }
        
        if ($line -match "^--.*Type: SEQUENCE SET") {
            $inDataSection = $true
            continue
        }
        
        # Check for end of data section
        if ($inDataSection -and $line -match "^---") {
            $inDataSection = $false
        }
        
        # Skip lines in data section
        if ($inDataSection) {
            continue
        }
        
        # Skip standalone INSERT and setval
        if ($line -match "^INSERT INTO|^SELECT pg_catalog\.setval") {
            continue
        }
        
        # Keep DDL
        [void]$output.Add($line)
    }
    
    $output | Set-Content $tempFile -Encoding UTF8
    
    # Compare files (normalize BOM first)
    Write-Host "Comparing generated vs committed $ExpectedFile..." -ForegroundColor Gray
    
    # Read files and strip BOM if present on first line
    $generatedContent = Get-Content $tempFile -Raw
    $committedContent = Get-Content $ExpectedFile -Raw
    
    # Remove UTF-8 BOM (EF BB BF) from start if present
    if ($generatedContent -match "^\uFEFF") {
        $generatedContent = $generatedContent.Substring(1)
    }
    if ($committedContent -match "^\uFEFF") {
        $committedContent = $committedContent.Substring(1)
    }
    
    # Split into lines for comparison
    $generatedLines = $generatedContent -split "`r?`n" | Where-Object { $_.Trim() -ne '' }
    $committedLines = $committedContent -split "`r?`n" | Where-Object { $_.Trim() -ne '' }
    
    # Use diff if available, otherwise compare hashes
    $diff = Compare-Object $generatedLines $committedLines
    
    if ($diff) {
        Write-Host ""
        Write-Host "[CHECK FAILED] $ExpectedFile is out of date!" -ForegroundColor Red
        Write-Host ""
        Write-Host "The following differences were found:" -ForegroundColor Yellow
        $diff | Select-Object -First 10 | ForEach-Object {
            $indicator = if ($_.SideIndicator -eq "<=") { "(generated)" } else { "(committed)" }
            $color = if ($_.SideIndicator -eq "<=") { "Green" } else { "Red" }
            $line = $_.InputObject
            Write-Host "  $indicator`: $line" -ForegroundColor $color
        }
        Write-Host ""
        Write-Host "To fix this, run:" -ForegroundColor Cyan
        Write-Host '  powershell scripts/generate_schema.ps1' -ForegroundColor White
        Write-Host "Then commit the updated `$ExpectedFile" -ForegroundColor White
        exit 1
    } else {
        Write-Host ""
        Write-Host "[CHECK PASSED] $ExpectedFile is up to date" -ForegroundColor Green
        exit 0
    }
}
finally {
    # Cleanup temp file
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force
    }
}
