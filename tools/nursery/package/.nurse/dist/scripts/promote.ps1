param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("merge", "a-test", "b-test", "dev")]
    [string]$From,

    [Parameter(Mandatory=$false)]
    [string]$To,

    [Parameter(Mandatory=$false)]
    [ValidateSet("major", "minor", "patch", "none")]
    [string]$Bump = "patch",
    
    [Parameter(Mandatory=$false)]
    [string]$Target = "core"
)

$current = $PSScriptRoot
$projectRoot = $null
while ($current) {
    if (Test-Path (Join-Path $current ".initialized")) { $projectRoot = $current; break }
    $parent = Split-Path $current -Parent
    if ($parent -eq $current) { break }
    $current = $parent
}
if ($null -eq $projectRoot) { $projectRoot = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent }

$pipelineDir  = Join-Path $projectRoot "pipeline"
$isFeature = ($Target -ne "core")

if ($isFeature) {
    $featureName = $Target -replace "^feature/", ""
    if ($From -eq "dev") { $From = "merge" }
    if ($To -eq "dev") { $To = "merge" }
}

if ([string]::IsNullOrWhiteSpace($To)) {
    switch ($From) {
        "merge"  { $To = "a-test" }
        "a-test" { $To = "b-test" }
        "b-test" { $To = "stable" }
        default  { throw "Cannot determine automatic promotion target for '$From'" }
    }
}

$isFeatureToCore = $isFeature -and $To -eq "merge"

if (-not $isFeature -and $From -ne "merge" -and -not $PSBoundParameters.ContainsKey('Bump')) {
    $Bump = "none"
}

if ($isFeatureToCore) {
    $fromBranch = "feature/$featureName/$From"
    $toBranch   = "core/merge"
} elseif ($isFeature) {
    $fromBranch = "feature/$featureName/$From"
    $toBranch   = "feature/$featureName/$To"
} else {
    $fromBranch = "core/$From"
    $toBranch   = "core/$To"
}

function Get-StageDir {
    param($stage, $isFeatureEnv)
    if ($isFeatureEnv -and $stage -eq "merge") { return "dev" }
    return $stage
}

$fromDir = Get-StageDir -stage $From -isFeatureEnv $isFeature
$toDir   = Get-StageDir -stage $To -isFeatureEnv ($isFeature -and -not $isFeatureToCore)

if ($isFeature) {
    $featureRoot = Join-Path (Join-Path $pipelineDir "feature") $featureName
}

if ($isFeatureToCore) {
    $fromPath = Join-Path $featureRoot $fromDir
    $toPath   = Join-Path $pipelineDir (Join-Path "core" $toDir)
} elseif ($isFeature) {
    $fromPath = Join-Path $featureRoot $fromDir
    $toPath   = Join-Path $featureRoot $toDir
} else {
    $fromPath = Join-Path $pipelineDir (Join-Path "core" $fromDir)
    $toPath   = Join-Path $pipelineDir (Join-Path "core" $toDir)
}

Write-Host "Context: $($isFeature ? 'Feature' : 'Core')" -ForegroundColor Gray
Write-Host "Promoting: $fromBranch → $toBranch" -ForegroundColor Cyan
Write-Host "Source Path: $fromPath" -ForegroundColor Gray
Write-Host "Target Path: $toPath" -ForegroundColor Gray

if (-not (Test-Path $toPath)) { Write-Error "Target worktree not found: $toPath"; exit 1 }

