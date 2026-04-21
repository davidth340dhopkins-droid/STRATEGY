param(
    [Parameter(Mandatory=$true)]
    [string]$RunCommand,
    [Parameter(Mandatory=$false)]
    [switch]$NoStart
)

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

$nurseryDir = Join-Path (Join-Path $projectRoot ".nurse") "dist"
$nurseRootDir = Join-Path $projectRoot ".nurse"

if ($null -eq $RunCommand -or $RunCommand -eq "") {
    $RunCommand = "node server.js --port {PORT}"
}
$runCmdFile = Join-Path $nurseRootDir ".runcmd"
Set-Content -Path $runCmdFile -Value $RunCommand -Encoding UTF8

$isFeature = $nurseRootDir -match "feature"
if (-not $isFeature) {
    Write-Host "Configuring Core Pipeline..." -ForegroundColor Cyan
    # Target folders are now prefixed with pipeline/
    $environments = @("pipeline/core/stable", "pipeline/core/b-test", "pipeline/core/a-test", "pipeline/core/merge")
} else {
    $featureName = Split-Path (Split-Path $nurseRootDir -Parent) -Leaf
    Write-Host "Configuring Feature Pipeline: $featureName..." -ForegroundColor Cyan
    # Feature envs are flat relative to the feature root (pipeline/feature/[name])
    $environments = @("b-test", "a-test", "dev")
}

foreach ($env in $environments) {
    # Branch naming: preserve existing core/ and features/ prefixes in git. 
    # Use feature/ (singular) for the new branch naming scheme if you want, 
    # but the user only explicitly asked for the folder name change.
    # Actually, singular 'feature/' in git branches is also cleaner.
    $branch = $env
    if ($isFeature) {
        if ($env -eq "dev") { $branch = "feature/$featureName/merge" }
        else { $branch = "feature/$featureName/$env" }
    } else {
        # Translate folder 'pipeline/core/stable' back to branch 'core/stable'
        $branch = $env -replace "pipeline/", ""
    }

    Write-Host "Creating worktree for $env (branch: $branch)..." -ForegroundColor Gray
    
    $branchExists = git branch --list $branch
    if (-not $branchExists) {
        $sourceBranch = if ($isFeature) { "core/merge" } else { "master" }
        git branch $branch $sourceBranch | Out-Null
    }
    
    if (-not (Test-Path $env)) {
        # Ensure parent exists
        $parent = Split-Path $env -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        git worktree add $env $branch | Out-Null
    } else {
        Write-Host "Worktree directory $env already exists. Skipping." -ForegroundColor Yellow
    }
}

Write-Host "Setup complete. Environments are ready." -ForegroundColor Green

# (Automated Servers Boot)
if (-not $NoStart) {
    Write-Host "Auto-booting servers..." -ForegroundColor Cyan
    $startScript = Join-Path $nurseryDir "scripts/start-servers.ps1"
    pwsh $startScript
} else {
    Write-Host "Run 'pwsh .nurse/dist/scripts/start-servers.ps1' to boot your servers manually." -ForegroundColor Gray
}
