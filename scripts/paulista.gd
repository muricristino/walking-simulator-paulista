extends Node

const Tex := preload("res://scripts/tex.gd")
const Geo := preload("res://scripts/geo.gd")
const Props := preload("res://scripts/props.gd")
const OsmCity := preload("res://scripts/osm_city.gd")
const RioClaro := preload("res://scripts/rio_claro.gd")
const Layout := preload("res://scripts/layout.gd")
const CROSS := Layout.CROSS
const MASP_Z := Layout.MASP_Z
const ROAD := "b_128"
const SEED := 7

var city: Node
var world: Node3D
var geo: Geo
var M: Dictionary
var rng := RandomNumberGenerator.new()
var props := Props.new()
var rio: RefCounted


func setup(c: Node) -> void:
	city = c
	world = c.world
	geo = c.geo
	M = c.M
	rng.seed = SEED


func build() -> void:
	_street()
	_buildings()
	_masp()
	_trianon()
	_furniture()


func solid(c: Vector3, size: Vector3, floor := false) -> void:
	city.solid(c, size, floor)


func mat(tex: Texture2D, tint := Color.WHITE, glow_tex: Texture2D = null, glow := 0.0, emit := Color.BLACK, unshaded := 0.0) -> ShaderMaterial:
	return city.mat(tex, tint, glow_tex, glow, emit, unshaded)


func materials() -> void:
	var white := Tex.flat(Color(0.8, 0.8, 0.8), 8, 0.04, 0.2, 1)
	M.asphalt = mat(Tex.plate("res://assets/road/%s.png" % ROAD)) if ROAD != "" else mat(Tex.asphalt(3))
	M.mosaic = mat(Tex.mosaic(4))
	M.concrete = mat(Tex.flat(Color(0.55, 0.53, 0.5), 16, 0.04, 0.4, 5))
	M.curb = mat(Tex.flat(Color(0.62, 0.6, 0.58), 8, 0.03, 0.3, 6))
	if ROAD != "":
		M.bike = mat(Tex.plate("res://assets/road/bike_red.png"))
		M.paint = mat(Tex.plate("res://assets/road/paint_white.png"))
		M.paint_y = mat(Tex.plate("res://assets/road/paint_yellow.png"))
	else:
		M.bike = mat(Tex.flat(Color(0.62, 0.12, 0.1), 16, 0.05, 0.5, 7))
		M.paint = mat(white, Color(0.9, 0.9, 0.85))
		M.paint_y = mat(white, Color(0.95, 0.75, 0.2))
	M.red = mat(Tex.flat(Color(0.78, 0.07, 0.06), 16, 0.04, 0.35, 8))
	M.slab = mat(Tex.flat(Color(0.42, 0.41, 0.4), 16, 0.04, 0.4, 9))
	M.dark = mat(Tex.flat(Color(0.12, 0.12, 0.13), 8, 0.02, 0.2, 10))
	M.metal = mat(Tex.flat(Color(0.3, 0.31, 0.33), 8, 0.03, 0.2, 11))
	M.trunk = mat(Tex.flat(Color(0.25, 0.19, 0.14), 8, 0.04, 0.3, 12))
	M.grass = mat(Tex.flat(Color(0.16, 0.24, 0.1), 16, 0.05, 0.6, 13))
	M.roof = mat(Tex.flat(Color(0.3, 0.29, 0.28), 16, 0.05, 0.5, 14))
	M.lamp = mat(white, Color.WHITE, null, 0.0, Color(1.6, 1.05, 0.55), 1.0)
	M.red_light = mat(white, Color.WHITE, null, 0.0, Color(2.0, 0.08, 0.05), 1.0)
	M.green_light = mat(white, Color.WHITE, null, 0.0, Color(0.1, 1.6, 0.6), 1.0)
	M.amber_off = mat(white, Color(0.2, 0.15, 0.05))
	M.head = mat(white, Color.WHITE, null, 0.0, Color(1.8, 1.7, 1.4), 1.0)
	M.tail = mat(white, Color.WHITE, null, 0.0, Color(1.6, 0.05, 0.03), 1.0)
	M.sign = mat(white, Color.WHITE, null, 0.0, Color(1.6, 0.7, 0.1), 1.0)
	var ms := Tex.masp_glass(15)
	M.masp_glass = mat(ms[0], Color.WHITE, ms[1], 0.9)
	var leaves := [Color(0.13, 0.25, 0.1), Color(0.18, 0.28, 0.09), Color(0.1, 0.2, 0.12)]
	for i in leaves.size():
		M["leaf%d" % i] = mat(Tex.leaves(20 + i, leaves[i]))
	M.tower = mat(Tex.stripes(Color(0.75, 0.1, 0.08), Color(0.85, 0.83, 0.8), 2, 16, 2, 30))
	var placa := FileAccess.file_exists("res://art/placa.png")
	if placa:
		M.placa = mat(Tex.plate("res://art/placa.png"), Color.WHITE)
	for k in M:
		geo.add_mat(k, M[k])


func environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://scripts/sky.gdshader")
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.3, 0.5)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.5, 0.28, 0.36)
	env.fog_density = 1.0
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 520.0
	env.fog_depth_curve = 1.4
	env.fog_aerial_perspective = 0.7
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.55, 0.32)
	sun.light_energy = 0.55
	sun.rotation_degrees = Vector3(-8, 172, 0)
	sun.shadow_enabled = false
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.45, 0.5, 0.85)
	fill.light_energy = 0.25
	fill.rotation_degrees = Vector3(-50, 20, 0)
	world.add_child(fill)


func bounds() -> void:
	var h := 60.0
	var zf := 56.0
	var zb := -700.0
	var m0 := MASP_Z.x - 6.0
	var m1 := MASP_Z.y + 6.0
	solid(Vector3(31.5, h * 0.5, (zf + zb) * 0.5), Vector3(1, h, zf - zb))
	solid(Vector3(-31.5, h * 0.5, (zf + m1) * 0.5), Vector3(1, h, zf - m1))
	solid(Vector3(-31.5, h * 0.5, (m0 - 326.0) * 0.5), Vector3(1, h, m0 + 326.0))
	solid(Vector3(-31.5, h * 0.5, (-348.0 + zb) * 0.5), Vector3(1, h, -348.0 - zb))
	solid(Vector3(-296.0, h * 0.5, -448.0), Vector3(530, h, 1))
	solid(Vector3(-296.0, h * 0.5, -168.0), Vector3(530, h, 1))
	solid(Vector3(-560.0, h * 0.5, -308.0), Vector3(1, h, 280))
	solid(Vector3(-62.5, h * 0.5, (m0 + m1) * 0.5), Vector3(1, h, m1 - m0))
	solid(Vector3(-47.0, h * 0.5, m1 + 0.5), Vector3(31, h, 1))
	solid(Vector3(-47.0, h * 0.5, m0 - 0.5), Vector3(31, h, 1))
	solid(Vector3(0, h * 0.5, zf + 0.5), Vector3(64, h, 1))
	solid(Vector3(0, h * 0.5, zb - 0.5), Vector3(64, h, 1))


func _street() -> void:
	var zf := 60.0
	var zb := -760.0
	geo.ground("asphalt", -16, -2, zb, zf, 0.0, Vector2(4, 4))
	geo.ground("asphalt", 2, 16, zb, zf, 0.0, Vector2(4, 4))
	for c in CROSS:
		geo.ground("asphalt", -140.0, -16.0, c - 9.0, c + 9.0, 0.0)
		geo.ground("asphalt", 16.0, 140.0, c - 9.0, c + 9.0, 0.0)
	geo.ground("asphalt", -2, 2, CROSS[0] - 9.0, CROSS[0] + 9.0, 0.0)
	var segs := [[zf, CROSS[0] + 9.0]]
	for i in CROSS.size():
		var nxt: float = CROSS[i + 1] + 9.0 if i + 1 < CROSS.size() else zb
		segs.append([CROSS[i] - 9.0, nxt])
	for s in segs:
		var z0: float = s[1]
		var z1: float = s[0]
		for sx in [-1.0, 1.0]:
			_raised("mosaic", sx * 16.0, sx * 30.0, z0, z1, 0.15, Vector2(0.8, 0.8))
	for s in [[zf, CROSS[0] + 9.0], [CROSS[0] - 9.0, zb]]:
		_raised("bike", -1.6, 1.6, s[1], s[0], 0.2, Vector2(4, 4))
		_raised("curb", -2.0, -1.6, s[1], s[0], 0.2, Vector2(2, 2))
		_raised("curb", 1.6, 2.0, s[1], s[0], 0.2, Vector2(2, 2))
	var z := zf
	while z > zb:
		var crossing := Layout.in_cross(z - 3.0, z, 2.0) or (z < -42.0 and z > -56.0)
		if not crossing:
			for lx in [5.5, 9.0, 12.5]:
				for sx in [-1.0, 1.0]:
					var w := 0.15
					var x: float = sx * lx
					if lx == 12.5:
						geo.ground("paint", x - w, x + w, z - 9.0, z, 0.02, Vector2(1, 1), 20.0)
					else:
						geo.ground("paint", x - w, x + w, z - 3.0, z, 0.02, Vector2(1, 1), 20.0)
			geo.ground("paint", -0.08, 0.08, z - 2.0, z, 0.21, Vector2(1, 1), 20.0)
		z -= 9.0
	for c in [-48.0] + CROSS:
		_zebra(c)


