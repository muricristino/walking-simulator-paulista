extends RefCounted

const PS1 := preload("res://scripts/ps1.gdshader")
const TS := 256.0

const RG := {
	"head": Rect2i(0, 0, 128, 96),
	"torso": Rect2i(128, 0, 128, 128),
	"uarm": Rect2i(0, 96, 48, 64),
	"farm": Rect2i(48, 96, 48, 64),
	"hand": Rect2i(96, 96, 32, 48),
	"thigh": Rect2i(0, 160, 64, 96),
	"shin": Rect2i(64, 160, 64, 96),
	"foot": Rect2i(128, 128, 64, 48),
	"bun": Rect2i(192, 128, 32, 32),
	"shadow": Rect2i(224, 128, 8, 8),
}

const SKIN := [Color(0.9, 0.7, 0.58), Color(0.82, 0.6, 0.46), Color(0.72, 0.5, 0.36), Color(0.58, 0.39, 0.27), Color(0.43, 0.28, 0.19), Color(0.32, 0.21, 0.15)]
const HAIR := [Color(0.07, 0.06, 0.05), Color(0.17, 0.11, 0.07), Color(0.32, 0.21, 0.12), Color(0.66, 0.52, 0.3), Color(0.5, 0.48, 0.46), Color(0.42, 0.16, 0.08)]
const CLOTH := [Color(0.33, 0.4, 0.17), Color(0.62, 0.12, 0.1), Color(0.15, 0.2, 0.38), Color(0.8, 0.8, 0.76), Color(0.1, 0.1, 0.11), Color(0.75, 0.55, 0.15), Color(0.42, 0.42, 0.45), Color(0.45, 0.25, 0.42), Color(0.2, 0.38, 0.45), Color(0.6, 0.35, 0.2)]
const SUIT := [Color(0.1, 0.11, 0.13), Color(0.17, 0.19, 0.27), Color(0.3, 0.3, 0.31), Color(0.25, 0.2, 0.15)]
const JEANS := [Color(0.38, 0.5, 0.66), Color(0.24, 0.32, 0.5), Color(0.17, 0.22, 0.36)]

var rng := RandomNumberGenerator.new()
var img: Image
var nlo := FastNoiseLite.new()
var nhi := FastNoiseLite.new()
var nfold := FastNoiseLite.new()
var cache := {}
var shadow_mesh: ArrayMesh


class MB:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

	func mesh(m: Material) -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(0, m)
		return am


func _uvp(reg: Rect2i, u: float, t: float) -> Vector2:
	return Vector2(reg.position.x + 0.5 + u * (reg.size.x - 1.0), reg.position.y + 0.5 + t * (reg.size.y - 1.0)) / TS


func _loft(mb: MB, rings: Array, sides: int, reg: Rect2i, along_z := false, cap0 := 0.0, cap1 := 0.0, off := Vector3.ZERO) -> void:
	var base := mb.v.size()
	var nr := rings.size()
	var s0: float = rings[0][0]
	var s1: float = rings[nr - 1][0]
	var acc := []
	acc.resize(nr * sides)
	for i in acc.size():
		acc[i] = Vector3.ZERO
	var pts := []
	for i in nr:
		var r: Array = rings[i]
		var push: float = r[4] if r.size() > 4 else 0.0
		var row := []
		for j in sides + 1:
			var a := (float(j) / sides - 0.5) * TAU
			var fp := push * pow(maxf(cos(a), 0.0), 6.0)
			var p: Vector3
			if along_z:
				p = Vector3(-r[1] * sin(a), r[3] + r[2] * cos(a) + fp, r[0])
			else:
				p = Vector3(-r[1] * sin(a), r[0], r[3] - r[2] * cos(a) - fp)
			row.append(p + off)
		pts.append(row)
	var center := func(i: int) -> Vector3:
		var r: Array = rings[i]
		return (Vector3(0, r[3], r[0]) if along_z else Vector3(0, r[0], r[3])) + off
	for i in nr - 1:
		for j in sides:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][j + 1]
			var c: Vector3 = pts[i + 1][j + 1]
			var d: Vector3 = pts[i + 1][j]
			var fn := (b - a).cross(d - a)
			if fn.length() < 1e-9:
				fn = (c - b).cross(a - b)
			var mid: Vector3 = (a + b + c + d) * 0.25
			var cen: Vector3 = (center.call(i) + center.call(i + 1)) * 0.5
			if fn.dot(mid - cen) < 0.0:
				fn = -fn
			fn = fn.normalized()
			for k in [[i, j], [i, j + 1], [i + 1, j + 1], [i + 1, j]]:
				acc[k[0] * sides + (k[1] % sides)] += fn
	var axis := Vector3.BACK if along_z else Vector3.DOWN
	for i in nr:
		var r: Array = rings[i]
		var t: float = (r[0] - s0) / (s1 - s0) if s1 != s0 else 0.0
		for j in sides + 1:
			var nn: Vector3 = acc[i * sides + (j % sides)]
			if (i == 0 and cap0 != 0.0):
				nn += -axis * 0.6 * nn.length()
			if (i == nr - 1 and cap1 != 0.0):
				nn += axis * 0.6 * nn.length()
			mb.v.append(pts[i][j])
			mb.n.append(nn.normalized())
			mb.uv.append(_uvp(reg, float(j) / sides, t))
	var w := sides + 1
	for i in nr - 1:
		for j in sides:
			var a := base + i * w + j
			var b := a + 1
			var c := a + w + 1
			var d := a + w
			mb.idx.append_array([a, b, c, a, c, d])
	for e in [[0, cap0, -axis, 0.0], [nr - 1, cap1, axis, 1.0]]:
		if e[1] == 0.0:
			continue
		var ci := mb.v.size()
		mb.v.append(center.call(e[0]) + e[2] * e[1])
		mb.n.append(e[2])
		mb.uv.append(_uvp(reg, 0.5, e[3]))
		for j in sides:
			var a: int = base + e[0] * w + j
			mb.idx.append_array([ci, a, a + 1])


