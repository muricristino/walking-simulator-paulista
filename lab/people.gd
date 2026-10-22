extends Node

const Tex := preload("res://scripts/tex.gd")
const People := preload("res://scripts/people.gd")
const PS1 := preload("res://scripts/ps1.gdshader")
const Geo := preload("res://scripts/geo.gd")

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var people := People.new()
var rigs := []
var holder: Node3D
var seed := 1
var yaw := 0.0
var t := 0.0
var all_walk := false
var dist := 3.6
var label: Label


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var si := args.find("--seed")
	if si >= 0 and si + 1 < args.size():
		seed = int(args[si + 1])
	vp = SubViewport.new()
	vp.size = Vector2i(320, 240)
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
	_ground()
	cam = Camera3D.new()
	cam.fov = 64.0
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
	var shot := args.find("--shot")
	if shot >= 0 and shot + 1 < args.size():
		label.visible = false
		_shot(args[shot + 1])


func _mat(tex: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter("tex", tex)
	return m


func _env() -> void:
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
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 520.0
	env.fog_depth_curve = 1.4
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.55, 0.32)
	sun.light_energy = 0.55
	sun.rotation_degrees = Vector3(-8, 172, 0)
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.45, 0.5, 0.85)
	fill.light_energy = 0.25
	fill.rotation_degrees = Vector3(-50, 20, 0)
	world.add_child(fill)
	var ol := OmniLight3D.new()
	ol.position = Vector3(1.5, 5.8, 2.5)
	ol.light_color = Color(1.0, 0.72, 0.42)
	ol.light_energy = 4.0
	ol.omni_range = 11.0
	ol.omni_attenuation = 0.9
	world.add_child(ol)


func _ground() -> void:
	var g := Geo.new()
	g.add_mat("mosaic", _mat(Tex.mosaic(4)))
	g.add_mat("curb", _mat(Tex.flat(Color(0.62, 0.6, 0.58), 8, 0.03, 0.3, 6)))
	g.add_mat("asphalt", _mat(Tex.asphalt(3)))
	var t := Tex.facade(101, 10, 8, 1, Color(0.62, 0.58, 0.5), Color(0.14, 0.16, 0.18), 0.4)
	var wm := _mat(t[0])
	wm.set_shader_parameter("glow_tex", t[1])
	wm.set_shader_parameter("glow", 1.0)
	g.add_mat("wall", wm)
	g.ground("mosaic", -20, 20, -14, 3.5, 0.0, Vector2(0.8, 0.8))
	g.ground("curb", -20, 20, 3.5, 3.9, 0.0, Vector2(2, 2))
	g.ground("asphalt", -20, 20, 3.9, 30, -0.15, Vector2(4, 4))
	g.box("wall", Vector3(0, 14.4, -18), Vector3(40, 28.8, 1), Vector2(30, 28.8))
	g.build(world)


func _place_cam() -> void:
	cam.position = Vector3(0, 1.45, dist)
	cam.look_at(Vector3(0, 1.0, 0))


func _spawn() -> void:
	for c in holder.get_children():
		c.queue_free()
	rigs.clear()
	var xs := [-2.25, -1.35, -0.45, 0.45, 1.35, 2.25]
	for i in 6:
		var r := people.rig(seed * 10 + i)
		var n: Node3D = r.root
		n.position = Vector3(xs[i], 0, 0)
		n.rotation.y = PI
		if i == 4:
			n.rotation.y = PI * 0.5
		if i == 5:
			n.rotation.y = PI * 0.75
		r.walk = i == 5
		holder.add_child(n)
		rigs.append(r)
	_label()


func _label() -> void:
	var tris := 0
	if rigs.size() > 0:
		var b: Dictionary = people.build(seed * 10)
		for k in b.parts:
			var mesh: ArrayMesh = b.parts[k]
			var c := mesh.surface_get_array_len(0) / 3
			tris += c * (2 if k in ["uarm", "farm", "thigh", "shin"] else 1)
	label.text = "seed %d  tris~%d\n<- -> girar   cima/baixo trocar pessoas\nespaco todos andam   Z/X zoom" % [seed, tris]


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_UP:
				seed += 1
				_spawn()
			KEY_DOWN:
				seed = maxi(0, seed - 1)
				_spawn()
			KEY_SPACE:
				all_walk = not all_walk
			KEY_Z:
				dist = maxf(1.2, dist - 0.4)
				_place_cam()
			KEY_X:
				dist = minf(10.0, dist + 0.4)
				_place_cam()


func _process(dt: float) -> void:
	t += dt
	var turn := Input.get_axis("ui_left", "ui_right")
	yaw += turn * dt * 2.0
	for r in rigs:
		var n: Node3D = r.root
		var base := PI
		if rigs.find(r) == 4:
			base = PI * 0.5
		elif rigs.find(r) == 5:
			base = PI * 0.75
		n.rotation.y = base + yaw
		var w: bool = r.walk or all_walk
		people.pose(r, t * 1.3 * PI / 0.65 * 0.6, 1.0 if w else 0.0)


func _shot(path: String) -> void:
	t = 0.35
	for f in 10:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(path)
	print("shot ", path)
	get_tree().quit()