func _zebra(zc: float) -> void:
	var x := -15.5
	while x < 15.5:
		if absf(x) > 2.2:
			geo.ground("paint", x, x + 0.6, zc - 3.0, zc + 3.0, 0.02, Vector2(1, 1), 20.0)
		x += 1.2
	for sx in [-1.0, 1.0]:
		geo.ground("paint", sx * 2.2 if sx > 0 else -15.8, 15.8 if sx > 0 else -2.2, zc + 4.2, zc + 4.6, 0.02, Vector2(1, 1), 40.0)


func _raised(key: String, xa: float, xb: float, z0: float, z1: float, h: float, unit: Vector2) -> void:
	var x0 := minf(xa, xb)
	var x1 := maxf(xa, xb)
	geo.ground(key, x0, x1, z0, z1, h, unit)
	solid(Vector3((x0 + x1) * 0.5, h - 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, 1.0, z1 - z0), true)
	geo.quad("curb", Vector3(x0, 0, z1), Vector3(x0, 0, z0), Vector3(x0, h, z0), Vector3(x0, h, z1), Vector3.LEFT, Vector2(2, 0.5))
	geo.quad("curb", Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x1, h, z1), Vector3(x1, h, z0), Vector3.RIGHT, Vector2(2, 0.5))
	geo.quad("curb", Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, h, z1), Vector3(x0, h, z1), Vector3.BACK, Vector2(2, 0.5))
	geo.quad("curb", Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, h, z0), Vector3(x0, h, z0), Vector3.FORWARD, Vector2(2, 0.5))


func _buildings() -> void:
	geo.ground("slab", 30.0, 260.0, -820.0, 120.0, 0.05, Vector2(4, 4), 40.0)
	geo.ground("slab", -260.0, -30.0, -820.0, -450.0, 0.05, Vector2(4, 4), 40.0)
	geo.ground("slab", -260.0, -30.0, -170.0, 120.0, 0.05, Vector2(4, 4), 40.0)
	geo.ground("slab", -34.0, -30.0, -450.0, -170.0, 0.05, Vector2(4, 4), 40.0)
	solid(Vector3(-50.0, -0.5, -500.0), Vector3(40, 1, 400), true)
	rio = RioClaro.new()
	rio.build(world, 34.0)
	var osm := OsmCity.new()
	osm.corridors = [rio.corridor()]
	osm.zrange = Vector2(-760.0, 70.0)
	for c in CROSS:
		osm.gaps.append(Vector2(c, 11.0))
	osm.set_glow(0.18)
	world.add_child(osm.build("res://assets/osm/paulista.json"))


