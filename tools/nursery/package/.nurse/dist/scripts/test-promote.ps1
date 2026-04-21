param(
    [Parameter(Mandatory=$false)]
    [string]$Target = "core"
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

$isFeature = ($Target -ne "core")
if ($isFeature) {
    $featureName = $Target -replace "^feature/", ""
    $localRoot = Join-Path (Join-Path (Join-Path $projectRoot "pipeline") "feature") $featureName
    $targetDir = "dev"
} else {
    $localRoot = $projectRoot
    $targetDir = "pipeline/core/merge"
}

$versionFile = Join-Path $localRoot (Join-Path $targetDir "VERSION")
if (-not (Test-Path $versionFile)) { $versionFile = Join-Path $localRoot "VERSION" }

if (-not (Test-Path $versionFile)) {
    Write-Error "VERSION file not found in $localRoot or $targetDir"
    exit 1
}

$currentVersion = (Get-Content $versionFile -Raw).Trim()
Write-Host "Current Version: $currentVersion" -ForegroundColor Gray

if ($currentVersion -match '^(?<base>.+)\.(?<patch>\d+)$') {
    $base = $Matches['base']
    $patch = [int]$Matches['patch'] + 1
    $newVersion = "$base.$patch"
} else {
    $newVersion = "$currentVersion.1"
}

Set-Content -Path $versionFile -Value $newVersion -Encoding UTF8

Push-Location (Split-Path $versionFile -Parent)
try {
    git add VERSION | Out-Null
    git commit -m "chore: bump version to $newVersion" | Out-Null
    git tag "v$newVersion" -f | Out-Null
} finally {
    Pop-Location
}

Write-Host "Incremented and committed: $newVersion" -ForegroundColor Green
