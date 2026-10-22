extends RefCounted

const Kit := preload("res://scripts/kit.gd")
const PS1 := preload("res://scripts/ps1.gdshader")

const R := {
	"face": Rect2(0, 0, 16, 16), "hside": Rect2(16, 0, 16, 16), "hback": Rect2(32, 0, 16, 16), "htop": Rect2(48, 0, 16, 16),
	"tf": Rect2(0, 16, 16, 16), "tb": Rect2(16, 16, 16, 16), "ts": Rect2(32, 16, 8, 16), "tt": Rect2(40, 16, 8, 8), "td": Rect2(40, 24, 8, 8),
	"pf": Rect2(48, 16, 16, 8), "pb": Rect2(48, 24, 16, 8),
	"ua": Rect2(0, 32, 8, 16), "fa": Rect2(8, 32, 8, 16), "hand": Rect2(16, 32, 8, 8), "th": Rect2(24, 32, 8, 16), "sh": Rect2(32, 32, 8, 16),
	"shoe_t": Rect2(40, 32, 8, 8), "shoe_s": Rect2(40, 40, 8, 8), "skin": Rect2(16, 40, 8, 8), "hair": Rect2(48, 32, 8, 8),
	"cloth": Rect2(56, 32, 8, 8), "pants": Rect2(56, 40, 8, 8), "pack": Rect2(48, 48, 16, 16), "packs": Rect2(40, 48, 8, 16),
	"cap": Rect2(0, 48, 16, 8), "capd": Rect2(0, 56, 16, 8), "dark": Rect2(16, 48, 8, 8), "neck": Rect2(24, 48, 8, 8),
}

const SKIN := [Color(0.93, 0.74, 0.6), Color(0.84, 0.62, 0.47), Color(0.7, 0.48, 0.33), Color(0.55, 0.36, 0.24), Color(0.4, 0.26, 0.17), Color(0.3, 0.19, 0.13)]
const HAIR := [Color(0.06, 0.05, 0.05), Color(0.16, 0.1, 0.06), Color(0.3, 0.19, 0.1), Color(0.72, 0.58, 0.3), Color(0.5, 0.48, 0.46), Color(0.45, 0.14, 0.08)]
const CLOTH := [Color(0.72, 0.13, 0.1), Color(0.14, 0.2, 0.42), Color(0.86, 0.86, 0.82), Color(0.1, 0.1, 0.11), Color(0.82, 0.62, 0.16), Color(0.2, 0.44, 0.28), Color(0.46, 0.46, 0.5), Color(0.55, 0.32, 0.55), Color(0.85, 0.45, 0.2), Color(0.3, 0.55, 0.75)]
const SUIT := [Color(0.12, 0.13, 0.16), Color(0.2, 0.22, 0.3), Color(0.32, 0.32, 0.33), Color(0.28, 0.22, 0.17)]
const JEANS := [Color(0.2, 0.3, 0.52), Color(0.14, 0.2, 0.36), Color(0.36, 0.46, 0.62)]

var rng := RandomNumberGenerator.new()
var img: Image
var cache := {}
var shadow_mesh: ArrayMesh


