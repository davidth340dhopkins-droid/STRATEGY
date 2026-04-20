# start-dashboard.ps1
# Starts the Nursery Pipeline Dashboard.

Set-Location "$PSScriptRoot\..\dashboard"
Write-Host "--- Starting Nursery Pipeline Dashboard ---" -ForegroundColor Cyan
Write-Host "URL: http://localhost:8081" -ForegroundColor Yellow

# Use node to start the server
node server.js
