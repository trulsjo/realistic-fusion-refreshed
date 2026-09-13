<#
.SYNOPSIS
    Photographs a machine's pipe socket against an ordinary pipe, close up, so the step between them
    can be seen and measured. Screenshots only -- it asserts nothing.

.DESCRIPTION
    A PROBE, NOT A CHECK. Exit 0 means it ran and wrote the pictures, never that the sockets are
    right. It exists because of a defect Truls found on 2026-09-13 that had been shipping unseen:
    a rendered socket and the vanilla pipe plugged into it DO NOT LINE UP. The machine's stub is
    drawn higher than the pipe's, so a run of pipe meets a machine at a step.

    NOBODY HAD LOOKED, and that is the interesting part. Both rendered machines put their sockets at
    the same height -- `SOCKET_Z = 0.55` in models/isotope-collector/build.py, `z = 0.55` in
    models/heat-exchanger/build.py -- so both have it. scripts/probe-heat-exchanger-art.ps1 shoots
    the machine bolted to a reactor, alone, and in four rotations, and never once puts a pipe on it;
    probe-isotope-collector-art.ps1 was the first to do that, and the first frame showed it.
    load-check compares a manifest's geometry against the prototype and cannot see a sprite at all.

    WHAT THE SPRITES SAY, measured off the sheets rather than off a screenshot, because both are
    drawn at scale 0.5 with no shift and are therefore directly comparable at 64 px to the tile:

      vanilla pipe   body 0.609 tiles tall on screen, centre 0.031 tiles above ground
      our socket     body 0.750 tiles tall on screen, centre 0.398 tiles above ground

    A world height h shows as 0.707 h on screen, so our socket is drawn about 0.52 tiles of world
    height too high, and about a quarter too fat.

    AND THE TWO CANNOT SIMPLY BE MADE TO AGREE, which is why this is a probe and not a fix. Our
    socket is a cylinder projected honestly: radius 0.3 at z 0.55, so its silhouette is what a real
    tube at that height would throw. Vanilla's pipe is not -- work its drawn extents back and no
    cylinder fits them. It is a stylised flat ribbon, drawn low and shallow, the way Factorio's own
    art is drawn. Lowering our socket until the two centres coincide puts its axis at about z 0.05,
    which draws correctly and buries the tube in the deck the bays are built around.

    So this rig takes the pictures and leaves the choice alone. It is a decision about how closely
    this mod's art imitates vanilla's conventions against its own, and CLAUDE.md puts that kind of
    call with Truls.

    WHAT IT SHOOTS:

      joint-collector.png  rf-isotope-collector's west socket with an ordinary pipe on it, zoomed
                           hard, nothing else in frame. The subject is the seam between the two.
      joint-exchanger.png  rf-heat-exchanger's water socket, the same way, because the defect is
                           shared and a picture of one machine invites the wrong conclusion.
      pipe-alone.png       three tiles of ordinary pipe on bare ground at the same zoom, as the
                           reference the other two are read against.
      run.png              a pipe run leaving the collector's west socket and going five tiles, at
                           the game's own zoom. This is the one a player would actually see, and it
                           is here so the step can be judged at the size it is met at rather than
                           only under magnification.

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
    pwsh -File scripts/probe-socket-height.ps1
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

