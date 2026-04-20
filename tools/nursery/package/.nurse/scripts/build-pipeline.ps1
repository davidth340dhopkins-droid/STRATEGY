param(
    [Parameter(Mandatory=$true)]
    [string]$RunCommand,
    [Parameter(Mandatory=$false)]
    [switch]$NoStart
)

Write-Host "Configuring Core Pipeline..." -ForegroundColor Cyan

# 1. Ensure config file paths are correct to the isolated .nurse setup
$nurseryDir = $PSScriptRoot | Split-Path -Parent
$runCmdFile = Join-Path $nurseryDir ".runcmd"

Set-Content -Path $runCmdFile -Value $RunCommand -Encoding UTF8

# 2. Branch creation and Worktree creation
$isFeature = $nurseryDir -match "features"
$environments = if (-not $isFeature) {
    @("core/stable", "core/b-test", "core/a-test", "core/merge")
} else {
    $featureName = Split-Path (Split-Path $nurseryDir -Parent) -Leaf
    @("features/$featureName/b-test", "features/$featureName/a-test", "features/$featureName/merge")
}

foreach ($env in $environments) {
    Write-Host "Creating worktree for $env..." -ForegroundColor Gray
    
    $branchExists = git branch --list $env
    if (-not $branchExists) {
        $sourceBranch = if ($isFeature) { "core/merge" } else { "master" }
        if ($env -match "stable$") {
             # Core stable is special
        } else {
            git branch $env $sourceBranch | Out-Null
        }
    }
    
    if (-not (Test-Path $env)) {
        git worktree add $env $env | Out-Null
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
