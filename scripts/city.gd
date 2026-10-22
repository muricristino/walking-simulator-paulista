extends Node

const Tex := preload("res://scripts/tex.gd")
const Geo := preload("res://scripts/geo.gd")
const Player := preload("res://scripts/player.gd")
const Autowalk := preload("res://scripts/autowalk.gd")
const People := preload("res://scripts/people.gd")
const Katcho := preload("res://scripts/katcho.gd")
const Props := preload("res://scripts/props.gd")
const OsmCity := preload("res://scripts/osm_city.gd")
const RioClaro := preload("res://scripts/rio_claro.gd")
const PS1 := preload("res://scripts/ps1.gdshader")
const RES := Vector2i(640, 480)
const CROSS := [-150.0, -380.0, -560.0]
const MASP_Z := Vector2(-131.0, -53.0)
const ROAD := "b_128"

var vp: SubViewport
var world: Node3D
var geo: Geo
var rng := RandomNumberGenerator.new()
var lamps := 0
var walls: StaticBody3D
var floors: StaticBody3D
var player: CharacterBody3D
var movers := []
var walkers := []
var people := People.new()
var katcho := Katcho.new()
var props := Props.new()
var ped_vars := []
var statics := []
var rio: RefCounted
var goal_label: Label
var goal_done := false
var goal_t := 0.0
var placed := []
var lod_t := 0.0


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
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	world = Node3D.new()
	vp.add_child(world)
	walls = StaticBody3D.new()
	walls.collision_layer = 1
	world.add_child(walls)
	floors = StaticBody3D.new()
	floors.collision_layer = 2
	floors.collision_mask = 0
	world.add_child(floors)
	solid(Vector3(65, -0.5, -350), Vector3(270, 1, 900), true)
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
	_bounds()
	_camera()
	_screen()
	_hud()
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


func solid(c: Vector3, size: Vector3, floor := false) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = c
	(floors if floor else walls).add_child(cs)


func _bounds() -> void:
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


var car_colors := [Color(0.85, 0.85, 0.83), Color(0.6, 0.62, 0.64), Color(0.1, 0.1, 0.11), Color(0.6, 0.08, 0.07), Color(0.12, 0.18, 0.35), Color(0.35, 0.36, 0.38), Color(0.9, 0.9, 0.88)]


func _car(x: float, z: float, toward: bool, g: Geo = null) -> void:
	var gg := g if g else geo
	var key := "car%d" % (rng.randi() % car_colors.size())
	if not M.has(key):
		M[key] = mat(Tex.flat(car_colors[int(key.substr(3))], 8, 0.03, 0.2, 40), Color.WHITE)
		geo.add_mat(key, M[key])
		gg.add_mat(key, M[key])
	var f := 1.0 if toward else -1.0
	gg.box(key, Vector3(x, 0.72, z), Vector3(1.8, 0.75, 4.3), Vector2(2, 1))
	if not g:
		solid(Vector3(x, 0.85, z), Vector3(1.9, 1.7, 4.4))
	gg.box(key, Vector3(x, 1.38, z - f * 0.2), Vector3(1.6, 0.56, 2.2), Vector2(2, 1))
	gg.box("dark", Vector3(x, 1.38, z - f * 0.2 + f * 1.11), Vector3(1.5, 0.48, 0.02), Vector2(1, 1))
	gg.box("dark", Vector3(x, 1.38, z - f * 0.2 - f * 1.11), Vector3(1.5, 0.48, 0.02), Vector2(1, 1))
	gg.box("dark", Vector3(x, 0.32, z), Vector3(1.86, 0.5, 3.2), Vector2(1, 1))
	var front := z + f * 2.16
	var back := z - f * 2.16
	for side in [-0.65, 0.65]:
		gg.box("head", Vector3(x + side, 0.85, front), Vector3(0.35, 0.16, 0.04), Vector2(1, 1))
		gg.box("tail", Vector3(x + side, 0.9, back), Vector3(0.35, 0.14, 0.04), Vector2(1, 1))


