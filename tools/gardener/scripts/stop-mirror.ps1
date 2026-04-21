# stop-mirror.ps1
# Stops the live Entity Database Explorer running on port 8080.

Write-Host "--- Stopping Entity Explorer ---" -ForegroundColor Cyan

$procsFound = $false
try {
    $connections = Get-NetTCPConnection -LocalPort 8080 -ErrorAction Stop
    foreach ($conn in $connections) {
        if ($conn -and $conn.OwningProcess) {
            $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $($conn.OwningProcess)"
            if ($proc -and $proc.CommandLine -match "node") {
                Write-Host "Found Mirror process (PID: $($conn.OwningProcess)). Terminating..." -ForegroundColor Yellow
                Stop-Process -Id $conn.OwningProcess -Force
                $procsFound = $true
                Start-Sleep -Seconds 1
            }
        }
    }
} catch {
    # Port might not be in use
}

if (-not $procsFound) {
    Write-Host "No active mirror process found on port 8080." -ForegroundColor Gray
} else {
    Write-Host "Mirror stopped successfully." -ForegroundColor Green
}
