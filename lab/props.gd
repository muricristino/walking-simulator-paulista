extends Node

const Tex := preload("res://scripts/tex.gd")
const Geo := preload("res://scripts/geo.gd")
const Props := preload("res://scripts/props.gd")
const PS1 := preload("res://scripts/ps1.gdshader")

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var holder: Node3D
var label: Label
var novo := true
var yaw := 0.0
var props := Props.new()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--atual"):
		novo = false
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
	cam.position = Vector3(0, 1.7, 5.5)
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
	cam.rotation = Vector3(0.16, yaw, 0)


func _mat(tex: Texture2D, emit := Color.BLACK, unshaded := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("emit", Vector3(emit.r, emit.g, emit.b))
	m.set_shader_parameter("unshaded", unshaded)
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
	for x in [-5.0, 5.0]:
		var ol := OmniLight3D.new()
		ol.position = Vector3(x, 6.0, 0.0)
		ol.light_color = Color(1.0, 0.68, 0.38)
		ol.light_energy = 5.0
		ol.omni_range = 14.0
		ol.omni_attenuation = 0.9
		world.add_child(ol)


func _build() -> void:
	for c in holder.get_children():
		c.queue_free()
	var g := Geo.new()
	g.add_mat("mosaic", _mat(Tex.mosaic(4)))
	g.add_mat("curb", _mat(Tex.flat(Color(0.62, 0.6, 0.58), 8, 0.03, 0.3, 6)))
	g.add_mat("asphalt", _mat(Tex.plate("res://assets/road/b_128.png")))
	g.ground("mosaic", -14, 14, -11, 4.5, 0.15, Vector2(0.8, 0.8))
	g.ground("asphalt", -14, 14, 4.9, 20, 0.0, Vector2(3.5, 3.5))
	g.ground("curb", -14, 14, 4.5, 4.9, 0.15, Vector2(2, 2))
	g.build(holder)
	if novo:
		_novo()
	else:
		_atual()
	label.text = "%s\nP alterna atual/novo   <- -> girar   cima/baixo andar" % ("NOVO" if novo else "ATUAL")


func _atual() -> void:
	var g := Geo.new()
	var mats := {
		"trunk": _mat(Tex.flat(Color(0.25, 0.19, 0.14), 8, 0.04, 0.3, 12)),
		"metal": _mat(Tex.flat(Color(0.3, 0.31, 0.33), 8, 0.03, 0.2, 11)),
		"dark": _mat(Tex.flat(Color(0.12, 0.12, 0.13), 8, 0.02, 0.2, 10)),
		"lamp": _mat(Tex.flat(Color(0.8, 0.8, 0.8), 8, 0.04, 0.2, 1), Color(1.6, 1.05, 0.55), 1.0),
		"banca": _mat(Tex.flat(Color(0.12, 0.32, 0.2), 8, 0.03, 0.3, 50)),
		"placa": _mat(Tex.plate("res://art/placa.png")),
	}
	for k in mats:
		g.add_mat(k, mats[k])
	var t := Tex.facade(101, 10, 8, 1, Color(0.62, 0.58, 0.5), Color(0.14, 0.16, 0.18), 0.4)
	var fm := _mat(t[0])
	fm.set_shader_parameter("glow_tex", t[1])
	fm.set_shader_parameter("glow", 1.0)
	g.add_mat("facade", fm)
	g.box("facade", Vector3(0, 12, -14), Vector3(30, 24, 6), Vector2(30, 28.8))
	var p := Vector3(-6.5, 0.15, -2.0)
	g.box("trunk", p + Vector3(0, 1.8, 0), Vector3(0.4, 3.6, 0.4), Vector2(1, 2))
	var leaf := _mat(Tex.leaves(20, Color(0.13, 0.25, 0.1)))
	for k in 3:
		var sm := SphereMesh.new()
		sm.radius = 2.0
		sm.height = 3.0
		sm.radial_segments = 6
		sm.rings = 3
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = leaf
		mi.position = p + Vector3([-0.8, 0.6, 0.0][k], 4.4 + k * 0.4, [0.3, -0.4, 0.6][k])
		holder.add_child(mi)
	var x := -3.2
	g.box("metal", Vector3(x, 5.0, -2), Vector3(0.25, 10.0, 0.25), Vector2(1, 4))
	g.box("metal", Vector3(x + 1.6, 9.9, -2), Vector3(3.2, 0.18, 0.18), Vector2(1, 1))
	g.box("lamp", Vector3(x + 3.0, 9.75, -2), Vector3(0.9, 0.22, 0.4), Vector2(1, 1))
	g.box("dark", Vector3(0.0, 0.6, -2.0), Vector3(1.8, 0.9, 0.6), Vector2(1, 1))
	g.box("metal", Vector3(3.5, 1.8, -2.0), Vector3(0.1, 3.6, 0.1), Vector2(1, 1))
	g.quad("placa", Vector3(2.2, 2.9, -1.95), Vector3(4.8, 2.9, -1.95), Vector3(4.8, 3.6, -1.95), Vector3(2.2, 3.6, -1.95), Vector3.BACK, Vector2(2.6, 0.7))
	g.box("banca", Vector3(8.0, 1.5, -3.0), Vector3(3.0, 2.7, 6.0), Vector2(1, 1))
	g.build(holder)


func _novo() -> void:
	holder.add_child(props.shopfront(Vector3(0, 0.15, -11.0), 28.0))
	holder.add_child(props.tree(Vector3(-6.5, 0.15, -2.0), 1.0, 3))
	var lamp := props.lamp()
	lamp.position = Vector3(-3.2, 0.15, -2.0)
	holder.add_child(lamp)
	var bench := props.bench()
	bench.position = Vector3(0.0, 0.15, -2.0)
	holder.add_child(bench)
	var trash := props.trash()
	trash.position = Vector3(1.8, 0.15, -1.6)
	holder.add_child(trash)
	holder.add_child(props.street_sign(Vector3(3.6, 0.15, -2.0)))
	holder.add_child(props.tree(Vector3(7.5, 0.15, -2.5), 1.15, 8))


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_P:
		novo = not novo
		_build()


func _process(dt: float) -> void:
	var turn := Input.get_axis("ui_right", "ui_left")
	var move := Input.get_axis("ui_down", "ui_up")
	if turn != 0.0:
		yaw += turn * dt * 1.5
		_aim()
	if move != 0.0:
		cam.position += -cam.global_basis.z * Vector3(1, 0, 1) * move * dt * 3.0


func _shot(path: String) -> void:
	for f in 12:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	print("shot ", path)
	get_tree().quit()
