# build-index.ps1
# Manages the entity database. Reformats templated entities in-place (seeds or sprouts)
# outputs a comprehensive _index.csv with all dynamic YAML fields.
# Handles bidirectional sync: propagates CSV edits back to source Markdown files.

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

function Get-Field-Value($yaml, $name) {
    if (-not $yaml) { return "" }
    
    # 1. Try Triple Single Quote block (supports multi-line across rows)
    # Using (?smi) to ensure '^' matches line starts AND '.' matches newlines.
    $triplePattern = "(?smi)^" + [regex]::Escape($name) + ":\s*'''(.*?)'''"
    if ($yaml -match $triplePattern) {
        return $Matches[1].Trim()
    }

    # 2. Try standard single-line
    $pattern = "(?mi)^" + [regex]::Escape($name) + ':\s*(?:["'']?)([^#\r\n]*?)(?:["'']?)\s*(?:#.*)?$'
    if ($yaml -match $pattern) {
        $ms = [regex]::Matches($yaml, $pattern)
        if ($ms.Count -gt 0) {
            $v = $ms[$ms.Count - 1].Groups[1].Value.Trim().Trim('"').Trim("'")
            if ($v -eq "-") { return "" }
            return $v
        }
    }
    return ""
}

function Update-Yaml-String($yaml, $name, $value) {
    # Prefer Triple Single Quote for multi-line or mixed quotes
    $vStr = if ($value -match "[\r\n]" -or $value -match '["'']') {
        "'''`n${value}`n'''" 
    } else {
        "`"${value}`""
    }
    $lines = $yaml -split "`r?`n"
    $found = $false
    for ($i=0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ("^(?i)" + [regex]::Escape($name) + ":")) {
            $origName = $lines[$i] -replace "^([^:]+):.*$", '$1'
            $lines[$i] = "${origName}: ${vStr}"
            $found = $true
        }
    }
    if ($found) { return $lines -join "`r`n" }
    return ($yaml.TrimEnd() + "`r`n${name}: ${vStr}")
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
if (Test-Path $indexCsv) {
    $firstLine = (Get-Content $indexCsv -TotalCount 1)
    if ($firstLine -match '^"(.*)"$') {
        foreach ($c in ($Matches[1] -split '","')) {
            $cl = ($c.ToLower()) -replace ' ', '_'
            if ($cl -notin $IndexColumns -and $cl -notin $ExcludeColumns -and $cl -ne "file" -and $cl -ne "master") { $IndexColumns += $cl }
        }
    }
    $csvItem = Get-Item $indexCsv
    if ($csvItem.LastWriteTime -gt $mostRecentFileTime) {
        Write-Host "CSV is newer. Propagating updates..." -ForegroundColor Yellow
        $csvRows = Import-Csv $indexCsv
        foreach ($cr in $csvRows) {
            if (-not $cr.File -or -not $cr.Key) { continue }
            $abs = [System.IO.Path]::GetFullPath("$outputDir\$($cr.File)")
            
            # --- Proactive File Lookup (Rename Resilience) ---
            if (-not (Test-Path $abs)) {
                $possible = Get-ChildItem -Path $entitiesDir -Filter "_$($cr.Key).md" -Recurse | Select-Object -First 1
                if ($possible) {
                    Write-Host "    [HEAL] Found stale path for '$($cr.Key)'. Redirecting to $($possible.Name)" -ForegroundColor Cyan
                    $abs = $possible.FullName
                }
            }

            if (Test-Path $abs) {
                $raw = [System.IO.File]::ReadAllText($abs)
                if ($raw -match "(?s)^---\s*`r?`n(.+?)`r?`n---") {
                    $yaml = $Matches[1]; $newYaml = $yaml; $changed = $false
                    foreach ($col in $IndexColumns) {
                        $colH = ((Get-Culture).TextInfo.ToTitleCase($col)) -replace '_', ' '
                        
                        # Handle Rename Migration (Master -> Parent)
                        $csvVal = ""
                        if ($col -eq "parent" -and $null -ne $cr.Parent) { $csvVal = $cr.Parent }
                        elseif ($col -eq "parent" -and $null -ne $cr.Master) { $csvVal = $cr.Master }
                        else { $csvVal = $cr.$colH }
                        
                        $csvVal = ($csvVal -replace "^-$", "")
                        $curVal = Get-Field-Value $yaml $col
                        if ($csvVal -cne $curVal) {
                            $changed = $true; Write-Host "    [PROP] $($cr.Key).${col}: '$curVal' -> '$csvVal'" -ForegroundColor Gray
                            $newYaml = Update-Yaml-String $newYaml $col $csvVal
                        }
                    }
                    if ($changed) {
                        $full = $raw -replace "(?s)^---\s*`r?`n.+?`r?`n---", ("---`r`n" + $newYaml + "`r`n---")
                        [System.IO.File]::WriteAllText($abs, ($full -replace "(?<!`r)`n", "`r`n"), (New-Object System.Text.UTF8Encoding $false))
                    }
                }
            }
        }
        $mostRecentFileTime = (Get-Date)
    }
}

# Settling delay to avoid stale disk reads/locks during multi-phase sync
Start-Sleep -Milliseconds 500

# --- Phase 1.5: Children Write-Back ---
$allFilesForChildren = Get-ChildItem -Path $sourceDirs -Filter "*.md" -Recurse | Where-Object { $_.Name -ne "index.md" -and $_.Name -ne "README.md" }
$parentToChildren = @{}
foreach ($f in $allFilesForChildren) {
    $raw = [System.IO.File]::ReadAllText($f.FullName)
    if ($raw -match "(?s)^---\s*`r?`n(.+?)`r?`n---") {
        $yamlObj = $Matches[1]
        $myTitle = Get-Field-Value $yamlObj "title"
        $myParent = Get-Field-Value $yamlObj "parent"
        if (-not $myTitle) { $myTitle = $f.BaseName -replace "^_", "" }
        if ($myParent) {
            if (-not $parentToChildren.ContainsKey($myParent)) { $parentToChildren[$myParent] = @() }
            if ($myTitle -notin $parentToChildren[$myParent]) { $parentToChildren[$myParent] += $myTitle }
        }
    }
}

foreach ($f in $allFilesForChildren) {
    $raw = [System.IO.File]::ReadAllText($f.FullName)
    if ($raw -match "(?s)^---\s*`r?`n(.+?)`r?`n---") {
        $yamlObj = $Matches[1]
        $myTitle = Get-Field-Value $yamlObj "title"
        if (-not $myTitle) { $myTitle = $f.BaseName -replace "^_", "" }
        
        $myChildren = ""
        if ($parentToChildren.ContainsKey($myTitle)) {
            $myChildrenList = $parentToChildren[$myTitle] | Sort-Object
            $myChildren = $myChildrenList -join ", "
        }
        
        $currentChildren = Get-Field-Value $yamlObj "children"
        if ($currentChildren -cne $myChildren) {
            $newYaml = Update-Yaml-String $yamlObj "children" $myChildren
            $full = $raw -replace "(?s)^---\s*`r?`n.+?`r?`n---", ("---`r`n" + $newYaml + "`r`n---")
            [System.IO.File]::WriteAllText($f.FullName, ($full -replace "(?<!`r)`n", "`r`n"), (New-Object System.Text.UTF8Encoding $false))
            Write-Host "    [CHILDREN] Updated children for '$myTitle'" -ForegroundColor Gray
        }
    }
}

# Settling delay after writing back children to make sure phase 2 has the updated files
Start-Sleep -Milliseconds 500

# --- Phase 2: Render & Refresh ---
$rows = @(); $unformattedCount = 0
foreach ($dir in $sourceDirs) {
    if (-not (Test-Path $dir)) { continue }
    Get-ChildItem -Path $dir -Filter "*.md" | Where-Object { $_.Name -ne "index.md" -and $_.Name -ne "README.md" } | ForEach-Object {
        $f = $_; $cFull = [System.IO.File]::ReadAllText($f.FullName)
        if ($cFull -notmatch "(?s)^---\s*`r?`n(.+?)`r?`n---") { $script:unformattedCount++; return }
        $yamlInFile = $Matches[1]; $vt = Get-Field-Value $yamlInFile "template_version"
        if (-not $vt) { $script:unformattedCount++; return }
        $vNum = [int]$vt
        if ($globalMaxTemplateVersion -gt 0 -and $vNum -lt $globalMaxTemplateVersion) { $vNum = $globalMaxTemplateVersion }
        
        $tp = "$templateDir\v$vNum\entity.md"
        if (-not (Test-Path $tp)) { return }
        $tr = [System.IO.File]::ReadAllText($tp)
        $tb = $tr -replace "(?s)^---\s*`r?`n.+?`r?`n---", ""
        
        $templateYaml = ""
        if ($tr -match "(?s)^---\s*`r?`n(.+?)`r?`n---") { $templateYaml = $Matches[1] }

        $vMap = @{}
        foreach ($col in $IndexColumns) { $vMap[$col] = Get-Field-Value $yamlInFile $col }
        
        # Explicitly retain derived fields not in IndexColumns
        $vMap["children"] = Get-Field-Value $yamlInFile "children"
        
        # Data Migration Logic: master -> parent
        if ($null -eq $vMap["parent"] -or $vMap["parent"] -eq "") {
            $mVal = Get-Field-Value $yamlInFile "master"
            if ($mVal) { $vMap["parent"] = $mVal }
        }

        # Data Migration Logic: trends -> trend_notes
        if ($null -eq $vMap["trend_notes"] -or $vMap["trend_notes"] -eq "") {
            $tVal = Get-Field-Value $yamlInFile "trends"
            if ($tVal) { $vMap["trend_notes"] = $tVal }
        }

        # Data Migration Logic: benefits -> benefit_notes
        if ($null -eq $vMap["benefit_notes"] -or $vMap["benefit_notes"] -eq "") {
            $bVal = Get-Field-Value $yamlInFile "benefits"
            if ($bVal) { $vMap["benefit_notes"] = $bVal }
        }

        # Data Migration Logic: trend_primary_... -> first_trend_...
        @("primary", "secondary", "tertiary") | ForEach-Object {
            $oldP = $_; $newP = if ($_ -eq "primary") { "first" } elseif ($_ -eq "secondary") { "second" } else { "third" }
            @("title", "description", "reference") | ForEach-Object {
                $oldKey = "trend_${oldP}_${_}"; $newKey = "${newP}_trend_${_}"
                if (-not $vMap[$newKey]) {
                    $val = Get-Field-Value $yamlInFile $oldKey
                    if ($val) { $vMap[$newKey] = $val }
                }
            }
        }

        $bodyContent = $tb
        foreach ($p in ([regex]::Matches($bodyContent, '\{\{([^}]+)\}\}') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)) {
            $val = $vMap[$p]; if (-not $val) { $val = "_No ${p}._" }
            $bodyContent = $bodyContent.Replace("{{" + $p + "}}", $val)
        }

        $newYaml = $templateYaml; $placedKeys = @{}
        foreach ($line in ($templateYaml -split "`r?`n")) {
            if ($line -match "^(?i)([a-zA-Z0-9_\-]+):") {
                $colKey = $Matches[1].ToLower()
                if ($vMap.ContainsKey($colKey)) {
                    $finalVal = $vMap[$colKey]
                    if ($colKey -eq "template_version") { $finalVal = "$vNum" }
                    $newYaml = Update-Yaml-String $newYaml $colKey $finalVal
                    $placedKeys[$colKey] = $true
                }
            }
        }
        $appendLines = @()
        foreach ($colKey in $IndexColumns) {
            # Skip placed keys, empty values, AND ghost master/template/trends
            if ($placedKeys.ContainsKey($colKey) -or -not $vMap[$colKey] -or $colKey -eq "master" -or $colKey -eq "template" -or $colKey -eq "trends") { continue }
            $appendLines += "${colKey}: `"$($vMap[$colKey])`""
        }
        if ($appendLines.Count -gt 0) { $newYaml = $newYaml.TrimEnd() + "`r`n" + ($appendLines -join "`r`n") }

        $seedMarker = ""; if ($cFull -match "(?s)(<!-- === ORIGINAL SEED DOCUMENT ===.+?================================== -->)") { $seedMarker = "`r`n`r`n" + $Matches[1] }
        $finalOutput = "---`r`n" + $newYaml + "`r`n---`r`n`r`n" + $bodyContent + $seedMarker
        
        $kVal = ($vMap["key"]) -replace "^_", ""; if (-not $kVal) { $kVal = $f.BaseName -replace "^_", "" }
        $finalPath = "$($f.DirectoryName)\_$kVal.md"
        if (-not (Test-Path -LiteralPath $finalPath) -or ([System.IO.File]::ReadAllText($finalPath) -ne $finalOutput)) {
            [System.IO.File]::WriteAllText($finalPath, ($finalOutput -replace "(?<!`r)`n", "`r`n"), (New-Object System.Text.UTF8Encoding $false))
            Write-Host "  Rendered: $($f.Name)" -ForegroundColor Cyan
        }
        if ($f.FullName -ne $finalPath -and $f.FullName.ToLower() -ne $finalPath.ToLower()) {
            if (Test-Path $finalPath) { Remove-Item -LiteralPath $finalPath -Force }
            Move-Item -LiteralPath $f.FullName -Destination $finalPath -Force
        }

        $rowTitle = $kVal; if ($vMap["title"]) { $rowTitle = $vMap["title"] }
        $rows += [PSCustomObject]@{
            File = [System.IO.Path]::GetRelativePath($outputDir, $finalPath).Replace("\", "/");
            Key = $kVal; Title = $rowTitle;
            TemplateVersion = $vNum; Yaml = $newYaml
        }
    }
}

