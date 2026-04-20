# stop-dashboard.ps1
# Stops the Nursery Pipeline Dashboard running on port 8081.

Write-Host "--- Stopping Nursery Pipeline Dashboard ---" -ForegroundColor Cyan

$procsFound = $false
try {
    $connections = Get-NetTCPConnection -LocalPort 8081 -ErrorAction Stop
    foreach ($conn in $connections) {
        if ($conn -and $conn.OwningProcess) {
            $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $($conn.OwningProcess)"
            if ($proc -and $proc.CommandLine -match "node") {
                Write-Host "Found Dashboard process (PID: $($conn.OwningProcess)). Terminating..." -ForegroundColor Yellow
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
    Write-Host "No active dashboard process found on port 8081." -ForegroundColor Gray
} else {
    Write-Host "Dashboard stopped successfully." -ForegroundColor Green
}
