extends RefCounted

const PS1 := preload("res://scripts/ps1.gdshader")
const MO := "res://assets/cars/moidev/"
const GG := "res://assets/cars/ggbot/"
const SU := "res://assets/cars/sunfl0w/"
const SILVER := Color(0.74, 0.76, 0.8)
const PEARL := Color(0.9, 0.9, 0.88)

const MODELS := {
	"sedan": {"path": MO + "sedan.obj", "len": 4.55, "wheels": false, "yaw": PI, "light": Vector3(0.34, 0.43, 0.32)},
	"sedan2": {"path": GG + "Car2.obj", "len": 4.45, "wheels": true, "yaw": PI, "light": Vector3(0.33, 0.4, 0.28)},
	"hatch": {"path": GG + "Car3.obj", "len": 3.85, "wheels": true, "yaw": PI, "light": Vector3(0.33, 0.42, 0.3)},
	"sedan5": {"path": GG + "Car5.obj", "len": 4.55, "wheels": true, "yaw": PI, "light": Vector3(0.33, 0.4, 0.28)},
	"german": {"path": SU + "GermanCar.fbx", "len": 4.6, "wheels": false, "yaw": 0.0, "light": Vector3(0.33, 0.42, 0.3)},
}

const VARIANTS := [
	["sedan", MO + "sedan_white.png", Color.WHITE, 3.0],
	["sedan", MO + "sedan_white.png", SILVER, 3.0],
	["sedan", MO + "sedan_black.png", Color.WHITE, 2.0],
	["sedan", MO + "sedan_red.png", Color.WHITE, 0.8],
	["sedan", MO + "sedan_blue.png", Color.WHITE, 0.5],
	["sedan", MO + "sedan_brown.png", Color.WHITE, 0.4],
	["sedan", MO + "sedan_persian_blue.png", Color.WHITE, 0.4],
	["taxi", MO + "sedan_white.png", PEARL, 2.0],
	["sedan5", GG + "car5_grey.png", Color.WHITE, 2.0],
	["sedan5", GG + "car5.png", Color.WHITE, 0.5],
	["sedan5", GG + "car5_green.png", Color.WHITE, 0.4],
	["sedan2", GG + "car2_black.png", Color.WHITE, 1.5],
	["sedan2", GG + "car2.png", Color.WHITE, 0.7],
	["sedan2", GG + "car2_red.png", Color.WHITE, 0.5],
	["hatch", GG + "car3.png", Color.WHITE, 0.7],
	["hatch", GG + "car3_red.png", Color.WHITE, 0.6],
	["hatch", GG + "car3_yellow.png", Color.WHITE, 0.3],
	["german", SU + "GermanCarTexture.png", Color.WHITE, 1.5],
	["german", SU + "GermanCarTexture.png", PEARL * 1.08, 0.8],
]

const AREAS := [Color(0.16, 0.42, 0.75), Color(0.1, 0.5, 0.28), Color(0.72, 0.12, 0.1), Color(0.92, 0.7, 0.08), Color(0.88, 0.42, 0.08), Color(0.45, 0.1, 0.15), Color(0.42, 0.62, 0.86)]
const ROUTES := [["875A-10", "PERDIZES"], ["702U-10", "BELEM"], ["669A-10", "PRINC ISABEL"], ["6913-10", "BANDEIRA"], ["N137-11", "TERM PQ D PEDRO"], ["7545-10", "STA CRUZ"]]
const LIVERIES := [[0, 0], [1, 1], [2, 2], [3, 3], [4, 4], [6, 5], [5, 0]]
const BUS := Vector3(2.55, 2.9, 12.4)
const BUS_Y0 := 0.32

const FONT := {
	"0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
	"4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001001010010",
	"8": "111101111101111", "9": "111101111001111", "A": "010101111101101", "B": "110101110101110",
	"C": "011100100100011", "D": "110101101101110", "E": "111100110100111", "F": "111100110100100",
	"G": "011100101101011", "H": "101101111101101", "I": "111010010010111", "J": "001001001101010",
	"K": "101101110101101", "L": "100100100100111", "M": "101111111101101", "N": "110101101101101",
	"O": "010101101101010", "P": "110101110100100", "Q": "010101101110011", "R": "110101110101101",
	"S": "011100010001110", "T": "111010010010010", "U": "101101101101111", "V": "101101101101010",
	"W": "101101111111101", "X": "101101010101101", "Y": "101101010010010", "Z": "111001010100111",
	"-": "000000111000000", " ": "000000000000000",
}

