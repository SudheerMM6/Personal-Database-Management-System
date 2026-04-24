#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Scans repository files for Cyrillic characters.
.DESCRIPTION
    Fails (exit 1) if Cyrillic is found in:
    - README.md
    - docs/**
    - scripts/**
    - schema.sql
    - CI workflow files
    
    Allows Cyrillic in the original dump file only.
.NOTES
    Exit codes: 0 = PASS (no Cyrillic), 1 = FAIL (Cyrillic found)
#>

[CmdletBinding()]
param(
    [switch]$Fix
)

$ErrorActionPreference = "Stop"
$FoundCyrillic = $false

$FilesToScan = @(
    "README.md"
    "schema.sql"
)

$DirsToScan = @(
    "docs"
    "scripts"
    ".github/workflows"
)

function Test-CyrillicInFile($filePath) {
    $content = Get-Content $filePath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { return @() }
    
    $matches = [regex]::Matches($content, '[\u0400-\u04FF]+')
    return $matches
}

Write-Host "=== Cyrillic Character Scan ===" -ForegroundColor Cyan
Write-Host ""

$AllFiles = @()

# Collect specific files
foreach ($file in $FilesToScan) {
    if (Test-Path $file) {
        $AllFiles += $file
    }
}

# Collect files from directories
foreach ($dir in $DirsToScan) {
    if (Test-Path $dir) {
        $files = Get-ChildItem -Path $dir -File -Recurse | Where-Object { 
            $_.Extension -notin @('.png','.jpg','.jpeg','.gif','.ico','.pdf') 
        } | Select-Object -ExpandProperty FullName
        $AllFiles += $files
    }
}

$ScannedCount = 0
$CyrillicFiles = @()

foreach ($file in $AllFiles) {
    $relativePath = $file -replace "^$([regex]::Escape($PWD.Path))\\", ""
    $ScannedCount++
    
    $matches = Test-CyrillicInFile $file
    if ($matches.Count -gt 0) {
        $FoundCyrillic = $true
        $CyrillicFiles += $relativePath
        
        Write-Host "[FAIL] $relativePath" -ForegroundColor Red
        $lines = Get-Content $file
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $cyrillicMatches = [regex]::Matches($lines[$i], '[\u0400-\u04FF]+')
            if ($cyrillicMatches.Count -gt 0) {
                $foundText = ($cyrillicMatches | ForEach-Object { $_.Value }) -join ", "
                Write-Host "  Line $($i+1): $foundText" -ForegroundColor Red
            }
        }
    }
}

Write-Host ""
Write-Host "Scanned $ScannedCount files" -ForegroundColor White

if ($FoundCyrillic) {
    Write-Host ""
    Write-Host "[SCAN FAILED] Cyrillic characters found in:" -ForegroundColor Red
    foreach ($file in $CyrillicFiles) {
        Write-Host "  - $file" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Note: Cyrillic is allowed only in 'Personal base.sql' (original dump file)" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host ""
    Write-Host "[SCAN PASSED] No Cyrillic characters found in English-clean files" -ForegroundColor Green
    Write-Host ""
    Write-Host "All files are English-only (schema.sql, docs, scripts, README)" -ForegroundColor Green
    exit 0
}