func _masp() -> void:
	var z0 := MASP_Z.x
	var z1 := MASP_Z.y
	var xa := -29.0
	var xb := -57.0
	geo.ground("slab", xb - 4.0, -30.0, z0 - 6.0, z1 + 6.0, 0.16, Vector2(3, 3))
	solid(Vector3((xb - 4.0 - 30.0) * 0.5, -0.34, (z0 + z1) * 0.5), Vector3(absf(xb - 4.0 + 30.0), 1.0, z1 - z0 + 12.0), true)
	for px in [xa, xb]:
		for pz in [z0, z1]:
			geo.box("red", Vector3(px, 12.75, pz), Vector3(2.4, 25.5, 3.6), Vector2(3, 3))
			solid(Vector3(px, 12.75, pz), Vector3(2.4, 25.5, 3.6))
	for px in [xa, xb]:
		geo.box("red", Vector3(px, 23.8, (z0 + z1) * 0.5), Vector3(2.4, 3.4, z1 - z0 + 3.6), Vector2(3, 3))
		geo.box("red", Vector3(px, 8.7, (z0 + z1) * 0.5), Vector3(2.4, 2.6, z1 - z0 + 3.6), Vector2(3, 3))
	geo.box("masp_glass", Vector3((xa + xb) * 0.5, 15.65, (z0 + z1) * 0.5), Vector3(absf(xa - xb) - 0.4, 12.5, z1 - z0 - 2.0), Vector2(z1 - z0, 12.5), Vector2.ZERO, 8.0, "slab")
	for i in 5:
		geo.box("dark", Vector3(-30.0 - i * 0.2, 0.6 + i * 0.3, (z0 + z1) * 0.5 - 18.0 - i * 0.6), Vector3(3.0, 0.3, 4.0), Vector2(2, 2))
		solid(Vector3(-30.0 - i * 0.2, 0.6 + i * 0.3, (z0 + z1) * 0.5 - 18.0 - i * 0.6), Vector3(3.0, 0.3, 4.0))


func _trianon() -> void:
	geo.ground("grass", 30.0, 92.0, MASP_Z.x, MASP_Z.y, 0.3, Vector2(4, 4))
	geo.box("concrete", Vector3(30.5, 0.6, (MASP_Z.x + MASP_Z.y) * 0.5), Vector3(0.6, 1.2, MASP_Z.y - MASP_Z.x), Vector2(2, 1))
	solid(Vector3(30.5, 0.6, (MASP_Z.x + MASP_Z.y) * 0.5), Vector3(0.6, 1.2, MASP_Z.y - MASP_Z.x))
	for i in 70:
		var p := Vector3(rng.randf_range(33, 90), 0.3, rng.randf_range(MASP_Z.x + 3, MASP_Z.y - 3))
		_tree(p, rng.randf_range(1.2, 1.9))


func _tree(p: Vector3, s: float) -> void:
	var trunk_h := 2.8 * s
	solid(p + Vector3(0, trunk_h * 0.5, 0), Vector3(0.45 * s, trunk_h, 0.45 * s))
	_place(props.tree(p, s * 0.85, rng.randi()), Transform3D.IDENTITY)


func _bake(node: Node3D, xf: Transform3D) -> void:
	for c in node.get_children():
		if not c is Node3D:
			continue
		var cx: Transform3D = xf * (c as Node3D).transform
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var mi := c as MeshInstance3D
			for si in mi.mesh.get_surface_count():
				var mt: Material = mi.material_override
				if mt == null:
					mt = mi.get_surface_override_material(si)
				if mt == null:
					mt = mi.mesh.surface_get_material(si)
				var key := "prop%d_%d" % [mt.get_instance_id(), si]
				if not geo.mats.has(key):
					geo.add_mat(key, mt)
				geo.tools_append(key, mi.mesh, si, cx)
		_bake(c, cx)


func _place(n: Node3D, xf: Transform3D) -> void:
	_bake(n, xf * n.transform)
	n.free()


func _lamp_post(x: float, z: float, light: bool) -> void:
	var sx := signf(x)
	solid(Vector3(x, 3.75, z), Vector3(0.35, 7.5, 0.35))
	var lp := props.lamp()
	_place(lp, Transform3D(Basis(Vector3.UP, -sx * PI * 0.5), Vector3(x, 0.15, z)))
	if rng.randf() < 0.5:
		var tc := props.trash()
		_place(tc, Transform3D(Basis(), Vector3(x + sx * 0.6, 0.15, z + 0.9)))
		solid(Vector3(x + sx * 0.6, 0.6, z + 0.9), Vector3(0.5, 1.0, 0.5))
	if light:
		var ol := OmniLight3D.new()
		ol.position = Vector3(x, 7.0, z)
		ol.light_color = Color(1.0, 0.66, 0.36)
		ol.light_energy = 10.0
		ol.omni_range = 17.0
		ol.omni_attenuation = 0.9
		world.add_child(ol)


