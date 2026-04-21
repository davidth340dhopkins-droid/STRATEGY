# .nurse/scripts/version-status.ps1
# Shows the current version deployed at each pipeline stage.

$nurseryDir = $PSScriptRoot | Split-Path -Parent
$nurseRootDir = $nurseryDir | Split-Path -Parent
$sproutDir  = $nurseRootDir | Split-Path -Parent

$stages = @(
    @{ Name = "merge";  Dir = "core/merge"  },
    @{ Name = "a-test"; Dir = "core/a-test" },
    @{ Name = "b-test"; Dir = "core/b-test" },
    @{ Name = "stable"; Dir = "core/stable" }
)

Write-Host "`nPipeline Version Status" -ForegroundColor Cyan
Write-Host ("=" * 72) -ForegroundColor DarkGray
Write-Host ("{0,-10} {1,-12} {2,-22} {3}" -f "Stage", "Version", "Latest Tag", "Last Commit") -ForegroundColor White
Write-Host ("{0,-10} {1,-12} {2,-22} {3}" -f "-----", "-------", "----------", "-----------") -ForegroundColor DarkGray

foreach ($stage in $stages) {
    $stagePath = Join-Path $sproutDir $stage.Dir

    if (-not (Test-Path $stagePath)) {
        Write-Host ("{0,-10} {1}" -f $stage.Name, "(not found)") -ForegroundColor DarkGray
        continue
    }

    $versionFile = Join-Path $stagePath "VERSION"
    $version = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { "unversioned" }

    Push-Location $stagePath
    $latestTag  = git describe --tags --abbrev=0 2>$null
    if (-not $latestTag) { $latestTag = "(no tag)" }
    $lastCommit = git log -1 --format="%s" 2>$null
    if (-not $lastCommit) { $lastCommit = "(no commits)" }
    Pop-Location

    $color = switch ($stage.Name) {
        "stable" { "Green"   }
        "b-test" { "Yellow"  }
        "a-test" { "Magenta" }
        "merge"  { "Gray"    }
        default  { "White"   }
    }

    Write-Host ("{0,-10} {1,-12} {2,-22} {3}" -f $stage.Name, "v$version", $latestTag, $lastCommit) -ForegroundColor $color
}

Write-Host ("=" * 72) -ForegroundColor DarkGray
Write-Host ""