func _mat(tex: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("tint", Color.WHITE)
	m.set_shader_parameter("affine", 0.25)
	return m


func _pick(list: Array) -> Variant:
	return list[rng.randi() % list.size()]


func describe(seed: int) -> Dictionary:
	rng.seed = seed
	var d := {}
	d.skin = _pick(SKIN)
	d.hair_c = _pick(HAIR)
	d.fem = rng.randf() < 0.4
	d.hair = _pick(["bob", "bun", "long"]) if d.fem else _pick(["short", "short", "buzz", "bald", "beanie", "short"])
	d.top = _pick(["tshirt", "hoodie", "shirt", "tshirt"]) if d.fem else _pick(["tshirt", "hoodie", "shirt", "suit", "tshirt"])
	d.bottom = _pick(["jeans", "jeans", "black", "khaki"])
	if d.top == "suit":
		d.bottom = "suit"
	d.c1 = _pick(CLOTH)
	d.c2 = _pick(CLOTH)
	d.suit = _pick(SUIT)
	d.jeans = _pick(JEANS)
	d.shoe = _pick(["sneaker", "sneaker", "black", "brown"])
	if d.bottom == "suit":
		d.shoe = "black"
	d.beard = 0.0 if d.fem else _pick([0.0, 0.25, 0.5, 0.85])
	d.mustache = not d.fem and rng.randf() < 0.3
	d.print = rng.randf() < 0.6
	d.hs = rng.randf_range(0.93, 1.05) * (0.95 if d.fem else 1.0)
	d.ws = rng.randf_range(0.94, 1.12)
	d.seed = seed
	return d


func _g(x: float, y: float, cx: float, cy: float, sx: float, sy: float) -> float:
	var dx := (x - cx) / sx
	var dy := (y - cy) / sy
	return exp(-(dx * dx + dy * dy))


func _ss(e0: float, e1: float, x: float) -> float:
	return smoothstep(e0, e1, x)


func _paint_region(reg: Rect2i, y0: float, y1: float, f: Callable) -> void:
	for py in reg.size.y:
		var t := (py + 0.5) / reg.size.y
		var y := lerpf(y0, y1, t)
		for px in reg.size.x:
			var a := ((px + 0.5) / reg.size.x - 0.5) * TAU
			var X := reg.position.x + px
			var Y := reg.position.y + py
			var c: Color = f.call(a, y, X, Y, t)
			img.set_pixel(X, Y, Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1)))


func _skin(d: Dictionary, X: int, Y: int) -> Color:
	var c: Color = d.skin
	c = c * (1.0 + nlo.get_noise_2d(X * 3.0, Y * 3.0) * 0.07)
	c = c.lerp(Color(0.75, 0.35, 0.3), maxf(nlo.get_noise_2d(X * 5.0 + 90, Y * 5.0), 0.0) * 0.12)
	return c * (1.0 + nhi.get_noise_2d(X, Y) * 0.035)


func _dark(c: Color, k: float) -> Color:
	return Color(c.r * (1.0 - k), c.g * (1.0 - k), c.b * (1.0 - k))


func _light(c: Color, k: float) -> Color:
	return c.lerp(Color.WHITE, k)


func _hairline(d: Dictionary, a: float) -> float:
	var aa := absf(a)
	var front := 1.718 + nlo.get_noise_1d(a * 40.0) * 0.004
	var side := 1.665
	var back := 1.565
	if d.hair == "bob":
		side = 1.585
		back = 1.53
		front = 1.71
	elif d.hair == "long" or d.hair == "bun":
		side = 1.62
		back = 1.5
		front = 1.712
	var h := lerpf(front, side, _ss(0.75, 1.35, aa))
	h = lerpf(h, back, _ss(1.9, 2.5, aa))
	if d.hair == "short" or d.hair == "buzz":
		h -= _g(aa, 0.0, 1.42, 0.0, 0.1, 1.0) * 0.03
	return h


func _hair_px(d: Dictionary, X: int, Y: int, a: float, y: float) -> Color:
	var hc: Color = d.hair_c
	var strand := nhi.get_noise_2d(X * 0.6, Y * 2.2)
	var c := hc * (1.0 + strand * 0.35)
	c = _light(c, maxf(nlo.get_noise_2d(X * 4.0, Y * 4.0), 0.0) * 0.12)
	c = _light(c, _g(a, y, 0.0, 1.735, 0.9, 0.015) * 0.1)
	return c


