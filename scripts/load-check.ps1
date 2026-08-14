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
    that failure out, so it needs its own check and does not come free with a pass here.

    The player's own mod directory is never touched: the repo's mods are junctioned into a
    temporary directory and a mod-list.json is written there.

    Mods bundled with the game (space-age, elevated-rails, quality) live in its data/ directory,
    so they load unless explicitly disabled. This script disables them by default to get a
    genuine base-2.0 check (ADR 0003, ADR 0008); -With re-enables them.

    PowerShell 7 is required: 5.1's Remove-Item -Recurse follows junctions instead of skipping
    them, which would delete the repo's own source through the links this script creates.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then to the Steam install on this machine.

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

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = @('RealisticFusionCore', 'RealisticFusion')

if (-not $FactorioExe) { $FactorioExe = $env:FACTORIO_EXE }
if (-not $FactorioExe) { $FactorioExe = 'D:\SteamLibrary\steamapps\common\Factorio\bin\x64\Factorio.exe' }
if (-not (Test-Path $FactorioExe)) {
    throw "Factorio.exe not found at '$FactorioExe'. Pass -FactorioExe or set `$env:FACTORIO_EXE."
}

# <install>\bin\x64\Factorio.exe -> <install>\data
$dataDir = Join-Path (Split-Path (Split-Path (Split-Path $FactorioExe -Parent) -Parent) -Parent) 'data'
if (-not (Test-Path $dataDir)) { throw "Factorio data directory not found at '$dataDir'." }

# Discover the toggleable bundled mods rather than hardcoding a list that can go stale.
# base and core are not optional and are never listed.
$bundledInfo = @{}
Get-ChildItem -Path $dataDir -Directory |
    Where-Object { $_.Name -notin @('base', 'core') -and (Test-Path (Join-Path $_.FullName 'info.json')) } |
    ForEach-Object {
        $bundledInfo[$_.Name] = (Get-Content (Join-Path $_.FullName 'info.json') -Raw | ConvertFrom-Json)
    }

$unknown = $With | Where-Object { $_ -notin $bundledInfo.Keys }
if ($unknown) {
    throw ("-With names no bundled mod: {0}. Available: {1}." -f ($unknown -join ', '), (($bundledInfo.Keys | Sort-Object) -join ', '))
}

# Canonicalise casing before anything downstream compares names. PowerShell's -notin and its
# hashtables are case-insensitive, but HashSet[string] below is ordinal, so "-With Space-Age"
# would pass validation and then be written enabled=false while the header printed it as enabled
# -- a base-only run reported as an expansion pass, exactly what the validation above exists to
# prevent.
# Where-Object drops the single $null that piping an empty collection would otherwise yield, and
# @() keeps the result an array rather than a scalar or $null.
$With = @($With |
    Where-Object { $_ } |
    ForEach-Object { $name = $_; $bundledInfo.Keys | Where-Object { $_ -eq $name } | Select-Object -First 1 })

# Enabling space-age without elevated-rails and quality is a missing-dependency error that looks
# like our mods failing, so resolve the closure over bundled mods before writing the list.
$enable = [System.Collections.Generic.HashSet[string]]::new()
$queue  = [System.Collections.Queue]::new()
$With | ForEach-Object { $queue.Enqueue($_) }
while ($queue.Count -gt 0) {
    $m = $queue.Dequeue()
    if (-not $enable.Add($m)) { continue }
    foreach ($dep in @($bundledInfo[$m].dependencies)) {
        # Skip optional ("?"), hidden-optional ("(?)") and incompatible ("!") only. "~" is a
        # REQUIRED dependency that merely does not affect load order, so it must be followed --
        # skipping it would drop a real dependency and produce a missing-dependency failure that
        # reads as this repo's mods being broken.
        if ($dep -match '^\s*[?!(]') { continue }
        $dep = $dep -replace '^\s*~\s*', ''
        $depName = ($dep -replace '^\s*', '') -split '\s+' | Select-Object -First 1
        if ($bundledInfo.ContainsKey($depName)) { $queue.Enqueue($depName) }
    }
}

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-loadcheck-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
New-Item -ItemType Directory -Path $modDir -Force | Out-Null

