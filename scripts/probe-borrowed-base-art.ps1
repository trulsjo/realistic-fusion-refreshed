<#
.SYNOPSIS
    Photographs rf-isotope-collector and rf-heat-exchanger at zoom 1 INSIDE the borrowed base, with
    a paved-rig control from the same run. Screenshots only -- it asserts nothing.

.DESCRIPTION
    A PROBE, NOT A CHECK. Exit 0 means the pictures were taken, never that the accents read.

    THE OTHER HALF OF "ON GRASS, AT SPEED" (#388). #359 asked whether a player can tell one fluid
    accent from another at 32 px to the tile, "on grass, at speed". ADR 0034 settled it on frames
    that answer the first half and says so in its own Consequences: *"It leaves 'at speed'
    unanswered... The frames are a machine standing still on grass, with the camera still. Nobody
    has looked at these accents on a screen with a factory on it."* A rig is flat ground, power, the
    entities under test and deliberately nothing else -- which is what makes it answerable and also
    what makes it the wrong place to ask whether an accent survives a busy screen.

    So this stands the two machines inside the one map in this project that is not a rig: the
    BORROWED BASE (ADR 0029, docs/research/borrowed-base.md), TimEv's Modular 10k SPM Vanilla 2.0
    Megabase. **Attribute TimEv wherever a figure or a frame taken on it is quoted.**

    THE FRAMES SHOT INSIDE IT CANNOT BE COMMITTED, AND THAT IS SETTLED BEFORE THEY ARE TAKEN RATHER
    THAN AFTER. ADR 0029: the borrowed base "is used locally and never redistributed, and no
    derivative of it is either." A screenshot of somebody's factory is a derivative of that factory.
    So `-OutputDirectory` defaults to a temp directory, nothing here writes into docs/, and the
    finding in docs/research/borrowed-base-at-zoom-1.md is prose and numbers rather than pictures.
    THE CONTROL FRAMES ARE DIFFERENT: they are our two machines on ground this rig paved on a
    surface it created, with nothing of TimEv's in them, so they are ours to keep. A tile NAME read
    off his map is a fact about Factorio's terrain generator rather than a piece of his factory.

    AND NOTHING IS WRITTEN BACK. --benchmark is not available to an art probe, so this loads the
    save in the graphical client -- but the client is never asked to save, autosave is off in the
    config scripts/art-probe-lib.ps1 writes, and an autosave would land in the run's own throwaway
    write-data directory rather than on the borrowed file in any case. No derivative exists on disk
    when this exits.

    WHAT IT SHOOTS, and why each one:

      base-collector-z1.png   rf-isotope-collector standing in TimEv's factory, zoom 1.
      base-exchanger-z1.png   rf-heat-exchanger the same. These are the frames #359 could not take.
      grass-collector-z1.png  THE CONTROL ON GRASS -- the ground #359 asked about, and what every
      grass-exchanger-z1.png  frame in docs/research/accent-legibility-at-zoom-1/ stands on, so a
                              frame here is comparable with those.
      ground-collector-z1.png THE CONTROL ON THE BASE'S OWN TILE, whatever the search landed the
      ground-exchanger-z1.png machine on, asked of the map rather than named here. It exists
                              because a grass control is CONFOUNDED: it differs from a base frame
                              in the clutter AND in the terrain, and only this one isolates the
                              clutter, which is the question. All four are shot in the SAME RUN on
                              purpose rather than compared against a remembered frame: same engine
                              build, same mods, same sheets, same tick, same lighting.

    WHERE INSIDE THE BASE, and why that is searched for rather than written down. A megabase is
    mostly module, and a 15x5 machine needs a free 15x5. So this samples the surface's generated
    chunks, counts what the player force has built in each, and tries the busiest ones first --
    taking the first position where can_place_entity says the machine fits. The neighbour count
    within twenty tiles of each machine is REPORTED with the frame, so "on a screen with a factory
    on it" is a number a reader can judge rather than a claim this file makes. If no position is
    found it says so and shoots the controls anyway; a probe reports, it does not insist.

    IT BUILDS ON TIMEV'S SURFACE AND DESTROYS NOTHING OF HIS. `pave` and `sweep` are not called on
    it -- they landfill and clear, which on this map would bulldoze somebody's factory -- and
    `place` refuses an overlap rather than making one. The control surface is created by this rig,
    and `surface_for_control` refuses to reuse a surface the save already had, which is
    bench-reactors.ps1's own guard for the same reason.

    Findings belong in docs/research/. Kept committed so the next engine version can be asked the
    same question -- by whoever still has the save, which is the cost ADR 0029 accepted.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER BorrowedBase
    Path to the borrowed base save. Defaults to $env:RF_BORROWED_BASE, then the copy in
    C:\src\factorio\_reference\ this machine holds. It is not in this repository and cannot be:
    167 MB against GitHub's 100 MB per-file limit, and no grant to redistribute it (ADR 0029).

.PARAMETER OutputDirectory
    Where the PNGs and their sidecars are copied. Defaults to a timestamped directory under the
    system temp path, which is printed at the end. NOT a directory in this repository by default,
    and see the ADR 0029 paragraph above before making it one.

.PARAMETER TimeoutSeconds
    How long to wait for the game to write the done marker before giving up. Default 600 -- six
    times the other art probes', because loading a 167 MB save is most of it.

.PARAMETER KeepTemp
    Leave the scratch mod directory and the raw script-output in place.

.EXAMPLE
    pwsh -File scripts/probe-borrowed-base-art.ps1
    pwsh -File scripts/probe-borrowed-base-art.ps1 -OutputDirectory C:\tmp\base-shots
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [string] $BorrowedBase,
    [string] $OutputDirectory,
    [int]    $TimeoutSeconds = 600,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
. "$repoRoot/scripts/factorio-lib.ps1"
. "$repoRoot/scripts/art-probe-lib.ps1"

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
if (-not $BorrowedBase) { $BorrowedBase = $env:RF_BORROWED_BASE }
if (-not $BorrowedBase) { $BorrowedBase = 'C:\src\factorio\_reference\Megabase in 2.0.zip' }
if (-not (Test-Path -LiteralPath $BorrowedBase)) {
    throw "no borrowed base at '$BorrowedBase'. It is not in this repository and cannot be " +
          "(ADR 0029); pass -BorrowedBase or set `$env:RF_BORROWED_BASE. " +
          "docs/research/borrowed-base.md says where this one came from."
}
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path ([IO.Path]::GetTempPath()) ('rf-base-art-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}

# ------------------------------------------------------ this probe's own half of the rig's control
$layout = @'

local MACHINES = { "rf-isotope-collector", "rf-heat-exchanger" }
local CONTROL_SURFACE = "rf-art-control"

-- How far around a machine the neighbour count is taken, in tiles. Twenty is a little wider than
-- the widest frame here (the exchanger's, 21 tiles), so the number covers what is in shot and a
-- little of what is about to be.
local BUSY_RADIUS = 20

--- How much of somebody's factory stands within BUSY_RADIUS of a point. The number that turns "on a
--- screen with a factory on it" from a claim into a reading.
local function neighbours(surface, x, y)
  return surface.count_entities_filtered({
    area = { { x - BUSY_RADIUS, y - BUSY_RADIUS }, { x + BUSY_RADIUS, y + BUSY_RADIUS } },
    force = "player" }) - 1
end

--- The busiest chunks of a surface, busiest first, as { {x=, y=, built=}, ... }.
---
--- FOUND FROM THE FACTORY'S OWN ENTITIES, NOT BY WALKING CHUNKS, and the first version of this
--- probe did walk them: `surface.get_chunks()` starts at the corner of the generated area, and on
--- this map the first four hundred chunks it hands over are empty ground. The run reported "0 of
--- them have something built on them" and shot no base frame at all, which is a probe failing
--- quietly in the one way a probe can -- by reporting an answer that is about its own search rather
--- than about the map.
---
--- So a sample of what the player force has BUILT is taken first, and the chunks are counted off
--- that. `limit` bounds the sample rather than the map: a 10k SPM megabase has on the order of a
--- million entities and none of this needs to see them all. Whichever part of the factory the
--- sample lands in is a part of the factory, which is the whole requirement.
local function busiest_chunks(surface, limit)
  local sample = surface.find_entities_filtered({ force = "player", limit = limit })
  local counts, keys = {}, {}
  for _, e in pairs(sample) do
    local cx, cy = math.floor(e.position.x / 32), math.floor(e.position.y / 32)
    local key = cx .. "," .. cy
    if not counts[key] then
      counts[key] = { x = cx, y = cy, built = 0 }
      keys[#keys + 1] = key
    end
    counts[key].built = counts[key].built + 1
  end
  local found = {}
  for _, key in ipairs(keys) do found[#found + 1] = counts[key] end
  table.sort(found, function(a, b) return a.built > b.built end)
  say(string.format("sampled %d entity(s) of somebody else's factory, spread over %d chunk(s); the "
    .. "busiest holds %d", #sample, #found, #found > 0 and found[1].built or 0))
  return found
end

--- A position inside the factory where `name` fits, or nil. Returns x, y, neighbour count.
---
--- NOTHING IS DESTROYED TO MAKE ROOM. can_place_entity is asked and its answer is taken; a chunk
--- with no gap in it is skipped rather than cleared. That is the whole of this probe's contract
--- with somebody else's work.
local function spot_in(surface, name, chunks, try)
  local w, h = footprint(name)
  local tried = 0
  -- An odd footprint's centre sits at a tile centre and an even one's on a boundary, so the offset
  -- that keeps `place`'s parity is half a tile exactly when the side is odd.
  local ox, oy = (w % 2 == 1) and 0.5 or 0.0, (h % 2 == 1) and 0.5 or 0.0
  for _, chunk in ipairs(chunks) do
    tried = tried + 1
    if tried > try then
      say(string.format("gave up on %s after %d chunk(s); a packed module has no 32x32 gap and"
        .. " this probe clears nothing to make one", name, try))
      return
    end
    for tx = 0, 31 do
      for ty = 0, 31 do
        local x, y = chunk.x * 32 + tx + ox, chunk.y * 32 + ty + oy
        if surface.can_place_entity({ name = name, position = { x, y }, force = "player",
                                      build_check_type = BUILD_CHECK }) then
          return x, y, neighbours(surface, x, y)
        end
      end
    end
  end
end

--- A surface of this rig's own to paint the control on, and it REFUSES ONE THE SAVE ALREADY HAD.
--- This is bench-reactors.ps1's guard and it exists for the same reason: the control surface gets
--- paved and swept, which landfills and clears everything in its area, and doing that to a surface
--- somebody else built would destroy the thing this probe came to photograph.
local function surface_for_control()
  if game.surfaces[CONTROL_SURFACE] then
    error("this save already has a surface called '" .. CONTROL_SURFACE .. "'; the control will "
      .. "not be painted on one this rig did not create, because it paves and clears its area")
  end
  return game.create_surface(CONTROL_SURFACE, { width = 200, height = 200 })
end

script.on_nth_tick(60, function()
  if storage.stage then return end
  storage.stage = "built"

  local base = game.surfaces[1]
  base.always_day = true
  base.show_clouds = false
  say("the borrowed base's surface is '" .. base.name .. "'")

  -- THE SUBJECTS, INSIDE SOMEBODY ELSE'S FACTORY. 20 000 entities is a sample, not the map; the
  -- report says how many were looked at, and the neighbour count beside each machine says how busy
  -- the spot it landed in actually is.
  local chunks = busiest_chunks(base, 20000)
  storage.inside = {}
  for _, name in ipairs(MACHINES) do
    local x, y, near = spot_in(base, name, chunks, 120)
    if x then
      place(base, name, x, y)
      say(string.format("%s planted at %g,%g inside the borrowed base, with %d entity(s) of "
        .. "somebody else's within %d tiles", name, x, y, near, BUSY_RADIUS))
      storage.inside[name] = { x = x, y = y, near = near }
    else
      say(string.format("NO ROOM for %s anywhere in the chunks sampled, so it has no base frame; "
        .. "the control below is shot regardless", name))
    end
  end

  -- TWO CONTROLS PER MACHINE, ON GROUND OF OUR OWN, IN THE SAME RUN -- and the second one exists
  -- because the first is CONFOUNDED. A control on grass differs from a base frame in two things at
  -- once: what else is on the screen, and what the ground under it is. The spot each machine landed
  -- in above is dirt, not grass, so "the accent stands out less inside a factory" off a grass
  -- control would be partly a statement about terrain.
  --
  --   grass-*  the ground #359 asked about and every frame in
  --            docs/research/accent-legibility-at-zoom-1/ stands on, so a frame here is comparable
  --            with those.
  --   ground-* THE SAME TILE THE BASE SPOT ACTUALLY HAS, asked of the map rather than named here.
  --            Against this one the only difference from the base frame is the factory itself,
  --            which is the question.
  --
  -- The base's tile is read at the machine's own position, so a spot that lands on concrete gets a
  -- concrete control and the pairing stays honest wherever the search puts things.
  local rig = surface_for_control()
  ready(rig)
  local x = 0.5
  storage.control = {}
  for _, name in ipairs(MACHINES) do
    local w, h = footprint(name)
    local inside = storage.inside[name]
    local ground = inside and base.get_tile(inside.x, inside.y).name or nil
    for _, cell in ipairs({ { key = "grass", tile = "grass-1" },
                            { key = "ground", tile = ground } }) do
      if cell.tile then
        pave(rig, x - w / 2 - 6, -h / 2 - 6, x + w / 2 + 6, h / 2 + 6, cell.tile)
        sweep(rig, x - w / 2 - 6, -h / 2 - 6, x + w / 2 + 6, h / 2 + 6, x, -h / 2 - 20)
        place(rig, name, x, 0.5)
        storage.control[name] = storage.control[name] or {}
        storage.control[name][cell.key] = { x = x, y = 0.5, tile = cell.tile }
        say(string.format("control for %s on %s at %g,%g", name, cell.tile, x, 0.5))
        x = x + w + 20
      end
    end
  end

  storage.shoot_at = game.tick + 120
end)

script.on_event(defines.events.on_tick, function()
  if not storage.shoot_at or game.tick < storage.shoot_at then return end
  storage.shoot_at = nil

  -- ZOOM 1 -- 32 px to the tile, the size a player meets the machine at (CONTEXT.md, Zoom). It is
  -- the only zoom shot here, because it is the only zoom the question is about. Each frame is the
  -- machine plus six tiles of surroundings, the same framing the other two art probes' zoom-1
  -- frames use, so a control frame from this rig and one from theirs are the same picture.
  local base = game.surfaces[1]
  for _, name in ipairs(MACHINES) do
    local w, h = footprint(name)
    local short = name:gsub("^rf%-", ""):gsub("isotope%-", ""):gsub("heat%-", "")
    local inside = storage.inside[name]
    if inside then
      shot_surface = base
      tiles_shot("base-" .. short .. "-z1.png", inside.x, inside.y, w + 6, h + 6, 1, 0)
      say(string.format("base-%s-z1.png has %d entity(s) of TimEv's within %d tiles of the machine",
        short, inside.near, BUSY_RADIUS))
    end
    shot_surface = game.surfaces[CONTROL_SURFACE]
    for key, control in pairs(storage.control[name] or {}) do
      tiles_shot(key .. "-" .. short .. "-z1.png", control.x, control.y, w + 6, h + 6, 1, 0)
      say(string.format("%s-%s-z1.png is the control on %s, with nothing else on the screen",
        key, short, control.tile))
    end
  end

  finish()
end)
'@

Invoke-ArtProbe -FactorioExe $FactorioExe -RepoRoot $repoRoot `
    -RigName 'rf-borrowed-base-art-probe' -RigTitle 'Borrowed base art probe' `
    -Author 'probe-borrowed-base-art.ps1' -TempPrefix 'rf-base-art-' `
    -Control ($ArtProbeLua + $layout) -OutputDirectory $OutputDirectory `
    -TimeoutSeconds $TimeoutSeconds -KeepTemp:$KeepTemp -LoadGame $BorrowedBase `
    -Epilogue @(
        'The base-*.png frames are inside TimEv''s megabase and are DERIVATIVES OF IT: used',
        'locally, never redistributed, and not committed (ADR 0029). The grass-* and ground-*',
        'controls are our machines on ground this rig paved, and are ours to keep. Attribute',
        'TimEv wherever a frame or a figure taken on the base is quoted.')
