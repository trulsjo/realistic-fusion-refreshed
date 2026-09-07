<#
.SYNOPSIS
    Photographs rf-heat-exchanger's rendered art in a real map, so a person can accept or reject
    the look. Screenshots only -- it asserts nothing.

.DESCRIPTION
    A PROBE, NOT A CHECK. Exit 0 means it ran and wrote the pictures, never that the art is good.
    The question it answers is the one no gate can: does the rendered building read correctly in
    the game, at the game's own camera, beside the machines it stands next to? load-check proves
    the sheets exist and agree with the prototype's footprint (#250); nothing proves they look
    right. That is a person looking, and this is what puts the pictures in front of them (#252).

    WHY IT NEEDS THE GRAPHICAL CLIENT, unlike every other probe here. game.take_screenshot renders
    through the game's own renderer, so --benchmark and --create cannot produce one. This launches
    the full client against a scratch map, waits for the mod to write a done marker beside the
    screenshots, and then closes the game. A window opens for a few seconds; that is expected.

    WHAT IT SHOOTS, and why each one:

      layout.png         rf-reactor, then rf-heat-exchanger BOLTED to the reactor's south face
                         along all fifteen tiles, then rf-hc-exchanger to the east as a size
                         comparison. The bolted pair is the arrangement the shape exists for
                         (#108, ADR 0022) and the one ADR 0031 makes buildable (#275): energy
                         sells north and south, so the exchanger stands south of the reactor with
                         its north long face against it. The high-capacity machine is in frame
                         because the tier's whole message is that the two are told apart at a
                         glance -- it is beside the reactor rather than bolted to it, since east
                         and west are plasma and no exchanger can meet them.
      cold.png           The machine alone, not burning. What it looks like switched off.
      working-day.png    The machine alone, burning, at noon. The glow sheet is drawn additively
                         over the structure, so this is where #249's open question is settled:
                         whether the manifold channel reads as the energy accent or washes pale.
      working-night.png  The same at midnight, where the glow is all there is.
      rotations.png      One machine in each of the four directions, in a two-by-two grid whose
                         pitch comes from the machine's own footprint. The engine turns the
                         connections and not the picture, so this is where a wrongly ordered sheet
                         set shows itself: sockets on the wrong edge, cabinet in the wrong corner.

    The machine is fed by writing its fluid boxes directly each tick rather than by plumbing a
    reactor into it. The picture is the subject; how the energy got there is not, and a real
    reactor takes minutes of simulation to light. The probe prints each machine's status at the
    moment it was photographed, so a shot of a machine that was not actually burning cannot be
    mistaken for one that was.

    NOTHING HERE WRITES A FOOTPRINT DOWN, and that is a fix rather than a style (#275). Every
    position used to be a constant computed by hand for a machine five wide and fifteen tall:
    ADR 0031 turned it fifteen by five, and those constants then put the exchanger on top of the
    reactor and the four rotations on top of each other. `place()` refuses an overlap now instead
    of building one, the bolted pair is placed by asking the reactor where its connection points,
    and the rotation grid's pitch is read off the machine. A picture nobody can build is worse than
    no picture, because it looks like a picture.

    Findings belong in docs/research/ or on the ticket. Kept committed so the next machine rendered
    -- and the next engine version -- can be asked the same question.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER OutputDirectory
    Where the PNGs are copied. Defaults to a timestamped directory under the system temp path,
    which is printed at the end.

.PARAMETER TimeoutSeconds
    How long to wait for the game to write the done marker before giving up. Default 180.

.PARAMETER KeepTemp
    Leave the scratch mod directory, the save and the raw script-output in place.

.EXAMPLE
    pwsh -File scripts/probe-heat-exchanger-art.ps1
    pwsh -File scripts/probe-heat-exchanger-art.ps1 -OutputDirectory C:\tmp\hx-shots
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [string] $OutputDirectory,
    [int]    $TimeoutSeconds = 180,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
. "$repoRoot/scripts/factorio-lib.ps1"

$ourMods = Get-RepoMods
$rigName = 'rf-heat-exchanger-art-probe'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-hx-art-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path ([IO.Path]::GetTempPath()) ('rf-hx-art-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

@{
    name = $rigName; version = '0.0.1'; title = 'Heat exchanger art probe'
    author = 'probe-heat-exchanger-art.ps1'; factorio_version = '2.0'
    dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed', 'realistic-fusion-refreshed-core')
} | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

# ---------------------------------------------------------------------------- the rig's control
$control = @'
-- Generated by probe-heat-exchanger-art.ps1. Nothing here ships.

local MACHINE = "rf-heat-exchanger"
local ENERGY  = "rf-reactor-energy"
local OUT     = "rf-art/"

-- Tagged so the caller can pick these out of a log that is mostly not ours.
local function say(line) localised_print('ARTPROBE ' .. line) end

local BUILD_CHECK = defines.build_check_type.manual
if not BUILD_CHECK then
  error("defines.build_check_type.manual is gone; this rig's placement guard would silently "
    .. "fall back to ghost_revive")
end

--- An odd-sided building's centre sits at a tile centre, so its edges land on tile boundaries.
--- Every position below is at a tile centre on purpose: "flush" is only true if it is.
---
--- REFUSES AN OVERLAP RATHER THAN PHOTOGRAPHING ONE. create_entity does NOT collision-check, so
--- until #275 this happily stacked two machines on one another and the shot came out garbled --
--- which is the worst way for this probe to fail, because a probe asserts nothing and a garbled
--- picture still looks like a picture. bench-mod-links.ps1's place_or_die is the same guard for the
--- same reason; the error says "stale" because that is what a refused placement here means.
local function place(surface, name, x, y, direction)
  if not surface.can_place_entity({
      name = name, position = { x, y }, direction = direction,
      force = "player", build_check_type = BUILD_CHECK }) then
    error(string.format("%s will not fit at (%g, %g): something is already there, so this rig's "
      .. "layout is stale against that prototype's footprint", name, x, y))
  end
  local e = surface.create_entity({
    name = name, position = { x, y }, direction = direction,
    force = "player", raise_built = true,
  })
  if not e then error("could not place " .. name .. " at " .. x .. "," .. y) end
  return e
end

--- The machine's footprint in whole tiles, asked rather than written down.
local function footprint(name)
  local box = prototypes.entity[name].collision_box
  return math.ceil(box.right_bottom.x - box.left_top.x),
         math.ceil(box.right_bottom.y - box.left_top.y)
end

--- Which fluidbox index carries a given fluid, asked rather than assumed: the order of a boiler's
--- boxes is the engine's business, and rf-heat-exchanger's energy source adds one of its own.
local function box_of(entity, fluid)
  for i = 1, #entity.fluidbox do
    local f = entity.fluidbox.get_filter(i)
    if f and f.name == fluid then return i end
  end
end

--- Which way a connection faces, read off the tile it targets rather than remembered.
local function facing(connection)
  local dx = connection.target_position.x - connection.position.x
  local dy = connection.target_position.y - connection.position.y
  if dy < 0 then return "north" elseif dy > 0 then return "south" elseif dx < 0 then return "west" end
  return "east"
end

--- The connection of `entity`'s `fluid` box that faces `side`.
local function connection_facing(entity, fluid, side)
  local index = box_of(entity, fluid)
  if not index then error(entity.name .. " has no box filtered to " .. fluid) end
  for _, c in pairs(entity.fluidbox.get_pipe_connections(index)) do
    if facing(c) == side then return c end
  end
  error(entity.name .. " has no " .. side .. "-facing " .. fluid .. " connection")
end

--- Place `name` so that its `fluid` connection facing `side` STANDS ON `tile` -- which is the other
--- machine's target_position, and is the whole of the bolt arithmetic ADR 0018's Consequences calls
--- a trap: a pipe run aligns a connection's target onto the pipe's tile, a bolt aligns one
--- machine's connection TILE onto the other's target. Align target against target and the two sit
--- one tile clear of each other pointing at the same empty ground.
---
--- The machine is placed once as a scratch entity, asked where that connection sits relative to
--- itself, destroyed, and placed again by the difference -- so this reads the prototype instead of
--- asserting a layout it does not own. Raw create_entity for the scratch one on purpose: it is
--- thrown away, and an overlap changes nothing it is asked for.
local function bolt(surface, name, fluid, side, tile, seed)
  local scratch = surface.create_entity({ name = name, position = seed, force = "player" })
  if not scratch then error("could not place a scratch " .. name) end
  local c = connection_facing(scratch, fluid, side)
  local dx, dy = c.position.x - scratch.position.x, c.position.y - scratch.position.y
  scratch.destroy()
  return place(surface, name, tile.x - dx, tile.y - dy)
end

--- entity.status as its name. There is no status_string in 2.0.77.
local function status_name(entity)
  if not (entity and entity.valid) then return "?" end
  for k, v in pairs(defines.entity_status) do
    if v == entity.status then return k end
  end
  return tostring(entity.status)
end

--- Flat, dry, uniform ground under a rectangle, so the shot is of the machine and not of the
--- terrain it happened to land on -- and so nothing is refused for standing in water.
local function pave(surface, x1, y1, x2, y2)
  local tiles = {}
  for x = math.floor(x1), math.ceil(x2) do
    for y = math.floor(y1), math.ceil(y2) do
      tiles[#tiles + 1] = { name = "grass-1", position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
end

script.on_nth_tick(60, function()
  if storage.stage then return end
  storage.stage = "built"

  local surface = game.surfaces[1]
  surface.request_to_generate_chunks({ 0, 0 }, 8)
  surface.force_generate_chunk_requests()
  surface.always_day = true

  -- THE PITCH BETWEEN NEIGHBOURS, off the machine rather than written down. A rotated machine is
  -- as wide as the other one is tall, so the long side governs both axes; +3 keeps a few tiles of
  -- ground visible between neighbours and keeps the pitch EVEN, which matters because an
  -- odd-sided building's centre has to stay on a tile centre for its edges to land on boundaries.
  local W, H = footprint(MACHINE)
  local PITCH = math.max(W, H) + 3
  say(string.format("%s is %d x %d, so the grid pitch is %d", MACHINE, W, H, PITCH))

  -- Paved and cleared from the extremes the layout actually reaches, so moving a shot cannot leave
  -- a machine standing in water or behind somebody's trees. GRID is the rotations frame's centre.
  local GRID_X, GRID_Y = -0.5, 100.5
  local x1, y1 = math.min(-PITCH, GRID_X - PITCH), -PITCH
  local x2, y2 = 40.5 + 2 * PITCH + 8, GRID_Y + PITCH
  pave(surface, x1, y1, x2, y2)
  -- THE CHARACTER IS MOVED, NOT DESTROYED, AND IT IS MOVED BY THE ENTITY RATHER THAN THROUGH THE
  -- PLAYER. It stands at the spawn point, which is exactly where the reactor goes, and it is the
  -- one thing this sweep spares -- destroying the player's character on a live client is not
  -- something a screenshot is worth. It blocks a manual build check like anything else, so
  -- place()'s guard refused the reactor outright the first time this ran: the guard was right and
  -- the layout was wrong.
  --
  -- Going through game.players[i].character did NOT move it, measured on 2.0.77: a character
  -- entity stands at spawn at tick 60 while the player's own `character` is not yet the one to
  -- reach it by. Teleporting the entity the sweep already has in hand always works, and the return
  -- value is checked because a teleport that quietly fails would come back as the same baffling
  -- "will not fit" as before.
  local PARK_X, PARK_Y = x2 - 3, y1 + 3
  for _, e in pairs(surface.find_entities_filtered({
      area = { { x1 - 5, y1 - 5 }, { x2 + 5, y2 + 5 } } })) do
    if e.type == "character" then
      if not e.teleport({ PARK_X, PARK_Y }) then
        error(string.format("could not move the character off the spawn point to (%g, %g); it "
          .. "stands where the reactor goes", PARK_X, PARK_Y))
      end
      say(string.format("parked the character at %g,%g", PARK_X, PARK_Y))
    else
      e.destroy()
    end
  end

  -- THE BOLTED PAIR (ADR 0031, #275). The reactor sells reactor energy north and south, so the
  -- exchanger stands SOUTH of it with its north long face against the reactor's south output,
  -- meeting along all fifteen tiles. Nothing here computes where that is: the reactor is asked
  -- where its south connection points, and bolt() puts the exchanger's own north connection on
  -- that tile.
  --
  -- rf-hc-exchanger is to the EAST of the reactor and NOT bolted to it, which is the honest
  -- arrangement rather than a compromise: east and west are plasma (ADR 0011), so no exchanger can
  -- meet them, and this machine is in the picture for its size rather than for its plumbing. It
  -- follows the ordinary one to 15x5 in #276, and this rig will place it wherever it fits then.
  local reactor = place(surface, "rf-reactor", 0.5, 0.5)
  local south = connection_facing(reactor, ENERGY, "south")
  bolt(surface, MACHINE, ENERGY, "north", south.target_position, { GRID_X, GRID_Y - 3 * PITCH })
  place(surface, "rf-hc-exchanger", 0.5 + math.ceil(W / 2) + 7, 0.5)

  -- The two single-machine subjects, spaced off the pitch so one cannot creep into the other's
  -- frame when the footprint changes.
  local COLD_X = 40.5
  local WORKING_X = COLD_X + PITCH + 4
  local cold    = place(surface, MACHINE, COLD_X, 0.5)
  local working = place(surface, MACHINE, WORKING_X, 0.5)

  -- One per direction, in a two-by-two grid at that pitch, far enough north to stay out of every
  -- other frame. Four in a row was 66 tiles wide once the machine turned -- wider than any frame
  -- worth taking -- and two rows of two is the same four machines in a square.
  place(surface, MACHINE, GRID_X - PITCH / 2, GRID_Y - PITCH / 2, defines.direction.north)
  place(surface, MACHINE, GRID_X + PITCH / 2, GRID_Y - PITCH / 2, defines.direction.south)
  place(surface, MACHINE, GRID_X - PITCH / 2, GRID_Y + PITCH / 2, defines.direction.east)
  place(surface, MACHINE, GRID_X + PITCH / 2, GRID_Y + PITCH / 2, defines.direction.west)

  storage.cold = cold
  storage.working = working
  storage.grid = { x = GRID_X, y = GRID_Y, pitch = PITCH }
  storage.solo = { cold_x = COLD_X, working_x = WORKING_X, w = W, h = H }
  storage.shoot_at = game.tick + 120
end)

script.on_event(defines.events.on_tick, function()
  if not storage.shoot_at then return end
  local w = storage.working
  if w and w.valid then
    w.fluidbox[box_of(w, ENERGY)] = { name = ENERGY, amount = 200 }
    w.fluidbox[box_of(w, "water")] = { name = "water", amount = 200 }
    w.fluidbox[box_of(w, "steam")] = nil
  end
  if game.tick < storage.shoot_at then return end
  storage.shoot_at = nil

  local surface = game.surfaces[1]

  -- Reported so a picture of a machine that was NOT burning cannot be read as one that was. This
  -- is the whole difference between cold.png and working-*.png.
  say("cold machine status    : " .. status_name(storage.cold))
  say("working machine status : " .. status_name(storage.working))

  -- daytime is passed per shot rather than set on the surface, so one run gives both. 0 is noon
  -- and 0.5 is midnight; the pictures say which is which and the names are checked against them.
  local function shot(file, x, y, w_px, h_px, zoom, daytime)
    game.take_screenshot({
      surface = surface, position = { x, y }, resolution = { w_px, h_px }, zoom = zoom,
      path = OUT .. file, daytime = daytime,
      show_gui = false, show_entity_info = false, anti_alias = true, force_render = true,
    })
    say("shot " .. file)
  end

  -- EVERY FRAME IS SIZED IN TILES AND THEN CONVERTED, because a resolution alone says nothing
  -- about what is in shot: at zoom z one tile is 32*z pixels. The layout frame has to hold the
  -- reactor and the machine bolted below it -- twenty tiles of subject where the old one framed
  -- nineteen and clipped -- and the rotations frame has to hold the grid above.
  local function tiles_shot(file, x, y, tiles_w, tiles_h, zoom, daytime)
    shot(file, x, y, math.ceil(tiles_w * 32 * zoom), math.ceil(tiles_h * 32 * zoom), zoom, daytime)
  end

  local g, solo = storage.grid, storage.solo
  local pair_h = 15 + solo.h + 2          -- the reactor, the machine bolted below it, and margin

  -- THE SINGLE-MACHINE FRAMES ARE SIZED OFF THE MACHINE TOO, and they were the last thing here
  -- still written for the old shape: 864 x 1824 at zoom 3 is nine tiles wide by nineteen tall, a
  -- portrait frame for a machine five wide and fifteen long. Turned fifteen by five, the subject
  -- ran out of both sides of its own portrait -- and cold.png and working-*.png are the shots this
  -- probe exists for.
  local solo_w, solo_h = solo.w + 6, solo.h + 6

  tiles_shot("layout.png",       7.0, 0.5 + solo.h / 2, 30, pair_h, 2, 0)
  tiles_shot("cold.png",         solo.cold_x,    0.5, solo_w, solo_h, 3, 0)
  tiles_shot("working-day.png",  solo.working_x, 0.5, solo_w, solo_h, 3, 0)
  tiles_shot("working-night.png", solo.working_x, 0.5, solo_w, solo_h, 3, 0.5)
  tiles_shot("rotations.png", g.x, g.y, 2 * g.pitch + 4, 2 * g.pitch + 4, 1.5, 0)

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

    $save = Join-Path $temp 'art.zip'
    Invoke-FactorioStep -FactorioExe $FactorioExe -ModDirectory $modDir -OutputDirectory $temp `
        -Tag 'create' -Arguments @('--create', $save) | Out-Null

    # The same private write-data directory Invoke-Factorio makes, reused: it is where the config
    # points, so it is also where script-output lands.
    $configPath = Join-Path $temp 'factorio-config.ini'
    $shotDir    = Join-Path $temp 'write-data/script-output/rf-art'
    $doneFile   = Join-Path $shotDir 'done.txt'

    # Launched from a scratch directory holding steam_appid.txt, for the reason dev-launch.ps1
    # gives: the Steam API reads that file from the WORKING directory and otherwise relaunches the
    # game through Steam, dropping --mod-directory and --config on the floor.
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
    if (-not (Test-Path -LiteralPath $doneFile)) {
        throw "timed out after $TimeoutSeconds s waiting for $doneFile."
    }

    # THE MARKER IS NOT THE PICTURES. take_screenshot queues; the engine renders and writes on its
    # own thread, and helpers.write_file lands in the same tick that queued them -- so done.txt
    # appears while every PNG is still zero bytes. Found the hard way: the first run of this probe
    # copied five empty files and reported success. Wait until each file has a size that has
    # stopped changing.
    $sizes = @{}
    while ((Get-Date) -lt $deadline) {
        $now = @{}
        foreach ($f in (Get-ChildItem -LiteralPath $shotDir -Filter '*.png')) { $now[$f.Name] = $f.Length }
        $settled = $now.Count -gt 0 -and
                   -not ($now.Values | Where-Object { $_ -eq 0 }) -and
                   $now.Count -eq $sizes.Count -and
                   -not ($now.Keys | Where-Object { $sizes[$_] -ne $now[$_] })
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
    Get-Content $runOut | Select-String -Pattern 'ARTPROBE ' |
        ForEach-Object { Write-Host (($_ -split 'ARTPROBE ', 2)[1].TrimEnd()) }
    Write-Host ''
    foreach ($s in $shots) {
        $img = Join-Path $OutputDirectory $s.Name
        Write-Host ("  {0,-20} {1,8:N0} KB   {2}" -f $s.Name, ($s.Length / 1KB), $img)
    }
    Write-Host ''
    Write-Host "screenshots: $OutputDirectory"
}
finally {
    if ($proc -and -not $proc.HasExited) { $proc.Kill() ; $proc.WaitForExit(10000) | Out-Null }
    if (-not $KeepTemp) {
        Remove-ModJunctions -ModDirectory $modDir
        Remove-TempDirectory -Path $temp -Label 'probe-heat-exchanger-art'
    } else { Write-Host "kept: $temp" }
}

Write-Host ''
Write-Host 'Probe finished. Exit 0 means the pictures were taken, not that the art is right.'
