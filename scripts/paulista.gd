extends Node

const Tex := preload("res://scripts/tex.gd")
const Geo := preload("res://scripts/geo.gd")
const Props := preload("res://scripts/props.gd")
const OsmCity := preload("res://scripts/osm_city.gd")
const RioClaro := preload("res://scripts/rio_claro.gd")
const Layout := preload("res://scripts/layout.gd")
const PS1 := preload("res://scripts/ps1.gdshader")
const CUT := preload("res://scripts/ps1_cut.gdshader")
const CROSS := Layout.CROSS
const MASP_Z := Layout.MASP_Z
const ROAD := "b_128"
const SEED := 7
const ZF_VIS := 430.0
const ZB_VIS := -1080.0
const XV := 420.0
const STUB := 58.5
const WALK_H := 0.15
const RIO_BOX := Vector2(-456.0, -160.0)
const VALLEY := Rect2(-XV, -128.0, XV - 66.0, 72.0)
const VALLEY_ROAD := Vector2(-92.0, 10.0)
const STAIRS := Layout.MASP_STAIRS
const CONJUNTO := Vector2(348.0, 482.0)
const SIGNS := "res://assets/props/signs/"
const BENCH_BACK := -0.28

var city: Node
var world: Node3D
var geo: Geo
var M: Dictionary
var rng := RandomNumberGenerator.new()
var props := Props.new()
var rio: RefCounted
var osm: OsmCity
var lights := []


func setup(c: Node) -> void:
	city = c
	world = c.world
	geo = c.geo
	M = c.M
	rng.seed = SEED


func build() -> void:
	_street()
	_buildings()
	_valley()
	_masp()
	_trianon()
	_furniture()


func solid(c: Vector3, size: Vector3, floor := false) -> void:
	city.solid(c, size, floor)


func mat(tex: Texture2D, tint := Color.WHITE, glow_tex: Texture2D = null, glow := 0.0, emit := Color.BLACK, unshaded := 0.0) -> ShaderMaterial:
	return city.mat(tex, tint, glow_tex, glow, emit, unshaded)


