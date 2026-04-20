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
$environments = @("core/stable", "core/b-test", "core/a-test", "core/merge")

foreach ($env in $environments) {
    Write-Host "Creating worktree for $env..." -ForegroundColor Gray
    
    $branchExists = git branch --list $env
    if (-not $branchExists) {
        if ($env -ne "core/stable") {
            git branch $env core/stable | Out-Null
        } else {
            git branch $env | Out-Null
        }
    }
    
    if (-not (Test-Path $env)) {
        git worktree add $env $env | Out-Null
    } else {
        Write-Host "Worktree directory $env already exists. Skipping." -ForegroundColor Yellow
    }
}

Write-Host "Setup complete. Core environments are ready." -ForegroundColor Green

# (Automated Servers Boot)
if (-not $NoStart) {
    Write-Host "Auto-booting servers..." -ForegroundColor Cyan
    $startScript = Join-Path $nurseryDir "scripts/start-servers.ps1"
    pwsh $startScript
} else {
    Write-Host "Run 'pwsh .nurse/scripts/start-servers.ps1' to boot your servers manually." -ForegroundColor Gray
}
