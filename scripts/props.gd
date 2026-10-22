extends RefCounted

const PS1 := preload("res://scripts/ps1.gdshader")
const CUT := preload("res://scripts/ps1_cut.gdshader")
const DIR := "res://assets/props/"

var mats := {}
var scenes := {}
var rng := RandomNumberGenerator.new()


func mat(path: String, cut := false, emit := Color.BLACK) -> ShaderMaterial:
	var key := path + str(cut) + str(emit)
	if mats.has(key):
		return mats[key]
	var m := ShaderMaterial.new()
	m.shader = CUT if cut else PS1
	var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + path))
	m.set_shader_parameter("tex", ImageTexture.create_from_image(img))
	m.set_shader_parameter("emit", Vector3(emit.r, emit.g, emit.b))
	mats[key] = m
	return m


func _mi(st: SurfaceTool, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv0 := Vector2.ZERO, uv1 := Vector2.ONE) -> void:
	var n := (b - a).cross(d - a).normalized()
	var uvs := [Vector2(uv0.x, uv0.y), Vector2(uv1.x, uv0.y), Vector2(uv1.x, uv1.y), Vector2(uv0.x, uv1.y)]
	var p := [a, b, c, d]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_uv(uvs[i])
		st.add_vertex(p[i])


func _tube(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, sides: int, vrep: float) -> void:
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up).normalized()
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := side * cos(a0) + fwd * sin(a0)
		var d1 := side * cos(a1) + fwd * sin(a1)
		var u0 := float(i) / sides
		var u1 := float(i + 1) / sides
		var pts := [a + d0 * r0, a + d1 * r0, b + d1 * r1, b + d0 * r1]
		var nrm := [d0, d1, d1, d0]
		var uvs := [Vector2(u0, vrep), Vector2(u1, vrep), Vector2(u1, 0), Vector2(u0, 0)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(nrm[k])
			st.set_uv(uvs[k])
			st.add_vertex(pts[k])


func tree(pos: Vector3, s: float, seed: int) -> Node3D:
	rng.seed = seed
	var root := Node3D.new()
	root.position = pos
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(rng.randf_range(-0.2, 0.2), 2.8 * s, rng.randf_range(-0.2, 0.2))
	_tube(st, Vector3.ZERO, top, 0.22 * s, 0.17 * s, 6, 3.0)
	var crown := Vector3(top.x, 5.0 * s, top.z)
	for k in 4:
		var a := TAU * k / 4.0 + rng.randf_range(-0.4, 0.4)
		var tip := crown + Vector3(cos(a) * 2.0 * s, rng.randf_range(-0.3, 0.6) * s, sin(a) * 2.0 * s)
		_tube(st, top, tip, 0.13 * s, 0.05 * s, 5, 2.0)
	root.add_child(_mi(st, mat("bark.png")))
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 44:
		var r := sqrt(rng.randf()) * 3.0 * s
		var a := rng.randf() * TAU
		var c := crown + Vector3(cos(a) * r, rng.randf_range(-0.5, 1.1) * s - r * r * 0.06, sin(a) * r)
		var size := rng.randf_range(2.0, 3.0) * s
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5) + (PI * 0.5 if k % 4 == 0 else 0.0))
		var ex := basis.x * size * 0.5
		var ez := basis.z * size * 0.5
		_quad(st, c - ex - ez, c + ex - ez, c + ex + ez, c - ex + ez)
	root.add_child(_mi(st, mat("canopy.png", true)))
	return root


func _scene(path: String, tex: String, size: float, axis := 1) -> Node3D:
	if not scenes.has(path):
		scenes[path] = load(DIR + path)
	var inst: Node3D = scenes[path].instantiate()
	var m := mat(tex)
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for si in mi.mesh.get_surface_count():
			mi.set_surface_override_material(si, m)
	var root := Node3D.new()
	root.add_child(inst)
	var box := _bounds(inst)
	var k := size / maxf(box.size[axis], 0.001)
	inst.scale *= k
	box = _bounds(inst)
	inst.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	return root


func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var p: Node = mi
		var chain := Transform3D.IDENTITY
		while p != n:
			if p is Node3D:
				chain = (p as Node3D).transform * chain
			p = p.get_parent()
		var b: AABB = n.transform * chain * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func lamp() -> Node3D:
	return _scene("loafbrr/LampPost_1.fbx", "loafbrr/streetlight.png", 7.5)


func bench() -> Node3D:
	return _scene("loafbrr/Bench.fbx", "loafbrr/bench.png", 1.8, 0)


func trash() -> Node3D:
	return _scene("loafbrr/TrashCan.fbx", "loafbrr/trash_orange.png", 0.95)


