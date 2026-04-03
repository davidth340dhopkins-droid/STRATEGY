# cleanup.ps1
# Cleans up old template folders, leaving only the most recent one.

$strategyRoot = [System.IO.Path]::GetFullPath("$PSScriptRoot\..\..")
$templatesDir = "$strategyRoot\gardener\_templates"

$vFolders = Get-ChildItem -Path $templatesDir -Directory | Where-Object { $_.Name -match '^v\d+$' } | Sort-Object { [int]($_.Name -replace 'v', '') } -Descending

if ($vFolders.Count -le 1) {
    Write-Host "Nothing to clean up. Only one template version exists."
    exit
}



for ($i = 1; $i -lt $vFolders.Count; $i++) {
    $folder = $vFolders[$i]
    Write-Host "Deleting obsolete template: $($folder.Name)"
    Remove-Item $folder.FullName -Recurse -Force
}

Write-Host "Cleanup complete."
