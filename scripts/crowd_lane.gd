extends RefCounted

var name := ""
var kind := "sidewalk"
var width := 2.0
var pts := PackedVector3Array()
var cum := PackedFloat32Array()
var length := 0.0
var links := []
var light := false
var light_z := 0.0
var enabled := true


func _init(p := PackedVector3Array(), w := 2.0, k := "sidewalk", n := "") -> void:
	pts = p
	width = w
	kind = k
	name = n
	cum.resize(p.size())
	var acc := 0.0
	for i in p.size():
		if i > 0:
			acc += Vector2(p[i].x - p[i - 1].x, p[i].z - p[i - 1].z).length()
		cum[i] = acc
	length = acc


func seg_at(s: float) -> int:
	var lo := 0
	var hi := pts.size() - 2
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if cum[mid] <= s:
			lo = mid
		else:
			hi = mid - 1
	return clampi(lo, 0, maxi(pts.size() - 2, 0))


func tangent(i: int) -> Vector2:
	var a := pts[i]
	var b := pts[i + 1]
	return Vector2(b.x - a.x, b.z - a.z).normalized()


func point(s: float, t := 0.0) -> Vector3:
	s = clampf(s, 0.0, length)
	var i := seg_at(s)
	var a := pts[i]
	var b := pts[i + 1]
	var sl := maxf(cum[i + 1] - cum[i], 0.0001)
	var p := a.lerp(b, (s - cum[i]) / sl)
	var tg := tangent(i)
	return p + Vector3(-tg.y, 0.0, tg.x) * t


func project(x: float, z: float, hint := -1) -> Vector3:
	var lo := 0
	var hi := pts.size() - 2
	if hint >= 0:
		lo = maxi(hint - 2, 0)
		hi = mini(hint + 2, pts.size() - 2)
	var best := INF
	var out := Vector3.ZERO
	for i in range(lo, hi + 1):
		var a := Vector2(pts[i].x, pts[i].z)
		var b := Vector2(pts[i + 1].x, pts[i + 1].z)
		var ab := b - a
		var q := Vector2(x, z)
		var u := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var c := a + ab * u
		var d := q.distance_squared_to(c)
		if d < best:
			best = d
			var tg := ab.normalized()
			out = Vector3(cum[i] + ab.length() * u, (q - c).dot(Vector2(-tg.y, tg.x)), i)
	return out