func _bus(x: float, z: float, toward: bool) -> void:
	if not M.has("bus"):
		M.bus = mat(Tex.stripes(Color(0.88, 0.88, 0.86), Color(0.15, 0.35, 0.6), 2, 8, 6, 41))
		geo.add_mat("bus", M.bus)
		M.bus_win = mat(Tex.flat(Color(0.15, 0.17, 0.2), 8, 0.02, 0.2, 42), Color.WHITE, null, 0.0, Color(0.35, 0.33, 0.25))
		geo.add_mat("bus_win", M.bus_win)
	var f := 1.0 if toward else -1.0
	geo.box("bus", Vector3(x, 1.75, z), Vector3(2.6, 3.0, 12.5), Vector2(4, 3.0))
	solid(Vector3(x, 1.6, z), Vector3(2.7, 3.2, 12.6))
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


func _moving_car(x: float, z: float, v: float) -> void:
	var g := Geo.new()
	for k in geo.mats:
		g.add_mat(k, geo.mats[k])
	_car(0.0, 0.0, false, g)
	var body := AnimatableBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.9, 1.7, 4.4)
	cs.shape = b
	cs.position = Vector3(0, 0.85, 0)
	body.add_child(cs)
	g.build(body)
	body.position = Vector3(x, 0, z)
	world.add_child(body)
	movers.append({"node": body, "v": v, "z0": -420.0, "z1": 50.0})


func _civilian(height: float) -> Dictionary:
	if ped_vars.is_empty():
		ped_vars = katcho.variants()
	var v: Array = ped_vars[rng.randi() % ped_vars.size()]
	var c := katcho.make(v[0], v[1], height)
	var sh := MeshInstance3D.new()
	sh.mesh = people._shadow()
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.root.add_child(sh)
	return c


func _walker(x: float, z: float, dir: float) -> void:
	var hs := rng.randf_range(0.95, 1.05)
	var c := _civilian(1.72 * hs)
	var body := AnimatableBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.5, 1.75 * hs, 0.34)
	cs.shape = b
	cs.position = Vector3(0, 0.875 * hs, 0)
	body.add_child(cs)
	var r: Node3D = c.root
	r.rotation.y = PI
	body.add_child(r)
	body.position = Vector3(x, 0.15, z)
	body.rotation.y = 0.0 if dir < 0.0 else PI
	world.add_child(body)
	var speed: float = c.spec.stride * rng.randf_range(0.95, 1.1)
	katcho.play(c, true, rng.randf() * 2.0)
	walkers.append({"node": body, "c": c, "dir": dir, "speed": speed, "v": speed, "walking": true})


func _physics_process(dt: float) -> void:
	for c in movers:
		var n: Node3D = c.node
		var z: float = n.position.z + c.v * dt
		if z < c.z0:
			z += c.z1 - c.z0
		n.position.z = z
	for w in walkers:
		_walk(w, dt)
	_check_goal(dt)
	lod_t -= dt
	if lod_t <= 0.0 and player:
		lod_t = 0.4
		var pp := player.global_position
		for st in statics:
			var ap: AnimationPlayer = st.ap
			if ap:
				ap.active = (st.pos as Vector3).distance_squared_to(pp) < 900.0


func _walk(w: Dictionary, dt: float) -> void:
	var n: Node3D = w.node
	var want: float = w.speed
	if player:
		var d := player.global_position - n.position
		if absf(d.x) < 0.75 and d.z * w.dir > 0.0 and d.z * w.dir < 1.5:
			want = 0.0
	w.v = lerpf(w.v, want, 1.0 - exp(-6.0 * dt))
	var z: float = n.position.z + w.dir * w.v * dt
	if z < -330.0:
		w.dir = 1.0
		n.rotation.y = PI
	elif z > 45.0:
		w.dir = -1.0
		n.rotation.y = 0.0
	n.position = Vector3(n.position.x, 0.0 if _in_cross(z, z) else 0.15, z)
	var c: Dictionary = w.c
	var moving: bool = w.v > 0.25
	if moving != w.walking:
		w.walking = moving
		katcho.play(c, moving)
	var ap: AnimationPlayer = c.ap
	if ap:
		ap.speed_scale = maxf(w.v, 0.3) / c.spec.stride if moving else 1.0