function Invoke-Factorio {
    param([string] $Label, [string[]] $Enabled, [string] $Tag)

    $entries = @(@{ name = 'base'; enabled = $true })
    foreach ($m in $bundledInfo.Keys) { $entries += @{ name = $m; enabled = [bool]$enable.Contains($m) } }
    foreach ($m in $Enabled)          { $entries += @{ name = $m; enabled = $true } }
    @{ mods = $entries } | ConvertTo-Json -Depth 4 |
        Set-Content -Path (Join-Path $modDir 'mod-list.json') -Encoding utf8

    # Report what is actually enabled, not what was asked for.
    $bundledOn = if ($enable.Count) { (($enable | Sort-Object) -join ', ') } else { 'none (base 2.0 only)' }
    Write-Host "$Label`: $($Enabled -join ', ')  |  bundled enabled: $bundledOn"

    $save    = Join-Path $temp "$Tag.zip"
    $outFile = Join-Path $temp "$Tag-stdout.txt"
    $errFile = Join-Path $temp "$Tag-stderr.txt"

    # Factorio.exe is a GUI-subsystem binary: the call operator does not wait for it and leaves
    # $LASTEXITCODE unset, so the exit code has to come from the process object.
    $proc = Start-Process -FilePath $FactorioExe `
        -ArgumentList @('--mod-directory', $modDir, '--create', $save) `
        -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $outFile -RedirectStandardError $errFile

    [pscustomobject]@{
        Code       = $proc.ExitCode
        SaveExists = Test-Path $save
        OutFile    = $outFile
        ErrFile    = $errFile
    }
}

function Write-Tail {
    param([object] $Result)
    # Tail each stream separately; Factorio's stdout runs to hundreds of lines and would
    # otherwise push every stderr line out of a shared window.
    foreach ($f in @($Result.ErrFile, $Result.OutFile)) {
        if (-not (Test-Path $f)) { continue }
        $lines = Get-Content $f -ErrorAction SilentlyContinue | Where-Object { $_ -match '\S' }
        if (-not $lines) { continue }
        Write-Host "  --- $(Split-Path $f -Leaf) (last 20 of $($lines.Count)) ---"
        $lines | Select-Object -Last 20 | ForEach-Object { Write-Host "    $_" }
    }
}

try {
    foreach ($m in $ourMods) {
        $src = Join-Path $repoRoot $m
        if (-not (Test-Path $src)) { throw "Mod directory not found in repo: $src" }
        # Junction rather than copy: no admin needed, no duplication, edits are picked up live.
        New-Item -ItemType Junction -Path (Join-Path $modDir $m) -Target $src | Out-Null
    }

    if ($SelfTest) {
        # Half one: the repo as it stands must pass, or a non-zero exit in half two proves nothing.
        Write-Host 'self-test 1/2: the repo as it stands must load.'
        $clean = Invoke-Factorio -Label 'load-check' -Enabled $ourMods -Tag 'clean'
        # Same pass criterion as a real run: exit 0 without a save is a failure there, so it must
        # be a failure here too, or -SelfTest could certify a check a plain run would reject.
        if ($clean.Code -ne 0 -or -not $clean.SaveExists) {
            Write-Host ''
            Write-Host "FAILED - self-test: the repo does not load cleanly (exit $($clean.Code), save produced: $($clean.SaveExists)),"
            Write-Host '         so the canary result would be meaningless.'
            Write-Tail $clean
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
        $broken = Invoke-Factorio -Label 'load-check' -Enabled ($ourMods + 'rf-loadcheck-canary') -Tag 'canary'
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

    $result = Invoke-Factorio -Label 'load-check' -Enabled $ourMods -Tag 'run'

    if ($result.Code -ne 0) {
        Write-Host ''
        Write-Host "FAILED - Factorio exited with code $($result.Code)"
        Write-Tail $result
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
    Get-ChildItem -Path $modDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.LinkType -eq 'Junction' } |
        ForEach-Object { [IO.Directory]::Delete($_.FullName) }

    if ($KeepTemp) {
        Write-Host "temp kept at: $temp"
    }
    elseif (Test-Path $temp) {
        # Factorio can still hold the save open for a moment after exiting, so retry briefly
        # rather than leaking the directory silently.
        foreach ($attempt in 1..5) {
            Remove-Item -Path $temp -Recurse -Force -ErrorAction SilentlyContinue
            if (-not (Test-Path $temp)) { break }
            Start-Sleep -Milliseconds 200
        }
        if (Test-Path $temp) { Write-Warning "load-check: could not remove temp directory $temp" }
    }
}
