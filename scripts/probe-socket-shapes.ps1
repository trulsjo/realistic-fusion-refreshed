<#
.SYNOPSIS
    Photographs a machine's socket END drawn several ways, each with an ordinary pipe plugged into
    it, close up and again at the size a player meets it. Screenshots only -- it asserts nothing.

.DESCRIPTION
    A PROBE, NOT A CHECK. Exit 0 means the pictures were taken, never that any of the shapes is
    right. #351 is where a shape is chosen; this rig only makes the choice possible to look at.

    WHY IT EXISTS. Truls accepted the new socket art on 2026-09-14 -- "I have looked at the images
    and they seems fine to me" -- and that acceptance covers HEIGHT and THICKNESS, both of which are
    measured against a vanilla pipe and gated by tools/check-socket-height.py. It does not cover
    SHAPE, which no measurement reaches. scripts/probe-socket-height.ps1 photographs ONE treatment
    against a plain pipe, and one picture cannot settle a choice between several.

    WHAT THE TWO OBJECTS ARE, so the candidates are drawn against something rather than invented.
    A socket is a bare-metal cylinder of radius 0.249 running from the body to the footprint edge,
    with one accent band set a little in from that edge and a dark rim at its outer mouth. Vanilla's
    pipe is not a cylinder at all -- it is a stylised flat ribbon 0.609 tiles tall with heavy flanges
    either side and a dark core. Since #342 and #345 they sit at the same height and the same
    width, and they still do not read as the same object.

    THE FOUR TREATMENTS are #350's, and models/socket-variants.py draws them:

      bare        what ships today, as the control
      flanged     vanilla's flange pair added at the stub's mouth
      dark-cored  a shadowed channel down the tube, the way vanilla's window reads
      collared    the dark rim brought in from the footprint edge onto the body face

    NOTHING IT MAKES CAN SHIP, and that is the property to keep when editing it. The variants are
    rendered from THROWAWAY copies of models/isotope-collector/isotope-collector.blend into a
    scratch directory (models/render.py --out), never into the Assets mod, and the entities that
    wear them are clones this rig's own mod adds in data-final-fixes -- rf-isotope-collector itself
    is untouched and is not in any frame. A rig that quietly changed a shipped sheet would have
    answered #351 by itself, which is the one thing it must not do.

    THE CONTROL IS LITERALLY WHAT SHIPS, and that is checkable rather than asserted: rendering the
    `bare` variant reproduces realistic-fusion-refreshed-assets' isotope-collector.png and
    isotope-collector-shadow.png byte for byte (verified 2026-09-14, sha256 44ce42a9be01 and
    45a2b4183d85). If a change here ever breaks that, the control has stopped being a control and
    every frame beside it is being read against the wrong reference.

    WHAT IT SHOOTS, per treatment:

      seam-<treatment>.png  the west socket with an ordinary pipe on it, at zoom 8 -- one tile on
                            256 px, eight times what a player sees. The subject is the seam.
      game-<treatment>.png  the same machine and pipe run at ZOOM 1, which is 32 px to the tile and
                            the size the game actually draws at. A difference nobody can see here
                            is not a candidate, however good it looks magnified.

    and once, as the references every other frame is read against:

      seam-pipe-alone.png   the same six-tile run with the machine taken away, at zoom 8: it stands
      game-pipe-alone.png   where the next subject would have stood, so its east end is the tile a
                            socket would have met. Same spacing, same parity, same framing -- and
                            zoom 1 as well, for the same reason every treatment gets one.

    Findings belong in docs/research/ or on #351.

    IT IS WRITTEN FOR ONE MACHINE AND SAYS WHERE. rf-isotope-collector is named in three places --
    $machine here, `data.raw.boiler["rf-isotope-collector"]` in the generated data stage, and the
    "rf-tritium" filter the control stage picks its west connection by. Pointing it at another
    machine is those three edits plus, if that machine's footprint is not square, a sheet per
    direction. So it is kept committed to be edited, not because it is already general: what
    survives unchanged is the method, and the next engine version can be asked the same question
    without rebuilding any of it.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Blender
    Path to blender.exe. Defaults to whatever tools/render-machine.py's own lookup finds, so this
    script and /render-machine never disagree about which Blender is in use.

.PARAMETER SheetDirectory
    Where the variant sprite sheets live. A directory that already holds <treatment>.png,
    <treatment>-shadow.png and <treatment>.manifest.json for every treatment is REUSED and Blender
    is not run at all. Rendering the variants is the slow part of a run, so this is what makes
    re-framing a shot cheap. Defaults to a directory under the temp path, so the default run
    renders every time.

