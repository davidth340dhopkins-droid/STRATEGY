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

$localNurseRoot = Join-Path $projectRoot ".nurse"
$runCmdFile = Join-Path $localNurseRoot ".runcmd"

if (-not (Test-Path $runCmdFile)) { Write-Error "Could not find .runcmd at $runCmdFile."; exit 1 }
$runCmdTemplate = Get-Content $runCmdFile -Raw

$isFeature = ($Target -ne "core")
if ($isFeature) {
    $featureName = $Target -replace "^feature/", ""
    $localRoot = Join-Path (Join-Path (Join-Path $projectRoot "pipeline") "feature") $featureName
    Write-Host "Configuring Feature Pipeline '$featureName'..." -ForegroundColor Cyan
} else {
    $localRoot = $projectRoot
    Write-Host "Configuring Core Pipeline..." -ForegroundColor Cyan
}

$tierFile = Join-Path $localRoot ".porttier"

$current = $projectRoot
$strategyRoot = $null
while ($current) {
    if (Test-Path (Join-Path $current "tools\nursery")) { $strategyRoot = $current; break }
    $parent = Split-Path $current -Parent
    if ($parent -eq $current) { break }
    $current = $parent
}
if ($null -eq $strategyRoot) { Write-Error "Could not find Strategy Root"; exit 1 }

$registryFile = Join-Path $strategyRoot "tools\nursery\port_registry.json"
$stream = [System.IO.File]::Open($registryFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
try {
    $reader = New-Object System.IO.StreamReader($stream)
    $json = $reader.ReadToEnd(); $registryData = @{}
    if ($json) { $registryData = $json | ConvertFrom-Json -AsHashtable }

    $xx = $null
    foreach ($k in $registryData.Keys) { if ($registryData[$k] -eq $localRoot) { $xx = $k; break } }

    if ($null -eq $xx) {
        $xx = 301
        while ($registryData.ContainsKey($xx.ToString())) { $xx++ }
        $registryData[$xx.ToString()] = $localRoot
        $stream.SetLength(0)
        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.Write(($registryData | ConvertTo-Json -Depth 2))
        $writer.Flush()
    }
} finally { $stream.Close() }

Set-Content -Path $tierFile -Value $xx -Encoding UTF8
Write-Host "Allocated port tier $xx." -ForegroundColor Gray

$envs = @()
if (-not $isFeature) {
    $envs += @{ Name = "pipeline/core/stable"; P = "${xx}10" }
    $envs += @{ Name = "pipeline/core/b-test"; P = "${xx}11" }
    $envs += @{ Name = "pipeline/core/a-test"; P = "${xx}12" }
    $envs += @{ Name = "pipeline/core/merge";  P = "${xx}13" }
} else {
    $envs += @{ Name = "b-test"; P = "${xx}11" }
    $envs += @{ Name = "a-test"; P = "${xx}12" }
    $envs += @{ Name = "dev";    P = "${xx}13" }
}

foreach ($e in $envs) {
    $p = [int]$e.P
    $conn = Get-NetTCPConnection -LocalPort $p -ErrorAction SilentlyContinue
    if ($conn.OwningProcess) { Stop-Process -Id $conn.OwningProcess -Force; Start-Sleep -Seconds 1 }

    $wPath = Join-Path $localRoot $e.Name
    if (Test-Path $wPath) {
        $cmd = $runCmdTemplate -replace "\{PORT\}", "$p"
        Write-Host "Starting $($e.Name) on port $p..." -ForegroundColor Magenta
        Start-Process pwsh -ArgumentList "-NonInteractive", "-Command", "cd '$wPath'; $cmd *>> server.log" -WindowStyle Hidden
    }
}
Write-Host "Done." -ForegroundColor Green
