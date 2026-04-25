#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates schema.sql from "Personal base.sql" by stripping data sections.
.DESCRIPTION
    Removes all data sections while preserving all DDL:
    - Skips sections marked with "Type: TABLE DATA"
    - Skips sections marked with "Type: SEQUENCE SET"
    - Skips INSERT INTO statements
    - Skips SELECT pg_catalog.setval(...) lines
    - Keeps all CREATE, ALTER, COMMENT ON, and other DDL
    
    Input: "Personal base.sql"
    Output: schema.sql
.NOTES
    Exit codes: 0 = success, 1 = error
#>

[CmdletBinding()]
param(
    [string]$InputFile = "Personal base.sql",
    [string]$OutputFile = "schema.sql"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Generating schema.sql from '$InputFile' ===" -ForegroundColor Cyan

# Check input file exists
if (-not (Test-Path $InputFile)) {
    Write-Error "Input file not found: $InputFile"
    exit 1
}

# Read all lines
$lines = Get-Content $InputFile
$totalLines = $lines.Count
Write-Host "Processing $totalLines lines..." -ForegroundColor Gray

$output = New-Object System.Collections.ArrayList
$inDataSection = $false
$dataSectionsRemoved = 0
$insertsRemoved = 0
$setvalsRemoved = 0

for ($i = 0; $i -lt $totalLines; $i++) {
    $line = $lines[$i]
    
    # Check for data section headers (comment lines indicating data)
    if ($line -match "^--.*Type: TABLE DATA") {
        $inDataSection = $true
        $dataSectionsRemoved++
        continue
    }
    
    if ($line -match "^--.*Type: SEQUENCE SET") {
        $inDataSection = $true
        $dataSectionsRemoved++
        continue
    }
    
    # Check for end of data section (blank line followed by comment or new section)
    if ($inDataSection -and $line -match "^---") {
        $inDataSection = $false
    }
    
    # Skip all lines while in data section
    if ($inDataSection) {
        # Also track what we're skipping for reporting
        if ($line -match "^INSERT INTO") {
            $insertsRemoved++
        }
        if ($line -match "^SELECT pg_catalog\.setval") {
            $setvalsRemoved++
        }
        continue
    }
    
    # Skip standalone INSERT lines (outside data sections)
    if ($line -match "^INSERT INTO") {
        $insertsRemoved++
        continue
    }
    
    # Skip standalone SELECT setval lines (outside data sections)
    if ($line -match "^SELECT pg_catalog\.setval") {
        $setvalsRemoved++
        continue
    }
    
    # Keep everything else (DDL)
    [void]$output.Add($line)
}

# Write output (UTF-8 without BOM)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$outputText = $output -join "`n"
[System.IO.File]::WriteAllText((Resolve-Path $OutputFile).Path, $outputText, $utf8NoBom)

$outputLines = $output.Count
Write-Host ""
Write-Host "=== Generation Complete ===" -ForegroundColor Green
Write-Host "Output: $OutputFile" -ForegroundColor White
Write-Host "Lines: $totalLines → $outputLines" -ForegroundColor White
Write-Host "Data sections removed: $dataSectionsRemoved" -ForegroundColor Yellow
Write-Host "INSERT statements removed: $insertsRemoved" -ForegroundColor Yellow
Write-Host "setval statements removed: $setvalsRemoved" -ForegroundColor Yellow

# Verify no Cyrillic in output
$cyrillic = Select-String -Path $OutputFile -Pattern '[\u0400-\u04FF]'
if ($cyrillic) {
    Write-Warning "Warning: Cyrillic characters found in output!"
} else {
    Write-Host "Verification: No Cyrillic characters in output" -ForegroundColor Green
}

exit 0