.PARAMETER OutputDirectory
    Where the PNGs are copied. Defaults to a timestamped directory under the system temp path,
    which is printed at the end.

.PARAMETER Treatments
    Which treatments to render and shoot. Defaults to all four. Names must be ones
    models/socket-variants.py knows.

.PARAMETER Samples
    Cycles samples per variant render. 64 is what the shipped sheets use, and lowering it makes the
    frames noisier than the art they stand in for.

.PARAMETER TimeoutSeconds
    How long to wait for the game to write the done marker before giving up. Default 300.

.PARAMETER KeepTemp
    Leave the scratch mod directory, the variant models, the save and the raw script-output in place.

.EXAMPLE
    pwsh -File scripts/probe-socket-shapes.ps1

.EXAMPLE
    pwsh -File scripts/probe-socket-shapes.ps1 -SheetDirectory C:\tmp\rf-shapes -KeepTemp
#>

#Requires -Version 7

[CmdletBinding()]
param(
    [string]   $FactorioExe,
    [string]   $Blender,
    [string]   $SheetDirectory,
    [string]   $OutputDirectory,
    [string[]] $Treatments = @('bare', 'flanged', 'dark-cored', 'collared'),
    [int]      $Samples = 64,
    [int]      $TimeoutSeconds = 300,
    [switch]   $KeepTemp
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
. "$repoRoot/scripts/factorio-lib.ps1"

$ourMods = Get-RepoMods
$rigName = 'rf-socket-shape-probe'
$machine = 'isotope-collector'                    # the subject: every connection on it is uncontained,
                                                  # so every stub in frame is one a pipe can meet

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-shape-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

$sheetsSurvive = [bool]$SheetDirectory -or $KeepTemp
if (-not $SheetDirectory)   { $SheetDirectory   = Join-Path $temp 'sheets' }
if (-not $OutputDirectory)  { $OutputDirectory  = Join-Path ([IO.Path]::GetTempPath()) ('rf-shape-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }

# NEITHER DIRECTORY MAY BE INSIDE A MOD. models/socket-variants.py guards its own out path the same
# way and for the same reason: this rig's whole claim is that nothing it makes can ship, and an
# unvalidated -SheetDirectory pointed at the Assets mod would put four untracked PNGs beside the
# shipped sheets. Nothing would be overwritten -- the names differ -- but "never into the Assets
# mod" would stop being true, and a claim a script does not enforce is a claim it will outlive.
foreach ($guarded in @($ourMods)) {
    $full = [IO.Path]::GetFullPath((Join-Path $repoRoot $guarded))
    foreach ($given in @(@('-SheetDirectory', $SheetDirectory), @('-OutputDirectory', $OutputDirectory))) {
        $path = [IO.Path]::GetFullPath($given[1])
        if ($path -eq $full -or $path.StartsWith($full + [IO.Path]::DirectorySeparatorChar)) {
            throw "$($given[0]) $($given[1]) is inside the $guarded mod. Both directories hold throwaway files; give one outside every mod."
        }
    }
}
New-Item -ItemType Directory -Path $SheetDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

# ---------------------------------------------------------------------------- the variant sheets
#
# One Blender run per treatment builds a throwaway model, a second renders it. Only the NORTH
# direction is rendered: this rig places every subject facing north and never turns one, so the
# other three would be three more renders per treatment for sprites nobody looks at. The clone
# below points all four directions at that one sheet, which holds only while the footprint is
# square -- the guard below refuses a machine where it does not.
$missing = @($Treatments | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $SheetDirectory "$_.png")) -or
    -not (Test-Path -LiteralPath (Join-Path $SheetDirectory "$_-shadow.png")) -or
    -not (Test-Path -LiteralPath (Join-Path $SheetDirectory "$_.manifest.json"))
})
if ($missing) {
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

    $model    = Join-Path $repoRoot "models/$machine/$machine.blend"
    $geometry = Join-Path $repoRoot "models/$machine/geometry.json"
    if (-not (Test-Path -LiteralPath $model)) {
        throw "no stored model at $model. Run /render-machine rf-$machine --regenerate first."
    }
    $variantDir = Join-Path $temp 'variants'
    New-Item -ItemType Directory -Path $variantDir -Force | Out-Null
    # render.py reads geometry.json BESIDE the model it is given and refuses one whose hash has
    # moved, so the throwaway copies need the same file beside them.
    Copy-Item -LiteralPath $geometry -Destination $variantDir -Force

    foreach ($t in $missing) {
        Write-Host "rendering $t ..."
        $blend = Join-Path $variantDir "socket-$t.blend"
        & $Blender -b $model --python-exit-code 1 --python (Join-Path $repoRoot 'models/socket-variants.py') `
            -- $t $blend | Select-String -Pattern 'SOCKET-VARIANTS|socket-variants' | ForEach-Object { Write-Host "  $_" }
        if ($LASTEXITCODE -ne 0) { throw "socket-variants.py failed for $t (exit $LASTEXITCODE)." }

        $out = Join-Path $variantDir "sheets-$t"
        & $Blender -b $blend --python-exit-code 1 --python (Join-Path $repoRoot 'models/render.py') `
            -- --samples $Samples --directions 1 --out $out | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "render.py failed for $t (exit $LASTEXITCODE)." }

        # The manifest travels with the sheets because it is where the FRAME SIZE is read from
        # below. graphics/rendered/pictures.lua has to retype that arithmetic -- the data stage
        # cannot read JSON and its own comment says so -- but this script can read the file the
        # render actually wrote, so it does.
        foreach ($pair in @(@("socket-$t.png", "$t.png"), @("socket-$t-shadow.png", "$t-shadow.png"),
                            @('manifest.json', "$t.manifest.json"))) {
            $src = Join-Path $out $pair[0]
            if (-not (Test-Path -LiteralPath $src)) { throw "render.py wrote no $($pair[0]) for $t." }
            Copy-Item -LiteralPath $src -Destination (Join-Path $SheetDirectory $pair[1]) -Force
        }
    }
} else {
    Write-Host "reusing the sheets already in $SheetDirectory (Blender not run)"
}
foreach ($t in $Treatments) {
    Copy-Item -LiteralPath (Join-Path $SheetDirectory "$t.png") -Destination $rigDir -Force
    Copy-Item -LiteralPath (Join-Path $SheetDirectory "$t-shadow.png") -Destination $rigDir -Force
}

