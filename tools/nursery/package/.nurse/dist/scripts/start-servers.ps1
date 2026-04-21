param(
    [Parameter(Mandatory=$false)]
    [string]$Target = "core"
)

# 1. Path Configuration
# .nurse typically rests closely inside the sprout directory after a sprout is executed.
$nurseryDir = $PSScriptRoot | Split-Path -Parent
$nurseRootDir = $nurseryDir | Split-Path -Parent
$rootDir = $nurseRootDir | Split-Path -Parent
$runCmdFile = Join-Path $nurseRootDir ".runcmd"
$tierFile = Join-Path $nurseRootDir ".porttier"

if (-not (Test-Path $runCmdFile)) {
    Write-Error "Could not find .runcmd. Please run build-pipeline.ps1 first."
    exit 1
}
$runCmdTemplate = Get-Content $runCmdFile -Raw

if ($Target -ne "core") {
    Write-Error "Only 'core' target is currently fully supported."
    # TODO: Expand feature startup loop.
    exit 1
}
$y = 1 # Core is pipeline 1

# 2. Tier Discovery & Registry Lock
$current = $rootDir
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
    Write-Error "Could not find Strategy Root (searching up from $rootDir)"
    exit 1
}

$registryFile = Join-Path $strategyRoot "tools\nursery\port_registry.json"
$registryDir = Split-Path $registryFile -Parent
if (-not (Test-Path $registryDir)) { New-Item -ItemType Directory -Path $registryDir -Force | Out-Null }

function Get-PortOwnerPath {
    param([int]$port)
    # Returns the command line of the process occupying the port
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

    # --- GLOBAL PRUNE: Clean up ANY existing tiers for this project root ---
    $oldTiers = @()
    foreach ($key in $registryData.Keys) {
        if ($registryData[$key] -eq $rootDir) {
            $oldTiers += $key
        }
    }

    if ($oldTiers.Count -gt 0) {
        Write-Host "Cleaning up $($oldTiers.Count) existing assignments for this project..." -ForegroundColor Yellow
        foreach ($t in $oldTiers) {
            $tNum = [int]$t
            10..13 | ForEach-Object {
                $p = [int]($t.ToString() + $_.ToString())
                $owner = Get-PortOwnerPath -port $p
                if ($null -ne $owner) {
                    Write-Host "Killing old process on port $p..." -ForegroundColor Gray
                    Stop-PortOwner -port $p
                }
            }
            $registryData.Remove($t)
        }
    }

    # Now, assign a fresh tier
    $xx = 30
    $foundFreeTier = $false

    Write-Host "Scanning for available port tier starting at $xx..." -ForegroundColor Gray
    while (-not $foundFreeTier -and $xx -le 655) {
        # Is this tier owned by another project in the registry?
        $tierKey = $xx.ToString()
        if ($registryData.ContainsKey($tierKey) -and $registryData[$tierKey] -ne $rootDir) {
            $xx++
            continue
        }

        # Check OS ports
        $p0 = [int]"${xx}${y}0"
        $p1 = [int]"${xx}${y}1"
        $p2 = [int]"${xx}${y}2"
        $p3 = [int]"${xx}${y}3"
        $ports = @($p0, $p1, $p2, $p3)
        
        $allFreeOrOwned = $true
        foreach ($p in $ports) {
            $cmdLine = Get-PortOwnerPath -port $p
            if ($null -ne $cmdLine) {
                $escapedRoot = [regex]::Escape($rootDir)
                if ($cmdLine -match $escapedRoot) {
                    Write-Host "Port $p is currently used by an old instance of THIS project. Terminating..." -ForegroundColor Yellow
                    Stop-PortOwner -port $p
                } else {
                    Write-Host "Port $p is blocked by another project or application. Bumping tier ($p)..." -ForegroundColor Magenta
                    $allFreeOrOwned = $false
                    break
                }
            }
        }

        if ($allFreeOrOwned) {
            $foundFreeTier = $true
        } else {
            $xx++
            if ($registryData.ContainsKey($tierKey) -and $registryData[$tierKey] -eq $rootDir) {
                $registryData.Remove($tierKey)
            }
        }
    }

    if (-not $foundFreeTier) {
        Write-Error "Could not find a free block of ports up to tier 655."
        exit 1
    }

    # Save to registry
    $registryData[$xx.ToString()] = $rootDir
    $stream.SetLength(0)
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.Write(($registryData | ConvertTo-Json -Depth 2))
    $writer.Flush()
} finally {
    if ($null -ne $stream) {
        $stream.Close()
        $stream.Dispose()
    }
}

# 3. Execution
Set-Content -Path $tierFile -Value $xx -Encoding UTF8
Write-Host "Allocated port tier $xx for target '$Target'." -ForegroundColor Cyan

$isFeature = $nurseryDir -match "features"
$environments = @()

if (-not $isFeature) {
    $environments += @{ Name = "core/stable"; Port = [int]"${xx}${y}0" }
    $environments += @{ Name = "core/b-test"; Port = [int]"${xx}${y}1" }
    $environments += @{ Name = "core/a-test"; Port = [int]"${xx}${y}2" }
    $environments += @{ Name = "core/merge";  Port = [int]"${xx}${y}3" }
} else {
    $featureName = Split-Path (Split-Path $nurseryDir -Parent) -Leaf
    $environments += @{ Name = "b-test"; Port = [int]"${xx}${y}1" }
    $environments += @{ Name = "a-test"; Port = [int]"${xx}${y}2" }
    $environments += @{ Name = "dev";    Port = [int]"${xx}${y}3" }
}

foreach ($env in $environments) {
    $worktreePath = Join-Path $rootDir $env.Name
    if (Test-Path $worktreePath) {
        # Start the server using the shell execution path for maximum compatibility and logging
        $logFile = Join-Path $worktreePath "server.log"
        $port = $env.Port
        $cmdToRun = $runCmdTemplate -replace "\{PORT\}", "$port"
        Write-Host "Starting $($env.Name) on port $port... " -ForegroundColor Magenta
        
        # We use absolute paths and explicit redirection to capture ALL errors
        Start-Process pwsh -ArgumentList "-NonInteractive", "-Command", "cd '$worktreePath'; $cmdToRun *>> '$logFile'" -WindowStyle Hidden
    } else {
        Write-Host "Worktree $($env.Name) ($worktreePath) not found. Skipping." -ForegroundColor Yellow
    }
}

Write-Host "Servers booted cleanly on tier $xx!" -ForegroundColor Green
