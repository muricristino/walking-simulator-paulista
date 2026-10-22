extends RefCounted

const PS1 := preload("res://scripts/ps1.gdshader")
const DIR := "res://assets/people/katcho/"
const FPS := 24.0
const ALIAS := {
	"root": "hips", "hip": "hips", "hips": "hips", "back": "back", "spine": "back", "chest": "chest",
	"neck": "neck", "head": "head", "arm_upper": "uarm", "upperarm": "uarm", "arm_a": "uarm",
	"arm_lower": "larm", "lowerarm": "larm", "arm_b": "larm", "hand": "hand", "leg_upper": "uleg",
	"upperleg": "uleg", "leg_a": "uleg", "leg_lower": "lleg", "lowerleg": "lleg", "leg_b": "lleg",
	"foot": "foot", "toe": "toe",
}

const MODELS := {
	"henry": {"scene": "henry/Henry.dae", "tex": ["henry/HenryTexture512.png", "henry/var_a.png", "henry/var_b.png"], "anims": {"idle": "idle01", "walk": "walk", "phone": "@phone"}, "stride": 1.3},
	"mob01": {"scene": "mob01/mob01.dae", "tex": ["mob01/mob01.png", "mob01/var_a.png", "mob01/var_b.png"], "anims": {"idle": "idle", "walk": "walk", "phone": "@phone"}, "stride": 1.45},
	"beggar": {"scene": "beggar/beggar.dae", "tex": ["beggar/beggar1st_x512i24.png", "beggar/beggar2nd_x512i24.png"], "anims": {"idle": "idle", "walk": "walk"}, "stride": 1.45},
	"granny": {"scene": "granny/Granny.dae", "tex": ["granny/granny.png", "granny/var_a.png"], "anims": {"idle": "Oidle", "walk": "Owalk"}, "stride": 0.92},
	"gramps": {"scene": "gramps/Gramps.dae", "tex": ["gramps/gramps.png", "gramps/var_a.png"], "anims": {"idle": "Idle", "walk": "Walk"}, "stride": 1.08},
	"johndoe": {"scene": "johndoe/JohnDoe.dae", "tex": ["johndoe/paintSkin.png", "johndoe/paintSkin03.png", "johndoe/var_a.png", "johndoe/var_b.png"], "anims": {"idle": "idle", "walk": "walk", "phone": "@phone"}, "stride": 1.3},
	"office_f": {"scene": "office_f/female_z.dae", "tex": ["office_f/female_base_001.png", "office_f/female_base_002.png", "office_f/female_base_003.png", "office_f/female_base_004.png", "office_f/female_base_005.png", "office_f/female_base_006.png"], "anims": {"idle": ["nanzy", "nanzy_idle"], "walk": ["nanzy", "nanzy_walk"], "phone": "@phone"}, "stride": 1.3, "hide": ["zf_head_02"]},
	"office_m": {"scene": "office_m/male_z.dae", "tex": ["office_m/male_z01.png", "office_m/var_a.png", "office_m/var_b.png"], "anims": {"idle": ["mob01", "idle"], "walk": ["mob01", "walk"], "phone": "@phone"}, "stride": 1.4},
	"nanzy": {"scene": "nanzy/Nanzy.dae", "tex": ["nanzy/Nanzy_x256_i86.png"], "anims": {"idle": "nanzy_idle", "walk": "nanzy_walk", "phone": "@phone"}, "stride": 1.3},
}

var mats := {}
var scenes := {}
var skins := {}
var rigs := {}
var baked := {}
var shadow_mesh: ArrayMesh
var phone_mesh: Mesh
var phone_at := {}


func _mat(path: String, tint := Color.WHITE) -> ShaderMaterial:
	var key := path + str(tint)
	if mats.has(key):
		return mats[key]
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter("tex", load(DIR + path))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("affine", 0.25)
	mats[key] = m
	return m


func texs(model: String) -> Array:
	var out := []
	for t in MODELS[model].tex:
		if ResourceLoader.exists(DIR + t):
			out.append(t)
	return out


func variants() -> Array:
	var out := []
	for k in MODELS:
		for i in texs(k).size():
			out.append([k, i])
	return out


func _scene(model: String) -> PackedScene:
	if not scenes.has(model):
		scenes[model] = load(DIR + MODELS[model].scene)
	return scenes[model]