# ---------------------------------------------------------------------------- the rig mod
@{
    name = $rigName; version = '0.0.1'; title = 'Socket shape probe'
    author = 'probe-socket-shapes.ps1'; factorio_version = '2.0'
    dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed', 'realistic-fusion-refreshed-core',
                     'realistic-fusion-refreshed-assets')
} | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

$treatmentList = ($Treatments | ForEach-Object { '"' + $_ + '"' }) -join ', '

# The frame size, read off the manifest the render wrote rather than retyped. It is the footprint
# plus MARGIN_TILES on every side at 64 px a tile; if either moves, this follows without an edit.
$manifest = Get-Content -LiteralPath (Join-Path $SheetDirectory "$($Treatments[0]).manifest.json") -Raw | ConvertFrom-Json
$frameW, $frameH = $manifest.frame.north
if ($frameW -ne $frameH) {
    throw "the $machine sheet is ${frameW}x${frameH}, not square. This rig points all four " +
          'directions at the one rendered sheet, which only holds while the frame is square -- ' +
          'render every direction and give each side its own sheet before shooting a machine like that.'
}

$data = @"
-- Generated by probe-socket-shapes.ps1. Nothing here ships.
--
-- One clone of rf-isotope-collector per socket treatment, wearing that treatment's sheet. The
-- shipped prototype is left alone and is not placed by the rig, so no frame can catch it and no
-- edit here can reach it.

local TREATMENTS = { $treatmentList }
local FRAME_W, FRAME_H = $frameW, $frameH
local DIR = "__${rigName}__/"

local base = data.raw.boiler["rf-isotope-collector"]
if not base then error("rf-isotope-collector is not in data.raw.boiler") end

