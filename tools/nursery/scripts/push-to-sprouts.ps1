param(
    [Parameter(Mandatory=$false)]
    [string]$SproutName = "all"
)

$nurseryScriptsDir = $PSScriptRoot
$strategyRoot = $nurseryScriptsDir | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
$sproutsRoot = Join-Path $strategyRoot "entities\sprouts"
$masterDistDir = Join-Path $nurseryScriptsDir "..\package\.nurse\dist"

if (-not (Test-Path $masterDistDir)) {
    Write-Error "Master dist folder not found: $masterDistDir"
    exit 1
}

$targets = @()
if ($SproutName -eq "all") {
    $targets = Get-ChildItem $sproutsRoot -Directory
} else {
    $path = Join-Path $sproutsRoot $SproutName
    if (Test-Path $path) {
        $targets = @(Get-Item $path)
    } else {
        Write-Error "Sprout '$SproutName' not found."
        exit 1
    }
}

foreach ($target in $targets) {
    $targetName = $target.Name
    $targetDist = Join-Path $target.FullName ".nurse\dist"
    
    if (Test-Path $targetDist) {
        Write-Host "Pushing template updates to '$targetName'..." -ForegroundColor Cyan
        Copy-Item -Path $masterDistDir -Destination (Split-Path $targetDist -Parent) -Recurse -Force
        
        # Also ensure init.ps1 is updated and neutralizing sentinel logic is present
        Copy-Item -Path (Join-Path $masterDistDir "..\init.ps1") -Destination (Split-Path $targetDist -Parent) -Force
    } else {
        Write-Host "Skipping '$targetName' (no .nurse/dist found)." -ForegroundColor Gray
    }
}

Write-Host "`nPush complete." -ForegroundColor Green
