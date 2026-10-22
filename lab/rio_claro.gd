extends Node

const Tex := preload("res://scripts/tex.gd")
const Geo := preload("res://scripts/geo.gd")
const OsmCity := preload("res://scripts/osm_city.gd")
const RioClaro := preload("res://scripts/rio_claro.gd")
const PS1 := preload("res://scripts/ps1.gdshader")
const CAMS := [
	[Vector3(-14.0, 1.75, -327.0), Vector3(-60.0, 3.0, -333.0)],
	[Vector3(-175.0, 11.5, -322.0), Vector3(-260.0, 12.0, -315.0)],
	[Vector3(-395.0, 9.6, -306.0), Vector3(-300.0, 9.0, -313.0)],
	[Vector3(-200.0, 420.0, -320.0), Vector3(-200.0, 0.0, -321.0)],
]

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var holder: Node3D
var label: Label
var novo := true
var noite := false
var cam_i := 0
var yaw := 0.0
var osm := OsmCity.new()
var rio := RioClaro.new()
var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var lamps := []
var lamp_mat: ShaderMaterial
var dia := false
var foto := -1
var vista := "frente"
var points := []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	novo = not args.has("--atual")
	rio.use_models = novo
	noite = args.has("--noite")
	dia = args.has("--dia")
	var fi := args.find("--foto")
	if fi >= 0 and fi + 1 < args.size():
		foto = int(args[fi + 1]) - 1
	var vi := args.find("--vista")
	if vi >= 0 and vi + 1 < args.size():
		vista = args[vi + 1]
	points = JSON.parse_string(FileAccess.get_file_as_string("res://assets/rioclaro/points.json")).points
	var ci := args.find("--cam")
	if ci >= 0 and ci + 1 < args.size():
		cam_i = int(args[ci + 1])
	vp = SubViewport.new()
	vp.size = Vector2i(640, 480)
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.audio_listener_enable_3d = false
	add_child(vp)
	var tr := TextureRect.new()
	tr.texture = vp.get_texture()
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(tr)
	label = Label.new()
	label.position = Vector2(8, 8)
	label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	add_child(label)
	world = Node3D.new()
	vp.add_child(world)
	_env()
	_street()
	cam = Camera3D.new()
	cam.fov = 64.0
	cam.far = 1500.0
	cam.current = true
	world.add_child(cam)
	_place_cam()
	holder = Node3D.new()
	world.add_child(holder)
	_build()
	_time()
	var cl := CanvasLayer.new()
	vp.add_child(cl)
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://scripts/screen.gdshader")
	cr.material = sm
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(cr)
	var shot := args.find("--shot")
	if shot >= 0 and shot + 1 < args.size():
		label.visible = false
		_shot(args[shot + 1])


func _mat(tex: Texture2D, emit := Color.BLACK, unshaded := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("emit", Vector3(emit.r, emit.g, emit.b))
	m.set_shader_parameter("unshaded", unshaded)
	return m


func _place_cam() -> void:
	var ai := OS.get_cmdline_user_args().find("--at")
	if ai >= 0:
		var v: PackedFloat64Array = OS.get_cmdline_user_args()[ai + 1].split_floats(",")
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.position = Vector3(v[0], v[1], v[2])
		cam.look_at(Vector3(v[3], v[4], v[5]))
		return
	if foto >= 0:
		var q: Dictionary = points[foto]
		var p := Vector3(q.p[0], 0.0, q.p[1])
		p.y = rio.street_y(p.x, p.z) + (0.17 if foto > 0 and foto < 5 else 0.0) + 2.4
		var d := Vector3(q.dir[0], 0.0, q.dir[1])
		p += d * float(q.get("ds", 0.0)) + Vector3(d.z, 0.0, -d.x) * float(q.get("dt", 0.0))
		p.y = rio.street_y(p.x, p.z) + (0.17 if foto > 0 and foto < 5 else 0.0) + 2.4
		d = d.rotated(Vector3.UP, deg_to_rad(float(q.get("dyaw", 0.0))))
		if vista == "esq":
			d = d.rotated(Vector3.UP, PI * 0.5)
		elif vista == "dir":
			d = d.rotated(Vector3.UP, -PI * 0.5)
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.position = p
		cam.look_at(p + d)
		env.fog_enabled = true
		return
	var c: Array = CAMS[cam_i]
	cam.position = c[0]
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL if cam_i == 3 else Camera3D.PROJECTION_PERSPECTIVE
	cam.size = 520.0
	env.fog_enabled = cam_i != 3
	if cam_i == 3:
		cam.rotation = Vector3(-PI * 0.5, 0, 0)
		env.ambient_light_energy = 2.2
		return
	cam.look_at(c[1])
	cam.rotate_y(yaw)
	env.fog_enabled = cam_i != 3


func _env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://scripts/sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 700.0
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-8, 172, 0)
	world.add_child(sun)
	fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-50, 20, 0)
	world.add_child(fill)


