<#
.SYNOPSIS
    Draw placeholder building sprites: a labelled rectangle at the machine's real tile footprint,
    with its pipe connections marked where they actually are.

.DESCRIPTION
    Four machines have no art of their own and wear a vanilla building that is the wrong size and,
    for three of them, the wrong machine. A vanilla sprite at the wrong footprint is worse than a
    plain box, because it looks finished and it lies about where the pipes go.

    So these are mockups on purpose. They state the footprint, they mark every connection, and they
    carry the machine's name, and they are meant to be replaced -- #108 for the heat exchanger, and
    whatever follows it for the rest.

    THE ART IS ORIGINAL AND THAT IS THE POINT. Rectangles drawn by this script are nobody else's
    work, so they carry the repository's own licence and raise no provenance question at all. That
    is the one thing Krastorio 2 could not supply and the predecessors could not supply cleanly:
    see ADR 0001 and issue #45, where the predecessor's exact 5x15 exchanger sheet was rejected for
    being unmarked.

    Regenerate rather than edit the PNGs. Sizes are still being settled and this is the cheap way
    to try one -- change Width/Height below, run this, run scripts/load-check.ps1.

    THE CONNECTION LIST HERE MUST AGREE WITH prototypes/entities.lua. Nothing enforces it: this
    script never loads the game. If they disagree the picture is wrong rather than the game, and a
    player is told a pipe goes somewhere it does not.

.PARAMETER OutputRoot
    Where the mod directories live. Defaults to the repository root.

.EXAMPLE
    ./scripts/make-mockup-art.ps1
