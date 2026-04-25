#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates schema.sql from "Personal base.sql" by stripping data sections.
.DESCRIPTION
    Uses proper section-based parsing to preserve DDL order:
    - Parses pg_dump sections using header pattern: -- Name: X; Type: Y; Schema: Z; Owner: W
    - Skips only TABLE DATA and SEQUENCE SET sections
    - Skips INSERT INTO statements
    - Skips SELECT pg_catalog.setval(...) lines
    - Skips COPY data blocks
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
$inSection = $false
$skipSection = $false
$inCopyBlock = $false
$dataSectionsRemoved = 0
$insertsRemoved = 0
$setvalsRemoved = 0
$copyBlocksRemoved = 0

for ($i = 0; $i -lt $totalLines; $i++) {
    $line = $lines[$i]
    
    # Detect section headers: -- Name: X; Type: Y; Schema: Z; Owner: W
    if ($line -match "^-- Name:.*Type:.*Schema:.*Owner:") {
        $inSection = $true
        $skipSection = $false
        
        # Extract Type from header
        if ($line -match "Type:\s*([^;]+)") {
            $sectionType = $matches[1].Trim()
            # Skip only TABLE DATA and SEQUENCE SET sections
            if ($sectionType -eq "TABLE DATA" -or $sectionType -eq "SEQUENCE SET") {
                $skipSection = $true
                $dataSectionsRemoved++
            }
        }
        continue
    }
    
    # Track COPY blocks (data loading)
    if ($line -match "^COPY ") {
        $inCopyBlock = $true
        $copyBlocksRemoved++
        continue
    }
    if ($inCopyBlock -and $line -match "^\\\.$") {
        $inCopyBlock = $false
        continue
    }
    if ($inCopyBlock) { continue }
    
    # End of section marker
    if ($inSection -and $line -match "^---$") {
        $inSection = $false
        $skipSection = $false
    }
    
    # Skip lines in data sections
    if ($skipSection) {
        if ($line -match "^INSERT INTO") { $insertsRemoved++ }
        if ($line -match "^SELECT pg_catalog\.setval") { $setvalsRemoved++ }
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
Write-Host "COPY blocks removed: $copyBlocksRemoved" -ForegroundColor Yellow

# Verify no Cyrillic in output
$cyrillic = Select-String -Path $OutputFile -Pattern '[\u0400-\u04FF]'
if ($cyrillic) {
    Write-Warning "Warning: Cyrillic characters found in output!"
} else {
    Write-Host "Verification: No Cyrillic characters in output" -ForegroundColor Green
}

exit 0