func _mat(tex: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("tint", Color.WHITE)
	return m


func _px(x: int, y: int, c: Color) -> void:
	img.set_pixel(x, y, c)


func _fill(r: Rect2, c: Color, grain := 0.025) -> void:
	for y in range(int(r.position.y), int(r.end.y)):
		for x in range(int(r.position.x), int(r.end.x)):
			var g := rng.randf_range(-grain, grain)
			_px(x, y, Color(clampf(c.r + g, 0, 1), clampf(c.g + g, 0, 1), clampf(c.b + g, 0, 1)))


func _at(r: Rect2, x: int, y: int, c: Color) -> void:
	_px(int(r.position.x) + x, int(r.position.y) + y, c)


func _shade(r: Rect2, amount: float) -> void:
	var w := int(r.size.x)
	for y in int(r.size.y):
		for x in [0, w - 1]:
			var p := Vector2i(int(r.position.x) + x, int(r.position.y) + y)
			img.set_pixelv(p, img.get_pixelv(p).darkened(amount))


func _pick(list: Array) -> Variant:
	return list[rng.randi() % list.size()]


func describe(seed: int) -> Dictionary:
	rng.seed = seed
	var d := {}
	d.skin = _pick(SKIN)
	d.hair_c = _pick(HAIR)
	d.fem = rng.randf() < 0.45
	d.hair = _pick(["long", "long", "bun", "short"]) if d.fem else _pick(["short", "short", "buzz", "bald", "cap", "curly"])
	d.top = _pick(["tshirt", "blouse", "hoodie", "jacket", "suit"]) if d.fem else _pick(["tshirt", "shirt", "suit", "hoodie", "jacket", "tshirt"])
	d.bottom = _pick(["jeans", "skirt", "trousers", "jeans"]) if d.fem else _pick(["jeans", "jeans", "trousers", "khaki"])
	if d.top == "suit":
		d.bottom = "suit"
	d.c1 = _pick(CLOTH)
	d.c2 = _pick(CLOTH)
	d.suit = _pick(SUIT)
	d.jeans = _pick(JEANS)
	d.shoe = _pick([Color(0.9, 0.9, 0.88), Color(0.08, 0.08, 0.08), Color(0.35, 0.22, 0.12), Color(0.75, 0.15, 0.12)])
	if d.bottom == "suit":
		d.shoe = Color(0.06, 0.05, 0.05)
	d.pack = rng.randf() < 0.3 and d.top != "suit"
	d.pack_c = _pick(CLOTH)
	d.beard = not d.fem and rng.randf() < 0.3
	d.glasses = rng.randf() < 0.2
	d.hs = rng.randf_range(0.9, 1.06) * (0.96 if d.fem else 1.0)
	d.ws = rng.randf_range(0.92, 1.14)
	return d


func _paint(d: Dictionary) -> void:
	img = Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.1, 0.1, 0.1))
	var sk: Color = d.skin
	var hc: Color = d.hair_c
	var bald: bool = d.hair == "bald"
	_fill(R.skin, sk, 0.015)
	_fill(R.neck, sk.darkened(0.12), 0.015)
	_fill(R.hair, hc if not bald else sk, 0.04)
	_fill(R.dark, Color(0.05, 0.05, 0.05), 0.01)
	_face(d)
	_head_rest(d)
	_torso(d)
	_legs(d)
	_fill(R.shoe_t, d.shoe, 0.03)
	_fill(R.shoe_s, d.shoe.darkened(0.2), 0.03)
	for x in 8:
		_at(R.shoe_s, x, 7, Color(0.85, 0.85, 0.82) if d.shoe.v < 0.5 and d.bottom != "suit" else Color(0.1, 0.1, 0.1))
	_fill(R.pack, d.pack_c, 0.04)
	for x in range(3, 13):
		_at(R.pack, x, 8, d.pack_c.darkened(0.45))
		_at(R.pack, x, 14, d.pack_c.darkened(0.45))
	for y in range(8, 15):
		_at(R.pack, 3, y, d.pack_c.darkened(0.45))
		_at(R.pack, 12, y, d.pack_c.darkened(0.45))
	_at(R.pack, 8, 9, Color(0.8, 0.8, 0.75))
	_fill(R.packs, d.pack_c.darkened(0.2), 0.04)
	var capc: Color = d.c2
	_fill(R.cap, capc, 0.03)
	_at(R.cap, 7, 3, Color(0.95, 0.95, 0.9))
	_at(R.cap, 8, 3, Color(0.95, 0.95, 0.9))
	_fill(R.capd, capc.darkened(0.35), 0.03)


