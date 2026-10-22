extends Node

const Tex := preload("res://scripts/tex.gd")
const Geo := preload("res://scripts/geo.gd")
const PS1 := preload("res://scripts/ps1.gdshader")
const RES := Vector2i(320, 240)
const CROSS := [-150.0, -380.0, -560.0]
const MASP_Z := Vector2(-131.0, -53.0)
const SKIP := [[-1.0, -226.0, -184.0]]

var vp: SubViewport
var world: Node3D
var geo: Geo
var rng := RandomNumberGenerator.new()
var lamps := 0


func _ready() -> void:
	rng.seed = 7
	vp = SubViewport.new()
	vp.size = RES
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.audio_listener_enable_3d = false
	add_child(vp)
	var tr := TextureRect.new()
	tr.texture = vp.get_texture()
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(tr)
	world = Node3D.new()
	vp.add_child(world)
	geo = Geo.new()
	_materials()
	_environment()
	_street()
	_buildings()
	_masp()
	_trianon()
	_furniture()
	_traffic()
	_people()
	geo.build(world)
	_camera()
	_screen()
	_maybe_shot()


func mat(tex: Texture2D, tint := Color.WHITE, glow_tex: Texture2D = null, glow := 0.0, emit := Color.BLACK, unshaded := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("tint", tint)
	if glow_tex:
		m.set_shader_parameter("glow_tex", glow_tex)
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("emit", Vector3(emit.r, emit.g, emit.b))
	m.set_shader_parameter("unshaded", unshaded)
	return m


var M := {}


func _materials() -> void:
	var white := Tex.flat(Color(0.8, 0.8, 0.8), 8, 0.04, 0.2, 1)
	M.asphalt = mat(Tex.asphalt(3))
	M.mosaic = mat(Tex.mosaic(4))
	M.concrete = mat(Tex.flat(Color(0.55, 0.53, 0.5), 16, 0.04, 0.4, 5))
	M.curb = mat(Tex.flat(Color(0.62, 0.6, 0.58), 8, 0.03, 0.3, 6))
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


func _environment() -> void:
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
	env.ambient_light_energy = 0.55
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


func _in_cross(z0: float, z1: float, pad := 0.0) -> bool:
	for c in CROSS:
		if z1 > c - 9.0 - pad and z0 < c + 9.0 + pad:
			return true
	return false


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
		var crossing := _in_cross(z - 3.0, z, 2.0) or (z < -42.0 and z > -56.0)
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
	geo.quad("curb", Vector3(x0, 0, z1), Vector3(x0, 0, z0), Vector3(x0, h, z0), Vector3(x0, h, z1), Vector3.LEFT, Vector2(2, 0.5))
	geo.quad("curb", Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x1, h, z1), Vector3(x1, h, z0), Vector3.RIGHT, Vector2(2, 0.5))
	geo.quad("curb", Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, h, z1), Vector3(x0, h, z1), Vector3.BACK, Vector2(2, 0.5))
	geo.quad("curb", Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, h, z0), Vector3(x0, h, z0), Vector3.FORWARD, Vector2(2, 0.5))


var bld_count := 0
var palettes := [
	[0, Color(0.32, 0.36, 0.38), Color(0.16, 0.26, 0.32)],
	[1, Color(0.62, 0.58, 0.5), Color(0.14, 0.16, 0.18)],
	[2, Color(0.55, 0.5, 0.44), Color(0.12, 0.13, 0.15)],
	[3, Color(0.2, 0.22, 0.25), Color(0.1, 0.18, 0.22)],
	[1, Color(0.48, 0.38, 0.3), Color(0.12, 0.12, 0.13)],
	[0, Color(0.25, 0.28, 0.3), Color(0.2, 0.3, 0.3)],
	[2, Color(0.7, 0.68, 0.62), Color(0.15, 0.15, 0.17)],
	[3, Color(0.18, 0.2, 0.18), Color(0.12, 0.2, 0.16)],
]


