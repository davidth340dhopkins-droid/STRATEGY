param([switch]$Cleanup, [switch]$KeepBin)

$strategyRoot = [System.IO.Path]::GetFullPath("$PSScriptRoot\..\..\..")
$entitiesDir  = "$strategyRoot\entities"
$seedsDir     = "$entitiesDir\seeds"
$sproutsDir   = "$entitiesDir\sprouts"
$templateDir = "$strategyRoot\tools\gardener\template"
$outputDir    = "$strategyRoot\tools\gardener\entities"
$indexCsv     = "$outputDir\index.csv"
$indexJson    = "$outputDir\index.json"
$indexMd      = "$outputDir\index.md" 

Import-Module "$PSScriptRoot\modules\GardenerCore.psm1" -Force
Import-Module "$PSScriptRoot\modules\SyncMaster.psm1" -Force
Import-Module "$PSScriptRoot\modules\TemplateRenderer.psm1" -Force
Import-Module "$PSScriptRoot\modules\StatsProvider.psm1" -Force

$IndexColumns = @("key", "title", "type", "parent")
$ExcludeColumns = @("key", "title", "schema_version", "template_version", "template", "type", "parent", "children")

# Identify latest template and baseline columns
$globalMaxTemplateVersion = 0
$latestTemplate = Get-ChildItem -Path $templateDir -Directory | Where-Object { $_.Name -match "^v\d+$" } | Sort-Object { [int]($_.Name -replace "v","") } -Descending | Select-Object -First 1

if ($null -ne $latestTemplate) {
    $globalMaxTemplateVersion = [int]($latestTemplate.Name -replace "v","")
    $latestTemplateContent = [System.IO.File]::ReadAllText("$($latestTemplate.FullName)\entity.md")
    if ($latestTemplateContent -match "(?s)^---\s*[\r\n]+(.+?)[\r\n]+---") {
        $yamlBlock = $Matches[1]
        foreach ($line in ($yamlBlock -split "[\r\n]+")) {
            if ($line -match '^([a-zA-Z0-9_\-]+):') {
                $foundCol = $Matches[1].ToLower()
                if ($foundCol -notin $ExcludeColumns -and $foundCol -notin $IndexColumns) {
                    $IndexColumns += $foundCol
                }
            }
        }
    }
}

# --- Preparation ---
$sourceDirs = @($seedsDir)
if (Test-Path $sproutsDir) {
    $subDirs = Get-ChildItem -Path $sproutsDir -Directory | Select-Object -ExpandProperty FullName
    if ($subDirs) { $sourceDirs += $subDirs }
}
$latestFiles = Get-ChildItem -Path $sourceDirs -Filter "*.md" -Recurse | Where-Object { $_.Name -ne "index.md" -and $_.Name -ne "README.md" }
$mostRecentFileTime = if ($latestFiles) { ($latestFiles | Measure-Object -Property LastWriteTime -Maximum).Maximum } else { [datetime]::MinValue }

# --- Phase 1: Bidirectional Sync (CSV -> Files) ---
$syncResult = Invoke-BidirectionalSync -IndexCsv $indexCsv -OutputDir $outputDir -EntitiesDir $entitiesDir -IndexColumns $IndexColumns -ExcludeColumns $ExcludeColumns -MostRecentFileTime $mostRecentFileTime
$IndexColumns = @($syncResult.IndexColumns)
$mostRecentFileTime = $syncResult.MostRecentFileTime

Start-Sleep -Milliseconds 500

# --- Phase 1.5: Children Write-Back ---
Invoke-ChildrenSync -SourceDirs $sourceDirs

Start-Sleep -Milliseconds 500

# --- Phase 2: Render & Refresh ---
$unformattedCountObj = [ref]0
$rows = Invoke-TemplateRender -SourceDirs $sourceDirs -GlobalMaxTemplateVersion $globalMaxTemplateVersion -TemplateDir $templateDir -IndexColumns $IndexColumns -UnformattedCountRef $unformattedCountObj
$unformattedCount = $unformattedCountObj.Value

$rows = $rows | Sort-Object { [int]$_.TemplateVersion } -Descending | Group-Object -Property key | ForEach-Object { $_.Group[0] }
$maxVersionAcrossAll = if ($rows) { ($rows | Measure-Object -Property TemplateVersion -Maximum).Maximum } else { 0 }

# --- Phase 3: CSV Output ---
if ($maxVersionAcrossAll -gt 0) {
    Export-IndexData -Rows @($rows) -MaxVersionAcrossAll $maxVersionAcrossAll -UnformattedCount $unformattedCount -IndexColumns $IndexColumns -IndexCsv $indexCsv -IndexJson $indexJson
    Write-Host "Index Sync Complete ($($rows.Count) entities)." -ForegroundColor Green
    if (Test-Path $indexMd) { Remove-Item $indexMd -Force }
} else {
    Write-Host "No templated entities found to build index." -ForegroundColor Yellow
}
