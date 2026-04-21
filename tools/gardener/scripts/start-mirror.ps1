# start-mirror.ps1
# Starts the live Entity Database Explorer.

Set-Location "$PSScriptRoot\..\mirror"
Write-Host "--- Starting Entity Explorer (Mirror) ---" -ForegroundColor Cyan
Write-Host "URL: http://localhost:8080" -ForegroundColor Yellow
Write-Host "Monitoring: /entities and /template" -ForegroundColor Gray

# Use node to start the server
node server.js