func _p_head(d: Dictionary) -> Callable:
	return func(a: float, y: float, X: int, Y: int, t: float) -> Color:
		var aa := absf(a)
		var c := _skin(d, X, Y)
		var sh := 0.0
		sh += _ss(1.545, 1.515, y) * _ss(1.3, 0.3, aa) * 0.4
		sh += _g(aa, y, 0.75, 1.598, 0.22, 0.018) * 0.14
		sh -= _g(aa, y, 0.5, 1.638, 0.2, 0.01) * 0.1
		sh -= _g(aa, y, 0.0, 1.70, 0.35, 0.012) * 0.08
		sh += _ss(1.3, 2.0, aa) * 0.06
		for s in [-1.0, 1.0]:
			var da: float = a - s * 0.36
			var dy := y - 1.662
			sh += _g(da, dy, 0.0, 0.0, 0.2, 0.016) * 0.3
			sh += _g(da, dy, 0.07 * s, -0.012, 0.12, 0.006) * 0.12
		if aa < 0.14 and y > 1.6 and y < 1.665:
			sh += _ss(0.04, 0.12, aa) * 0.28 * _ss(1.665, 1.64, y)
			sh -= _ss(0.05, 0.0, aa) * 0.1
		sh += _g(aa, y, 0.0, 1.6, 0.12, 0.004) * 0.3
		for s in [-1.0, 1.0]:
			var la: float = s * lerpf(0.14, 0.24, _ss(1.605, 1.575, y))
			sh += _g(a, y, la, clampf(y, 1.575, 1.605), 0.025, 0.012) * 0.16
		c = _dark(c, clampf(sh, -0.3, 0.8))
		if aa > 1.37 and aa < 1.77 and y > 1.612 and y < 1.675:
			var ea := (aa - 1.57) / 0.2
			var ey := (y - 1.643) / 0.032
			var e := ea * ea + ey * ey
			if e < 1.0:
				c = _dark(_skin(d, X, Y), 0.12 + (0.3 if e < 0.35 else 0.0))
		var mw := 0.2
		if aa < mw:
			var k := 1.0 - (aa / mw) * (aa / mw)
			var lip := c.lerp(Color(0.55, 0.2, 0.2), 0.3 if d.fem else 0.18)
			if y > 1.584 and y < 1.584 + 0.008 * k:
				c = _dark(lip, 0.12)
			elif y > 1.574 + 0.003 * (1.0 - k) and y <= 1.584:
				c = _dark(lip, 0.55) if y > 1.581 else _light(lip, 0.05)
			elif y > 1.566 and y <= 1.574:
				c = _dark(c, 0.12 * k)
		for s in [-1.0, 1.0]:
			var da: float = a - s * 0.36
			var dy := y - 1.662
			var e := (da / 0.11) * (da / 0.11) + (dy / 0.0068) * (dy / 0.0068)
			if e < 1.0:
				c = Color(0.82, 0.78, 0.72)
				var ia := (da / 0.045) * (da / 0.045) + (dy / 0.0068) * (dy / 0.0068)
				if ia < 1.0:
					c = Color(0.22, 0.14, 0.08) if ia > 0.25 else Color(0.04, 0.03, 0.03)
				if dy > 0.003:
					c = _dark(c, 0.45)
			if absf(da) < 0.13 and dy > 0.0055 and dy < 0.0095:
				c = Color(0.08, 0.06, 0.05) if absf(da) < 0.11 else _dark(c, 0.4)
			var by: float = 1.684 + 0.004 * (1.0 - (da / 0.2) * (da / 0.2))
			if absf(da) < 0.2 and absf(y - by) < (0.0042 if not d.fem else 0.0028) and d.hair != "bald":
				c = c.lerp(_dark(d.hair_c, 0.1), 0.85 if nhi.get_noise_2d(X * 2.0, Y * 2.0) > -0.3 else 0.4)
		if d.beard > 0.0:
			var m := _ss(1.615, 1.6, y - 0.012 * _ss(0.3, 1.2, aa)) * _ss(1.75, 1.5, aa) * _ss(1.505, 1.53, y)
			if aa < 0.22 and y > 1.566 and y < 1.592:
				m *= 0.4
			if nhi.get_noise_2d(X * 3.1, Y * 3.1) < m * d.beard * 2.0 - 1.0 + d.beard:
				c = c.lerp(d.hair_c, 0.55 + d.beard * 0.35)
			else:
				c = c.lerp(d.hair_c, m * d.beard * 0.25)
		if d.mustache and aa < 0.26 and y > 1.586 and y < 1.6 - aa * 0.02:
			c = _hair_px(d, X, Y, a, y)
		if y < 1.535 and aa < 2.6:
			c = _dark(_skin(d, X, Y), 0.12 + _ss(1.53, 1.5, y) * 0.0 + _g(aa, 0.0, 0.0, 0.0, 0.25, 1.0) * 0.08)
		if d.hair == "bald":
			c = _light(c, _g(aa, y, 0.0, 1.74, 1.4, 0.012) * 0.15)
		elif d.hair == "beanie":
			var top := 1.695 + 0.008 * cos(a)
			if y > top:
				var cc: Color = d.c2
				var rib := 0.12 if (X % 3) == 0 else 0.0
				cc = _dark(cc * (1.0 + nhi.get_noise_2d(X * 2.0, Y * 4.0) * 0.12), rib)
				if y < top + 0.018:
					cc = _dark(cc, 0.1 + _ss(top + 0.012, top + 0.018, y) * 0.25)
				c = cc
			elif y > _hairline(d, a) and aa > 1.0:
				c = _hair_px(d, X, Y, a, y)
		else:
			var hl := _hairline(d, a)
			if y > hl:
				c = _hair_px(d, X, Y, a, y)
				if d.hair == "buzz":
					c = _skin(d, X, Y).lerp(c, 0.65 if nhi.get_noise_2d(X * 3.0, Y * 3.0) > -0.2 else 0.25)
				c = _dark(c, _ss(hl + 0.01, hl, y) * 0.15)
		return c


