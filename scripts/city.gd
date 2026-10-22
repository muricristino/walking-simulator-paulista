extends Node

const Geo := preload("res://scripts/geo.gd")
const Player := preload("res://scripts/player.gd")
const Autowalk := preload("res://scripts/autowalk.gd")
const Layout := preload("res://scripts/layout.gd")
const Paulista := preload("res://scripts/paulista.gd")
const Traffic := preload("res://scripts/traffic.gd")
const Crowd := preload("res://scripts/crowd.gd")
const Hud := preload("res://scripts/hud.gd")
const PS1 := preload("res://scripts/ps1.gdshader")
const RES := Vector2i(640, 480)

var vp: SubViewport
var world: Node3D
var geo: Geo
var walls: StaticBody3D
var floors: StaticBody3D
var player: CharacterBody3D
var M := {}
var paulista: Paulista
var traffic: Traffic
var crowd: Crowd
var hud: Hud
var rio: RefCounted:
	get:
		return paulista.rio if paulista else null
var movers: Array:
	get:
		return traffic.movers if traffic else []
var walkers: Array:
	get:
		return crowd.walkers if crowd else []
var statics: Array:
	get:
		return crowd.statics if crowd else []
var goal_done: bool:
	get:
		return hud.goal_done if hud else false


func _input(e: InputEvent) -> void:
	if vp:
		vp.push_input(e)


func _ready() -> void:
	paulista = _module(Paulista, "Paulista")
	traffic = _module(Traffic, "Traffic")
	crowd = _module(Crowd, "Crowd")
	hud = _module(Hud, "Hud")
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
	paulista.setup(self)
	paulista.materials()
	paulista.environment()
	paulista.build()
	traffic.build(self)
	crowd.build(self)
	geo.build(world)
	paulista.bounds()
	_camera()
	_screen()
	hud.build(self)
	_maybe_shot()


func _module(script: Script, n: String) -> Node:
	var m: Node = script.new()
	m.name = n
	add_child(m)
	return m


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


func solid(c: Vector3, size: Vector3, floor := false) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = c
	(floors if floor else walls).add_child(cs)


func _camera() -> void:
	var args := OS.get_cmdline_user_args()
	player = Player.new()
	player.auto = args.has("--autowalk") or args.has("--shot")
	world.add_child(player)
	var feet := Layout.SPAWN_FEET
	var target := Layout.SPAWN_LOOK
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