func _cut(tex: Texture2D, tint := Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CUT
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("tint", tint)
	return m


func _add(key: String, m: Material) -> void:
	M[key] = m
	geo.add_mat(key, m)


func materials() -> void:
	var white := Tex.flat(Color(0.8, 0.8, 0.8), 8, 0.04, 0.2, 1)
	M.asphalt = mat(Tex.plate("res://assets/road/%s.png" % ROAD)) if ROAD != "" else mat(Tex.asphalt(3))
	M.mosaic = mat(Tex.mosaic(4), Color(0.92, 0.92, 0.9))
	M.walk = mat(Tex.plate("res://assets/road/sidewalk_dark.png"))
	M.walk_light = mat(Tex.plate("res://assets/road/sidewalk_light.png"))
	M.tactile = mat(Tex.plate("res://assets/road/tactile.png"))
	M.concrete = mat(Tex.flat(Color(0.55, 0.53, 0.5), 16, 0.04, 0.4, 5))
	M.curb = mat(Tex.flat(Color(0.62, 0.6, 0.58), 8, 0.03, 0.3, 6))
	if ROAD != "":
		M.bike = mat(Tex.plate("res://assets/road/bike_red.png"), Color(1.25, 1.1, 1.1))
		M.paint = mat(Tex.plate("res://assets/road/paint_white.png"))
		M.paint_y = mat(Tex.plate("res://assets/road/paint_yellow.png"))
	else:
		M.bike = mat(Tex.flat(Color(0.62, 0.12, 0.1), 16, 0.05, 0.5, 7))
		M.paint = mat(white, Color(0.9, 0.9, 0.85))
		M.paint_y = mat(white, Color(0.95, 0.75, 0.2))
	M.stencil_bus = _cut(Tex.plate("res://assets/road/onibus.png"))
	M.stencil_bike = _cut(Tex.plate("res://assets/road/bike_symbol.png"))
	M.red = mat(Tex.flat(Color(0.78, 0.07, 0.06), 16, 0.04, 0.35, 8))
	M.slab = mat(Tex.flat(Color(0.42, 0.41, 0.4), 16, 0.04, 0.4, 9))
	M.ground = mat(Tex.flat(Color(0.36, 0.35, 0.34), 16, 0.05, 0.5, 16))
	M.dark = mat(Tex.flat(Color(0.12, 0.12, 0.13), 8, 0.02, 0.2, 10))
	M.metal = mat(Tex.flat(Color(0.3, 0.31, 0.33), 8, 0.03, 0.2, 11))
	M.trunk = mat(Tex.flat(Color(0.25, 0.19, 0.14), 8, 0.04, 0.3, 12))
	M.grass = mat(Tex.flat(Color(0.16, 0.24, 0.1), 16, 0.05, 0.6, 13))
	M.roof = mat(Tex.flat(Color(0.3, 0.29, 0.28), 16, 0.05, 0.5, 14))
	M.wallc = mat(Tex.plate("res://assets/props/concrete.png"), Color(0.75, 0.74, 0.72))
	M.green_metal = mat(Tex.flat(Color(0.1, 0.26, 0.17), 8, 0.03, 0.2, 17))
	M.fence = _cut(Tex.fence(18, Color(0.12, 0.3, 0.2)))
	M.glass = mat(Tex.flat(Color(0.32, 0.4, 0.42), 8, 0.02, 0.1, 19), Color.WHITE, null, 0.0, Color(0.05, 0.06, 0.06))
	M.cavalete = mat(Tex.stripes(Color(0.95, 0.45, 0.08), Color(0.92, 0.92, 0.9), 16, 4, 1, 21, true))
	M.tapume = mat(Tex.flat(Color(0.2, 0.38, 0.3), 16, 0.04, 0.4, 22))
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
	if FileAccess.file_exists("res://art/placa.png"):
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
	env.fog_depth_begin = 25.0
	env.fog_depth_end = 380.0
	env.fog_depth_curve = 1.25
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


func _in_rio_box(z: float) -> bool:
	return z > RIO_BOX.x and z < RIO_BOX.y


func _stub_open(s: Dictionary, sd: int) -> bool:
	return s.sides.has(sd) and not (sd < 0 and _in_rio_box(s.z))


func _street_end(s: Dictionary, sd: int) -> float:
	if sd < 0 and _in_rio_box(s.z):
		return -34.0
	if s.has("len") and s.len.has(sd):
		return sd * float(s.len[sd])
	return sd * XV


func _cuts(sd: int) -> Array:
	var out := []
	for s in Layout.STREETS:
		if s.sides.has(sd):
			out.append(Vector2(s.z - s.half, s.z + s.half))
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return out


func _segments(cuts: Array, z0: float, z1: float) -> Array:
	var segs := []
	var cur := z0
	for c in cuts:
		if cur >= z1:
			break
		if c.x > cur:
			segs.append(Vector2(cur, minf(c.x, z1)))
		cur = maxf(cur, c.y)
	if cur < z1:
		segs.append(Vector2(cur, z1))
	return segs.filter(func(v: Vector2) -> bool: return v.y - v.x > 0.01)


func bounds() -> void:
	var h := 60.0
	var zf := Layout.WALK_Z.y
	var zb := Layout.WALK_Z.x
	var m0 := MASP_Z.x - 6.0
	var m1 := MASP_Z.y + 6.0
	for sd in [-1, 1]:
		var gaps := []
		for s in Layout.STREETS:
			if _stub_open(s, sd):
				var hw: float = s.half + s.walk
				gaps.append(Vector2(s.z - hw, s.z + hw))
				var x0: float = sd * 31.5
				var x1: float = sd * STUB
				for e in [-1.0, 1.0]:
					solid(Vector3((x0 + x1) * 0.5, h * 0.5, s.z + e * (hw + 0.5)), Vector3(absf(x1 - x0) + 1.0, h, 1))
				solid(Vector3(x1 - sd * 1.5, h * 0.5, s.z), Vector3(1, h, 2.0 * hw + 2.0))
		if sd < 0:
			gaps.append(Vector2(m0, m1))
			gaps.append(Layout.RIO_GAP)
		gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		for g in _segments(gaps, zb, zf):
			solid(Vector3(sd * 31.5, h * 0.5, (g.x + g.y) * 0.5), Vector3(1, h, g.y - g.x))
	solid(Vector3(-296.0, h * 0.5, -448.0), Vector3(530, h, 1))
	solid(Vector3(-296.0, h * 0.5, -168.0), Vector3(530, h, 1))
	solid(Vector3(-560.0, h * 0.5, -308.0), Vector3(1, h, 280))
	solid(Vector3(-62.5, h * 0.5, (m0 + m1) * 0.5), Vector3(1, h, m1 - m0))
	solid(Vector3(-47.0, h * 0.5, m1 + 0.5), Vector3(31, h, 1))
	solid(Vector3(-47.0, h * 0.5, m0 - 0.5), Vector3(31, h, 1))
	solid(Vector3(0, h * 0.5, zf + 0.5), Vector3(64, h, 1))
	solid(Vector3(0, h * 0.5, zb - 0.5), Vector3(64, h, 1))


func _street() -> void:
	geo.ground("asphalt", -16, -2, ZB_VIS, ZF_VIS, 0.0, Vector2(4, 4), 6.0)
	geo.ground("asphalt", 2, 16, ZB_VIS, ZF_VIS, 0.0, Vector2(4, 4), 6.0)
	for sd in [-1, 1]:
		_sidewalk(sd)
	for s in Layout.STREETS:
		for sd in s.sides:
			_side_street(s, sd)
	var mid := _segments(_cross_cuts(), ZB_VIS, ZF_VIS)
	for c in CROSS:
		geo.ground("asphalt", -2, 2, c - Layout.CROSS_HALF, c + Layout.CROSS_HALF, 0.0)
		geo.ground("bike", -1.6, 1.6, c - Layout.CROSS_HALF, c + Layout.CROSS_HALF, 0.015, Vector2(4, 4))
	for s in mid:
		_raised("bike", -1.6, 1.6, s.x, s.y, 0.2, Vector2(4, 4), true)
		_raised("curb", -2.0, -1.6, s.x, s.y, 0.2, Vector2(2, 2), true)
		_raised("curb", 1.6, 2.0, s.x, s.y, 0.2, Vector2(2, 2), true)
	_markings()
	for w in Layout.crosswalks():
		_zebra(w.z)


func _cross_cuts() -> Array:
	var out := []
	for c in CROSS:
		out.append(Vector2(c - Layout.CROSS_HALF, c + Layout.CROSS_HALF))
	return out


func _sidewalk(sd: int) -> void:
	var cuts := _cuts(sd)
	for seg in _segments(cuts, ZB_VIS, ZF_VIS):
		var z0: float = seg.x
		var z1: float = seg.y
		var near0 := z0 > ZB_VIS + 1.0
		var near1 := z1 < ZF_VIS - 1.0
		var marks := [z0, z1]
		if near0:
			marks.append(minf(z0 + 6.0, z1))
		if near1:
			marks.append(maxf(z1 - 6.0, z0))
		if sd > 0:
			for c in [CONJUNTO.x, CONJUNTO.y]:
				if c > z0 and c < z1:
					marks.append(c)
		marks.sort()
		for i in marks.size() - 1:
			var a: float = marks[i]
			var b: float = marks[i + 1]
			if b - a < 0.01:
				continue
			var key := "walk"
			if (near0 and b <= z0 + 6.01) or (near1 and a >= z1 - 6.01):
				key = "walk_light"
			elif sd > 0 and a >= CONJUNTO.x - 0.01 and b <= CONJUNTO.y + 0.01:
				key = "mosaic"
			var unit := Vector2(1.5, 1.5) if key != "mosaic" else Vector2(1.6, 1.6)
			geo.ground(key, minf(sd * 16.0, sd * 25.0), maxf(sd * 16.0, sd * 25.0), a, b, WALK_H, unit, 6.0)
			geo.ground(key, minf(sd * 25.4, sd * 30.0), maxf(sd * 25.4, sd * 30.0), a, b, WALK_H, unit, 6.0)
			geo.ground("tactile", minf(sd * 25.0, sd * 25.4), maxf(sd * 25.0, sd * 25.4), a, b, WALK_H, Vector2(0.4, 0.4), 6.0)
		_raised("", sd * 16.0, sd * 30.0, z0, z1, WALK_H, Vector2(1.5, 1.5), true)


func _side_street(s: Dictionary, sd: int) -> void:
	var xe := _street_end(s, sd)
	var x0 := sd * 16.0
	geo.ground("asphalt", minf(x0, xe), maxf(x0, xe), s.z - s.half, s.z + s.half, 0.0, Vector2(4, 4), 6.0)
	var xs := sd * 30.0
	for e in [-1.0, 1.0]:
		var za: float = s.z + e * s.half
		var zb: float = s.z + e * (s.half + s.walk)
		_raised("walk", minf(xs, xe), maxf(xs, xe), minf(za, zb), maxf(za, zb), WALK_H, Vector2(1.5, 1.5))
	if absf(xe) > 40.0:
		var x := sd * 40.0
		while absf(x) < absf(xe) - 6.0:
			geo.ground("paint", minf(x, x + sd * 3.0), maxf(x, x + sd * 3.0), s.z - 0.08, s.z + 0.08, 0.02, Vector2(1, 1), 20.0)
			x += sd * 9.0
	_zebra_side(s, sd)


func _zebra_side(s: Dictionary, sd: int) -> void:
	var z: float = s.z - s.half + 0.4
	while z < s.z + s.half - 0.5:
		geo.ground("paint", minf(sd * 17.5, sd * 21.5), maxf(sd * 17.5, sd * 21.5), z, z + 0.5, 0.02, Vector2(1, 1), 20.0)
		z += 1.0
	geo.ground("paint", minf(sd * 22.4, sd * 22.8), maxf(sd * 22.4, sd * 22.8), s.z - s.half + 0.3, s.z + s.half - 0.3, 0.02, Vector2(1, 1), 20.0)


func _on_zebra(z0: float, z1: float) -> bool:
	for w in Layout.crosswalks():
		if z1 > w.z0 - 5.0 and z0 < w.z1 + 5.0:
			return true
	return false


func _markings() -> void:
	var z := ZF_VIS
	var k := 0
	while z > ZB_VIS:
		var blocked := Layout.in_cross(z - 9.0, z, 1.0) or _on_zebra(z - 9.0, z)
		if not blocked:
			for lx in [5.5, 9.0, 12.5]:
				for sx in [-1.0, 1.0]:
					var w := 0.15 if lx != 12.5 else 0.2
					var x: float = sx * lx
					geo.ground("paint", x - w, x + w, z - (9.0 if lx == 12.5 else 3.0), z, 0.02, Vector2(1, 1), 20.0)
			for dz in [0.0, 3.0, 6.0]:
				geo.ground("paint", -0.06, 0.06, z - dz - 1.5, z - dz, 0.21, Vector2(1, 1), 20.0)
			if k % 5 == 2:
				_stencil("stencil_bike", Vector3(0.8, 0.205, z - 4.5), 1.2, 1.2, 1.0)
				_stencil("stencil_bike", Vector3(-0.8, 0.205, z - 4.5), 1.2, 1.2, -1.0)
			if k % 8 == 4:
				_stencil("stencil_bus", Vector3(14.25, 0.025, z - 4.5), 1.5, 4.5, 1.0)
				_stencil("stencil_bus", Vector3(-14.25, 0.025, z - 4.5), 1.5, 4.5, -1.0)
		z -= 9.0
		k += 1


func _stencil(key: String, c: Vector3, w: float, l: float, dir: float) -> void:
	var hw := w * 0.5 * dir
	var hl := l * 0.5 * dir
	geo.quad(key, c + Vector3(-hw, 0, hl), c + Vector3(hw, 0, hl), c + Vector3(hw, 0, -hl), c + Vector3(-hw, 0, -hl), Vector3.UP, Vector2(w, l), Vector2.ZERO, 20.0)


func _zebra(zc: float) -> void:
	var x := -15.5
	while x < 15.5:
		if absf(x) > 2.2 and absf(x + 0.6) > 2.2:
			geo.ground("paint", x, x + 0.6, zc - 3.0, zc + 3.0, 0.02, Vector2(1, 1), 20.0)
		x += 1.2
	geo.ground("paint", 2.2, 15.8, zc + 4.2, zc + 4.6, 0.02, Vector2(1, 1), 40.0)
	geo.ground("paint", -15.8, -2.2, zc - 4.6, zc - 4.2, 0.02, Vector2(1, 1), 40.0)
	for sx in [-1.0, 1.0]:
		geo.ground("bike", -1.6, 1.6, zc - 3.0, zc + 3.0, 0.205, Vector2(4, 4))


func _raised(key: String, xa: float, xb: float, z0: float, z1: float, h: float, unit: Vector2, collide := true) -> void:
	var x0 := minf(xa, xb)
	var x1 := maxf(xa, xb)
	if key != "":
		geo.ground(key, x0, x1, z0, z1, h, unit, 6.0)
	if collide and z1 > Layout.WALK_Z.x - 20.0 and z0 < Layout.WALK_Z.y + 20.0 and x1 > -STUB - 2.0 and x0 < STUB + 2.0:
		var cx0 := maxf(x0, -STUB - 2.0)
		var cx1 := minf(x1, STUB + 2.0)
		var cz0 := maxf(z0, Layout.WALK_Z.x - 20.0)
		var cz1 := minf(z1, Layout.WALK_Z.y + 20.0)
		solid(Vector3((cx0 + cx1) * 0.5, h - 0.5, (cz0 + cz1) * 0.5), Vector3(cx1 - cx0, 1.0, cz1 - cz0), true)
	geo.quad("curb", Vector3(x0, 0, z1), Vector3(x0, 0, z0), Vector3(x0, h, z0), Vector3(x0, h, z1), Vector3.LEFT, Vector2(2, 0.5), Vector2.ZERO, 12.0)
	geo.quad("curb", Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x1, h, z1), Vector3(x1, h, z0), Vector3.RIGHT, Vector2(2, 0.5), Vector2.ZERO, 12.0)
	geo.quad("curb", Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, h, z1), Vector3(x0, h, z1), Vector3.BACK, Vector2(2, 0.5), Vector2.ZERO, 12.0)
	geo.quad("curb", Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, h, z0), Vector3(x0, h, z0), Vector3.FORWARD, Vector2(2, 0.5), Vector2.ZERO, 12.0)