func _cloth(base: Color, X: int, Y: int, a: float, y: float, fold := 0.16) -> Color:
	var f := nfold.get_noise_2d(X * 0.6, Y * 2.6)
	var f2 := nfold.get_noise_2d(X * 1.8 + 50.0, Y * 1.2)
	var c := base * (1.0 + f * fold + f2 * fold * 0.5)
	c = c * (1.0 + (0.035 if (X + Y) % 2 == 0 else -0.035))
	c = c * (1.0 + nhi.get_noise_2d(X * 3.0, Y * 3.0) * 0.04)
	return c


func _glyph_on(seed: int, gx: int, gy: int) -> bool:
	var h := hash(Vector3i(seed, gx, gy))
	return (h % 100) < 55


func _print_px(d: Dictionary, a: float, y: float) -> Color:
	var u := (a + 0.5) / 1.0
	var v := (1.36 - y) / 0.12
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return Color(0, 0, 0, 0)
	var gx := int(u * 20.0)
	var gy := int(v * 11.0)
	if gy == 5:
		return Color(0, 0, 0, 0)
	var on := _glyph_on(d.seed, gx, gy) and gx % 4 != 3
	if not on:
		return Color(0, 0, 0, 0)
	var col := Color(0.85, 0.3, 0.15) if gy < 5 else Color(0.95, 0.55, 0.15)
	if d.c1.r > 0.55 and d.c1.g < 0.3:
		col = Color(0.95, 0.92, 0.85)
	return col


func _top_px(d: Dictionary, a: float, y: float, X: int, Y: int) -> Color:
	var aa := absf(a)
	var c: Color
	match d.top:
		"tshirt":
			c = _cloth(d.c1, X, Y, a, y)
			var neck := 1.448 - 0.022 * pow(maxf(cos(a), 0.0), 2.0)
			if y > neck - 0.012:
				c = _dark(c, 0.15) * (1.0 + (0.08 if X % 2 == 0 else -0.08))
			if d.print:
				var p := _print_px(d, a, y)
				if p.a > 0.0:
					c = p * (1.0 + nhi.get_noise_2d(X * 3.0, Y * 3.0) * 0.15)
		"hoodie":
			c = _cloth(d.c1, X, Y, a, y, 0.22)
			if aa < 0.75 and y > 0.985 and y < 1.135:
				c = _dark(c, 0.06)
				if absf(y - 1.135) < 0.006 or absf(aa - (0.75 - (1.135 - y) * 1.6)) < 0.03:
					c = _dark(c, 0.3)
			for s in [-1.0, 1.0]:
				if absf(a - s * 0.13) < 0.035 and y > 1.3 and y < 1.44:
					c = Color(0.86, 0.85, 0.8) * (0.9 if y < 1.31 else 1.0)
			if aa > 1.9 and y > 1.33:
				c = _dark(c, 0.1 + 0.2 * sin((aa - 1.9) * 14.0) * 0.5 + _ss(1.4, 1.46, y) * 0.2)
			if y > 1.44:
				c = _dark(c, 0.25)
			if d.print:
				var p := _print_px(d, a, y)
				if p.a > 0.0:
					c = p * (1.0 + nhi.get_noise_2d(X * 3.0, Y * 3.0) * 0.15)
			if y < 0.975:
				c = _dark(c, 0.12) * (1.0 + (0.1 if X % 2 == 0 else -0.1))
		"shirt":
			c = _cloth(d.c2.lerp(Color(0.92, 0.92, 0.9), 0.75), X, Y, a, y, 0.2)
			if aa < 0.025:
				c = _dark(c, 0.12)
			if aa < 0.06 and y < 1.43 and y > 1.08:
				c = _cloth(_dark(d.c1, 0.2), X, Y, a, y, 0.08) * (1.0 + (0.12 if (Y / 2) % 3 == 0 else 0.0))
			if y > 1.425 and aa < 0.9:
				c = _light(c, 0.1) if y > 1.44 else _dark(c, 0.2)
		"suit":
			c = _cloth(d.suit, X, Y, a, y, 0.12)
			var open := 0.36 * clampf((y - 1.16) / 0.27, 0.0, 1.0)
			if aa < open:
				c = _cloth(Color(0.9, 0.9, 0.88), X, Y, a, y, 0.08)
				if aa < 0.05:
					c = _cloth(_dark(d.c1, 0.25), X, Y, a, y, 0.05)
			elif aa < open + 0.04 and y > 1.16:
				c = _light(c, 0.12)
			if aa < 0.02 and y < 1.16:
				c = _dark(c, 0.35)
			for by in [1.12, 1.05]:
				if absf(a + 0.04) < 0.03 and absf(y - by) < 0.006:
					c = Color(0.05, 0.05, 0.05)
			for s in [-1.0, 1.0]:
				if absf(a - s * 0.65) < 0.2 and absf(y - 0.99) < 0.006:
					c = _dark(c, 0.35)
	var aa2 := absf(aa - PI * 0.5)
	c = _dark(c, _g(aa2, y, 0.0, 1.33, 0.18, 0.05) * 0.35)
	c = _dark(c, _ss(0.9, 0.2, aa) * 0.0 + _g(aa, y, 0.0, 1.19, 0.6, 0.015) * 0.1)
	if aa2 < 0.02:
		c = _dark(c, 0.12)
	return c