func make(model: String, tex_i := 0, height := 1.72, tint := Color.WHITE) -> Dictionary:
	var spec: Dictionary = MODELS[model]
	var inst: Node3D = _scene(model).instantiate()
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var tl := texs(model)
	var m := _mat(tl[tex_i % tl.size()], tint)
	var hide: Array = spec.get("hide", [])
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var skinned: bool = (mi.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_BONES) != 0
		if mi.name == "Cap":
			_hat(mi, sk, m, spec)
			continue
		if not skinned or mi.name == "CaneDummy" or hide.has(String(mi.name)):
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
	var names := {}
	for key in spec.anims:
		var a := _resolve(model, key, ap, sk)
		if a != "":
			names[key] = a
	return {"root": root, "ap": ap, "sk": sk, "spec": spec, "model": model, "scale": k, "anims": names, "stride": float(spec.stride) * height / 1.72}


func _resolve(model: String, key: String, ap: AnimationPlayer, sk: Skeleton3D) -> String:
	if not ap:
		return ""
	var want: Variant = MODELS[model].anims[key]
	var out := ""
	var pose := ""
	if want is String and want.begins_with("@"):
		pose = want.substr(1)
		want = MODELS[model].anims.idle
		if want is String:
			want = [model, want]
	if want is String:
		out = want
	else:
		out = "x_" + key
		if not ap.has_animation(out):
			var anim := _bake(model, sk, ap, want[0], want[1], pose)
			if anim:
				ap.get_animation_library("").add_animation(out, anim)
	if not ap.has_animation(out):
		return ""
	ap.get_animation(out).loop_mode = Animation.LOOP_LINEAR
	return out


static func canon(n: String) -> String:
	var s := n.to_lower().replace("_bone", "")
	var side := ""
	if s.ends_with(".l") or s.ends_with(".r"):
		side = s.right(2)
		s = s.left(s.length() - 2)
	return ALIAS.get(s, "") + side if ALIAS.has(s) else ""


func _rig(model: String) -> Dictionary:
	if rigs.has(model):
		return rigs[model]
	var inst: Node3D = _scene(model).instantiate()
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	var r := _rig_of(sk, _main_skin(MODELS[model], sk))
	r.anims = {}
	for a in ap.get_animation_list():
		r.anims[a] = ap.get_animation(a)
	inst.free()
	rigs[model] = r
	return r


func _main_skin(spec: Dictionary, sk: Skeleton3D) -> Skin:
	var best: MeshInstance3D = null
	for c in sk.get_parent().find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if (mi.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_BONES) == 0:
			continue
		if best == null or mi.mesh.get_faces().size() > best.mesh.get_faces().size():
			best = mi
	return _skin(spec, best.name, sk) if best else null


func _rig_of(sk: Skeleton3D, skin: Skin) -> Dictionary:
	var n := sk.get_bone_count()
	var names := []
	var parents := []
	var rest := []
	var glob := []
	var order := []
	var by_canon := {}
	for b in n:
		names.append(sk.get_bone_name(b))
		parents.append(sk.get_bone_parent(b))
		rest.append(sk.get_bone_rest(b))
		glob.append(Transform3D.IDENTITY)
		var c := canon(sk.get_bone_name(b))
		if c != "" and not by_canon.has(c):
			by_canon[c] = b
	var depth := []
	for b in n:
		var d := 0
		var p: int = parents[b]
		while p >= 0:
			d += 1
			p = parents[p]
		depth.append(d)
	order = range(n)
	order.sort_custom(func(a, b): return depth[a] < depth[b])
	var ref := {}
	if skin:
		for i in skin.get_bind_count():
			ref[skin.get_bind_bone(i) if skin.get_bind_bone(i) >= 0 else i] = skin.get_bind_pose(i).affine_inverse()
	for b in order:
		if ref.has(b):
			glob[b] = ref[b]
		else:
			glob[b] = rest[b] if parents[b] < 0 else glob[parents[b]] * rest[b]
	return {"names": names, "parents": parents, "rest": rest, "glob": glob, "order": order, "canon": by_canon}