func _building(cx: float, cz: float, w: float, d: float, h: float, antenna: bool) -> void:
	bld_count += 1
	var key := "bld%d" % bld_count
	var p: Array = palettes[rng.randi() % palettes.size()]
	var cols := maxi(4, int(maxf(w, d) / 3.0))
	var rows := maxi(4, int(h / 3.6))
	var t := Tex.facade(100 + bld_count, cols, rows, p[0], p[1], p[2], rng.randf_range(0.2, 0.5))
	geo.add_mat(key, mat(t[0], Color.WHITE, t[1], 1.0))
	geo.box(key, Vector3(cx, h * 0.5, cz), Vector3(w, h, d), Vector2(cols * 3.0, rows * 3.6), Vector2.ZERO, 10.0, "roof")
	if rng.randf() < 0.5:
		geo.box("roof", Vector3(cx + rng.randf_range(-w, w) * 0.2, h + 2.5, cz + rng.randf_range(-d, d) * 0.2), Vector3(w * 0.4, 5.0, d * 0.4), Vector2(4, 4))
	if antenna:
		_antenna(Vector3(cx + rng.randf_range(-w, w) * 0.25, h, cz + rng.randf_range(-d, d) * 0.25), rng.randf_range(22, 50), rng.randf() < 0.35)


func _antenna(base: Vector3, height: float, striped: bool) -> void:
	var key := "tower" if striped else "metal"
	var s := height * 0.07 + 1.0
	var legs := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for l in legs:
		var a := base + Vector3(l.x * s, 0, l.y * s)
		var b := base + Vector3(l.x * 0.25, height, l.y * 0.25)
		var mi := _rod(a, b, 0.7, M[key])
		world.add_child(mi)
	var y := 3.0
	while y < height:
		var t := y / height
		var r := lerpf(s, 0.25, t)
		geo.box(key, base + Vector3(0, y, 0), Vector3(r * 2.0, 0.45, r * 2.0), Vector2(1, 2), Vector2.ZERO, 50.0)
		y += 5.0
	geo.box("red_light", base + Vector3(0, height + 0.6, 0), Vector3(1.4, 1.2, 1.4), Vector2(1, 1))
	geo.box("red_light", base + Vector3(0, height * 0.55, 0), Vector3(1.0, 1.0, 1.0) + Vector3(s, 0, s), Vector2(1, 1))
	geo.box(key, base + Vector3(0, height + 5.0, 0), Vector3(0.5, 8.0, 0.5), Vector2(1, 2))