func _pants_base(d: Dictionary) -> Color:
	match d.bottom:
		"jeans":
			return d.jeans
		"black":
			return Color(0.09, 0.09, 0.1)
		"khaki":
			return Color(0.6, 0.52, 0.37)
		"suit":
			return d.suit
	return Color.GRAY


func _pants_px(d: Dictionary, a: float, X: int, Y: int, front_fade: float) -> Color:
	var b := _pants_base(d)
	var c := _cloth(b, X, Y, a, 0.0, 0.14)
	if d.bottom == "jeans":
		if (X + Y * 2) % 4 == 0:
			c = _light(c, 0.07)
		if nhi.get_noise_2d(X * 4.0, Y * 4.0) > 0.72:
			c = _light(c, 0.1)
		c = _light(c, front_fade * (0.18 + maxf(nlo.get_noise_2d(X * 6.0, Y * 6.0), 0.0) * 0.3))
	return c


func _stitch(d: Dictionary) -> Color:
	return Color(0.78, 0.55, 0.25) if d.bottom == "jeans" else _dark(_pants_base(d), 0.35)


func _hem(d: Dictionary) -> float:
	match d.top:
		"hoodie":
			return 0.935
		"suit":
			return 0.875
	return 0.965 if d.top == "tshirt" else 0.99


func _p_torso(d: Dictionary) -> Callable:
	return func(a: float, y: float, X: int, Y: int, t: float) -> Color:
		var aa := absf(a)
		var hem := _hem(d) + nlo.get_noise_1d(a * 30.0) * 0.004
		var c: Color
		if y > hem:
			c = _top_px(d, a, y, X, Y)
			if y < hem + 0.01:
				c = _dark(c, 0.2)
			var neck := 1.448 - (0.022 if d.top == "tshirt" else 0.0) * pow(maxf(cos(a), 0.0), 2.0)
			if d.top == "suit" or d.top == "shirt":
				neck = 1.452 - 0.02 * _ss(0.4, 0.0, aa)
			if y > neck:
				c = _dark(_skin(d, X, Y), 0.18)
		else:
			c = _pants_px(d, a, X, Y, pow(maxf(cos(a), 0.0), 2.0) * _ss(0.82, 0.9, y) * 0.6)
			if y > 0.952 and y < 0.985:
				c = _dark(c, 0.12)
				if absf(y - 0.955) < 0.003 or absf(y - 0.982) < 0.003:
					c = _stitch(d) if X % 2 == 0 else c
				if d.top == "shirt" or d.top == "suit":
					c = Color(0.08, 0.06, 0.05) * (1.0 + nhi.get_noise_2d(X * 3.0, Y * 3.0) * 0.2)
					if aa < 0.08:
						c = Color(0.7, 0.66, 0.5)
				for la in [0.6, 1.7, PI]:
					if absf(aa - la) < 0.05:
						c = _dark(c, 0.2)
			if y < 0.952 and y > 0.86 and absf(a - 0.06) < 0.02:
				c = _stitch(d) if Y % 2 == 0 else _dark(c, 0.25)
			for s in [-1.0, 1.0]:
				var pa: float = s * lerpf(0.3, 0.95, _ss(0.952, 0.885, y))
				if y > 0.885 and y < 0.952 and absf(a - pa) < 0.04:
					c = _dark(c, 0.3) if absf(a - pa) < 0.02 else _stitch(d)
				if absf(a - s * 2.45) < 0.32 and y > 0.855 and y < 0.935:
					if absf(absf(a - s * 2.45) - 0.3) < 0.03 or absf(y - 0.935) < 0.004 or absf(y - 0.857) < 0.004:
						c = _stitch(d) if (X + Y) % 2 == 0 else _dark(c, 0.2)
			c = _dark(c, _ss(0.85, 0.8, y) * 0.35)
			c = _dark(c, _ss(hem, hem - 0.025, y) * 0.0 + _ss(hem - 0.03, hem, y) * 0.25)
		return c


func _p_uarm(d: Dictionary) -> Callable:
	return func(a: float, y: float, X: int, Y: int, t: float) -> Color:
		var aa := absf(a)
		var c: Color
		var long: bool = d.top != "tshirt"
		var cut := 0.42 + nlo.get_noise_1d(a * 20.0) * 0.03
		if long or t < cut:
			match d.top:
				"suit":
					c = _cloth(d.suit, X, Y, a, y, 0.14)
				"shirt":
					c = _cloth(d.c2.lerp(Color(0.92, 0.92, 0.9), 0.75), X, Y, a, y, 0.25)
				_:
					c = _cloth(d.c1, X, Y, a, y, 0.22)
			if not long and t > cut - 0.06:
				c = _dark(c, 0.15)
			c = _dark(c, _ss(0.75, 1.0, t) * 0.12 * (1.0 + sin(X * 0.9)))
		else:
			c = _skin(d, X, Y)
			c = _dark(c, _ss(cut + 0.06, cut, t) * 0.3)
			c = _light(c, _g(aa, t, 0.0, 0.62, 0.8, 0.2) * 0.07)
			c = _dark(c, _g(aa, t, PI, 1.0, 0.5, 0.08) * 0.2)
		c = _dark(c, _g(aa, t, PI * 0.5, 0.05, 0.6, 0.15) * 0.15)
		return c


