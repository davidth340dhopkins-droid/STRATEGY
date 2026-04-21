# .nurse/scripts/test-promote.ps1
# Simple utility to increment the version of the primary development workspace.

$nurseryDir = $PSScriptRoot | Split-Path -Parent
$sproutDir  = $nurseryDir   | Split-Path -Parent
$isFeature  = $nurseryDir -match "features"

# The "first" environment where development happens
$targetDir  = if ($isFeature) { "dev" } else { "core/merge" }
$versionFile = Join-Path $sproutDir (Join-Path $targetDir "VERSION")

if (-not (Test-Path $versionFile)) {
    # If dev doesn't exist yet, try finding any stage VERSION or use the root one
    $versionFile = Join-Path $sproutDir "VERSION"
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
