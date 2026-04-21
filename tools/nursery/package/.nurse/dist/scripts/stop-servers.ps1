param(
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
if ($isFeature) {
    $featureName = $Target -replace "^feature/", ""
    $localRoot = Join-Path (Join-Path (Join-Path $projectRoot "pipeline") "feature") $featureName
} else {
    $localRoot = $projectRoot
}

$tierFile = Join-Path $localRoot ".porttier"
if (-not (Test-Path $tierFile)) { exit 0 }

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

$xx = [int](Get-Content $tierFile -Raw)
$ports = @([int]"${xx}10", [int]"${xx}11", [int]"${xx}12", [int]"${xx}13")

foreach ($p in $ports) {
    $cmdLine = Get-PortOwnerPath -port $p
    if ($null -ne $cmdLine) {
        $escapedRoot = [regex]::Escape($localRoot)
        if ($cmdLine -match $escapedRoot) {
            $conn = Get-NetTCPConnection -LocalPort $p -ErrorAction Stop
            if ($conn -and $conn.OwningProcess) { Stop-Process -Id $conn.OwningProcess -Force }
        }
    }
}
