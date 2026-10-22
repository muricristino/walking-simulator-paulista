extends Node

const Tex := preload("res://scripts/tex.gd")
const Geo := preload("res://scripts/geo.gd")
const PS1 := preload("res://scripts/ps1.gdshader")
const OPTS := ["atual", "A", "B", "C"]
const RES := [64, 128, 256]

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var holder: Node3D
var label: Label
var opt := 1
var res_i := 1
var yaw := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var ri := args.find("--road")
	if ri >= 0 and ri + 1 < args.size():
		opt = maxi(0, OPTS.find(args[ri + 1]))
	var si := args.find("--res")
	if si >= 0 and si + 1 < args.size():
		res_i = maxi(0, RES.find(int(args[si + 1])))
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
	cam = Camera3D.new()
	cam.fov = 64.0
	cam.far = 900.0
	cam.current = true
	cam.position = Vector3(17.2, 1.75, 6.0)
	world.add_child(cam)
	_aim()
	holder = Node3D.new()
	world.add_child(holder)
	_build()
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


func _aim() -> void:
	cam.rotation = Vector3(-0.2, 0.42 + yaw, 0)


func _mat(tex: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter("tex", tex)
	return m


func _img(path: String) -> ImageTexture:
	return ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))


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
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.45, 0.5, 0.85)
	fill.light_energy = 0.25
	fill.rotation_degrees = Vector3(-50, 20, 0)
	world.add_child(fill)
	var z := -14.0
	while z > -200.0:
		for sx in [-1.0, 1.0]:
			var ol := OmniLight3D.new()
			ol.position = Vector3(sx * 14.0, 9.0, z - (16.0 if sx < 0 else 0.0))
			ol.light_color = Color(1.0, 0.68, 0.38)
			ol.light_energy = 9.0
			ol.omni_range = 16.0
			ol.omni_attenuation = 0.9
			world.add_child(ol)
		z -= 32.0


func _build() -> void:
	for c in holder.get_children():
		c.queue_free()
	var g := Geo.new()
	var name: String = OPTS[opt]
	var white := Tex.flat(Color(0.8, 0.8, 0.8), 8, 0.04, 0.2, 1)
	var unit := Vector2(4, 4)
	if name == "atual":
		g.add_mat("asphalt", _mat(Tex.asphalt(3)))
		var pm := _mat(white)
		pm.set_shader_parameter("tint", Color(0.9, 0.9, 0.85))
		g.add_mat("paint", pm)
		var py := _mat(white)
		py.set_shader_parameter("tint", Color(0.95, 0.75, 0.2))
		g.add_mat("paint_y", py)
		g.add_mat("bike", _mat(Tex.flat(Color(0.62, 0.12, 0.1), 16, 0.05, 0.5, 7)))
	else:
		g.add_mat("asphalt", _mat(_img("res://assets/road/%s_%d.png" % [name.to_lower(), RES[res_i]])))
		g.add_mat("paint", _mat(_img("res://assets/road/paint_white.png")))
		g.add_mat("paint_y", _mat(_img("res://assets/road/paint_yellow.png")))
		g.add_mat("bike", _mat(_img("res://assets/road/bike_red.png")))
		unit = Vector2(3.5, 3.5)
	g.add_mat("mosaic", _mat(Tex.mosaic(4)))
	g.add_mat("curb", _mat(Tex.flat(Color(0.62, 0.6, 0.58), 8, 0.03, 0.3, 6)))
	var z0 := -400.0
	var z1 := 20.0
	g.ground("asphalt", -16, -2, z0, z1, 0.0, unit)
	g.ground("asphalt", 2, 16, z0, z1, 0.0, unit)
	g.ground("bike", -1.6, 1.6, z0, z1, 0.2, Vector2(3.5, 3.5))
	g.ground("curb", -2.0, -1.6, z0, z1, 0.2, Vector2(2, 2))
	g.ground("curb", 1.6, 2.0, z0, z1, 0.2, Vector2(2, 2))
	g.ground("mosaic", 16, 30, z0, z1, 0.15, Vector2(0.8, 0.8))
	g.ground("mosaic", -30, -16, z0, z1, 0.15, Vector2(0.8, 0.8))
	for x in [16.0, -16.0]:
		var s := signf(x)
		g.quad("curb", Vector3(x, 0, z1), Vector3(x, 0, z0), Vector3(x, 0.15, z0), Vector3(x, 0.15, z1), Vector3(-s, 0, 0), Vector2(2, 0.5))
	var z := z1
	while z > z0:
		for lx in [5.5, 9.0, 12.5]:
			for sx in [-1.0, 1.0]:
				var x: float = sx * lx
				var w := 0.15
				if lx == 12.5:
					g.ground("paint", x - w, x + w, z - 9.0, z, 0.02, Vector2(0.3, 3.0), 20.0)
				else:
					g.ground("paint", x - w, x + w, z - 3.0, z, 0.02, Vector2(0.3, 3.0), 20.0)
		g.ground("paint_y", -0.08, 0.08, z - 2.0, z, 0.21, Vector2(0.16, 2.0), 20.0)
		z -= 9.0
	g.build(holder)
	label.text = "asfalto: %s  %s\nP alterna atual/A/B/C   R resolucao   <- -> olhar" % [name, "" if name == "atual" else str(RES[res_i]) + "px"]


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_P:
				opt = (opt + 1) % OPTS.size()
				_build()
			KEY_R:
				res_i = (res_i + 1) % RES.size()
				_build()


func _process(dt: float) -> void:
	var turn := Input.get_axis("ui_right", "ui_left")
	if turn != 0.0:
		yaw += turn * dt * 1.5
		_aim()


func _shot(path: String) -> void:
	for f in 12:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	print("shot ", path)
	get_tree().quit()
