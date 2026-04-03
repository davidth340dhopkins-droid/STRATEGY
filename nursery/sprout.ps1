# nursery/sprout.ps1
# Promotes a seed project to a sprout by moving its document into a dedicated directory.
param(
    [Parameter(Mandatory=$true)]
    [string]$SeedPath,
    
    [switch]$Force
)

# 1. Resolve absolute path
if (-not (Test-Path $SeedPath)) {
    Write-Error "Seed file not found: $SeedPath"
    exit 1
}
$seed = Get-Item $SeedPath

# 2. Index Check
$content = Get-Content $seed.FullName -Raw
$isIndexed = $content -match "(?s)^---\s*\n.*?template_version:\s*\d+.*?\n---"

if (-not $isIndexed -and -not $Force) {
    $choice = Read-Host "Seed '$($seed.Name)' is currently unindexed. Index it first? (y/n)"
    if ($choice -eq 'y') {
        Write-Host "Indexing $($seed.Name)..."
        $strategyRoot = [System.IO.Path]::GetFullPath("$PSScriptRoot\..")
        $indexScript = Join-Path $strategyRoot "gardener\scripts\add-to-index.ps1"
        pwsh -File $indexScript -Files $seed.FullName
        # Refresh metadata
        $seed = Get-Item $seed.FullName
    }
}

# 3. Extract project name (remove leading underscore if present)
$name = $seed.BaseName -replace "^_", ""

# 4. Define the target sprout directory
$strategyRootPath = [System.IO.Path]::GetFullPath("$PSScriptRoot\..")
$sproutsDir = Join-Path $strategyRootPath "entities\sprouts"
$targetDir = Join-Path $sproutsDir $name

# 5. Create the target directory if it doesn't exist
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

# 6. Move the seed file into the sprout folder
$destination = Join-Path $targetDir $seed.Name
Move-Item -Path $seed.FullName -Destination $destination -Force

Write-Host "Success: Seed $($seed.Name) sprouted into $targetDir"
