#Requires -Version 7
<#
.SYNOPSIS
    Runs Factorio's data stage against the Realistic Fusion mods. Exit 0 means they load.

.DESCRIPTION
    Creates a throwaway map in an isolated mod directory containing only the game's bundled
    mods plus this repository's two. Exit 0 means every prototype is valid, every dependency
    resolves, and nothing references a prototype that does not exist -- broader coverage than a
    test suite, for the cost of this script.

    It does NOT check locale coverage. Factorio's data stage loads a prototype with no locale
    entry without complaint; the omission only shows in game as "Unknown key". ADR 0010 singles
    that failure out, so it has its own check: scripts/locale-check.ps1. A pass here says nothing
    about it.

    The player's own mod directory is never touched: the repo's mods are junctioned into a
    temporary directory and a mod-list.json is written there.

    Bundled mods (space-age, elevated-rails, quality) live in the game's data/ directory, so they
    load unless explicitly disabled. Disabled by default to get a genuine base-2.0 check
    (ADR 0003, ADR 0008); -With re-enables them.

    PowerShell 7 is required: 5.1's Remove-Item -Recurse follows junctions instead of skipping
    them, which would delete the repo's own source through the links this script creates.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER With
    Bundled mods to enable, e.g. -With space-age. Dependencies are pulled in automatically --
    space-age requires elevated-rails and quality, so naming it alone is enough. Unknown names
    are rejected rather than silently ignored, because a typo would otherwise produce a base-only
    run reported as an expansion pass. Used to discharge ADR 0003's obligation.

.PARAMETER SelfTest
    Verify the check can fail. Runs twice: once as normal, which must pass, and once with a mod
    carrying an invalid prototype, which must fail. Both halves are required -- a non-zero exit
    on its own proves nothing, since Factorio also exits non-zero when the repo is genuinely
    broken. Run this whenever the script changes.

.PARAMETER KeepTemp
    Keep the temporary save and captured output for debugging. Junctions are always removed.

.EXAMPLE
    pwsh -File scripts/load-check.ps1
    pwsh -File scripts/load-check.ps1 -With space-age
    pwsh -File scripts/load-check.ps1 -SelfTest