func _slab(x0: float, x1: float, z0: float, z1: float, sd: int) -> void:
	var cuts := []
	for s in Layout.STREETS:
		if s.sides.has(sd):
			cuts.append(Vector2(s.z - s.half - s.walk, s.z + s.half + s.walk))
	cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for g in _segments(cuts, z0, z1):
		geo.ground("slab", x0, x1, g.x, g.y, 0.05, Vector2(4, 4), 40.0)


func _buildings() -> void:
	_slab(30.0, XV, ZB_VIS, ZF_VIS, 1)
	_slab(-66.0, -30.0, -166.0, MASP_Z.x - 6.0, -1)
	_slab(-66.0, -30.0, MASP_Z.y + 6.0, ZF_VIS, -1)
	_slab(-XV, -66.0, VALLEY.end.y, ZF_VIS, -1)
	_slab(-XV, -66.0, -166.0, VALLEY.position.y, -1)
	_slab(-XV, -30.0, ZB_VIS, -452.0, -1)
	geo.ground("slab", -34.0, -30.0, -452.0, -166.0, 0.05, Vector2(4, 4), 40.0)
	solid(Vector3(-50.0, -0.5, -500.0), Vector3(40, 1, 400), true)
	rio = RioClaro.new()
	rio.osm.clip_x = Layout.SIDEWALK_X.y + 0.5
	rio.osm.exclude = [Rect2(0.0, -100000.0, 100000.0, 200000.0)]
	rio.build(world, 34.0)
	osm = OsmCity.new()
	osm.corridors = [rio.corridor()]
	osm.zrange = Vector2(ZB_VIS - 20.0, ZF_VIS + 20.0)
	osm.near_x = 90.0
	osm.seg = 6.0
	osm.set_glow(0.18)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/osm/paulista.json"))
	data.buildings = _without_rio_dupes(data.buildings) + _trim_rio()
	world.add_child(osm.build_data(data))
	osm.collide = false
	osm.seg = 0.0
	osm.corridors = []
	world.add_child(osm.build_data({"buildings": _fillers(data.buildings)}))
	osm.set_glow(0.18)


func _rio_cut(w: Vector3, lim: float) -> bool:
	return w.x > lim and w.z > RIO_BOX.x and w.z < RIO_BOX.y


