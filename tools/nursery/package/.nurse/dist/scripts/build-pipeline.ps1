param(
    [Parameter(Mandatory=$true)]
    [string]$RunCommand,
    [Parameter(Mandatory=$false)]
    [switch]$NoStart,
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
$nurseRootDir = Join-Path $projectRoot ".nurse"
$nurseryDir   = Join-Path $nurseRootDir "dist"
Set-Location $projectRoot

if ($isFeature) {
    $featureName = $Target -replace "^feature/", ""
    Write-Host "Configuring Feature Pipeline: $featureName..." -ForegroundColor Cyan
    $environments = @(
        "pipeline/feature/$featureName/b-test",
        "pipeline/feature/$featureName/a-test",
        "pipeline/feature/$featureName/dev"
    )
} else {
    Write-Host "Configuring Core Pipeline..." -ForegroundColor Cyan
    $environments = @("pipeline/core/stable", "pipeline/core/b-test", "pipeline/core/a-test", "pipeline/core/merge")
}

if ($null -eq $RunCommand -or $RunCommand -eq "") {
    $RunCommand = "node server.js --port {PORT}"
}
if (-not $isFeature) {
    $runCmdFile = Join-Path $nurseRootDir ".runcmd"
    Set-Content -Path $runCmdFile -Value $RunCommand -Encoding UTF8
}

foreach ($env in $environments) {
    if ($isFeature) {
        $suffix = $env -replace "pipeline/feature/$featureName/", ""
        if ($suffix -eq "dev") { $branch = "feature/$featureName/merge" }
        else { $branch = "feature/$featureName/$suffix" }
    } else {
        $branch = $env -replace "^pipeline/", ""
    }

    Write-Host "Creating worktree for $env (branch: $branch)..." -ForegroundColor Gray
    
    $branchExists = git branch --list $branch
    if (-not $branchExists) {
        $sourceBranch = "master"
        if ($isFeature) { $sourceBranch = "core/merge" } elseif ($branch -ne "core/stable") { $sourceBranch = "core/stable" }
        Write-Host "Creating branch $branch from $sourceBranch..." -ForegroundColor Gray
        git branch $branch $sourceBranch | Out-Null
    } else {
        $sourceBranch = "master"
        if ($isFeature) { $sourceBranch = "core/merge" } elseif ($branch -ne "core/stable") { $sourceBranch = "core/stable" }
        Write-Host "Resetting branch $branch to match $sourceBranch..." -ForegroundColor Yellow
        git branch -f $branch $sourceBranch | Out-Null
    }
    
    $absTarget = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $env))
    $wtList = git worktree list --porcelain | Select-String "^worktree "
    $isRegistered = $false
    foreach ($wt in $wtList) {
        $wtPath = ($wt.ToString() -replace "^worktree ", "").Trim()
        $absWT = [System.IO.Path]::GetFullPath($wtPath)
        if ($absWT -eq $absTarget) { $isRegistered = $true; break }
    }

    if (-not $isRegistered) {
        if (Test-Path $env) { Remove-Item $env -Recurse -Force | Out-Null }
        $parent = Split-Path $env -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        git worktree add $env $branch | Out-Null
    } else {
        git -C $env reset --hard $branch | Out-Null
        git -C $env clean -fd | Out-Null
    }
}

Write-Host "Setup complete." -ForegroundColor Green

if ($isFeature) {
    Write-Host "Enforcing strict semantic version for $featureName..." -ForegroundColor Gray
    $devEnv = "pipeline/feature/$featureName/dev"
    $versionFile = Join-Path $projectRoot (Join-Path $devEnv "VERSION")
    $coreMergeVerFile = Join-Path $projectRoot "pipeline/core/merge/VERSION"
    $baseVer = if (Test-Path $coreMergeVerFile) { (Get-Content $coreMergeVerFile -Raw).Trim() } else { "0.1.0" }
    
    $currentString = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { "" }
    if (-not ($currentString -match "-$featureName")) {
        $newVer = "$baseVer-$featureName.0"
        Set-Content -Path $versionFile -Value $newVer -Encoding UTF8
        Push-Location (Join-Path $projectRoot $devEnv)
        try {
            git add VERSION | Out-Null
            git commit -m "chore: align semantic version strictly for feature branch" | Out-Null
        } finally {
            Pop-Location
        }
    }
}
if (-not $NoStart) {
    Write-Host "Auto-booting servers..." -ForegroundColor Cyan
    $startScript = Join-Path $nurseryDir "scripts/start-servers.ps1"
    pwsh $startScript -Target $Target
}