--- The tile a named fluid's WEST-facing connection points at, and the connection's own tile.
--- Asked rather than written down: this rig is about where a socket IS, so it must not assume.
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
  surface.request_to_generate_chunks({ 0, 0 }, 8)
  surface.force_generate_chunk_requests()
  surface.always_day = true

  -- Three subjects, a long way apart, so no frame can catch a neighbour. The zoom here is extreme
  -- and the frames are small, but the spacing is generous on purpose: a rig that has to be
  -- re-tuned every time a footprint changes is a rig that photographs the wrong thing quietly.
  local CW, CH = footprint("rf-isotope-collector")
  local EW, EH = footprint("rf-heat-exchanger")
  local SPACING = math.max(CW, CH, EW, EH) + 24
  say(string.format("collector %dx%d, exchanger %dx%d, subjects %d apart", CW, CH, EW, EH, SPACING))

  local x1, y1 = -20, -SPACING - 20
  local x2, y2 = 2 * SPACING + 20, SPACING + 20
  pave(surface, x1, y1, x2, y2)
  for _, e in pairs(surface.find_entities_filtered({ area = { { x1, y1 }, { x2, y2 } } })) do
    if e.type == "character" then
      if not e.teleport({ x2 - 3, y1 + 3 }) then error("could not park the character") end
    else
      e.destroy()
    end
  end

  -- 1. The collector, with a pipe on its west socket and a run leaving it.
  local collector = place(surface, "rf-isotope-collector", 0.5, 0.5)
  local cw = west_connection(collector, "rf-tritium")
  if not cw then error("rf-isotope-collector has no west-facing rf-tritium connection") end
  for k = 0, 4 do
    place(surface, "pipe", cw.target_position.x - k, cw.target_position.y)
  end
  say(string.format("collector west socket tile %g,%g; pipe run starts there and goes 5 west",
    cw.target_position.x, cw.target_position.y))

  -- 2. The heat exchanger, the same way, because the defect is shared and one machine's picture
  --    invites the wrong conclusion. Its west connection is water (#298 names the filters).
  local exchanger = place(surface, "rf-heat-exchanger", 0.5 + SPACING, 0.5)
  local ew = west_connection(exchanger, "water")
  if ew then
    for k = 0, 2 do place(surface, "pipe", ew.target_position.x - k, ew.target_position.y) end
    say(string.format("exchanger west water socket tile %g,%g", ew.target_position.x, ew.target_position.y))
  else
    say("exchanger has no west-facing water connection; its frame will show the machine alone")
  end

  -- 3. The reference: three tiles of ordinary pipe on bare ground, nothing near it.
  local PIPE_X, PIPE_Y = 0.5 + 2 * SPACING, 0.5
  for k = -1, 1 do place(surface, "pipe", PIPE_X + k, PIPE_Y) end

  storage.shot = {
    collector = { x = cw.target_position.x, y = cw.target_position.y },
    exchanger = ew and { x = ew.target_position.x, y = ew.target_position.y } or nil,
    pipe = { x = PIPE_X, y = PIPE_Y },
    collector_centre = { x = 0.5, y = 0.5 },
  }
  storage.shoot_at = game.tick + 120
end)

script.on_event(defines.events.on_tick, function()
  if not storage.shoot_at or game.tick < storage.shoot_at then return end
  storage.shoot_at = nil
  local surface, s = game.surfaces[1], storage.shot

  local function shot(file, x, y, tiles_w, tiles_h, zoom)
    game.take_screenshot({
      surface = surface, position = { x, y },
      resolution = { math.ceil(tiles_w * 32 * zoom), math.ceil(tiles_h * 32 * zoom) },
      zoom = zoom, path = OUT .. file, daytime = 0,
      show_gui = false, show_entity_info = false, anti_alias = true, force_render = true })
    say("shot " .. file)
  end

  -- THE JOINT FRAMES ARE CENTRED ON THE SEAM, not on either machine: the subject is the half-tile
  -- where the socket stops and the pipe starts. Zoom 8 puts one tile on 256 px, which is four times
  -- what a player sees and is the point -- a step of a fifth of a tile is three pixels at the
  -- game's own zoom and has to be magnified before anyone can argue about it.
  shot("joint-collector.png", s.collector.x + 0.5, s.collector.y, 4, 3, 8)
  if s.exchanger then shot("joint-exchanger.png", s.exchanger.x + 0.5, s.exchanger.y, 4, 3, 8) end
  shot("pipe-alone.png", s.pipe.x, s.pipe.y, 4, 3, 8)
  -- And the same seam at the size a player actually meets it, which is the frame that decides
  -- whether any of this matters.
  shot("run.png", s.collector_centre.x - 4, s.collector_centre.y, 14, 8, 2)

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
        Write-Host ("  {0,-22} {1,8:N0} KB   {2}" -f $s.Name, ($s.Length / 1KB), (Join-Path $OutputDirectory $s.Name))
    }
    Write-Host ''
    Write-Host "screenshots: $OutputDirectory"
    Write-Host 'Both rendered machines build sockets at z 0.55. The sprites say ours are drawn about'
    Write-Host '0.52 tiles of world height too high and a quarter too fat against a vanilla pipe --'
    Write-Host 'and that vanilla pipe is a stylised flat ribbon rather than an honest cylinder, so'
    Write-Host 'matching it exactly is a decision about house style, not a number to correct.'
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
