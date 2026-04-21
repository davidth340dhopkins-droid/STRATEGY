param(
    [Parameter(Mandatory=$true)]
    [string]$Name
)

# 1. Robust Project Root Discovery
# Look upwards for the .initialized sentinel to find the TRUE project root.
$current = $PSScriptRoot
$projectRoot = $null
while ($current) {
    if (Test-Path (Join-Path $current ".initialized")) {
        $projectRoot = $current
        break
    }
    $parent = Split-Path $current -Parent
    if ($parent -eq $current) { break }
    $current = $parent
}

# Fallback to climbing if sentinel is missing (e.g. initial setup)
if ($null -eq $projectRoot) {
    # .nurse/dist/scripts/add-feature.ps1 -> climb 3
    $projectRoot = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
}

$pipelineDir = Join-Path $projectRoot "pipeline"
$featureBaseDir = Join-Path $pipelineDir "feature"
$targetDir = Join-Path $featureBaseDir $Name

if (-not (Test-Path $featureBaseDir)) {
    New-Item -ItemType Directory -Path $featureBaseDir -Force | Out-Null
}

if (Test-Path $targetDir) {
    Write-Error "Feature '$Name' already exists at $targetDir"
    exit 1
}

Write-Host "Sprouting feature: $Name..." -ForegroundColor Cyan

# 2. Create target directory
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

# 3. Copy .nurse/dist and .nurse/init.ps1 (exclude project state)
$featureNurse = New-Item -ItemType Directory -Path (Join-Path $targetDir ".nurse") -Force
$distDir = $PSScriptRoot | Split-Path -Parent
$initScript = Join-Path (Split-Path $distDir -Parent) "init.ps1"

Copy-Item -Path $distDir -Destination $featureNurse -Recurse -Force
Copy-Item -Path $initScript -Destination $featureNurse -Force

# 4. Initialize the feature pipeline
$buildScript = Join-Path $featureNurse "dist/scripts/build-pipeline.ps1"
$runCmdFile = Join-Path (Join-Path $projectRoot ".nurse") ".runcmd"
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

# 5. Initialize VERSION file
$coreVersionFile = Join-Path $pipelineDir "core/merge/VERSION"
$coreVersion = if (Test-Path $coreVersionFile) { (Get-Content $coreVersionFile -Raw).Trim() } else { "0.1.0" }
$featureVersion = "$coreVersion-$Name.0"

Set-Content -Path (Join-Path $targetDir "VERSION") -Value $featureVersion -Encoding UTF8

Write-Host "Feature '$Name' (v$featureVersion) is now active." -ForegroundColor Green
