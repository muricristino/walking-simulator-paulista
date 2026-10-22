extends RefCounted

const PS1 := preload("res://scripts/ps1.gdshader")
const DIR := "res://assets/people/katcho/"

const MODELS := {
	"henry": {"scene": "henry/Henry.dae", "tex": ["henry/HenryTexture512.png"], "idle": "idle01", "walk": "walk", "stride": 1.35},
	"mob01": {"scene": "mob01/mob01.dae", "tex": ["mob01/mob01.png"], "idle": "idle", "walk": "walk", "stride": 1.35},
	"beggar": {"scene": "beggar/beggar.dae", "tex": ["beggar/beggar1st_x512i24.png", "beggar/beggar2nd_x512i24.png"], "idle": "idle", "walk": "walk", "stride": 1.3},
	"granny": {"scene": "granny/Granny.dae", "tex": ["granny/granny.png"], "idle": "Oidle", "walk": "Owalk", "stride": 0.9},
	"gramps": {"scene": "gramps/Gramps.dae", "tex": ["gramps/gramps.png"], "idle": "Idle", "walk": "Walk", "stride": 1.0},
}

var mats := {}
var scenes := {}
var skins := {}


func _mat(path: String) -> ShaderMaterial:
	if mats.has(path):
		return mats[path]
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter("tex", load(DIR + path))
	m.set_shader_parameter("tint", Color.WHITE)
	m.set_shader_parameter("affine", 0.25)
	mats[path] = m
	return m


func variants() -> Array:
	var out := []
	for k in MODELS:
		for i in MODELS[k].tex.size():
			out.append([k, i])
	return out


func make(model: String, tex_i := 0, height := 1.72) -> Dictionary:
	var spec: Dictionary = MODELS[model]
	if not scenes.has(model):
		scenes[model] = load(DIR + spec.scene)
	var inst: Node3D = scenes[model].instantiate()
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var m := _mat(spec.tex[tex_i % spec.tex.size()])
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var skinned: bool = (mi.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_BONES) != 0
		if mi.name == "Cap":
			_hat(mi, sk, m, spec)
			continue
		if not skinned or mi.name == "CaneDummy":
			mi.get_parent().remove_child(mi)
			mi.free()
			continue
		if mi.skin == null:
			mi.skeleton = mi.get_path_to(sk)
			mi.skin = _skin(spec, mi.name, sk)
		for si in mi.mesh.get_surface_count():
			mi.set_surface_override_material(si, m)
	var root := Node3D.new()
	root.add_child(inst)
	var box := _bounds(inst)
	var k := height / maxf(box.size.y, 0.01)
	inst.scale *= k
	box = _bounds(inst)
	inst.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	for a in [spec.idle, spec.walk]:
		if ap and ap.has_animation(a):
			ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	return {"root": root, "ap": ap, "spec": spec, "model": model, "scale": k}


func _hat(mi: MeshInstance3D, sk: Skeleton3D, m: Material, spec: Dictionary) -> void:
	var head := sk.find_bone("Head")
	var body: MeshInstance3D = null
	for c in sk.get_children():
		if c is MeshInstance3D and c != mi:
			body = c
	if head < 0 or body == null:
		mi.get_parent().remove_child(mi)
		mi.free()
		return
	var top := body.get_aabb().end.y
	var box := body.get_aabb()
	var want := Transform3D(Basis(), Vector3(box.get_center().x, top - 0.115, box.get_center().z - 0.01))
	var bind := _skin(spec, body.name, sk).get_bind_pose(head)
	var ba := BoneAttachment3D.new()
	ba.bone_name = "Head"
	sk.add_child(ba)
	mi.get_parent().remove_child(mi)
	ba.add_child(mi)
	mi.transform = bind * want
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_surface_override_material(0, m)


func _m(a: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(a[0], a[4], a[8]), Vector3(a[1], a[5], a[9]), Vector3(a[2], a[6], a[10])), Vector3(a[3], a[7], a[11]))


func _skin(spec: Dictionary, mesh_name: String, sk: Skeleton3D) -> Skin:
	var key: String = spec.scene + ":" + mesh_name
	if skins.has(key):
		return skins[key]
	var path: String = DIR + spec.scene.get_base_dir() + "/skin.json"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var skin: Skin
	if data is Dictionary and data.has(mesh_name):
		var e: Dictionary = data[mesh_name]
		var bsm := _m(e.bsm)
		var conv := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3.ZERO)
		skin = Skin.new()
		for i in e.inv.size():
			var b := _m(e.inv[i]) * bsm
			b = conv * b * conv.affine_inverse()
			if sk.get_parent() is Node3D:
				b = b * (sk.get_parent() as Node3D).transform
			skin.add_bind(i, b)
	else:
		skin = sk.create_skin_from_rest_transforms()
	skins[key] = skin
	return skin


func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var xf := n.transform
		var p: Node = mi
		var chain := Transform3D.IDENTITY
		while p != n:
			chain = (p as Node3D).transform * chain if p is Node3D else chain
			p = p.get_parent()
		var b: AABB = xf * chain * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func play(c: Dictionary, walking: bool, offset := 0.0, speed := 1.0) -> void:
	var ap: AnimationPlayer = c.ap
	if not ap:
		return
	var a: String = c.spec.walk if walking else c.spec.idle
	if not ap.has_animation(a):
		return
	ap.play(a, 0.2, speed)
	if offset > 0.0:
		ap.seek(fmod(offset, ap.get_animation(a).length), true)