for _, t in ipairs(TREATMENTS) do
  local e = table.deepcopy(base)
  e.name = "rf-socket-" .. t
  e.localised_name = "socket shape: " .. t
  -- No item places or mines these: they exist to be created by the rig's control stage and to be
  -- photographed. Leaving minable in place would put a second entity behind the collector's item.
  e.minable = nil
  e.placeable_by = nil
  e.fast_replaceable_group = nil
  e.next_upgrade = nil

  -- ALL FOUR DIRECTIONS TAKE THE NORTH SHEET, which is a lie the rig can afford and a shipping mod
  -- could not: only one direction is rendered (see the script's comment on why), the rig places
  -- every subject facing north, and the footprint is square so the frame is the same size either
  -- way. Turn a subject and the sockets move while the picture does not.
  local function side()
    return {
      structure = {
        layers = {
          { filename = DIR .. t .. ".png", priority = "extra-high",
            width = FRAME_W, height = FRAME_H, scale = 0.5 },
          { filename = DIR .. t .. "-shadow.png", priority = "extra-high",
            width = FRAME_W, height = FRAME_H, scale = 0.5, draw_as_shadow = true },
        },
      },
    }
  end
  e.pictures = { north = side(), east = side(), south = side(), west = side() }
  data:extend({ e })
end
"@
Set-Content -Path (Join-Path $rigDir 'data-final-fixes.lua') -Value $data -Encoding utf8

# ---------------------------------------------------------------------------- the rig's control
$control = @"
-- Generated by probe-socket-shapes.ps1. Nothing here ships.

local TREATMENTS = { $treatmentList }
"@ + @'
local OUT = "rf-shape/"
local function say(line) localised_print('SHAPEPROBE ' .. line) end

local BUILD_CHECK = defines.build_check_type.manual
if not BUILD_CHECK then error("defines.build_check_type.manual is gone") end

local function place(surface, name, x, y)
  if not surface.can_place_entity({
      name = name, position = { x, y }, force = "player", build_check_type = BUILD_CHECK }) then
    error(string.format("%s will not fit at (%g, %g)", name, x, y))
  end
  local e = surface.create_entity({ name = name, position = { x, y }, force = "player", raise_built = true })
  if not e then error("could not place " .. name) end
  return e
end

--- The tile a named fluid's WEST-facing connection points at. Asked rather than written down:
--- this rig is about where a socket IS, so it must not assume.
local function west_connection(entity, fluid)
  for i = 1, #entity.fluidbox do
    local f = entity.fluidbox.get_filter(i)
    if (not fluid) or (f and f.name == fluid) then
      for _, c in pairs(entity.fluidbox.get_pipe_connections(i)) do
        if c.target_position and c.target_position.x < c.position.x then return c end
      end
    end
  end
end

--- Flat, dry, uniform ground, decoratives destroyed as well as tiles retiled -- set_tiles alone
--- leaves every shrub standing, which probe-isotope-collector-art.ps1 learnt the hard way.
local function pave(surface, x1, y1, x2, y2)
  local tiles = {}
  for x = math.floor(x1), math.ceil(x2) do
    for y = math.floor(y1), math.ceil(y2) do
      tiles[#tiles + 1] = { name = "grass-1", position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
  surface.destroy_decoratives({ area = { { x1, y1 }, { x2, y2 } } })
end

script.on_nth_tick(60, function()
  if storage.stage then return end
  storage.stage = "built"

  local surface = game.surfaces[1]
  surface.always_day = true

  -- The subjects are a long way apart so no frame can catch a neighbour, and the spacing is read
  -- off the footprint rather than typed: a rig that has to be re-tuned every time a footprint
  -- changes is a rig that photographs the wrong thing quietly.
  local box = prototypes.entity["rf-socket-" .. TREATMENTS[1]].collision_box
  local SIZE = math.ceil(math.max(box.right_bottom.x - box.left_top.x,
                                  box.right_bottom.y - box.left_top.y))
  -- THE SPACING IS EVEN ON PURPOSE, and the first version of this rig was not. Vanilla's pipe
  -- alternates between its plain sheet and its windowed one by the TILE'S OWN COORDINATE, so an
  -- odd spacing put a window under one treatment's frame and a plain barrel under the next, and
  -- two frames meant to differ only in the socket differed in the pipe as well. Rounding up to an
  -- even number puts every subject on the same parity and the same pipe under all of them.
  local SPACING = 2 * math.ceil((SIZE + 24) / 2)
  say(string.format("%d treatment(s), footprint %d, subjects %d apart", #TREATMENTS, SIZE, SPACING))

  surface.request_to_generate_chunks({ (#TREATMENTS * SPACING) / 2, 0 },
                                     math.ceil((#TREATMENTS * SPACING + 60) / 32))
  surface.force_generate_chunk_requests()

  local x1, y1 = -20, -SPACING
  local x2, y2 = #TREATMENTS * SPACING + 20, SPACING
  pave(surface, x1, y1, x2, y2)
  for _, e in pairs(surface.find_entities_filtered({ area = { { x1, y1 }, { x2, y2 } } })) do
    if e.type == "character" then
      if not e.teleport({ x2 - 3, y1 + 3 }) then error("could not park the character") end
    else
      e.destroy()
    end
  end

  -- Six tiles of pipe under every subject: enough that the frames at the game's own zoom show a
  -- RUN meeting the machine rather than one lonely pipe, which is a different picture and an
  -- easier one to like.
  local RUN = 6

  storage.shot = {}
  for k, t in ipairs(TREATMENTS) do
    local cx = 0.5 + (k - 1) * SPACING
    local subject = place(surface, "rf-socket-" .. t, cx, 0.5)
    local w = west_connection(subject, "rf-tritium")
    if not w then error("rf-socket-" .. t .. " has no west-facing rf-tritium connection") end
    for j = 0, RUN - 1 do place(surface, "pipe", w.target_position.x - j, w.target_position.y) end
    storage.shot[#storage.shot + 1] =
      { name = t, x = w.target_position.x, y = w.target_position.y }
    say(string.format("%s at %g,%g; west socket tile %g,%g", t, cx, 0.5,
      w.target_position.x, w.target_position.y))
  end

  -- THE REFERENCE IS THE SAME RUN WITH THE MACHINE TAKEN AWAY, not a short pipe somewhere else. It
  -- stands where the next subject would have stood and its east end is the tile a socket would have
  -- met, so the frame is identical in every respect but the one being judged -- same spacing, same
  -- parity, same six pipes, same framing. A reference shot differently is a reference nobody can
  -- subtract.
  local px = 0.5 + #TREATMENTS * SPACING
  local pipe_end = px - 3
  for j = 0, RUN - 1 do place(surface, "pipe", pipe_end - j, 0.5) end
  storage.shot[#storage.shot + 1] = { name = "pipe-alone", x = pipe_end, y = 0.5 }
  say(string.format("pipe-alone: %d pipes ending at %g,%g, where a socket would be", RUN, pipe_end, 0.5))

  storage.shoot_at = game.tick + 120
end)

script.on_event(defines.events.on_tick, function()
  if not storage.shoot_at or game.tick < storage.shoot_at then return end
  storage.shoot_at = nil
  local surface = game.surfaces[1]

  local function shot(file, x, y, tiles_w, tiles_h, zoom)
    game.take_screenshot({
      surface = surface, position = { x, y },
      resolution = { math.ceil(tiles_w * 32 * zoom), math.ceil(tiles_h * 32 * zoom) },
      zoom = zoom, path = OUT .. file, daytime = 0,
      show_gui = false, show_entity_info = false, anti_alias = true, force_render = true })
    say("shot " .. file)
  end

  for _, s in ipairs(storage.shot) do
    -- THE SEAM FRAME IS CENTRED ON THE SEAM, not on the machine: the subject is the half-tile where
    -- the socket stops and the pipe starts. Zoom 8 puts one tile on 256 px.
    shot("seam-" .. s.name .. ".png", s.x + 0.5, s.y, 4, 3, 8)
    -- AND THE SAME THING AT ZOOM 1, which is 32 px to the tile and what the game actually draws.
    -- A treatment nobody can tell from the control here is not a candidate, and magnification alone
    -- would hide that. Wide enough for the whole machine, its shadow and the run that feeds it; the
    -- lone pipe gets the same frame, so the two are read at the same size and in the same place.
    shot("game-" .. s.name .. ".png", s.x, s.y, 16, 8, 1)
  end

  game.set_wait_for_screenshots_to_finish()
  helpers.write_file(OUT .. "done.txt", "done\n")
  say("done")
end)
'@
Set-Content -Path (Join-Path $rigDir 'control.lua') -Value $control -Encoding utf8

# ---------------------------------------------------------------------------- run it
$proc = $null
try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    $enabled = Resolve-BundledSelection -Requested @() -Bundled $bundled
    Write-Host "bundled enabled: $(if ($enabled) { $enabled -join ', ' } else { 'none (base 2.0 only)' })"
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabled -Mods ($ourMods + $rigName)

    $save = Join-Path $temp 'shape.zip'
    Invoke-FactorioStep -FactorioExe $FactorioExe -ModDirectory $modDir -OutputDirectory $temp `
        -Tag 'create' -Arguments @('--create', $save) | Out-Null

    $configPath = Join-Path $temp 'factorio-config.ini'
    $shotDir    = Join-Path $temp 'write-data/script-output/rf-shape'
    $doneFile   = Join-Path $shotDir 'done.txt'

    $launchDir = Join-Path $temp 'launch'
    New-Item -ItemType Directory -Path $launchDir -Force | Out-Null
    '427520' | Set-Content -Path (Join-Path $launchDir 'steam_appid.txt') -Encoding ascii -NoNewline

    $line = (@('--config', $configPath, '--mod-directory', $modDir, '--load-game', $save,
               '--disable-audio') | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    Write-Host 'launching the graphical client; a window will open and close by itself.'
    $runOut = Join-Path $temp 'run-stdout.txt'
    $proc = Start-Process -FilePath $FactorioExe -ArgumentList $line `
        -WorkingDirectory $launchDir -PassThru -RedirectStandardOutput $runOut

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while (-not (Test-Path -LiteralPath $doneFile) -and (Get-Date) -lt $deadline) {
        if ($proc.HasExited) { throw "Factorio exited (code $($proc.ExitCode)) before writing the screenshots." }
        Start-Sleep -Milliseconds 500
    }
    if (-not (Test-Path -LiteralPath $doneFile)) { throw "timed out after $TimeoutSeconds s waiting for $doneFile." }

    # The marker is not the pictures: take_screenshot queues and the engine writes on its own
    # thread, so done.txt lands while every PNG is still zero bytes. Wait for settled sizes.
    # ITS OWN DEADLINE, not the one the marker wait just spent. Sharing it meant that done.txt
    # arriving near the timeout left this loop's body unrun, $sizes empty, and the script reporting
    # "(no PNG at all)" over a directory that was merely still being written.
    $settleBy = (Get-Date).AddSeconds([Math]::Max(30, $TimeoutSeconds / 4))
    $sizes = @{}
    while ((Get-Date) -lt $settleBy) {
        $now = @{}
        foreach ($f in (Get-ChildItem -LiteralPath $shotDir -Filter '*.png')) { $now[$f.Name] = $f.Length }
        $settled = $now.Count -gt 0 -and -not ($now.Values | Where-Object { $_ -eq 0 }) -and
                   $now.Count -eq $sizes.Count -and -not ($now.Keys | Where-Object { $sizes[$_] -ne $now[$_] })
        $sizes = $now
        if ($settled) { break }
        Start-Sleep -Milliseconds 700
    }
    $unwritten = @($sizes.Keys | Where-Object { $sizes[$_] -eq 0 })
    if ($sizes.Count -eq 0 -or $unwritten) {
        throw "the game wrote no bytes for: $(if ($unwritten) { $unwritten -join ', ' } else { '(no PNG at all)' })"
    }

    $shots = @(Get-ChildItem -LiteralPath $shotDir -Filter '*.png' | Sort-Object Name)
    foreach ($s in $shots) { Copy-Item -LiteralPath $s.FullName -Destination $OutputDirectory -Force }

    Write-Host ''
    Get-Content $runOut | Select-String -Pattern 'SHAPEPROBE ' |
        ForEach-Object { Write-Host (($_ -split 'SHAPEPROBE ', 2)[1].TrimEnd()) }
    Write-Host ''
    foreach ($s in $shots) {
        Write-Host ("  {0,-26} {1,8:N0} KB   {2}" -f $s.Name, ($s.Length / 1KB), (Join-Path $OutputDirectory $s.Name))
    }
    Write-Host ''
    Write-Host "screenshots: $OutputDirectory"
    # Only offer the reuse if the sheets will still be there. On a default run they are inside the
    # scratch directory the finally block deletes, and telling someone to reuse a path that is about
    # to stop existing is worse than saying nothing.
    if ($sheetsSurvive) {
        Write-Host "sheets:      $SheetDirectory  (pass the same -SheetDirectory to reuse them and skip Blender)"
    } else {
        Write-Host "sheets:      written under the scratch directory and deleted with it. Pass"
        Write-Host "             -SheetDirectory to keep them and skip Blender on the next run."
    }
}
finally {
    if ($proc -and -not $proc.HasExited) { $proc.Kill() ; $proc.WaitForExit(10000) | Out-Null }
    if (-not $KeepTemp) {
        Remove-ModJunctions -ModDirectory $modDir
        Remove-TempDirectory -Path $temp -Label 'probe-socket-shapes'
    } else { Write-Host "kept: $temp" }
}

Write-Host ''
Write-Host 'Probe finished. Exit 0 means the pictures were taken, not that any shape is right.'
Write-Host 'Read seam-bare.png and seam-pipe-alone.png first: they are the two references every'
Write-Host 'other frame is judged against. Then read every game-*.png, because a difference that'
Write-Host 'only exists at zoom 8 is not a candidate. The choice itself belongs on #351.'
