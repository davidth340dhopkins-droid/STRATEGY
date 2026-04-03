# nursery/run.ps1
# Temporary executor script. Edit this to run any sequence of commands.

# 1. Kill any existing test-sprout or unsprout processes
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match "test-sprout.ps1" -or $_.CommandLine -match "unsprout.ps1" -or $_.CommandLine -match "testsprout" } | ForEach-Object { 
    if ($_.ProcessId -ne $PID) { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

# 2. Run a clean idempotent test
pwsh nursery/test-sprout.ps1