func _p_farm(d: Dictionary) -> Callable:
	return func(a: float, y: float, X: int, Y: int, t: float) -> Color:
		var aa := absf(a)
		var c: Color
		match d.top:
			"tshirt":
				c = _skin(d, X, Y)
				c = _dark(c, _g(aa, t, 0.0, 0.05, 0.4, 0.08) * 0.25)
				c = _light(c, _g(aa, t, 0.4, 0.35, 0.7, 0.25) * 0.08)
				if not d.fem and nhi.get_noise_2d(X * 5.0, Y * 5.0) > 0.5:
					c = c.lerp(d.hair_c, 0.25)
			"suit":
				c = _cloth(d.suit, X, Y, a, y, 0.14)
				if t > 0.9:
					c = Color(0.9, 0.9, 0.88)
			"shirt":
				c = _cloth(d.c2.lerp(Color(0.92, 0.92, 0.9), 0.75), X, Y, a, y, 0.3)
				if t > 0.86:
					c = _dark(c, 0.08)
			_:
				c = _cloth(d.c1, X, Y, a, y, 0.28)
				if t > 0.84:
					c = _dark(c, 0.15) * (1.0 + (0.1 if X % 2 == 0 else -0.1))
		return c


func _p_hand(d: Dictionary) -> Callable:
	return func(a: float, y: float, X: int, Y: int, t: float) -> Color:
		var c := _skin(d, X, Y)
		var ca := cos(a)
		if t > 0.55:
			for k in [-0.5, 0.0, 0.5]:
				if absf(ca - k) < 0.07:
					c = _dark(c, 0.3 * _ss(0.55, 0.65, t))
		if absf(t - 0.55) < 0.04:
			c = _dark(c, 0.12)
		if t > 0.9:
			c = _light(c, 0.1)
		c = _dark(c, _ss(0.1, 0.0, t) * 0.2)
		return c


func _p_thigh(d: Dictionary) -> Callable:
	return func(a: float, y: float, X: int, Y: int, t: float) -> Color:
		var aa := absf(a)
		var fade := pow(maxf(cos(a), 0.0), 2.0) * (0.6 + _g(t, 0.0, 0.85, 0.0, 0.2, 1.0) * 0.6)
		var c := _pants_px(d, a, X, Y, fade)
		if d.bottom == "jeans" and t < 0.25 and aa < 0.7 and absf(sin(Y * 1.3 + aa * 6.0)) < 0.25:
			c = _light(c, 0.15)
		if absf(aa - PI * 0.5) < 0.03:
			c = _stitch(d) if Y % 2 == 0 else _dark(c, 0.2)
		if d.bottom == "suit" and aa < 0.02:
			c = _light(c, 0.12)
		c = _dark(c, _ss(0.15, 0.0, t) * 0.2)
		c = _dark(c, _g(t, 0.0, 0.92, 0.0, 0.06, 1.0) * 0.12 * (1.0 + sin(X * 1.2)))
		return c


func _p_shin(d: Dictionary) -> Callable:
	return func(a: float, y: float, X: int, Y: int, t: float) -> Color:
		var aa := absf(a)
		var fade := pow(maxf(cos(a), 0.0), 2.0) * (0.35 + _g(t, 0.0, 0.05, 0.0, 0.15, 1.0) * 0.5)
		var c := _pants_px(d, a, X, Y, fade)
		if absf(aa - PI * 0.5) < 0.03:
			c = _stitch(d) if Y % 2 == 0 else _dark(c, 0.2)
		if t > 0.72:
			c = _dark(c, 0.12 * (1.0 + sin(Y * 1.4 + a * 3.0)))
		if t > 0.96:
			c = _dark(c, 0.2)
		return c


func _p_foot(d: Dictionary) -> Callable:
	return func(a: float, y: float, X: int, Y: int, t: float) -> Color:
		var aa := absf(a)
		var c: Color
		match d.shoe:
			"sneaker":
				c = Color(0.88, 0.88, 0.86) * (1.0 + nhi.get_noise_2d(X * 3.0, Y * 3.0) * 0.04)
				if aa > 1.95:
					c = Color(0.62, 0.6, 0.58) if aa < 2.5 else Color(0.25, 0.24, 0.24)
				elif absf(aa - 1.3) < 0.25 and t > 0.25 and t < 0.65:
					c = d.c2.lerp(Color(0.8, 0.1, 0.1), 0.5)
				if aa < 0.45 and t > 0.35 and t < 0.75:
					c = Color(0.95, 0.95, 0.93) if Y % 2 == 0 else Color(0.6, 0.6, 0.6)
				if t < 0.12 and aa < 1.6:
					c = _dark(c, 0.15)
			"black":
				c = Color(0.05, 0.05, 0.05)
				c = _light(c, _g(aa, t, 0.4, 0.85, 0.4, 0.15) * 0.25)
				if aa > 2.2:
					c = Color(0.03, 0.03, 0.03)
			"brown":
				c = Color(0.3, 0.18, 0.1) * (1.0 + nhi.get_noise_2d(X * 2.0, Y * 2.0) * 0.12)
				if aa > 2.2:
					c = Color(0.12, 0.08, 0.05)
				if aa < 0.3 and t > 0.3 and t < 0.6 and Y % 2 == 0:
					c = Color(0.55, 0.45, 0.3)
		return c