func _face(d: Dictionary) -> void:
	var r: Rect2 = R.face
	var sk: Color = d.skin
	var hc: Color = d.hair_c
	_fill(r, sk, 0.015)
	for y in 16:
		_at(r, 0, y, sk.darkened(0.18))
		_at(r, 15, y, sk.darkened(0.18))
		_at(r, 1, y, sk.darkened(0.08))
		_at(r, 14, y, sk.darkened(0.08))
	var top := 0
	match d.hair:
		"long", "short", "curly", "bun":
			top = 4
		"buzz":
			top = 2
		"cap":
			top = 3
	for x in 16:
		var h := top
		if d.hair == "long" or d.hair == "bun":
			h = top + (1 if (x < 7 or x > 8) else 0) + (2 if x < 2 or x > 13 else 0)
		elif d.hair == "short" or d.hair == "curly":
			h = top + (1 if x < 3 or x > 12 else 0) - (1 if x > 4 and x < 9 and d.hair == "short" else 0)
		for y in h:
			_at(r, x, y, hc.lightened(0.08 * float((x + y) % 3 == 0)))
	if d.hair == "long":
		for y in range(4, 14):
			for x in [0, 1, 14, 15]:
				_at(r, x, y, hc)
	var brow := hc.darkened(0.2) if d.hair != "bald" else sk.darkened(0.45)
	for x in [4, 5, 10, 11]:
		_at(r, x, 6, brow)
	var white := Color(0.92, 0.9, 0.86)
	var iris := Color(0.08, 0.06, 0.05)
	_at(r, 4, 7, white)
	_at(r, 5, 7, iris)
	_at(r, 10, 7, iris)
	_at(r, 11, 7, white)
	_at(r, 4, 8, sk.darkened(0.12))
	_at(r, 5, 8, sk.darkened(0.12))
	_at(r, 10, 8, sk.darkened(0.12))
	_at(r, 11, 8, sk.darkened(0.12))
	for y in [8, 9, 10]:
		_at(r, 7, y, sk.darkened(0.06))
	_at(r, 7, 10, sk.darkened(0.25))
	_at(r, 8, 10, sk.darkened(0.25))
	_at(r, 8, 9, sk.lightened(0.08))
	var lip := sk.darkened(0.35).lerp(Color(0.55, 0.15, 0.15), 0.35 if d.fem else 0.15)
	for x in range(6, 10):
		_at(r, x, 12, lip)
	_at(r, 7, 13, sk.darkened(0.1))
	_at(r, 8, 13, sk.darkened(0.1))
	if d.fem:
		_at(r, 3, 10, sk.lerp(Color(0.85, 0.4, 0.4), 0.18))
		_at(r, 12, 10, sk.lerp(Color(0.85, 0.4, 0.4), 0.18))
		_at(r, 3, 7, Color(0.1, 0.08, 0.08))
		_at(r, 12, 7, Color(0.1, 0.08, 0.08))
	if d.beard:
		for y in range(10, 16):
			for x in range(2, 14):
				var edge := y < 12 and x > 4 and x < 11
				if not edge and (y > 11 or x < 4 or x > 11) and not (y == 12 and x > 5 and x < 10):
					_at(r, x, y, hc.lerp(sk, 0.25 if (x + y) % 2 == 0 else 0.05))
	if d.glasses:
		var g := Color(0.08, 0.08, 0.1)
		for x in range(3, 13):
			_at(r, x, 6 if x != 7 and x != 8 else 7, g)
		for x in [3, 6, 9, 12]:
			_at(r, x, 7, g)
			_at(r, x, 8, g)
	for x in range(3, 13):
		_at(r, x, 15, sk.darkened(0.22))


func _head_rest(d: Dictionary) -> void:
	var sk: Color = d.skin
	var hc: Color = d.hair_c
	var bald: bool = d.hair == "bald"
	var long: bool = d.hair == "long" or d.hair == "bun"
	var s: Rect2 = R.hside
	_fill(s, sk, 0.015)
	for y in 16:
		for x in 16:
			var lim := 9 - x * 0.5 if not long else 14.0
			var hair_here := y < 4 or (x > 7 and y < 16 - (0 if long else 6)) or (x > 5 and y < lim)
			if d.hair == "buzz" and (y > 3 and x < 9):
				hair_here = false
			if d.hair == "cap" and y > 4 and x < 12:
				hair_here = false
			if not bald and hair_here:
				_at(s, x, y, hc.lightened(0.07 * float((x * 3 + y) % 4 == 0)))
	_at(s, 7, 7, sk.darkened(0.25))
	_at(s, 7, 8, sk.darkened(0.3))
	_at(s, 6, 8, sk.darkened(0.15))
	if d.beard:
		for y in range(10, 16):
			for x in range(0, 7):
				_at(s, x, y, hc.lerp(sk, 0.2))
	if d.glasses:
		for x in range(0, 7):
			_at(s, x, 7, Color(0.08, 0.08, 0.1))
	var b: Rect2 = R.hback
	_fill(b, hc if not bald else sk, 0.04)
	if not long and not bald:
		for y in range(12, 16):
			for x in 16:
				_at(b, x, y, sk.darkened(0.08))
	if bald:
		_fill(b, sk.darkened(0.05), 0.02)
	if d.hair == "bun":
		for y in range(2, 6):
			for x in range(6, 10):
				_at(b, x, y, hc.darkened(0.3))
	_fill(R.htop, hc if not bald else sk.lightened(0.05), 0.05)
	if d.hair == "curly":
		for y in 16:
			for x in 16:
				if (x + y * 2) % 3 == 0:
					_at(R.htop, x, y, hc.lightened(0.15))
					_at(b, x, y, hc.lightened(0.15))