func _trim_rio() -> Array:
	var lim := -(Layout.SIDEWALK_X.y + 0.45)
	for n in rio.root.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if m.mesh == null or not (m.mesh is ArrayMesh):
			continue
		var xf := m.global_transform
		var ab := xf * m.get_aabb()
		if ab.end.x <= lim or ab.end.z < RIO_BOX.x or ab.position.z > RIO_BOX.y:
			continue
		var nm := ArrayMesh.new()
		var changed := false
		for si in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(verts.size())
				for k in verts.size():
					idx[k] = k
			var keep := PackedInt32Array()
			for t in range(0, idx.size() - 2, 3):
				if _rio_cut(xf * verts[idx[t]], lim) or _rio_cut(xf * verts[idx[t + 1]], lim) or _rio_cut(xf * verts[idx[t + 2]], lim):
					changed = true
					continue
				keep.append(idx[t])
				keep.append(idx[t + 1])
				keep.append(idx[t + 2])
			if keep.is_empty():
				keep = PackedInt32Array([0, 0, 0])
			arr[Mesh.ARRAY_INDEX] = keep
			nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			nm.surface_set_material(si, m.mesh.surface_get_material(si))
		if changed:
			var over := []
			for si in m.mesh.get_surface_count():
				over.append(m.get_surface_override_material(si))
			m.mesh = nm
			for si in over.size():
				m.set_surface_override_material(si, over[si])
	for n in rio.root.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		var body := cs.get_parent() as CollisionObject3D
		if body == null or body.collision_layer != 1 or not (cs.shape is ConcavePolygonShape3D):
			continue
		var xf := cs.global_transform
		var faces := (cs.shape as ConcavePolygonShape3D).get_faces()
		var kept := PackedVector3Array()
		for t in range(0, faces.size() - 2, 3):
			if _rio_cut(xf * faces[t], lim) or _rio_cut(xf * faces[t + 1], lim) or _rio_cut(xf * faces[t + 2], lim):
				continue
			kept.append_array([faces[t], faces[t + 1], faces[t + 2]])
		if kept.size() != faces.size():
			(cs.shape as ConcavePolygonShape3D).set_faces(kept)
	var caps := []
	var strip := PackedVector2Array([Vector2(-34.5, RIO_BOX.x), Vector2(lim - 0.05, RIO_BOX.x), Vector2(lim - 0.05, RIO_BOX.y), Vector2(-34.5, RIO_BOX.y)])
	var gap := PackedVector2Array([Vector2(-40.0, Layout.RIO_GAP.x - 2.0), Vector2(0.0, Layout.RIO_GAP.x - 2.0), Vector2(0.0, Layout.RIO_GAP.y + 2.0), Vector2(-40.0, Layout.RIO_GAP.y + 2.0)])
	for i in rio.models.replaced:
		if rio.models.closed.has(i):
			continue
		var b: Dictionary = rio.data.buildings[i]
		var poly := PackedVector2Array()
		var mx := -INF
		for p in b.p:
			poly.append(Vector2(p[0], p[1]))
			mx = maxf(mx, p[0])
		if mx <= lim:
			continue
		for q in Geometry2D.intersect_polygons(poly, strip):
			for r in Geometry2D.clip_polygons(q, gap):
				if r.size() < 3:
					continue
				var pts := []
				for v in r:
					pts.append([v.x, v.y])
				caps.append({"p": pts, "h": b.get("h", 9.0), "style": "", "seed": 5000 + int(i), "name": "", "front": true, "y": b.get("y", 0.0)})
	return caps


func _without_rio_dupes(blds: Array) -> Array:
	var boxes := []
	for b in rio.data.buildings:
		var r := Rect2(b.p[0][0], b.p[0][1], 0, 0)
		for p in b.p:
			r = r.expand(Vector2(p[0], p[1]))
		if r.get_center().x < 0.0:
			boxes.append(r)
	var out := []
	for b in blds:
		var c := Vector2.ZERO
		for p in b.p:
			c += Vector2(p[0], p[1])
		c /= float(b.p.size())
		var drop := false
		if c.x < -30.0 and c.y > -448.0 and c.y < -168.0:
			drop = c.x < -75.0
			for r in boxes:
				if (r as Rect2).has_point(c):
					drop = true
		if not drop:
			out.append(b)
	return out


func _valley_y(x: float) -> float:
	return -7.0 - maxf(-66.0 - x, 0.0) * 0.045


func _reserved(x: float, z: float) -> bool:
	if absf(x) < 34.0:
		return true
	var sd := 1 if x > 0.0 else -1
	for s in Layout.STREETS:
		if s.sides.has(sd) and absf(z - s.z) < s.half + s.walk + 1.0 and absf(x) < absf(_street_end(s, sd)) + 1.0:
			return true
	if x < -26.0 and z > MASP_Z.x - 8.0 and z < MASP_Z.y + 8.0 and x > -68.0:
		return true
	if x > 26.0 and x < 96.0 and z > MASP_Z.x - 4.0 and z < MASP_Z.y + 4.0:
		return true
	if x < -30.0 and z > RIO_BOX.x and z < RIO_BOX.y:
		return true
	if VALLEY.has_point(Vector2(x, z)) and absf(z - VALLEY_ROAD.x) < VALLEY_ROAD.y + 4.0:
		return true
	if x < -60.0 and x > -72.0 and VALLEY.has_point(Vector2(-100.0, z)):
		return true
	return false


