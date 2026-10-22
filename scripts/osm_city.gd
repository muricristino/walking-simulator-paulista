extends RefCounted

const PS1 := preload("res://scripts/ps1.gdshader")
const DIR := "res://assets/buildings/"
const FLOOR := 3.1
const GROUND := 4.5
const LANDMARKS := {"safra": 1.0, "fiesp": 1.0, "gazeta": 1.0, "center3": 1.0, "conjunto": 1.0}
const TINTS := [Color(1, 1, 1), Color(1.05, 1.0, 0.92), Color(0.92, 0.95, 1.05), Color(1.08, 1.04, 0.98), Color(0.88, 0.88, 0.9), Color(1.0, 0.93, 0.88), Color(0.95, 1.02, 0.97)]

var styles := {}
var pools := {"tower": [], "mid": [], "low": []}
var mats := {}
var glow := 0.3
var tools := {}
var rng := RandomNumberGenerator.new()
var faces := PackedVector3Array()
var zrange := Vector2(-INF, INF)
var gaps := []


func _init() -> void:
	styles = JSON.parse_string(FileAccess.get_file_as_string(DIR + "styles.json"))
	for k in styles:
		var kind: String = styles[k].kind
		if pools.has(kind):
			pools[kind].append(k)
	pools.mid.append("conjunto")
	styles["conjunto"] = {"floors": 14, "aspect": 1.0, "kind": "mid"}
	for k in ["e_concrete", "e_panel", "e_bricks"]:
		styles[k] = {"floors": 3, "aspect": 1.0, "kind": "empena"}
	for k in ["safra", "fiesp", "gazeta", "center3"]:
		styles[k] = {"floors": 0, "aspect": 0.5, "kind": "landmark"}


func _tex(path: String) -> ImageTexture:
	return ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))


func _mat(style: String) -> ShaderMaterial:
	if mats.has(style):
		return mats[style]
	var m := ShaderMaterial.new()
	m.shader = PS1
	if style == "roof":
		m.set_shader_parameter("tex", _tex(DIR + "e_concrete_c.png"))
		m.set_shader_parameter("tint", Color(0.62, 0.6, 0.58))
	else:
		m.set_shader_parameter("tex", _tex(DIR + style + "_c.png"))
		m.set_shader_parameter("glow_tex", _tex(DIR + style + "_e.png"))
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("affine", 0.4)
	mats[style] = m
	return m


func set_glow(g: float) -> void:
	glow = g
	for k in mats:
		var f := 1.0
		if k == "fiesp":
			f = 1.8
		elif k.begins_with("t_"):
			f = 1.6
		mats[k].set_shader_parameter("glow", g * f)


func _st(key: String) -> SurfaceTool:
	if not tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[key] = st
	return tools[key]


func build(path: String) -> Node3D:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	tools.clear()
	faces = PackedVector3Array()
	for b in data.buildings:
		if _keep(b):
			_building(b)
	var root := Node3D.new()
	if faces.size() > 0:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		cs.shape = shape
		body.add_child(cs)
		root.add_child(body)
	for k in tools:
		var mi := MeshInstance3D.new()
		mi.mesh = tools[k].commit()
		mi.material_override = _mat(k)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


func _keep(b: Dictionary) -> bool:
	for p in b.p:
		if p[1] < zrange.x or p[1] > zrange.y:
			return false
		for g in gaps:
			if absf(p[1] - g.x) < g.y and absf(p[0]) < 160.0:
				return false
	return true


func _pick(kind: String, seed: int) -> String:
	var pool: Array = pools[kind]
	return pool[seed % pool.size()]