func _time() -> void:
	if dia and not noite:
		sky_mat.set_shader_parameter("zenith", Vector3(0.25, 0.42, 0.75))
		sky_mat.set_shader_parameter("mid", Vector3(0.55, 0.68, 0.85))
		sky_mat.set_shader_parameter("horizon", Vector3(0.85, 0.88, 0.9))
		env.ambient_light_color = Color(0.62, 0.64, 0.7)
		env.ambient_light_energy = 0.9
		env.fog_light_color = Color(0.7, 0.75, 0.82)
		sun.light_color = Color(1.0, 0.95, 0.85)
		sun.light_energy = 0.85
		sun.rotation_degrees = Vector3(-55, 150, 0)
		fill.light_color = Color(0.6, 0.65, 0.8)
		fill.light_energy = 0.3
		osm.set_glow(0.0)
		rio.osm.set_glow(0.0)
		rio.models.set_glow(0.0, false)
	elif noite:
		sky_mat.set_shader_parameter("zenith", Vector3(0.01, 0.01, 0.04))
		sky_mat.set_shader_parameter("mid", Vector3(0.05, 0.04, 0.09))
		sky_mat.set_shader_parameter("horizon", Vector3(0.25, 0.14, 0.12))
		env.ambient_light_color = Color(0.22, 0.2, 0.32)
		env.ambient_light_energy = 0.45
		env.fog_light_color = Color(0.14, 0.1, 0.12)
		sun.light_energy = 0.0
		fill.light_color = Color(0.35, 0.4, 0.7)
		fill.light_energy = 0.12
		osm.set_glow(1.15)
		rio.osm.set_glow(1.15)
		rio.models.set_glow(1.15, true)
	else:
		sky_mat.set_shader_parameter("zenith", Vector3(0.05, 0.05, 0.16))
		sky_mat.set_shader_parameter("mid", Vector3(0.32, 0.16, 0.34))
		sky_mat.set_shader_parameter("horizon", Vector3(1.0, 0.48, 0.24))
		env.ambient_light_color = Color(0.36, 0.3, 0.5)
		env.ambient_light_energy = 0.8
		env.fog_light_color = Color(0.5, 0.28, 0.36)
		sun.light_color = Color(1.0, 0.55, 0.32)
		sun.light_energy = 0.55
		fill.light_color = Color(0.45, 0.5, 0.85)
		fill.light_energy = 0.25
		osm.set_glow(0.18)
		rio.osm.set_glow(0.18)
		rio.models.set_glow(0.18, false)
	for l in lamps:
		l.light_energy = 12.0 if noite else 7.0
	lamp_mat.set_shader_parameter("emit", Vector3(2.2, 1.2, 0.45) if noite else Vector3(1.4, 0.9, 0.45))
	if cam_i == 3:
		env.ambient_light_energy = 2.2
	_label()


func _street() -> void:
	var g := Geo.new()
	g.add_mat("asphalt", _mat(Tex.plate("res://assets/road/b_128.png")))
	g.add_mat("mosaic", _mat(Tex.mosaic(4)))
	g.add_mat("paint", _mat(Tex.plate("res://assets/road/paint_white.png")))
	lamp_mat = _mat(Tex.flat(Color(0.8, 0.8, 0.8), 8, 0.04, 0.2, 1), Color(1.4, 0.9, 0.45), 1.0)
	g.add_mat("lamp", lamp_mat)
	g.add_mat("metal", _mat(Tex.flat(Color(0.3, 0.31, 0.33), 8, 0.03, 0.2, 11)))
	g.add_mat("red", _mat(Tex.flat(Color(0.78, 0.07, 0.06), 16, 0.04, 0.35, 8)))
	var mg := Tex.masp_glass(15)
	var mm := _mat(mg[0])
	mm.set_shader_parameter("glow_tex", mg[1])
	mm.set_shader_parameter("glow", 0.9)
	g.add_mat("masp_glass", mm)
	g.add_mat("slab", _mat(Tex.flat(Color(0.42, 0.41, 0.4), 16, 0.04, 0.4, 9)))
	var z0 := -560.0
	var z1 := -120.0
	g.ground("asphalt", -16, 16, z0, z1, 0.0, Vector2(3.5, 3.5), 8.0)
	g.ground("mosaic", 16, 34, z0, z1, 0.15, Vector2(0.8, 0.8), 8.0)
	g.ground("mosaic", -34, -16, z0, z1, 0.15, Vector2(0.8, 0.8), 8.0)
	g.add_mat("ground", _mat(Tex.plate("res://assets/road/b_128.png")))
	g.ground("ground", 34, 260, z0, z1, 0.05, Vector2(3.5, 3.5), 40.0)
	var z := z1
	while z > z0:
		for lx in [5.5, 9.0, 12.5, -5.5, -9.0, -12.5]:
			g.ground("paint", lx - 0.15, lx + 0.15, z - 3.0, z, 0.02, Vector2(0.3, 3.0), 20.0)
		z -= 9.0
	if true:
		g.build(world)
		return
	var mz0 := -131.0
	var mz1 := -53.0
	for px in [-29.0, -57.0]:
		for pz in [mz0, mz1]:
			g.box("red", Vector3(px, 12.75, pz), Vector3(2.4, 25.5, 3.6), Vector2(3, 3))
		g.box("red", Vector3(px, 23.8, (mz0 + mz1) * 0.5), Vector3(2.4, 3.4, mz1 - mz0 + 3.6), Vector2(3, 3))
		g.box("red", Vector3(px, 8.7, (mz0 + mz1) * 0.5), Vector3(2.4, 2.6, mz1 - mz0 + 3.6), Vector2(3, 3))
	g.box("masp_glass", Vector3(-43.0, 15.65, (mz0 + mz1) * 0.5), Vector3(27.6, 12.5, mz1 - mz0 - 2.0), Vector2(mz1 - mz0, 12.5), Vector2.ZERO, 8.0, "slab")
	z = 40.0
	while z > z0:
		for sx in [-1.0, 1.0]:
			var x: float = sx * 17.0
			var zz: float = z - (16.0 if sx < 0 else 0.0)
			g.box("metal", Vector3(x, 4.0, zz), Vector3(0.25, 8.0, 0.25), Vector2(1, 4))
			g.box("lamp", Vector3(x - sx * 1.2, 7.9, zz), Vector3(0.9, 0.2, 0.4), Vector2(1, 1))
			if absf(zz) < 420.0 or zz > 250.0:
				var ol := OmniLight3D.new()
				ol.position = Vector3(x - sx * 1.2, 7.2, zz)
				ol.light_color = Color(1.0, 0.6, 0.28)
				ol.omni_range = 16.0
				ol.omni_attenuation = 0.9
				world.add_child(ol)
				lamps.append(ol)
		z -= 32.0
	g.build(world)