$rows = $rows | Sort-Object { [int]$_.TemplateVersion } -Descending | Group-Object -Property key | ForEach-Object { $_.Group[0] }
$maxVersionAcrossAll = ($rows | Measure-Object -Property TemplateVersion -Maximum).Maximum
if (-not $maxVersionAcrossAll) { return }

# --- Phase 3: CSV Output ---
$finalBuildCount = 1
if (Test-Path $indexJson) {
    $metaJson = [System.IO.File]::ReadAllText($indexJson) | ConvertFrom-Json
    if ($metaJson -and [string]$metaJson.index_version -eq [string]$maxVersionAcrossAll) { $finalBuildCount = [int]$metaJson.build_count + 1 }
}

$csvRows = $rows | ForEach-Object {
    $rObj = $_; $orderedRow = [ordered]@{}
    foreach ($colName in $IndexColumns) { 
        $colLabel = ((Get-Culture).TextInfo.ToTitleCase($colName)) -replace '_', ' '
        
        $fieldVal = ""
        if ($colName -eq "key") { $fieldVal = $rObj.Key }
        elseif ($colName -eq "title") { $fieldVal = $rObj.Title }
        else { $fieldVal = Get-Field-Value $rObj.Yaml $colName }
        $orderedRow[$colLabel] = if (-not $fieldVal) { "" } else { $fieldVal -replace '\r?\n', ' ' }
    }
    $psObj = [PSCustomObject]$orderedRow; 
    $psObj | Add-Member NoteProperty Template "v$($rObj.TemplateVersion)" -Force
    $psObj | Add-Member NoteProperty File $rObj.File -Force
    $psObj
} | Sort-Object Key