func _bake(model: String, sk: Skeleton3D, ap: AnimationPlayer, src_model: String, src_anim: String, pose := "") -> Animation:
	var key := "%s>%s>%s" % [src_model + ":" + src_anim, model, pose]
	if baked.has(key):
		return baked[key]
	var src := _rig(src_model)
	if not src.anims.has(src_anim):
		return null
	var A: Animation = src.anims[src_anim]
	var dst := _rig_of(sk, _main_skin(MODELS[model], sk))
	var prefix := String(ap.get_node(ap.root_node).get_path_to(sk))
	var rtrack := {}
	var ptrack := {}
	for t in A.get_track_count():
		var bn := String(A.track_get_path(t).get_concatenated_subnames())
		var bi: int = src.names.find(bn)
		if bi < 0:
			continue
		if A.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			rtrack[bi] = t
		elif A.track_get_type(t) == Animation.TYPE_POSITION_3D:
			ptrack[bi] = t
	var map := {}
	for b in dst.names.size():
		var c := canon(dst.names[b])
		if c != "" and src.canon.has(c):
			map[b] = src.canon[c]
	var hs: int = src.canon.get("hips", -1)
	var ht: int = dst.canon.get("hips", -1)
	var ratio := 1.0
	if hs >= 0 and ht >= 0:
		ratio = absf(dst.glob[ht].origin.y) / maxf(absf(src.glob[hs].origin.y), 0.001)
	var out := Animation.new()
	out.length = A.length
	out.loop_mode = Animation.LOOP_LINEAR
	var otr := {}
	var opt := {}
	for b in dst.names.size():
		var t := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(t, NodePath(prefix + ":" + dst.names[b]))
		otr[b] = t
		t = out.add_track(Animation.TYPE_POSITION_3D)
		out.track_set_path(t, NodePath(prefix + ":" + dst.names[b]))
		opt[b] = t
	var bl := []
	for b in dst.names.size():
		var p: int = dst.parents[b]
		var g: Transform3D = dst.glob[b]
		bl.append(g.orthonormalized() if p < 0 else ((dst.glob[p] as Transform3D).orthonormalized().affine_inverse() * g.orthonormalized()))
	var over := {}
	if pose == "phone":
		over = _phone_dirs(dst)
	var frames := maxi(2, int(ceil(A.length * FPS)) + 1)
	var gs := []
	gs.resize(src.names.size())
	var gt := []
	gt.resize(dst.names.size())
	for f in frames:
		var time := minf(f / FPS, A.length)
		for b in src.order:
			var r: Transform3D = src.rest[b]
			var loc := r
			if rtrack.has(b):
				loc.basis = Basis(A.rotation_track_interpolate(rtrack[b], time)).scaled(r.basis.get_scale())
			if ptrack.has(b):
				loc.origin = A.position_track_interpolate(ptrack[b], time)
			var p: int = src.parents[b]
			gs[b] = loc if p < 0 else gs[p] * loc
		for b in dst.order:
			var p: int = dst.parents[b]
			var pg: Transform3D = Transform3D.IDENTITY if p < 0 else gt[p]
			var base: Transform3D = bl[b]
			var lq := base.basis.get_rotation_quaternion()
			if map.has(b):
				var s: int = map[b]
				var want_q: Quaternion = (gs[s] as Transform3D).basis.get_rotation_quaternion() * (src.glob[s] as Transform3D).basis.get_rotation_quaternion().inverse() * (dst.glob[b] as Transform3D).basis.get_rotation_quaternion()
				if over.has(b):
					var ov: Array = over[b]
					want_q = ov[0] if ov[1] else ov[0] * want_q
				lq = (pg.basis.get_rotation_quaternion().inverse() * want_q).normalized()
			var o := base.origin
			if b == ht and hs >= 0:
				var d: Vector3 = ((gs[hs] as Transform3D).origin - (src.glob[hs] as Transform3D).origin) * ratio
				var pr: Transform3D = Transform3D.IDENTITY if p < 0 else (dst.glob[p] as Transform3D).orthonormalized()
				o += pr.basis.inverse() * d
			out.rotation_track_insert_key(otr[b], time, lq)
			out.position_track_insert_key(opt[b], time, o)
			var loc := Transform3D(Basis(lq), o)
			gt[b] = loc if p < 0 else pg * loc
		if f == 0 and over.has(-1):
			var hb: int = over[-1][0]
			phone_at[model] = Transform3D(Basis(Quaternion(Vector3.UP, over[-1][1])), (gt[hb] as Transform3D).origin + over[-1][1] * over[-1][2])
	baked[key] = out
	return out


