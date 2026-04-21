param(
    [Parameter(Mandatory=$true)]
    [string]$Name
)

$current = $PSScriptRoot
$projectRoot = $null
while ($current) {
    if (Test-Path (Join-Path $current ".initialized")) { $projectRoot = $current; break }
    $parent = Split-Path $current -Parent
    if ($parent -eq $current) { break }
    $current = $parent
}
if ($null -eq $projectRoot) { $projectRoot = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent }

$pipelineDir = Join-Path $projectRoot "pipeline"
$featureBaseDir = Join-Path $pipelineDir "feature"
$targetDir = Join-Path $featureBaseDir $Name

if (-not (Test-Path $featureBaseDir)) { New-Item -ItemType Directory -Path $featureBaseDir -Force | Out-Null }
if (Test-Path $targetDir) { Write-Error "Feature '$Name' already exists at $targetDir"; exit 1 }

Write-Host "Sprouting feature: $Name..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

$buildScript = Join-Path $projectRoot ".nurse/dist/scripts/build-pipeline.ps1"
$runCmdFile = Join-Path $projectRoot ".nurse/.runcmd"
$runCommand = Get-Content $runCmdFile -Raw

if (Test-Path $buildScript) {
    Write-Host "Running build-pipeline for feature '$Name'..." -ForegroundColor Cyan
    pwsh -File $buildScript -Target "feature/$Name" -RunCommand $runCommand
}

$coreVersionFile = Join-Path $pipelineDir "core/merge/VERSION"
$coreVersion = if (Test-Path $coreVersionFile) { (Get-Content $coreVersionFile -Raw).Trim() } else { "0.1.0" }
$featureVersion = "$coreVersion-$Name.0"

Set-Content -Path (Join-Path $targetDir "VERSION") -Value $featureVersion -Encoding UTF8

Write-Host "Feature '$Name' (v$featureVersion) is now active." -ForegroundColor Green
