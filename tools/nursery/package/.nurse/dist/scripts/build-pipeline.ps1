param(
    [Parameter(Mandatory=$true)]
    [string]$RunCommand,
    [Parameter(Mandatory=$false)]
    [switch]$NoStart
)

$nurseryDir = $PSScriptRoot | Split-Path -Parent
$nurseRootDir = $nurseryDir | Split-Path -Parent # This is the .nurse/ root where state lives

if ($null -eq $RunCommand -or $RunCommand -eq "") {
    $RunCommand = "node server.js --port {PORT}"
}
$runCmdFile = Join-Path $nurseRootDir ".runcmd"
Set-Content -Path $runCmdFile -Value $RunCommand -Encoding UTF8

$isFeature = $nurseRootDir -match "features"
if (-not $isFeature) {
    Write-Host "Configuring Core Pipeline..." -ForegroundColor Cyan
    $environments = @("core/stable", "core/b-test", "core/a-test", "core/merge")
} else {
    $featureName = Split-Path (Split-Path $nurseRootDir -Parent) -Leaf
    Write-Host "Configuring Feature Pipeline: $featureName..." -ForegroundColor Cyan
    # Flat directory structure for features
    $environments = @("b-test", "a-test", "dev")
}

foreach ($env in $environments) {
    $branch = $env
    # For features, we map internal names to the full branch paths
    if ($isFeature) {
        if ($env -eq "dev") { $branch = "features/$featureName/merge" }
        else { $branch = "features/$featureName/$env" }
    }

    Write-Host "Creating worktree for $env (branch: $branch)..." -ForegroundColor Gray
    
    $branchExists = git branch --list $branch
    if (-not $branchExists) {
        $sourceBranch = if ($isFeature) { "core/merge" } else { "master" }
        git branch $branch $sourceBranch | Out-Null
    }
    
    if (-not (Test-Path $env)) {
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
    Write-Host "Run 'pwsh .nurse/scripts/start-servers.ps1' to boot your servers manually." -ForegroundColor Gray
}
