<#
.SYNOPSIS
    Photographs the pipe cover a CONTAINED socket does not meet, beside a plumbable socket that
    does, and asks the engine what it draws when a contained box declares no covers at all.
    Screenshots and a report -- it asserts nothing.

.DESCRIPTION
    A PROBE, NOT A CHECK. Exit 0 means it ran and reported, never that the answer was the hoped-for
    one.

    WHAT TRULS SAW (#390), on the frames committed with #389: on rf-heat-exchanger's short ends the
    rf-reactor-energy sockets have a pipe cover sitting below and outboard of the socket, attached
    to nothing. The cause is understood in outline -- a CONTAINED connection (ADR 0018) is drawn at
    world height 0.55 and the engine draws `pipe_covers` flat on the ground at the connection tile,
    and nothing reconciles the two -- but NONE OF THE NUMBERS IS ESTABLISHED, and nobody has asked
    Factorio what it does when a contained box declares no covers at all.

    THE 0.55 IS INHERITED RATHER THAN CHOSEN. It is the height every socket had before #349, and
    models/house-style.md records that "a look chosen for them would be a decision nobody has been
    asked for". So levelling the sockets is as live a remedy as changing the cover, and #391 weighs
    both. This probe weighs neither: it measures, photographs and reports.

    RUN IT THREE TIMES, AND THE SET IS THE MEASUREMENT.

        pwsh -File scripts/probe-pipe-cover-miss.ps1 -MapSeed 7                   -OutputDirectory covers
        pwsh -File scripts/probe-pipe-cover-miss.ps1 -MapSeed 7 -Strip contained  -OutputDirectory bare
        pwsh -File scripts/probe-pipe-cover-miss.ps1 -MapSeed 7 -Strip all        -OutputDirectory bare-all
        python tools/measure-pipe-cover-miss.py covers bare --all bare-all

    -Strip adds a data-final-fixes that removes `pipe_covers`. That answers the second question
    directly -- the
    game either loads or it does not, and the log either complains or it does not -- and it also
    produces the pair the first question is measured from: THE DIFFERENCE BETWEEN THE TWO RUNS' PIXELS
    IS THE COVER. Nothing has to recognise a cover in a frame, or be told what one looks like; it is
    whatever stops being drawn when the declaration goes.

    WHY A BOX AND NOT A CONNECTION. `pipe_covers` is declared per fluid box, so a box holding both
    contained and plumbable connections could not have its covers removed for one and kept for the
    other. The rig reports any such box rather than guessing. MEASURED on 2026-09-17 against 2.0.77:
    there are none -- twelve boxes are entirely contained, none is mixed -- so the question is
    hypothetical today and the report is what will say when it stops being.

    -Strip all IS AN INSTRUMENT, NOT A PROPOSAL. It takes the covers off plumbable sockets too,
    which would be wrong in the game and is not suggested anywhere; it exists because a plumbable
    socket's cover has to disappear once for the subtraction to find it, and #390 asks for that
    socket as the control.

    WHAT IT SHOOTS, and which of #390's questions each one is for. Every frame is taken at zoom 8
    AND at zoom 1, because the miss being visible under magnification and invisible where a player
    meets it are different findings (CONTEXT.md, Zoom):

      exchanger-west-*    THE SUBJECT AND ITS CONTROL IN ONE FRAME. The west short end carries a
                          contained rf-reactor-energy socket and a plumbable water socket two tiles
                          apart, on one machine, in one light. So the figure this probe exists for
                          is a difference between two readings rather than one reading against a
                          prediction, which is what #390 asks for.
      exchanger-north-*   THE REACTOR CONTACT, standing alone.
      exchanger-bolted-*  The same connection with a reactor actually bolted to it, which is how a
                          player meets that face. Whether the miss shows there IN PRACTICE is a
                          question about what covers what, and only this frame answers it.
      reactor-*           rf-reactor, which still wears Krastorio 2 art. Six contained boxes belong
                          to machines nobody has rendered, so whether one of those looks WORSE with
                          its cover gone is its own question -- a K2 sprite was drawn with a cover
                          in mind and ours was not.
      aneutronic-*        rf-aneutronic-reactor, a mockup.
      converter-*         rf-direct-energy-converter, a mockup. Mockups are flat plates with
                          labelled connection marks, so a cover against one is a third case again.

    AND IT REPORTS EVERY CONTAINED CONNECTION IN THE TREE, asked of the loaded prototypes rather
    than listed here, so the note's coverage claim is the game's rather than this file's.

    Findings belong in docs/research/. Kept committed so the next engine version can be asked the
    same question -- which matters more than usual here, because half of what is being asked is what
    the ENGINE does.

.PARAMETER Strip
    Which fluid boxes lose their `pipe_covers`, in data-final-fixes. Three runs make the whole
    measurement, and each answers something the other two cannot:

      none        the tree exactly as it ships. The reference every subtraction is against.
      contained   every box whose connections ALL carry a connection_category -- the remedy #391
                  weighs, so this run is also the answer to "does Factorio load one of those".
      all         every box of ours, contained or not. NOT a remedy and never proposed as one: it is
                  the INSTRUMENT that makes the plumbable control measurable. A plumbable socket's
                  cover survives the `contained` run, so subtracting that run finds nothing at it --
                  and #390 asks for the contained figure to be a difference against a control rather
                  than against a prediction.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER OutputDirectory
    Where the PNGs and their sidecars are copied. Defaults to a timestamped directory under the
    system temp path, which is printed at the end.

.PARAMETER TimeoutSeconds
    How long to wait for the game to write the done marker before giving up. Default 180.

.PARAMETER MapSeed
    Map generation seed, passed to --create. Give the SAME seed to both runs: the two frame sets are
    subtracted from each other, and a difference in the grass under the machine is a difference in
    the subtraction.

.PARAMETER KeepTemp
    Leave the scratch mod directory, the save and the raw script-output in place.

.EXAMPLE
    pwsh -File scripts/probe-pipe-cover-miss.ps1 -MapSeed 7 -OutputDirectory C:\tmp\covers
    pwsh -File scripts/probe-pipe-cover-miss.ps1 -MapSeed 7 -Strip contained -OutputDirectory C:\tmp\bare
    pwsh -File scripts/probe-pipe-cover-miss.ps1 -MapSeed 7 -Strip all -OutputDirectory C:\tmp\bare-all
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [ValidateSet('none', 'contained', 'all')] [string] $Strip = 'none',
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
    $OutputDirectory = Join-Path ([IO.Path]::GetTempPath()) `
        ('rf-cover-' + $Strip + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}

# ---------------------------------------------------------------------------------- the data stage
# Only written when -Strip is given, so the default run is the tree exactly as it ships.
$dataFinalFixes = @'
-- Generated by probe-pipe-cover-miss.ps1 -Strip. Nothing here ships.
--
-- STRIP pipe_covers. The question is what Factorio 2.0.77 does when a box declares none: whether it
-- loads, what it draws in their place, and whether anything complains. Removing them is the only way
-- to ask. WHICH boxes is the caller's -Strip: "contained" is the remedy #391 weighs, "all" is the
-- instrument that makes a plumbable socket's cover visible to a subtraction.
--
-- PER BOX, BECAUSE THE FIELD IS PER BOX. A box holding both contained and plumbable connections
-- cannot lose its covers for one and keep them for the other, so such a box is REPORTED AND LEFT
-- ALONE rather than stripped -- stripping it would take the cover off a socket a player really does
-- plumb, and the frame would then show two changes at once.

--- (all contained, mixed) for one box. MIXED MEANS BOTH KINDS IN ONE BOX, not "not all contained":
--- the first version of this returned `seen and not all` for the second value and so reported every
--- entirely-plumbable box in the tree as mixed -- forty of them, including rf-heat-exchanger's own
--- water box. A box with no contained connection at all is simply not this probe's business.
local STRIP_ALL = __STRIP_ALL__

--- (all contained, mixed, has any connection) for one box. MIXED MEANS BOTH KINDS IN ONE BOX, not
--- "not all contained": the first version of this returned `seen and not all` for the second value
--- and so reported every entirely-plumbable box in the tree as mixed -- forty of them, including
--- rf-heat-exchanger's own water box. A box with no contained connection at all is simply not the
--- `contained` run's business, though it IS the `all` run's.
local function contained(box)
  local any, all, seen = false, true, false
  for _, c in ipairs(box.pipe_connections or {}) do
    seen = true
    if c.connection_category then any = true else all = false end
  end
  return seen and all, any and not all, seen
end

local stripped, mixed, kept = 0, 0, 0
for _, class in pairs(data.raw) do
  for _, proto in pairs(class) do
    if type(proto) == "table" and proto.name and proto.name:sub(1, 3) == "rf-" then
      local boxes = {}
      if proto.fluid_box then boxes[#boxes + 1] = { "fluid_box", proto.fluid_box } end
      if proto.output_fluid_box then boxes[#boxes + 1] = { "output_fluid_box", proto.output_fluid_box } end
      if proto.fluid_boxes then
        for i, b in pairs(proto.fluid_boxes) do
          if type(b) == "table" then boxes[#boxes + 1] = { "fluid_boxes[" .. tostring(i) .. "]", b } end
        end
      end
      if proto.energy_source and proto.energy_source.fluid_box then
        boxes[#boxes + 1] = { "energy_source.fluid_box", proto.energy_source.fluid_box }
      end
      for _, entry in ipairs(boxes) do
        local where, box = entry[1], entry[2]
        local all, some, seen = contained(box)
        if all or (STRIP_ALL and seen) then
          if box.pipe_covers then
            box.pipe_covers = nil
            stripped = stripped + 1
            log("ARTPROBE data: stripped pipe_covers from " .. proto.name .. "." .. where)
          else
            kept = kept + 1
            log("ARTPROBE data: " .. proto.name .. "." .. where .. " declared no pipe_covers to begin with")
          end
        elseif some then
          mixed = mixed + 1
          log("ARTPROBE data: MIXED BOX left alone: " .. proto.name .. "." .. where
            .. " holds both contained and plumbable connections, and pipe_covers is per box")
        end
      end
    end
  end
end
log(string.format("ARTPROBE data: %d box(es) stripped, %d already bare, %d mixed and left alone",
  stripped, kept, mixed))
'@

# ------------------------------------------------------ this probe's own half of the rig's control
$layout = @'

local EXCHANGER = "rf-heat-exchanger"
local REACTOR   = "rf-reactor"
local ENERGY    = "rf-reactor-energy"

--- Which way a connection faces, read off the tile it targets rather than remembered.
local function facing(c)
  local dx, dy = c.target_position.x - c.position.x, c.target_position.y - c.position.y
  if dy < 0 then return "north" elseif dy > 0 then return "south" elseif dx < 0 then return "west" end
  return "east"
end

--- The first connection of `entity` facing `side`, and whether a pipe can join it. The engine is
--- asked which by BUILDING a pipe on the tile and seeing whether it joined -- the same question a
--- player asks by dragging one, and the same discriminator the library's pipe_up uses.
local function connection_facing(entity, side)
  for i = 1, #entity.fluidbox do
    for _, c in pairs(entity.fluidbox.get_pipe_connections(i)) do
      if facing(c) == side then return c end
    end
  end
end

--- Every connection in the tree that carries a connection_category, asked of the loaded prototypes.
--- Reported so the note's coverage claim is the game's rather than a list somebody typed.
local function report_contained()
  local machines, total = {}, 0
  for name, proto in pairs(prototypes.entity) do
    if name:sub(1, 3) == "rf-" then
      local here = 0
      for _, box in pairs(proto.fluidbox_prototypes or {}) do
        for _, c in pairs(box.pipe_connections or {}) do
          if c.connection_category then
            for _, cat in pairs(c.connection_category) do
              if cat ~= "default" then here = here + 1 ; break end
            end
          end
        end
      end
      if here > 0 then machines[#machines + 1] = name .. " (" .. here .. ")" ; total = total + here end
    end
  end
  table.sort(machines)
  say(string.format("%d contained connection(s) across %d prototype(s): %s",
    total, #machines, table.concat(machines, ", ")))
end

script.on_nth_tick(60, function()
  if storage.stage then return end
  storage.stage = "built"

  local surface = game.surfaces[1]
  ready(surface)
  report_contained()

  -- FOUR SUBJECTS, ONE PER ART SOURCE plus the bolted pair. Spaced by the widest frame each needs
  -- rather than by a footprint, for the reason the other two art probes learnt: a frame is what has
  -- to clear a frame.
  local SUBJECTS = {
    { key = "exchanger",  name = EXCHANGER },
    { key = "reactor",    name = REACTOR },
    { key = "aneutronic", name = "rf-aneutronic-reactor" },
    { key = "converter",  name = "rf-direct-energy-converter" },
  }

  local x = 0.5
  storage.subjects = {}
  for _, s in ipairs(SUBJECTS) do
    local w, h = footprint(s.name)
    pave(surface, x - w / 2 - 8, -h / 2 - 8, x + w / 2 + 8, h / 2 + 8)
    sweep(surface, x - w / 2 - 8, -h / 2 - 8, x + w / 2 + 8, h / 2 + 8, x, -h / 2 - 30)
    local e = place(surface, s.name, x, 0.5)
    local west = connection_facing(e, "west")
    local north = connection_facing(e, "north")
    storage.subjects[#storage.subjects + 1] = {
      key = s.key, name = s.name, x = x, y = 0.5, w = w, h = h,
      west = west and { x = west.position.x, y = west.position.y } or nil,
      north = north and { x = north.position.x, y = north.position.y } or nil,
    }
    say(string.format("%s at %g,%g, %dx%d tiles", s.name, x, 0.5, w, h))
    x = x + math.max(w, 24) + 16
  end

  -- THE BOLTED PAIR, which is the only frame that can answer whether the north energy connection
  -- shows the miss IN PRACTICE. That face is the reactor contact: a player never sees it bare.
  -- Placed by asking the reactor where its south energy connection points, the way
  -- probe-heat-exchanger-art.ps1 does, rather than by arithmetic this file would own.
  local rw, rh = footprint(REACTOR)
  local ew, eh = footprint(EXCHANGER)
  pave(surface, x - rw / 2 - 8, -rh / 2 - 8, x + rw / 2 + 8, rh / 2 + rh + eh + 8)
  sweep(surface, x - rw / 2 - 8, -rh / 2 - 8, x + rw / 2 + 8, rh / 2 + rh + eh + 8, x, -rh / 2 - 30)
  local reactor = place(surface, REACTOR, x, 0.5)
  local south = connection_facing(reactor, "south")
  local scratch = surface.create_entity({ name = EXCHANGER, position = { x, 0.5 - 4 * rh },
                                          force = "player" })
  local own = connection_facing(scratch, "north")
  local dx, dy = own.position.x - scratch.position.x, own.position.y - scratch.position.y
  scratch.destroy()
  local bolted = place(surface, EXCHANGER, south.target_position.x - dx, south.target_position.y - dy)
  local joint = connection_facing(bolted, "north")
  storage.bolted = { x = bolted.position.x, y = bolted.position.y, w = ew, h = eh,
                     north = { x = joint.position.x, y = joint.position.y } }
  say(string.format("%s bolted to %s's south face; the joint connection is at %g,%g",
    EXCHANGER, REACTOR, joint.position.x, joint.position.y))

  storage.shoot_at = game.tick + 120
end)

script.on_event(defines.events.on_tick, function()
  if not storage.shoot_at or game.tick < storage.shoot_at then return end
  storage.shoot_at = nil

  -- SIX TILES ACROSS, AT ZOOM 8 AND AT ZOOM 1. Six holds a socket, the cover outboard of it and a
  -- tile of ground either side; on rf-heat-exchanger's west end it holds BOTH west sockets, which
  -- is what makes the contained one and its plumbable control one frame rather than two.
  --
  -- BOTH ZOOMS ON PURPOSE. A miss that is obvious at 256 px to the tile and invisible at 32 are
  -- different findings, and #390 asks for both by number.
  local TILES = 6
  local function pair_of_shots(stem, x, y)
    tiles_shot(stem .. "-x8.png", x, y, TILES, TILES, 8, 0)
    tiles_shot(stem .. "-z1.png", x, y, TILES, TILES, 1, 0)
  end

  for _, s in ipairs(storage.subjects) do
    if s.west then pair_of_shots(s.key .. "-west", s.west.x, s.west.y) end
    if s.north then pair_of_shots(s.key .. "-north", s.north.x, s.north.y) end
    -- The whole machine at zoom 1 as well, so a reader can see where the close frames were cut.
    tiles_shot(s.key .. "-whole-z1.png", s.x, s.y, s.w + 6, s.h + 6, 1, 0)
  end

  local b = storage.bolted
  pair_of_shots("exchanger-bolted", b.north.x, b.north.y)

  finish()
end)
'@

$invoke = @{
    FactorioExe = $FactorioExe; RepoRoot = $repoRoot
    RigName = 'rf-pipe-cover-probe'; RigTitle = 'Pipe cover miss probe'
    Author = 'probe-pipe-cover-miss.ps1'; TempPrefix = 'rf-cover-'
    Control = ($ArtProbeLua + $layout); OutputDirectory = $OutputDirectory
    TimeoutSeconds = $TimeoutSeconds; KeepTemp = $KeepTemp
    MapSeed = $(if ($PSBoundParameters.ContainsKey('MapSeed')) { $MapSeed } else { $null })
    Epilogue = @(
        'Run this three times -- as it ships, with -Strip contained and with -Strip all -- and',
        'hand the three directories to tools/measure-pipe-cover-miss.py. The difference between',
        'two runs'' pixels IS the cover, so nothing has to be told what one looks like.')
}
if ($Strip -ne 'none') {
    $invoke.DataFinalFixes = $dataFinalFixes.Replace('__STRIP_ALL__', $(if ($Strip -eq 'all') { 'true' } else { 'false' }))
}
Invoke-ArtProbe @invoke
