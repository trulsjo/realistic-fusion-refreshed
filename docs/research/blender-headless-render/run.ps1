<#
.SYNOPSIS
Runs the headless-render experiment for issue #243 end to end.
.DESCRIPTION
Finds blender.exe (the 5.2 LTS portable unzip is not on PATH), builds the test scene,
renders the passes and the icon, and reports what came out. Exit 0 means it ran, not
that the pictures are right: read the report. This is a probe, not a gate.
.PARAMETER Out
Directory for the .blend and the PNGs. Defaults to a scratch directory under $env:TEMP.
.PARAMETER Samples
Cycles samples. 16 is enough to see the passes; it is not a quality setting.
.PARAMETER Directions
How many 90-degree rig rotations to render (1..4).
.PARAMETER Denoise
Turn on Cycles denoising (OpenImageDenoise). Off by default so the raw pass is visible.
.PARAMETER Blender
Path to blender.exe. Found automatically when omitted.
#>
param(
    [string]$Out = (Join-Path $env:TEMP "rf-blender-243"),
    [int]$Samples = 16,
    [int]$Directions = 1,
    [switch]$Denoise,
    [string]$Blender
)
$ErrorActionPreference = "Stop"
if (-not $Blender) {
    $candidates = @(
        (Get-Process blender -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Path),
        "$env:USERPROFILE\Downloads\blender-5.2.0-windows-x64\blender.exe",
        "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }
    if (-not $candidates) { throw "blender.exe not found; pass -Blender" }
    $Blender = $candidates[0]
}
$here = $PSScriptRoot
New-Item -ItemType Directory -Force $Out | Out-Null
$blend = Join-Path $Out "scene.blend"
& $Blender -b --python-exit-code 1 --python (Join-Path $here "build_scene.py") -- $blend
if ($LASTEXITCODE) { throw "build failed" }
& $Blender -b $blend --python-exit-code 1 --python (Join-Path $here "render_passes.py") -- $Out $Samples $Directions $(if ($Denoise) { "denoise" } else { "raw" })
if ($LASTEXITCODE) { throw "render failed" }
& $Blender -b --python-exit-code 1 --python (Join-Path $here "verify_pngs.py") -- $Out
