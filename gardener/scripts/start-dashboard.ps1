# start-dashboard.ps1
# Starts the live Entity Database Explorer.

Set-Location "$PSScriptRoot\..\dashboard"
Write-Host "--- Starting Entity Explorer (Direct File View) ---" -ForegroundColor Cyan
Write-Host "URL: http://localhost:8080" -ForegroundColor Yellow
Write-Host "Monitoring: /entities and /_templates" -ForegroundColor Gray

# Use node to start the server
node server.js
