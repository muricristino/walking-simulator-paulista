---
name: ps1-city
description: Build a PS1-style walk through a real street in Godot 4 — real map data from OpenStreetMap, street relief from public contour lines, Street View captures as modeling reference, textures painted in code, and the PlayStation 1 look (vertex snapping, affine textures, low resolution, dithering). Use when someone asks to make a walking simulator, a PS1/retro 3D scene of a real place, or "something like Paulista PS1".
---

# PS1 city walk in Godot

This is how [Paulista PS1](https://github.com/muricristino/walking-simulator-paulista) was built in one night with Claude Code. Every step points to a file in this repo you can copy.

## 1. The look first

The PS1 look is three things, and all of them are cheap:

1. **Low internal resolution.** Set the project viewport to 640×480 (`project.godot`) and let the window stretch it with nearest filtering.
2. **The material shader** — [`scripts/ps1.gdshader`](../../scripts/ps1.gdshader):
   - *vertex snapping*: snap the clip-space position to a coarse grid (`snap_res`, 400×300) so vertices wobble as the camera moves;
   - *affine texture mapping*: interpolate UVs without perspective correction (`affine` = 0.6 mixes it with the correct UV so walls warp but stay readable);
   - `filter_nearest` on every texture, `ROUGHNESS = 1.0`, no specular.
3. **The screen shader** — [`scripts/screen.gdshader`](../../scripts/screen.gdshader): posterize to ~24 levels per channel with a 4×4 Bayer dither, plus a small saturation boost. Add fog and a gradient sky ([`scripts/sky.gdshader`](../../scripts/sky.gdshader)).

Get these three on a single gray cube before modeling anything. If the cube already looks like 1998, the rest follows.

## 2. The map comes from data, not from your hands

- **Buildings**: export the area from OpenStreetMap (Overpass) and extrude each footprint by `height` or `building:levels × 3.2 m + 2 m` — [`tools/osm_to_game.py`](../../tools/osm_to_game.py), loaded in game by [`scripts/osm_city.gd`](../../scripts/osm_city.gd). Cross streets land in the right place for free.
- **Relief**: a sloped street needs real heights. São Paulo publishes 1 m contour lines (GeoSampa); [`tools/rc_geosampa.py`](../../tools/rc_geosampa.py) turns them into a height profile for the ground mesh. Use your city's equivalent.
- Keep a single geo origin and convert lat/lon to meters in one place — [`scripts/geo.gd`](../../scripts/geo.gd).

## 3. Street View is a reference, not a texture

Walk the street in Street View with Playwright and save a capture every ~30 m. Use them to count trees, place the newsstand, pick each façade color. Do not put them in the game (license, and they would look wrong in PS1 anyway).

## 4. Textures painted in code

Where no asset pack fits, generate the texture:

- in Godot at runtime — [`scripts/tex.gd`](../../scripts/tex.gd): a base color, simplex noise for stains, per-pixel grain, small sizes (64–256 px) so `filter_nearest` reads as PS1;
- in Python for baked assets — [`tools/blender/rc_textures.py`](../../tools/blender/rc_textures.py) (numpy → PNG: sidewalk tiles, plaster, asphalt);
- façades from a photo pack, posterized and recolored with ImageMagick — [`tools/make_facades.py`](../../tools/make_facades.py).

Blender modeling by script (no clicking): [`tools/blender/`](../../tools/blender/) builds the street, the calçadão and the houses, and exports glTF.

## 5. Life on the street

Traffic with traffic lights ([`scripts/traffic.gd`](../../scripts/traffic.gd), [`scripts/traffic_light.gd`](../../scripts/traffic_light.gd)), pedestrians that cross on green ([`scripts/crowd.gd`](../../scripts/crowd.gd)), 3D audio and footsteps that change with the floor ([`scripts/audio_surface.gd`](../../scripts/audio_surface.gd)). CC0/CC BY packs for people and cars are listed in [CREDITS.md](../../CREDITS.md).

## 6. Let agents check it

- Take screenshots without opening the editor: [`tools/shot.sh`](../../tools/shot.sh) runs the scene offscreen and saves a PNG — the agent can look at its own work.
- At the end, one agent plays the game and lists what is broken; one agent per area (traffic, crowd, audio, player, avenue, street, menus) fixes its list in parallel.

## Checklist

- [ ] PS1 shaders on a test cube look right at 640×480
- [ ] OSM buildings in place, heights real
- [ ] ground follows real relief
- [ ] one reference capture per 30 m of street
- [ ] every texture ≤ 256 px, nearest filter
- [ ] offscreen screenshot script working before the first agent
- [ ] credits file for every third-party asset
