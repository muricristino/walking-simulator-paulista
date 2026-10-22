extends RefCounted

static var rng := RandomNumberGenerator.new()


static func _noise(seed: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_octaves = 3
	return n


static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func _grain(c: Color, amount: float) -> Color:
	var g := rng.randf_range(-amount, amount)
	return Color(clampf(c.r + g, 0, 1), clampf(c.g + g, 0, 1), clampf(c.b + g, 0, 1))


static func flat(base: Color, size: int, grain: float, stain: float, seed: int) -> ImageTexture:
	rng.seed = seed
	var n := _noise(seed, 0.12)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var c := base.darkened(maxf(n.get_noise_2d(x, y), 0.0) * stain)
			c = c.lightened(maxf(-n.get_noise_2d(x + 40, y), 0.0) * stain * 0.4)
			img.set_pixel(x, y, _grain(c, grain))
	return _tex(img)


static func asphalt(seed: int) -> ImageTexture:
	rng.seed = seed
	var n := _noise(seed, 0.08)
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			var v := 0.17 + n.get_noise_2d(x, y) * 0.04
			if rng.randf() < 0.08:
				v += 0.07
			var c := Color(v, v * 0.98, v * 1.03)
			img.set_pixel(x, y, _grain(c, 0.02))
	return _tex(img)


static func mosaic(seed: int) -> ImageTexture:
	rng.seed = seed
	var shape := PackedVector2Array([
		Vector2(0.05, 0.42), Vector2(0.2, 0.22), Vector2(0.38, 0.3), Vector2(0.55, 0.12),
		Vector2(0.78, 0.2), Vector2(0.95, 0.45), Vector2(0.8, 0.62), Vector2(0.62, 0.58),
		Vector2(0.5, 0.82), Vector2(0.3, 0.7), Vector2(0.15, 0.6)])
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	for y in s:
		for x in s:
			var black := false
			for oy in [-1, 0, 1]:
				for ox in [-1, 0, 1]:
					var shift := 0.5 if (oy % 2) != 0 else 0.0
					var p := Vector2(float(x) / s - ox - shift, float(y) / s - oy)
					if Geometry2D.is_point_in_polygon(p, shape):
						black = true
			var stone := rng.randf_range(-0.06, 0.06)
			var c := Color(0.13, 0.12, 0.12) if black else Color(0.78, 0.76, 0.72)
			if (x + y * 3) % 5 == 0:
				c = c.darkened(0.15)
			img.set_pixel(x, y, Color(c.r + stone, c.g + stone, c.b + stone))
	return _tex(img)


static func stripes(a: Color, b: Color, w: int, h: int, band: int, seed: int) -> ImageTexture:
	rng.seed = seed
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var c := a if (y / band) % 2 == 0 else b
			img.set_pixel(x, y, _grain(c, 0.04))
	return _tex(img)


static func leaves(seed: int, base: Color) -> ImageTexture:
	rng.seed = seed
	var n := _noise(seed, 0.3)
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		for x in 16:
			var v := n.get_noise_2d(x, y)
			var c := base.lightened(maxf(v, 0.0) * 0.5).darkened(maxf(-v, 0.0) * 0.6)
			img.set_pixel(x, y, _grain(c, 0.05))
	return _tex(img)


static func facade(seed: int, cols: int, rows: int, style: int, wall: Color, glass: Color, lit: float) -> Array:
	rng.seed = seed
	var bw := 4
	var fh := 4
	var w := cols * bw
	var h := rows * fh
	var n := _noise(seed, 0.05)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var gl := Image.create(w, h, false, Image.FORMAT_RGB8)
	gl.fill(Color.BLACK)
	var floor_lit := []
	for r in rows:
		floor_lit.append(rng.randf() < lit)
	var warm := [Color(1.0, 0.86, 0.55), Color(0.95, 0.95, 0.85), Color(0.75, 0.88, 1.0)]
	var floor_col := []
	for r in rows:
		floor_col.append(warm[rng.randi() % warm.size()])
	for y in h:
		for x in w:
			var r := y / fh
			var cx := x % bw
			var cy := y % fh
			var dirt := n.get_noise_2d(x, y) * 0.08
			var is_win := false
			match style:
				0:
					is_win = cx != 0 and cy != 0
				1:
					is_win = cy >= 2
				2:
					is_win = cx >= 1 and cx <= 2 and cy >= 1 and cy <= 2
				3:
					is_win = cy != 0
			var c: Color
			if is_win:
				var refl := 1.0 - float(y) / h * 0.5
				c = glass * (0.7 + refl * 0.5)
				c = c.lightened(clampf(dirt, 0, 1))
				var bay_on: bool = floor_lit[r] and rng.randf() < 0.85
				if not floor_lit[r] and rng.randf() < 0.06:
					bay_on = true
				if bay_on:
					var lc: Color = floor_col[r]
					c = c.lerp(lc, 0.55)
					gl.set_pixel(x, y, lc * rng.randf_range(0.55, 0.9))
			else:
				c = wall.darkened(clampf(dirt + float(y) / h * 0.1, 0, 1))
			img.set_pixel(x, y, _grain(c, 0.03))
	return [_tex(img), _tex(gl)]


static func masp_glass(seed: int) -> Array:
	rng.seed = seed
	var w := 64
	var h := 16
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var gl := Image.create(w, h, false, Image.FORMAT_RGB8)
	gl.fill(Color.BLACK)
	for y in h:
		for x in w:
			var c := Color(0.1, 0.12, 0.13)
			if x % 3 == 0 or y == 0 or y == 8 or y == h - 1:
				c = Color(0.2, 0.2, 0.22)
			elif (y > 2 and y < 7) or (y > 10 and y < 15):
				if rng.randf() < 0.3:
					var lc := Color(1.0, 0.92, 0.75) * rng.randf_range(0.4, 0.7)
					gl.set_pixel(x, y, lc)
					c = c.lerp(lc, 0.5)
			img.set_pixel(x, y, _grain(c, 0.02))
	return [_tex(img), _tex(gl)]


static func plate(path: String) -> ImageTexture:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return _tex(img)


static func magazines(seed: int) -> ImageTexture:
	rng.seed = seed
	var img := Image.create(48, 20, false, Image.FORMAT_RGB8)
	img.fill(Color(0.85, 0.85, 0.8))
	for row in 4:
		var x := 0
		while x < 48:
			var w := rng.randi_range(3, 5)
			var c := Color.from_hsv(rng.randf(), rng.randf_range(0.4, 0.9), rng.randf_range(0.5, 1.0))
			for yy in range(row * 5, row * 5 + 4):
				for xx in range(x, mini(x + w - 1, 48)):
					img.set_pixel(xx, yy, _grain(c, 0.08))
			x += w
	return _tex(img)
