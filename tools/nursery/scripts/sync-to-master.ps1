param(
    [Parameter(Mandatory=$true)]
    [string]$SproutName
)

$nurseryScriptsDir = $PSScriptRoot
$strategyRoot = $nurseryScriptsDir | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
$sproutDir = Join-Path $strategyRoot "entities\sprouts\$SproutName"
$masterDistDir = Join-Path $nurseryScriptsDir "..\package\.nurse\dist"

if (-not (Test-Path $sproutDir)) {
    Write-Error "Sprout '$SproutName' not found at $sproutDir"
    exit 1
}

$sproutDistDir = Join-Path $sproutDir ".nurse\dist"

if (-not (Test-Path $sproutDistDir)) {
    Write-Error "Sprout dist directory not found: $sproutDistDir"
    exit 1
}

Write-Host "Syncing improvements from '$SproutName' back to Master Template..." -ForegroundColor Cyan

# Sync the dist folder
Copy-Item -Path $sproutDistDir -Destination (Split-Path $masterDistDir -Parent) -Recurse -Force

Write-Host "Sync complete. Master package at $masterDistDir is updated." -ForegroundColor Green