func _torso(d: Dictionary) -> void:
	var sk: Color = d.skin
	var base: Color = d.c1
	var sleeve := base
	var short_sleeve := false
	match d.top:
		"suit":
			base = d.suit
			sleeve = base
		"tshirt", "blouse":
			short_sleeve = true
	var f: Rect2 = R.tf
	var bk: Rect2 = R.tb
	_fill(f, base, 0.03)
	_fill(bk, base, 0.03)
	_fill(R.ts, base.darkened(0.12), 0.03)
	_fill(R.tt, base, 0.03)
	_fill(R.td, base.darkened(0.3), 0.02)
	_fill(R.cloth, base, 0.03)
	match d.top:
		"tshirt":
			for x in range(6, 10):
				_at(f, x, 0, sk.darkened(0.1))
			_at(f, 7, 1, sk.darkened(0.15))
			_at(f, 8, 1, sk.darkened(0.15))
			var logo: Color = d.c2 if d.c2 != base else Color(0.95, 0.95, 0.9)
			for y in range(5, 8):
				for x in range(6, 10):
					if (x + y) % 2 == 0 or y == 6:
						_at(f, x, y, logo)
		"blouse":
			for x in range(5, 11):
				_at(f, x, 0, sk.darkened(0.1))
			for x in range(6, 10):
				_at(f, x, 1, sk.darkened(0.12))
			for y in range(3, 16, 3):
				for x in range(1 + (y % 2), 15, 3):
					_at(f, x, y, d.c2.lightened(0.3))
					_at(bk, x, y, d.c2.lightened(0.3))
		"shirt":
			var tie: Color = d.c2.darkened(0.2)
			for y in range(1, 13):
				_at(f, 7, y, tie)
				_at(f, 8, y, tie)
			_at(f, 6, 0, Color(0.95, 0.95, 0.95))
			_at(f, 9, 0, Color(0.95, 0.95, 0.95))
			_at(f, 7, 0, tie.darkened(0.3))
			_at(f, 8, 0, tie.darkened(0.3))
			for x in 16:
				_at(f, x, 14, Color(0.12, 0.1, 0.08))
		"suit":
			var shirt := Color(0.9, 0.9, 0.88)
			var tie: Color = d.c2.darkened(0.15)
			for y in 9:
				var half := 3 - y / 3
				for x in range(8 - half - 1, 8 + half + 1):
					_at(f, x, y, shirt)
			for y in range(0, 9):
				_at(f, 7, y, tie)
				_at(f, 8, y, tie)
			for y in range(9, 16):
				_at(f, 7, y, base.darkened(0.3))
			_at(f, 6, 11, Color(0.05, 0.05, 0.05))
			_at(f, 6, 13, Color(0.05, 0.05, 0.05))
			_at(f, 3, 4, base.lightened(0.2))
			for y in range(0, 16):
				_at(bk, 7, y, base.darkened(0.25))
		"hoodie":
			for y in range(9, 15):
				for x in range(3, 13):
					if y == 9 or x == 3 or x == 12:
						_at(f, x, y, base.darkened(0.3))
			for y in range(1, 6):
				_at(f, 6, y, Color(0.9, 0.9, 0.88))
				_at(f, 9, y, Color(0.9, 0.9, 0.88))
			for x in range(4, 12):
				_at(f, x, 0, base.darkened(0.4))
			for y in range(0, 5):
				for x in range(3, 13):
					_at(bk, x, y, base.darkened(0.22 if y < 4 else 0.4))
			for x in 16:
				_at(f, x, 15, base.darkened(0.25))
				_at(bk, x, 15, base.darkened(0.25))
		"jacket":
			var inner: Color = d.c2
			for y in 16:
				for x in range(6, 10):
					_at(f, x, y, inner)
			for y in 16:
				_at(f, 5, y, base.darkened(0.35))
				_at(f, 10, y, base.darkened(0.35))
			_at(f, 3, 9, base.darkened(0.4))
			_at(f, 12, 9, base.darkened(0.4))
			for x in 16:
				_at(f, x, 15, base.darkened(0.2))
	for y in 16:
		_at(f, 0, y, base.darkened(0.2))
		_at(f, 15, y, base.darkened(0.2))
	if d.pack:
		var st: Color = d.pack_c.darkened(0.35)
		for y in range(0, 12):
			_at(f, 3, y, st)
			_at(f, 12, y, st)
	var ua: Rect2 = R.ua
	var fa: Rect2 = R.fa
	_fill(ua, sleeve, 0.03)
	_fill(fa, sleeve.darkened(0.05), 0.03)
	if short_sleeve:
		for y in range(7, 16):
			for x in 8:
				_at(ua, x, y, sk.darkened(0.05 if x > 0 and x < 7 else 0.15))
		_fill(fa, sk, 0.015)
		for y in 16:
			_at(fa, 0, y, sk.darkened(0.15))
	else:
		for x in 8:
			_at(ua, x, 15, sleeve.darkened(0.25))
			_at(fa, x, 15, Color(0.9, 0.9, 0.88) if d.top == "suit" else sleeve.darkened(0.3))
	_fill(R.hand, sk, 0.015)
	for y in range(5, 8):
		for x in [1, 3, 5]:
			_at(R.hand, x, y, sk.darkened(0.2))