func _paint(d: Dictionary) -> void:
	img = Image.create(int(TS), int(TS), false, Image.FORMAT_RGB8)
	img.fill(Color(0.03, 0.03, 0.04))
	nlo.seed = d.seed
	nlo.frequency = 0.01
	nlo.fractal_octaves = 3
	nhi.seed = d.seed + 7
	nhi.frequency = 0.35
	nhi.fractal_octaves = 1
	nfold.seed = d.seed + 3
	nfold.frequency = 0.04
	nfold.fractal_octaves = 2
	_paint_region(RG.head, 1.76, 1.44, _p_head(d))
	_paint_region(RG.torso, 1.47, 0.8, _p_torso(d))
	_paint_region(RG.uarm, 0.0, 1.0, _p_uarm(d))
	_paint_region(RG.farm, 0.0, 1.0, _p_farm(d))
	_paint_region(RG.hand, 0.0, 1.0, _p_hand(d))
	_paint_region(RG.thigh, 0.0, 1.0, _p_thigh(d))
	_paint_region(RG.shin, 0.0, 1.0, _p_shin(d))
	_paint_region(RG.foot, 0.0, 1.0, _p_foot(d))
	_paint_region(RG.bun, 0.0, 1.0, func(a: float, y: float, X: int, Y: int, t: float) -> Color: return _hair_px(d, X, Y, a, 1.6))


func _fem_w(y: float, fem: bool) -> float:
	if not fem:
		return 1.0
	return lerpf(1.08, 0.88, _ss(0.95, 1.4, y))


func build(seed: int) -> Dictionary:
	if cache.has(seed):
		return cache[seed]
	var d := describe(seed)
	_paint(d)
	var tex := ImageTexture.create_from_image(img)
	var m := _mat(tex)
	var parts := {}
	var fem: bool = d.fem
	var tr := []
	for r in [[1.47, 0.06, 0.06, 0.005], [1.44, 0.12, 0.075, 0.0], [1.4, 0.175, 0.095, 0.0], [1.34, 0.18, 0.11, -0.005], [1.25, 0.175, 0.115, -0.01], [1.14, 0.155, 0.105, -0.005], [1.04, 0.145, 0.095, 0.0], [0.96, 0.162, 0.1, 0.0], [0.88, 0.165, 0.105, 0.0], [0.8, 0.12, 0.09, 0.0]]:
		var w := _fem_w(r[0], fem)
		var z: float = r[2] * (1.12 if fem and r[0] > 1.2 and r[0] < 1.32 else 1.0)
		if d.top == "hoodie" and r[0] < 1.42 and r[0] > 0.93:
			w *= 1.06
			z *= 1.08
		tr.append([r[0], r[1] * w, z, r[3]])
	var mb := MB.new()
	_loft(mb, tr, 12, RG.torso, false, 0.0, 0.0)
	var head := [[1.75, 0.04, 0.05, 0.01], [1.73, 0.07, 0.085, 0.005], [1.70, 0.08, 0.098, 0.0], [1.66, 0.08, 0.1, -0.005, 0.012], [1.62, 0.077, 0.098, -0.01, 0.028], [1.58, 0.07, 0.09, -0.01, 0.006], [1.545, 0.06, 0.075, -0.005, 0.012], [1.52, 0.054, 0.058, 0.012], [1.44, 0.053, 0.053, 0.01]]
	if d.hair == "beanie":
		head[0] = [1.765, 0.05, 0.06, 0.01]
		head[1] = [1.74, 0.083, 0.098, 0.005]
		head[2] = [1.705, 0.086, 0.104, 0.0]
	elif d.hair == "short" or d.hair == "bob" or d.hair == "long" or d.hair == "bun":
		head[0] = [1.757, 0.045, 0.055, 0.01]
		head[1] = [1.735, 0.075, 0.09, 0.008]
	var h0 := mb.v.size()
	_loft(mb, head, 12, RG.head, false, 0.008, 0.0)
	for i in range(h0, mb.v.size()):
		mb.v[i] = Vector3(0, 1.5, 0) + (mb.v[i] - Vector3(0, 1.5, 0)) * 1.1
	if d.hair == "bun":
		_loft(mb, [[1.73, 0.0, 0.0, 0.0], [1.72, 0.035, 0.03, 0.0], [1.68, 0.035, 0.03, 0.0], [1.665, 0.0, 0.0, 0.0]], 6, RG.bun, false, 0.0, 0.0, Vector3(0, 0, 0.1))
	parts.torso = mb.mesh(m)
	mb = MB.new()
	var ua := [[0.035, 0.028, 0.032, 0.0], [0.015, 0.05, 0.054, 0.0], [-0.06, 0.054, 0.054, 0.0], [-0.16, 0.05, 0.05, 0.0], [-0.28, 0.041, 0.043, 0.005]]
	if d.top != "tshirt":
		for r in ua:
			r[1] *= 1.08
			r[2] *= 1.08
	_loft(mb, ua, 9, RG.uarm, false, 0.0, 0.0)
	parts.uarm = mb.mesh(m)
	mb = MB.new()
	var fa := [[0.02, 0.041, 0.043, 0.005], [-0.06, 0.045, 0.042, 0.0], [-0.17, 0.035, 0.031, 0.0], [-0.245, 0.026, 0.022, 0.0]]
	if d.top != "tshirt":
		for r in fa:
			r[1] *= 1.15
			r[2] *= 1.15
	_loft(mb, fa, 9, RG.farm, false, 0.0, 0.0)
	_loft(mb, [[-0.235, 0.019, 0.027, 0.0], [-0.27, 0.02, 0.04, 0.0], [-0.33, 0.016, 0.039, -0.004], [-0.4, 0.011, 0.028, 0.0]], 8, RG.hand, false, 0.0, 0.006)
	parts.farm = mb.mesh(m)
	mb = MB.new()
	var bw := 1.12 if d.bottom != "black" else 1.0
	_loft(mb, [[0.07, 0.07 * bw, 0.08 * bw, 0.0], [0.0, 0.082 * bw, 0.088 * bw, 0.0], [-0.15, 0.072 * bw, 0.078 * bw, 0.0], [-0.32, 0.056 * bw, 0.062 * bw, 0.0], [-0.41, 0.051 * bw, 0.057 * bw, 0.0]], 10, RG.thigh, false, 0.0, 0.0)
	parts.thigh = mb.mesh(m)
	mb = MB.new()
	_loft(mb, [[0.02, 0.051 * bw, 0.057 * bw, 0.0], [-0.08, 0.05 * bw, 0.06 * bw, 0.01], [-0.2, 0.044 * bw, 0.05 * bw, 0.005], [-0.33, 0.04 * bw, 0.044 * bw, 0.0], [-0.38, 0.042 * bw, 0.046 * bw, 0.0]], 10, RG.shin, false, 0.0, 0.0)
	_loft(mb, [[0.06, 0.035, 0.035, -0.425], [0.045, 0.048, 0.05, -0.43], [-0.04, 0.05, 0.045, -0.44], [-0.13, 0.048, 0.032, -0.45], [-0.18, 0.03, 0.022, -0.455]], 8, RG.foot, true, 0.01, 0.012)
	parts.shin = mb.mesh(m)
	var res := {"d": d, "mat": m, "parts": parts, "tex": tex}
	cache[seed] = res
	return res


