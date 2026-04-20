Import-Module "$PSScriptRoot\GardenerCore.psm1" -Force

function Invoke-TemplateRender {
    param(
        [string[]]$SourceDirs,
        [int]$GlobalMaxTemplateVersion,
        [string]$TemplateDir,
        [string[]]$IndexColumns,
        [ref]$UnformattedCountRef
    )
    
    $rows = @()
    $localUnformattedCount = 0

    foreach ($dir in $SourceDirs) {
        if (-not (Test-Path $dir)) { continue }
        Get-ChildItem -Path $dir -Filter "*.md" | Where-Object { $_.Name -ne "index.md" -and $_.Name -ne "README.md" } | ForEach-Object {
            $f = $_; $cFull = [System.IO.File]::ReadAllText($f.FullName)
            if ($cFull -notmatch "(?s)^---\s*`r?`n(.+?)`r?`n---") { $localUnformattedCount++; return }
            $yamlInFile = $Matches[1]; $vt = Get-Field-Value -yaml $yamlInFile -name "template_version"
            if (-not $vt) { $localUnformattedCount++; return }
            $vNum = [int]$vt
            if ($GlobalMaxTemplateVersion -gt 0 -and $vNum -lt $GlobalMaxTemplateVersion) { $vNum = $GlobalMaxTemplateVersion }
            
            $tp = "$TemplateDir\v$vNum\entity.md"
            if (-not (Test-Path $tp)) { return }
            $tr = [System.IO.File]::ReadAllText($tp)
            $tb = $tr -replace "(?s)^---\s*`r?`n.+?`r?`n---", ""
            
            $templateYaml = ""
            if ($tr -match "(?s)^---\s*`r?`n(.+?)`r?`n---") { $templateYaml = $Matches[1] }

            $vMap = @{}
            foreach ($col in $IndexColumns) { $vMap[$col] = Get-Field-Value -yaml $yamlInFile -name $col }
            
            $vMap["children"] = Get-Field-Value -yaml $yamlInFile -name "children"
            
            if ($null -eq $vMap["parent"] -or $vMap["parent"] -eq "") {
                $mVal = Get-Field-Value -yaml $yamlInFile -name "master"
                if ($mVal) { $vMap["parent"] = $mVal }
            }

            if ($null -eq $vMap["trend_notes"] -or $vMap["trend_notes"] -eq "") {
                $tVal = Get-Field-Value -yaml $yamlInFile -name "trends"
                if ($tVal) { $vMap["trend_notes"] = $tVal }
            }

            if ($null -eq $vMap["benefit_notes"] -or $vMap["benefit_notes"] -eq "") {
                $bVal = Get-Field-Value -yaml $yamlInFile -name "benefits"
                if ($bVal) { $vMap["benefit_notes"] = $bVal }
            }

            @("primary", "secondary", "tertiary") | ForEach-Object {
                $oldP = $_; $newP = if ($_ -eq "primary") { "first" } elseif ($_ -eq "secondary") { "second" } else { "third" }
                @("title", "description", "reference") | ForEach-Object {
                    $oldKey = "trend_${oldP}_${_}"; $newKey = "${newP}_trend_${_}"
                    if (-not $vMap[$newKey]) {
                        $val = Get-Field-Value -yaml $yamlInFile -name $oldKey
                        if ($val) { $vMap[$newKey] = $val }
                    }
                }
            }

            $bodyContent = $tb
            foreach ($p in ([regex]::Matches($bodyContent, '\{\{([^}]+)\}\}') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)) {
                $val = $vMap[$p]; if (-not $val) { $val = "<!-- No ${p} specified -->" }
                $bodyContent = $bodyContent.Replace("{{" + $p + "}}", $val)
            }

            $newYaml = $templateYaml; $placedKeys = @{}
            foreach ($line in ($templateYaml -split "`r?`n")) {
                if ($line -match "^(?i)([a-zA-Z0-9_\-]+):") {
                    $colKey = $Matches[1].ToLower()
                    if ($vMap.ContainsKey($colKey)) {
                        $finalVal = $vMap[$colKey]
                        if ($colKey -eq "template_version") { $finalVal = "$vNum" }
                        $newYaml = Update-Yaml-String -yaml $newYaml -name $colKey -value $finalVal
                        $placedKeys[$colKey] = $true
                    }
                }
            }
            $appendLines = @()
            foreach ($colKey in $IndexColumns) {
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
            $strategyRootRelative = [System.IO.Path]::GetFullPath("$TemplateDir\..\..\..")
            $outputDirAbs = [System.IO.Path]::GetFullPath("$strategyRootRelative\tools\gardener\entities")
            
            $rows += [PSCustomObject]@{
                File = [System.IO.Path]::GetRelativePath($outputDirAbs, $finalPath).Replace("\", "/");
                Key = $kVal; Title = $rowTitle;
                TemplateVersion = $vNum; Yaml = $newYaml
            }
        }
    }
    
    $UnformattedCountRef.Value += $localUnformattedCount
    return $rows
}

Export-ModuleMember -Function Invoke-TemplateRender
