param(
    [Parameter(Mandatory=$true)]
    [string]$RunCommand
)

Write-Host "Configuring Core Pipeline..." -ForegroundColor Cyan

# 1. Ensure config file paths are correct to the isolated _nursery setup
$nurseryDir = $PSScriptRoot | Split-Path -Parent
$runCmdFile = Join-Path $nurseryDir ".runcmd"

Set-Content -Path $runCmdFile -Value $RunCommand -Encoding UTF8

# 2. Branch creation and Worktree creation
$environments = @("core-stable", "core-b-test", "core-a-test", "core-merge")

foreach ($env in $environments) {
    Write-Host "Creating worktree for $env..." -ForegroundColor Gray
    
    $branchExists = git branch --list $env
    if (-not $branchExists) {
        git branch $env | Out-Null
    }
    
    if (-not (Test-Path $env)) {
        git worktree add $env $env | Out-Null
    } else {
        Write-Host "Worktree directory $env already exists. Skipping." -ForegroundColor Yellow
    }
}

Write-Host "Setup complete. Core environments are ready." -ForegroundColor Green
Write-Host "Run 'pwsh _nursery/scripts/start-env.ps1' to boot your servers." -ForegroundColor Cyan
