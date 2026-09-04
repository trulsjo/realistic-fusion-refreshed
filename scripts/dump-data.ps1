<#
.SYNOPSIS
    Run the game's --dump-data with only this repository's mods enabled, and copy the dump to a path.

.DESCRIPTION
    A build tool, not a gate: exit 0 means a dump was written where -Out says, and nothing about
    what is in it. It exists so that tools outside PowerShell -- tools/extract-geometry.py first --
    can get the game's resolved prototypes without re-implementing how this repository runs the
    game: Resolve-FactorioExe, the junctioned mod directory, the mod list with every bundled mod
    written explicitly disabled, and a write-data directory of its own so it works while the game
    is open. All of that is factorio-lib.ps1's and is used here unchanged.

    The dump path is deleted before the run, not merely overwritten, for the reason load-check.ps1
    and probe-connection-categories.ps1 give: a run that exits 0 without writing would otherwise
    leave a previous dump for the caller to read.

.PARAMETER Out
    Where to put the dump. Defaults to data-raw-dump.json in the current directory.

.PARAMETER FactorioExe
    Path to Factorio.exe. Resolved the usual way when omitted (see Resolve-FactorioExe).

.PARAMETER With
    Bundled mods to enable as well (space-age, quality, elevated-rails). None by default: the
    dump then describes the base-game load, which is the v1 target (ADR 0003).

.EXAMPLE
    ./scripts/dump-data.ps1 -Out $env:TEMP/rf-dump.json
#>
[CmdletBinding()]
param(
    [string]   $Out = (Join-Path (Get-Location) 'data-raw-dump.json'),
    [string]   $FactorioExe,
    [string[]] $With = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot    = Split-Path $PSScriptRoot -Parent
$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe
try   { $enabledBundled = Resolve-BundledSelection -Requested $With -Bundled $bundled }
catch { throw "-With $($_.Exception.Message)" }

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-dump-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
New-Item -ItemType Directory -Path $modDir -Force | Out-Null

try {
    $ourMods = Get-RepoMods
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabledBundled -Mods $ourMods

    $rawPath = Join-Path $temp 'write-data/script-output/data-raw-dump.json'
    Remove-Item -LiteralPath $rawPath -Force -ErrorAction SilentlyContinue
    Invoke-FactorioStep -FactorioExe $FactorioExe -ModDirectory $modDir `
        -Arguments @('--dump-data') -OutputDirectory $temp -Tag 'dump' | Out-Null
    if (-not (Test-Path -LiteralPath $rawPath)) {
        throw "Factorio exited 0 but wrote no data-raw-dump.json at $rawPath."
    }

    $outDir = Split-Path -Parent $Out
    if ($outDir) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    Copy-Item -LiteralPath $rawPath -Destination $Out -Force
    # The one line a caller parses.
    Write-Output (Resolve-Path -LiteralPath $Out).Path
}
finally {
    # Junctions first, or the recursive delete follows them into the repository.
    Remove-ModJunctions -ModDirectory $modDir
    Remove-TempDirectory -Path $temp -Label 'dump-data'
}
