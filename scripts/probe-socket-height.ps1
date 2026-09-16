<#
.SYNOPSIS
    Photographs every socket a player can plumb against an ordinary pipe, close up and at the size
    a player meets it, on both rendered machines. Screenshots only -- it asserts nothing.

.DESCRIPTION
    A PROBE, NOT A CHECK. Exit 0 means it ran and wrote the pictures, never that the sockets are
    right. It was written for a defect Truls found on 2026-09-13 that had been shipping unseen:
    a rendered socket and the vanilla pipe plugged into it DID NOT LINE UP. The machine's stub was
    drawn higher than the pipe's, so a run of pipe met a machine at a step.

    NOBODY HAD LOOKED, and that is the interesting part. Both rendered machines put their sockets at
    z 0.55, so both had it. scripts/probe-heat-exchanger-art.ps1 shot the machine bolted to a
    reactor, alone, and in four rotations, and never once put a pipe on it (#346 is where it
    learned to); probe-isotope-collector-art.ps1 was the first to do that, and the first frame
    showed it. load-check compares a manifest's geometry against the prototype and cannot see a
    sprite at all -- #344 is the gate that can, and it was written from what this probe measured.

    WHAT THE SPRITES SAID, measured off the sheets rather than off a screenshot, because both are
    drawn at scale 0.5 with no shift and are therefore directly comparable at 64 px to the tile:

      vanilla pipe   body 0.609 tiles tall on screen, centre 0.0234 tiles above ground
      our socket     body 0.750 tiles tall on screen, centre 0.398 tiles above ground

    THE PIPE'S CENTRE READ 0.031 HERE UNTIL #355, and the half-pixel error it carried was in the
    shipped art until #356: the height was solved from it, so every plumbable socket sat 0.011 tiles
    of world height high -- 0.25 px at the game's own zoom. The gate measures the reference off
    vanilla's sheet now rather than carrying it, and holds the constant against it. The reading
    above is corrected; nothing else below has moved.

    A world height h shows as 0.707 h on screen, so our socket was drawn about 0.52 tiles of world
    height too high, and about a quarter too fat.

    BOTH HAVE SINCE BEEN FIXED ON BOTH MACHINES, and not by making a cylinder pretend to be
    vanilla's ribbon. Work vanilla's drawn extents back and no cylinder fits them: it is a stylised
    flat ribbon, drawn low and shallow, the way Factorio's own art is. What Truls settled instead --
    the height on 2026-09-14, the thickness on #345 -- is that our honest cylinder is drawn at the
    pipe's own CENTRE and at the pipe's own WIDTH, and that the tube then passing through the
    plinth is preferable to one floating over it so long as the floor has a modelled hole for it.
    models/house-style.md carries the rule and the arithmetic, models/rf_blender.py's `SOCKET_Z` the
    height itself (it moved there from rf_parts in #354, so a gate can read it), and #343 is where
    rf-heat-exchanger followed rf-isotope-collector to both.

    IT BINDS ONLY A SOCKET A PLAYER CAN PLUMB, and it finds out which those are by asking rather
    than by listing. A pipe is built on the tile every connection of every subject points at, and
    the engine is then asked whether it joined; one that did not is destroyed again and gets no
    frame. rf-heat-exchanger's three reactor-energy connections are contained (ADR 0018) and drop
    out that way, which is also the stronger answer -- it is the same question a player asks by
    dragging a pipe at the machine, and it stays right the day a category changes. So a third
    machine with a plumbable socket is covered without editing this file.

    THE CONTAINED SOCKETS ARE NOT PHOTOGRAPHED HERE. They keep the machine's old 0.55 and radius
    0.3 on purpose and never meet a pipe, so there is no seam to shoot;
    scripts/probe-heat-exchanger-art.ps1 is where they are shown refusing one.

    SO THESE FRAMES ARE NOW A REGRESSION CHECK BY EYE rather than the question itself. A socket
    drawn at the right height and width can still be the wrong SHAPE beside a pipe, and that is a
    person looking, which is what keeps this a probe.

    WEST WAS NOT THE WHOLE STORY, and #378 is why every side is shot now. Six plumbable sockets
    exist across the two machines and this probe used to photograph two of them, both facing west.
    TWO THINGS MAKE A SEAM READ DIFFERENTLY BY SIDE:

      THE LIT SIDE AND THE SHADOWED SIDE ARE THE SAME FRAME. The sun is parented to the rig
      (models/render.py: "The sun is parented to the same rig, so every sheet is lit from
      screen-left and shadows fall screen-right"), so within one sheet a west socket sits on the lit
      side and an east socket on the shadowed side. Identical geometry, different read, and only the
      lit one had ever been looked at closely.

      A NORTH OR SOUTH SOCKET IS MET END-ON. It runs along the camera's axis, so a player sees its
      mouth rather than its side. tools/socket_strip.py sidesteps that deliberately for MEASUREMENT
      -- it reads a north or south connection on the -e sheet, where the socket lies across the
      screen -- which is sound arithmetic and means the seam a player actually meets on a north
      socket had never been measured or photographed at all.

    WHAT AN END-ON SEAM SHOWS, WHICH IS LESS THAN A SIDE-ON ONE, and the answer is a finding rather
    than a guess: the frames were shot and looked at on 2026-09-16. The frame is turned for it --
    three tiles across by four down rather than four by three -- because the subject is a column
    rather than a run. On rf-isotope-collector's NORTH socket the pipe's own body is drawn over the
    machine's stub, and what shows past the pipe's edge is the mouth ring and its accent, nothing
    of the tube. On rf-heat-exchanger's SOUTH socket it is the other way round -- the machine's
    body is drawn over the seam and the stub is behind it altogether. So NEITHER FRAME SHOWS A
    LENGTH OF TUBE BESIDE A LENGTH OF PIPE, and neither height nor width can be judged in one,
    which is the whole of what a side-on frame is for. tools/check-socket-height.py is the gate
    that sees height, on every side, off the sheets.

    THEY ARE KEPT ANYWAY, and not for completeness. What they show is what a player actually meets
    on those two sides, which is a pipe and a machine and not a seam -- and that is worth a picture
    precisely because it is the thing no side-on frame can tell you. This is a probe: it answers a
    question and asserts nothing.

    THE GROUND HOLDS STILL BETWEEN RUNS since #374, and it did not before. Measured on 2026-09-16
    across a before-and-after pair shot for #357, 84.75 per cent of the reference frame's 786,432
    pixels differed between two runs on art that had not changed -- a frame whose only subject is
    three tiles of vanilla pipe. So the pairs could not be diffed, which is the cheap check that
    catches a regression nobody's eye happened to land on.

    AND THE MAP SEED IS NOT WHAT CAUSED IT, which is worth writing down because it is what the
    ticket expected and it was tried first. Pinning a seed and building on a surface of the rig's
    own left the ground differing on 84.53 per cent of that frame, at a mean channel delta of 11 --
    unchanged in kind. The cause is the TILE: base's grass-1 declares its variants with weighted
    probabilities over sizes 1, 2 and 4, so the engine draws for every tile set_tiles writes, and
    no seed a rig can set reaches that draw. The rig paves with a lab tile instead, whose main
    variant is `count = 1`, and then two runs are byte-identical. Measured both ways on 2026-09-16.

    THE SEED IS KEPT ANYWAY, for what the floor does not cover: the rig creates its own surface
    with the seed typed below, so the trees, rocks and decoratives OUTSIDE the paved rectangle are
    the same ones every run. No frame reaches them today. One would the day a footprint grew, and a
    plant in the corner of one run frame and not the other is the other half of what #374 found.

    WHAT IT SHOOTS, per plumbable socket, and the machine, the side and the fluid are in the name:

      seam-<machine>-<side>-<fluid>.png   that socket with an ordinary pipe on it, at zoom 8 --
                            one tile on 256 px, which is EIGHT times what a player sees -- and
                            nothing else in frame. The subject is the seam between the two.
      run-<machine>-<side>-<fluid>.png    the same socket with a five-tile pipe run leaving it, at
                            ZOOM 1 -- 32 px to the tile, the size a player meets it at. This is the
                            one a player would actually see, and it is here so the join can be
                            judged at that size rather than only under magnification.

    and once, as the reference every seam frame is read against:

      pipe-alone.png        three tiles of ordinary pipe on bare ground at zoom 8, with no machine
                            anywhere near it.

    THE ZOOMS ARE NAMED BY NUMBER RATHER THAN DESCRIBED, and #371 is why. The run frame was shot at
    zoom 2, and FIVE CLAIMS were wrong about it -- four sentences in three places, enumerated
    because a count is no better than the list behind it:

      1. its entry, that it is "at the game's own zoom"
      2. that entry again, that it "is the one a player would actually see"
      3. the joint-frames comment, that zoom 8 is "four times what a player sees" -- it is eight
      4. that same sentence, that "a step of a fifth of a tile is three pixels at the game's own
         zoom"
      5. the comment above the run shot, that it is "the size a player actually meets it"

    So the one frame that exists to say whether a difference is VISIBLE showed it at twice the size
    it is met at.

    THEY ARE NOT ALL PUT RIGHT THE SAME WAY, which is worth saying because only one of them was a
    wrong sentence. 1, 2 and 5 were false only because the shot was at zoom 2: moving it to zoom 1
    makes them true, and they now name the zoom rather than describe it. 3 is a wrong number and is
    corrected in place. 4 is REPLACED rather than corrected -- no reading of 0.2 tiles at any scale
    this repository uses gives three pixels, 6.4 on the ground at zoom 1 or 4.5 as a world height
    through the 0.707 projection -- so rather than swap in a figure that cannot be derived from what
    was written, that sentence gives way to the worked example above, which this file already
    proves. docs/research/socket-shapes.md had it right all along -- "zoom 1, 32 px to the tile,
    where a player meets it" -- so the two socket probes now agree about a term they both use, and
    CONTEXT.md's Measurement words is where it is fixed for everyone else.

    Findings belong in docs/research/ or on the ticket. Kept committed so the next machine rendered
    -- and the next engine version -- can be asked the same question.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER OutputDirectory
    Where the PNGs are copied. Defaults to a timestamped directory under the system temp path,
    which is printed at the end.

.PARAMETER TimeoutSeconds
    How long to wait for the game to write the done marker before giving up. Default 240.

.PARAMETER KeepTemp
    Leave the scratch mod directory, the save and the raw script-output in place.

.EXAMPLE
    pwsh -File scripts/probe-socket-height.ps1
#>

#Requires -Version 7

[CmdletBinding()]
param(
    [string] $FactorioExe,
    [string] $OutputDirectory,
    [int]    $TimeoutSeconds = 240,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
. "$repoRoot/scripts/factorio-lib.ps1"

$ourMods = Get-RepoMods
$rigName = 'rf-socket-height-probe'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-sock-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path ([IO.Path]::GetTempPath()) ('rf-sock-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

@{
    name = $rigName; version = '0.0.1'; title = 'Socket height probe'
    author = 'probe-socket-height.ps1'; factorio_version = '2.0'
    dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed', 'realistic-fusion-refreshed-core')
} | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

# ---------------------------------------------------------------------------- the rig's control
$control = @'
-- Generated by probe-socket-height.ps1. Nothing here ships.

local OUT = "rf-sock/"
local function say(line) localised_print('SOCKPROBE ' .. line) end

-- THE SEED IS TYPED so the rig owns its ground rather than borrowing the save's. It is NOT what
-- makes two runs identical -- `pave` below is, and its comment says why -- and it was tried alone
-- first and did not. What it holds is everything the floor does not: the trees, rocks and
-- decoratives outside the paved rectangle, which no frame reaches today and one would the day a
-- footprint grew. Any fixed number does; this one is the ticket's.
local MAP_SEED = 374
local SURFACE = "rf-socket-probe"

-- The two rendered machines. Which of their sockets get shot is asked of the engine below, not
-- listed here.
local SUBJECTS = { "rf-isotope-collector", "rf-heat-exchanger" }

local DIR = { north = { 0, -1 }, south = { 0, 1 }, west = { -1, 0 }, east = { 1, 0 } }
local RUN_TILES = 4                -- pipes beyond the one on the socket's own tile

local BUILD_CHECK = defines.build_check_type.manual
if not BUILD_CHECK then error("defines.build_check_type.manual is gone") end

local function place(surface, name, x, y, direction)
  if not surface.can_place_entity({
      name = name, position = { x, y }, direction = direction,
      force = "player", build_check_type = BUILD_CHECK }) then
    error(string.format("%s will not fit at (%g, %g)", name, x, y))
  end
  local e = surface.create_entity({
    name = name, position = { x, y }, direction = direction, force = "player", raise_built = true })
  if not e then error("could not place " .. name) end
  return e
end

local function footprint(name)
  local box = prototypes.entity[name].collision_box
  return math.ceil(box.right_bottom.x - box.left_top.x),
         math.ceil(box.right_bottom.y - box.left_top.y)
end

--- Which way a connection points away from its machine, as one of DIR's keys.
local function facing(c)
  local dx = c.target_position.x - c.position.x
  local dy = c.target_position.y - c.position.y
  if dy < 0 then return "north" elseif dy > 0 then return "south"
  elseif dx < 0 then return "west" end
  return "east"
end

--- Names go in filenames, and rf- on both halves of every one of them says nothing.
local function short(name) return (string.gsub(name, "^rf%-", "")) end

--- Every connection on `entity` that an ordinary pipe actually joins, as { side, fluid, tile }.
---
--- ASKED, NOT LISTED, and the same way scripts/probe-heat-exchanger-art.ps1 asks it: a pipe is
--- built on the tile each connection points at and the engine is then asked whether it took. One
--- that did not is destroyed again, which is what contained means (ADR 0018). Stronger than any
--- table here could be, because it is the question a player asks by dragging a pipe at the machine,
--- and it stays right the day a connection's category changes.
local function plumbable(surface, entity)
  local found, refused = {}, 0
  for i = 1, #entity.fluidbox do
    local filter = entity.fluidbox.get_filter(i)
    for _, c in pairs(entity.fluidbox.get_pipe_connections(i)) do
      if c.target_position and #surface.find_entities_filtered({ position = c.target_position }) == 0 then
        local p = place(surface, "pipe", c.target_position.x, c.target_position.y)
        local joined = false
        for _, pc in pairs(p.fluidbox.get_pipe_connections(1)) do
          if pc.target and pc.target.owner and pc.target.owner.unit_number == entity.unit_number then
            joined = true
          end
        end
        if joined then
          found[#found + 1] = {
            side = facing(c),
            fluid = filter and filter.name or ("box" .. i),
            tile = { x = c.target_position.x, y = c.target_position.y },
          }
        else
          p.destroy()
          refused = refused + 1
        end
      end
    end
  end
  say(string.format("%s: %d plumbable socket(s), %d refused a pipe", entity.name, #found, refused))
  return found
end

--- Flat, dry, uniform ground, decoratives destroyed as well as tiles retiled -- set_tiles alone
--- leaves every shrub standing, which probe-isotope-collector-art.ps1 learnt the hard way.
---
--- THE TILE HAS ONE VARIANT, AND THAT IS THE WHOLE OF #374. It was grass-1, whose variants.main
--- carries weighted probabilities over sizes 1, 2 and 4 -- so the engine DRAWS for every tile it
--- sets, and two runs paved the same rectangle with different grass. A fixed map seed does not
--- reach that draw: it was tried first and the ground still differed on 85 per cent of the
--- reference frame. base's lab tiles are the ones whose main variant is `count = 1`, so there is
--- nothing to draw and the floor is the same floor every run. Dark rather than white because every
--- subject here is a light-grey machine and a tan pipe, and a shadow has to stay readable under
--- them.
local FLOOR = "lab-dark-2"

--- The one-variant claim is NOT asserted here. A probe asserts nothing, and what checks this one is
--- the thing it exists for: two runs and a diff. The header says so.
local function pave(surface, x1, y1, x2, y2)
  local tiles = {}
  for x = math.floor(x1), math.ceil(x2) do
    for y = math.floor(y1), math.ceil(y2) do
      tiles[#tiles + 1] = { name = FLOOR, position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
  surface.destroy_decoratives({ area = { { x1, y1 }, { x2, y2 } } })
end

script.on_nth_tick(60, function()
  if storage.stage then return end
  storage.stage = "built"

  local surface = game.get_surface(SURFACE) or game.create_surface(SURFACE, { seed = MAP_SEED })
  surface.request_to_generate_chunks({ 0, 0 }, 8)
  surface.force_generate_chunk_requests()
  surface.always_day = true

  -- Three subjects, a long way apart, so no frame can catch a neighbour. The zoom here is extreme
  -- and the frames are small, but the spacing is generous on purpose: a rig that has to be
  -- re-tuned every time a footprint changes is a rig that photographs the wrong thing quietly.
  local SPACING = 0
  for _, name in ipairs(SUBJECTS) do
    local w, h = footprint(name)
    SPACING = math.max(SPACING, w, h)
    say(string.format("%s is %dx%d", name, w, h))
  end
  SPACING = SPACING + 24
  say(string.format("subjects %d apart", SPACING))

  local x1, y1 = -20, -SPACING - 20
  local x2, y2 = (#SUBJECTS) * SPACING + 20, SPACING + 20
  pave(surface, x1, y1, x2, y2)
  for _, e in pairs(surface.find_entities_filtered({ area = { { x1, y1 }, { x2, y2 } } })) do
    e.destroy()
  end
  -- THE PLAYER IS LEFT WHERE IT IS, on the save's own surface, and take_screenshot's force_render
  -- draws this one anyway. Moving it here was tried first and the engine refused the teleport --
  -- freeplay has the player in its intro cutscene at this tick -- and the parking that the rig used
  -- to need is not needed at all now: nobody is standing on this surface to get into a frame.

  local frames = {}
  for n, name in ipairs(SUBJECTS) do
    local machine = place(surface, name, 0.5 + (n - 1) * SPACING, 0.5)
    local centre = machine.position
    for _, s in ipairs(plumbable(surface, machine)) do
      local d = DIR[s.side]
      for k = 1, RUN_TILES do
        place(surface, "pipe", s.tile.x + d[1] * k, s.tile.y + d[2] * k)
      end
      -- A NORTH OR SOUTH SOCKET IS MET END-ON, so its frame is turned: the subject is a column
      -- rather than a run, and 4x3 tiles on it is three tiles of ground either side of a thing one
      -- tile wide. The header says what such a frame can and cannot settle.
      local endon = d[1] == 0
      local tag = string.format("%s-%s-%s", short(name), s.side, short(s.fluid))
      frames[#frames + 1] = { file = "seam-" .. tag .. ".png",
        x = s.tile.x - d[1] * 0.5, y = s.tile.y - d[2] * 0.5,
        w = endon and 3 or 4, h = endon and 4 or 3, zoom = 8 }
      frames[#frames + 1] = { file = "run-" .. tag .. ".png",
        x = centre.x + d[1] * 4, y = centre.y + d[2] * 4,
        w = endon and 8 or 14, h = endon and 14 or 8, zoom = 1 }
      say(string.format("%s %s %s: socket tile %g,%g", name, s.side, s.fluid, s.tile.x, s.tile.y))
    end
  end
  if #frames == 0 then error("no subject has a socket an ordinary pipe will join") end

  -- The reference: three tiles of ordinary pipe on bare ground, nothing near it. Shot ONCE -- it is
  -- what every seam frame is read against, and a second copy of it is a second thing to keep true.
  local PIPE_X, PIPE_Y = 0.5 + (#SUBJECTS) * SPACING, 0.5
  for k = -1, 1 do place(surface, "pipe", PIPE_X + k, PIPE_Y) end
  frames[#frames + 1] = { file = "pipe-alone.png", x = PIPE_X, y = PIPE_Y, w = 4, h = 3, zoom = 8 }

  storage.frames = frames
  storage.shoot_at = game.tick + 120
end)

script.on_event(defines.events.on_tick, function()
  if not storage.shoot_at or game.tick < storage.shoot_at then return end
  storage.shoot_at = nil
  local surface = game.get_surface(SURFACE)

  -- THE SEAM FRAMES ARE CENTRED ON THE SEAM, not on either machine: the subject is the half-tile
  -- where the socket stops and the pipe starts. Zoom 8 puts one tile on 256 px, which is EIGHT
  -- times what a player sees -- zoom 1, 32 px to the tile -- and that is the point. The header's
  -- own worked example says how small the subject is: 0.011 tiles of world height, the error this
  -- probe was built for, is a quarter of a pixel at the game's zoom. Nothing that small can be
  -- argued about unmagnified. The run frames are the same seams at zoom 1, which is the frame that
  -- decides whether any of this matters; they were shot at zoom 2 until #371, which made every
  -- difference in the one frame that judges visibility look twice its real size.
  for _, f in ipairs(storage.frames) do
    game.take_screenshot({
      surface = surface, position = { f.x, f.y },
      resolution = { math.ceil(f.w * 32 * f.zoom), math.ceil(f.h * 32 * f.zoom) },
      zoom = f.zoom, path = OUT .. f.file, daytime = 0,
      show_gui = false, show_entity_info = false, anti_alias = true, force_render = true })
    say("shot " .. f.file)
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

    $save = Join-Path $temp 'sock.zip'
    Invoke-FactorioStep -FactorioExe $FactorioExe -ModDirectory $modDir -OutputDirectory $temp `
        -Tag 'create' -Arguments @('--create', $save) | Out-Null

    $configPath = Join-Path $temp 'factorio-config.ini'
    $shotDir    = Join-Path $temp 'write-data/script-output/rf-sock'
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
    $sizes = @{}
    while ((Get-Date) -lt $deadline) {
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
    Get-Content $runOut | Select-String -Pattern 'SOCKPROBE ' |
        ForEach-Object { Write-Host (($_ -split 'SOCKPROBE ', 2)[1].TrimEnd()) }
    Write-Host ''
    foreach ($s in $shots) {
        Write-Host ("  {0,-46} {1,8:N0} KB" -f $s.Name, ($s.Length / 1KB))
    }
    Write-Host ''
    Write-Host "screenshots: $OutputDirectory"
    Write-Host "Both rendered machines draw every socket a player can plumb at rf_parts' SOCKET_Z"
    Write-Host 'and at radius 0.249 now -- where a vanilla pipe draws its own body, and as thick --'
    Write-Host 'so the step these frames were taken to show is gone. What is left to judge by eye is'
    Write-Host 'the SHAPE of the join, on every side a player can plumb rather than only the west.'
}
finally {
    if ($proc -and -not $proc.HasExited) { $proc.Kill() ; $proc.WaitForExit(10000) | Out-Null }
    if (-not $KeepTemp) {
        Remove-ModJunctions -ModDirectory $modDir
        Remove-TempDirectory -Path $temp -Label 'probe-socket-height'
    } else { Write-Host "kept: $temp" }
}

Write-Host ''
Write-Host 'Probe finished. Exit 0 means the pictures were taken, not that the sockets are right.'
Write-Host 'Two runs on unchanged art are byte-identical (#374); a diff of the pair is the cheap check.'