func _rod(a: Vector3, b: Vector3, thick: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(thick, (b - a).length(), thick)
	mi.mesh = bm
	mi.material_override = m
	var up := (b - a).normalized()
	var basis := Basis()
	var side := up.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	basis = Basis(side, up, side.cross(up).normalized())
	mi.transform = Transform3D(basis, (a + b) * 0.5)
	return mi


func _buildings() -> void:
	for sx in [-1.0, 1.0]:
		var z := 40.0
		while z > -720.0:
			var w := rng.randf_range(20, 38)
			var z1 := z
			var z0 := z - w
			if _in_cross(z0, z1, 1.0):
				z = _next_after_cross(z0)
				continue
			if z0 < MASP_Z.y and z1 > MASP_Z.x:
				z = MASP_Z.x - 4.0
				continue
			var skipped := false
			for sk in SKIP:
				if sk[0] == sx and z0 < sk[2] and z1 > sk[1]:
					z = sk[1] - 2.0
					skipped = true
			if skipped:
				continue
			var d := rng.randf_range(22, 34)
			var tall := rng.randf()
			var h := rng.randf_range(26, 55) if tall < 0.4 else rng.randf_range(55, 100)
			var cx: float = sx * (31.0 + d * 0.5 + rng.randf_range(0, 2))
			_building(cx, (z0 + z1) * 0.5, d, w - rng.randf_range(1, 4), h, rng.randf() < 0.8 and h > 40)
			z = z0
		z = 20.0
		while z > -720.0:
			var w := rng.randf_range(24, 44)
			var h := rng.randf_range(70, 160)
			var cx: float = sx * rng.randf_range(78, 110)
			if sx < 0 and z - w < -40.0 and z > -150.0:
				z -= w
				continue
			_building(cx, z - w * 0.5, rng.randf_range(24, 36), w, h, rng.randf() < 0.7)
			z -= w + rng.randf_range(4, 20)
	_gazeta()


func _next_after_cross(z0: float) -> float:
	for c in CROSS:
		if z0 < c + 10.0 and z0 > c - 60.0:
			return c - 10.0
	return z0


func _gazeta() -> void:
	_building(-46.0, -205.0, 30.0, 34.0, 52.0, false)
	_antenna(Vector3(-46.0, 52.0, -205.0), 70.0, true)


func _masp() -> void:
	var z0 := MASP_Z.x
	var z1 := MASP_Z.y
	var xa := -29.0
	var xb := -57.0
	geo.ground("slab", xb - 4.0, -30.0, z0 - 6.0, z1 + 6.0, 0.16, Vector2(3, 3))
	for px in [xa, xb]:
		for pz in [z0, z1]:
			geo.box("red", Vector3(px, 12.75, pz), Vector3(2.4, 25.5, 3.6), Vector2(3, 3))
	for px in [xa, xb]:
		geo.box("red", Vector3(px, 23.8, (z0 + z1) * 0.5), Vector3(2.4, 3.4, z1 - z0 + 3.6), Vector2(3, 3))
		geo.box("red", Vector3(px, 8.7, (z0 + z1) * 0.5), Vector3(2.4, 2.6, z1 - z0 + 3.6), Vector2(3, 3))
	geo.box("masp_glass", Vector3((xa + xb) * 0.5, 15.65, (z0 + z1) * 0.5), Vector3(absf(xa - xb) - 0.4, 12.5, z1 - z0 - 2.0), Vector2(z1 - z0, 12.5), Vector2.ZERO, 8.0, "slab")
	for i in 5:
		geo.box("dark", Vector3(-30.0 - i * 0.2, 0.6 + i * 0.3, (z0 + z1) * 0.5 - 18.0 - i * 0.6), Vector3(3.0, 0.3, 4.0), Vector2(2, 2))


func _trianon() -> void:
	geo.ground("grass", 30.0, 92.0, MASP_Z.x, MASP_Z.y, 0.3, Vector2(4, 4))
	geo.box("concrete", Vector3(30.5, 0.6, (MASP_Z.x + MASP_Z.y) * 0.5), Vector3(0.6, 1.2, MASP_Z.y - MASP_Z.x), Vector2(2, 1))
	for i in 70:
		var p := Vector3(rng.randf_range(33, 90), 0.3, rng.randf_range(MASP_Z.x + 3, MASP_Z.y - 3))
		_tree(p, rng.randf_range(1.2, 1.9))


func _tree(p: Vector3, s: float) -> void:
	var trunk_h := 3.2 * s
	geo.box("trunk", p + Vector3(0, trunk_h * 0.5, 0), Vector3(0.35, trunk_h, 0.35) * Vector3(s, 1, s), Vector2(1, 2))
	var leaf: String = "leaf%d" % (rng.randi() % 3)
	for k in 3:
		var sm := SphereMesh.new()
		var r := rng.randf_range(1.6, 2.4) * s
		sm.radius = r
		sm.height = r * rng.randf_range(1.3, 1.8)
		sm.radial_segments = 6
		sm.rings = 3
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = M[leaf]
		mi.position = p + Vector3(rng.randf_range(-1, 1) * s, trunk_h + rng.randf_range(0.2, 1.6) * s, rng.randf_range(-1, 1) * s)
		mi.rotation.y = rng.randf() * TAU
		world.add_child(mi)


func _lamp_post(x: float, z: float, light: bool) -> void:
	var sx := signf(x)
	geo.box("metal", Vector3(x, 5.0, z), Vector3(0.25, 10.0, 0.25), Vector2(1, 4))
	geo.box("metal", Vector3(x - sx * 1.6, 9.9, z), Vector3(3.2, 0.18, 0.18), Vector2(1, 1))
	geo.box("lamp", Vector3(x - sx * 3.0, 9.75, z), Vector3(0.9, 0.22, 0.4), Vector2(1, 1))
	geo.box("metal", Vector3(x + sx * 0.8, 6.4, z), Vector3(1.6, 0.14, 0.14), Vector2(1, 1))
	geo.box("lamp", Vector3(x + sx * 1.5, 6.25, z), Vector3(0.6, 0.18, 0.3), Vector2(1, 1))
	if light:
		var sl := OmniLight3D.new()
		sl.position = Vector3(x + sx * 1.5, 5.8, z)
		sl.light_color = Color(1.0, 0.72, 0.42)
		sl.light_energy = 4.0
		sl.omni_range = 11.0
		sl.omni_attenuation = 0.9
		world.add_child(sl)
		var ol := OmniLight3D.new()
		ol.position = Vector3(x - sx * 3.0, 9.0, z)
		ol.light_color = Color(1.0, 0.68, 0.38)
		ol.light_energy = 9.0
		ol.omni_range = 16.0
		ol.omni_attenuation = 0.9
		world.add_child(ol)


func _signal(x: float, z: float, facing: float, red: bool) -> void:
	var sx := signf(x)
	geo.box("dark", Vector3(x, 3.0, z), Vector3(0.2, 6.0, 0.2), Vector2(1, 4))
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
		if not _in_cross(z - 1.0, z + 1.0, 2.0):
			_lamp_post(17.0, z, z > -200.0)
			_lamp_post(-17.0, z - 16.0, z > -200.0)
		z -= 32.0
		i += 1
	for sx in [-1.0, 1.0]:
		var tz := 22.0
		while tz > -600.0:
			if not _in_cross(tz - 3.0, tz + 3.0, 2.0) and not (sx < 0 and tz < MASP_Z.y + 22 and tz > MASP_Z.x - 4):
				if rng.randf() < 0.75 and not (sx > 0 and tz > -36.0):
					_tree(Vector3(sx * rng.randf_range(18.6, 19.2), 0.15, tz + rng.randf_range(-2, 2)), rng.randf_range(0.9, 1.25))
			tz -= rng.randf_range(11, 16)
	_signal(16.6, -44.0, 1.0, true)
	_signal(-16.6, -52.0, -1.0, true)
	_signal(16.6, CROSS[0] + 10.0, 1.0, false)
	_signal(-16.6, CROSS[0] - 10.0, -1.0, false)
	if M.has("placa"):
		geo.box("metal", Vector3(19.0, 1.8, -26.0), Vector3(0.1, 3.6, 0.1), Vector2(1, 1))
		geo.quad("placa", Vector3(17.7, 2.9, -25.95), Vector3(20.3, 2.9, -25.95), Vector3(20.3, 3.6, -25.95), Vector3(17.7, 3.6, -25.95), Vector3.BACK, Vector2(2.6, 0.7))
	_banca(Vector3(26.5, 0.15, -36.0))
	for k in 6:
		geo.box("dark", Vector3(-23.0, 0.6, -20.0 - k * 7.0), Vector3(0.6, 0.9, 1.8), Vector2(1, 1))


func _banca(p: Vector3) -> void:
	if not M.has("banca"):
		M.banca = mat(Tex.flat(Color(0.12, 0.32, 0.2), 8, 0.03, 0.3, 50))
		geo.add_mat("banca", M.banca)
		var t := Tex.magazines(51)
		M.mags = mat(t, Color.WHITE, t, 0.55)
		geo.add_mat("mags", M.mags)
	geo.box("banca", p + Vector3(0, 1.35, 0), Vector3(3.0, 2.7, 6.0), Vector2(1, 1))
	geo.box("banca", p + Vector3(-0.3, 2.85, 0), Vector3(3.8, 0.25, 6.8), Vector2(1, 1))
	geo.quad("mags", p + Vector3(-1.52, 0.3, 2.8), p + Vector3(-1.52, 0.3, -2.8), p + Vector3(-1.52, 2.5, -2.8), p + Vector3(-1.52, 2.5, 2.8), Vector3.LEFT, Vector2(5.6, 2.2))
	var ol := OmniLight3D.new()
	ol.position = p + Vector3(-2.5, 2.4, 0)
	ol.light_color = Color(0.9, 0.95, 1.0)
	ol.light_energy = 1.2
	ol.omni_range = 6.0
	world.add_child(ol)


var car_colors := [Color(0.85, 0.85, 0.83), Color(0.6, 0.62, 0.64), Color(0.1, 0.1, 0.11), Color(0.6, 0.08, 0.07), Color(0.12, 0.18, 0.35), Color(0.35, 0.36, 0.38), Color(0.9, 0.9, 0.88)]


func _car(x: float, z: float, toward: bool) -> void:
	var key := "car%d" % (rng.randi() % car_colors.size())
	if not M.has(key):
		M[key] = mat(Tex.flat(car_colors[int(key.substr(3))], 8, 0.03, 0.2, 40), Color.WHITE)
		geo.add_mat(key, M[key])
	var f := 1.0 if toward else -1.0
	geo.box(key, Vector3(x, 0.72, z), Vector3(1.8, 0.75, 4.3), Vector2(2, 1))
	geo.box(key, Vector3(x, 1.38, z - f * 0.2), Vector3(1.6, 0.56, 2.2), Vector2(2, 1))
	geo.box("dark", Vector3(x, 1.38, z - f * 0.2 + f * 1.11), Vector3(1.5, 0.48, 0.02), Vector2(1, 1))
	geo.box("dark", Vector3(x, 1.38, z - f * 0.2 - f * 1.11), Vector3(1.5, 0.48, 0.02), Vector2(1, 1))
	geo.box("dark", Vector3(x, 0.32, z), Vector3(1.86, 0.5, 3.2), Vector2(1, 1))
	var front := z + f * 2.16
	var back := z - f * 2.16
	for side in [-0.65, 0.65]:
		geo.box("head", Vector3(x + side, 0.85, front), Vector3(0.35, 0.16, 0.04), Vector2(1, 1))
		geo.box("tail", Vector3(x + side, 0.9, back), Vector3(0.35, 0.14, 0.04), Vector2(1, 1))


func _bus(x: float, z: float, toward: bool) -> void:
	if not M.has("bus"):
		M.bus = mat(Tex.stripes(Color(0.88, 0.88, 0.86), Color(0.15, 0.35, 0.6), 2, 8, 6, 41))
		geo.add_mat("bus", M.bus)
		M.bus_win = mat(Tex.flat(Color(0.15, 0.17, 0.2), 8, 0.02, 0.2, 42), Color.WHITE, null, 0.0, Color(0.35, 0.33, 0.25))
		geo.add_mat("bus_win", M.bus_win)
	var f := 1.0 if toward else -1.0
	geo.box("bus", Vector3(x, 1.75, z), Vector3(2.6, 3.0, 12.5), Vector2(4, 3.0))
	for sx in [-1.31, 1.31]:
		geo.quad("bus_win", Vector3(x + sx, 1.9, z - 5.5), Vector3(x + sx, 1.9, z + 5.5), Vector3(x + sx, 2.9, z + 5.5), Vector3(x + sx, 2.9, z - 5.5), Vector3(signf(sx), 0, 0), Vector2(2, 1))
	var front := z + f * 6.26
	var back := z - f * 6.26
	geo.quad("bus_win", Vector3(x - 1.2, 1.6, front), Vector3(x + 1.2, 1.6, front), Vector3(x + 1.2, 2.8, front), Vector3(x - 1.2, 2.8, front), Vector3(0, 0, f), Vector2(2, 1))
	geo.box("sign", Vector3(x, 3.0, front), Vector3(2.0, 0.3, 0.04), Vector2(1, 1))
	geo.box("dark", Vector3(x, 0.4, z), Vector3(2.66, 0.5, 9.0), Vector2(1, 1))
	for side in [-1.0, 1.0]:
		geo.box("head", Vector3(x + side, 0.8, front), Vector3(0.3, 0.18, 0.04), Vector2(1, 1))
		geo.box("tail", Vector3(x + side * 1.05, 1.0, back), Vector3(0.22, 0.4, 0.04), Vector2(1, 1))


func _traffic() -> void:
	var lanes := [3.75, 7.25, 10.75]
	for lx in lanes:
		var z := rng.randf_range(-22, -40)
		while z > -520.0:
			if not _in_cross(z - 3, z + 3):
				_car(lx, z, false)
			z -= rng.randf_range(9, 30)
		z = rng.randf_range(-62, -70)
		while z > -520.0:
			if not _in_cross(z - 3, z + 3):
				_car(-lx, z, true)
			z -= rng.randf_range(7, 22)
	_bus(14.25, -46.0, false)
	_bus(14.25, -120.0, false)
	_bus(-14.25, -66.0, true)
	_bus(-14.25, -200.0, true)


var skin := [Color(0.85, 0.65, 0.5), Color(0.62, 0.42, 0.3), Color(0.42, 0.28, 0.2), Color(0.75, 0.55, 0.42)]
var shirts := [Color(0.7, 0.15, 0.12), Color(0.15, 0.2, 0.4), Color(0.85, 0.85, 0.8), Color(0.1, 0.1, 0.1), Color(0.75, 0.6, 0.2), Color(0.25, 0.45, 0.3), Color(0.45, 0.45, 0.48)]


func _cmat(prefix: String, list: Array, i: int) -> String:
	var key := "%s%d" % [prefix, i]
	if not M.has(key):
		M[key] = mat(Tex.flat(list[i], 4, 0.03, 0.1, 60 + i))
		geo.add_mat(key, M[key])
	return key


func _person(p: Vector3) -> void:
	var sk := _cmat("skin", skin, rng.randi() % skin.size())
	var sh := _cmat("shirt", shirts, rng.randi() % shirts.size())
	var lg := _cmat("shirt", shirts, [1, 3, 6][rng.randi() % 3])
	var hs := rng.randf_range(0.92, 1.08)
	geo.box(lg, p + Vector3(0, 0.42 * hs, 0), Vector3(0.38, 0.84 * hs, 0.24), Vector2(1, 1))
	geo.box(sh, p + Vector3(0, 1.12 * hs, 0), Vector3(0.48, 0.62 * hs, 0.28), Vector2(1, 1))
	geo.box(sk, p + Vector3(0, 1.57 * hs, 0), Vector3(0.22, 0.26, 0.22), Vector2(1, 1))


func _people() -> void:
	for i in 70:
		var sx := -1.0 if rng.randf() < 0.5 else 1.0
		var z := rng.randf_range(-6, -320)
		if _in_cross(z - 1, z + 1):
			continue
		_person(Vector3(sx * rng.randf_range(20, 29), 0.15, z))
	for i in 40:
		_person(Vector3(rng.randf_range(-56, -31), 0.16, rng.randf_range(MASP_Z.x + 2, MASP_Z.y - 2)))
	for i in 10:
		_person(Vector3(rng.randf_range(-15, -5), 0.0, rng.randf_range(-46, -50)))
	for i in 14:
		_person(Vector3(rng.randf_range(18.5, 28.0), 0.15, rng.randf_range(-24, -60)))


func _camera() -> void:
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.2
	cam.far = 900.0
	cam.position = Vector3(21.5, 2.3, -12.0)
	world.add_child(cam)
	cam.look_at(Vector3(-14.0, 12.5, -100.0))
	cam.current = true


func _screen() -> void:
	var cl := CanvasLayer.new()
	vp.add_child(cl)
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://scripts/screen.gdshader")
	cr.material = sm
	cl.add_child(cr)


func _maybe_shot() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shot")
	if i < 0 or i + 1 >= args.size():
		return
	var path: String = args[i + 1]
	for f in 12:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(path)
	print("shot ", path, " ", img.get_size())
	get_tree().quit()
