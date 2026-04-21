# .nurse/scripts/stop-servers.ps1
# Gracefully identifies and terminates servers associated with this project.

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

# Find the local root (ProjectRoot or FeatureRoot)
$localNurseRoot = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
$localRoot = $localNurseRoot | Split-Path -Parent
$tierFile = Join-Path $localNurseRoot ".porttier"

if (-not (Test-Path $tierFile)) {
    Write-Host "No .porttier found. Skipping graceful stop." -ForegroundColor Gray
    exit 0
}

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
            Write-Host "Terminating process $($conn.OwningProcess) on port $port..." -ForegroundColor Yellow
            Stop-Process -Id $conn.OwningProcess -Force
            Start-Sleep -Seconds 1
        }
    } catch { }
}

$xx = [int](Get-Content $tierFile -Raw)
$y = 1 # Core is pipeline 1

# Ports: p0, p1, p2, p3
$ports = @([int]"${xx}${y}0", [int]"${xx}${y}1", [int]"${xx}${y}2", [int]"${xx}${y}3")

Write-Host "Releasing ports for tier $xx..." -ForegroundColor Cyan
foreach ($p in $ports) {
    $cmdLine = Get-PortOwnerPath -port $p
    if ($null -ne $cmdLine) {
        $escapedRoot = [regex]::Escape($rootDir)
        if ($cmdLine -match $escapedRoot) {
            Stop-PortOwner -port $p
        }
    }
}

Write-Host "Project servers stopped." -ForegroundColor Green
