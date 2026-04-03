# init.ps1
# This script runs once immediately after a sprout directory is created and the package is copied.
# Its primary purpose is to establish the isolated initial git repository structure.

Write-Host "Initializing isolated Git repository..." -ForegroundColor Cyan

# 1. Initialize empty git repository
git init

# 2. Add all recently copied files (seed file and packaged scripts)
git add .

# 3. Create root commit
git commit -m "chore: initial sprout generation"

Write-Host "Git repository initialized and committed." -ForegroundColor Green
