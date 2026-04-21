param(
    [Parameter(Mandatory=$false)]
    [string]$SproutName
)

$scriptsDir = $PSScriptRoot

# Detection Logic: Are we running from within a sprout or from the Nursery root?
$isInsideSprout = $scriptsDir.Contains("entities\sprouts")
$strategyRoot = $null
$masterDistDir = $null

if ($isInsideSprout) {
    # Inside: entities\sprouts\<name>\.nurse\dist\scripts
    $strategyRoot = $scriptsDir | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
    $masterDistDir = Join-Path $strategyRoot "tools\nursery\package\.nurse\dist"
    if ([string]::IsNullOrWhiteSpace($SproutName)) {
        # entities\sprouts\<name>
        $SproutName = ($scriptsDir | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent | Split-Path -Leaf)
    }
} else {
    # Nursery Root Path: tools\nursery\package\.nurse\dist\scripts
    $strategyRoot = $scriptsDir | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
    $masterDistDir = Split-Path $scriptsDir -Parent
    if ([string]::IsNullOrWhiteSpace($SproutName)) {
        Write-Error "Running from Nursery root: You must provide a -SproutName."
        exit 1
    }
}

$sproutDir = Join-Path $strategyRoot "entities\sprouts\$SproutName"
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
Write-Host "Source: $sproutDistDir" -ForegroundColor Gray
Write-Host "Target: $masterDistDir" -ForegroundColor Gray

# Sync the dist folder and the init.ps1 sibling
Copy-Item -Path $sproutDistDir -Destination (Split-Path $masterDistDir -Parent) -Recurse -Force
Copy-Item -Path (Join-Path $sproutDistDir "..\init.ps1") -Destination (Split-Path $masterDistDir -Parent) -Force

Write-Host "Sync complete. Master package at $masterDistDir is updated." -ForegroundColor Green