func street_sign(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube(st, Vector3.ZERO, Vector3(0, 3.7, 0), 0.05, 0.05, 6, 4.0)
	root.add_child(_mi(st, mat("concrete.png")))
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zz in [0.04, -0.04]:
		var x0 := -1.3 if zz > 0 else 1.3
		var x1 := -x0
		_quad(st, Vector3(x0, 3.6, zz), Vector3(x1, 3.6, zz), Vector3(x1, 2.9, zz), Vector3(x0, 2.9, zz))
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter("tex", ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://art/placa.png"))))
	var mi := _mi(st, m)
	root.add_child(mi)
	return root


func shopfront(pos: Vector3, width: float, upper := true, seed_off := 0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var h := 4.2
	var bays := int(width / 6.0)
	var x0 := -bays * 3.0
	var wall := SurfaceTool.new()
	wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := SurfaceTool.new()
	up.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shut := SurfaceTool.new()
	shut.begin(Mesh.PRIMITIVE_TRIANGLES)
	var win := SurfaceTool.new()
	win.begin(Mesh.PRIMITIVE_TRIANGLES)
	var signs := []
	for i in bays:
		var bx := x0 + i * 6.0
		var kind := (i + seed_off) % 3
		_quad(wall, Vector3(bx, h, 0), Vector3(bx + 0.5, h, 0), Vector3(bx + 0.5, 0, 0), Vector3(bx, 0, 0), Vector2(0, 0), Vector2(0.25, 2.0))
		_quad(wall, Vector3(bx + 5.5, h, 0), Vector3(bx + 6.0, h, 0), Vector3(bx + 6.0, 0, 0), Vector3(bx + 5.5, 0, 0), Vector2(0, 0), Vector2(0.25, 2.0))
		_quad(wall, Vector3(bx + 0.5, h, 0), Vector3(bx + 5.5, h, 0), Vector3(bx + 5.5, 3.2, 0), Vector3(bx + 0.5, 3.2, 0), Vector2(0, 0), Vector2(2.5, 0.5))
		for side in [0.5, 5.5]:
			_quad(wall, Vector3(bx + side, 3.2, 0), Vector3(bx + side, 3.2, -0.3), Vector3(bx + side, 0, -0.3), Vector3(bx + side, 0, 0), Vector2(0, 0), Vector2(0.15, 1.6))
		_quad(wall, Vector3(bx + 0.5, 3.2, -0.3), Vector3(bx + 5.5, 3.2, -0.3), Vector3(bx + 5.5, 3.2, 0), Vector3(bx + 0.5, 3.2, 0), Vector2(0, 0), Vector2(2.5, 0.15))
		var face := [Vector3(bx + 0.5, 3.2, -0.3), Vector3(bx + 5.5, 3.2, -0.3), Vector3(bx + 5.5, 0, -0.3), Vector3(bx + 0.5, 0, -0.3)]
		if kind == 0:
			_quad(shut, face[0], face[1], face[2], face[3], Vector2(0, 0), Vector2(2.0, 1.3))
		else:
			_quad(win, face[0], face[1], Vector3(bx + 5.5, 0.5, -0.3), Vector3(bx + 0.5, 0.5, -0.3), Vector2(0, 0), Vector2(1.0, 1.0))
			_quad(wall, Vector3(bx + 0.5, 0.5, -0.3), Vector3(bx + 5.5, 0.5, -0.3), face[2], face[3], Vector2(0, 0), Vector2(2.5, 0.2))
		signs.append([bx, i])
	if upper:
		_quad(up, Vector3(x0, 20.0, 0), Vector3(-x0, 20.0, 0), Vector3(-x0, h, 0), Vector3(x0, h, 0), Vector2(0, 0), Vector2(width / 8.0, (20.0 - h) / 8.0))
	root.add_child(_mi(wall, mat("concrete.png")))
	if upper:
		root.add_child(_mi(up, mat("facade_upper.png")))
	root.add_child(_mi(shut, mat("shutter.png")))
	root.add_child(_mi(win, mat("window.png", false, Color(0.12, 0.1, 0.06))))
	for s in signs:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var bx: float = s[0]
		_quad(st, Vector3(bx + 0.9, 4.05, 0.12), Vector3(bx + 5.1, 4.05, 0.12), Vector3(bx + 5.1, 3.3, 0.12), Vector3(bx + 0.9, 3.3, 0.12))
		root.add_child(_mi(st, mat("sign%d.png" % ((s[1] + seed_off) % 4), false, Color(0.08, 0.07, 0.05))))
	return root