#>
[CmdletBinding()]
param(
    [string] $OutputRoot = (Split-Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# 64 pixels to the tile, drawn at scale 0.5 in the prototype -- the arrangement Krastorio 2 and
# vanilla both use, so a mockup sits at the right size beside a real building.
$PIXELS_PER_TILE = 64

# Connection kinds and the colour each is drawn in. A player should tell an input from an output
# without reading the label, because on the smaller machines the label does not fit.
$KIND_COLOUR = @{
    input  = [System.Drawing.Color]::FromArgb(255,  90, 170, 255)
    output = [System.Drawing.Color]::FromArgb(255, 255, 150,  60)
    energy = [System.Drawing.Color]::FromArgb(255, 255, 215,  70)
}

# Positions are TILE CENTRES relative to the entity centre, exactly as pipe_connections declares
# them. Widths and heights are the selection box in tiles.
$MACHINES = @(
    @{
        # BOTH LONG SIDES CARRY THE BIG FLOWS, which is what the 5x15 shape is for: reactor energy in
        # along one whole fifteen-tile face and steam out along the other, so the machine sits
        # between the reactor and the turbine hall with a full-length contact on each side. Water is
        # the small flow and goes on the short ends, where a single pipe run can thread a column of
        # exchangers end to end.
        Mod = 'realistic-fusion-refreshed-assets'; Name = 'heat-exchanger'; Label = "HEAT`nEXCHANGER"
        Prototype = 'boiler'
        Width = 5; Height = 15; Core = $false
        Connections = @(
            @{ X = -2; Y =  0; Kind = 'energy'; Text = 'energy' },
            @{ X =  2; Y =  0; Kind = 'output'; Text = 'steam' },
            @{ X =  0; Y = -7; Kind = 'input';  Text = 'water' },
            @{ X =  0; Y =  7; Kind = 'input';  Text = 'water' }
        )
    },
    @{
        # Both long sides, so one butts the reactor and the other passes fluid to the next converter
        # in the row -- the chaining rf-hc-turbine and vanilla's steam turbine also do.
        Mod = 'realistic-fusion-refreshed-assets'; Name = 'direct-energy-converter'; Label = "DIRECT`nENERGY`nCONVERTER"
        Prototype = 'generator'
        Width = 5; Height = 15; Core = $false
        Connections = @(
            @{ X = -2; Y = 0; Kind = 'energy'; Text = 'energy' },
            @{ X =  2; Y = 0; Kind = 'energy'; Text = 'energy' }
        )
    },
    @{
        Mod = 'realistic-fusion-refreshed-assets'; Name = 'aneutronic-reactor'; Label = "ANEUTRONIC`nREACTOR"
        Prototype = 'boiler'
        Width = 15; Height = 15; Core = $true
        Connections = @(
            @{ X = -7; Y =  0; Kind = 'input';  Text = 'plasma' },
            @{ X =  7; Y =  0; Kind = 'input';  Text = 'plasma' },
            @{ X =  0; Y = -7; Kind = 'output'; Text = 'energy' }
        )
    },
    @{
        Mod = 'realistic-fusion-refreshed-assets'; Name = 'isotope-collector'; Label = "ISOTOPE`nCOLLECTOR"
        Prototype = 'boiler'
        Width = 5; Height = 5; Core = $false
        Connections = @(
            @{ X = -2; Y =  0; Kind = 'output'; Text = 'tritium' },
            @{ X =  2; Y =  0; Kind = 'output'; Text = 'tritium' },
            @{ X =  0; Y = -2; Kind = 'output'; Text = 'He3' }
        )
    },
    @{
        # A container: lithium arrives by inserter and the tritium it breeds leaves through the
        # reactor's own pipe, so it has no connections of its own to mark. See entities.lua.
        Mod = 'realistic-fusion-refreshed-assets'; Name = 'lithium-blanket'; Label = "LITHIUM`nBLANKET"
        Prototype = 'still'
        Width = 5; Height = 5; Core = $false
        Connections = @()
    }
)

function New-MockupFont {
    param([single] $Size)
    foreach ($family in @('Consolas', 'Segoe UI', 'Arial')) {
        try { return New-Object System.Drawing.Font($family, $Size, [System.Drawing.FontStyle]::Bold) } catch { }
    }
    return New-Object System.Drawing.Font([System.Drawing.FontFamily]::GenericMonospace, $Size, [System.Drawing.FontStyle]::Bold)
}

function Write-MockupSprite {
    param(
        [Parameter(Mandatory)] [hashtable] $Machine,
        [Parameter(Mandatory)] [string]    $Path,
        [switch] $Shadow
    )

    $w = $Machine.Width  * $PIXELS_PER_TILE
    $h = $Machine.Height * $PIXELS_PER_TILE

    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
        $g.Clear([System.Drawing.Color]::Transparent)

        $inset = [int]($PIXELS_PER_TILE * 0.12)
        $rect  = New-Object System.Drawing.Rectangle($inset, $inset, ($w - 2*$inset), ($h - 2*$inset))

        if ($Shadow) {
            # A flat translucent slab. The engine offsets and darkens it, so it only has to be the
            # right shape.
            $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(110, 0, 0, 0))
            $g.FillRectangle($brush, $rect)
            $brush.Dispose()
            $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
            return
        }

        $body = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 62, 68, 76))
        $g.FillRectangle($body, $rect)
        $body.Dispose()

        # A faint tile grid. This is what makes a mockup worth more than a plain box: the footprint
        # is countable at a glance, which is the thing being assessed.
        $grid = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(38, 255, 255, 255)), 1
        for ($i = 1; $i -lt $Machine.Width;  $i++) {
            $x = $i * $PIXELS_PER_TILE
            $g.DrawLine($grid, $x, $rect.Top, $x, $rect.Bottom)
        }
        for ($i = 1; $i -lt $Machine.Height; $i++) {
            $y = $i * $PIXELS_PER_TILE
            $g.DrawLine($grid, $rect.Left, $y, $rect.Right, $y)
        }
        $grid.Dispose()

        $edge = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 150, 160, 172)), 3
        $g.DrawRectangle($edge, $rect)
        $edge.Dispose()

        # Connections, drawn on the tile the prototype names, so the picture answers "where does the
        # pipe go" directly rather than decoratively.
        $font = New-MockupFont -Size 9
        foreach ($c in $Machine.Connections) {
            $cx = ($c.X + ($Machine.Width  - 1) / 2.0) * $PIXELS_PER_TILE
            $cy = ($c.Y + ($Machine.Height - 1) / 2.0) * $PIXELS_PER_TILE
            $mark = New-Object System.Drawing.Rectangle(
                [int]($cx + $PIXELS_PER_TILE * 0.18), [int]($cy + $PIXELS_PER_TILE * 0.18),
                [int]($PIXELS_PER_TILE * 0.64),       [int]($PIXELS_PER_TILE * 0.64))

            $brush = New-Object System.Drawing.SolidBrush $KIND_COLOUR[$c.Kind]
            $g.FillRectangle($brush, $mark)
            $brush.Dispose()

            $ring = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 20, 22, 26)), 2
            $g.DrawRectangle($ring, $mark)
            $ring.Dispose()

            $size = $g.MeasureString($c.Text, $font)
            $tx = $mark.Left + ($mark.Width - $size.Width) / 2
            $ty = $mark.Bottom + 2
            if ($ty + $size.Height -gt $rect.Bottom) { $ty = $mark.Top - $size.Height - 2 }
            $ink = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 225, 232, 240))
            $g.DrawString($c.Text, $font, $ink, $tx, $ty)
            $ink.Dispose()
        }
        $font.Dispose()

        # The name, centred, sized to the narrow dimension -- and dropped entirely below three tiles,
        # which is what "if space allows" has to mean.
        $shortest = [Math]::Min($Machine.Width, $Machine.Height)
        if ($shortest -ge 3) {
            $nameFont = New-MockupFont -Size ([single][Math]::Min(22, 7 + 3 * $shortest))
            $fmt = New-Object System.Drawing.StringFormat
            $fmt.Alignment     = [System.Drawing.StringAlignment]::Center
            $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
            $ink = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 232, 238, 245))
            $box = New-Object System.Drawing.RectangleF($rect.X, $rect.Y, $rect.Width, $rect.Height)
            $g.DrawString($Machine.Label, $nameFont, $ink, $box, $fmt)
            $ink.Dispose(); $fmt.Dispose(); $nameFont.Dispose()
        }

        $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $g.Dispose(); $bmp.Dispose() }
}

