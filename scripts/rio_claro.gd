extends RefCounted

const Tex := preload("res://scripts/tex.gd")
const PS1 := preload("res://scripts/ps1.gdshader")
const OsmCity := preload("res://scripts/osm_city.gd")
const Props := preload("res://scripts/props.gd")
const Models := preload("res://scripts/rio_claro_models.gd")

var data: Dictionary
var grid: Dictionary
var props := Props.new()
var osm := OsmCity.new()
var tools := {}
var mats := {}
var floor_faces := PackedVector3Array()
var root: Node3D
var start := Vector3.ZERO
var end := Vector3.ZERO
var lamps := []
var models := Models.new()
var use_models := true


func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/osm/rioclaro.json"))
	grid = data.grid


func corridor() -> Array:
	var pts := []
	for q in data.street:
		pts.append(Vector2(q.p[0], q.p[1]))
	pts[0] = pts[0] + Vector2(30.0, 0.0)
	return [pts, 11.0]


func height(x: float, z: float) -> float:
	var fx := (x - float(grid.x0)) / float(grid.step)
	var fz := (z - float(grid.z0)) / float(grid.step)
	var nx: int = grid.nx
	var nz: int = grid.nz
	fx = clampf(fx, 0.0, nx - 1.001)
	fz = clampf(fz, 0.0, nz - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var h: Array = grid.h
	var a := lerpf(h[j * nx + i], h[j * nx + i + 1], tx)
	var b := lerpf(h[(j + 1) * nx + i], h[(j + 1) * nx + i + 1], tx)
	return lerpf(a, b, tz)


func street_y(x: float, z: float) -> float:
	var best := INF
	var y := 0.0
	var st: Array = data.street
	for k in st.size() - 1:
		var a := Vector2(st[k].p[0], st[k].p[1])
		var b := Vector2(st[k + 1].p[0], st[k + 1].p[1])
		var ab := b - a
		var t := clampf((Vector2(x, z) - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := Vector2(x, z).distance_to(a + ab * t)
		if d < best:
			best = d
			y = lerpf(st[k].y, st[k + 1].y, t)
	var w := clampf((best - 8.0) / 25.0, 0.0, 1.0)
	return lerpf(y, height(x, z), w)


func _mat(key: String, tex: Texture2D) -> void:
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter("tex", tex)
	mats[key] = m


func _st(key: String) -> SurfaceTool:
	if not tools.has(key):
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[key] = s
	return tools[key]


func _tri(key: String, p: Array, uv: Array, floor := true) -> void:
	var s := _st(key)
	var n: Vector3 = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
	if n.y < 0.0:
		n = -n
	for k in 3:
		s.set_normal(n)
		s.set_uv(uv[k])
		s.add_vertex(p[k])
	if floor:
		floor_faces.append_array(p)


func build(parent: Node3D, skip_near_paulista := 0.0) -> Node3D:
	root = Node3D.new()
	parent.add_child(root)
	_mat("asphalt", Tex.plate("res://assets/road/b_128.png"))
	_mat("walk", Tex.plate("res://assets/rioclaro/tex/sidewalk.png") if models.available() else Tex.mosaic(4))
	_mat("paving", Tex.plate("res://assets/props/concrete.png"))
	_mat("ground", Tex.plate("res://assets/rioclaro/tex/sidewalk.png") if models.available() else Tex.flat(Color(0.36, 0.34, 0.31), 16, 0.05, 0.4, 77))
	_mat("curb", Tex.flat(Color(0.62, 0.6, 0.58), 8, 0.03, 0.3, 6))
	var mroot: Node3D = null
	if use_models and models.available():
		mroot = models.build()
	_terrain(skip_near_paulista)
	_street()
	if not models.available():
		for c in data.cross:
			_cross(c)
	for k in tools:
		var mi := MeshInstance3D.new()
		mi.mesh = tools[k].commit()
		mi.material_override = mats[k]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var fb := StaticBody3D.new()
	fb.collision_layer = 2
	fb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.set_faces(floor_faces)
	sh.backface_collision = true
	cs.shape = sh
	fb.add_child(cs)
	root.add_child(fb)
	osm.set_glow(0.18)
	var keep := []
	for i in data.buildings.size():
		if not models.replaced.has(i):
			keep.append(data.buildings[i])
	root.add_child(osm.build_data({"buildings": keep}))
	if mroot:
		root.add_child(mroot)
		for p in models.lamps:
			var ol := OmniLight3D.new()
			ol.position = p - Vector3(0, 0.6, 0)
			ol.light_color = Color(1.0, 0.6, 0.28)
			ol.light_energy = 8.0
			ol.omni_range = 16.0
			root.add_child(ol)
			lamps.append(ol)
	_furniture()
	return root


func along(x: float, z: float) -> float:
	var best := INF
	var s := 0.0
	var acc := 0.0
	var st: Array = data.street
	for k in st.size() - 1:
		var a := Vector2(st[k].p[0], st[k].p[1])
		var b := Vector2(st[k + 1].p[0], st[k + 1].p[1])
		var ab := b - a
		var t := clampf((Vector2(x, z) - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := Vector2(x, z).distance_to(a + ab * t)
		if d < best:
			best = d
			s = acc + ab.length() * t
		acc += ab.length()
	return s


func _terrain(skip: float) -> void:
	var nx: int = grid.nx
	var nz: int = grid.nz
	var step: float = grid.step
	for j in nz - 1:
		for i in nx - 1:
			var x0: float = grid.x0 + i * step
			var z0: float = grid.z0 + j * step
			if x0 > -skip:
				continue
			var p := []
			for o in [Vector2(0, 0), Vector2(step, 0), Vector2(step, step), Vector2(0, step)]:
				var x: float = x0 + o.x
				var z: float = z0 + o.y
				p.append(Vector3(x, street_y(x, z) - 0.25, z))
			var uv := [Vector2(p[0].x, p[0].z) / 4.0, Vector2(p[1].x, p[1].z) / 4.0, Vector2(p[2].x, p[2].z) / 4.0, Vector2(p[3].x, p[3].z) / 4.0]
			_tri("ground", [p[0], p[1], p[2]], [uv[0], uv[1], uv[2]])
			_tri("ground", [p[0], p[2], p[3]], [uv[0], uv[2], uv[3]])


func _ribbon(key: String, pts: Array, w0: float, w1: float, lift: float, seg := 4.0, floor := true) -> void:
	var dense := []
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var n := maxi(1, int(a.distance_to(b) / seg))
		for i in n:
			dense.append(a.lerp(b, float(i) / n))
	dense.append(pts[pts.size() - 1])
	var v := 0.0
	for k in dense.size() - 1:
		var a: Vector3 = dense[k]
		var b: Vector3 = dense[k + 1]
		var d := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		var side := Vector3(-d.z, 0, d.x)
		var l := a.distance_to(b)
		var q := []
		for pnt in [a + side * w0, a + side * w1, b + side * w1, b + side * w0]:
			q.append(Vector3(pnt.x, street_y(pnt.x, pnt.z) + lift, pnt.z))
		var uv := [Vector2(w0 / 4.0, v), Vector2(w1 / 4.0, v), Vector2(w1 / 4.0, v + l / 4.0), Vector2(w0 / 4.0, v + l / 4.0)]
		_tri(key, [q[0], q[1], q[2]], [uv[0], uv[1], uv[2]], floor)
		_tri(key, [q[0], q[2], q[3]], [uv[0], uv[2], uv[3]], floor)
		v += l / 4.0


func _street() -> void:
	var st: Array = data.street
	var ped := []
	var road := []
	for k in st.size():
		var p := Vector3(st[k].p[0], st[k].y, st[k].p[1])
		if st[k].w > 10.0 or (k > 0 and st[k - 1].w > 10.0):
			ped.append(p)
		if st[k].w < 10.0 or (k + 1 < st.size() and st[k + 1].w < 10.0 and st[k].w > 10.0):
			road.append(p)
	start = ped[0]
	end = road[road.size() - 1]
	ped[0] = ped[0] + (ped[1] - ped[0]).normalized() * 16.0
	if not models.covers(60.0):
		_ribbon("paving", ped, -10.0, 10.0, 0.15)
	if models.covers(300.0):
		return
	_ribbon("asphalt", road, -3.0, 3.0, 0.02)
	_ribbon("walk", road, 3.0, 6.0, 0.17)
	_ribbon("walk", road, -6.0, -3.0, 0.17)
	_ribbon("curb", road, 3.0, 3.05, 0.17)


func _cross(c: Dictionary) -> void:
	var pts := []
	for q in c.pts:
		var p := Vector3(q.p[0], 0, q.p[1])
		if _near_street(p) < 70.0:
			pts.append(p)
	if pts.size() < 2:
		return
	var w: float = c.w * 0.5
	_ribbon("asphalt", pts, -w, w, 0.0)
	_ribbon("walk", pts, w, w + 2.5, 0.15)
	_ribbon("walk", pts, -w - 2.5, -w, 0.15)


func _near_street(p: Vector3) -> float:
	var best := INF
	var st: Array = data.street
	for k in st.size() - 1:
		var a := Vector2(st[k].p[0], st[k].p[1])
		var b := Vector2(st[k + 1].p[0], st[k + 1].p[1])
		var ab := b - a
		var t := clampf((Vector2(p.x, p.z) - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, Vector2(p.x, p.z).distance_to(a + ab * t))
	return best


func _place(n: Node3D) -> void:
	root.add_child(n)


func _furniture() -> void:
	var st: Array = data.street
	var dist := 0.0
	var next := 12.0
	var flip := 1.0
	for k in st.size() - 1:
		var a := Vector3(st[k].p[0], 0, st[k].p[1])
		var b := Vector3(st[k + 1].p[0], 0, st[k + 1].p[1])
		var l := a.distance_to(b)
		var d := (b - a).normalized()
		var side := Vector3(-d.z, 0, d.x)
		var w: float = 8.5 if st[k].w > 10.0 else 4.8
		while next < dist + l:
			if models.covers(next):
				flip = -flip
				next += 12.0
				continue
			var p := a + d * (next - dist) + side * w * flip
			p.y = street_y(p.x, p.z) + 0.15
			if int(next / 12.0) % 3 == 0:
				var lp := props.lamp()
				lp.position = p
				root.add_child(lp)
				var ol := OmniLight3D.new()
				ol.position = p + Vector3(0, 7.0, 0)
				ol.light_color = Color(1.0, 0.6, 0.28)
				ol.light_energy = 8.0
				ol.omni_range = 15.0
				root.add_child(ol)
				lamps.append(ol)
			else:
				root.add_child(props.tree(p, 0.75, int(next)))
			flip = -flip
			next += 12.0
		dist += l
	for poi in data.pois:
		var generic := {"pharmacy": "FARMACIA", "restaurant": "RESTAURANTE", "planetarium": "PLANETARIO"}
		var txt: String = generic.get(poi.kind, String(poi.name).to_upper())
		var p := Vector3(poi.p[0], 0, poi.p[1])
		p.y = street_y(p.x, p.z) + 3.4
		root.add_child(_label3d(txt, p))
	var sign := _street_sign()
	var d0 := (Vector3(st[1].p[0], 0, st[1].p[1]) - start).normalized()
	sign.position = start + d0 * 18.0 + Vector3(-d0.z, 0, d0.x) * 9.0
	sign.position.y = street_y(sign.position.x, sign.position.z) + 0.15
	sign.rotation.y = atan2(d0.x, d0.z)
	root.add_child(sign)


func _label3d(txt: String, p: Vector3) -> Node3D:
	var l := Label3D.new()
	l.text = txt
	l.position = p
	l.pixel_size = 0.03
	l.font_size = 32
	l.modulate = Color(1.0, 0.9, 0.6)
	l.outline_modulate = Color(0.1, 0.05, 0.02)
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return l


func _street_sign() -> Node3D:
	var n := Node3D.new()
	var pole := props.street_sign(Vector3.ZERO)
	n.add_child(pole)
	for c in pole.get_children():
		if c is MeshInstance3D and c.material_override and c.material_override.get_shader_parameter("tex") != null:
			var tex: Texture2D = c.material_override.get_shader_parameter("tex")
			if tex.get_width() > 64:
				var m := ShaderMaterial.new()
				m.shader = PS1
				m.set_shader_parameter("tex", Tex.plate("res://art/placa_rioclaro.png"))
				c.material_override = m
	return n
