# City Look

A PS1-style first-person walk through São Paulo: Avenida Paulista by MASP and up Alameda Rio Claro, built in Godot from real map data.

![Avenida Paulista at dusk, with MASP on the left and the sign to Alameda Rio Claro](docs/screenshot.png)

- **Real streets.** Building footprints and heights come from OpenStreetMap, street relief from GeoSampa's 1 m contour lines, and Alameda Rio Claro is modeled in Blender on top of them.
- **PS1 look.** 640×480 internal resolution, vertex snapping, affine textures, posterized photo textures and fog.
- **A living street.** Traffic with traffic lights, pedestrians on crosswalks and sidewalks, a standing crowd, and 3D audio for the city, cars and footsteps.

## Run

Open the folder in [Godot 4.7](https://godotengine.org) and press Play, or:

```
godot --path . res://main.tscn
```

| Key | Action |
|---|---|
| W A S D | Walk |
| Mouse | Look |
| Shift | Hold to run, double tap and hold to sprint |
| Space | Jump |
| E | Phone |
| Esc | Menu |

## Layout

- `main.tscn`, `scripts/`: the game (city, traffic, crowd, player, audio, PS1 shaders)
- `assets/`: models, textures, map data and audio
- `lab/`: small scenes to look at buildings, cars, people, props and roads on their own
- `tools/`: the scripts that build the assets: OpenStreetMap and GeoSampa import, Blender models, facade textures, audio, and offscreen screenshots (`tools/shot.sh`)

## Credits

Every third-party asset and its license is listed in [CREDITS.md](CREDITS.md). Map data © OpenStreetMap contributors (ODbL 1.0) and GeoSampa, Prefeitura de São Paulo.