func _legs(d: Dictionary) -> void:
	var sk: Color = d.skin
	var c: Color
	match d.bottom:
		"jeans":
			c = d.jeans
		"trousers":
			c = Color(0.13, 0.13, 0.15)
		"khaki":
			c = Color(0.62, 0.54, 0.38)
		"suit":
			c = d.suit
		"skirt":
			c = d.c2.darkened(0.2)
	var th: Rect2 = R.th
	var sh: Rect2 = R.sh
	_fill(R.pf, c, 0.03)
	_fill(R.pb, c, 0.03)
	_fill(R.pants, c, 0.03)
	_fill(th, c, 0.035)
	_fill(sh, c, 0.035)
	if d.bottom != "skirt":
		var belt := Color(0.08, 0.06, 0.05)
		for x in 16:
			_at(R.pf, x, 0, belt)
			_at(R.pb, x, 0, belt)
		_at(R.pf, 7, 0, Color(0.75, 0.7, 0.5))
		for y in range(1, 6):
			_at(R.pf, 8, y, c.darkened(0.25))
		for y in 16:
			_at(th, 0, y, c.darkened(0.2))
			_at(sh, 0, y, c.darkened(0.2))
		if d.bottom == "jeans":
			for y in range(2, 6):
				for x in range(2, 6):
					_at(th, x, y + 8, c.lightened(0.12))
			for y in 16:
				_at(th, 7, y, Color(0.7, 0.5, 0.25) if y % 2 == 0 else c)
			_at(R.pb, 3, 3, c.darkened(0.25))
			_at(R.pb, 12, 3, c.darkened(0.25))
		for x in 8:
			_at(sh, x, 15, c.darkened(0.3))
	else:
		for y in range(9, 16):
			for x in 8:
				_at(th, x, y, sk.darkened(0.05 if x > 0 else 0.15))
		_fill(sh, sk, 0.015)
		for y in 16:
			_at(sh, 0, y, sk.darkened(0.15))
		for x in 8:
			_at(th, x, 8, c.darkened(0.3))
		for x in 16:
			_at(R.pf, x, 7, c.darkened(0.3))
			_at(R.pb, x, 7, c.darkened(0.3))