func _building(b: Dictionary) -> void:
	var seed: int = b.seed
	rng.seed = seed
	var h: float = b.h
	var land: String = b.style
	var kind := "tower" if h >= 60.0 else ("mid" if h >= 18.0 else "low")
	var style := land if land != "" and land != "conjunto" else _pick(kind, seed)
	if land == "conjunto":
		style = "conjunto"
	var body := style
	if styles[style].kind == "landmark":
		body = _pick(kind, seed + 7)
	var tint: Color = TINTS[(seed / 7) % TINTS.size()]
	tint.a = rng.randf_range(0.35, 1.25)
	var empena: String = ["e_concrete", "e_panel", "e_bricks"][(seed / 3) % 3]
	var terreo: String = ["t_shops", "t_shops", "t_lobby", "t_pilotis"][(seed / 11) % 4] if b.get("front", false) else ["t_lobby", "t_pilotis", "t_shops"][(seed / 11) % 3]
	var module := rng.randf_range(0.9, 1.15)
	var poly := PackedVector2Array()
	for p in b.p:
		poly.append(Vector2(p[0], p[1]))
	var area := 0.0
	var cen := Vector2.ZERO
	for i in poly.size():
		var a := poly[i]
		var c := poly[(i + 1) % poly.size()]
		area += a.x * c.y - c.x * a.y
		cen += a
	cen /= poly.size()
	var top := poly.duplicate()
	if land == "fiesp":
		for i in top.size():
			top[i] = Vector2(top[i].x, cen.y + (top[i].y - cen.y) * 0.45)
	var has_ground := h > 8.0
	var parapet := 1.0 if h > 8.0 else 0.4
	var avenue_dir := -signf(cen.x)
	var u := float(rng.randi_range(0, 6)) * 4.0
	for i in poly.size():
		var a := poly[i]
		var c := poly[(i + 1) % poly.size()]
		var at := top[i]
		var ct := top[(i + 1) % top.size()]
		var len := a.distance_to(c)
		if len < 0.05:
			continue
		var d := (c - a) / len
		var n := Vector3(d.y, 0, -d.x) if area > 0.0 else Vector3(-d.y, 0, d.x)
		var faces_avenue := n.x * avenue_dir > 0.6
		var side_style := body
		if styles[style].kind == "landmark":
			side_style = style if faces_avenue else body
		elif kind != "tower" and not faces_avenue and len > 7.0 and (seed + i) % 5 < 3:
			side_style = empena
		var A := Vector3(a.x, 0, a.y)
		var C := Vector3(c.x, 0, c.y)
		var hc := minf(h, 8.0)
		faces.append_array([A, C, C + Vector3(0, hc, 0), A, C + Vector3(0, hc, 0), A + Vector3(0, hc, 0)])
		var y0 := GROUND if has_ground else 0.0
		var y1 := h - parapet
		if has_ground:
			_wall(terreo, a, c, a, c, 0.0, GROUND, n, u, len, Vector2(16.0, GROUND), Color(1, 1, 1, tint.a), false)
		var lm: bool = styles[side_style].kind == "landmark"
		var sp: Dictionary = styles[side_style]
		var tile_h: float = sp.floors * FLOOR * module if not lm else (y1 - y0)
		var tile_w: float = tile_h * float(sp.aspect) if not lm else len
		var at0 := a.lerp(at, y0 / h)
		var ct0 := c.lerp(ct, y0 / h)
		var at1 := a.lerp(at, y1 / h)
		var ct1 := c.lerp(ct, y1 / h)
		var tt := tint if not side_style.begins_with("e_") else Color(tint.r, tint.g, tint.b, 0.0)
		_wall(side_style, at0, ct0, at1, ct1, y0, y1, n, u if not lm else 0.0, len, Vector2(tile_w, tile_h), tt, lm)
		var atp := a.lerp(at, 1.0)
		var ctp := c.lerp(ct, 1.0)
		_wall("roof", at1, ct1, atp, ctp, y1, h, n, u, len, Vector2(4.0, 1.0), Color(1, 1, 1, 0), false)
		u += len
	_roof(top, h, b)


func _wall(key: String, a0: Vector2, c0: Vector2, a1: Vector2, c1: Vector2, y0: float, y1: float, n: Vector3, u: float, len: float, tile: Vector2, col: Color, photo: bool) -> void:
	var st := _st(key)
	var A0 := Vector3(a0.x, y0, a0.y)
	var C0 := Vector3(c0.x, y0, c0.y)
	var A1 := Vector3(a1.x, y1, a1.y)
	var C1 := Vector3(c1.x, y1, c1.y)
	var nn := (C0 - A0).cross(A1 - A0).normalized()
	if nn.dot(n) < 0.0:
		nn = -nn
	var u0 := u / tile.x
	var u1 := (u + len) / tile.x
	var v0 := -(y1 - y0) / tile.y if not photo else 0.0
	var v1 := 0.0 if not photo else 1.0
	if key == "roof":
		v0 = 0.0
		v1 = 1.0
	var vs := [A1, C1, C0, A1, C0, A0]
	var uvs := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1)]
	if photo:
		uvs = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in 6:
		st.set_color(col)
		st.set_normal(nn)
		st.set_uv(uvs[k])
		st.add_vertex(vs[k])


func _roof(poly: PackedVector2Array, h: float, b: Dictionary) -> void:
	var st := _st("roof")
	var idx := Geometry2D.triangulate_polygon(poly)
	for k in idx.size():
		var p := poly[idx[k]]
		st.set_color(Color(0.9, 0.9, 0.9, 0))
		st.set_normal(Vector3.UP)
		st.set_uv(p / 8.0)
		st.add_vertex(Vector3(p.x, h - 0.6, p.y))
	if h < 15.0 or b.style == "fiesp":
		return
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in poly:
		mn = mn.min(p)
		mx = mx.max(p)
	var c := (mn + mx) * 0.5
	var size := (mx - mn) * 0.22
	size = size.clamp(Vector2(2.5, 2.5), Vector2(7, 7))
	if Geometry2D.is_point_in_polygon(c, poly):
		_box(c, size, h - 0.6, rng.randf_range(2.5, 4.0))
		if rng.randf() < 0.6:
			_box(c + Vector2(size.x * 0.7, 0), size * 0.5, h - 0.6 + 3.0, 2.5)
		if h > 60.0 and rng.randf() < 0.4:
			_box(c - Vector2(size.x * 0.5, 0), Vector2(0.4, 0.4), h - 0.6, rng.randf_range(10.0, 24.0))


func _box(c: Vector2, s: Vector2, y: float, hh: float) -> void:
	var p := [c + Vector2(-s.x, -s.y), c + Vector2(s.x, -s.y), c + Vector2(s.x, s.y), c + Vector2(-s.x, s.y)]
	for i in 4:
		var a: Vector2 = p[i]
		var d: Vector2 = p[(i + 1) % 4]
		var n := Vector3(d.y - a.y, 0, -(d.x - a.x)).normalized()
		if n.dot(Vector3(a.x - c.x, 0, a.y - c.y)) < 0.0:
			n = -n
		_wall("roof", a, d, a, d, y, y + hh, n, 0.0, a.distance_to(d), Vector2(4, hh), Color(0.85, 0.85, 0.85, 0), false)
	var st := _st("roof")
	for k in [0, 1, 2, 0, 2, 3]:
		var q: Vector2 = p[k]
		st.set_color(Color(0.8, 0.8, 0.8, 0))
		st.set_normal(Vector3.UP)
		st.set_uv(q / 4.0)
		st.add_vertex(Vector3(q.x, y + hh, q.y))
