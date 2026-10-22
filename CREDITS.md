# Credits

## Free Characters (assets/people/katcho)
- Author: Katcho (https://katcho.itch.io/)
- Source: https://katcho.itch.io/free-characters
- License: CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/)
- Used: Henry, mob01, beggar (Mr Grease, both textures), Granny, Gramps, JohnDoe (Hehe folder; paintSkin, paintSkin03), female_z with the six clean female_base_00x skins (female_zombies folder), male_z with male_z01 (male_zombie folder), Nanzy (Popcorn folder)
- The zombie walk/idle clips are not used: female_z, male_z and the phone pose get animations retargeted at load from Nanzy and mob01 (scripts/katcho.gd)
- var_*.png: recolored clothing variants of the textures above, made by tools/people_variants.gd
- skin.json: bind poses read from the .dae files by tools/katcho_skin.py

## PS2 Styled Characters (assets/people/wobble)
- Author: Wobble Blocks (@WobbleBlocks)
- Source: https://opengameart.org/node/183199
- License: CC0 1.0
- Used: PS2CharacterBase.fbx (textures embedded in the FBX)

## Road textures (assets/road)
- Source: ambientCG (https://ambientcg.com), License: CC0 1.0
- a_*.png: Asphalt015 (https://ambientcg.com/view?id=Asphalt015)
- b_*.png: Asphalt019 (https://ambientcg.com/view?id=Asphalt019)
- c_*.png: Asphalt026C (https://ambientcg.com/view?id=Asphalt026C)
- paint_white.png, paint_yellow.png: RoadLines020A (https://ambientcg.com/view?id=RoadLines020A)
- bike_red.png: tinted from Asphalt015
- sidewalk_dark.png, sidewalk_light.png, tactile.png: Paulista cast-in-place concrete plates (post-2008 standard), built from ambientCG Concrete017 (https://ambientcg.com/view?id=Concrete017), CC0 1.0: downscaled to 64 px, desaturated, posterized, joints and tactile ridges drawn locally
- onibus.png, bike_symbol.png: road stencils drawn locally with ImageMagick (Arial Narrow Bold)
- Downscaled to 64/128/256 px, brightness matched, palette posterized

## Street props (assets/props)
- loafbrr/: "Lamp Post Bench TrashCan" by Loafbrr (https://loafbrr.itch.io/lamp-post-bench-trashcan), CC0 1.0. Bench, TrashCan, LampPost_1; textures downscaled, trash can recolored orange, pole desaturated
- bark.png: ambientCG Bark004 (https://ambientcg.com/view?id=Bark004), CC0 1.0
- canopy.png: leaves cut from ambientCG LeafSet026 (https://ambientcg.com/view?id=LeafSet026), CC0 1.0
- shutter.png: ambientCG CorrugatedSteel005 (https://ambientcg.com/view?id=CorrugatedSteel005), CC0 1.0
- concrete.png and shop sign backgrounds: ambientCG Concrete034 (https://ambientcg.com/view?id=Concrete034), CC0 1.0
- window.png: crop of ambientCG Facade009 (https://ambientcg.com/view?id=Facade009), CC0 1.0
- facade_upper.png: crop of ambientCG Facade013 (https://ambientcg.com/view?id=Facade013), CC0 1.0
- sign0-3.png: generic shop names drawn locally over the concrete photo
- signs/*.png: São Paulo street name plates (blue) and brown wayfinding plates drawn locally with ImageMagick (Arial Narrow Bold); street names and positions from OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0)

## Buildings (assets/osm, assets/buildings)
- Footprints and heights: © OpenStreetMap contributors, ODbL 1.0 (https://www.openstreetmap.org/copyright), fetched via Overpass API and converted by tools/osm_to_game.py
- Common facades a0xx_*.png from ambientCG (CC0 1.0, https://ambientcg.com): Facade001-006, 012-015, 017, 018A/B, 019A/B, 020A/B with their emission maps where available; other night masks generated locally
- p_*.png, e_*.png: built from "Panelka Pack" by kureca (https://kureca.itch.io/panelka-pack), CC0 1.0: II-68 facade, Panel1-6 windows, Bricks1, BrickWall1, WallTiles, WhiteBricks, Concrete1, Panel1Edge
- t_*.png (ground floors): composed from the props textures above and ambientCG Facade006
- Built by tools/make_facades.py
- Landmark photos from Wikimedia Commons, cropped, downscaled and posterized:
  - conjunto_c.png (also the common 'conjunto' style): "Facade of the Conjunto Nacional cropped version.jpg" by Wilfredor, CC0, https://commons.wikimedia.org/wiki/File:Facade_of_the_Conjunto_Nacional_cropped_version.jpg
  - fiesp_c.png: "FIESP building 52.jpg" by Mauro Cateb, CC BY-SA 4.0, https://commons.wikimedia.org/wiki/File:FIESP_building_52.jpg
  - gazeta_c.png: "Imagem da Fundação Cásper Líbero - Gazeta.JPG" by Paulo De Sá Machado, CC BY-SA 4.0, https://commons.wikimedia.org/wiki/File:Imagem_da_Funda%C3%A7%C3%A3o_C%C3%A1sper_L%C3%ADbero_-_Gazeta.JPG
  - safra_c.png: "Banco Safra na Avenida Paulista 1.JPG" by Joehawkins, CC BY-SA 4.0, https://commons.wikimedia.org/wiki/File:Banco_Safra_na_Avenida_Paulista_1.JPG
  - center3_c.png: "Shopping Center 3.JPG" by Raphael Igor, CC BY-SA 3.0, https://commons.wikimedia.org/wiki/File:Shopping_Center_3.JPG

## Alameda Rio Claro (assets/osm/rioclaro.json)
- Street, cross streets, buildings and points of interest: © OpenStreetMap contributors, ODbL 1.0, via Overpass API, converted by tools/osm_rioclaro.py
- Elevation: Mapzen/AWS Terrain Tiles (terrarium, zoom 15, https://registry.opendata.aws/terrain-tiles/), derived from SRTM and other public sources; see https://github.com/tilezen/joerd/blob/master/docs/attribution.md
- art/placa_rioclaro.png: drawn locally in the style of the São Paulo street sign

## Alameda Rio Claro models (assets/rioclaro)
- Modeled in Blender by tools/blender/rc_calcadao.py and tools/blender/rc_rua.py, positioned on the OpenStreetMap footprints above (© OpenStreetMap contributors, ODbL 1.0); shapes and materials eyeballed from street-level photos, which are not used as textures
- Street relief: terrain tiles above, smoothed by tools/rc_relief.py
- tex/*.png: painted procedurally by tools/blender/rc_textures.py (herringbone pavers, wood deck, copper slats, granite, glass, panels, concrete, fences, graffiti wall, casarão facade, roof tiles, residential facades, cars, leaves, plane-tree bark), except:
  - asphalt.png: copy of assets/road/b_128.png (ambientCG Asphalt019, CC0 1.0)
  - bark.png: copy of assets/props/bark.png (ambientCG Bark004, CC0 1.0)
  - placa_*.png and banca_sign.png: text drawn locally with ImageMagick and system fonts (Arial Narrow Bold, Times New Roman Bold)
  - bark_ficus.png: ambientCG Bark012 (https://ambientcg.com/view?id=Bark012), CC0 1.0, downscaled and darkened

## Suspicious Car (assets/cars/moidev)
- Author: MoiDev (https://moi0210.itch.io/)
- Source: https://moi0210.itch.io/a-suspicious-car-for-your-projects
- License: CC0 1.0
- Used: Suspicious Car.obj (renamed sedan.obj) and its 6 color textures; front plate repainted as Mercosul

## PSX Style Cars (assets/cars/ggbot)
- Author: GGBotNet (https://ggbot.itch.io/)
- Source: https://ggbot.itch.io/psx-style-cars
- License: CC0 1.0
- Used: Car 02, Car 03, Car 05, Car 05 Taxi, Wheel (OBJ + PNG)

## German PSX Car (assets/cars/sunfl0w)
- "GermanCar" by Luca Anthony Schwarz (sunfl0w, https://sunfl0w.itch.io/)
- Source: https://sunfl0w.itch.io/german-psx-car
- License: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)
- Used: GermanCar.fbx, GermanCarTexture.png

## UI fonts (assets/ui)
- Press Start 2P by CodeMan38 (https://fonts.google.com/specimen/Press+Start+2P), SIL Open Font License 1.1 (assets/ui/OFL-PressStart2P.txt). Used: title
- Silkscreen by Jason Kottke (https://fonts.google.com/specimen/Silkscreen), SIL Open Font License 1.1 (assets/ui/OFL-Silkscreen.txt). Used: buttons, compass, labels
- VT323 by Peter Hull (https://fonts.google.com/specimen/VT323), SIL Open Font License 1.1 (assets/ui/OFL-VT323.txt). Used: body text
