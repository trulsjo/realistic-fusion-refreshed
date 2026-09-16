<#
.SYNOPSIS
    Renders a machine with its flange ribs deleted, into a directory you name, so the bare tube can
    be measured. One Blender pair of runs and no game -- it asserts nothing.

.DESCRIPTION
    A PROBE, NOT A CHECK. Exit 0 means it rendered, never that a socket is right. Nothing it makes
    is committed and nothing it makes can ship: it refuses an output directory inside any of this
    repository's mods, and models/socket-variants.py refuses to write its throwaway model into
    models/ or the Assets mod for the same reason.

    WHY THE RENDER CANNOT BE READ OFF A SHIPPED SHEET. On a shipped sheet no column of a plumbable
    socket shows bare tube: the two flange ribs leave 1.15 px of tube between them and no whole
    column falls clear of both, so tools/measure-socket-parts.py correctly reports the stub as
    having NO WINDOW. The three contained sockets (ADR 0018) do expose their tube, but they are
    drawn at the machine's own 0.55 and radius 0.3 by design and cannot stand in for a plumbable
    one.

    WHY THE RECIPE IS COMMITTED AND THE RENDER IS NOT. Two things already rest on a measurement
    that was taken off a control render built by hand in a scratch directory and thrown away --
    models/house-style.md's stub row (+20.5 above the axis and +20.5 below since ADR 0035, where it
    was +20.5 and +18.5 while the ground plane cut) and #373's whole requirement, that the tube draw
    vanilla's barrel extent above and below. Neither could be re-derived without somebody working
    the method out again, and #373 was CLOSED on a reading taken this way. COMMITTING A RENDERED SHEET
    WAS RULED OUT DELIBERATELY: an artefact whose only purpose is to be measured would need a home
    outside ADR 0023's Assets rule and a regeneration rule nobody wants to maintain. So what is
    committed is the recipe, which is what every probe here is -- kept so the next machine
    rendered, and the next engine version, can be asked the same question.

    WHAT IT DOES, which is the method models/house-style.md used to describe in prose:

      1. models/socket-variants.py `unflanged` over the machine's stored model, into a scratch
         .blend. That treatment deletes every `Flange-*` object and refuses a model that carries
         none.
      2. geometry.json copied beside it, because models/render.py reads the file next to the model
         it opens and refuses one whose hash has moved.
      3. models/render.py over the copy with --directions 2, into -OutputDirectory. TWO AND NOT
         ONE, because tools/socket_strip.py reads a socket only on a sheet whose camera looks along
         its axis: east and west off the north sheet, north and south off the -e sheet a quarter
         turn on. One direction renders faster and then refuses half the sockets on the machine
         ("the manifest records no '-e' sheet to measure it on"). The other two are the same two
         cameras seen from behind and would be renders of sprites nobody measures.

    WHAT TO DO WITH THE RESULT. tools/measure-socket-parts.py against the manifest it wrote, with
    the socket's own radius and --no-flange -- the command is printed at the end. THAT FLAG IS NOT
    OPTIONAL HERE: the tool works every part's window out from the constants the model was built
    from, not from the sheet, so without it the ribs' span is still labelled "flange ribs" and
    measured at the ribs' radius, and the stub is still reported as having no window. --no-flange
    is the caller saying which kind of sheet this is. With it, rf-isotope-collector's west socket
    reproduces models/house-style.md's stub row exactly: +20.5 above the axis and +20.5 below, 1.0
    px of drawn edge gained at each, through columns 198..201. Re-measured 2026-09-16 after ADR
    0035, on the north socket as well, which reads the same off the -e sheet.

    Findings belong in docs/research/ or on the ticket.

.PARAMETER Machine
    Which machine, with or without the rf- prefix. Its stored model must exist at
    models/<machine>/<machine>.blend.

.PARAMETER OutputDirectory
    Where the sheets and manifest.json are written. Required, and refused if it is inside any mod
    in this repository. Defaults to nothing on purpose: a default inside the repository is how a
    throwaway render ends up beside a shipped one.

.PARAMETER Blender
    Path to blender.exe. Defaults to whatever tools/render-machine.py's own lookup finds, so this
    script and /render-machine never disagree about which Blender is in use.

.PARAMETER Samples
    Cycles samples. 64 is what the shipped sheets use; a lower figure is noisier than the art the
    measurement is standing in for.

.PARAMETER KeepTemp
    Leave the scratch model and its geometry.json in place.

