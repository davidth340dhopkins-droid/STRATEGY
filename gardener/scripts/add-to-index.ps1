# add-to-index.ps1
# Takes unformatted freeform entities, converts them using the latest gardener template, 
# and kicks off build-index.ps1 so they are incorporated immediately.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
    [string[]]$Files,
    
    [switch]$All,
    [switch]$NoPreserve
)

$strategyRoot  = [System.IO.Path]::GetFullPath("$PSScriptRoot\..\..")
$templatesDir  = "$strategyRoot\gardener\_templates"
$seedsDir      = "$strategyRoot\entities\seeds"

if ($All) {
    if ($null -eq $Files) { $Files = @() }
    $unindexed = Get-ChildItem -Path $seedsDir -Filter "*.md" | Where-Object { $_.Name -ne "_index.md" -and $_.Name -ne "README.md" } | Where-Object {
        $content = Get-Content $_.FullName -Raw
        return ($content -notmatch "(?s)^---\s*\n.*?template_version:\s*\d+.*?\n---")
    } | Select-Object -ExpandProperty FullName
    
    if ($unindexed) {
        $Files += $unindexed
    } else {
        Write-Host "No unindexed seeds found in $seedsDir."
    }
}

if (-not $Files -or $Files.Count -eq 0) {
    Write-Error "Must provide -Files <paths> or use the -All flag to process all unformatted seeds."
    exit
}

# Dynamically find the latest template version
$latestTemplate = Get-ChildItem -Path $templatesDir -Directory | Where-Object { $_.Name -match '^v\d+$' } | Select-Object @{Name="Ver"; Expression={[int]($_.Name -replace 'v','')}} | Sort-Object Ver -Descending | Select-Object -First 1

if (-not $latestTemplate) { 
    Write-Error "No templates found in gardener/_templates!"
    exit 
}

$templateVersion = $latestTemplate.Ver
$templateContent = Get-Content "$templatesDir\v$templateVersion\entity.md" -Raw

foreach ($filePath in $Files) {
    if (-not (Test-Path $filePath)) { 
        # Attempt relative resolution
        $resolved = Join-Path (Get-Location) $filePath
        if (-not (Test-Path $resolved)) {
            Write-Warning "File not found: $filePath"
            continue
        }
        $filePath = $resolved
    }

    $file = Get-Item $filePath
    $rawContent = Get-Content $file.FullName -Raw

    if ($rawContent -match "(?s)^---\s*\n.*?template_version:\s*\d+.*?\n---") {
        Write-Warning "Skipping $($file.Name): Document already formatted with a template_version."
        continue
    }

    # Base key extraction
    $key = $file.BaseName -replace "^_", ""
    
    # Extract structural chunks from the blank template
    $newYaml = if ($templateContent -match "(?s)^---\s*\n(.+?)\n---") { $Matches[1] } else { "" }
    $newBody = $templateContent -replace "(?s)^---\s*\n.+?\n---\s*\n", ""
    
    # Pre-inject the filename key safely into the YAML header where applicable
    $newYaml = $newYaml -replace '(?m)^(key:\s*)[^\r\n]*', "`${1}`"$key`""
    $newYaml = $newYaml -replace '(?m)^(title:\s*)[^\r\n]*', "`${1}`"$key`""
    
    $newContent = "---`n$newYaml`n---`n`n$newBody"

    # Append original data silently if requested
    if (-not $NoPreserve) {
        # Clean potential unescaped HTML comment closers
        $safeOriginal = $rawContent -replace "-->", "->" 
        $newContent += "`n`n<!-- === ORIGINAL SEED DOCUMENT ===`n$safeOriginal`n================================== -->"
    }

    # Apply proper line endings and rewrite the file
    $newContent = $newContent -replace "(?<!`r)`n", "`r`n"
    $newContent | Set-Content $file.FullName -Encoding UTF8 -NoNewline
    
    Write-Host "Success: Seed $($file.Name) refitted with template v$templateVersion"
}

Write-Host "Triggering build-index to catalog new entities..."
& "$PSScriptRoot\build-index.ps1"
