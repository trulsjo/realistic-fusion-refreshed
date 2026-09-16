<#
.SYNOPSIS
    The scaffolding every art probe needs: the Lua a rig is built on, and the launch that turns it
    into pictures. Dot-sourced -- it runs nothing by itself.

.DESCRIPTION
    THE ONE COPY OF WHAT THREE ART PROBES WOULD OTHERWISE HAND-COPY (#386). An art probe is the
    only shape in scripts/ that needs the GRAPHICAL client: game.take_screenshot renders through
    the game's own renderer, so --benchmark and --create cannot produce a frame. That is a rig mod
    written to a scratch directory, a launch from a directory holding steam_appid.txt, a wait for a
    done marker, a settle-wait on the PNG sizes, and a copy -- about two hundred lines that say
    nothing about any machine.

    UNTIL #386 THERE WERE TWO COPIES, AND THE SECOND ONE SAID SO IN ITS OWN HEADER: "If a third art
    probe is written, extract then: two is where you notice, three is where it pays." #388 is that
    third probe, and this is the extraction it was told to do first.

    THE STANDALONE CONVENTION IS NARROWED HERE, NOT OVERTURNED. Every probe in scripts/ is
    standalone by design -- it stays committed so the next engine version can be asked the same
    question, and reading one should need no other file. That still holds for a probe that dumps
    prototypes or ticks a rig: eight of them carry their own status_name and four their own
    place(), and none of them is asked to change. What moved is the part no probe's own question is
    written in: an art probe's reader wants to know WHAT IT SHOOTS AND WHY, and every line of that
    is still in the probe's own file. What is here is how a window gets opened.

    WHAT AN ART PROBE STILL OWNS, and this list is the boundary rather than an accident:

      - Its layout. Where each machine stands, what it is bolted to, what is fed into it, and what
        every frame is for. That is the probe's question and it is not scaffolding.
      - Its shot list. `tiles_shot` below takes the picture; which pictures to take, at what zoom,
        of what, is the probe's.
      - Anything about ONE machine's plumbing. rf-heat-exchanger meets a reactor along a fluid
        connection, so its probe carries `bolt`, `facing` and `connection_facing`;
        rf-isotope-collector shares no connection with a reactor at all, so its probe carries
        `blind_face` and `connection_tiles` instead. Neither is here, because neither is shared,
        and a helper with one caller is a helper in the wrong file.

.NOTES
    A PROBE, NOT A CHECK, and that does not change by being shared. Nothing here asserts anything
    about a picture. It raises on a rig that could not be built or a game that wrote no bytes --
    which is an instrument fault, not a finding.
#>

#Requires -Version 7

# ---------------------------------------------------------------------------------- the Lua half
# Prepended to each probe's own control.lua. Every name below is a file-scope local, so a probe's
# own code sees them without qualification -- and a probe that wants a different `pave` can simply
# declare one after this and shadow it.
#
# THE SHUTTER WRITES A SIDECAR (#385). Before it, a frame was a bare PNG: a reader could see it and
# nothing could measure it, because nothing recorded which world coordinate the centre pixel was.
# tools/measure-frame-accents.py is what wanted that, and could not have it.
$ArtProbeLua = @'
-- Generated from scripts/art-probe-lib.ps1, which is where to change it. Nothing here ships.

local OUT = "rf-art/"

-- Tagged so the caller can pick these out of a log that is mostly not ours.
local function say(line) localised_print('ARTPROBE ' .. line) end

local BUILD_CHECK = defines.build_check_type.manual
if not BUILD_CHECK then
  error("defines.build_check_type.manual is gone; this rig's placement guard would silently "
    .. "fall back to ghost_revive")
end

--- An odd-sided building's centre sits at a tile centre, so its edges land on tile boundaries.
--- Every position a probe computes is at a tile centre on purpose: "flush" is only true if it is.
---
--- REFUSES AN OVERLAP RATHER THAN PHOTOGRAPHING ONE. create_entity does NOT collision-check, so
--- until #275 a stale layout happily stacked two machines on one another and the shot came out
--- garbled -- which is the worst way for a probe to fail, because a probe asserts nothing and a
--- garbled picture still looks like a picture. bench-mod-links.ps1's place_or_die is the same
--- guard for the same reason; the error says "stale" because that is what a refused placement here
--- means.
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
--- boxes is the engine's business, and an energy source can add one of its own.
local function box_of(entity, fluid)
  for i = 1, #entity.fluidbox do
    local f = entity.fluidbox.get_filter(i)
    if f and f.name == fluid then return i end
  end
end

--- entity.status as its name. There is no status_string in 2.0.77.
local function status_name(entity)
  if not (entity and entity.valid) then return "?" end
  for k, v in pairs(defines.entity_status) do
    if v == entity.status then return k end
  end
  return tostring(entity.status)
end

--- An ordinary pipe on every connection a player can actually plumb, and none on the rest.
--- Vanilla's pipe on purpose rather than rf-pipe: the claim being photographed is that an ordinary
--- pipe reaches these fluids at all.
---
--- WHICH CONNECTIONS THOSE ARE IS ASKED, NOT LISTED. Three of rf-heat-exchanger's six carry a
--- connection_category of their own (ADR 0018, #86) and nothing a player can build joins them. So
--- a pipe is built on every tile a connection points at and the engine is then asked whether it
--- joined; one that did not is destroyed again. That is a stronger answer than any table here
--- could be, because it is the same question a player asks by dragging a pipe at the machine --
--- and it stays right the day a connection's category changes, on a machine whose every fluid is
--- uncontained today.
local function pipe_up(surface, entity)
  local made, refused = 0, 0
  for i = 1, #entity.fluidbox do
    for _, c in pairs(entity.fluidbox.get_pipe_connections(i)) do
      if c.target_position and #surface.find_entities_filtered({ position = c.target_position }) == 0 then
        local p = place(surface, "pipe", c.target_position.x, c.target_position.y)
        local joined = false
        for _, pc in pairs(p.fluidbox.get_pipe_connections(1)) do
          if pc.target and pc.target.owner and pc.target.owner.unit_number == entity.unit_number then
            joined = true
          end
        end
        if joined then made = made + 1 else p.destroy() ; refused = refused + 1 end
      end
    end
  end
  if refused > 0 then
    say(string.format("%s took %d pipe(s); %d connection(s) refused one, which is what contained "
      .. "means", entity.name, made, refused))
  else
    say(string.format("%s took %d pipe(s); every connection accepted one", entity.name, made))
  end
  return made, refused
end

--- Flat, dry, uniform ground under a rectangle, so the shot is of the machine and not of the
--- terrain it happened to land on -- and so nothing is refused for standing in water.
---
--- DECORATIVES ARE DESTROYED AS WELL AS TILES RETILED. set_tiles alone leaves every shrub, dry root
--- and rock patch standing: they are not entities, so `sweep` below walks straight past them, and
--- "uniform ground" was a claim this comment made that the code did not keep. The first run of the
--- collector's probe came back with weeds across half of every frame (#346).
---
--- THE GRASS VARIANT IS STILL THE MAP'S, NOT OURS. set_tiles names grass-1; which of its variants
--- each tile draws comes off the map seed, so two runs on random maps differ on most of a frame's
--- pixels while the machine itself does not. Pass -MapSeed to make two frames comparable.
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

--- Clear everything out of a rectangle and park the player's character at (park_x, park_y).
---
--- THE CHARACTER IS MOVED, NOT DESTROYED, AND IT IS MOVED BY THE ENTITY RATHER THAN THROUGH THE
--- PLAYER. It stands at the spawn point, which is where a rig's first machine usually goes, and it
--- is the one thing this sweep spares -- destroying the player's character on a live client is not
--- something a screenshot is worth. It blocks a manual build check like anything else, so place()'s
--- guard refused the heat exchanger's reactor outright the first time that probe ran: the guard was
--- right and the layout was wrong.
---
--- Going through game.players[i].character does NOT move it, measured on 2.0.77: a character entity
--- stands at spawn at tick 60 while the player's own `character` is not yet the one to reach it by.
--- Teleporting the entity the sweep already has in hand always works, and the return value is
--- checked because a teleport that quietly fails comes back as the same baffling "will not fit".
local function sweep(surface, x1, y1, x2, y2, park_x, park_y)
  for _, e in pairs(surface.find_entities_filtered({
      area = { { x1 - 5, y1 - 5 }, { x2 + 5, y2 + 5 } } })) do
    if e.type == "character" then
      if not e.teleport({ park_x, park_y }) then
        error(string.format("could not move the character off the spawn point to (%g, %g); it "
          .. "stands where this rig builds", park_x, park_y))
      end
      say(string.format("parked the character at %g,%g", park_x, park_y))
    else
      e.destroy()
    end
  end
end

--- Get a surface ready to be photographed: chunks generated, sun fixed, WEATHER OFF.
---
--- CLOUDS ARE WHY THIS IS FOUR LINES RATHER THAN THREE, and they cost a measurement before anybody
--- noticed them (#387). Factorio draws a moving cloud shadow over the map, and a screenshot catches
--- whatever the clouds were doing on that tick: soft-edged, tens of tiles across, and worth up to
--- 6.4 dE00 on an accent band read off a frame -- against the 0.7 the game otherwise differs from
--- the sheet by. It cannot be subtracted either. On the frame that caught one it darkened the top
--- two thirds of a socket by up to 22% and left the bottom third IDENTICAL TO THE PIXEL, which is a
--- shadow with an edge across it and not an offset.
---
--- They were also most of what made one frame irreproducible, THOUGH NOT ALL OF IT, and the
--- difference is measured rather than assumed. rf-heat-exchanger's working-night.png came back
--- different from two runs of identical code on the same map seed: 311,621 pixels apart, by up to
--- 17 of 255, with clouds on. With them off the same pair is 115,233 pixels apart by AT MOST 2, so
--- the clouds were the visible part and something in the glow still jitters by a level or two. That
--- residue is unexplained and is not this function's; it is recorded here so nobody re-finds it and
--- calls it weather. Every other frame either probe takes is byte-identical across runs at a fixed
--- seed, the collector's own night.png included -- which is what `glow: false` means, and is why
--- only the machine that HAS a glow shows the residue.
---
--- always_day fixes the sun and does NOT fix the clouds: they are a separate LuaSurface flag, and
--- setting it false means clouds are never shown whatever the player's graphics settings say
--- (LuaSurface.show_clouds, 2.0.77). The first three lines are what both probes ran before #386.
local function ready(surface)
  surface.request_to_generate_chunks({ 0, 0 }, 8)
  surface.force_generate_chunk_requests()
  surface.always_day = true
  surface.show_clouds = false
end

--- WHICH SURFACE THE SHUTTER LOOKS AT. nil means the map's first, which is every rig this
--- repository builds for itself. A probe shooting two surfaces in one run -- a control on ground of
--- its own beside a subject inside a borrowed base (#388) -- assigns this before each frame, so the
--- surface a frame was taken on reaches the sidecar rather than being assumed by its reader.
local shot_surface = nil

--- Take one frame, and write beside it what it is a frame OF (#385).
---
--- daytime is passed per shot rather than set on the surface, so one run gives both. 0 is noon and
--- 0.5 is midnight; the pictures say which is which and the names are checked against them.
---
--- THE SIDECAR IS WRITTEN FROM THE SHOT'S OWN ARGUMENTS, WHICH IS THE WHOLE POINT OF IT BEING
--- HERE. A frame used to be a bare PNG: the position, size and zoom were computed in Lua and then
--- thrown away, so a reader could see a frame and nothing could measure it. Everything below comes
--- off the same five values take_screenshot is handed, on the line that hands them over -- and the
--- machines are ASKED FOR rather than passed in, through the frame's own world rectangle derived
--- from those same values. probe-heat-exchanger-art.ps1's own comment already warned that "two
--- expressions for one number is how the spacing above and the framing here would come apart";
--- this is that warning applied to the sidecar.
local function shot(file, x, y, w_px, h_px, zoom, daytime)
  local surface = shot_surface or game.surfaces[1]
  game.take_screenshot({
    surface = surface, position = { x, y }, resolution = { w_px, h_px }, zoom = zoom,
    path = OUT .. file, daytime = daytime,
    show_gui = false, show_entity_info = false, anti_alias = true, force_render = true,
  })

  -- The frame as a world rectangle. At zoom z one tile is 32*z pixels, so the frame is
  -- w_px / (32*z) tiles across and reaches half of that either side of where the camera is
  -- centred. No constant here that take_screenshot was not given.
  local px_per_tile = 32 * zoom
  local half_w, half_h = w_px / (2 * px_per_tile), h_px / (2 * px_per_tile)
  local in_shot = {}
  for _, e in pairs(surface.find_entities_filtered({
      area = { { x - half_w, y - half_h }, { x + half_w, y + half_h } }, force = "player" })) do
    local w, h = footprint(e.name)
    in_shot[#in_shot + 1] = {
      name = e.name,
      position = { x = e.position.x, y = e.position.y },
      direction = e.direction,
      footprint = { w = w, h = h },
    }
  end

  helpers.write_file(OUT .. file:gsub("%.png$", "") .. ".json", helpers.table_to_json({
    frame = file,
    zoom = zoom,
    pixels_per_tile = px_per_tile,
    resolution = { w = w_px, h = h_px },
    centre = { x = x, y = y },
    tiles = { w = w_px / px_per_tile, h = h_px / px_per_tile },
    daytime = daytime,
    surface = surface.name,
    machines = in_shot,
  }) .. "\n", false)

  say(string.format("shot %s at zoom %g, %dx%d px, centred on %g,%g, with %d entity(s) in frame",
    file, zoom, w_px, h_px, x, y, #in_shot))
end

--- EVERY FRAME IS SIZED IN TILES AND THEN CONVERTED, because a resolution alone says nothing about
--- what is in shot: at zoom z one tile is 32*z pixels.
local function tiles_shot(file, x, y, tiles_w, tiles_h, zoom, daytime)
  shot(file, x, y, math.ceil(tiles_w * 32 * zoom), math.ceil(tiles_h * 32 * zoom), zoom, daytime)
end

--- Written when every frame has been queued: the caller waits on it. NOT the pictures -- see the
--- settle-wait in scripts/art-probe-lib.ps1, which is where that was learnt the hard way.
local function finish()
  game.set_wait_for_screenshots_to_finish()
  helpers.write_file(OUT .. "done.txt", "done\n")
  say("done")
end
'@

# ------------------------------------------------------------------------- the PowerShell half
function Invoke-ArtProbe {
    <#  .SYNOPSIS
            Build the rig mod, open the graphical client on a scratch map, wait for the frames, and
            copy them out. Returns nothing; the frames and their sidecars are in $OutputDirectory.

        .DESCRIPTION
            WHY THE GRAPHICAL CLIENT, unlike every other probe in scripts/. game.take_screenshot
            renders through the game's own renderer, so --benchmark and --create cannot produce a
            frame. A window opens for a few seconds and closes by itself; that is expected.  #>
    param(
        [Parameter(Mandatory)] [string] $FactorioExe,
        [Parameter(Mandatory)] [string] $RepoRoot,
        [Parameter(Mandatory)] [string] $RigName,
        [Parameter(Mandatory)] [string] $RigTitle,
        [Parameter(Mandatory)] [string] $Author,
        [Parameter(Mandatory)] [string] $Control,
        [Parameter(Mandatory)] [string] $OutputDirectory,
        [Parameter(Mandatory)] [string] $TempPrefix,
        [int]      $TimeoutSeconds = 180,
        [Nullable[int]] $MapSeed,
        [switch]   $KeepTemp,
        [string]   $LoadGame,
        [string[]] $Epilogue = @()
    )

    $bundled = Get-BundledMods -FactorioExe $FactorioExe
    $ourMods = Get-RepoMods

    $temp   = Join-Path ([IO.Path]::GetTempPath()) ($TempPrefix + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $modDir = Join-Path $temp 'mods'
    $rigDir = Join-Path $modDir $RigName
    New-Item -ItemType Directory -Path $rigDir -Force | Out-Null
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

    @{
        name = $RigName; version = '0.0.1'; title = $RigTitle
        author = $Author; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed', 'realistic-fusion-refreshed-core')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8
    Set-Content -Path (Join-Path $rigDir 'control.lua') -Value $Control -Encoding utf8

    $proc = $null
    try {
        New-ModJunctions -ModDirectory $modDir -RepoRoot $RepoRoot -Mods $ourMods
        $enabled = Resolve-BundledSelection -Requested @() -Bundled $bundled
        Write-Host "bundled enabled: $(if ($enabled) { $enabled -join ', ' } else { 'none (base 2.0 only)' })"
        Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabled -Mods ($ourMods + $RigName)

        # THE MAP THE FRAMES ARE SHOT ON. A probe handed -LoadGame opens that save instead of
        # creating one, which is what an art probe standing inside a borrowed base needs (#388,
        # ADR 0029) -- nothing here writes a save back, so the borrowed file is untouched on disk.
        if ($LoadGame) {
            $save = $LoadGame
            if (-not (Test-Path -LiteralPath $save)) { throw "no save at '$save'." }
            if ($null -ne $MapSeed) {
                throw "-MapSeed generates terrain and means nothing against a save that already has some."
            }
        } else {
            $save = Join-Path $temp 'art.zip'
            $create = @('--create', $save)
            if ($null -ne $MapSeed) { $create += @('--map-gen-seed', "$MapSeed") }
            Invoke-FactorioStep -FactorioExe $FactorioExe -ModDirectory $modDir -OutputDirectory $temp `
                -Tag 'create' -Arguments $create | Out-Null
        }

        # The same private write-data directory Invoke-Factorio makes, reused: it is where the
        # config points, so it is also where script-output lands.
        $configPath = Join-Path $temp 'factorio-config.ini'
        $shotDir    = Join-Path $temp 'write-data/script-output/rf-art'
        $doneFile   = Join-Path $shotDir 'done.txt'

        # Launched from a scratch directory holding steam_appid.txt, for the reason dev-launch.ps1
        # gives: the Steam API reads that file from the WORKING directory and otherwise relaunches
        # the game through Steam, dropping --mod-directory and --config on the floor.
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

        # THE MARKER IS NOT THE PICTURES. take_screenshot queues; the engine renders and writes on
        # its own thread, and helpers.write_file lands in the same tick that queued them -- so
        # done.txt appears while every PNG is still zero bytes. Found the hard way: the first run of
        # the heat exchanger's probe copied five empty files and reported success. Wait until each
        # file has a size that has stopped changing. The sidecars need no such wait; they go through
        # helpers.write_file like the marker itself.
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

        # EVERY FRAME GOES WITH ITS SIDECAR (#385). A frame copied out without the JSON beside it is
        # back to being a picture nothing can measure, so both extensions are copied together.
        $shots = @(Get-ChildItem -LiteralPath $shotDir -Filter '*.png' | Sort-Object Name)
        foreach ($s in $shots) { Copy-Item -LiteralPath $s.FullName -Destination $OutputDirectory -Force }
        foreach ($j in (Get-ChildItem -LiteralPath $shotDir -Filter '*.json')) {
            Copy-Item -LiteralPath $j.FullName -Destination $OutputDirectory -Force
        }
        $orphans = @($shots | Where-Object {
            -not (Test-Path -LiteralPath (Join-Path $OutputDirectory ($_.BaseName + '.json'))) })
        if ($orphans) {
            throw "no sidecar was written for: $($orphans.Name -join ', '). A frame nothing can say the position of is what #385 exists to stop."
        }

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
        foreach ($l in $Epilogue) { Write-Host $l }
    }
    finally {
        if ($proc -and -not $proc.HasExited) { $proc.Kill() ; $proc.WaitForExit(10000) | Out-Null }
        if (-not $KeepTemp) {
            Remove-ModJunctions -ModDirectory $modDir
            Remove-TempDirectory -Path $temp -Label $RigName
        } else { Write-Host "kept: $temp" }
    }

    Write-Host ''
    Write-Host 'Probe finished. Exit 0 means the pictures were taken, not that the art is right.'
}
