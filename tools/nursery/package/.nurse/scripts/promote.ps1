# .nurse/scripts/promote.ps1
# Promotes changes from one pipeline tier to the next, bumps version, and tags.

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("merge", "a-test", "b-test", "dev")]
    [string]$From,

    [Parameter(Mandatory=$false)]
    [string]$To,

    [Parameter(Mandatory=$false)]
    [ValidateSet("major", "minor", "patch", "none")]
    [string]$Bump = "patch"
)

$nurseryDir = $PSScriptRoot | Split-Path -Parent
$sproutDir  = $nurseryDir   | Split-Path -Parent

# Determine if we're in a feature context
$isFeature = $nurseryDir -match "features"

# Mapping aliases
if ($isFeature) {
    if ($From -eq "dev") { $From = "merge" }
    if ($To -eq "dev") { $To = "merge" }
}

# Determine target if not specified
if ([string]::IsNullOrWhiteSpace($To)) {
    switch ($From) {
        "merge"  { $To = "a-test" }
        "a-test" { $To = "b-test" }
        "b-test" { $To = "stable" }
        default  { throw "Cannot determine automatic promotion target for '$From'" }
    }
}

# Set fully qualified branch names
$isFeatureToCore = $isFeature -and $To -eq "merge"

# Core versioning defaults: only graduation from merge bumps by default. 
# Internal moves (a-test -> b-test) inherit the version from the source.
if (-not $isFeature -and $From -ne "merge" -and -not $PSBoundParameters.ContainsKey('Bump')) {
    $Bump = "none"
}

if ($isFeatureToCore) {
    $featureName = Split-Path $sproutDir -Leaf
    $fromBranch = "features/$featureName/$From"
    $toBranch   = "core/merge"
} elseif ($isFeature) {
    # Feature branches are prefixed with features/name/
    $featureName = Split-Path $sproutDir -Leaf
    $fromBranch = "features/$featureName/$From"
    $toBranch   = "features/$featureName/$To"
} else {
    # Core branches are prefixed with core/
    $fromBranch = "core/$From"
    $toBranch   = "core/$To"
}

# Define paths
function Get-StageDir {
    param($stage, $isFeatureEnv)
    if ($isFeatureEnv -and $stage -eq "merge") { return "dev" }
    return $stage
}

$fromDir = Get-StageDir -stage $From -isFeatureEnv $isFeature
$toDir   = Get-StageDir -stage $To -isFeatureEnv ($isFeature -and -not $isFeatureToCore)

if ($isFeatureToCore) {
    $rootSproutDir = Split-Path (Split-Path $sproutDir -Parent) -Parent
    $fromPath = Join-Path $sproutDir $fromDir
    $toPath   = Join-Path $rootSproutDir (Join-Path "core" $toDir)
} elseif ($isFeature) {
    $fromPath = Join-Path $sproutDir $fromDir
    $toPath   = Join-Path $sproutDir $toDir
} else {
    $fromPath = Join-Path $sproutDir (Join-Path "core" $fromDir)
    $toPath   = Join-Path $sproutDir (Join-Path "core" $toDir)
}

Write-Host "Context: $($isFeature ? 'Feature' : 'Core')" -ForegroundColor Gray
Write-Host "Promoting: $fromBranch → $toBranch" -ForegroundColor Cyan
Write-Host "Source Path: $fromPath" -ForegroundColor Gray
Write-Host "Target Path: $toPath" -ForegroundColor Gray

if (-not (Test-Path $toPath)) {
    Write-Error "Target worktree not found: $toPath. Run build-pipeline.ps1 first."
    exit 1
}

Push-Location $toPath
try {
    # --- Auto-commit any dirty state ---
    $dirty = git status --porcelain
    if ($dirty) {
        Write-Host "Auto-committing dirty worktree state..." -ForegroundColor Gray
        git add -A | Out-Null
        git commit -m "chore: auto-commit before promotion" | Out-Null
    }

    # --- Merge ---
    # Cache VERSION for feature graduation or core graduation to prevent -X theirs overriding pipeline milestones
    $coreVersionCache = ""
    $coreVersionFile = Join-Path $toPath "VERSION"
    $shouldCache = $isFeatureToCore -or (-not $isFeature -and $From -eq "merge")
    if ($shouldCache -and (Test-Path $coreVersionFile)) {
        $coreVersionCache = Get-Content $coreVersionFile -Raw
    }

    Write-Host "Merging $fromBranch into $toBranch (favoring source content)..." -ForegroundColor Gray
    # --allow-unrelated-histories handles first-time merges
    # -X theirs ensures source branch wins on conflicts
    git merge $fromBranch --no-edit --allow-unrelated-histories -X theirs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Merge failed. Manual intervention required in $toPath."
        exit 1
    }

    # Restore Version for protected tiers
    if ($shouldCache -and $coreVersionCache -ne "") {
        Set-Content -Path $coreVersionFile -Value $coreVersionCache -Encoding UTF8
        git add VERSION | Out-Null
        git commit --amend --no-edit | Out-Null
    }

    # --- Version Bump ---
    $versionFile    = Join-Path $toPath "VERSION"
    $currentVersion = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { "0.1.0" }

    # For features, we always inherit the version from the source.
    # The version is manually managed via the 'Bump Dev' button (test-promote.ps1).
    if ($isFeature) {
        $Bump = "none"
    }

    if ($Bump -ne "none") {
        if ($isFeature) {
            # Feature versioning: e.g. 0.1.0-auth.1 → 0.1.0-auth.2
            if ($currentVersion -match '^(?<base>.+[^0-9])\.(?<patch>\d+)$') {
                $base  = $Matches['base']
                $patch = [int]$Matches['patch'] + 1
                $newVersion = "$base.$patch"
            } else {
                $newVersion = "$currentVersion.1"
            }
        } else {
            # Core versioning: standard X.Y.Z
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
        # --- Auto-Increment for Core Graduation ---
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

    # --- Git Tagging ---
    $tagName = "v$newVersion"
    if (-not $isFeature -and $To -ne "stable") { $tagName += "-$To" }

    # --- Feature Merged Manifest ---
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

    # --- Post-Graduation Cleanup ---
    if (-not $isFeature -and $From -eq "merge") {
        # Core has promoted out of merge, reset the context in core/merge
        Push-Location $fromPath
        $manifestPathSrc = Join-Path $fromPath "FEATURES_MERGED.json"
        
        # Sync the new bumped version backwards
        $srcVersionFile = Join-Path $fromPath "VERSION"
        Set-Content -Path $srcVersionFile -Value $newVersion -Encoding UTF8
        git add VERSION | Out-Null
        
        Write-Host "Resetting feature manifest in $fromBranch..." -ForegroundColor Gray
        Set-Content -Path $manifestPathSrc -Value "[]" -Encoding UTF8
        git add FEATURES_MERGED.json | Out-Null
        
        git commit -m "chore: clear feature manifest and bump version post-graduation" -q | Out-Null
        Pop-Location
    }
} finally {
    Pop-Location
}
