Import-Module "$PSScriptRoot\GardenerCore.psm1" -Force

function Export-IndexData {
    param(
        [array]$Rows,
        [int]$MaxVersionAcrossAll,
        [int]$UnformattedCount,
        [string[]]$IndexColumns,
        [string]$IndexCsv,
        [string]$IndexJson
    )

    $finalBuildCount = 1
    if (Test-Path $IndexJson) {
        $metaJson = [System.IO.File]::ReadAllText($IndexJson) | ConvertFrom-Json
        if ($metaJson -and [string]$metaJson.index_version -eq [string]$MaxVersionAcrossAll) { $finalBuildCount = [int]$metaJson.build_count + 1 }
    }

    $csvRows = $Rows | ForEach-Object {
        $rObj = $_; $orderedRow = [ordered]@{}
        foreach ($colName in $IndexColumns) { 
            $colLabel = ((Get-Culture).TextInfo.ToTitleCase($colName)) -replace '_', ' '
            $fieldVal = ""
            if ($colName -eq "key") { $fieldVal = $rObj.Key }
            elseif ($colName -eq "title") { $fieldVal = $rObj.Title }
            else { $fieldVal = Get-Field-Value -yaml $rObj.Yaml -name $colName }
            $orderedRow[$colLabel] = if (-not $fieldVal) { "" } else { $fieldVal -replace '\r?\n', ' ' }
        }
        $psObj = [PSCustomObject]$orderedRow; 
        $psObj | Add-Member NoteProperty Template "v$($rObj.TemplateVersion)" -Force
        $psObj | Add-Member NoteProperty File $rObj.File -Force
        $psObj
    } | Sort-Object Key

    $newCsvString = $csvRows | ConvertTo-Csv -NoTypeInformation | Out-String
    $oldCsvString = if (Test-Path $IndexCsv) { [System.IO.File]::ReadAllText($IndexCsv) } else { "" }
    if ($newCsvString.Trim() -cne $oldCsvString.Trim()) {
        $csvRows | Export-Csv -Path $IndexCsv -NoTypeInformation -Encoding UTF8
        Write-Host "CSV Updated." -ForegroundColor Cyan
    }

    $stats = [ordered]@{ 
        index_version = $MaxVersionAcrossAll; 
        build_count = $finalBuildCount; 
        managed_entities = $Rows.Count; 
        unformatted_entities = $UnformattedCount; 
        last_updated = (Get-Date -Format 'yyyy-MM-dd HH:mm') 
    }
    
    $oldJson = if (Test-Path $IndexJson) { [System.IO.File]::ReadAllText($IndexJson) } else { "" }
    $newMetaComp = [ordered]@{ index_version=$stats.index_version; managed_entities=$stats.managed_entities; unformatted_entities=$stats.unformatted_entities } | ConvertTo-Json -Depth 2
    $oldMetaComp = ""
    if ($oldJson) {
        $oldStats = $oldJson | ConvertFrom-Json
        $oldMetaComp = [ordered]@{ index_version=$oldStats.index_version; managed_entities=$oldStats.managed_entities; unformatted_entities=$oldStats.unformatted_entities } | ConvertTo-Json -Depth 2
    }

    if ($newMetaComp -ne $oldMetaComp) {
        $stats | ConvertTo-Json -Depth 2 | Set-Content $IndexJson -Encoding UTF8
        Write-Host "JSON Updated." -ForegroundColor Gray
    }
}

Export-ModuleMember -Function Export-IndexData
