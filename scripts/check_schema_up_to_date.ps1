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
    $inSection = $false
    $skipSection = $false
    $inCopyBlock = $false

    foreach ($line in $lines) {
        if ($line -match "^-- Name:.*Type:.*Schema:.*Owner:") {
            $inSection = $true
            $skipSection = $false

            if ($line -match "Type:\s*([^;]+)") {
                $sectionType = $matches[1].Trim()
                if ($sectionType -eq "TABLE DATA" -or $sectionType -eq "SEQUENCE SET") {
                    $skipSection = $true
                }
            }
            continue
        }

        if ($line -match "^COPY ") {
            $inCopyBlock = $true
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
            continue
        }

        if ($line -match "^INSERT INTO|^SELECT pg_catalog\.setval") {
            continue
        }

        [void]$output.Add($line)
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    $outputText = $output -join "`n"
    [System.IO.File]::WriteAllText($tempFile, $outputText, $utf8NoBom)
    
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
    
    # Match the Bash checker: ignore whitespace-only differences.
    $generatedNormalized = [regex]::Replace($generatedContent, "\s+", "")
    $committedNormalized = [regex]::Replace($committedContent, "\s+", "")

    if ($generatedNormalized -ne $committedNormalized) {
        Write-Host ""
        Write-Host "[CHECK FAILED] $ExpectedFile is out of date!" -ForegroundColor Red
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
