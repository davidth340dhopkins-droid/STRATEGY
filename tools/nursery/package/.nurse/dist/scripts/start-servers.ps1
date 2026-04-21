param(
    [Parameter(Mandatory=$false)]
    [string]$Target = "core"
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

$nurseRootDir = Join-Path $projectRoot ".nurse"
$pipelineDir  = Join-Path $projectRoot "pipeline"

# If we are in a feature, nurseRootDir is actually the FEATURE's nurse root.
# Let's find the nearest .nurse to the script.
$localNurseRoot = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
$isFeature = $localNurseRoot -match "feature"

$runCmdFile = Join-Path $localNurseRoot ".runcmd"
$tierFile = Join-Path $localNurseRoot ".porttier"

if (-not (Test-Path $runCmdFile)) {
    Write-Error "Could not find .runcmd. Please run build-pipeline.ps1 first."
    exit 1
}
$runCmdTemplate = Get-Content $runCmdFile -Raw

if ($Target -ne "core") {
    Write-Error "Only 'core' target is currently fully supported."
    exit 1
}
$y = 1 # Core is pipeline 1

# 2. Tier Discovery & Registry Lock
# Use projectRoot to find the Strategy Root (for the global registry)
$current = $projectRoot
$strategyRoot = $null
while ($current) {
    if (Test-Path (Join-Path $current "tools\nursery")) {
        $strategyRoot = $current
        break
    }
    $parent = Split-Path $current -Parent
    if ($parent -eq $current) { break }
    $current = $parent
}

if ($null -eq $strategyRoot) {
    Write-Error "Could not find Strategy Root (searching up from $projectRoot)"
    exit 1
}

$registryFile = Join-Path $strategyRoot "tools\nursery\port_registry.json"
$registryDir = Split-Path $registryFile -Parent
if (-not (Test-Path $registryDir)) { New-Item -ItemType Directory -Path $registryDir -Force | Out-Null }

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

$lockAcquired = $false
$stream = $null
$retryCount = 0
Write-Host "Acquiring registry lock..." -ForegroundColor Gray
while (-not $lockAcquired -and $retryCount -lt 50) {
    try {
        $stream = [System.IO.File]::Open($registryFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $lockAcquired = $true
    } catch {
        Start-Sleep -Milliseconds 100
        $retryCount++
    }
}

if (-not $lockAcquired) {
    Write-Error "Failed to acquire lock on port registry ($registryFile). Is another project starting?"
    exit 1
}

try {
    $reader = New-Object System.IO.StreamReader($stream)
    $jsonContent = $reader.ReadToEnd()
    $registryData = @{}
    if (-not [string]::IsNullOrWhiteSpace($jsonContent)) {
        try {
            $parsed = $jsonContent | ConvertFrom-Json
            if ($null -ne $parsed) {
                foreach ($prop in $parsed.psobject.properties) {
                    $registryData[$prop.Name] = $prop.Value
                }
            }
        } catch {
            Write-Warning "Failed to parse registry JSON. Rebuilding..."
        }
    }

    # --- GLOBAL PRUNE: Clean up ANY existing tiers for the LOCAL root (ProjectRoot or FeatureRoot) ---
    # Use $localNurseRoot | Split-Path -Parent as the identity anchor
    $localRoot = $localNurseRoot | Split-Path -Parent
    $oldTiers = @()
    foreach ($key in $registryData.Keys) {
        if ($registryData[$key] -eq $localRoot) {
            $oldTiers += $key
        }
    }

    if ($oldTiers.Count -gt 0) {
        Write-Host "Cleaning up $($oldTiers.Count) existing assignments for this project..." -ForegroundColor Yellow
        foreach ($t in $oldTiers) {
            10..13 | ForEach-Object {
                $p = [int]($t.ToString() + $_.ToString())
                Stop-PortOwner -port $p
            }
            $registryData.Remove($t)
        }
    }

    # Now, assign a fresh tier
    $xx = 30
    $foundFreeTier = $false
    while (-not $foundFreeTier -and $xx -le 655) {
        $tierKey = $xx.ToString()
        if ($registryData.ContainsKey($tierKey) -and $registryData[$tierKey] -ne $localRoot) {
            $xx++
            continue
        }

        $p0 = [int]"${xx}${y}0"; $p1 = [int]"${xx}${y}1"; $p2 = [int]"${xx}${y}2"; $p3 = [int]"${xx}${y}3"
        $ports = @($p0, $p1, $p2, $p3)
        $allFreeOrOwned = $true
        foreach ($p in $ports) {
            $cmdLine = Get-PortOwnerPath -port $p
            if ($null -ne $cmdLine) {
                $escapedRoot = [regex]::Escape($localRoot)
                if ($cmdLine -match $escapedRoot) {
                    Stop-PortOwner -port $p
                } else {
                    $allFreeOrOwned = $false
                    break
                }
            }
        }
        if ($allFreeOrOwned) { $foundFreeTier = $true } else { $xx++ }
    }
    if (-not $foundFreeTier) { Write-Error "Could not find a free block of ports."; exit 1 }

    $registryData[$xx.ToString()] = $localRoot
    $stream.SetLength(0)
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.Write(($registryData | ConvertTo-Json -Depth 2))
    $writer.Flush()
} finally {
    if ($null -ne $stream) { $stream.Close(); $stream.Dispose() }
}

# 3. Execution
Set-Content -Path $tierFile -Value $xx -Encoding UTF8
Write-Host "Allocated port tier $xx for target '$Target'." -ForegroundColor Cyan

$environments = @()
if (-not $isFeature) {
    # Core uses pipeline/core/ prefix
    $environments += @{ Name = "pipeline/core/stable"; Port = [int]"${xx}${y}0" }
    $environments += @{ Name = "pipeline/core/b-test"; Port = [int]"${xx}${y}1" }
    $environments += @{ Name = "pipeline/core/a-test"; Port = [int]"${xx}${y}2" }
    $environments += @{ Name = "pipeline/core/merge";  Port = [int]"${xx}${y}3" }
} else {
    $environments += @{ Name = "b-test"; Port = [int]"${xx}${y}1" }
    $environments += @{ Name = "a-test"; Port = [int]"${xx}${y}2" }
    $environments += @{ Name = "dev";    Port = [int]"${xx}${y}3" }
}

foreach ($env in $environments) {
    $worktreePath = Join-Path $localRoot $env.Name
    if (Test-Path $worktreePath) {
        $logFile = Join-Path $worktreePath "server.log"
        $port = $env.Port
        $cmdToRun = $runCmdTemplate -replace "\{PORT\}", "$port"
        Write-Host "Starting $($env.Name) on port $port... " -ForegroundColor Magenta
        Start-Process pwsh -ArgumentList "-NonInteractive", "-Command", "cd '$worktreePath'; $cmdToRun *>> '$logFile'" -WindowStyle Hidden
    } else {
        Write-Host "Worktree $($env.Name) ($worktreePath) not found. Skipping." -ForegroundColor Yellow
    }
}

Write-Host "Servers booted cleanly on tier $xx!" -ForegroundColor Green