func _shadow() -> ArrayMesh:
	if shadow_mesh:
		return shadow_mesh
	var im := Image.create(2, 2, false, Image.FORMAT_RGB8)
	im.fill(Color(0.03, 0.03, 0.04))
	var mb := MB.new()
	mb.v.append(Vector3(0, 0.012, 0))
	mb.n.append(Vector3.UP)
	mb.uv.append(Vector2(0.5, 0.5))
	for i in 8:
		var a := TAU * i / 8.0
		mb.v.append(Vector3(cos(a) * 0.3, 0.012, sin(a) * 0.24))
		mb.n.append(Vector3.UP)
		mb.uv.append(Vector2(0.5, 0.5))
		mb.idx.append_array([0, 1 + i, 1 + (i + 1) % 8])
	shadow_mesh = mb.mesh(_mat(ImageTexture.create_from_image(im)))
	return shadow_mesh


func tri_count(seed: int) -> int:
	var b := build(seed)
	var n := 0
	for k in b.parts:
		var mesh: ArrayMesh = b.parts[k]
		var c: int = mesh.surface_get_array_index_len(0) / 3
		n += c * (2 if k != "torso" else 1)
	return n


func _mi(mesh: Mesh, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func rig(seed: int) -> Dictionary:
	var b := build(seed)
	var d: Dictionary = b.d
	var p: Dictionary = b.parts
	var root := Node3D.new()
	root.add_child(_mi(_shadow()))
	var body := Node3D.new()
	body.scale = Vector3(d.ws, d.hs, d.ws)
	root.add_child(body)
	var chest := Node3D.new()
	chest.position = Vector3(0, 0.9, 0)
	body.add_child(chest)
	chest.add_child(_mi(p.torso, Vector3(0, -0.9, 0)))
	var r := {"root": root, "body": body, "chest": chest, "hips": [], "knees": [], "shoulders": [], "elbows": []}
	var sw := 0.88 if d.fem else 1.0
	for sx in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(sx * 0.18 * sw, 1.39 - 0.9, 0)
		chest.add_child(sh)
		sh.add_child(_mi(p.uarm))
		var el := Node3D.new()
		el.position = Vector3(0, -0.28, 0)
		sh.add_child(el)
		el.add_child(_mi(p.farm))
		r.shoulders.append(sh)
		r.elbows.append(el)
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.085 * (1.05 if d.fem else 1.0), 0.88, 0)
		body.add_child(hip)
		hip.add_child(_mi(p.thigh))
		var kn := Node3D.new()
		kn.position = Vector3(0, -0.4, 0)
		hip.add_child(kn)
		kn.add_child(_mi(p.shin))
		r.hips.append(hip)
		r.knees.append(kn)
	pose(r, 0.0, 0.0)
	return r


func pose(r: Dictionary, phase: float, amt: float) -> void:
	var s := sin(phase)
	for i in 2:
		var sg := 1.0 if i == 0 else -1.0
		var a := s * sg * 0.45 * amt
		r.hips[i].rotation.x = a
		var ph := phase + (0.0 if i == 0 else PI)
		r.knees[i].rotation.x = -maxf(0.0, -sin(ph + 0.9)) * 0.75 * amt - 0.03
		r.shoulders[i].rotation.x = -a * 0.75
		r.shoulders[i].rotation.z = -0.07 * sg
		r.elbows[i].rotation.x = 0.12 + maxf(0.0, -a) * 0.6 * amt
	r.body.position.y = absf(cos(phase)) * 0.025 * amt
	r.chest.rotation.y = s * 0.07 * amt