func _phone_dirs(r: Dictionary) -> Dictionary:
	var c: Dictionary = r.canon
	var out := {}
	if not (c.has("uarm.r") and c.has("larm.r") and c.has("hand.r")):
		return out
	var g: Array = r.glob
	var ua: int = c["uarm.r"]
	var la: int = c["larm.r"]
	var ha: int = c["hand.r"]
	var xr := signf((g[ua] as Transform3D).origin.x)
	var fwd := Vector3(0, 0, 1)
	var up_d := Vector3(-xr * 0.12, -1.0, 0.3).normalized()
	var fore := (Vector3(-xr * 0.5, 0.0, 0.0) + fwd * 0.75 + Vector3.UP * 0.55).normalized()
	var d_ua := ((g[la] as Transform3D).origin - (g[ua] as Transform3D).origin).normalized()
	var d_la := ((g[ha] as Transform3D).origin - (g[la] as Transform3D).origin).normalized()
	var rot := func(b: int) -> Quaternion: return (g[b] as Transform3D).basis.orthonormalized().get_rotation_quaternion()
	out[ua] = [Quaternion(d_ua, up_d) * rot.call(ua), true]
	out[la] = [Quaternion(d_la, fore) * rot.call(la), true]
	out[ha] = [Quaternion(d_la, fore) * rot.call(ha), true]
	if c.has("head"):
		out[c.head] = [Quaternion(Vector3.RIGHT, 0.38), false]
	var flen := ((g[ha] as Transform3D).origin - (g[la] as Transform3D).origin).length()
	out[-1] = [ha, fore, flen * 0.3]
	return out


func phone(c: Dictionary) -> void:
	if not phone_at.has(c.model):
		return
	if not phone_mesh:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.14, 0.014)
		var m := ShaderMaterial.new()
		m.shader = PS1
		var im := Image.create(2, 2, false, Image.FORMAT_RGB8)
		im.fill(Color(0.04, 0.04, 0.05))
		m.set_shader_parameter("tex", ImageTexture.create_from_image(im))
		m.set_shader_parameter("emit", Vector3(0.1, 0.13, 0.2))
		bm.material = m
		phone_mesh = bm
	var sk: Skeleton3D = c.sk
	var at: Transform3D = phone_at[c.model]
	var mi := MeshInstance3D.new()
	mi.mesh = phone_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var basis := Basis(Quaternion(Vector3.UP, (at.basis * Vector3.UP).normalized()))
	var gs := (sk.get_parent() as Node3D).transform.basis.get_scale().x * float(c.scale)
	mi.transform = Transform3D(basis.scaled(Vector3.ONE / maxf(gs, 0.0001)), at.origin)
	sk.add_child(mi)
	c.phone = mi


func shadow() -> ArrayMesh:
	if shadow_mesh:
		return shadow_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var a := TAU * i / 8.0
		var b := TAU * (i + 1) / 8.0
		for v in [Vector3(0, 0.012, 0), Vector3(cos(a) * 0.3, 0.012, sin(a) * 0.24), Vector3(cos(b) * 0.3, 0.012, sin(b) * 0.24)]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(v)
	var m := ShaderMaterial.new()
	m.shader = PS1
	var im := Image.create(2, 2, false, Image.FORMAT_RGB8)
	im.fill(Color(0.03, 0.03, 0.04))
	m.set_shader_parameter("tex", ImageTexture.create_from_image(im))
	shadow_mesh = st.commit()
	shadow_mesh.surface_set_material(0, m)
	return shadow_mesh


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
	mi.owner = null
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


func play(c: Dictionary, walking: Variant, offset := 0.0, speed := 1.0) -> void:
	var ap: AnimationPlayer = c.ap
	if not ap:
		return
	var key: String = walking if walking is String else ("walk" if walking else "idle")
	var a: String = c.anims.get(key, c.anims.get("idle", ""))
	if a == "" or not ap.has_animation(a):
		return
	ap.play(a, 0.25, speed)
	if offset > 0.0:
		ap.seek(fmod(offset, ap.get_animation(a).length), true)
