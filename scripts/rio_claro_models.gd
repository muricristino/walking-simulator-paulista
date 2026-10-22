extends RefCounted

const PS1 := preload("res://scripts/ps1.gdshader")
const CUT := preload("res://scripts/ps1_cut.gdshader")
const DIR := "res://assets/rioclaro/"
const SECTIONS := ["rc_calcadao", "rc_rua"]

var mats := {}
var glow_mats := []
var lamp_mats := []
var replaced := {}
var lamps := []
var ranges := []
var floor_faces := PackedVector3Array()
var wall_faces := PackedVector3Array()


func _tex(name: String) -> ImageTexture:
	var p := ProjectSettings.globalize_path(DIR + "tex/" + name + ".png")
	if not FileAccess.file_exists(p):
		return null
	return ImageTexture.create_from_image(Image.load_from_file(p))


func material(name: String) -> ShaderMaterial:
	if mats.has(name):
		return mats[name]
	var cut := name.begins_with("cut__")
	var key := name.trim_prefix("cut__")
	var m := ShaderMaterial.new()
	m.shader = CUT if cut else PS1
	m.set_shader_parameter("tex", _tex(key))
	var e := _tex(key + "_e")
	if e:
		m.set_shader_parameter("glow_tex", e)
		m.set_shader_parameter("glow", 0.2)
		glow_mats.append(m)
	if key == "lamp":
		m.set_shader_parameter("emit", Vector3(1.4, 1.0, 0.6))
		m.set_shader_parameter("unshaded", 1.0)
		lamp_mats.append(m)
	mats[name] = m
	return m


func set_glow(g: float, night: bool) -> void:
	for m in glow_mats:
		m.set_shader_parameter("glow", g)
	for m in lamp_mats:
		m.set_shader_parameter("emit", Vector3(2.2, 1.3, 0.5) if night else Vector3(1.2, 0.9, 0.6))


func available() -> bool:
	for s in SECTIONS:
		if ResourceLoader.exists(DIR + s + ".glb"):
			return true
	return false


func build() -> Node3D:
	var root := Node3D.new()
	root.name = "RioClaroModels"
	for s in SECTIONS:
		if not ResourceLoader.exists(DIR + s + ".glb"):
			continue
		var meta_path := ProjectSettings.globalize_path(DIR + s + ".json")
		if FileAccess.file_exists(meta_path):
			var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
			for i in meta.get("replaced", []):
				replaced[int(i)] = true
			for l in meta.get("lamps", []):
				lamps.append(Vector3(l[0], l[1], l[2]))
			if meta.has("range"):
				ranges.append(Vector2(meta.range[0], meta.range[1]))
		var scene: PackedScene = load(DIR + s + ".glb")
		var inst := scene.instantiate()
		_walk(inst, root)
		inst.free()
	_body(root, floor_faces, 2)
	_body(root, wall_faces, 1)
	return root


func covers(s: float) -> bool:
	for r in ranges:
		if s >= r.x and s <= r.y:
			return true
	return false


func _walk(n: Node, root: Node3D) -> void:
	for c in n.get_children():
		_walk(c, root)
	if not (n is MeshInstance3D):
		return
	var mi: MeshInstance3D = n
	var xf := mi.global_transform if mi.is_inside_tree() else _xf(mi)
	if String(mi.name).begins_with("COL_"):
		var faces := xf * mi.mesh.get_faces()
		if String(mi.name).begins_with("COL_floor"):
			floor_faces.append_array(faces)
		else:
			wall_faces.append_array(faces)
		return
	var out := MeshInstance3D.new()
	out.name = mi.name
	out.mesh = mi.mesh
	out.transform = xf
	out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in mi.mesh.get_surface_count():
		var sm := mi.mesh.surface_get_material(i)
		var nm := sm.resource_name if sm else "white"
		out.set_surface_override_material(i, material(nm))
	root.add_child(out)


func _xf(n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p := n
	while p and p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _body(root: Node3D, faces: PackedVector3Array, layer: int) -> void:
	if faces.is_empty():
		return
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)
