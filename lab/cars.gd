extends Node

const Tex := preload("res://scripts/tex.gd")
const Geo := preload("res://scripts/geo.gd")
const Cars := preload("res://scripts/cars.gd")
const MODES := ["mix", "side", "front", "bus"]

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var holder: Node3D
var label: Label
var mode := "mix"
var start := 0
var yaw := 35.0
var dist := 11.5
var cars := []


func _arg(n: String, def: String) -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find(n)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else def


func _ready() -> void:
	mode = _arg("--pack", mode)
	start = int(_arg("--start", "0"))
	dist = float(_arg("--dist", str(dist)))
	yaw = float(_arg("--yaw", str(yaw)))
	vp = SubViewport.new()
	vp.size = Vector2i(640, 480)
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	_ground()
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.current = true
	world.add_child(cam)
	_place_cam()
	holder = Node3D.new()
	world.add_child(holder)
	_spawn()
	var cl := CanvasLayer.new()
	vp.add_child(cl)
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://scripts/screen.gdshader")
	cr.material = sm
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(cr)
	var shot := _arg("--shot", "")
	if shot != "":
		label.visible = false
		_shot(shot)


func _env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.45, 0.46)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.6, 0.66)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.9, 0.8)
	key.light_energy = 0.75
	key.rotation_degrees = Vector3(-35, 30, 0)
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(1.0, 0.6, 0.4)
	fill.light_energy = 0.25
	fill.rotation_degrees = Vector3(-8, 172, 0)
	world.add_child(fill)


func _ground() -> void:
	var g := Geo.new()
	g.add_mat("floor", Cars.mat(Tex.flat(Color(0.5, 0.5, 0.5), 16, 0.015, 0.15, 3)))
	g.add_mat("wall", Cars.mat(Tex.flat(Color(0.55, 0.55, 0.55), 16, 0.01, 0.1, 4)))
	g.ground("floor", -40, 40, -14, 18, 0.0, Vector2(4, 4))
	g.box("wall", Vector3(0, 10, -14.5), Vector3(80, 20, 1), Vector2(4, 4))
	g.build(world)


func _place_cam() -> void:
	cam.position = Vector3(0, 1.7 if mode != "bus" else 2.2, dist)
	cam.look_at(Vector3(0, 0.9 if mode != "bus" else 1.6, -0.5))


func _spawn() -> void:
	for c in holder.get_children():
		c.queue_free()
	cars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var items := []
	if mode == "bus":
		for i in 3:
			items.append(Cars.make_bus(start + i, rng))
	elif mode == "side" or mode == "front":
		for k in Cars.MODELS:
			items.append(Cars.make_car(k, -1, rng))
		items.append(Cars.make_car("taxi", -1, rng))
	else:
		for i in 4:
			items.append(Cars.make_car("", (start + i) % Cars.VARIANTS.size(), rng))
	var gap := 3.3 if mode == "mix" else (5.0 if mode == "bus" else (5.2 if mode == "side" else 2.6))
	var n := items.size()
	for i in n:
		var c: Node3D = items[i]
		holder.add_child(c)
		c.position = Vector3((i - (n - 1) * 0.5) * gap, 0, -1.0 if (i % 2 and mode == "mix") else 0.0)
		cars.append(c)
		print("CAR ", c.get_meta("kind"), " v", c.get_meta("variant"), " size ", c.get_meta("size"))
	label.text = "%s from %d  (P mode, up/down page, Z/X zoom)" % [mode, start]


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_UP:
				start += 4
				_spawn()
			KEY_DOWN:
				start = maxi(0, start - 4)
				_spawn()
			KEY_P:
				mode = MODES[(MODES.find(mode) + 1) % MODES.size()]
				start = 0
				_place_cam()
				_spawn()
			KEY_Z:
				dist = maxf(3.0, dist - 1.0)
				_place_cam()
			KEY_X:
				dist = minf(40.0, dist + 1.0)
				_place_cam()


func _process(dt: float) -> void:
	yaw += Input.get_axis("ui_left", "ui_right") * dt * 120.0
	var base := 90.0 if mode == "side" else (0.0 if mode == "front" else yaw)
	for r in cars:
		r.rotation.y = deg_to_rad(base)


func _shot(path: String) -> void:
	for f in 50:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(path)
	print("shot ", path)
	get_tree().quit()
