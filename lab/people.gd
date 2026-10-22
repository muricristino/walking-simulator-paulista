extends Node

const Tex := preload("res://scripts/tex.gd")
const People := preload("res://scripts/people.gd")
const PS1 := preload("res://scripts/ps1.gdshader")
const Geo := preload("res://scripts/geo.gd")
const Katcho := preload("res://scripts/katcho.gd")

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
var dist := 2.5
var cam_x := 0.0
var label: Label
var katcho := Katcho.new()
var mode := "proc"
const MODES := ["proc", "katcho", "wobble"]
const PACKS := {
		"wobble": [
		["res://assets/people/wobble/PS2CharacterBase.fbx", ""],
	],
}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var si := args.find("--seed")
	if si >= 0 and si + 1 < args.size():
		seed = int(args[si + 1])
	var pk := args.find("--pack")
	if pk >= 0 and pk + 1 < args.size():
		mode = args[pk + 1]
	var cx := args.find("--camx")
	if cx >= 0 and cx + 1 < args.size():
		cam_x = float(args[cx + 1])
	var di := args.find("--dist")
	if di >= 0 and di + 1 < args.size():
		dist = float(args[di + 1])
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
	key.rotation_degrees = Vector3(-25, 20, 0)
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(1.0, 0.6, 0.4)
	fill.light_energy = 0.25
	fill.rotation_degrees = Vector3(-8, 172, 0)
	world.add_child(fill)


func _ground() -> void:
	var g := Geo.new()
	g.add_mat("floor", _mat(Tex.flat(Color(0.5, 0.5, 0.5), 16, 0.015, 0.15, 3)))
	g.add_mat("wall", _mat(Tex.flat(Color(0.55, 0.55, 0.55), 16, 0.01, 0.1, 4)))
	g.ground("floor", -20, 20, -6, 10, 0.0, Vector2(4, 4))
	g.box("wall", Vector3(0, 10, -6.5), Vector3(40, 20, 1), Vector2(4, 4))
	g.build(world)


func _place_cam() -> void:
	var h := lerpf(1.55, 0.92, clampf((dist - 0.8) / 1.7, 0.0, 1.0))
	cam.position = Vector3(cam_x, h + 0.08, dist)
	cam.look_at(Vector3(cam_x, h, 0))


func _spawn() -> void:
	for c in holder.get_children():
		c.queue_free()
	rigs.clear()
	if mode != "proc":
		_spawn_pack()
		return
	var xs := [-1.2, -0.4, 0.4, 1.2]
	for i in 4:
		var r := people.rig(seed * 10 + i)
		var n: Node3D = r.root
		n.position = Vector3(xs[i], 0, 0)
		n.rotation.y = PI
		if i == 2:
			n.rotation.y = PI * 0.5
		if i == 3:
			n.rotation.y = PI * 0.8
		r.walk = i == 3
		holder.add_child(n)
		rigs.append(r)
	_label()


func _spawn_pack() -> void:
	if mode == "katcho":
		_spawn_katcho()
		return
	var list: Array = PACKS[mode]
	var xs := [-1.2, -0.4, 0.4, 1.2]
	for i in 4:
		var e: Array = list[(seed + i) % list.size()]
		var ps: PackedScene = load(e[0])
		var inst: Node3D = ps.instantiate()
		var root := Node3D.new()
		root.add_child(inst)
		holder.add_child(root)
		_ps1ify(inst, e[1])
		var box := _bounds(inst)
		var k := 1.72 / maxf(box.size.y, 0.01)
		inst.scale *= k
		box = _bounds(inst)
		inst.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z) - root.global_position
		root.position = Vector3(xs[i], 0, 0)
		var base := 0.0
		if i == 2:
			base = PI * 0.5
		if i == 3:
			base = -PI * 0.2
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		var r := {"root": root, "pack": true, "base": base, "ap": ap, "walk": i == 3}
		rigs.append(r)
		_anim(r)
	_label()


func _spawn_katcho() -> void:
	var list := katcho.variants()
	var xs := [-1.2, -0.4, 0.4, 1.2]
	for i in 4:
		var v: Array = list[(seed + i) % list.size()]
		var c := katcho.make(v[0], v[1])
		var root: Node3D = c.root
		holder.add_child(root)
		root.position = Vector3(xs[i], 0, 0)
		var base := 0.0
		if i == 2:
			base = PI * 0.5
		if i == 3:
			base = -PI * 0.2
		var r := {"root": root, "pack": true, "base": base, "k": c, "walk": i == 3}
		rigs.append(r)
		_anim(r)
	_label()


func _anim(r: Dictionary) -> void:
	if r.has("k"):
		katcho.play(r.k, r.walk or all_walk, randf() * 3.0)
		return
	var ap: AnimationPlayer = r.ap
	if not ap:
		return
	var anims := ap.get_animation_list()
	var want := "walk" if (r.walk or all_walk) else "idle"
	var pick := ""
	for a in anims:
		if want in a.to_lower():
			pick = a
	if pick == "" and anims.size() > 0 and (r.walk or all_walk):
		pick = anims[0]
	if pick != "":
		ap.get_animation(pick).loop_mode = Animation.LOOP_LINEAR
		ap.play(pick)
	else:
		ap.stop()


func _ps1ify(n: Node, tex_path: String) -> void:
	var fallback: Texture2D = load(tex_path) if tex_path != "" else null
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		for si in mi.mesh.get_surface_count():
			var om := mi.get_active_material(si)
			var tx: Texture2D = fallback
			if om is BaseMaterial3D and om.albedo_texture and fallback == null:
				tx = om.albedo_texture
			var m := _mat(tx if tx else Tex.flat(Color(0.7, 0.7, 0.7), 4, 0.0, 0.0, 1))
			m.set_shader_parameter("affine", 0.25)
			mi.set_surface_override_material(si, m)


func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b: AABB = mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _label() -> void:
	if mode != "proc":
		label.text = "%s  set %d\n<- -> girar   cima/baixo trocar   P pack\nespaco todos andam   Z/X zoom" % [mode, seed]
		return
	label.text = "seed %d  tris~%d\n<- -> girar   cima/baixo trocar pessoas\nespaco todos andam   Z/X zoom" % [seed, people.tri_count(seed * 10)]


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
				for r in rigs:
					if r.has("pack"):
						_anim(r)
			KEY_P:
				mode = MODES[(MODES.find(mode) + 1) % MODES.size()]
				_spawn()
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
		if r.has("pack"):
			n.rotation.y = r.base + yaw
			continue
		var base := PI
		if rigs.find(r) == 2:
			base = PI * 0.5
		elif rigs.find(r) == 3:
			base = PI * 0.8
		n.rotation.y = base + yaw
		var w: bool = r.walk or all_walk
		people.pose(r, t * 1.3 * PI / 0.65 * 0.6, 1.0 if w else 0.0)


func _shot(path: String) -> void:
	t = 0.35
	for f in 50:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(path)
	print("shot ", path)
	get_tree().quit()
