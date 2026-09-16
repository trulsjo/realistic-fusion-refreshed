<#
.SYNOPSIS
    Photographs rf-isotope-collector's rendered art in a real map, so a person can accept or reject
    the look. Screenshots only -- it asserts nothing.

.DESCRIPTION
    A PROBE, NOT A CHECK. Exit 0 means it ran and wrote the pictures, never that the art is good.
    The question it answers is the one no gate can: does the rendered building read correctly in
    the game, at zoom 1 -- 32 px to the tile, the game's own camera, the size a player meets it at
    (CONTEXT.md, Zoom) -- and again magnified, beside the machines it stands next to? load-check proves
    the sheets exist and agree with the prototype's footprint (#250); nothing proves they look
    right. That is a person looking, and this is what puts the pictures in front of them. The
    acceptance criterion left open on #262 and #333 is exactly this, and it is Truls's to answer.

    THE SIBLING OF scripts/probe-heat-exchanger-art.ps1, AND THEY NOW SHARE THEIR SCAFFOLDING.
    place(), footprint(), box_of(), status_name(), pave(), pipe_up(), the character sweep, the
    shutter, the launch and the settle-wait live in scripts/art-probe-lib.ps1 and are dot-sourced
    from both. They were hand-copied here until #386, and this file's own header set the trigger for
    moving them: *"If a third art probe is written, extract then: two is where you notice, three is
    where it pays."* #388 is the third, and the extraction went first so that it would not become a
    third copy.

    A THIRD ART PROBE SHOULD REUSE THE LIBRARY AND WRITE NOTHING BUT ITS OWN QUESTION. Dot-source
    art-probe-lib.ps1, build `$control` as `$ArtProbeLua` plus the layout and the shot list, and
    hand it to `Invoke-ArtProbe`. What belongs in the new file is where each machine stands, what it
    is fed, and what every frame is FOR -- nothing about opening a window.

    WHAT THIS PROBE KEEPS FOR ITSELF, because this machine is not that machine:

      - NO BOLT ARITHMETIC. The exchanger meets a reactor along a fluid connection, so its probe
        carries `bolt`, `facing` and `connection_facing`. This machine shares no connection with a
        reactor at all: scripts/entity-management.lua's `touching` pairs them by the reactor's
        bounding box grown one tile, so the collector only has to stand near it. `blind_face` and
        `connection_tiles` below are this file's answer to the same question and are not in the
        library, because a helper with one caller is a helper in the wrong file.
      - `contents` AND `fill`. Two by-product boxes written directly, and reported so that two
        pictures which are MEANT to match cannot be read as a rig that failed to fill one.
      - NO GLOW PAIR IN THE USUAL SENSE. The exchanger's working-day and working-night shots exist
        to settle whether its manifold reads as the energy accent. Nothing on this machine glows --
        the look note in prototypes/entities.lua says why, and its manifest records `glow: false` --
        so the same two shots are here to prove a NEGATIVE. night.png is the load-bearing one: at
        midnight a stray emission would be the only thing visible on the frame.

    THE PIPES SHOT NEEDS NO FILTERING HERE, AND TAKES THE FILTERING VERSION ANYWAY. Every fluid this
    machine carries is ordinary and uncontained (#26), its three sockets are tritium west, tritium
    east and helium-3 north, and the whole argument for the two accents (#262,
    models/house-style.md) is that a player reads which socket is which from its colour. The
    library's `pipe_up` asks the engine whether each pipe joined rather than assuming it did, which
    on this machine is three out of three -- and it says so in its own report line, which is the
    evidence that nothing here is contained rather than a claim that nothing is.

    WHAT IT SHOOTS, and why each one:

      layout.png     rf-reactor with rf-isotope-collector flush against its west face -- near
                     enough to pair, which is the arrangement a player builds. WHERE a collector
                     ought to go is not settled and this picture does not settle it: north and
                     south are the reactor's energy faces and east and west its plasma ones
                     (ADR 0031, ADR 0011), so every face is already spoken for and the choice here
                     is only the simplest one that pairs.
      alone.png      The machine by itself with both boxes empty. What an idle collector looks like.
      working.png    Its twin with tritium and helium-3 in it, at noon. The MACHINE should look the
                     same as in alone.png -- a boiler draws no fluid level and this one has no
                     working state to light. Compare it by eye, not by subtracting the two files:
                     they are different machines standing in different places, so the ground differs
                     and shows through the deck's openings. What actually proves nothing is
                     state-driven is that the picture set has no fire_glow layer at all
                     (graphics/rendered/pictures.lua, M.boiler with no_glow); this is what lets a
                     person see it.
      night.png      The filled machine at midnight, where any emission would be all there is. This
                     is the picture that proves `glow: false` rather than repeating it.
      rotations.png  One machine in each of the four directions, in a two-by-two grid whose pitch
                     comes from the machine's own footprint. THE CRITICAL SHOT FOR THIS MACHINE:
                     it is square, so a wrongly ordered sheet set survives every other picture here
                     unchanged. graphics/mockup/pictures.lua records what one sheet across four
                     directions did to it -- the output drawn on the north edge every time, wrong in
                     three out of four -- and that is invisible unless the four are seen together.
      pipes.png      One machine with an ordinary pipe on each of its three sockets. A socket in the
                     wrong place, or an accent that does not match the fluid its pipe carries, shows
                     here and nowhere else.

    EVERY FRAME NOW CARRIES A SIDECAR (#385). `<frame>.json` beside `<frame>.png` records the zoom,
    the world position the camera was centred on, the resolution, and the position, direction and
    footprint of everything in shot -- written by the shutter from the arguments it takes the
    picture with. tools/measure-frame-accents.py is what reads them.

    The machine is fed by writing its fluid boxes directly rather than by running a reactor into it.
    The picture is the subject; how the by-products got there is not, and a real reactor takes
    minutes of simulation to light. scripts/check-breeding.ps1 is what proves the breeding path; this
    proves nothing about it. The probe prints each machine's status at the moment it was
    photographed, so a shot of a machine that was not actually holding anything cannot be mistaken
    for one that was.

    NOTHING HERE WRITES A FOOTPRINT DOWN, which is #275's lesson taken rather than relearnt. Every
    position is computed from the collision boxes the game loaded, place() refuses an overlap
    instead of building one, and the rotation grid's pitch is read off the machine. A picture nobody
    can build is worse than no picture, because it looks like a picture.

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
    pwsh -File scripts/probe-isotope-collector-art.ps1
    pwsh -File scripts/probe-isotope-collector-art.ps1 -OutputDirectory C:\tmp\collector-shots
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
    $OutputDirectory = Join-Path ([IO.Path]::GetTempPath()) ('rf-ic-art-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}

# ------------------------------------------------------ this probe's own half of the rig's control
$layout = @'

local MACHINE  = "rf-isotope-collector"
local REACTOR  = "rf-reactor"
local TRITIUM  = "rf-tritium"
local HELIUM3  = "rf-helium-3"

--- How full each of the two by-product boxes is, which is the only thing that separates working.png
--- from alone.png. Reported because the two shots are MEANT to look identical: without this line a
--- reader cannot tell a machine that was full from a rig that quietly failed to fill it.
local function contents(entity)
  if not (entity and entity.valid) then return "?" end
  local parts = {}
  for _, fluid in ipairs({ TRITIUM, HELIUM3 }) do
    local i = box_of(entity, fluid)
    local box = i and entity.fluidbox[i]
    parts[#parts + 1] = string.format("%s %s", fluid,
      box and string.format("%.0f", box.amount) or "(no box)")
  end
  return table.concat(parts, ", ")
end

--- Fill both by-product boxes, which is what a paired reactor's control.lua does to this machine.
local function fill(entity, amount)
  for _, fluid in ipairs({ TRITIUM, HELIUM3 }) do
    local i = box_of(entity, fluid)
    if not i then error(entity.name .. " has no box filtered to " .. fluid) end
    entity.fluidbox[i] = { name = fluid, amount = amount }
  end
end

--- Every tile this entity's connections point AT, as a "x,y" set. A tile a machine wants a pipe on
--- is a tile nothing may be built over, which is what the pairing below has to respect.
local function connection_tiles(entity)
  local tiles = {}
  for i = 1, #entity.fluidbox do
    for _, c in pairs(entity.fluidbox.get_pipe_connections(i)) do
      if c.target_position then
        tiles[string.format("%g,%g", c.target_position.x, c.target_position.y)] = true
      end
    end
  end
  return tiles
end

--- The one face of this machine that no connection leaves by -- its BLIND face -- asked rather than
--- remembered. nil if every face carries one, which is not this machine but could be the next.
---
--- THIS IS THE FACE THAT SHOULD MEET A REACTOR, and it is Truls's correction to the first version
--- of this probe, which stood the collector west of the reactor and so buried its own east tritium
--- socket against the reactor's wall. A machine with three sockets and four faces has exactly one
--- side it can afford to lose; bolting by any other is asking a player to give up a pipe run.
local function blind_face(entity)
  local used = {}
  for i = 1, #entity.fluidbox do
    for _, c in pairs(entity.fluidbox.get_pipe_connections(i)) do
      local dx = c.target_position.x - c.position.x
      local dy = c.target_position.y - c.position.y
      if dy < 0 then used.north = true elseif dy > 0 then used.south = true
      elseif dx < 0 then used.west = true else used.east = true end
    end
  end
  for _, side in ipairs({ "south", "north", "west", "east" }) do
    if not used[side] then return side end
  end
end

script.on_nth_tick(60, function()
  if storage.stage then return end
  storage.stage = "built"

  local surface = game.surfaces[1]
  ready(surface)

  -- THE PITCH BETWEEN NEIGHBOURS, off the machine rather than written down. This machine is square,
  -- so both axes are the same either way -- but it is computed from max(W, H) regardless, because a
  -- footprint that stops being square should move the pictures rather than break them. +3 keeps a
  -- few tiles of ground visible between neighbours and keeps the pitch EVEN, which matters because
  -- an odd-sided building's centre has to stay on a tile centre for its edges to land on boundaries.
  local W, H = footprint(MACHINE)
  local RW, RH = footprint(REACTOR)
  local PITCH = math.max(W, H) + 3
  say(string.format("%s is %d x %d and %s is %d x %d, so the grid pitch is %d",
    MACHINE, W, H, REACTOR, RW, RH, PITCH))

  -- WHERE THE COLLECTOR STANDS BESIDE THE REACTOR, and the parity argument for the arithmetic.
  -- Flush against the west face is centre-to-centre (RW + W) / 2 tiles apart. Two odd footprints
  -- give a whole number, so both centres stay on tile centres and both sets of edges land on tile
  -- boundaries; one odd and one even gives a half, which shifts the parity in exactly the way it
  -- has to shift. That is why this is a formula and not a constant.
  local REACTOR_X, REACTOR_Y = 0.5, 0.5

  -- EVERY SOLO SUBJECT IS SPACED BY THE WIDEST FRAME, NOT BY THE PITCH, and the pitch is what the
  -- first run of this probe used. The frames are wider than the pitch -- the machine plus six tiles
  -- of air, and plus eight for the pipes shot, against a pitch of eight -- so working.png came back
  -- with a neighbour intruding from each side. A frame is what has to clear a frame; a pitch only
  -- has to clear a machine. SOLO_TILES and PIPES_TILES are computed once here and handed to the
  -- shutter in storage, so the spacing and the framing cannot drift apart.
  local SOLO_TILES  = W + 6
  local PIPES_TILES = W + 8
  local SPACING     = math.max(SOLO_TILES, PIPES_TILES) + 1
  say(string.format("solo frame %d tiles, pipes frame %d, so subjects stand %d apart",
    SOLO_TILES, PIPES_TILES, SPACING))

  -- Paved and cleared from the extremes the layout actually reaches, so moving a shot cannot leave
  -- a machine standing in water or behind somebody's trees. GRID is the rotations frame's centre.
  local GRID_X, GRID_Y = -0.5, 100.5
  -- Clear of the LAYOUT frame as well, which reaches half its own width east of the pair's centre.
  local COLD_X    = REACTOR_X + RW / 2 + SPACING
  local WORKING_X = COLD_X + SPACING
  local PIPES_X   = WORKING_X + SPACING
  local x1 = math.min(REACTOR_X - RW / 2 - W - math.max(RW, W), GRID_X - PITCH) - 4
  local y1 = -math.max(RH, H) - 6
  local x2 = PIPES_X + SPACING + 4
  local y2 = GRID_Y + PITCH + 4
  pave(surface, x1, y1, x2, y2)
  sweep(surface, x1, y1, x2, y2, x2 - 3, y1 + 3)

  -- THE PAIRED ARRANGEMENT, AND IT IS BOLTED BY THE BLIND FACE (Truls, 2026-09-13). The first
  -- version of this probe stood the collector west of the reactor, which put the collector's own
  -- EAST tritium socket flat against the reactor's wall with nowhere for its pipe to go. The
  -- machine has three sockets and four faces, so exactly one face is free to lose -- the south one
  -- -- and that is the face that meets the reactor. The collector therefore stands NORTH of it.
  --
  -- AND IT SLIDES ALONG THAT FACE UNTIL IT BLOCKS NOTHING. Centred, a 5-wide collector on the
  -- reactor's north edge sits squarely on the tile the reactor's own north energy connection points
  -- at, so a heat exchanger could no longer bolt there -- one machine's plumbing solved by breaking
  -- another's. The offsets are tried outward from centre and the first that covers no connection
  -- tile of either machine wins. Nothing here is a footprint written down: move a socket and this
  -- finds the new answer instead of photographing a layout nobody can build.
  local reactor = place(surface, REACTOR, REACTOR_X, REACTOR_Y)
  local blind = blind_face(prototypes.entity[MACHINE] and
    surface.create_entity({ name = MACHINE, position = { GRID_X, GRID_Y - 4 * PITCH },
                            force = "player" }))
  say(string.format("%s's blind face is %s, so it bolts to the reactor by that side",
    MACHINE, tostring(blind)))
  for _, e in pairs(surface.find_entities_filtered({
      area = { { GRID_X - W, GRID_Y - 4 * PITCH - H }, { GRID_X + W, GRID_Y - 4 * PITCH + H } },
      name = MACHINE })) do
    e.destroy()
  end
  if not blind then error(MACHINE .. " has a connection on every face; this rig cannot bolt it") end

  local blocked = connection_tiles(reactor)
  local ALONG = { north = "x", south = "x", west = "y", east = "y" }
  local AWAY  = { north = -1, south = 1, west = -1, east = 1 }
  -- The blind face meets the reactor, so the machine sits on the OPPOSITE side of it.
  local side = ({ north = "south", south = "north", west = "east", east = "west" })[blind]
  local along, away = ALONG[side], AWAY[side]
  local far = (side == "north" or side == "south")
      and { x = 0, y = away * (RH + H) / 2 } or { x = away * (RW + W) / 2, y = 0 }

  local pair_x, pair_y
  for step = 0, math.max(RW, RH) do
    for _, sign in ipairs(step == 0 and { 1 } or { -1, 1 }) do
      local cx = REACTOR_X + far.x + (along == "x" and sign * step or 0)
      local cy = REACTOR_Y + far.y + (along == "y" and sign * step or 0)
      local clear = true
      for x = math.floor(cx - W / 2), math.ceil(cx + W / 2) - 1 do
        for y = math.floor(cy - H / 2), math.ceil(cy + H / 2) - 1 do
          if blocked[string.format("%g,%g", x + 0.5, y + 0.5)] then clear = false end
        end
      end
      if clear and surface.can_place_entity({
          name = MACHINE, position = { cx, cy }, force = "player",
          build_check_type = BUILD_CHECK }) then
        pair_x, pair_y = cx, cy
        break
      end
    end
    if pair_x then break end
  end
  if not pair_x then
    error("no position on the reactor's " .. side .. " face leaves both machines' sockets reachable")
  end
  say(string.format("collector bolted on the reactor's %s face at %g,%g, clear of every "
    .. "connection tile", side, pair_x, pair_y))
  local paired = place(surface, MACHINE, pair_x, pair_y)
  -- Pipes on the paired machine too, which is the point of bolting by the blind face: all three
  -- sockets must still be reachable. A picture of three pipes is the proof.
  pipe_up(surface, paired)

  -- The single-machine subjects, spaced a whole pitch apart so one cannot creep into another's
  -- frame when the footprint changes.
  local cold    = place(surface, MACHINE, COLD_X, REACTOR_Y)
  local working = place(surface, MACHINE, WORKING_X, REACTOR_Y)
  local piped   = place(surface, MACHINE, PIPES_X, REACTOR_Y)
  pipe_up(surface, piped)

  -- One per direction, in a two-by-two grid at that pitch, far enough north to stay out of every
  -- other frame. This is the shot this machine most needs: it is square, so all four sheets are
  -- near enough the same picture turned, and only seeing them together catches a set in the wrong
  -- order -- sockets on the wrong edge, cabinet in the wrong corner.
  place(surface, MACHINE, GRID_X - PITCH / 2, GRID_Y - PITCH / 2, defines.direction.north)
  place(surface, MACHINE, GRID_X + PITCH / 2, GRID_Y - PITCH / 2, defines.direction.south)
  place(surface, MACHINE, GRID_X - PITCH / 2, GRID_Y + PITCH / 2, defines.direction.east)
  place(surface, MACHINE, GRID_X + PITCH / 2, GRID_Y + PITCH / 2, defines.direction.west)

  storage.cold = cold
  storage.working = working
  storage.grid = { x = GRID_X, y = GRID_Y, pitch = PITCH }
  storage.solo = { cold_x = COLD_X, working_x = WORKING_X, pipes_x = PIPES_X,
                   solo_tiles = SOLO_TILES, pipes_tiles = PIPES_TILES }
  storage.pair = { x = (pair_x + REACTOR_X) / 2, y = (pair_y + REACTOR_Y) / 2,
                   w = math.abs(pair_x - REACTOR_X) + math.max(RW, W) + 2,
                   h = math.abs(pair_y - REACTOR_Y) + math.max(RH, H) + 2 }
  storage.shoot_at = game.tick + 120
end)

script.on_event(defines.events.on_tick, function()
  if not storage.shoot_at then return end
  -- Refilled every tick until the shutter, not once: a boiler with an output box and somewhere to
  -- put it will push fluid out, and a "working" machine that had quietly drained by the time the
  -- frame rendered would be the same picture as the cold one for the wrong reason.
  local w = storage.working
  if w and w.valid then fill(w, 200) end
  if game.tick < storage.shoot_at then return end
  storage.shoot_at = nil

  -- Reported so that two pictures which are SUPPOSED to match cannot be read as a rig that failed
  -- to fill one of them. This is the whole difference between alone.png and working.png.
  say("idle machine   : " .. status_name(storage.cold) .. " | " .. contents(storage.cold))
  say("filled machine : " .. status_name(storage.working) .. " | " .. contents(storage.working))

  local g, solo, pair = storage.grid, storage.solo, storage.pair
  -- The frames the spacing above was computed from, taken from storage rather than recomputed: two
  -- expressions for one number is how the frames and the spacing came to disagree in the first run.
  -- The pipes frame is the wider one because a pipe stands a tile outside the footprint on three
  -- sides, and a frame that clipped them would hide the thing that shot is for.
  local solo_t, pipes_t = solo.solo_tiles, solo.pipes_tiles

  tiles_shot("layout.png",    pair.x, pair.y, pair.w + 8, pair.h + 8, 2, 0)
  tiles_shot("alone.png",     solo.cold_x,    0.5, solo_t,  solo_t,  3, 0)
  tiles_shot("working.png",   solo.working_x, 0.5, solo_t,  solo_t,  3, 0)
  tiles_shot("night.png",     solo.working_x, 0.5, solo_t,  solo_t,  3, 0.5)
  tiles_shot("pipes.png",     solo.pipes_x,   0.5, pipes_t, pipes_t, 3, 0)
  tiles_shot("rotations.png", g.x, g.y, 2 * g.pitch + 4, 2 * g.pitch + 4, 1.5, 0)

  -- ZOOM 1 -- 32 px to the tile, the size a player meets the machine at (CONTEXT.md, Zoom). Every
  -- other frame above is magnification. #359 asks whether two pale accents can be told apart where
  -- they are MET, and tools/measure-accent-separation.py answers that in numbers off the sheet;
  -- these two are the same question put to an eye. The pair is deliberate: game-alone.png is the
  -- bench's own window, the machine and nothing else, and game-pipes.png is the condition #359
  -- names -- on grass, with vanilla pipes plugged in, where the accents compete for the eye.
  tiles_shot("game-alone.png", solo.cold_x,  0.5, solo_t,  solo_t,  1, 0)
  tiles_shot("game-pipes.png", solo.pipes_x, 0.5, pipes_t, pipes_t, 1, 0)

  finish()
end)
'@

Invoke-ArtProbe -FactorioExe $FactorioExe -RepoRoot $repoRoot `
    -RigName 'rf-isotope-collector-art-probe' -RigTitle 'Isotope collector art probe' `
    -Author 'probe-isotope-collector-art.ps1' -TempPrefix 'rf-ic-art-' `
    -Control ($ArtProbeLua + $layout) -OutputDirectory $OutputDirectory `
    -TimeoutSeconds $TimeoutSeconds -KeepTemp:$KeepTemp `
    -MapSeed $(if ($PSBoundParameters.ContainsKey('MapSeed')) { $MapSeed } else { $null }) `
    -Epilogue @(
        'The MACHINE in alone.png and working.png should look the same -- compare by eye,',
        'not by subtracting the files: they stand in different places, so the ground under',
        'them differs and shows through the deck. The status lines above say which one was',
        'actually holding by-products. night.png is where a glow that should not exist would',
        'show.')
