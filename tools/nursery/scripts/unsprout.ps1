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
    # 0. ALWAYS: Prune + force-remove ALL worktrees inside this sprout before anything else.
    # This releases git branch locks so branches can be re-checked-out cleanly elsewhere.
    if (Test-Path (Join-Path $sproutDir.FullName ".git")) {
        Write-Host "Releasing all Git worktrees..." -ForegroundColor Gray
        Push-Location $sproutDir.FullName
        
        # First prune dead worktrees (directories already deleted)
        git worktree prune 2>$null
        
        # Then force-remove any live worktrees inside the sprout (all except the main .git root)
        $worktrees = git worktree list --porcelain 2>$null | Select-String "^worktree " | ForEach-Object {
            $_.ToString() -replace "^worktree ", "" | ForEach-Object { $_.Trim() }
        }
        foreach ($wt in $worktrees) {
            $normalWt  = $wt.Replace("\\", "/")
            $normalRoot = $sproutDir.FullName.Replace("\\", "/")
            if ($normalWt -ne $normalRoot -and $normalWt.StartsWith($normalRoot)) {
                Write-Host "Removing worktree: $wt" -ForegroundColor Yellow
                git worktree remove --force $wt 2>$null
            }
        }
        
        # Final prune to unregister any that couldn't be removed
        git worktree prune 2>$null
        Pop-Location
    }

    # 1. Gracefully stop servers if the script exists
    $stopScript = Join-Path $sproutDir.FullName ".nurse\dist\scripts\stop-servers.ps1"
    if (Test-Path $stopScript) {
        Write-Host "Executing project stop-servers.ps1..." -ForegroundColor Gray
        pwsh $stopScript
    }

    # 2. If -Kill: also scavenge processes by path and stop port owners
    if ($Kill) {
        Write-Host "Invoking Global Scavenger..." -ForegroundColor Gray
        $scavengeScript = Join-Path $strategyRoot "tools\nursery\scripts\scavenge.ps1"
        if (Test-Path $scavengeScript) { pwsh $scavengeScript }
        
        Write-Host "Scanning for background shells locked to this sprout..." -ForegroundColor Gray
        $escapedRoot = [regex]::Escape($sproutDir.FullName)
        $processes = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match $escapedRoot }
        foreach ($proc in $processes) {
            if ($proc.ProcessId -ne $PID) {
                Write-Host "Stopping PID $($proc.ProcessId): $($proc.Name)" -ForegroundColor Yellow
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