.EXAMPLE
    pwsh -File scripts/probe-flange-free-render.ps1 -Machine rf-isotope-collector `
         -OutputDirectory $env:TEMP\rf-unflanged
#>

#Requires -Version 7

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Machine,
    [Parameter(Mandatory)] [string] $OutputDirectory,
    [string] $Blender,
    [int]    $Samples = 64,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
. "$repoRoot/scripts/factorio-lib.ps1"

$machine = $Machine -replace '^rf-', ''
$model    = Join-Path $repoRoot "models/$machine/$machine.blend"
$geometry = Join-Path $repoRoot "models/$machine/geometry.json"
if (-not (Test-Path -LiteralPath $model)) {
    throw "no stored model at $model. Run /render-machine rf-$machine --regenerate first."
}

# THE OUTPUT DIRECTORY MAY NOT BE INSIDE A MOD, and the Assets mod is the one that matters: a
# render written there would sit beside the shipped sheets of the same machine, under the same
# names, and the next pack would ship a machine with no flanges on it. Refused rather than
# overwritten -- a claim a script does not enforce is a claim it will outlive.
$outFull = [IO.Path]::GetFullPath($OutputDirectory)
foreach ($guarded in @(Get-RepoMods) + @('models')) {
    $full = [IO.Path]::GetFullPath((Join-Path $repoRoot $guarded))
    if ($outFull -eq $full -or $outFull.StartsWith($full + [IO.Path]::DirectorySeparatorChar)) {
        throw "-OutputDirectory $OutputDirectory is inside $guarded, where committed files live. Nothing this script makes may ship; give a directory outside the repository's mods and models."
    }
}
New-Item -ItemType Directory -Path $outFull -Force | Out-Null

if (-not $Blender) {
    # tools/render-machine.py's own lookup, not a second copy of it: --blender, $BLENDER_EXE, a
    # running blender.exe, the portable unzip in Downloads, Program Files.
    $find = "import importlib.util,sys;" +
            "s=importlib.util.spec_from_file_location('rm',r'$repoRoot/tools/render-machine.py');" +
            "m=importlib.util.module_from_spec(s);s.loader.exec_module(m);print(m.find_blender(None))"
    $Blender = (& python -c $find | Select-Object -Last 1)
    if ($LASTEXITCODE -ne 0 -or -not $Blender) { throw 'could not find blender.exe; pass -Blender or set BLENDER_EXE.' }
}
Write-Host "blender: $Blender"

$temp = Join-Path ([IO.Path]::GetTempPath()) ('rf-unflanged-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
    # render.py reads geometry.json BESIDE the model it is given and refuses one whose hash has
    # moved, so the throwaway copy needs the same file beside it.
    Copy-Item -LiteralPath $geometry -Destination $temp -Force
    $blend = Join-Path $temp "$machine-unflanged.blend"

    & $Blender -b $model --python-exit-code 1 --python (Join-Path $repoRoot 'models/socket-variants.py') `
        -- unflanged $blend | Select-String -Pattern 'SOCKET-VARIANTS|socket-variants' |
        ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -ne 0) { throw "socket-variants.py failed (exit $LASTEXITCODE)." }

    & $Blender -b $blend --python-exit-code 1 --python (Join-Path $repoRoot 'models/render.py') `
        -- --samples $Samples --directions 2 --out $outFull | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "render.py failed (exit $LASTEXITCODE)." }

    $manifest = Join-Path $outFull 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifest)) { throw "render.py wrote no manifest.json into $outFull." }
}
finally {
    if ($KeepTemp) { Write-Host "kept: $temp" }
    else { Remove-TempDirectory -Path $temp -Label 'probe-flange-free-render' }
}

Write-Host ''
foreach ($f in (Get-ChildItem -LiteralPath $outFull | Sort-Object Name)) {
    Write-Host ("  {0,-34} {1,8:N0} KB" -f $f.Name, ($f.Length / 1KB))
}
Write-Host ''
Write-Host "flange-free render: $outFull"
# THE COMMAND IS BUILT FROM THE MANIFEST THIS RUN WROTE, not typed. `--direction west` alone is
# ambiguous on rf-heat-exchanger, which records two west connections -- water and reactor energy --
# and measure-socket-parts.py rightly refuses to guess between them. So every plumbable connection
# is listed, each with the --fluid that names it. A contained one is left out: it is drawn at the
# machine's own height and radius and needs a --z this script has no business inventing.
$connections = (Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).geometry.connections
$plumbable = @($connections | Where-Object { -not $_.connection_category })
Write-Host 'Measure it with --no-flange, which is what tells the tool this is a control render;'
Write-Host 'without it the ribs'' span is still labelled "flange ribs" and the stub has no window:'
Write-Host ''
foreach ($c in $plumbable) {
    Write-Host "  python tools/measure-socket-parts.py `"$manifest`" --direction $($c.direction) --fluid $($c.fluid) --radius 0.249 --no-flange"
}
if (-not $plumbable) {
    Write-Host "  (no connection here is plumbable; a contained one needs its own --radius and --z)"
}
Write-Host ''
Write-Host "On rf-isotope-collector's west socket that reproduces models/house-style.md's stub row:"
Write-Host '+20.5 above the axis and +20.5 below, a pixel of drawn edge at each, through columns 198..201.'
Write-Host ''
Write-Host 'Probe finished. Exit 0 means it rendered, never that a socket is right.'
