"""Shared helpers for the headless-render experiment (issue #243).

Written outside Blender and imported by the scripts beside it from inside Blender's
bundled Python 3.13. Blender does NOT put the --python script's directory on sys.path,
so every script that imports this does
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
first. Verified against Blender 5.2.0 LTS on 2026-09-04.
"""
import sys

PX_PER_TILE = 64  # Factorio high-resolution sprites: 64 px per tile (32 at normal)


def script_args():
    """Arguments after '--' on the blender command line. Blender leaves sys.argv whole."""
    argv = sys.argv
    return argv[argv.index("--") + 1:] if "--" in argv else []


def set_frame(scene, camera, tiles_w, tiles_h, margin_tiles=1.0, px_per_tile=PX_PER_TILE):
    """Size the output from a footprint in tiles.

    One Blender unit is one tile. An orthographic camera's ortho_scale is the world-space
    width of the LONGER frame side, so with the resolution set from the same tile count
    the scale is pixel-exact: px_per_tile pixels per tile along the ground's own axis.
    The tilted axis foreshortens by the camera pitch; that is the sibling camera ticket's
    business and is NOT corrected here.
    """
    w = tiles_w + 2 * margin_tiles
    h = tiles_h + 2 * margin_tiles
    scene.render.resolution_x = int(round(w * px_per_tile))
    scene.render.resolution_y = int(round(h * px_per_tile))
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = scene.render.pixel_aspect_y = 1.0
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = max(w, h)
    return scene.render.resolution_x, scene.render.resolution_y


def png_rgba(image_settings):
    """5.x: media_type must be set before file_format (5.0 Python API release notes)."""
    image_settings.media_type = "IMAGE"
    image_settings.file_format = "PNG"
    image_settings.color_mode = "RGBA"
    image_settings.color_depth = "8"