func _traffic() -> void:
	var lanes := [3.75, 7.25, 10.75]
	for lx in lanes:
		var z := rng.randf_range(-22, -40)
		var v := -rng.randf_range(8.0, 11.5)
		z = 50.0
		while z > -420.0:
			_moving_car(lx, z, v)
			z -= rng.randf_range(18, 42)
		z = rng.randf_range(-62, -70)
		while z > -520.0:
			if not _in_cross(z - 3, z + 3):
				_car(-lx, z, true)
			z -= rng.randf_range(7, 22)
	_bus(14.25, -46.0, false)
	_bus(14.25, -120.0, false)
	_bus(-14.25, -66.0, true)
	_bus(-14.25, -200.0, true)


func _person(p: Vector3) -> void:
	for q in placed:
		if Vector2(p.x - q.x, p.z - q.z).length_squared() < 0.64:
			return
	placed.append(p)
	var hs := rng.randf_range(0.95, 1.05)
	var c := _civilian(1.72 * hs)
	var r: Node3D = c.root
	r.position = p
	r.rotation.y = rng.randf() * TAU
	world.add_child(r)
	katcho.play(c, false, rng.randf() * 4.0, rng.randf_range(0.85, 1.1))
	statics.append({"ap": c.ap, "pos": p})
	solid(p + Vector3(0, 0.875 * hs, 0), Vector3(0.5, 1.75 * hs, 0.32))


func _people() -> void:
	for i in 70:
		var sx := -1.0 if rng.randf() < 0.5 else 1.0
		var z := rng.randf_range(-6, -320)
		if _in_cross(z - 1, z + 1):
			continue
		_person(Vector3(sx * rng.randf_range(23.2, 29), 0.15, z))
	for i in 40:
		_person(Vector3(rng.randf_range(-56, -31), 0.16, rng.randf_range(MASP_Z.x + 2, MASP_Z.y - 2)))
	for i in 10:
		_person(Vector3(rng.randf_range(-15, -5), 0.0, rng.randf_range(-46, -50)))
	for i in 14:
		_person(Vector3(rng.randf_range(23.2, 28.0), 0.15, rng.randf_range(-24, -60)))
	for sx in [-1.0, 1.0]:
		for i in 16:
			_walker(sx * rng.randf_range(20.4, 22.2), rng.randf_range(-320, 40), -1.0 if rng.randf() < 0.5 else 1.0)


func _camera() -> void:
	var args := OS.get_cmdline_user_args()
	player = Player.new()
	player.auto = args.has("--autowalk") or args.has("--shot")
	world.add_child(player)
	var feet := Vector3(21.5, 0.15, -12.0)
	var target := Vector3(-14.0, 9.0, -100.0)
	var at := args.find("--at")
	if at >= 0 and at + 1 < args.size():
		var f := args[at + 1].split_floats(",")
		feet = Vector3(f[0], 0.15, f[1])
		target = Vector3(f[2], f[3], f[4])
	player.setup(feet, target)
	player.capture(true)
	var i := args.find("--autowalk")
	if i >= 0 and i + 1 < args.size():
		var aw := Autowalk.new()
		aw.player = player
		aw.vp = vp
		aw.out = args[i + 1]
		DirAccess.make_dir_recursive_absolute(aw.out)
		add_child(aw)


func _hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	goal_label = Label.new()
	goal_label.text = "Objetivo: chegar à Alameda Rio Claro"
	goal_label.add_theme_font_size_override("font_size", 26)
	goal_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	goal_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02))
	goal_label.add_theme_constant_override("outline_size", 6)
	goal_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_label.position = Vector2(-300, 14)
	goal_label.size = Vector2(600, 40)
	cl.add_child(goal_label)


func _check_goal(dt: float) -> void:
	if not player or not goal_label:
		return
	var p := player.global_position
	if not goal_done and p.x < -38.0 and absf(p.z + 337.0) < 30.0:
		goal_done = true
		goal_t = 6.0
		goal_label.text = "Você chegou à Alameda Rio Claro!"
		goal_label.add_theme_font_size_override("font_size", 40)
	if goal_done and goal_t > 0.0:
		goal_t -= dt
		if goal_t <= 0.0:
			goal_label.text = "Alameda Rio Claro"
			goal_label.add_theme_font_size_override("font_size", 22)


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
