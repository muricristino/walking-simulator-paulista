extends RefCounted

var tools := {}
var mats := {}


func add_mat(key: String, m: Material) -> void:
	mats[key] = m


func _st(key: String) -> SurfaceTool:
	if not tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[key] = st
	return tools[key]


func _tri(st: SurfaceTool, p: Array, uv: Array, n: Vector3) -> void:
	var order := [0, 1, 2]
	if (p[1] - p[0]).cross(p[2] - p[0]).dot(n) > 0.0:
		order = [0, 2, 1]
	for i in order:
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(p[i])


func quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, unit := Vector2(4, 4), off := Vector2.ZERO, seg := 6.0) -> void:
	var st := _st(key)
	var wlen := maxf((b - a).length(), (c - d).length())
	var hlen := maxf((d - a).length(), (c - b).length())
	var nu := maxi(1, ceili(wlen / seg))
	var nv := maxi(1, ceili(hlen / seg))
	for j in nv:
		for i in nu:
			var pts := []
			var uvs := []
			for k in [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]:
				var s: float = k.x / nu
				var t: float = k.y / nv
				var bot := a.lerp(b, s)
				var top := d.lerp(c, s)
				pts.append(bot.lerp(top, t))
				var wl := lerpf((b - a).length(), (c - d).length(), t)
				var u := s * wl / unit.x + off.x
				var v := (1.0 - t) * hlen / unit.y + off.y
				uvs.append(Vector2(u, v))
			_tri(st, [pts[0], pts[1], pts[2]], [uvs[0], uvs[1], uvs[2]], n)
			_tri(st, [pts[0], pts[2], pts[3]], [uvs[0], uvs[2], uvs[3]], n)


func ground(key: String, x0: float, x1: float, z0: float, z1: float, y: float, unit := Vector2(4, 4), seg := 3.5) -> void:
	quad(key, Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector3.UP, unit, Vector2(x0 / unit.x, z0 / unit.y), seg)


func prism(key: String, bot: Array, top: Array, unit := Vector2(4, 4), off := Vector2.ZERO, seg := 8.0, caps := true, cap_key := "") -> void:
	var center := Vector3.ZERO
	for p in bot + top:
		center += p
	center /= 8.0
	var u := off.x
	for i in 4:
		var j := (i + 1) % 4
		var a: Vector3 = bot[i]
		var b: Vector3 = bot[j]
		var c: Vector3 = top[j]
		var d: Vector3 = top[i]
		var n := (b - a).cross(d - a).normalized()
		if n.dot((a + b + c + d) / 4.0 - center) < 0.0:
			n = -n
		quad(key, a, b, c, d, n, unit, Vector2(u, off.y), seg)
		u += (b - a).length() / unit.x
	if caps:
		var ck := cap_key if cap_key != "" else key
		quad(ck, top[0], top[1], top[2], top[3], Vector3.UP, unit, Vector2.ZERO, seg)
		quad(ck, bot[0], bot[1], bot[2], bot[3], Vector3.DOWN, unit, Vector2.ZERO, seg)


func box(key: String, center: Vector3, size: Vector3, unit := Vector2(4, 4), off := Vector2.ZERO, seg := 8.0, cap_key := "") -> void:
	var h := size * 0.5
	var bot := [
		center + Vector3(-h.x, -h.y, -h.z), center + Vector3(h.x, -h.y, -h.z),
		center + Vector3(h.x, -h.y, h.z), center + Vector3(-h.x, -h.y, h.z)]
	var top := []
	for p in bot:
		top.append(p + Vector3(0, size.y, 0))
	prism(key, bot, top, unit, off, seg, true, cap_key)


func frustum(key: String, base: Vector3, bsize: Vector2, tsize: Vector2, height: float, unit := Vector2(4, 4), cap_key := "") -> void:
	var bot := []
	var top := []
	for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		bot.append(base + Vector3(s.x * bsize.x * 0.5, 0, s.y * bsize.y * 0.5))
		top.append(base + Vector3(s.x * tsize.x * 0.5, height, s.y * tsize.y * 0.5))
	prism(key, bot, top, unit, Vector2.ZERO, 8.0, true, cap_key)


func build(parent: Node) -> void:
	for key in tools:
		var mi := MeshInstance3D.new()
		mi.mesh = tools[key].commit()
		mi.material_override = mats[key]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = key
		parent.add_child(mi)


func tools_append(key: String, mesh: Mesh, surface: int, xf: Transform3D) -> void:
	_st(key).append_from(mesh, surface, xf)