# THE ENGINE ROTATES NOTHING, and the connections rotate anyway. That is the whole reason this is
# more than one sheet per machine: a boiler's pipe_connections are declared in its own frame and the
# engine turns them with the entity's direction, while the picture is whatever the picture set names
# for that direction. So every direction whose connections differ needs its own drawing.
#
# THE FIRST VERSION OF THIS GOT IT WRONG and shipped art that lied. It drew one sideways sheet and
# gave it to BOTH east and west, and gave one upright sheet to both north and south. Those are four
# different rotations, not two:
#
#     north  (x,  y)      east  (-y,  x)      south  (-x, -y)      west  (y, -x)
#
# Sharing is only safe when the connections a rotation swaps are identical in kind. It is not for
# rf-heat-exchanger, where 180 degrees exchanges the energy inlet with the steam outlet, nor for the
# square machines, whose single output connection lands on a different edge every quarter turn --
# so a rotated one drew its outlet on the wrong side of the building.
#
# A generator is the exception, and only by luck: it has just two pictures, one per axis, and
# rf-direct-energy-converter's two connections are the same kind, so every rotation produces the same
# picture. If a generator ever gets connections that differ, two sheets stop being enough and the
# prototype cannot express four.
$TURNS = @(
    @{ Suffix = '';   Turn = 0 },   # north
    @{ Suffix = '-e'; Turn = 1 },   # east
    @{ Suffix = '-s'; Turn = 2 },   # south
    @{ Suffix = '-w'; Turn = 3 }    # west
)

