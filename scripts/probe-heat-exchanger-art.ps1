<#
.SYNOPSIS
    Photographs rf-heat-exchanger's rendered art in a real map, so a person can accept or reject
    the look. Screenshots only -- it asserts nothing.

.DESCRIPTION
    A PROBE, NOT A CHECK. Exit 0 means it ran and wrote the pictures, never that the art is good.
    The question it answers is the one no gate can: does the rendered building read correctly in
    the game, at zoom 1 -- 32 px to the tile, the game's own camera, the size a player meets it at
    (CONTEXT.md, Zoom) -- and again magnified, beside the machines it stands next to? load-check proves
    the sheets exist and agree with the prototype's footprint (#250); nothing proves they look
    right. That is a person looking, and this is what puts the pictures in front of them (#252).

    THE SIBLING OF scripts/probe-isotope-collector-art.ps1, AND THEY NOW SHARE THEIR SCAFFOLDING.
    place(), footprint(), box_of(), status_name(), pave(), pipe_up(), the character sweep, the
    shutter, the launch and the settle-wait live in scripts/art-probe-lib.ps1 and are dot-sourced
    from both (#386). Everything below this paragraph is this machine's own question.

    WHAT THIS PROBE KEEPS FOR ITSELF: the bolt arithmetic. `facing`, `connection_facing` and `bolt`
    place one machine so that its own connection tile lands on another machine's target -- which is
    what ADR 0018's Consequences call a trap, and which the collector's probe has no use for,
    because that machine shares no connection with a reactor at all.

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
      pipes.png          One machine with an ordinary pipe on every connection a player can plumb,
                         and none on the three that are contained -- which is asked of the engine
                         rather than listed here (see the library's pipe_up). THE FRAME THAT WAS
                         MISSING FOR MONTHS (#346): the socket-height defect Truls found on
                         2026-09-13 lived in the join between a socket and the pipe in it, and until
                         this shot not one frame this rig took had a pipe in it at all. A socket in
                         the wrong place, or an accent that does not match the fluid its pipe
                         carries, shows here too.
      rotations.png      One machine in each of the four directions, in a two-by-two grid whose
                         pitch comes from the machine's own footprint. The engine turns the
                         connections and not the picture, so this is where a wrongly ordered sheet
                         set shows itself: sockets on the wrong edge, cabinet in the wrong corner.

    EVERY FRAME NOW CARRIES A SIDECAR (#385). `<frame>.json` beside `<frame>.png` records the zoom,
    the world position the camera was centred on, the resolution, and the position, direction and
    footprint of everything in shot -- written by the shutter from the arguments it takes the
    picture with, which is the warning this file's own framing comment already carried: "two
    expressions for one number is how the spacing above and the framing here would come apart."

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
    Where the PNGs and their sidecars are copied. Defaults to a timestamped directory under the
    system temp path, which is printed at the end.

.PARAMETER TimeoutSeconds
    How long to wait for the game to write the done marker before giving up. Default 180.

.PARAMETER MapSeed
    Map generation seed, passed to --create. Unset means a random map, which is what the frames
    already committed were shot on -- and which is why re-running this probe reproduces the MACHINE
    and not the ground under it. Every grass tile picks a variant off the map seed, so two runs of
    identical code differ on about 85% of a frame's pixels while the machine itself differs by at
    most 5 of 255. Give a seed to make a frame comparable with another frame.

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
    [int]    $MapSeed,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
. "$repoRoot/scripts/factorio-lib.ps1"
. "$repoRoot/scripts/art-probe-lib.ps1"

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path ([IO.Path]::GetTempPath()) ('rf-hx-art-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}

# ------------------------------------------------------ this probe's own half of the rig's control
$layout = @'

local MACHINE = "rf-heat-exchanger"
local ENERGY  = "rf-reactor-energy"

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

script.on_nth_tick(60, function()
  if storage.stage then return end
  storage.stage = "built"

  local surface = game.surfaces[1]
  ready(surface)

  -- THE PITCH BETWEEN NEIGHBOURS, off the machine rather than written down. A rotated machine is
  -- as wide as the other one is tall, so the long side governs both axes; +3 keeps a few tiles of
  -- ground visible between neighbours and keeps the pitch EVEN, which matters because an
  -- odd-sided building's centre has to stay on a tile centre for its edges to land on boundaries.
  local W, H = footprint(MACHINE)
  local PITCH = math.max(W, H) + 3
  say(string.format("%s is %d x %d, so the grid pitch is %d", MACHINE, W, H, PITCH))

  -- THE SOLO SUBJECTS ARE SPACED BY THE WIDEST FRAME, NOT BY THE PITCH, which is the collector
  -- probe's lesson taken rather than relearnt (#346): the frames are wider than the pitch, so a
  -- spacing that only clears a machine lets a neighbour intrude on a frame. The pipes frame is the
  -- widest because a pipe stands a tile outside the footprint on every plumbable side. Computed
  -- once here and handed to the shutter in storage, so spacing and framing cannot drift apart.
  local SOLO_W, SOLO_H = W + 6, H + 6
  local PIPES_W, PIPES_H = W + 8, H + 8
  local SPACING = math.max(SOLO_W, PIPES_W) + 1
  say(string.format("solo frame %dx%d, pipes frame %dx%d, so solo subjects stand %d apart",
    SOLO_W, SOLO_H, PIPES_W, PIPES_H, SPACING))

  -- Paved and cleared from the extremes the layout actually reaches, so moving a shot cannot leave
  -- a machine standing in water or behind somebody's trees. GRID is the rotations frame's centre.
  local GRID_X, GRID_Y = -0.5, 100.5
  local COLD_X = 40.5
  local WORKING_X = COLD_X + SPACING
  local PIPES_X = WORKING_X + SPACING
  local x1, y1 = math.min(-PITCH, GRID_X - PITCH), -PITCH
  local x2, y2 = PIPES_X + SPACING, GRID_Y + PITCH
  pave(surface, x1, y1, x2, y2)
  sweep(surface, x1, y1, x2, y2, x2 - 3, y1 + 3)

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

  -- The three single-machine subjects, spaced off the widest frame so one cannot creep into
  -- another's when the footprint changes.
  local cold    = place(surface, MACHINE, COLD_X, 0.5)
  local working = place(surface, MACHINE, WORKING_X, 0.5)
  -- AND ONE WITH PIPES ON IT (#346). No frame this rig took had ever put a pipe against this
  -- machine: it shot the bolted pair, the machine alone and four rotations, and the socket-height
  -- defect Truls found on 2026-09-13 had shipped for months with no picture that could show it.
  -- A probe that cannot photograph the join cannot be asked about it.
  pipe_up(surface, place(surface, MACHINE, PIPES_X, 0.5))

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
  storage.solo = { cold_x = COLD_X, working_x = WORKING_X, pipes_x = PIPES_X, h = H,
                   solo_w = SOLO_W, solo_h = SOLO_H, pipes_w = PIPES_W, pipes_h = PIPES_H }
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

  -- Reported so a picture of a machine that was NOT burning cannot be read as one that was. This
  -- is the whole difference between cold.png and working-*.png.
  say("cold machine status    : " .. status_name(storage.cold))
  say("working machine status : " .. status_name(storage.working))

  local g, solo = storage.grid, storage.solo
  local pair_h = 15 + solo.h + 2          -- the reactor, the machine bolted below it, and margin

  -- THE SINGLE-MACHINE FRAMES ARE SIZED OFF THE MACHINE TOO, and they were the last thing here
  -- still written for the old shape: 864 x 1824 at zoom 3 is nine tiles wide by nineteen tall, a
  -- portrait frame for a machine five wide and fifteen long. Turned fifteen by five, the subject
  -- ran out of both sides of its own portrait -- and cold.png and working-*.png are the shots this
  -- probe exists for. The sizes come from storage rather than being recomputed here: two
  -- expressions for one number is how the spacing above and the framing here would come apart.

  tiles_shot("layout.png",       7.0, 0.5 + solo.h / 2, 30, pair_h, 2, 0)
  tiles_shot("cold.png",         solo.cold_x,    0.5, solo.solo_w,  solo.solo_h,  3, 0)
  tiles_shot("working-day.png",  solo.working_x, 0.5, solo.solo_w,  solo.solo_h,  3, 0)
  tiles_shot("working-night.png", solo.working_x, 0.5, solo.solo_w, solo.solo_h,  3, 0.5)
  tiles_shot("pipes.png",        solo.pipes_x,   0.5, solo.pipes_w, solo.pipes_h, 3, 0)
  tiles_shot("rotations.png", g.x, g.y, 2 * g.pitch + 4, 2 * g.pitch + 4, 1.5, 0)

  -- ZOOM 1 -- 32 px to the tile, the size a player meets the machine at (CONTEXT.md, Zoom). Every
  -- other frame above is magnification. #359 asks whether two accents can be told apart where they
  -- are MET, and this machine is the hard case: docs/research/accent-separation.md measures its
  -- steam and water accents 11.2 dE00 apart at their closest, the tightest pair on any sheet, and
  -- draws two of its six bands at two screen pixels. game-alone.png is the bench's own window and
  -- game-pipes.png is the condition #359 names -- on grass, with vanilla pipes plugged in.
  tiles_shot("game-alone.png", solo.cold_x,  0.5, solo.solo_w,  solo.solo_h,  1, 0)
  tiles_shot("game-pipes.png", solo.pipes_x, 0.5, solo.pipes_w, solo.pipes_h, 1, 0)

  finish()
end)
'@

Invoke-ArtProbe -FactorioExe $FactorioExe -RepoRoot $repoRoot `
    -RigName 'rf-heat-exchanger-art-probe' -RigTitle 'Heat exchanger art probe' `
    -Author 'probe-heat-exchanger-art.ps1' -TempPrefix 'rf-hx-art-' `
    -Control ($ArtProbeLua + $layout) -OutputDirectory $OutputDirectory `
    -TimeoutSeconds $TimeoutSeconds -KeepTemp:$KeepTemp `
    -MapSeed $(if ($PSBoundParameters.ContainsKey('MapSeed')) { $MapSeed } else { $null })
