# tools/nursery/scripts/scavenge.ps1
# Global "Nuclear" cleanup script for Nursery infrastructure.

Write-Host "--- ☢️ NURSERY SCAVENGER: Global Cleanup ☢️ ---" -ForegroundColor Red

$strategyRoot = [System.IO.Path]::GetFullPath("$PSScriptRoot\..\..\..")
$registryFile = Join-Path $strategyRoot "tools\nursery\port_registry.json"

# 1. Stop Dashboard
$stopDashboard = Join-Path $PSScriptRoot "stop-dashboard.ps1"
if (Test-Path $stopDashboard) {
    pwsh $stopDashboard
}

# Helper functions
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
            Write-Host "Killing process $($conn.OwningProcess) on port $port..." -ForegroundColor Yellow
            Stop-Process -Id $conn.OwningProcess -Force
            Start-Sleep -Seconds 1
        }
    } catch { }
}

# 2. Cleanup via Port Registry
if (Test-Path $registryFile) {
    Write-Host "Processing port registry assignments..." -ForegroundColor Cyan
    try {
        $registryData = Get-Content $registryFile -Raw | ConvertFrom-Json
        if ($null -ne $registryData) {
            foreach ($prop in $registryData.psobject.properties) {
                $tier = [int]$prop.Name
                Write-Host "Scrubbing tier $tier..." -ForegroundColor Gray
                # Tiers use ports: [tier]10, [tier]11, [tier]12, [tier]13
                10..13 | ForEach-Object {
                    $port = [int]($tier.ToString() + $_.ToString())
                    Stop-PortOwner -port $port
                }
            }
        }
    } catch {
        Write-Warning "Failed to parse port registry. Proceeding with rogue process scan."
    }
}

# 3. Aggressive Rogue Process Scan
Write-Host "Scanning for any rogue processes running from 'entities\sprouts'..." -ForegroundColor Cyan
$escapedSprouts = [regex]::Escape("entities\sprouts")

# This matches ANY process that mentions 'entities\sprouts' in its command line
$processes = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match $escapedSprouts -or $_.ExecutablePath -match $escapedSprouts }
foreach ($proc in $processes) {
    if ($proc.ProcessId -ne $PID) {
        Write-Host "Stopping matching process $($proc.ProcessId): $($proc.Name)..." -ForegroundColor Yellow
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

# 4. Final Sweep: Node & PWSH
Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match "server.js" } | Stop-Process -Force -ErrorAction SilentlyContinue

# 5. Manual Trash Sweep (for old structures)
Write-Host "Cleaning legacy trash folders..." -ForegroundColor Gray
$sproutsRoot = Join-Path $strategyRoot "entities\sprouts"
if (Test-Path $sproutsRoot) {
    Get-ChildItem $sproutsRoot -Directory | ForEach-Object {
        $legacyCore = Join-Path $_.FullName "core"
        $legacyFeatures = Join-Path $_.FullName "features"
        if (Test-Path $legacyCore) { Remove-Item $legacyCore -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $legacyFeatures) { Remove-Item $legacyFeatures -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host "`nCleanup Complete." -ForegroundColor Green