#>
[CmdletBinding()]
param(
    [string]   $FactorioExe,
    [string[]] $With = @(),
    [switch]   $SelfTest,
    [switch]   $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = @('RealisticFusionCore', 'RealisticFusion')

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe
try {
    $enabledBundled = Resolve-BundledSelection -Requested $With -Bundled $bundled
}
catch { throw "-With $($_.Exception.Message)" }

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-loadcheck-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
New-Item -ItemType Directory -Path $modDir -Force | Out-Null

function Invoke-LoadCheck {
    <#  One check: write the mod list, create a map, and report whether a save came out.

        The running of Factorio itself lives in factorio-lib.ps1; what is here is the part that is
        this script's own -- which mods to enable, and that "exit 0 but no save" is a failure.  #>
    param([string] $Label, [string[]] $Enabled, [string] $Tag)

    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabledBundled -Mods $Enabled

    $bundledOn = if ($enabledBundled) { $enabledBundled -join ', ' } else { 'none (base 2.0 only)' }
    Write-Host "$Label`: $($Enabled -join ', ')  |  bundled enabled: $bundledOn"

    $save   = Join-Path $temp "$Tag.zip"
    $result = Invoke-Factorio -FactorioExe $FactorioExe -ModDirectory $modDir `
        -Arguments @('--create', $save) -OutputDirectory $temp -Tag $Tag

    [pscustomobject]@{
        Code       = $result.Code
        SaveExists = Test-Path $save
        OutFile    = $result.OutFile
        ErrFile    = $result.ErrFile
    }
}

try {
    # Before Factorio runs at all, because Factorio will not catch this. A headless run loads no
    # sprites, so a prototype naming an icon that does not exist validates and exits 0 -- and the
    # player's game then refuses to start on it. That happened: a heat-exchanger icon whose file
    # had been renamed in vanilla passed every check here and broke the game on first launch.
    $missingAssets = Find-MissingVanillaAssets -DataDir (Get-FactorioDataDirectory -FactorioExe $FactorioExe) `
        -SourceDirectories ($ourMods | ForEach-Object { Join-Path $repoRoot $_ })
    if ($missingAssets) {
        Write-Host "FAILED - $($missingAssets.Count) vanilla asset(s) referenced but not present:"
        foreach ($m in $missingAssets) {
            Write-Host "    $($m.Reference)"
            Write-Host "      named in $([IO.Path]::GetRelativePath($repoRoot, $m.Source))"
        }
        exit 1
    }

    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods

    if ($SelfTest) {
        # Half one: the repo as it stands must pass, or a non-zero exit in half two proves nothing.
        Write-Host 'self-test 1/2: the repo as it stands must load.'
        $clean = Invoke-LoadCheck -Label 'load-check' -Enabled $ourMods -Tag 'clean'
        # Same pass criterion as a real run: exit 0 without a save is a failure there, so it must
        # be a failure here too, or -SelfTest could certify a check a plain run would reject.
        if ($clean.Code -ne 0 -or -not $clean.SaveExists) {
            Write-Host ''
            Write-Host "FAILED - self-test: the repo does not load cleanly (exit $($clean.Code), save produced: $($clean.SaveExists)),"
            Write-Host '         so the canary result would be meaningless.'
            Write-FactorioTail $clean
            exit 1
        }

        # Half two: an invalid prototype must be rejected. The canary lives in the temp directory,
        # never in the repo.
        $canary = Join-Path $modDir 'rf-loadcheck-canary'
        New-Item -ItemType Directory -Path $canary -Force | Out-Null
        @{
            name = 'rf-loadcheck-canary'; version = '0.0.1'; title = 'Load-check canary'
            author = 'load-check.ps1'; factorio_version = '2.0'; dependencies = @('base >= 2.0.77')
        } | ConvertTo-Json | Set-Content -Path (Join-Path $canary 'info.json') -Encoding utf8
        # Valid Lua, invalid prototype: "stack_size" is mandatory on an item.
        'data:extend({{ type = "item", name = "rf-loadcheck-canary-item" }})' |
            Set-Content -Path (Join-Path $canary 'data.lua') -Encoding utf8

        Write-Host 'self-test 2/2: an invalid prototype must be rejected.'
        $broken = Invoke-LoadCheck -Label 'load-check' -Enabled ($ourMods + 'rf-loadcheck-canary') -Tag 'canary'
        if ($broken.Code -eq 0) {
            Write-Host ''
            Write-Host 'FAILED - self-test: an invalid prototype did NOT fail the check.'
            Write-Host '         The load-check is not proving anything; fix it before trusting a pass.'
            exit 1
        }

        Write-Host ''
        Write-Host "OK - self-test passed: clean repo loads, invalid prototype rejected (exit $($broken.Code))."
        exit 0
    }

    $result = Invoke-LoadCheck -Label 'load-check' -Enabled $ourMods -Tag 'run'

    if ($result.Code -ne 0) {
        Write-Host ''
        Write-Host "FAILED - Factorio exited with code $($result.Code)"
        Write-FactorioTail $result
        exit $result.Code
    }
    if (-not $result.SaveExists) {
        Write-Host 'FAILED - Factorio exited 0 but produced no save; treating as a failure.'
        exit 1
    }

    Write-Host 'OK - data stage valid, map created.'
    exit 0
}
finally {
    # Junctions always go, even with -KeepTemp: leaving links to the repo in %TEMP% hands a
    # delete-through-the-link hazard to whatever cleans it up later.
    Remove-ModJunctions -ModDirectory $modDir

    if ($KeepTemp) {
        Write-Host "temp kept at: $temp"
    }
    else {
        Remove-TempDirectory -Path $temp -Label 'load-check'
    }
}