static var _meshes := {}
static var _mats := {}
static var _bounds := {}
static var _total_w := 0.0


static func mat(tex: Texture2D, tint := Color.WHITE, glow_tex: Texture2D = null, glow := 0.0, affine := 0.25, unshaded := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("tint", tint)
	if glow_tex:
		m.set_shader_parameter("glow_tex", glow_tex)
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("affine", affine)
	m.set_shader_parameter("unshaded", unshaded)
	return m


static func _cached_mat(key: String, make: Callable) -> ShaderMaterial:
	if not _mats.has(key):
		_mats[key] = make.call()
	return _mats[key]


static func _white() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


static func _lights_mat() -> ShaderMaterial:
	return _cached_mat("lights", func() -> ShaderMaterial: return mat(_white(), Color.WHITE, null, 0.0, 0.0, 1.0))


static func pick(r: float) -> int:
	if _total_w <= 0.0:
		for v in VARIANTS:
			_total_w += v[3]
	var t := r * _total_w
	for i in VARIANTS.size():
		t -= VARIANTS[i][3]
		if t <= 0.0:
			return i
	return VARIANTS.size() - 1


static func variant_of(kind: String, rng: RandomNumberGenerator) -> int:
	var ids := []
	for i in VARIANTS.size():
		if VARIANTS[i][0] == kind:
			ids.append(i)
	if ids.is_empty():
		return pick(rng.randf())
	return ids[rng.randi() % ids.size()]


static func make_car(kind := "", variant := -1, rng: RandomNumberGenerator = null) -> Node3D:
	if kind == "bus":
		return make_bus(variant, rng)
	var r := rng if rng else RandomNumberGenerator.new()
	var vi := variant
	if vi < 0 or vi >= VARIANTS.size():
		vi = variant_of(kind, r) if kind != "" else pick(r.randf())
	var v: Array = VARIANTS[vi]
	var k: String = v[0]
	var mesh := _mesh(k)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body_mat := _cached_mat("%s|%s" % [v[1], v[2]], func() -> ShaderMaterial: return mat(load(v[1]), v[2]))
	for si in mesh.get_surface_count():
		var sn := mesh.surface_get_name(si)
		if sn == "body":
			mi.set_surface_override_material(si, body_mat)
		elif sn == "wheels":
			mi.set_surface_override_material(si, _cached_mat("wheel", func() -> ShaderMaterial: return mat(load(GG + "wheel.png"))))
		elif sn == "lights":
			mi.set_surface_override_material(si, _lights_mat())
		elif sn == "taxi":
			mi.set_surface_override_material(si, _cached_mat("taxi", _taxi_mat))
	var root := Node3D.new()
	root.name = "Car"
	root.add_child(mi)
	var size: Vector3 = _bounds[k]
	root.set_meta("kind", k)
	root.set_meta("variant", vi)
	root.set_meta("size", size)
	return root


static func size_of(kind: String) -> Vector3:
	if kind == "bus":
		return BUS + Vector3(0, BUS_Y0, 0)
	_mesh(kind)
	return _bounds[kind]


static func _rel_xf(n: Node, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var c := n
	while c and c != root:
		if c is Node3D:
			xf = (c as Node3D).transform * xf
		c = c.get_parent()
	return xf


static func _parts(spec: Dictionary) -> Array:
	var out := []
	var res = load(spec.path)
	if res is Mesh:
		for si in res.get_surface_count():
			out.append([res, si, Transform3D.IDENTITY, "body"])
		if spec.wheels:
			var b: AABB = res.get_aabb()
			var wm: Mesh = load(GG + "Wheel.obj")
			var r := 0.4586
			var hx := b.size.x * 0.5 - 0.16
			var zc := b.get_center().z
			var hz := b.size.z * 0.31
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var xf := Transform3D(Basis(Vector3.UP, PI if sx < 0 else 0.0), Vector3(b.get_center().x + sx * hx, r, zc + sz * hz))
					out.append([wm, 0, xf, "wheels"])
	elif res is PackedScene:
		var inst: Node = res.instantiate()
		for c in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			var xf := _rel_xf(mi, inst)
			for si in mi.mesh.get_surface_count():
				out.append([mi.mesh, si, xf, "body"])
		inst.free()
	return out


static func _mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var base := "sedan" if kind == "taxi" else kind
	var spec: Dictionary = MODELS[base]
	var parts := _parts(spec)
	var pre := Transform3D(Basis(Vector3.UP, spec.yaw), Vector3.ZERO)
	var box := AABB()
	var first := true
	for p in parts:
		var m: Mesh = p[0]
		var arr := m.surface_get_arrays(p[1])
		var xf: Transform3D = pre * p[2]
		for v in arr[Mesh.ARRAY_VERTEX]:
			var w: Vector3 = xf * v
			if first:
				box = AABB(w, Vector3.ZERO)
				first = false
			else:
				box = box.expand(w)
	var k: float = spec.len / maxf(box.size.z, 0.01)
	var fix := Transform3D(Basis().scaled(Vector3(k, k, k)), Vector3.ZERO) * Transform3D(Basis(), -Vector3(box.get_center().x, box.position.y, box.get_center().z))
	var size := box.size * k
	var tools := {}
	for p in parts:
		var key: String = p[3]
		if not tools.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = st
		tools[key].append_from(p[0], p[1], fix * pre * p[2])
	var mesh := ArrayMesh.new()
	for key in ["body", "wheels"]:
		if tools.has(key):
			var st: SurfaceTool = tools[key]
			st.commit(mesh)
			mesh.surface_set_name(mesh.get_surface_count() - 1, key)
	_lights(mesh, size, spec.light)
	if kind == "taxi":
		_taxi_sign(mesh, size)
	_meshes[kind] = mesh
	_bounds[kind] = size
	return mesh


static func _quad(st: SurfaceTool, c: Vector3, w: float, h: float, n: Vector3, col: Color, uv0 := Vector2.ZERO, uv1 := Vector2.ONE) -> void:
	var right := Vector3.UP.cross(n).normalized() * w * 0.5
	var up := Vector3.UP * h * 0.5
	var p := [c - right - up, c + right - up, c + right + up, c - right + up]
	var uv := [Vector2(uv0.x, uv1.y), Vector2(uv1.x, uv1.y), Vector2(uv1.x, uv0.y), Vector2(uv0.x, uv0.y)]
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(p[i])


static func _lights(mesh: ArrayMesh, size: Vector3, l: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := size.y * l.y
	var hz := size.z * 0.5 + 0.015
	for sx in [-1.0, 1.0]:
		var x: float = sx * size.x * l.x
		_quad(st, Vector3(x, y, -hz), 0.2, 0.08, Vector3.FORWARD, Color(0.82, 0.78, 0.62))
		_quad(st, Vector3(x * 1.05, y + size.y * 0.05, hz), 0.22, 0.08, Vector3.BACK, Color(0.85, 0.05, 0.03))
	st.commit(mesh)
	mesh.surface_set_name(mesh.get_surface_count() - 1, "lights")


static func _taxi_sign(mesh: ArrayMesh, size: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3(0, size.y + 0.08, 0.15)
	var w := 0.62
	var h := 0.16
	var d := 0.2
	_quad(st, c + Vector3(0, 0, -d * 0.5), w, h, Vector3.FORWARD, Color.WHITE)
	_quad(st, c + Vector3(0, 0, d * 0.5), w, h, Vector3.BACK, Color.WHITE)
	_quad(st, c + Vector3(w * 0.5, 0, 0), d, h, Vector3.RIGHT, Color.WHITE, Vector2(0, 0), Vector2(0.1, 1))
	_quad(st, c + Vector3(-w * 0.5, 0, 0), d, h, Vector3.LEFT, Color.WHITE, Vector2(0, 0), Vector2(0.1, 1))
	var top := c + Vector3(0, h * 0.5, 0)
	for i in [[-1, -1], [1, 1], [1, -1], [-1, -1], [-1, 1], [1, 1]]:
		st.set_color(Color.WHITE)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.02, 0.1))
		st.add_vertex(top + Vector3(i[0] * w * 0.5, 0, i[1] * d * 0.5))
	st.commit(mesh)
	mesh.surface_set_name(mesh.get_surface_count() - 1, "taxi")


static func _taxi_mat() -> ShaderMaterial:
	var img := Image.create(32, 8, false, Image.FORMAT_RGB8)
	img.fill(Color(0.92, 0.92, 0.88))
	var gl := Image.create(32, 8, false, Image.FORMAT_RGB8)
	gl.fill(Color(0.35, 0.35, 0.3))
	text(img, "TAXI", 9, 2, Color(0.08, 0.08, 0.1), 1)
	text(gl, "TAXI", 9, 2, Color.BLACK, 1)
	return mat(ImageTexture.create_from_image(img), Color.WHITE, ImageTexture.create_from_image(gl), 1.0, 0.1)


static func text(img: Image, s: String, x: int, y: int, col: Color, scale := 1) -> int:
	var cx := x
	for ch in s.to_upper():
		var g: String = FONT.get(ch, FONT[" "])
		for gy in 5:
			for gx in 3:
				if g[gy * 3 + gx] == "1":
					for sy in scale:
						for sx in scale:
							var px := cx + gx * scale + sx
							var py := y + gy * scale + sy
							if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
								img.set_pixel(px, py, col)
		cx += 4 * scale
	return cx


static func text_width(s: String, scale := 1) -> int:
	return s.length() * 4 * scale - scale


static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color, grain := 0.0, rng: RandomNumberGenerator = null) -> void:
	for y in range(maxi(y0, 0), mini(y1, img.get_height())):
		for x in range(maxi(x0, 0), mini(x1, img.get_width())):
			var c := col
			if grain > 0.0 and rng:
				var g := rng.randf_range(-grain, grain)
				c = Color(clampf(c.r + g, 0, 1), clampf(c.g + g, 0, 1), clampf(c.b + g, 0, 1))
			img.set_pixel(x, y, c)


static func _glass(img: Image, x0: int, y0: int, x1: int, y1: int, rng: RandomNumberGenerator) -> void:
	for y in range(y0, y1):
		var t := float(y - y0) / maxf(y1 - y0, 1)
		var base := Color(0.2, 0.24, 0.29).lerp(Color(0.07, 0.08, 0.1), t)
		for x in range(x0, x1):
			var c := base
			if (x + y) % 23 < 2:
				c = c.lightened(0.12)
			img.set_pixel(x, y, Color(clampf(c.r + rng.randf_range(-0.015, 0.015), 0, 1), c.g, c.b))


static func _side_tex(area: Color, route: Array, doors: bool, front_right: bool, rng: RandomNumberGenerator) -> Array:
	var w := 248
	var h := 58
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var gl := Image.create(w, h, false, Image.FORMAT_RGB8)
	gl.fill(Color.BLACK)
	var white := Color(0.88, 0.88, 0.86)
	_rect(img, 0, 0, w, h, white, 0.015, rng)
	var fx := func(a: int, b: int) -> Vector2i:
		return Vector2i(w - b, w - a) if front_right else Vector2i(a, b)
	_glass(img, 0, 6, w, 26, rng)
	var p := 24
	while p < w - 4:
		var r: Vector2i = fx.call(p, p + 2)
		_rect(img, r.x, 6, r.y, 26, Color(0.1, 0.1, 0.11))
		p += 30
	_rect(img, 0, 33, w, 51, area, 0.02, rng)
	_rect(img, 0, 30, w, 32, area.darkened(0.2))
	var sweep := 0
	while sweep < 26:
		var r: Vector2i = fx.call(150 + sweep * 3, 172 + sweep * 3)
		_rect(img, r.x, 33 + (sweep >> 1), r.y, 34 + (sweep >> 1), white)
		sweep += 1
	_rect(img, 0, 51, w, h, Color(0.16, 0.16, 0.17))
	if doors:
		for d in [[6, 28], [118, 140], [196, 218]]:
			var r: Vector2i = fx.call(d[0], d[1])
			_rect(img, r.x - 1, 4, r.y + 1, 54, Color(0.12, 0.12, 0.13))
			_glass(img, r.x, 6, r.y, 52, rng)
			_rect(img, ((r.x + r.y) >> 1), 6, ((r.x + r.y) >> 1) + 1, 52, Color(0.1, 0.1, 0.11))
	for a in [50, 180]:
		var c: int = (w - a) if front_right else a
		for y in range(44, h):
			for x in range(c - 12, c + 13):
				if Vector2(x - c, y - 57).length() < 12.5 and x >= 0 and x < w:
					img.set_pixel(x, y, Color(0.05, 0.05, 0.06))
	var sr: Vector2i = fx.call(34, 80)
	_rect(img, sr.x, 7, sr.y, 14, Color(0.03, 0.03, 0.03))
	var led := Color(1.0, 0.55, 0.1)
	var num: String = route[0]
	var tx := sr.x + ((sr.y - sr.x - text_width(num)) >> 1)
	text(img, num, tx, 8, led)
	text(gl, num, tx, 8, led)
	var brand := "SPTRANS"
	var bx: int = (w - 100 - text_width(brand)) if front_right else 100
	text(img, brand, bx, 40, white)
	var fleet := "%d %04d" % [rng.randi_range(1, 8), rng.randi_range(100, 9999)]
	var fxp: Vector2i = fx.call(36, 36 + text_width(fleet))
	text(img, fleet, fxp.x, 44, Color(0.05, 0.05, 0.05))
	return [ImageTexture.create_from_image(img), ImageTexture.create_from_image(gl)]


static func _front_tex(area: Color, route: Array, rng: RandomNumberGenerator) -> Array:
	var w := 102
	var h := 116
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var gl := Image.create(w, h, false, Image.FORMAT_RGB8)
	gl.fill(Color.BLACK)
	var white := Color(0.88, 0.88, 0.86)
	_rect(img, 0, 0, w, h, white, 0.015, rng)
	_rect(img, 3, 2, w - 3, 17, Color(0.03, 0.03, 0.03))
	var led := Color(1.0, 0.55, 0.1)
	var num: String = route[0].split("-")[0]
	text(img, num, 6, 5, led, 2)
	text(gl, num, 6, 5, led, 2)
	var dest: String = route[1]
	var dx := maxi(6 + text_width(num, 2) + 4, w - 5 - text_width(dest))
	text(img, dest, dx, 7, led)
	text(gl, dest, dx, 7, led)
	_glass(img, 3, 20, w - 3, 62, rng)
	_rect(img, (w >> 1), 20, (w >> 1) + 1, 62, Color(0.1, 0.1, 0.11))
	_rect(img, 0, 66, w, 100, area, 0.02, rng)
	_rect(img, 0, 63, w, 66, area.darkened(0.2))
	for sx in [6, w - 22]:
		_rect(img, sx, 82, sx + 16, 89, Color(0.95, 0.93, 0.8))
		_rect(gl, sx, 82, sx + 16, 89, Color(1.0, 0.95, 0.8))
	_rect(img, (w >> 1) - 12, 90, (w >> 1) + 12, 97, Color(0.92, 0.92, 0.9))
	_rect(img, (w >> 1) - 12, 90, (w >> 1) + 12, 92, Color(0.1, 0.2, 0.55))
	_rect(img, 0, 100, w, h, Color(0.16, 0.16, 0.17))
	text(img, "SPTRANS", ((w - text_width("SPTRANS")) >> 1), 70, white)
	return [ImageTexture.create_from_image(img), ImageTexture.create_from_image(gl)]


static func _back_tex(area: Color, route: Array, rng: RandomNumberGenerator) -> Array:
	var w := 102
	var h := 116
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var gl := Image.create(w, h, false, Image.FORMAT_RGB8)
	gl.fill(Color.BLACK)
	var white := Color(0.88, 0.88, 0.86)
	_rect(img, 0, 0, w, h, white, 0.015, rng)
	_rect(img, 30, 4, 72, 14, Color(0.03, 0.03, 0.03))
	var led := Color(1.0, 0.55, 0.1)
	var num: String = route[0].split("-")[0]
	var tx := 51 - (text_width(num) >> 1)
	text(img, num, tx, 7, led)
	text(gl, num, tx, 7, led)
	_glass(img, 8, 18, w - 8, 44, rng)
	_rect(img, 0, 50, w, 100, area, 0.02, rng)
	for gy in range(60, 80, 3):
		_rect(img, 22, gy, w - 22, gy + 1, area.darkened(0.45))
	for sx in [2, w - 10]:
		_rect(img, sx, 56, sx + 8, 76, Color(0.8, 0.08, 0.05))
		_rect(gl, sx, 56, sx + 8, 76, Color(1.0, 0.05, 0.03))
	_rect(img, (w >> 1) - 12, 86, (w >> 1) + 12, 93, Color(0.92, 0.92, 0.9))
	_rect(img, 0, 100, w, h, Color(0.16, 0.16, 0.17))
	return [ImageTexture.create_from_image(img), ImageTexture.create_from_image(gl)]


static func _face(st: SurfaceTool, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, n: Vector3, nu: int, nv: int) -> void:
	for j in nv:
		for i in nu:
			var pts := []
			var uvs := []
			for q in [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]:
				var s: float = q.x / nu
				var t: float = q.y / nv
				pts.append(bl.lerp(br, s).lerp(tl.lerp(tr, s), t))
				uvs.append(Vector2(s, 1.0 - t))
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_normal(n)
				st.set_uv(uvs[k])
				st.add_vertex(pts[k])


static func _bus_mesh() -> ArrayMesh:
	if _meshes.has("bus"):
		return _meshes.bus
	var mesh := ArrayMesh.new()
	var hw := BUS.x * 0.5
	var hl := BUS.z * 0.5
	var y0 := BUS_Y0
	var y1 := BUS_Y0 + BUS.y
	var faces := {
		"right": [Vector3(hw, y0, hl), Vector3(hw, y0, -hl), Vector3(hw, y1, -hl), Vector3(hw, y1, hl), Vector3.RIGHT, 8, 2],
		"left": [Vector3(-hw, y0, -hl), Vector3(-hw, y0, hl), Vector3(-hw, y1, hl), Vector3(-hw, y1, -hl), Vector3.LEFT, 8, 2],
		"front": [Vector3(hw, y0, -hl), Vector3(-hw, y0, -hl), Vector3(-hw, y1, -hl), Vector3(hw, y1, -hl), Vector3.FORWARD, 2, 2],
		"back": [Vector3(-hw, y0, hl), Vector3(hw, y0, hl), Vector3(hw, y1, hl), Vector3(-hw, y1, hl), Vector3.BACK, 2, 2],
		"roof": [Vector3(-hw, y1, -hl), Vector3(hw, y1, -hl), Vector3(hw, y1, hl), Vector3(-hw, y1, hl), Vector3.UP, 1, 8],
	}
	for key in faces:
		var f: Array = faces[key]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_face(st, f[0], f[1], f[2], f[3], f[4], f[5], f[6])
		st.commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wm: Mesh = load(GG + "Wheel.obj")
	var k := 0.52 / 0.4586
	for az in [-hl + 2.5, hl - 3.4]:
		for sx in [-1.0, 1.0]:
			var xf := Transform3D(Basis(Vector3.UP, PI if sx < 0 else 0.0).scaled(Vector3(k, k, k)), Vector3(sx * (hw - 0.17), 0.52, az))
			st.append_from(wm, 0, xf)
	st.commit(mesh)
	mesh.surface_set_name(mesh.get_surface_count() - 1, "wheels")
	_meshes.bus = mesh
	return mesh


static func make_bus(variant := -1, rng: RandomNumberGenerator = null) -> Node3D:
	var r := rng if rng else RandomNumberGenerator.new()
	var li := (variant if variant >= 0 else r.randi()) % LIVERIES.size()
	var ai: int = LIVERIES[li][0]
	var area: Color = AREAS[ai]
	var ri: int = LIVERIES[li][1]
	var route: Array = ROUTES[ri]
	var mesh := _bus_mesh()
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var key := "bus|%d|%d" % [ai, ri]
	var mats: Dictionary = {}
	for face in ["right", "left", "front", "back"]:
		mats[face] = _cached_mat("%s|%s" % [key, face], func() -> ShaderMaterial:
			var t: Array
			if face == "right":
				t = _side_tex(area, route, true, true, r)
			elif face == "left":
				t = _side_tex(area, route, false, false, r)
			elif face == "front":
				t = _front_tex(area, route, r)
			else:
				t = _back_tex(area, route, r)
			return mat(t[0], Color.WHITE, t[1], 1.6, 0.15))
	mats["roof"] = _cached_mat("bus_roof", func() -> ShaderMaterial:
		var img := Image.create(8, 32, false, Image.FORMAT_RGB8)
		_rect(img, 0, 0, 8, 32, Color(0.7, 0.7, 0.69), 0.03, r)
		return mat(ImageTexture.create_from_image(img), Color.WHITE, null, 0.0, 0.15))
	mats["wheels"] = _cached_mat("wheel", func() -> ShaderMaterial: return mat(load(GG + "wheel.png")))
	for si in mesh.get_surface_count():
		mi.set_surface_override_material(si, mats[mesh.surface_get_name(si)])
	var root := Node3D.new()
	root.name = "Bus"
	root.add_child(mi)
	root.set_meta("kind", "bus")
	root.set_meta("variant", li)
	root.set_meta("route", route[0])
	root.set_meta("size", size_of("bus"))
	return root