Push-Location $toPath
try {
    $dirty = git status --porcelain
    if ($dirty) {
        git add -A | Out-Null
        git commit -m "chore: auto-commit before promotion" | Out-Null
    }

    $coreVersionCache = ""
    $coreVersionFile = Join-Path $toPath "VERSION"
    $shouldCache = $isFeatureToCore -or (-not $isFeature -and $From -eq "merge")
    if ($shouldCache -and (Test-Path $coreVersionFile)) {
        $coreVersionCache = Get-Content $coreVersionFile -Raw
    }

    git merge $fromBranch --no-edit --allow-unrelated-histories -X theirs
    if ($LASTEXITCODE -ne 0) { Write-Error "Merge failed."; exit 1 }

    if ($shouldCache -and $coreVersionCache -ne "") {
        Set-Content -Path $coreVersionFile -Value $coreVersionCache -Encoding UTF8
        git add VERSION | Out-Null
        git commit --amend --no-edit | Out-Null
    }

    $versionFile    = Join-Path $toPath "VERSION"
    $currentVersion = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { "0.1.0" }

    if ($isFeature) { $Bump = "none" }

    if ($Bump -ne "none") {
        if ($isFeature) {
        if ($currentVersion -match '^(?<base>.+)\.(?<patch>\d+)$') {
            $base = $Matches['base']
            $patch = [int]$Matches['patch'] + 1
            $newVersion = "$base.$patch"
        } else {
            $newVersion = "$currentVersion.1"
        }
        } else {
            $parts = $currentVersion.Split('.')
            if ($parts.Count -ne 3) { $parts = @(0, 1, 0) }
            $major = [int]$parts[0]; $minor = [int]$parts[1]; $patch = [int]$parts[2]
            switch ($Bump) {
                "major" { $major++; $minor = 0; $patch = 0 }
                "minor" { $minor++; $patch = 0 }
                "patch" { $patch++ }
            }
            $newVersion = "$major.$minor.$patch"
        }
    } else {
        if (-not $isFeature -and $From -eq "merge") {
            $parts = $currentVersion.Split('.')
            if ($parts.Count -ne 3) { $parts = @(0, 1, 0) }
            $major = [int]$parts[0]; $minor = [int]$parts[1]; $patch = [int]$parts[2]
            $patch++
            $newVersion = "$major.$minor.$patch"
        } else {
            $newVersion = $currentVersion
        }
    }

    Set-Content -Path $versionFile -Value $newVersion -Encoding UTF8
    $tagName = "v$newVersion"
    if (-not $isFeature -and $To -ne "stable") { $tagName += "-$To" }

    if ($isFeatureToCore) {
        $manifestPath = Join-Path $toPath "FEATURES_MERGED.json"
        $featureVersionFile = Join-Path $fromPath "VERSION"
        $featureVersionStr = if(Test-Path $featureVersionFile) { (Get-Content $featureVersionFile -Raw).Trim() } else { "unknown" }
        
        $mergedList = @()
        if (Test-Path $manifestPath) {
            $rawJson = Get-Content $manifestPath -Raw
            if ([string]::IsNullOrWhiteSpace($rawJson)) { $rawJson = "[]" }
            $mergedList = @($rawJson | ConvertFrom-Json)
        }
        
        $existing = $mergedList | Where-Object { $_.name -eq $featureName }
        if ($existing) {
            $existing.version = $featureVersionStr
        } else {
            $mergedList += [pscustomobject]@{ name = $featureName; version = $featureVersionStr }
        }
        
        $mergedList | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath -Encoding UTF8
        git add FEATURES_MERGED.json | Out-Null
    }

    git add VERSION | Out-Null
    git commit -m "chore: promote $From to $To (v$newVersion)" | Out-Null
    git tag -f $tagName | Out-Null

    Write-Host "Successfully promoted to $To (Version: $newVersion)" -ForegroundColor Green

    if (-not $isFeature -and $From -eq "merge") {
        Push-Location $fromPath
        $manifestPathSrc = Join-Path $fromPath "FEATURES_MERGED.json"
        $srcVersionFile = Join-Path $fromPath "VERSION"
        Set-Content -Path $srcVersionFile -Value $newVersion -Encoding UTF8
        git add VERSION | Out-Null
        
        Set-Content -Path $manifestPathSrc -Value "[]" -Encoding UTF8
        git add FEATURES_MERGED.json | Out-Null
        
        git commit -m "chore: clear manifest and bump post-graduation" -q | Out-Null
        Pop-Location
    }
} finally {
    Pop-Location
}
