# build-hierarchy.ps1
# Generates a visual hierarchy table from _index.csv
# Format: Each level of depth is its own column. Every entity gets its own row.

$strategyRoot = [System.IO.Path]::GetFullPath("$PSScriptRoot\..\..")
$entitiesDir  = "$strategyRoot\gardener\entities"
$indexCsv     = "$entitiesDir\_index.csv"
$outputCsv    = "$entitiesDir\_hierarchy.csv"

if (-not (Test-Path $indexCsv)) {
    Write-Error "Could not find _index.csv. Run build-index.ps1 first."
    return
}

# 1. Load Index
$csvRows = Import-Csv $indexCsv

# 2. Build Maps
$lookup = @{}
$children = @{} # ParentKey -> List of FileObjects
foreach ($row in $csvRows) {
    if (-not $row.Key) { continue }
    $lookup[$row.Key] = $row
    $pKey = $row.Parent; if (-not $pKey) { $pKey = "ROOT" }
    if (-not $children.ContainsKey($pKey)) { $children[$pKey] = @() }
    $children[$pKey] += $row
}

# 3. Dynamic Depth Calculation
$maxDepth = 1
$traversalData = New-Object System.Collections.Generic.List[PSObject]

function Traverse-Node($nodeKey, $depth) {
    $node = $lookup[$nodeKey]
    if (-not $node) { return }

    if ($depth -gt $script:maxDepth) { $script:maxDepth = $depth }
    
    $traversalData.Add([PSCustomObject]@{ Title = $node.Title; Depth = $depth })

    if ($children.ContainsKey($nodeKey)) {
        $sortedChildren = $children[$nodeKey] | Sort-Object Title
        foreach ($child in $sortedChildren) {
            Traverse-Node $child.Key ($depth + 1)
        }
    }
}

# 4. Process Roots
if ($children.ContainsKey("ROOT")) {
    $rootNodes = $children["ROOT"] | Sort-Object Title
    foreach ($root in $rootNodes) {
        Traverse-Node $root.Key 1
    }
}

# 5. Build Final Rows with Dynamic Columns
$hierarchyList = New-Object System.Collections.Generic.List[PSObject]
foreach ($item in $traversalData) {
    $rowObj = [ordered]@{}
    1..$maxDepth | ForEach-Object { $rowObj["L$_"] = "" }
    $rowObj["L$($item.Depth)"] = $item.Title
    $hierarchyList.Add([PSCustomObject]$rowObj)
}

# 6. Export
if ($hierarchyList.Count -gt 0) {
    $hierarchyList | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8
    Write-Host "Visual Hierarchy Generated ($($hierarchyList.Count) rows, Max Depth: $maxDepth): $outputCsv" -ForegroundColor Green
} else {
    Write-Warning "No nodes found to export."
}
