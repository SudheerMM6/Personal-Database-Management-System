#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates schema.sql from "Personal base.sql" by stripping data sections.
.DESCRIPTION
    Preserves DDL order while removing TABLE DATA, SEQUENCE SET, INSERT, setval,
    and COPY data blocks.
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

if (-not (Test-Path $InputFile)) {
    Write-Error "Input file not found: $InputFile"
    exit 1
}

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

    if ($line -match "^-- Name:.*Type:.*Schema:.*Owner:") {
        $inSection = $true
        $skipSection = $false

        if ($line -match "Type:\s*([^;]+)") {
            $sectionType = $matches[1].Trim()
            if ($sectionType -eq "TABLE DATA" -or $sectionType -eq "SEQUENCE SET") {
                $skipSection = $true
                $dataSectionsRemoved++
            }
        }
        continue
    }

    if ($line -match "^COPY ") {
        $inCopyBlock = $true
        $copyBlocksRemoved++
        continue
    }

    if ($inCopyBlock -and $line -match "^\\\.$") {
        $inCopyBlock = $false
        continue
    }

    if ($inCopyBlock) {
        continue
    }

    if ($inSection -and $line -match "^---$") {
        $inSection = $false
        $skipSection = $false
    }

    if ($skipSection) {
        if ($line -match "^INSERT INTO") { $insertsRemoved++ }
        if ($line -match "^SELECT pg_catalog\.setval") { $setvalsRemoved++ }
        continue
    }

    if ($line -match "^INSERT INTO") {
        $insertsRemoved++
        continue
    }

    if ($line -match "^SELECT pg_catalog\.setval") {
        $setvalsRemoved++
        continue
    }

    [void]$output.Add($line)
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$outputText = $output -join "`n"
[System.IO.File]::WriteAllText((Resolve-Path $OutputFile).Path, $outputText, $utf8NoBom)

$outputLines = $output.Count
Write-Host ""
Write-Host "=== Generation Complete ===" -ForegroundColor Green
Write-Host "Output: $OutputFile" -ForegroundColor White
Write-Host "Lines: $totalLines -> $outputLines" -ForegroundColor White
Write-Host "Data sections removed: $dataSectionsRemoved" -ForegroundColor Yellow
Write-Host "INSERT statements removed: $insertsRemoved" -ForegroundColor Yellow
Write-Host "setval statements removed: $setvalsRemoved" -ForegroundColor Yellow
Write-Host "COPY blocks removed: $copyBlocksRemoved" -ForegroundColor Yellow

$cyrillic = Select-String -Path $OutputFile -Pattern '[\u0400-\u04FF]'
if ($cyrillic) {
    Write-Warning "Warning: Cyrillic characters found in output."
} else {
    Write-Host "Verification: No Cyrillic characters in output" -ForegroundColor Green
}

exit 0
