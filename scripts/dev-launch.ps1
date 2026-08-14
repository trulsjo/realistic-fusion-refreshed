#Requires -Version 7
<#
.SYNOPSIS
    Launch the Factorio client with this repository's mods, in an isolated mod directory.

.DESCRIPTION
    The full GUI game, pointed at a mod directory containing only base plus this repo's two mods.
    The repo's mods are junctioned in, so editing a prototype and restarting the game is the whole
    edit-test loop -- nothing is copied and nothing needs reinstalling.

    Base 2.0 only by default, which is what ADR 0003 and ADR 0008 actually target. -With enables
    the bundled expansion mods and resolves their dependencies.

    Your own mod directory is deliberately not used. It has other mods installed and the expansion
    enabled, so playtesting there would mean testing against everything at once -- and ADR 0007
    commits to coexistence, not integration.

    Data-stage changes (prototypes, recipes, locale) need a full restart of the game; Factorio has
    no hot reload for them.

    On a Steam build, running Factorio.exe directly makes the Steam API re-launch the game through
    Steam and exit ("Steam requires game restart, restarting..."). Steam then starts it WITHOUT
    --mod-directory, so you silently get your normal mods instead of these. The fix is a
    steam_appid.txt in the working directory, which tells the Steam API not to restart. This script
    puts that file in a scratch directory of its own and launches from there -- the Steam
    installation is never modified. Passing arguments through steam:// URLs does not work; modern
    Steam clients ignore them.

.PARAMETER With
    Bundled mods to enable, e.g. -With space-age. Dependencies are pulled in automatically and
    unknown names are rejected.

.PARAMETER ModDirectory
    Where to build the mod directory. Defaults to a sibling of the repo, next to _reference.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Wait
    Block until the game exits. Without it the script returns as soon as Factorio starts.

.EXAMPLE
    pwsh -File scripts/dev-launch.ps1
    pwsh -File scripts/dev-launch.ps1 -With space-age
#>
[CmdletBinding()]
param(
    [string[]] $With = @(),
    [string]   $ModDirectory,
    [string]   $FactorioExe,
    [switch]   $Wait
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = @('RealisticFusionCore', 'RealisticFusion')

if (-not $ModDirectory) { $ModDirectory = Join-Path (Split-Path $repoRoot -Parent) '_dev-mods' }

$exe     = Resolve-FactorioExe -Path $FactorioExe
$bundled = Get-BundledMods -FactorioExe $exe
try {
    $enabled = Resolve-BundledSelection -Requested $With -Bundled $bundled
}
catch { throw "-With $($_.Exception.Message)" }

New-Item -ItemType Directory -Path $ModDirectory -Force | Out-Null
# Rebuilt every run, so a mod renamed or removed in the repo cannot linger as a stale link.
Remove-ModJunctions -ModDirectory $ModDirectory
New-ModJunctions -ModDirectory $ModDirectory -RepoRoot $repoRoot -Mods $ourMods
Write-ModList -ModDirectory $ModDirectory -Bundled $bundled -EnabledBundled $enabled -Mods $ourMods

$bundledOn = if ($enabled) { $enabled -join ', ' } else { 'none (base 2.0 only)' }
Write-Host "mods       : $($ourMods -join ', ')"
Write-Host "bundled    : $bundledOn"
Write-Host "mod dir    : $ModDirectory"
Write-Host ''
Write-Host 'Nothing is unlocked from a fresh start. In game, open the console with ~ and:'
Write-Host '  /editor                                            instant build; infinity pipe gives water'
Write-Host '  /c game.player.force.research_all_technologies()    unlock the chains'
Write-Host ''
Write-Host 'Restart the game to pick up prototype, recipe or locale edits.'
Write-Host ''

# Launch from a scratch directory holding steam_appid.txt. The Steam API reads that file from the
# WORKING directory (not from next to the executable) and skips its relaunch-through-Steam, which
# would otherwise drop our --mod-directory argument on the floor. Harmless on a non-Steam build.
$launchDir = Join-Path ([IO.Path]::GetTempPath()) 'rf-dev-launch'
New-Item -ItemType Directory -Path $launchDir -Force | Out-Null
'427520' | Set-Content -Path (Join-Path $launchDir 'steam_appid.txt') -Encoding ascii -NoNewline

$proc = Start-Process -FilePath $exe -ArgumentList @('--mod-directory', $ModDirectory) `
    -WorkingDirectory $launchDir -PassThru
Write-Host "launched Factorio (pid $($proc.Id))"

if ($Wait) {
    $proc.WaitForExit()
    Write-Host "Factorio exited with code $($proc.ExitCode)"
    exit $proc.ExitCode
}