function Get-Turned {
    param(
        [Parameter(Mandatory)] [hashtable] $Machine,
        [Parameter(Mandatory)] [int]       $Turn,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Suffix
    )
    $conns = @($Machine.Connections | ForEach-Object {
        $x = $_.X; $y = $_.Y
        switch ($Turn) {
            1 { $nx = -$y; $ny =  $x }
            2 { $nx = -$x; $ny = -$y }
            3 { $nx =  $y; $ny = -$x }
            default { $nx = $x; $ny = $y }
        }
        @{ X = $nx; Y = $ny; Kind = $_.Kind; Text = $_.Text }
    })
    $swap = ($Turn % 2) -eq 1
    return @{
        Mod = $Machine.Mod; Name = "$($Machine.Name)$Suffix"; Label = $Machine.Label
        Width  = $(if ($swap) { $Machine.Height } else { $Machine.Width })
        Height = $(if ($swap) { $Machine.Width }  else { $Machine.Height })
        Core = $false; Prototype = $Machine.Prototype
        Connections = $conns
    }
}

# A reactor's lit core, drawn over the building while it is fusing. It has to exist: a reactor whose
# "<name>-core" animation prototype is missing crashes rendering.draw_animation the first time it
# starts fusing, on a live save -- scripts/reactor-animation.lua records that. So a mockup reactor
# needs a mockup core rather than simply going without one.
#
# A bright block on transparent, sized to the middle of the building. Nothing moves: it is a single
# frame declared as an animation, which is enough to say "this is running" without pretending to
# detail that is not drawn.
function Write-MockupCore {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [int]    $Tiles
    )
    $side = $Tiles * $PIXELS_PER_TILE
    $bmp  = New-Object System.Drawing.Bitmap($side, $side)
    $g    = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.Clear([System.Drawing.Color]::Transparent)

        $inner = [int]($side * 0.38)
        $off   = [int](($side - $inner) / 2)
        $rect  = New-Object System.Drawing.Rectangle($off, $off, $inner, $inner)

        $glow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(190, 120, 220, 255))
        $g.FillRectangle($glow, $rect)
        $glow.Dispose()

        $edge = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 225, 245, 255)), 3
        $g.DrawRectangle($edge, $rect)
        $edge.Dispose()

        $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $g.Dispose(); $bmp.Dispose() }
}

foreach ($m in $MACHINES) {
    $dir = Join-Path $OutputRoot "$($m.Mod)/graphics/mockup"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null

    if ($m.Core) {
        Write-MockupCore -Path (Join-Path $dir "$($m.Name)-core.png") -Tiles $m.Width
        Write-Host ("{0,-28} core {1} x {1}" -f "$($m.Name)-core", $m.Width)
    }

    # How many faces the prototype can actually express, which is what decides how many sheets are
    # worth drawing. A boiler names four; a generator names two, one per axis; a container names one
    # and does not rotate.
    $faces = switch ($m.Prototype) {
        'boiler'    { 4 }
        'generator' { 2 }
        default     { 1 }
    }

    $variants = @()
    for ($i = 0; $i -lt $faces; $i++) {
        $variants += (Get-Turned -Machine $m -Turn $TURNS[$i].Turn -Suffix $TURNS[$i].Suffix)
    }

    foreach ($v in $variants) {
        Write-MockupSprite -Machine $v -Path (Join-Path $dir "$($v.Name).png")
        Write-MockupSprite -Machine $v -Path (Join-Path $dir "$($v.Name)-shadow.png") -Shadow
        Write-Host ("{0,-28} {1,2} x {2,-3} {3} connection(s)" -f $v.Name, $v.Width, $v.Height, $v.Connections.Count)
    }
}

Write-Host ''
Write-Host 'Mockups written. They are placeholders: see the header, and #108.'