func build(seed: int) -> Dictionary:
	if cache.has(seed):
		return cache[seed]
	var d := describe(seed)
	_paint(d)
	var m := _mat(ImageTexture.create_from_image(img))
	var parts := {}
	var k := Kit.new()
	var bottom: String = d.bottom
	var skirt := bottom == "skirt"
	k.cuboid(0.84 if not skirt else 0.68, 1.0, 0.33 if not skirt else 0.42, 0.2 if not skirt else 0.28, 0.32, 0.19, {"f": R.pf, "b": R.pb, "s": R.pb, "t": R.pants, "d": R.pants})
	parts.pelvis = k.mesh(m)
	k = Kit.new()
	k.cuboid(0.99, 1.45, 0.31, 0.19, 0.41, 0.22, {"f": R.tf, "b": R.tb, "s": R.ts, "t": R.tt, "d": R.td})
	k.cuboid(1.44, 1.52, 0.08, 0.08, 0.08, 0.08, {"f": R.neck})
	var hf := {"f": R.face, "b": R.hback, "s": R.hside, "t": R.htop, "d": R.neck}
	k.cuboid(1.49, 1.73, 0.165, 0.19, 0.2, 0.22, hf)
	if d.hair == "long":
		k.cuboid(1.36, 1.68, 0.2, 0.05, 0.21, 0.05, {"f": R.hair}, Vector3(0, 0, 0.115))
	elif d.hair == "bun":
		k.cuboid(1.66, 1.76, 0.08, 0.07, 0.07, 0.06, {"f": R.hair}, Vector3(0, 0, 0.12))
	elif d.hair == "curly":
		k.cuboid(1.7, 1.77, 0.21, 0.23, 0.17, 0.19, {"f": R.hair, "t": R.htop})
	elif d.hair == "cap":
		k.cuboid(1.68, 1.77, 0.215, 0.235, 0.19, 0.21, {"f": R.cap, "b": R.cap, "s": R.capd, "t": R.capd})
		k.cuboid(1.68, 1.70, 0.18, 0.12, 0.18, 0.12, {"f": R.capd}, Vector3(0, 0, -0.16))
	if d.pack:
		k.cuboid(1.05, 1.4, 0.3, 0.15, 0.28, 0.13, {"f": R.packs, "b": R.pack, "s": R.packs}, Vector3(0, 0, 0.18))
	parts.torso = k.mesh(m)
	k = Kit.new()
	k.cuboid(-0.29, 0.03, 0.095, 0.1, 0.11, 0.12, {"f": R.ua, "b": R.ua, "s": R.ua, "t": R.cloth, "d": R.skin})
	parts.uarm = k.mesh(m)
	k = Kit.new()
	k.cuboid(-0.21, 0.01, 0.08, 0.085, 0.09, 0.095, {"f": R.fa, "b": R.fa, "s": R.fa, "t": R.cloth, "d": R.skin})
	k.cuboid(-0.3, -0.2, 0.045, 0.085, 0.05, 0.075, {"f": R.hand, "s": R.hand, "t": R.skin})
	parts.farm = k.mesh(m)
	k = Kit.new()
	k.cuboid(-0.46, 0.04, 0.125, 0.14, 0.155, 0.17, {"f": R.th, "b": R.th, "s": R.th, "t": R.pants, "d": R.pants})
	parts.thigh = k.mesh(m)
	k = Kit.new()
	k.cuboid(-0.39, 0.01, 0.1, 0.11, 0.12, 0.13, {"f": R.sh, "b": R.sh, "s": R.sh, "t": R.pants, "d": R.dark})
	k.cuboid(-0.47, -0.38, 0.11, 0.25, 0.1, 0.2, {"f": R.shoe_s, "b": R.shoe_s, "s": R.shoe_s, "t": R.shoe_t, "d": R.dark}, Vector3(0, 0, -0.04))
	parts.shin = k.mesh(m)
	var res := {"d": d, "mat": m, "parts": parts}
	cache[seed] = res
	return res


func _shadow() -> ArrayMesh:
	if shadow_mesh:
		return shadow_mesh
	var im := Image.create(2, 2, false, Image.FORMAT_RGB8)
	im.fill(Color(0.03, 0.03, 0.04))
	var k := Kit.new(Vector2(2, 2))
	k.disc(Vector3(0, 0.012, 0), 0.32, 6, Rect2(0, 0, 2, 2))
	shadow_mesh = k.mesh(_mat(ImageTexture.create_from_image(im)))
	return shadow_mesh


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
	body.add_child(_mi(p.pelvis))
	var chest := Node3D.new()
	chest.position = Vector3(0, 0.98, 0)
	body.add_child(chest)
	var t := _mi(p.torso, Vector3(0, -0.98, 0))
	chest.add_child(t)
	var r := {"root": root, "body": body, "chest": chest, "hips": [], "knees": [], "shoulders": [], "elbows": []}
	for sx in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(sx * 0.255, 1.41 - 0.98, 0)
		chest.add_child(sh)
		sh.add_child(_mi(p.uarm))
		var el := Node3D.new()
		el.position = Vector3(0, -0.28, 0)
		sh.add_child(el)
		el.add_child(_mi(p.farm))
		r.shoulders.append(sh)
		r.elbows.append(el)
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.085, 0.9, 0)
		body.add_child(hip)
		hip.add_child(_mi(p.thigh))
		var kn := Node3D.new()
		kn.position = Vector3(0, -0.44, 0)
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
		var a := s * sg * 0.5 * amt
		r.hips[i].rotation.x = a
		var ph := phase + (0.0 if i == 0 else PI)
		r.knees[i].rotation.x = -maxf(0.0, -sin(ph + 0.9)) * 0.7 * amt
		r.shoulders[i].rotation.x = -a * 0.8
		r.shoulders[i].rotation.z = (-0.06 if i == 0 else 0.06)
		r.elbows[i].rotation.x = 0.18 + maxf(0.0, -a) * 0.5 * amt
	r.body.position.y = absf(cos(phase)) * 0.03 * amt
	r.chest.rotation.y = s * 0.08 * amt
