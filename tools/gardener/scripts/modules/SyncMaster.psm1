Import-Module "$PSScriptRoot\GardenerCore.psm1" -Force

function Invoke-BidirectionalSync {
    param(
        [string]$IndexCsv,
        [string]$OutputDir,
        [string]$EntitiesDir,
        [string[]]$IndexColumns,
        [string[]]$ExcludeColumns,
        [datetime]$MostRecentFileTime
    )
    
    $newColumns = @()
    foreach ($c in $IndexColumns) { $newColumns += $c }
    $updatedTime = $MostRecentFileTime

    if (Test-Path $IndexCsv) {
        $firstLine = (Get-Content $IndexCsv -TotalCount 1)
        if ($firstLine -match '^"(.*)"$') {
            foreach ($c in ($Matches[1] -split '","')) {
                $cl = ($c.ToLower()) -replace ' ', '_'
                if ($cl -notin $newColumns -and $cl -notin $ExcludeColumns -and $cl -ne "file" -and $cl -ne "master") { $newColumns += $cl }
            }
        }
        $csvItem = Get-Item $IndexCsv
        if ($csvItem.LastWriteTime -gt $MostRecentFileTime) {
            Write-Host "CSV is newer. Propagating updates..." -ForegroundColor Yellow
            $csvRows = Import-Csv $IndexCsv
            foreach ($cr in $csvRows) {
                if (-not $cr.File -or -not $cr.Key) { continue }
                $abs = [System.IO.Path]::GetFullPath("$OutputDir\$($cr.File)")
                
                if (-not (Test-Path $abs)) {
                    $possible = Get-ChildItem -Path $EntitiesDir -Filter "_$($cr.Key).md" -Recurse | Select-Object -First 1
                    if ($possible) {
                        Write-Host "    [HEAL] Found stale path for '$($cr.Key)'. Redirecting to $($possible.Name)" -ForegroundColor Cyan
                        $abs = $possible.FullName
                    }
                }

                if (Test-Path $abs) {
                    $raw = [System.IO.File]::ReadAllText($abs)
                    if ($raw -match "(?s)^---\s*`r?`n(.+?)`r?`n---") {
                        $yaml = $Matches[1]; $newYaml = $yaml; $changed = $false
                        foreach ($col in $newColumns) {
                            $colH = ((Get-Culture).TextInfo.ToTitleCase($col)) -replace '_', ' '
                            $csvVal = ""
                            if ($col -eq "parent" -and $null -ne $cr.Parent) { $csvVal = $cr.Parent }
                            elseif ($col -eq "parent" -and $null -ne $cr.Master) { $csvVal = $cr.Master }
                            else { $csvVal = $cr.$colH }
                            
                            $csvVal = ($csvVal -replace "^-$", "")
                            $curVal = Get-Field-Value -yaml $yaml -name $col
                            if ($csvVal -cne $curVal) {
                                $changed = $true; Write-Host "    [PROP] $($cr.Key).${col}: '$curVal' -> '$csvVal'" -ForegroundColor Gray
                                $newYaml = Update-Yaml-String -yaml $newYaml -name $col -value $csvVal
                            }
                        }
                        if ($changed) {
                            $full = $raw -replace "(?s)^---\s*`r?`n.+?`r?`n---", ("---`r`n" + $newYaml + "`r`n---")
                            [System.IO.File]::WriteAllText($abs, ($full -replace "(?<!`r)`n", "`r`n"), (New-Object System.Text.UTF8Encoding $false))
                        }
                    }
                }
            }
            $updatedTime = (Get-Date)
        }
    }

    return @{
        IndexColumns = $newColumns
        MostRecentFileTime = $updatedTime
    }
}

function Invoke-ChildrenSync {
    param(
        [string[]]$SourceDirs
    )
    $allFilesForChildren = Get-ChildItem -Path $SourceDirs -Filter "*.md" -Recurse | Where-Object { $_.Name -ne "index.md" -and $_.Name -ne "README.md" }
    $parentToChildren = @{}
    foreach ($f in $allFilesForChildren) {
        $raw = [System.IO.File]::ReadAllText($f.FullName)
        if ($raw -match "(?s)^---\s*`r?`n(.+?)`r?`n---") {
            $yamlObj = $Matches[1]
            $myTitle = Get-Field-Value -yaml $yamlObj -name "title"
            $myParent = Get-Field-Value -yaml $yamlObj -name "parent"
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
            $myTitle = Get-Field-Value -yaml $yamlObj -name "title"
            if (-not $myTitle) { $myTitle = $f.BaseName -replace "^_", "" }
            
            $myChildren = ""
            if ($parentToChildren.ContainsKey($myTitle)) {
                $myChildrenList = $parentToChildren[$myTitle] | Sort-Object
                $myChildren = $myChildrenList -join ", "
            }
            
            $currentChildren = Get-Field-Value -yaml $yamlObj -name "children"
            if ($currentChildren -cne $myChildren) {
                $newYaml = Update-Yaml-String -yaml $yamlObj -name "children" -value $myChildren
                $full = $raw -replace "(?s)^---\s*`r?`n.+?`r?`n---", ("---`r`n" + $newYaml + "`r`n---")
                [System.IO.File]::WriteAllText($f.FullName, ($full -replace "(?<!`r)`n", "`r`n"), (New-Object System.Text.UTF8Encoding $false))
                Write-Host "    [CHILDREN] Updated children for '$myTitle'" -ForegroundColor Gray
            }
        }
    }
}

Export-ModuleMember -Function Invoke-BidirectionalSync, Invoke-ChildrenSync
