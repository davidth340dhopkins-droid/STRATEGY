param(
    [Parameter(Mandatory=$true)]
    [string]$Name
)

$nurseryDir = $PSScriptRoot | Split-Path -Parent
$nurseRootDir = $nurseryDir | Split-Path -Parent
$rootDir = $nurseRootDir | Split-Path -Parent
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

# 2. Copy .nurse/dist and .nurse/init.ps1 (exclude project state)
$featureNurse = New-Item -ItemType Directory -Path (Join-Path $targetDir ".nurse") -Force
Copy-Item -Path $nurseryDir -Destination $featureNurse -Recurse -Force
Copy-Item -Path (Join-Path $nurseRootDir "init.ps1") -Destination $featureNurse -Force

# 3. Initialize the feature pipeline
$buildScript = Join-Path $featureNurse "dist/scripts/build-pipeline.ps1"
$runCmdFile = Join-Path $nurseRootDir ".runcmd"
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

# 4. Initialize VERSION file
$coreVersionFile = Join-Path $rootDir "core/merge/VERSION"
$coreVersion = if (Test-Path $coreVersionFile) { (Get-Content $coreVersionFile -Raw).Trim() } else { "0.1.0" }
$featureVersion = "$coreVersion-$Name.0"

# Find all environment worktrees created by build-pipeline.ps1 and set their version
# Since build-pipeline hasn't run yet in the new target, we'll let it handle the first VERSION file creation.
# Or better, we set it here in the source so build-pipeline picks it up.
Set-Content -Path (Join-Path $targetDir "VERSION") -Value $featureVersion -Encoding UTF8

Write-Host "Feature '$Name' (v$featureVersion) is now active." -ForegroundColor Green
