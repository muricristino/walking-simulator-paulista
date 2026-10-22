extends RefCounted

var v := PackedVector3Array()
var n := PackedVector3Array()
var uv := PackedVector2Array()
var size := Vector2(64, 64)


func _init(tex_size := Vector2(64, 64)) -> void:
	size = tex_size


func _uv(r: Rect2, s: float, t: float) -> Vector2:
	var inset := 0.3
	var p := r.position + Vector2(inset + s * (r.size.x - inset * 2.0), inset + t * (r.size.y - inset * 2.0))
	return p / size


func tri(a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, out: Vector3) -> void:
	var nn := (b - a).cross(c - a).normalized()
	if nn.dot(out) < 0.0:
		nn = -nn
	for k in [[a, ua], [b, ub], [c, uc]]:
		v.append(k[0])
		n.append(nn)
		uv.append(k[1])


func quad(tl: Vector3, tr: Vector3, br: Vector3, bl: Vector3, r: Rect2, out: Vector3) -> void:
	var a := _uv(r, 0, 0)
	var b := _uv(r, 1, 0)
	var c := _uv(r, 1, 1)
	var d := _uv(r, 0, 1)
	tri(tl, tr, br, a, b, c, out)
	tri(tl, br, bl, a, c, d, out)


func cuboid(y0: float, y1: float, wb: float, db: float, wt: float, dt: float, regs: Dictionary, off := Vector3.ZERO) -> void:
	var xb := wb * 0.5
	var zb := db * 0.5
	var xt := wt * 0.5
	var zt := dt * 0.5
	var fallback: Rect2 = regs.get("f")
	var o := off
	quad(o + Vector3(xt, y1, -zt), o + Vector3(-xt, y1, -zt), o + Vector3(-xb, y0, -zb), o + Vector3(xb, y0, -zb), regs.get("f", fallback), Vector3.FORWARD)
	quad(o + Vector3(-xt, y1, zt), o + Vector3(xt, y1, zt), o + Vector3(xb, y0, zb), o + Vector3(-xb, y0, zb), regs.get("b", fallback), Vector3.BACK)
	quad(o + Vector3(xt, y1, -zt), o + Vector3(xt, y1, zt), o + Vector3(xb, y0, zb), o + Vector3(xb, y0, -zb), regs.get("s", fallback), Vector3.RIGHT)
	quad(o + Vector3(-xt, y1, -zt), o + Vector3(-xt, y1, zt), o + Vector3(-xb, y0, zb), o + Vector3(-xb, y0, -zb), regs.get("s", fallback), Vector3.LEFT)
	quad(o + Vector3(-xt, y1, -zt), o + Vector3(xt, y1, -zt), o + Vector3(xt, y1, zt), o + Vector3(-xt, y1, zt), regs.get("t", fallback), Vector3.UP)
	quad(o + Vector3(-xb, y0, -zb), o + Vector3(xb, y0, -zb), o + Vector3(xb, y0, zb), o + Vector3(-xb, y0, zb), regs.get("d", regs.get("t", fallback)), Vector3.DOWN)


func disc(center: Vector3, radius: float, sides: int, r: Rect2) -> void:
	var a := _uv(r, 0.5, 0.5)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := center + Vector3(cos(a0), 0, sin(a0)) * radius
		var p1 := center + Vector3(cos(a1), 0, sin(a1)) * radius
		tri(center, p0, p1, a, a, a, Vector3.UP)


func tri_count() -> int:
	return v.size() / 3


func mesh(m: Material) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, m)
	return am