func _fillers(blds: Array) -> Array:
	var cell := 4.0
	var nx := int(2.0 * XV / cell)
	var nz := int((ZF_VIS - ZB_VIS) / cell)
	var occ := PackedByteArray()
	occ.resize(nx * nz)
	for b in blds:
		var poly := PackedVector2Array()
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		for p in b.p:
			var v := Vector2(p[0], p[1])
			poly.append(v)
			mn = mn.min(v)
			mx = mx.max(v)
		var i0 := clampi(int((mn.x + XV) / cell) - 1, 0, nx - 1)
		var i1 := clampi(int((mx.x + XV) / cell) + 1, 0, nx - 1)
		var j0 := clampi(int((mn.y - ZB_VIS) / cell) - 1, 0, nz - 1)
		var j1 := clampi(int((mx.y - ZB_VIS) / cell) + 1, 0, nz - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var c := Vector2(-XV + (i + 0.5) * cell, ZB_VIS + (j + 0.5) * cell)
				if Geometry2D.is_point_in_polygon(c, poly) or _near_poly(c, poly, cell * 0.75):
					occ[j * nx + i] = 1
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	var out := []
	for s in Layout.STREETS:
		for sd in s.sides:
			var xe := _street_end(s, sd)
			if absf(xe) < XV - 1.0 and absf(xe) > STUB + 2.0:
				var hw: float = s.half + s.walk
				var p := [[xe, s.z - hw - 2.0], [xe + sd * 22.0, s.z - hw - 2.0], [xe + sd * 22.0, s.z + hw + 2.0], [xe, s.z + hw + 2.0]]
				out.append({"p": p, "h": 38.0, "style": "", "seed": 777, "name": "", "front": true, "y": 0.0})
				_mark(occ, nx, nz, cell, Rect2(minf(xe, xe + sd * 22.0), s.z - hw - 2.0, 22.0, 2.0 * hw + 4.0))
	for bs: float in [24.0, 12.0]:
		var z := ZB_VIS
		while z < ZF_VIS - bs:
			var x := -XV
			while x < XV - bs:
				var c := Vector2(x + bs * 0.5, z + bs * 0.5)
				if _fill_ok(c, bs, occ, nx, nz, cell):
					var m := bs / 24.0
					var ia := r.randf_range(1.5, 4.0) * m
					var ib := r.randf_range(1.5, 4.0) * m
					var ic := r.randf_range(1.5, 4.0) * m
					var id := r.randf_range(1.5, 4.0) * m
					var p := [[x + ia, z + ib], [x + bs - ic, z + ib], [x + bs - ic, z + bs - id], [x + ia, z + bs - id]]
					var far := absf(c.x)
					var roll := r.randf()
					var h := r.randf_range(9.0, 20.0)
					if roll > 0.35:
						h = r.randf_range(24.0, 55.0)
					if roll > (0.8 if far < 200.0 else 0.9) and bs > 20.0:
						h = r.randf_range(60.0, 105.0)
					var y := 0.0
					if VALLEY.has_point(c):
						y = _valley_y(c.x) + 0.5
					out.append({"p": p, "h": snappedf(h, 0.1), "style": "", "seed": r.randi() % 100000, "name": "", "front": false, "y": y})
					_mark(occ, nx, nz, cell, Rect2(x, z, bs, bs))
				x += bs
			z += bs
	return out


func _mark(occ: PackedByteArray, nx: int, nz: int, cell: float, rc: Rect2) -> void:
	for j in range(maxi(int((rc.position.y - ZB_VIS) / cell), 0), mini(int((rc.end.y - ZB_VIS) / cell) + 1, nz)):
		for i in range(maxi(int((rc.position.x + XV) / cell), 0), mini(int((rc.end.x + XV) / cell) + 1, nx)):
			occ[j * nx + i] = 1


func _near_poly(c: Vector2, poly: PackedVector2Array, d: float) -> bool:
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if Geometry2D.get_closest_point_to_segment(c, a, b).distance_to(c) < d:
			return true
	return false


func _fill_ok(c: Vector2, bs: float, occ: PackedByteArray, nx: int, nz: int, cell: float) -> bool:
	var reach := minf(c.distance_to(Vector2(0.0, clampf(c.y, Layout.WALK_Z.x, Layout.WALK_Z.y))), c.distance_to(Vector2(clampf(c.x, -400.0, 0.0), Layout.RIO_Z)))
	if reach > 440.0:
		return false
	var h := bs * 0.5 - 1.0
	for oz in [-h, -h * 0.5, 0.0, h * 0.5, h]:
		for ox in [-h, -h * 0.5, 0.0, h * 0.5, h]:
			var q := c + Vector2(ox, oz)
			if _reserved(q.x, q.y):
				return false
			var i := int((q.x + XV) / cell)
			var j := int((q.y - ZB_VIS) / cell)
			if i < 0 or j < 0 or i >= nx or j >= nz or occ[j * nx + i] == 1:
				return false
	return true


func _valley() -> void:
	var z0 := VALLEY.position.y
	var z1 := VALLEY.end.y
	var xs := [-66.0, -100.0, -160.0, -240.0, -330.0, -XV]
	for i in xs.size() - 1:
		var xa: float = xs[i]
		var xb: float = xs[i + 1]
		var ya := _valley_y(xa)
		var yb := _valley_y(xb)
		var r0 := VALLEY_ROAD.x - VALLEY_ROAD.y
		var r1 := VALLEY_ROAD.x + VALLEY_ROAD.y
		for band in [[z0, r0, "ground"], [r0, r1, "asphalt"], [r1, z1, "ground"]]:
			var a: float = band[0]
			var b: float = band[1]
			geo.quad(band[2], Vector3(xb, yb, a), Vector3(xa, ya, a), Vector3(xa, ya, b), Vector3(xb, yb, b), Vector3.UP, Vector2(4, 4), Vector2.ZERO, 8.0)
		var x := xa
		while x > xb + 3.0:
			var y0 := _valley_y(x) + 0.03
			var y1 := _valley_y(x - 3.0) + 0.03
			for lz in [VALLEY_ROAD.x - 3.4, VALLEY_ROAD.x, VALLEY_ROAD.x + 3.4]:
				var w := 0.08 if lz != VALLEY_ROAD.x else 0.1
				var key := "paint" if lz != VALLEY_ROAD.x else "paint_y"
				geo.quad(key, Vector3(x - 3.0, y1, lz - w), Vector3(x, y0, lz - w), Vector3(x, y0, lz + w), Vector3(x - 3.0, y1, lz + w), Vector3.UP, Vector2(1, 1), Vector2.ZERO, 20.0)
			x -= 8.0
		geo.quad("wallc", Vector3(xb, yb - 0.5, z0), Vector3(xa, ya - 0.5, z0), Vector3(xa, 0.05, z0), Vector3(xb, 0.05, z0), Vector3.BACK, Vector2(4, 4), Vector2.ZERO, 8.0)
		geo.quad("wallc", Vector3(xa, ya - 0.5, z1), Vector3(xb, yb - 0.5, z1), Vector3(xb, 0.05, z1), Vector3(xa, 0.05, z1), Vector3.FORWARD, Vector2(4, 4), Vector2.ZERO, 8.0)
	var yw := _valley_y(-66.0)
	geo.quad("wallc", Vector3(-66.0, yw - 0.5, z1), Vector3(-66.0, yw - 0.5, z0), Vector3(-66.0, 0.05, z0), Vector3(-66.0, 0.05, z1), Vector3.LEFT, Vector2(4, 4), Vector2.ZERO, 8.0)
	var t0 := VALLEY_ROAD.x - VALLEY_ROAD.y + 1.0
	var t1 := VALLEY_ROAD.x + VALLEY_ROAD.y - 1.0
	geo.quad("dark", Vector3(-65.95, yw, t1), Vector3(-65.95, yw, t0), Vector3(-65.95, yw + 5.6, t0), Vector3(-65.95, yw + 5.6, t1), Vector3.LEFT, Vector2(4, 4))
	geo.box("concrete", Vector3(-66.4, yw + 6.3, VALLEY_ROAD.x), Vector3(0.8, 1.4, VALLEY_ROAD.y * 2.0 + 1.0), Vector2(2, 1))
	var tx := -72.0
	while tx > -300.0:
		for e in [-1.0, 1.0]:
			var tz: float = VALLEY_ROAD.x + e * (VALLEY_ROAD.y + rng.randf_range(3.0, 9.0))
			_place(props.tree(Vector3(tx, _valley_y(tx), tz), rng.randf_range(1.2, 1.7), rng.randi()), Transform3D.IDENTITY)
		tx -= rng.randf_range(9.0, 15.0)
	var lx := -80.0
	var lit := 0
	while lx > -330.0:
		if lit < 4:
			var ol := OmniLight3D.new()
			ol.position = Vector3(lx, _valley_y(lx) + 7.0, VALLEY_ROAD.x)
			ol.light_color = Color(1.0, 0.66, 0.36)
			ol.light_energy = 8.0
			ol.omni_range = 22.0
			world.add_child(ol)
			lights.append(ol)
			lit += 1
		for e in [-1.0, 1.0]:
			var lz: float = VALLEY_ROAD.x + e * (VALLEY_ROAD.y + 1.0)
			var y := _valley_y(lx)
			geo.box("metal", Vector3(lx, y + 4.0, lz), Vector3(0.18, 8.0, 0.18), Vector2(1, 4))
			geo.box("lamp", Vector3(lx, y + 7.9, lz - e * 1.0), Vector3(0.5, 0.15, 0.9), Vector2(1, 1))
		lx -= 30.0


func _masp() -> void:
	var z0 := MASP_Z.x
	var z1 := MASP_Z.y
	var xa := -29.0
	var xb := -57.0
	var sx0 := STAIRS.position.x
	var sx1 := STAIRS.end.x
	var sz0 := STAIRS.position.y
	var sz1 := STAIRS.end.y
	var pz0 := z0 - 6.0
	var pz1 := z1 + 6.0
	geo.ground("slab", xb - 4.0, -30.0, pz0, sz0, 0.16, Vector2(3, 3))
	geo.ground("slab", xb - 4.0, -30.0, sz1, pz1, 0.16, Vector2(3, 3))
	geo.ground("slab", xb - 4.0, sx0, sz0, sz1, 0.16, Vector2(3, 3))
	geo.ground("slab", sx1, -30.0, sz0, sz1, 0.16, Vector2(3, 3))
	geo.ground("slab", -66.0, xb - 4.0, pz0, pz1, 0.16, Vector2(3, 3))
	solid(Vector3((-66.0 - 30.0) * 0.5, -0.34, (z0 + z1) * 0.5), Vector3(36.0, 1.0, z1 - z0 + 12.0), true)
	for px in [xa, xb]:
		for pz in [z0, z1]:
			geo.box("red", Vector3(px, 12.75, pz), Vector3(2.4, 25.5, 3.6), Vector2(3, 3))
			solid(Vector3(px, 12.75, pz), Vector3(2.4, 25.5, 3.6))
	for px in [xa, xb]:
		geo.box("red", Vector3(px, 23.8, (z0 + z1) * 0.5), Vector3(2.4, 3.4, z1 - z0 + 3.6), Vector2(3, 3))
		geo.box("red", Vector3(px, 8.7, (z0 + z1) * 0.5), Vector3(2.4, 2.6, z1 - z0 + 3.6), Vector2(3, 3))
	geo.box("masp_glass", Vector3((xa + xb) * 0.5, 15.65, (z0 + z1) * 0.5), Vector3(absf(xa - xb) - 0.4, 12.5, z1 - z0 - 2.0), Vector2(z1 - z0, 12.5), Vector2.ZERO, 8.0, "slab")
	_stairs()
	var px := -65.6
	geo.box("concrete", Vector3(px, 0.66, (pz0 + pz1) * 0.5), Vector3(0.4, 1.0, pz1 - pz0), Vector2(2, 1))
	geo.box("metal", Vector3(px, 1.2, (pz0 + pz1) * 0.5), Vector3(0.08, 0.08, pz1 - pz0), Vector2(2, 1))
	var z := pz0
	while z < pz1:
		geo.box("metal", Vector3(px, 1.05, z), Vector3(0.06, 0.3, 0.06), Vector2(1, 1))
		z += 2.0
	for e in [pz0, pz1]:
		geo.box("concrete", Vector3((-66.0 + xb - 4.0) * 0.5, 0.66, e), Vector3(5.0, 1.0, 0.4), Vector2(2, 1))


func _stairs() -> void:
	var x0 := STAIRS.position.x
	var x1 := STAIRS.end.x
	var z0 := STAIRS.position.y
	var z1 := STAIRS.end.y
	var depth := -3.6
	var n := 20
	var run := (z1 - z0 - 4.5) / n
	var rise := (0.16 - depth) / n
	for i in n:
		var top := 0.16 - (i + 1) * rise
		var za := z1 - (i + 1) * run
		var zb := z1 - i * run
		geo.box("curb", Vector3((x0 + x1) * 0.5, (top + depth - 0.2) * 0.5, (za + zb) * 0.5), Vector3(x1 - x0 - 0.2, top - depth + 0.2, zb - za), Vector2(1.5, 0.2))
		geo.box("dark", Vector3((x0 + x1) * 0.5, top + 0.005, za + 0.04), Vector3(x1 - x0 - 0.3, 0.012, 0.06), Vector2(1, 1))
	geo.ground("wallc", x0, x1, z0, z1 - n * run, depth, Vector2(1.5, 1.5))
	geo.quad("wallc", Vector3(x0, depth, z0), Vector3(x0, depth, z1), Vector3(x0, 0.16, z1), Vector3(x0, 0.16, z0), Vector3.RIGHT, Vector2(3, 3))
	geo.quad("wallc", Vector3(x1, depth, z1), Vector3(x1, depth, z0), Vector3(x1, 0.16, z0), Vector3(x1, 0.16, z1), Vector3.LEFT, Vector2(3, 3))
	geo.quad("wallc", Vector3(x1, depth, z1), Vector3(x0, depth, z1), Vector3(x0, 0.16, z1), Vector3(x1, 0.16, z1), Vector3.FORWARD, Vector2(3, 3))
	geo.quad("wallc", Vector3(x0, depth, z0), Vector3(x1, depth, z0), Vector3(x1, 0.16, z0), Vector3(x0, 0.16, z0), Vector3.BACK, Vector2(3, 3))
	geo.quad("dark", Vector3(x0 + 1.0, depth, z0 + 0.02), Vector3(x1 - 1.0, depth, z0 + 0.02), Vector3(x1 - 1.0, depth + 2.4, z0 + 0.02), Vector3(x0 + 1.0, depth + 2.4, z0 + 0.02), Vector3.BACK, Vector2(4, 2.4))
	geo.box("lamp", Vector3((x0 + x1) * 0.5, depth + 2.8, z0 + 0.1), Vector3(1.2, 0.12, 0.12), Vector2(1, 1))
	var pl := OmniLight3D.new()
	pl.position = Vector3((x0 + x1) * 0.5, depth + 2.4, z0 + 1.0)
	pl.light_color = Color(0.95, 0.9, 0.8)
	pl.light_energy = 2.5
	pl.omni_range = 9.0
	world.add_child(pl)
	var rail := [[Vector3(x0, 0, z0), Vector3(x1, 0, z0)], [Vector3(x0, 0, z0), Vector3(x0, 0, z1)], [Vector3(x1, 0, z0), Vector3(x1, 0, z1)], [Vector3(x0, 0, z1), Vector3(x1, 0, z1)]]
	for r in rail:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var c := (a + b) * 0.5
		var l := a.distance_to(b)
		var along_x := absf(b.x - a.x) > 0.1
		geo.box("metal", c + Vector3(0, 1.26, 0), Vector3(l if along_x else 0.07, 0.07, 0.07 if along_x else l), Vector2(2, 1))
		geo.box("metal", c + Vector3(0, 0.7, 0), Vector3(l if along_x else 0.04, 0.04, 0.04 if along_x else l), Vector2(2, 1))
		var k := 0.0
		while k <= l + 0.01:
			geo.box("metal", a.lerp(b, k / l) + Vector3(0, 0.71, 0), Vector3(0.06, 1.1, 0.06), Vector2(1, 1))
			k += 1.5
	solid(Vector3((x0 + x1) * 0.5, 0.76, (z0 + z1) * 0.5), Vector3(x1 - x0 + 0.2, 1.2, z1 - z0 + 0.2))


func _trianon() -> void:
	geo.ground("grass", 30.0, 92.0, MASP_Z.x, MASP_Z.y, 0.3, Vector2(4, 4))
	var zc := (MASP_Z.x + MASP_Z.y) * 0.5
	var zl := MASP_Z.y - MASP_Z.x
	geo.box("concrete", Vector3(30.5, 0.4, zc), Vector3(0.6, 0.8, zl), Vector2(2, 1))
	solid(Vector3(30.5, 0.6, zc), Vector3(0.6, 1.2, zl))
	for e in [-1.0, 1.0]:
		var x: float = 30.5 + e * 0.02
		geo.quad("fence", Vector3(x, 0.8, MASP_Z.x), Vector3(x, 0.8, MASP_Z.y), Vector3(x, 2.6, MASP_Z.y), Vector3(x, 2.6, MASP_Z.x), Vector3(-e, 0, 0), Vector2(1.8, 1.8), Vector2.ZERO, 12.0)
	var z := MASP_Z.x
	while z <= MASP_Z.y + 0.01:
		geo.box("green_metal", Vector3(30.5, 1.75, z), Vector3(0.14, 1.9, 0.14), Vector2(1, 1))
		z += 3.0
	geo.box("green_metal", Vector3(30.5, 2.65, zc), Vector3(0.1, 0.1, zl), Vector2(2, 1))
	for i in 70:
		var p := Vector3(rng.randf_range(33, 90), 0.3, rng.randf_range(MASP_Z.x + 3, MASP_Z.y - 3))
		if absf(p.z - zc) < 2.5 and p.x < 60.0:
			continue
		_tree(p, rng.randf_range(1.1, 2.1))
	geo.ground("slab", 30.8, 60.0, zc - 1.6, zc + 1.6, 0.32, Vector2(2, 2))


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


func _walkable_z(z: float) -> bool:
	return z > Layout.WALK_Z.x - 10.0 and z < Layout.WALK_Z.y + 10.0


func _lamp_post(x: float, z: float) -> void:
	var sx := signf(x)
	var near := _walkable_z(z)
	if near:
		solid(Vector3(x, 3.75, z), Vector3(0.35, 7.5, 0.35))
	var lp := props.lamp()
	_place(lp, Transform3D(Basis(Vector3.UP, -sx * PI * 0.5), Vector3(x, WALK_H, z)))
	geo.box("lamp", Vector3(x - sx * 1.1, 7.2, z), Vector3(0.5, 0.08, 0.3), Vector2(1, 1))
	if near and rng.randf() < 0.5 and Layout.is_clear(x + sx * 0.6, z + 0.9):
		var tc := props.trash()
		_place(tc, Transform3D(Basis(), Vector3(x + sx * 0.6, WALK_H, z + 0.9)))
		solid(Vector3(x + sx * 0.6, 0.6, z + 0.9), Vector3(0.5, 1.0, 0.5))
	if near:
		var ol := OmniLight3D.new()
		ol.position = Vector3(x - sx * 1.0, 7.0, z)
		ol.light_color = Color(1.0, 0.66, 0.36)
		ol.light_energy = 9.0
		ol.omni_range = 18.0
		ol.omni_attenuation = 0.9
		ol.shadow_enabled = false
		world.add_child(ol)
		lights.append(ol)


func _sign_mat(name: String) -> String:
	var key := "plate_" + name.get_file().get_basename()
	if not M.has(key):
		_add(key, mat(Tex.plate(name)))
	return key


func _plate(path: String, c: Vector3, w: float, h: float, normal: Vector3) -> void:
	var key := _sign_mat(path)
	var right := Vector3.UP.cross(normal).normalized()
	var a := c - right * w * 0.5 - Vector3(0, h * 0.5, 0)
	var b := c + right * w * 0.5 - Vector3(0, h * 0.5, 0)
	var up := Vector3(0, h, 0)
	var f := normal * 0.025
	geo.quad(key, a + f, b + f, b + up + f, a + up + f, normal, Vector2(w, h))
	geo.quad(key, b - f, a - f, a + up - f, b + up - f, -normal, Vector2(w, h))


func _corner_sign(x: float, z: float, cross_tex: String, cross_normal: Vector3) -> void:
	geo.box("metal", Vector3(x, 1.85 + WALK_H, z), Vector3(0.08, 3.7, 0.08), Vector2(1, 4))
	if _walkable_z(z):
		solid(Vector3(x, 1.85, z), Vector3(0.15, 3.7, 0.15))
	_plate(SIGNS + "paulista.png", Vector3(x, 3.55, z), 1.3, 0.33, Vector3.RIGHT)
	_plate(cross_tex, Vector3(x, 3.15, z), 1.3, 0.33, cross_normal)


func _way_sign(x: float, z: float, tex: String, normal: Vector3) -> void:
	geo.box("metal", Vector3(x, 1.45 + WALK_H, z), Vector3(0.08, 2.9, 0.08), Vector2(1, 3))
	solid(Vector3(x, 1.45, z), Vector3(0.15, 2.9, 0.15))
	_plate(SIGNS + tex + ".png", Vector3(x, 2.65, z), 1.4, 0.44, normal)


func _shelter(x: float, z: float) -> void:
	var sx := signf(x)
	var len := 7.0
	var back := x + sx * 2.0
	geo.box("metal", Vector3(x + sx * 0.6, 2.75, z), Vector3(2.0, 0.12, len), Vector2(2, 2))
	for e in [-1.0, 1.0]:
		geo.box("metal", Vector3(back, 1.4, z + e * (len * 0.5 - 0.2)), Vector3(0.1, 2.7, 0.1), Vector2(1, 2))
		solid(Vector3(back, 1.4, z + e * (len * 0.5 - 0.2)), Vector3(0.15, 2.7, 0.15))
	geo.box("glass", Vector3(back, 1.45, z), Vector3(0.05, 2.1, len - 0.6), Vector2(2, 2))
	solid(Vector3(back, 1.45, z), Vector3(0.1, 2.1, len - 0.6))
	geo.box("metal", Vector3(back - sx * 0.35, 0.6, z), Vector3(0.45, 0.06, 3.5), Vector2(2, 1))
	geo.box("lamp", Vector3(x + sx * 0.6, 2.68, z), Vector3(0.2, 0.03, len - 1.0), Vector2(1, 1))
	geo.box("plate_paulista" if M.has("plate_paulista") else "metal", Vector3(x - sx * 0.3, 2.95, z + len * 0.5 - 0.3), Vector3(0.05, 0.3, 0.6), Vector2(1, 1))


func _barrier(x0: float, x1: float, z0: float, z1: float, n: Vector3) -> void:
	var along_x := absf(x1 - x0) > absf(z1 - z0)
	var a := Vector3(x0, WALK_H, z0)
	var b := Vector3(x1, WALK_H, z1)
	var l := a.distance_to(b)
	geo.quad("tapume", a + n * 0.6, b + n * 0.6, b + n * 0.6 + Vector3(0, 2.2, 0), a + n * 0.6 + Vector3(0, 2.2, 0), n, Vector2(2.4, 2.2), Vector2.ZERO, 6.0)
	geo.quad("tapume", b + n * 0.6, a + n * 0.6, a + n * 0.6 + Vector3(0, 2.2, 0), b + n * 0.6 + Vector3(0, 2.2, 0), -n, Vector2(2.4, 2.2), Vector2.ZERO, 6.0)
	var k := 0.8
	while k < l - 0.5:
		var p := a.lerp(b, k / l)
		var s := Vector3(1.5, 0.25, 0.06) if along_x else Vector3(0.06, 0.25, 1.5)
		geo.box("cavalete", p + Vector3(0, 0.95, 0) - n * 0.2, s, Vector2(1.5, 0.25))
		geo.box("cavalete", p + Vector3(0, 0.55, 0) - n * 0.2, s, Vector2(1.5, 0.25))
		for e in [-0.65, 0.65]:
			var leg := p + (Vector3(e, 0, 0) if along_x else Vector3(0, 0, e)) - n * 0.2
			geo.box("dark", leg + Vector3(0, 0.55, 0), Vector3(0.06, 1.1, 0.06), Vector2(1, 1))
		k += 2.0


func _furniture() -> void:
	var z := 50.0
	while z > -700.0:
		if Layout.is_clear(17.0, z, 1.0) and not Layout.in_street(z - 1.0, z + 1.0, 1, 3.5):
			_lamp_post(17.0, z)
		var zl := z - 16.0
		if Layout.is_clear(-17.0, zl, 1.0) and not Layout.in_street(zl - 1.0, zl + 1.0, -1, 3.5):
			_lamp_post(-17.0, zl)
		z -= 32.0
	for zr in [[ZF_VIS - 10.0, 60.0], [-704.0, ZB_VIS + 10.0]]:
		z = zr[0]
		while z > zr[1]:
			if not Layout.in_street(z - 1.0, z + 1.0, 1, 3.5):
				_lamp_post(17.0, z)
			if not Layout.in_street(z - 17.0, z - 15.0, -1, 3.5):
				_lamp_post(-17.0, z - 16.0)
			z -= 32.0
	for sx in [-1, 1]:
		var tz := 200.0
		while tz > -860.0:
			var tx: float = sx * rng.randf_range(18.6, 19.2)
			var pz := tz + rng.randf_range(-2, 2)
			var ok := not Layout.in_street(pz - 3.0, pz + 3.0, sx, 2.0) and Layout.is_clear(tx, pz, 2.0)
			if sx < 0 and pz < MASP_Z.y + 22 and pz > MASP_Z.x - 4:
				ok = false
			for b in Layout.BUS_STOPS:
				if signf(b.x) == sx and absf(pz - b.z) < 7.0:
					ok = false
			if ok and rng.randf() < 0.75 and not (sx > 0 and pz > -36.0 and pz < 0.0):
				_tree(Vector3(tx, WALK_H, pz), rng.randf_range(0.9, 1.25))
			tz -= rng.randf_range(11, 16)
	for s in Layout.STREETS:
		for sd in s.sides:
			var name: String = s.names[sd]
			var cz: float = s.z + s.half + 1.2
			_corner_sign(sd * 16.9, cz, SIGNS + name + ".png", Vector3.BACK)
			if not _stub_open(s, sd):
				_barrier(sd * 31.3, sd * 31.3, s.z - s.half - s.walk, s.z + s.half + s.walk, Vector3(sd, 0, 0))
			elif absf(_street_end(s, sd)) > STUB:
				var hw: float = s.half + s.walk
				_barrier(sd * (STUB - 0.6), sd * (STUB - 0.6), s.z - hw, s.z + hw, Vector3(sd, 0, 0))
	_corner_sign(-16.9, Layout.RIO_GAP.y + 1.0, SIGNS + "rioclaro.png", Vector3.BACK)
	_corner_sign(-16.9, Layout.RIO_GAP.x - 1.0, SIGNS + "rioclaro.png", Vector3.FORWARD)
	_way_sign(19.6, -19.0, "way330", Vector3.BACK)
	_way_sign(17.4, Layout.MASP_CROSSWALK_Z + 5.5, "waycross", Vector3.BACK)
	_way_sign(-17.4, -60.0, "way280", Vector3.BACK)
	_way_sign(-17.4, -197.0, "way140", Vector3.BACK)
	for sd in [-1.0, 1.0]:
		_barrier(sd * 16.4, sd * 30.6, Layout.WALK_Z.y + 1.0, Layout.WALK_Z.y + 1.0, Vector3.BACK)
		_barrier(sd * 16.4, sd * 30.6, Layout.WALK_Z.x - 1.0, Layout.WALK_Z.x - 1.0, Vector3.FORWARD)
	for b in Layout.BUS_STOPS:
		_shelter(signf(b.x) * 18.0, b.z)
	if M.has("placa"):
		solid(Vector3(19.0, 1.8, -26.0), Vector3(0.15, 3.6, 0.15))
		_place(props.street_sign(Vector3(19.0, WALK_H, -26.0)), Transform3D.IDENTITY)
	_banca(Vector3(26.5, WALK_H, -36.0))
	_banca_rio(Vector3(-27.0, WALK_H, Layout.RIO_GAP.y + 9.5))
	for bz in [-20.0, -27.0, -58.0, -66.0, -74.0, -82.0, -90.0]:
		if not Layout.is_clear(-23.0, bz, 1.0):
			continue
		_place(props.bench(), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-23.0, WALK_H, bz)))
		solid(Vector3(-23.0, WALK_H + 0.22, bz), Vector3(0.6, 0.44, 1.8))
		solid(Vector3(-23.0 + BENCH_BACK, WALK_H + 0.65, bz), Vector3(0.1, 0.5, 1.8))


