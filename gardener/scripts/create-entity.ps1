# create-entity.ps1
# Creates a new entity file from the latest template.
param(
    [string]$Name,
    [switch]$NoBuild
)

$managerDir  = [System.IO.Path]::GetFullPath("$PSScriptRoot\..")
$templatesDir = "$managerDir\_templates"
$entitiesDir  = "$managerDir\entities"

# 1. Find the latest template version
$vFolders = Get-ChildItem -Path $templatesDir -Directory | Where-Object { $_.Name -match '^v\d+$' } | Sort-Object { [int]($_.Name -replace 'v', '') } -Descending
if ($vFolders.Count -eq 0) {
    Write-Error "No template folders found in $templatesDir"
    exit 1
}

$latestVersionFolder = $vFolders[0]
$templatePath = "$($latestVersionFolder.FullName)\entity.md"
if (-not (Test-Path $templatePath)) {
    Write-Error "Template not found at $templatePath"
    exit 1
}

# 2. Determine target filename and key
$key = $Name
if (-not $key) {
    $base = "blank"
    $target = "$entitiesDir\$($latestVersionFolder.Name)\$base.md"
    if (-not (Test-Path $target)) {
        $key = $base
    } else {
        $i = 1
        while (Test-Path "$entitiesDir\$($latestVersionFolder.Name)\$base-$i.md") { $i++ }
        $key = "$base-$i"
    }
}

$targetPath = "$entitiesDir\$($latestVersionFolder.Name)\$key.md"

if (Test-Path $targetPath) {
    Write-Error "Entity '$key' already exists at $targetPath"
    exit 1
}

# 3. Read template and set the key field
$content = Get-Content $templatePath -Raw
# Replace 'key: ""' with 'key: "key"'
$content = $content -replace "(?m)^(key:)[ \t]*([^#\r\n]*)(#.*)?$", "`${1} `"$key`"  `$3"

# 4. Write new file
$content | Set-Content -Path $targetPath -Encoding UTF8 -NoNewline

Write-Host "Created new entity: $key  at $targetPath"

if (-not $NoBuild) {
    Write-Host "Updating index..."
    pwsh -File "$PSScriptRoot\build-index.ps1"
}

