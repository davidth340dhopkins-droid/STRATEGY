# .nurse/scripts/test-promote.ps1
# Simple utility to increment the version of the primary development workspace.

# 1. Robust Project Root Discovery
$current = $PSScriptRoot
$projectRoot = $null
while ($current) {
    if (Test-Path (Join-Path $current ".initialized")) { $projectRoot = $current; break }
    $parent = Split-Path $current -Parent
    if ($parent -eq $current) { break }
    $current = $parent
}
if ($null -eq $projectRoot) { $projectRoot = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent }

$localNurseRoot = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
$isFeature  = $localNurseRoot -match "feature"
$localRoot  = $localNurseRoot | Split-Path -Parent

# The "first" environment where development happens
$targetDir  = if ($isFeature) { "dev" } else { "pipeline/core/merge" }
$versionFile = Join-Path $localRoot (Join-Path $targetDir "VERSION")

if (-not (Test-Path $versionFile)) {
    # If dev doesn't exist yet, try finding any stage VERSION or use the root one
    $versionFile = Join-Path $localRoot "VERSION"
}

if (-not (Test-Path $versionFile)) {
    Write-Error "VERSION file not found in sprout root or worktrees."
    exit 1
}

$currentVersion = (Get-Content $versionFile -Raw).Trim()
Write-Host "Current Version: $currentVersion" -ForegroundColor Gray

# Semantic increment logic
if ($currentVersion -match '(?<base>.+)\.(?<patch>\d+)$') {
    $base = $Matches['base']
    $patch = [int]$Matches['patch'] + 1
    $newVersion = "$base.$patch"
} else {
    $newVersion = "$currentVersion.1"
}

Set-Content -Path $versionFile -Value $newVersion -Encoding UTF8

# Commit the version bump so it can be merged during promotion
Push-Location (Split-Path $versionFile -Parent)
try {
    git add VERSION | Out-Null
    git commit -m "chore: bump version to $newVersion" | Out-Null
    git tag "v$newVersion" -f | Out-Null
} finally {
    Pop-Location
}

Write-Host "Incremented and committed: $newVersion" -ForegroundColor Green
