# .nurse/scripts/promote.ps1
# Promotes changes from one pipeline tier to the next, bumps version, and tags.

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("merge", "a-test", "b-test")]
    [string]$From,

    [Parameter(Mandatory=$false)]
    [string]$To,

    [Parameter(Mandatory=$false)]
    [ValidateSet("major", "minor", "patch", "none")]
    [string]$Bump = "patch"
)

$nurseryDir = $PSScriptRoot | Split-Path -Parent
$sproutDir  = $nurseryDir   | Split-Path -Parent

# Determine target if not specified
if ([string]::IsNullOrWhiteSpace($To)) {
    switch ($From) {
        "merge"  { $To = "a-test" }
        "a-test" { $To = "b-test" }
        "b-test" { $To = "stable" }
    }
}

$fromBranch = "core/$From"
$toBranch   = "core/$To"
$toPath     = Join-Path $sproutDir "core/$To"

Write-Host "Promoting: $fromBranch -> $toBranch" -ForegroundColor Cyan

if (-not (Test-Path $toPath)) {
    Write-Error "Target worktree not found: $toPath. Run build-pipeline.ps1 first."
    exit 1
}

Push-Location $toPath
try {
    # --- Merge ---
    Write-Host "Merging $fromBranch into $toBranch..." -ForegroundColor Gray
    git merge $fromBranch --no-edit
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Merge failed. Manual intervention required in $toPath."
        exit 1
    }

    # --- Version Bump ---
    $versionFile    = Join-Path $toPath "VERSION"
    $currentVersion = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { "0.1.0" }

    if ($Bump -ne "none") {
        $parts = $currentVersion.Split('.')
        if ($parts.Count -ne 3) { $parts = @(0, 1, 0) }
        $major = [int]$parts[0]; $minor = [int]$parts[1]; $patch = [int]$parts[2]
        switch ($Bump) {
            "major" { $major++; $minor = 0; $patch = 0 }
            "minor" { $minor++; $patch = 0 }
            "patch" { $patch++ }
        }
        $newVersion = "$major.$minor.$patch"
    } else {
        $newVersion = $currentVersion
    }

    Set-Content -Path $versionFile -Value $newVersion -Encoding UTF8

    # --- Git Tagging ---
    $tagName = "v$newVersion"
    if ($To -ne "stable") { $tagName += "-$To" }

    git add VERSION | Out-Null
    git commit -m "chore: promote $From to $To (v$newVersion)" | Out-Null
    
    # Force tag if it exists (allows re-running promotions if cleanup happened)
    git tag -f $tagName | Out-Null

    Write-Host "Successfully promoted to $To (Version: $newVersion)" -ForegroundColor Green
} finally {
    Pop-Location
}
