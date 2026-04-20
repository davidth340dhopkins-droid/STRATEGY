# tools/nursery/scripts/unsprout.ps1
# Retreats a sprout back into a seed and archives the workspace into the compost bin.

param(
    [Parameter(Mandatory=$true)]
    [string]$SproutPath,
    [Parameter(Mandatory=$false)]
    [switch]$Delete,
    [Parameter(Mandatory=$false)]
    [switch]$Kill
)

$strategyRoot = [System.IO.Path]::GetFullPath("$PSScriptRoot\..\..\..")
$compostBin = Join-Path $strategyRoot "compost\bin"
$seedsDir = Join-Path $strategyRoot "entities\seeds"

if (-not (Test-Path $SproutPath)) {
    Write-Error "Sprout path does not exist: $SproutPath"
    exit 1
}

$sproutDir = Get-Item $SproutPath
$sproutName = $sproutDir.Name

$sproutDir = Get-Item $SproutPath
$sproutName = $sproutDir.Name

$destCompost = Join-Path $compostBin $sproutName

# (We'll still keep these as local helpers for the -Kill scavenger if needed,
# or we can remove them if stop-servers.ps1 is always present).

function Get-PortOwnerPath {
    param([int]$port)
    try {
        $conn = Get-NetTCPConnection -LocalPort $port -ErrorAction Stop
        if ($conn -and $conn.OwningProcess) {
            $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $($conn.OwningProcess)"
            if ($proc) { return $proc.CommandLine }
        }
    } catch { }
    return $null
}

function Stop-PortOwner {
    param([int]$port)
    try {
        $conn = Get-NetTCPConnection -LocalPort $port -ErrorAction Stop
        if ($conn -and $conn.OwningProcess) {
            Stop-Process -Id $conn.OwningProcess -Force
            Start-Sleep -Seconds 1
        }
    } catch { }
}

if ($Delete) {
    Write-Host "DELETING sprout $sproutName definitively..." -ForegroundColor Red
} else {
    Write-Host "Attempting to unsprout $sproutName to compost..." -ForegroundColor Cyan
}

try {
    # 0. Forcefully remove Git worktrees if this is a Git repo
    if (Test-Path (Join-Path $sproutDir.FullName ".git")) {
        Write-Host "Releasing Git worktrees..." -ForegroundColor Gray
        Push-Location $sproutDir.FullName
        # Find all worktrees associated with this repo and remove them
        $worktrees = git worktree list --porcelain | Select-String "^worktree " | ForEach-Object { $_.ToString().Replace("worktree ", "").Trim() }
        foreach ($wt in $worktrees) {
            # Only remove if it's inside our sprout directory (don't touch the main one)
            if ($wt -match [regex]::Escape($sproutDir.FullName) -and $wt -ne $sproutDir.FullName) {
                Write-Host "Removing worktree $wt..." -ForegroundColor Yellow
                git worktree remove --force $wt 2>$null
            }
        }
        Pop-Location
    }

    # 1. Gracefully stop servers if the script exists
    $stopScript = Join-Path $sproutDir.FullName ".nurse\scripts\stop-servers.ps1"
    if (Test-Path $stopScript) {
        Write-Host "Executing project stop-servers.ps1..." -ForegroundColor Gray
        pwsh $stopScript
    }

    # 2. Aggressively kill ANY remaining process that has this folder in its command line (e.g. background shells)
    # ONLY if the user specifically asked to -Kill
    if ($Kill) {
        Write-Host "Scanning for background shells or locked processes..." -ForegroundColor Gray
        $escapedRoot = [regex]::Escape($sproutDir.FullName)
        $processes = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match $escapedRoot }
        foreach ($proc in $processes) {
            if ($proc.ProcessId -ne $PID) {
                Write-Host "Stopping matching process $($proc.ProcessId): $($proc.Name)..." -ForegroundColor Yellow
                Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
            }
        }
        Start-Sleep -Seconds 1
    }

    if ($Delete) {
        $maxRetries = 10
        $retryCount = 0
        while ($true) {
            try {
                Remove-Item -Path $sproutDir.FullName -Recurse -Force -ErrorAction Stop
                break
            } catch {
                $retryCount++
                if ($retryCount -ge $maxRetries) { throw $_ }
                Write-Host "Directory locked. Retrying in 1s... ($retryCount/$maxRetries)" -ForegroundColor Gray
                Start-Sleep -Seconds 1
            }
        }
        Write-Host "Success: Deleted $sproutName." -ForegroundColor Green
        exit 0
    }

    if (Test-Path $destCompost) {
        Write-Error "A folder named '$sproutName' already exists in compost/bin. Remove it first."
        exit 1
    }

    $maxRetries = 10
    $retryCount = 0
    while ($true) {
        try {
            # Move the entire structure to compost first, using -Force to bypass Git readonly file locks.
            Move-Item -Path $sproutDir.FullName -Destination $destCompost -Force -ErrorAction Stop
            break
        } catch {
            $retryCount++
            if ($retryCount -ge $maxRetries) { throw $_ }
            Write-Host "Directory locked. Retrying in 1s... ($retryCount/$maxRetries)" -ForegroundColor Gray
            Start-Sleep -Seconds 1
        }
    }
    
    # Identify the seed file
    $seedFile = Get-ChildItem -Path $destCompost -Filter "_*.md" | Select-Object -First 1
    if (-not $seedFile) {
        Write-Error "Could not find a seed file (_seed.md) inside archive. Proceeding anyway."
    } else {
        # Retrieve the seed file back into entities/seeds
        $movedSeedPath = Join-Path $destCompost $seedFile.Name
        $targetSeedPath = Join-Path $seedsDir $seedFile.Name
        Move-Item -Path $movedSeedPath -Destination $targetSeedPath -Force -ErrorAction Stop
        Write-Host "Seed returned to $targetSeedPath" -ForegroundColor Gray
    }
    
    Write-Host "Success: Unsprouted $sproutName." -ForegroundColor Green
    Write-Host "Workspace archived in compost/bin/$sproutName" -ForegroundColor Gray
} catch {
    Write-Error "Unsprout process failed. Ensure no servers or terminals are actively open inside the sprout folder."
    Write-Error $_
    exit 1
}