func _signal(x: float, z: float, facing: float, red: bool) -> void:
	var sx := signf(x)
	geo.box("dark", Vector3(x, 3.0, z), Vector3(0.2, 6.0, 0.2), Vector2(1, 4))
	solid(Vector3(x, 3.0, z), Vector3(0.25, 6.0, 0.25))
	geo.box("dark", Vector3(x - sx * 3.0, 5.9, z), Vector3(6.0, 0.15, 0.15), Vector2(1, 1))
	for hx in [x - sx * 5.5, x]:
		var by: float = 5.0 if hx != x else 3.2
		geo.box("dark", Vector3(hx, by, z), Vector3(0.38, 1.1, 0.3), Vector2(1, 1))
		var fz := z + facing * 0.17
		geo.box("red_light" if red else "amber_off", Vector3(hx, by + 0.34, fz), Vector3(0.22, 0.22, 0.04), Vector2(1, 1))
		geo.box("amber_off", Vector3(hx, by, fz), Vector3(0.22, 0.22, 0.04), Vector2(1, 1))
		geo.box("amber_off" if red else "green_light", Vector3(hx, by - 0.34, fz), Vector3(0.22, 0.22, 0.04), Vector2(1, 1))


func _furniture() -> void:
	var z := -14.0
	var i := 0
	while z > -620.0:
		if not Layout.in_cross(z - 1.0, z + 1.0, 2.0):
			_lamp_post(17.0, z, z > -200.0)
			_lamp_post(-17.0, z - 16.0, z > -200.0)
		z -= 32.0
		i += 1
	for sx in [-1.0, 1.0]:
		var tz := 22.0
		while tz > -600.0:
			if not Layout.in_cross(tz - 3.0, tz + 3.0, 2.0) and not (sx < 0 and tz < MASP_Z.y + 22 and tz > MASP_Z.x - 4):
				if rng.randf() < 0.75 and not (sx > 0 and tz > -36.0):
					_tree(Vector3(sx * rng.randf_range(18.6, 19.2), 0.15, tz + rng.randf_range(-2, 2)), rng.randf_range(0.9, 1.25))
			tz -= rng.randf_range(11, 16)
	_signal(16.6, -44.0, 1.0, false)
	_signal(-16.6, -52.0, -1.0, true)
	_signal(16.6, CROSS[0] + 10.0, 1.0, false)
	_signal(-16.6, CROSS[0] - 10.0, -1.0, false)
	if M.has("placa"):
		solid(Vector3(19.0, 1.8, -26.0), Vector3(0.15, 3.6, 0.15))
		_place(props.street_sign(Vector3(19.0, 0.15, -26.0)), Transform3D.IDENTITY)
	_banca(Vector3(26.5, 0.15, -36.0))
	for k in 6:
		_place(props.bench(), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-23.0, 0.15, -20.0 - k * 7.0)))
		solid(Vector3(-23.0, 0.6, -20.0 - k * 7.0), Vector3(0.6, 0.9, 1.8))


func _banca(p: Vector3) -> void:
	if not M.has("banca"):
		M.banca = mat(Tex.flat(Color(0.12, 0.32, 0.2), 8, 0.03, 0.3, 50))
		geo.add_mat("banca", M.banca)
		var t := Tex.magazines(51)
		M.mags = mat(t, Color.WHITE, t, 0.55)
		geo.add_mat("mags", M.mags)
	geo.box("banca", p + Vector3(0, 1.35, 0), Vector3(3.0, 2.7, 6.0), Vector2(1, 1))
	solid(p + Vector3(0, 1.35, 0), Vector3(3.0, 2.7, 6.0))
	geo.box("banca", p + Vector3(-0.3, 2.85, 0), Vector3(3.8, 0.25, 6.8), Vector2(1, 1))
	geo.quad("mags", p + Vector3(-1.52, 0.3, 2.8), p + Vector3(-1.52, 0.3, -2.8), p + Vector3(-1.52, 2.5, -2.8), p + Vector3(-1.52, 2.5, 2.8), Vector3.LEFT, Vector2(5.6, 2.2))
	var ol := OmniLight3D.new()
	ol.position = p + Vector3(-2.5, 2.4, 0)
	ol.light_color = Color(0.9, 0.95, 1.0)
	ol.light_energy = 1.2
	ol.omni_range = 6.0
	world.add_child(ol)