# Conditional CSV Write (to avoid watcher loops)
$newCsvString = $csvRows | ConvertTo-Csv -NoTypeInformation | Out-String
$oldCsvString = if (Test-Path $indexCsv) { [System.IO.File]::ReadAllText($indexCsv) } else { "" }
if ($newCsvString.Trim() -cne $oldCsvString.Trim()) {
    $csvRows | Export-Csv -Path $indexCsv -NoTypeInformation -Encoding UTF8
    Write-Host "CSV Updated (Self-Healed Pathing)." -ForegroundColor Cyan
}

# Conditional JSON Write
$stats = [ordered]@{ index_version=[int]$maxVersionAcrossAll; build_count=[int]$finalBuildCount; managed_entities=$rows.Count; unformatted_entities=$script:unformattedCount; last_updated=Get-Date -Format 'yyyy-MM-dd HH:mm' }
$oldJson = if (Test-Path $indexJson) { [System.IO.File]::ReadAllText($indexJson) } else { "" }

$newMetaComp = [ordered]@{ index_version=$stats.index_version; managed_entities=$stats.managed_entities; unformatted_entities=$stats.unformatted_entities } | ConvertTo-Json
$oldMetaComp = ""
if ($oldJson) {
    $oldStats = $oldJson | ConvertFrom-Json
    $oldMetaComp = [ordered]@{ index_version=$oldStats.index_version; managed_entities=$oldStats.managed_entities; unformatted_entities=$oldStats.unformatted_entities } | ConvertTo-Json
}

if ($newMetaComp -ne $oldMetaComp) {
    $stats | ConvertTo-Json | Set-Content $indexJson -Encoding UTF8
    Write-Host "JSON Updated." -ForegroundColor Gray
}

Write-Host "Index Sync Complete ($($rows.Count) entities)." -ForegroundColor Green
if (Test-Path $indexMd) { Remove-Item $indexMd -Force }
