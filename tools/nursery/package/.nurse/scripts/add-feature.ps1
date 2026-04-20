param(
    [Parameter(Mandatory=$true)]
    [string]$Name
)

$rootDir = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
$featuresDir = Join-Path $rootDir "features"
$targetDir = Join-Path $featuresDir $Name

if (-not (Test-Path $featuresDir)) {
    New-Item -ItemType Directory -Path $featuresDir -Force | Out-Null
}

if (Test-Path $targetDir) {
    Write-Error "Feature '$Name' already exists at $targetDir"
    exit 1
}

Write-Host "Sprouting feature: $Name..." -ForegroundColor Cyan

# 1. Create target directory
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

# 2. Copy .nurse package into the feature directory
$nurseryBaseDir = Join-Path $PSScriptRoot ".."
Copy-Item -Path $nurseryBaseDir -Destination $targetDir -Recurse -Force

# 3. Initialize the feature pipeline
$nurseryDir = Join-Path $targetDir ".nurse"
$buildScript = Join-Path $nurseryDir "scripts/build-pipeline.ps1"
$runCmdFile = Join-Path ($PSScriptRoot | Split-Path -Parent) ".runcmd"
$runCommand = Get-Content $runCmdFile -Raw

if (Test-Path $buildScript) {
    Write-Host "Running build-pipeline for feature '$Name'..." -ForegroundColor Cyan
    Push-Location $targetDir
    try {
        & $buildScript -RunCommand $runCommand
    } finally {
        Pop-Location
    }
}

Write-Host "Feature '$Name' is now active." -ForegroundColor Green
