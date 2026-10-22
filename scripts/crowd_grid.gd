extends RefCounted

const CELL := 0.5
const UNKNOWN := 0
const FREE := 1
const BLOCKED := 2
const ROAD := 3

var x0 := 0.0
var z0 := 0.0
var nx := 0
var nz := 0
var cells := PackedByteArray()
var queries := 0


func setup(xa: float, xb: float, za: float, zb: float) -> void:
	x0 = xa
	z0 = za
	nx = int(ceil((xb - xa) / CELL))
	nz = int(ceil((zb - za) / CELL))
	cells.resize(nx * nz)
	cells.fill(UNKNOWN)


func idx(x: float, z: float) -> int:
	var i := int(floor((x - x0) / CELL))
	var j := int(floor((z - z0) / CELL))
	if i < 0 or j < 0 or i >= nx or j >= nz:
		return -1
	return j * nx + i


func at(x: float, z: float) -> int:
	var k := idx(x, z)
	return UNKNOWN if k < 0 else cells[k]


func walkable(x: float, z: float, road_ok := false) -> bool:
	var v := at(x, z)
	return v == FREE or v == UNKNOWN or (road_ok and v == ROAD)


func clear(x: float, z: float, r: float, road_ok := false) -> bool:
	if not walkable(x, z, road_ok):
		return false
	var d := r * 0.7071
	for o in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r), Vector2(d, d), Vector2(-d, d), Vector2(d, -d), Vector2(-d, -d)]:
		if not walkable(x + o.x, z + o.y, road_ok):
			return false
	return true


func clear4(x: float, z: float, r: float, road_ok := false) -> bool:
	return walkable(x, z, road_ok) and walkable(x + r, z, road_ok) and walkable(x - r, z, road_ok) and walkable(x, z + r, road_ok) and walkable(x, z - r, road_ok)


func fill_rect(xa: float, xb: float, za: float, zb: float, v: int) -> void:
	for j in range(maxi(int(floor((za - z0) / CELL)), 0), mini(int(ceil((zb - z0) / CELL)), nz)):
		for i in range(maxi(int(floor((xa - x0) / CELL)), 0), mini(int(ceil((xb - x0) / CELL)), nx)):
			cells[j * nx + i] = v


func fill_soft(xa: float, xb: float, za: float, zb: float, v: int) -> void:
	for j in range(maxi(int(floor((za - z0) / CELL)), 0), mini(int(ceil((zb - z0) / CELL)), nz)):
		for i in range(maxi(int(floor((xa - x0) / CELL)), 0), mini(int(ceil((xb - x0) / CELL)), nx)):
			if cells[j * nx + i] != BLOCKED:
				cells[j * nx + i] = v


func stamp(x: float, z: float, r: float, v := BLOCKED) -> void:
	var ia := maxi(int(floor((x - r - x0) / CELL)), 0)
	var ib := mini(int(floor((x + r - x0) / CELL)), nx - 1)
	var ja := maxi(int(floor((z - r - z0) / CELL)), 0)
	var jb := mini(int(floor((z + r - z0) / CELL)), nz - 1)
	for j in range(ja, jb + 1):
		for i in range(ia, ib + 1):
			var cx := x0 + (i + 0.5) * CELL
			var cz := z0 + (j + 0.5) * CELL
			if Vector2(cx - x, cz - z).length() <= r + CELL * 0.5:
				cells[j * nx + i] = v


func scan(space: PhysicsDirectSpaceState3D, xa: float, xb: float, za: float, zb: float, y: float, exclude: Array, base := FREE) -> void:
	var q := PhysicsShapeQueryParameters3D.new()
	q.collision_mask = 1
	q.exclude = exclude
	var box := BoxShape3D.new()
	q.shape = box
	var bs := 4.0
	var x := xa
	while x < xb - 0.001:
		var z := za
		while z < zb - 0.001:
			_scan_block(space, q, box, x, z, minf(bs, xb - x), minf(bs, zb - z), y, base)
			z += bs
		x += bs


func _scan_block(space: PhysicsDirectSpaceState3D, q: PhysicsShapeQueryParameters3D, box: BoxShape3D, x: float, z: float, w: float, d: float, y: float, base: int) -> void:
	if w < 0.05 or d < 0.05:
		return
	box.size = Vector3(w - 0.02, 1.3, d - 0.02)
	q.transform = Transform3D(Basis(), Vector3(x + w * 0.5, y + 0.95, z + d * 0.5))
	queries += 1
	var hit := not space.intersect_shape(q, 1).is_empty()
	if not hit:
		fill_soft(x, x + w, z, z + d, base)
		return
	if w <= CELL + 0.001 and d <= CELL + 0.001:
		fill_rect(x, x + w, z, z + d, BLOCKED)
		return
	var hw := maxf(w * 0.5, CELL)
	var hd := maxf(d * 0.5, CELL)
	var xs := [x] if w <= CELL + 0.001 else [x, x + hw]
	var zs := [z] if d <= CELL + 0.001 else [z, z + hd]
	for sx in xs:
		for sz in zs:
			var ww := minf(hw, x + w - sx)
			var dd := minf(hd, z + d - sz)
			if ww > 0.01 and dd > 0.01:
				_scan_block(space, q, box, sx, sz, ww, dd, y, base)


func _open(k: int, keep: int) -> bool:
	if cells[k] != keep:
		return false
	var i := k % nx
	var j := k / nx
	if i == 0 or j == 0 or i == nx - 1 or j == nz - 1:
		return false
	return cells[k - 1] != BLOCKED and cells[k + 1] != BLOCKED and cells[k - nx] != BLOCKED and cells[k + nx] != BLOCKED


func flood(seeds: Array, keep: int) -> void:
	var seen := PackedByteArray()
	seen.resize(cells.size())
	var stack := PackedInt32Array()
	for s in seeds:
		var k := idx(s.x, s.y)
		if k >= 0 and seen[k] == 0 and _open(k, keep):
			seen[k] = 1
			stack.append(k)
	while not stack.is_empty():
		var k := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		for kk in [k + 1, k - 1, k + nx, k - nx]:
			if kk >= 0 and kk < cells.size() and seen[kk] == 0 and _open(kk, keep):
				seen[kk] = 1
				stack.append(kk)
	for k in cells.size():
		if cells[k] != keep or seen[k] == 1:
			continue
		var near := false
		for kk in [k + 1, k - 1, k + nx, k - nx]:
			if kk >= 0 and kk < cells.size() and seen[kk] == 1:
				near = true
				break
		if not near:
			cells[k] = BLOCKED