func _banca_rio(p: Vector3) -> void:
	var rc := "res://assets/rioclaro/tex/"
	if not M.has("banca_steel"):
		for k in [["banca_steel", "steel"], ["banca_front", "banca"], ["banca_sign", "banca_sign"]]:
			var t := Tex.plate(rc + k[1] + ".png")
			M[k[0]] = mat(t, Color.WHITE, t if k[0] == "banca_front" else null, 0.45 if k[0] == "banca_front" else 0.0)
			geo.add_mat(k[0], M[k[0]])
	var L := 6.6
	var W := 2.9
	var H := 3.1
	geo.box("banca_steel", p + Vector3(0, H * 0.5, 0), Vector3(W, H, L), Vector2(2.0, 3.1))
	solid(p + Vector3(0, H * 0.5, 0), Vector3(W, H, L))
	var x := p.x + W * 0.5 + 0.03
	var a := Vector3(x, p.y + 0.4, p.z + 3.2)
	var b := Vector3(x, p.y + 0.4, p.z - 3.2)
	geo.quad("banca_front", a, b, b + Vector3(0, 2.6, 0), a + Vector3(0, 2.6, 0), Vector3.RIGHT, Vector2(6.4, 2.6))
	geo.box("concrete", p + Vector3(0.15, H + 0.28, 0), Vector3(3.2, 0.55, 6.9), Vector2(2, 2))
	var xs := p.x + 1.78
	var sa := Vector3(xs, p.y + H + 0.04, p.z + 3.3)
	var sb := Vector3(xs, p.y + H + 0.04, p.z - 3.3)
	geo.quad("banca_sign", sa, sb, sb + Vector3(0, 0.48, 0), sa + Vector3(0, 0.48, 0), Vector3.RIGHT, Vector2(6.6, 0.48))
	var ol := OmniLight3D.new()
	ol.position = p + Vector3(2.4, 2.4, 0)
	ol.light_color = Color(0.9, 0.95, 1.0)
	ol.light_energy = 1.0
	ol.omni_range = 6.0
	world.add_child(ol)


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
