extends SceneTree

const DIR := "res://assets/people/katcho/"
const JOBS := [
	["henry/HenryTexture512.png", "henry/var_a.png", 175.0, 0.35, Color(0.55, 0.62, 0.75), 0.45],
	["henry/HenryTexture512.png", "henry/var_b.png", 0.0, 0.12, Color(0.75, 0.35, 0.3), 0.4],
	["mob01/mob01.png", "mob01/var_a.png", 170.0, 0.9, Color(0.9, 0.9, 0.9), 0.0],
	["mob01/mob01.png", "mob01/var_b.png", -55.0, 0.6, Color(0.9, 0.9, 0.9), 0.0],
	["johndoe/paintSkin.png", "johndoe/var_a.png", 170.0, 0.7, Color(0.3, 0.38, 0.55), 0.5],
	["johndoe/paintSkin.png", "johndoe/var_b.png", 60.0, 0.5, Color(0.55, 0.2, 0.18), 0.45],
	["office_m/male_z01.png", "office_m/var_a.png", 150.0, 0.6, Color(0.6, 0.72, 0.9), 0.35],
	["office_m/male_z01.png", "office_m/var_b.png", 40.0, 0.4, Color(0.9, 0.85, 0.7), 0.3],
	["granny/granny.png", "granny/var_a.png", 130.0, 1.0, Color(0.8, 0.7, 0.85), 0.3],
	["gramps/gramps.png", "gramps/var_a.png", -140.0, 0.8, Color(0.7, 0.75, 0.85), 0.3],
]


func _skin(c: Color) -> bool:
	var h := c.h * 360.0
	return (h >= 345.0 or h <= 50.0) and c.s >= 0.15 and c.v >= 0.12


func _init() -> void:
	for j in JOBS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + j[0]))
		img.convert(Image.FORMAT_RGBA8)
		var hue: float = j[2] / 360.0
		var sat: float = j[3]
		var tint: Color = j[4]
		var tk: float = j[5]
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if _skin(c):
					continue
				if c.s < 0.14:
					if c.v > 0.12 and tk > 0.0:
						var t := c * tint
						c = Color(lerpf(c.r, t.r, tk), lerpf(c.g, t.g, tk), lerpf(c.b, t.b, tk), c.a)
				else:
					c = Color.from_hsv(fposmod(c.h + hue, 1.0), clampf(c.s * sat, 0.0, 1.0), c.v, c.a)
				img.set_pixel(x, y, c)
		img.save_png(ProjectSettings.globalize_path(DIR + j[1]))
		print("wrote ", j[1])
	quit()
