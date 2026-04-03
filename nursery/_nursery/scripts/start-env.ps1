param(
    [Parameter(Mandatory=$false)]
    [string]$Target = "core"
)

# 1. Path Configuration
# _nursery typically rests closely inside the sprout directory after a sprout is executed.
$nurseryDir = $PSScriptRoot | Split-Path -Parent
$rootDir = $nurseryDir | Split-Path -Parent
$runCmdFile = Join-Path $nurseryDir ".runcmd"
$tierFile = Join-Path $nurseryDir ".porttier"

if (-not (Test-Path $runCmdFile)) {
    Write-Error "Could not find .runcmd. Please run setup-core.ps1 first."
    exit 1
}
$runCmdTemplate = Get-Content $runCmdFile -Raw

if ($Target -ne "core") {
    Write-Error "Only 'core' target is currently fully supported."
    # TODO: Expand feature startup loop.
    exit 1
}
$y = 1 # Core is pipeline 1

# 2. Tier Discovery
$xx = 30
if (Test-Path $tierFile) {
    # If the project generated a previous tier bump, read it.
    $xx = [int](Get-Content $tierFile -Raw)
}

function Get-PortOwnerPath {
    param([int]$port)
    # Returns the command line of the process occupying the port
    try {
        $conn = Get-NetTCPConnection -LocalPort $port -ErrorAction Stop
        if ($conn -and $conn.OwningProcess) {
            $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $($conn.OwningProcess)"
            if ($proc) {
                return $proc.CommandLine
            }
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

$foundFreeTier = $false
Write-Host "Scanning for available port tier..." -ForegroundColor Gray

while (-not $foundFreeTier -and $xx -le 99) {
    # e.g., 3010, 3011, 3012, 3013
    $p0 = [int]"${xx}${y}0"
    $p1 = [int]"${xx}${y}1"
    $p2 = [int]"${xx}${y}2"
    $p3 = [int]"${xx}${y}3"
    
    $ports = @($p0, $p1, $p2, $p3)
    $allFreeOrOwned = $true
    
    foreach ($p in $ports) {
        $cmdLine = Get-PortOwnerPath -port $p
        if ($null -ne $cmdLine) {
            # Is it our app? We check if the command line contains our root sprout directory path.
            $escapedRoot = [regex]::Escape($rootDir)
            if ($cmdLine -match $escapedRoot) {
                Write-Host "Port $p is currently used by an old instance of THIS project. Terminating..." -ForegroundColor Yellow
                Stop-PortOwner -port $p
            } else {
                Write-Host "Port $p is blocked by another project or application. Bumping tier to $($xx + 1)..." -ForegroundColor Magenta
                $allFreeOrOwned = $false
                break
            }
        }
    }
    
    if ($allFreeOrOwned) {
        $foundFreeTier = $true
    } else {
        $xx++
    }
}

if (-not $foundFreeTier) {
    Write-Error "Could not find a free block of ports up to tier 99."
    exit 1
}

# 3. Execution
Set-Content -Path $tierFile -Value $xx -Encoding UTF8
Write-Host "Allocated port tier $xx for target '$Target'." -ForegroundColor Cyan

$environments = @(
    @{ Name = "core-stable"; Port = [int]"${xx}${y}0" },
    @{ Name = "core-b-test"; Port = [int]"${xx}${y}1" },
    @{ Name = "core-a-test"; Port = [int]"${xx}${y}2" },
    @{ Name = "core-merge";  Port = [int]"${xx}${y}3" }
)

foreach ($env in $environments) {
    $worktreePath = Join-Path $rootDir $env.Name
    if (Test-Path $worktreePath) {
        $port = $env.Port
        $cmdToRun = $runCmdTemplate -replace "\{PORT\}", "$port"
        Write-Host "Starting $($env.Name) on port $port... " -ForegroundColor Magenta
        
        Start-Process pwsh -ArgumentList "-NoExit", "-Command", "cd ""$worktreePath""; Write-Host ""Port $port -> $($env.Name)"" -ForegroundColor Cyan; $cmdToRun" -WindowStyle Minimized
    } else {
        Write-Host "Worktree $($env.Name) not found. Skipping." -ForegroundColor Yellow
    }
}

Write-Host "Servers booted cleanly on tier $xx!" -ForegroundColor Green