func _build() -> void:
	for c in holder.get_children():
		c.queue_free()
	osm.zrange = Vector2(-560.0, -120.0)
	osm.corridors = [rio.corridor()]
	holder.add_child(osm.build("res://assets/osm/paulista.json"))
	rio.build(holder, 34.0)
	lamps.append_array(rio.lamps)
	_label()


func _antenna(base: Vector3, height: float) -> void:
	var g := Geo.new()
	g.add_mat("tower", _mat(Tex.stripes(Color(0.75, 0.1, 0.08), Color(0.85, 0.83, 0.8), 2, 16, 2, 30)))
	g.add_mat("red_light", _mat(Tex.flat(Color(0.8, 0.8, 0.8), 8, 0.04, 0.2, 1), Color(2.0, 0.08, 0.05), 1.0))
	g.frustum("tower", base, Vector2(8, 8), Vector2(0.8, 0.8), height, Vector2(1, 4))
	g.box("red_light", base + Vector3(0, height + 0.6, 0), Vector3(1.4, 1.2, 1.4), Vector2(1, 1))
	g.build(holder)


func _atual() -> void:
	var g := Geo.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := 0
	g.add_mat("roof", _mat(Tex.flat(Color(0.3, 0.29, 0.28), 16, 0.05, 0.5, 14)))
	for sx in [-1.0, 1.0]:
		var z := 520.0
		while z > -880.0:
			var w := rng.randf_range(20, 38)
			if sx < 0 and z - w < -50.0 and z > -134.0:
				z = -136.0
				continue
			var d := rng.randf_range(22, 34)
			var h := rng.randf_range(26, 55) if rng.randf() < 0.4 else rng.randf_range(55, 100)
			n += 1
			var cols := maxi(4, int(maxf(d, w) / 3.0))
			var rows := maxi(4, int(h / 3.6))
			var t := Tex.facade(100 + n, cols, rows, n % 4, Color(0.45, 0.43, 0.4), Color(0.14, 0.16, 0.18), 0.35)
			var m := _mat(t[0])
			m.set_shader_parameter("glow_tex", t[1])
			m.set_shader_parameter("glow", 1.0)
			g.add_mat("b%d" % n, m)
			g.box("b%d" % n, Vector3(sx * (31.0 + d * 0.5), h * 0.5, z - w * 0.5), Vector3(d, h, w - 2.0), Vector2(cols * 3.0, rows * 3.6), Vector2.ZERO, 10.0, "roof")
			z -= w
	g.build(holder)


func _label() -> void:
	if label:
		label.text = "Alameda Rio Claro  %s  cam %d\nT tarde/noite   C camera (entrada/meio/fim/mapa)   <- -> girar   cima/baixo andar" % ["NOITE" if noite else "TARDE", cam_i]


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_T:
				noite = not noite
				_time()
			KEY_C:
				cam_i = (cam_i + 1) % CAMS.size()
				yaw = 0.0
				_place_cam()
				_label()


func _process(dt: float) -> void:
	var turn := Input.get_axis("ui_right", "ui_left")
	var move := Input.get_axis("ui_down", "ui_up")
	if turn != 0.0:
		cam.rotate_y(turn * dt * 1.5)
	if move != 0.0:
		var f := -cam.global_basis.z
		f.y = 0.0
		cam.position += f.normalized() * move * dt * 12.0


func _shot(path: String) -> void:
	for f in 15:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	print("shot ", path)
	get_tree().quit()
