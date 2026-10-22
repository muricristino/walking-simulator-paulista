extends Node

const Katcho := preload("res://scripts/katcho.gd")
const Layout := preload("res://scripts/layout.gd")
const Grid := preload("res://scripts/crowd_grid.gd")
const Lane := preload("res://scripts/crowd_lane.gd")
const RNG_STATE := -7827248741660285753
const WALK_X := 23.0
const WALK_W := 13.0
const Z_FRONT := 52.0
const Z_BACK := -470.0
const RADIUS := 0.33
const GAP := 0.7
const GAP_PLAYER := 0.8
const NEAR := 70.0
const CLOSE := 25.0
const SHOW := 160.0
const STATIC_ANIM := 35.0
const PAULISTA_WALKERS := 80
const RIO_WALKERS := 18
const BAG := {"office_f": 18, "office_m": 16, "henry": 15, "johndoe": 15, "mob01": 14, "gramps": 8, "granny": 7, "nanzy": 5}
const HEIGHT := {"office_f": Vector2(1.58, 1.72), "nanzy": Vector2(1.55, 1.66), "granny": Vector2(1.5, 1.62), "gramps": Vector2(1.62, 1.74)}
const SPEED := {"granny": Vector2(0.75, 0.9), "gramps": Vector2(0.85, 1.0)}
const CYCLE := 50.0
const GREEN := Vector2(29.0, 44.0)

var city: Node
var rng := RandomNumberGenerator.new()
var katcho := Katcho.new()
var grid := Grid.new()
var lanes := []
var walk_lanes := []
var rio_lanes := []
var walkers := []
var statics := []
var placed := []
var bins := {}
var bags := {}
var vehicles := []
var veh_t := 0.0
var lod_t := 0.0
var clock := 0.0
var built := false
var rio_source := ""
var build_ms := 0
var tick_us := 0
var frame := 0
var tints := [Color(1, 1, 1), Color(0.92, 0.92, 0.95), Color(1.05, 1.0, 0.95), Color(0.88, 0.9, 0.86)]


func build(c: Node) -> void:
	city = c
	rng.state = RNG_STATE


func _exit_tree() -> void:
	for l in lanes:
		l.links.clear()
	for w in walkers:
		w.clear()
	lanes.clear()
	walk_lanes.clear()
	rio_lanes.clear()
	walkers.clear()
	bins.clear()


func _physics_process(dt: float) -> void:
	if not city or not city.world:
		return
	if not built:
		_setup()
		return
	clock += dt
	var t0 := Time.get_ticks_usec()
	var player: Node3D = city.player
	var pp: Vector3 = player.global_position if player else Vector3(1e6, 0, 1e6)
	_rehash()
	veh_t -= dt
	if veh_t <= 0.0:
		veh_t = 0.5
		_vehicles(0.5)
	frame += 1
	for i in walkers.size():
		var w: Dictionary = walkers[i]
		var every: int = 1 if w.close else (2 if w.near else (5 if w.shown else 12))
		if (frame + i) % every == 0:
			_update(w, dt * every, pp)
	lod_t -= dt
	if lod_t <= 0.0:
		lod_t = 0.4
		for st in statics:
			var d2: float = (st.pos as Vector3).distance_squared_to(pp)
			var ap: AnimationPlayer = st.ap
			if ap:
				ap.active = d2 < STATIC_ANIM * STATIC_ANIM
			(st.node as Node3D).visible = d2 < SHOW * SHOW
	tick_us = Time.get_ticks_usec() - t0


func _setup() -> void:
	built = true
	var t0 := Time.get_ticks_msec()
	_grid()
	_paulista_lanes()
	_rio_lanes()
	_link()
	_place_statics()
	_place_walkers()
	build_ms = Time.get_ticks_msec() - t0
	print("crowd: %d walkers, %d statics, %d lanes (rio: %s), grid queries %d, %d ms" % [walkers.size(), statics.size(), lanes.size(), rio_source, grid.queries, build_ms])


func crossings() -> Array:
	var tr: Object = city.traffic
	if tr and tr.has_method("crossings"):
		var out := []
		for e in tr.crossings():
			if e is float or e is int:
				out.append(float(e))
			elif e is Dictionary and e.has("z"):
				out.append(float(e.z))
			elif e is Vector3:
				out.append(e.z)
			elif e is Vector2:
				out.append(e.y)
		if not out.is_empty():
			return out
	return [-48.0] + Layout.CROSS


func green(z: float) -> bool:
	var tr: Object = city.traffic
	if tr and tr.has_method("ped_green"):
		return tr.ped_green(z)
	var ph := fmod(clock, CYCLE)
	return ph >= GREEN.x and ph < GREEN.y


func green_left(z: float) -> float:
	var tr: Object = city.traffic
	if tr and tr.has_method("ped_time_left"):
		return float(tr.ped_time_left(z))
	if tr and tr.has_method("ped_green"):
		return 99.0 if tr.ped_green(z) else 0.0
	var ph := fmod(clock, CYCLE)
	return GREEN.y - ph if ph >= GREEN.x and ph < GREEN.y else 0.0


func _grid() -> void:
	grid.setup(-600.0, 32.0, Z_BACK - 22.0, Z_FRONT + 8.0)
	var space: PhysicsDirectSpaceState3D = city.world.get_world_3d().direct_space_state
	var ex := []
	for n in _vehicle_nodes():
		if n is CollisionObject3D:
			ex.append((n as CollisionObject3D).get_rid())
	for sx in [-1.0, 1.0]:
		var xa: float = 16.25 if sx > 0 else -29.75
		grid.scan(space, xa, xa + 13.5, Z_BACK - 20.0, Z_FRONT + 6.0, 0.15, ex)
	grid.fill_rect(-16.25, 16.25, Z_BACK - 20.0, Z_FRONT + 6.0, Grid.BLOCKED)
	for cz in crossings():
		grid.fill_rect(-16.25, 16.25, cz - 3.0, cz + 3.0, Grid.UNKNOWN)
		grid.scan(space, -16.0, 16.0, cz - 3.0, cz + 3.0, 0.0, ex, Grid.ROAD)
	var m: Vector2 = Layout.MASP_Z
	grid.scan(space, -58.0, -31.0, m.x + 1.0, m.y - 1.0, 0.16, ex)
	var seeds := []
	var z := Z_FRONT
	while z > Z_BACK - 18.0:
		for x in [-17.8, 17.8]:
			seeds.append(Vector2(x, z))
		z -= 3.0
	for x in range(-56, -32, 4):
		for zz in range(int(m.x) + 4, int(m.y) - 2, 4):
			seeds.append(Vector2(x, zz))
	grid.flood(seeds, Grid.FREE)


func _paulista_lanes() -> void:
	for sx in [-1.0, 1.0]:
		var l := Lane.new(PackedVector3Array([Vector3(sx * WALK_X, 0.15, Z_FRONT), Vector3(sx * WALK_X, 0.15, Z_BACK)]), WALK_W, "sidewalk", "paulista_%s" % ("L" if sx < 0 else "R"))
		lanes.append(l)
		walk_lanes.append(l)
	for cz in crossings():
		if cz < Z_BACK + 5.0 or cz > Z_FRONT - 5.0:
			continue
		var l := Lane.new(PackedVector3Array([Vector3(17.4, 0.15, cz), Vector3(-17.4, 0.15, cz)]), 5.0, "crossing", "zebra_%d" % int(cz))
		l.light = true
		l.light_z = cz
		var s := 0.0
		while s <= l.length:
			var ok := false
			for k in 9:
				var p := l.point(s, -2.0 + k * 0.5)
				if grid.clear(p.x, p.z, RADIUS, true):
					ok = true
					break
			if not ok:
				l.enabled = false
				break
			s += 0.5
		if not l.enabled:
			print("crowd: crossing z=%.0f blocked by an obstacle, disabled" % cz)
		lanes.append(l)


func _rio_lanes() -> void:
	var found := []
	for n in get_tree().get_nodes_in_group("rc_walk"):
		if n is Path3D and (n as Path3D).curve:
			var cv: Curve3D = (n as Path3D).curve
			var pts := PackedVector3Array()
			var xf := (n as Path3D).global_transform
			for i in cv.point_count:
				pts.append(xf * cv.get_point_position(i))
			if pts.size() >= 2:
				found.append(Lane.new(pts, float(n.get_meta("width", 1.5)), String(n.get_meta("kind", "sidewalk")), String(n.name)))
	if not found.is_empty():
		rio_source = "group rc_walk"
	elif FileAccess.file_exists("res://assets/rioclaro/rc_walk.json"):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/rioclaro/rc_walk.json"))
		if d is Dictionary:
			for p in d.get("paths", []):
				var pts := PackedVector3Array()
				for q in p.pts:
					pts.append(Vector3(q[0], q[1], q[2]))
				if pts.size() >= 2:
					found.append(Lane.new(pts, float(p.get("width", 1.5)), String(p.get("kind", "sidewalk")), String(p.get("name", ""))))
		if not found.is_empty():
			rio_source = "rc_walk.json"
	if found.is_empty():
		found = _rio_fallback()
		rio_source = "fallback from rioclaro.json"
	var space: PhysicsDirectSpaceState3D = city.world.get_world_3d().direct_space_state
	var ex := []
	for n in _vehicle_nodes():
		if n is CollisionObject3D:
			ex.append((n as CollisionObject3D).get_rid())
	for l in found:
		lanes.append(l)
		if l.kind != "crossing":
			rio_lanes.append(l)
		var pad: float = l.width * 0.5 + 2.0
		for i in l.pts.size() - 1:
			var a: Vector3 = l.pts[i]
			var b: Vector3 = l.pts[i + 1]
			grid.scan(space, minf(a.x, b.x) - pad, maxf(a.x, b.x) + pad, minf(a.z, b.z) - pad, maxf(a.z, b.z) + pad, minf(a.y, b.y), ex)


func _rio_fallback() -> Array:
	var rio: Object = city.rio
	if not rio:
		return []
	var st: Array = rio.data.street
	var ped := PackedVector3Array()
	var road := PackedVector3Array()
	for k in st.size():
		var p := Vector3(st[k].p[0], st[k].y, st[k].p[1])
		if p.x > -24.0:
			continue
		if st[k].w > 10.0:
			ped.append(p)
		else:
			if road.is_empty() and ped.size() > 0:
				road.append(ped[ped.size() - 1])
			road.append(p)
	var out := []
	if ped.size() >= 2:
		var base := Lane.new(ped)
		out.append(_offset(base, 2.5, 3.0, "plaza", "calcadao_a"))
		out.append(_offset(base, -4.0, 2.0, "plaza", "calcadao_b"))
	if road.size() >= 2:
		var base := Lane.new(road)
		out.append(_offset(base, 5.0, 2.2, "sidewalk", "rua_right"))
		out.append(_offset(base, -5.0, 2.2, "sidewalk", "rua_left"))
	return out


func _offset(base: RefCounted, t: float, w: float, kind: String, n: String) -> RefCounted:
	var pts := PackedVector3Array()
	for i in base.pts.size():
		var s: float = base.cum[i]
		pts.append(base.point(clampf(s, 0.01, base.length - 0.01), t))
	return Lane.new(pts, w, kind, n)


func _link() -> void:
	for a in lanes:
		for end_s in [0.0, a.length]:
			var e: Vector3 = a.point(end_s)
			for b in lanes:
				if b == a:
					continue
				var pr: Vector3 = b.project(e.x, e.z)
				var q: Vector3 = b.point(pr.x)
				if Vector2(q.x - e.x, q.z - e.z).length() > 6.5:
					continue
				if _has_link(a, end_s, b):
					continue
				a.links.append({"s": end_s, "to": b, "s2": pr.x})
				b.links.append({"s": pr.x, "to": a, "s2": end_s})


func _has_link(a: RefCounted, s: float, b: RefCounted) -> bool:
	for l in a.links:
		if l.to == b and absf(l.s - s) < 1.0:
			return true
	return false


func _pick_model(key: String) -> String:
	if not bags.has(key):
		bags[key] = []
	var bag: Array = bags[key]
	if bag.is_empty():
		for k in BAG:
			for i in BAG[k]:
				bag.append(k)
		for i in range(bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: String = bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
	return bag.pop_back()


func civilian(model := "", key := "static") -> Dictionary:
	if model == "":
		model = _pick_model(key)
	var hr: Vector2 = HEIGHT.get(model, Vector2(1.66, 1.84))
	var h := rng.randf_range(hr.x, hr.y)
	var n := katcho.texs(model).size()
	var c := katcho.make(model, rng.randi() % maxi(n, 1), h, tints[rng.randi() % tints.size()])
	var sh := MeshInstance3D.new()
	sh.mesh = katcho.shadow()
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(c.root as Node3D).add_child(sh)
	c.height = h
	return c


func _floor(x: float, z: float, y := 0.15) -> float:
	var space: PhysicsDirectSpaceState3D = city.world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, y + 1.6, z), Vector3(x, y - 4.0, z), 2)
	var r := space.intersect_ray(q)
	return r.position.y if r else y


func _free_spot(p: Vector3, r: float) -> bool:
	if not grid.clear(p.x, p.z, r):
		return false
	for q in placed:
		if Vector2(p.x - q.x, p.z - q.z).length_squared() < 1.0:
			return false
	var sp: Vector3 = Layout.SPAWN_FEET
	if Vector2(p.x - sp.x, p.z - sp.z).length() < 3.5:
		return false
	var space: PhysicsDirectSpaceState3D = city.world.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = r + 0.1
	cy.height = 1.2
	q.shape = cy
	q.collision_mask = 1
	q.transform = Transform3D(Basis(), p + Vector3(0, 1.0, 0))
	return space.intersect_shape(q, 1).is_empty()


func person(p: Vector3, yaw: float, kind := "idle", model := "") -> bool:
	if not _free_spot(p, 0.4):
		return false
	p.y = _floor(p.x, p.z, p.y)
	var c := civilian(model)
	var r: Node3D = c.root
	r.position = p
	r.rotation.y = yaw
	r.add_to_group("pedestrian")
	city.world.add_child(r)
	var anim := kind if c.anims.has(kind) else "idle"
	if anim == "phone":
		katcho.phone(c)
	katcho.play(c, anim, rng.randf() * 4.0, rng.randf_range(0.85, 1.1))
	placed.append(p)
	statics.append({"ap": c.ap, "pos": p, "node": r, "c": c, "kind": anim})
	city.solid(p + Vector3(0, 0.875 * c.height / 1.75, 0), Vector3(0.5, c.height, 0.32))
	grid.stamp(p.x, p.z, 0.45)
	return true


func _group(center: Vector3, n: int) -> void:
	var a0 := rng.randf() * TAU
	var r := 0.5 if n == 2 else 0.62
	var pts := []
	for i in n:
		var a := a0 + TAU * i / n
		pts.append(center + Vector3(cos(a) * r, 0, sin(a) * r))
	for p in pts:
		if not _free_spot(p, 0.4):
			return
	for p in pts:
		var d: Vector3 = center - p
		person(p, atan2(d.x, d.z) + rng.randf_range(-0.25, 0.25), "idle")


func _place_statics() -> void:
	var n0 := statics.size()
	var tries := 0
	while statics.size() - n0 < 80 and tries < 600:
		tries += 1
		var sx := -1.0 if rng.randf() < 0.5 else 1.0
		var z := rng.randf_range(-300.0, 45.0) if rng.randf() < 0.75 else rng.randf_range(Z_BACK + 10.0, -300.0)
		var roll := rng.randf()
		if roll < 0.32:
			person(Vector3(sx * rng.randf_range(19.5, 28.5), 0.15, z), rng.randf() * TAU, "phone")
		elif roll < 0.62:
			_group(Vector3(sx * rng.randf_range(20.0, 27.5), 0.15, z), 2 if rng.randf() < 0.65 else 3)
		elif roll < 0.8:
			person(Vector3(sx * rng.randf_range(28.6, 29.2), 0.15, z), atan2(-sx, 0.0) + rng.randf_range(-0.4, 0.4), "phone" if rng.randf() < 0.5 else "idle")
		elif not _near_crossing(z, 6.0):
			person(Vector3(sx * rng.randf_range(17.6, 18.2), 0.15, z), atan2(-sx, 0.0) + rng.randf_range(-0.5, 0.5), "idle")
	var n1 := statics.size()
	var m: Vector2 = Layout.MASP_Z
	tries = 0
	while statics.size() - n1 < 30 and tries < 300:
		tries += 1
		var p := Vector3(rng.randf_range(-55.0, -34.0), 0.16, rng.randf_range(m.x + 4.0, m.y - 4.0))
		if rng.randf() < 0.5:
			_group(p, 2 if rng.randf() < 0.6 else 3)
		else:
			person(p, rng.randf() * TAU, "phone" if rng.randf() < 0.6 else "idle")
	for k in 2:
		person(Vector3(-32.6, 0.16, rng.randf_range(m.x + 6.0, m.y - 6.0)), PI * 0.5 + rng.randf_range(-0.3, 0.3), "idle", "beggar")
	var n2 := statics.size()
	for k in 3:
		person(Vector3(23.6, 0.15, -34.2 - k * 1.4), PI * 0.5 + rng.randf_range(-0.3, 0.3), "idle")
	var n3 := statics.size()
	tries = 0
	while statics.size() - n3 < 20 and tries < 200 and not rio_lanes.is_empty():
		tries += 1
		var l: RefCounted = rio_lanes[rng.randi() % rio_lanes.size()]
		var s := rng.randf_range(2.0, l.length - 2.0)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var t: float = side * (l.width * 0.5 + rng.randf_range(0.7, 1.6))
		var p: Vector3 = l.point(s, t)
		var c: Vector3 = l.point(s)
		var d := c - p
		if rng.randf() < 0.4:
			_group(p, 2)
		else:
			person(p, atan2(d.x, d.z) + rng.randf_range(-0.8, 0.8), "phone" if rng.randf() < 0.6 else "idle")
	print("crowd: statics sidewalk %d, masp %d, banca %d, rio %d" % [n1 - n0, n2 - n1, n3 - n2, statics.size() - n3])


func _near_crossing(z: float, r: float) -> bool:
	for cz in crossings():
		if absf(z - cz) < r:
			return true
	return false


func _place_walkers() -> void:
	var tries := 0
	var made := 0
	while made < PAULISTA_WALKERS and tries < 2000:
		tries += 1
		var l: RefCounted = walk_lanes[made % walk_lanes.size()]
		var s := rng.randf_range(0.0, l.length)
		if _spawn(l, s):
			made += 1
	made = 0
	tries = 0
	while made < RIO_WALKERS and tries < 1000 and not rio_lanes.is_empty():
		tries += 1
		var l: RefCounted = rio_lanes[rng.randi() % rio_lanes.size()]
		if _spawn(l, rng.randf_range(0.0, l.length)):
			made += 1


func _spawn(l: RefCounted, s: float) -> bool:
	var dir := -1.0 if rng.randf() < 0.5 else 1.0
	var half: float = maxf(l.width * 0.5 - 0.5, 0.0)
	var tp: float = clampf(dir * rng.randf_range(0.3, 4.5), -half, half) if l.width > 4.0 else rng.randf_range(-half, half)
	var p: Vector3 = l.point(s, tp)
	if not grid.clear(p.x, p.z, 0.35):
		return false
	var sp: Vector3 = Layout.SPAWN_FEET
	if Vector2(p.x - sp.x, p.z - sp.z).length() < 3.5:
		return false
	for q in placed:
		if Vector2(p.x - q.x, p.z - q.z).length_squared() < 1.0:
			return false
	for w in walkers:
		if (w.pos as Vector2).distance_squared_to(Vector2(p.x, p.z)) < 1.0:
			return false
	walker(l, s, dir, tp, p)
	return true


func walker(l: RefCounted, s: float, dir: float, tp: float, p: Vector3) -> Dictionary:
	var c := civilian("", "walker")
	var hs: float = c.height / 1.72
	var body := AnimatableBody3D.new()
	body.collision_layer = 1 | 8
	body.collision_mask = 0
	body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.5, 1.75 * hs, 0.34)
	cs.shape = b
	cs.position = Vector3(0, 0.875 * hs, 0)
	body.add_child(cs)
	var r: Node3D = c.root
	r.rotation.y = PI
	body.add_child(r)
	body.add_to_group("pedestrian")
	var tg: Vector2 = l.tangent(l.seg_at(s)) * dir
	var h := atan2(-tg.x, -tg.y)
	p.y = _floor(p.x, p.z, p.y)
	body.position = p
	body.rotation.y = h
	city.world.add_child(body)
	var sr: Vector2 = SPEED.get(c.model, Vector2(1.15, 1.5))
	var v0 := rng.randf_range(sr.x, sr.y)
	katcho.play(c, true, rng.randf() * 2.0)
	var w := {
		"node": body, "c": c, "lane": l, "s": s, "seg": l.seg_at(s), "dir": dir, "tp": tp,
		"speed": v0, "v": v0 * 0.5, "h": h, "want_h": h, "want_v": v0, "walking": true,
		"pos": Vector2(p.x, p.z), "vel": Vector2.ZERO, "y": p.y, "yt": rng.randf() * 0.3,
		"st": rng.randf() * 0.15, "state": "walk", "timer": rng.randf_range(8.0, 30.0),
		"stuck": 0.0, "cool": 0.0, "near": true, "close": true, "shown": true, "prog_t": 0.0, "prog_s": s, "fails": 0, "anim": "walk", "spot": Vector3.ZERO, "face": 0.0, "delay": 0.0,
	}
	walkers.append(w)
	return w


func _rehash() -> void:
	bins.clear()
	for w in walkers:
		var p: Vector2 = w.pos
		var k := Vector2i(floori(p.x * 0.5), floori(p.y * 0.5))
		if bins.has(k):
			bins[k].append(w)
		else:
			bins[k] = [w]


func _neighbors(p: Vector2) -> Array:
	var out := []
	var k := Vector2i(floori(p.x * 0.5), floori(p.y * 0.5))
	for i in range(-1, 2):
		for j in range(-1, 2):
			var kk := Vector2i(k.x + i, k.y + j)
			if bins.has(kk):
				out.append_array(bins[kk])
	return out


func _vehicle_nodes() -> Array:
	var out := []
	for m in city.movers:
		if m is Dictionary and m.has("node"):
			out.append(m.node)
		elif m is Node3D:
			out.append(m)
	for g in ["car", "vehicle", "bus"]:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node3D and not out.has(n):
				out.append(n)
	return out


func _vehicles(dt: float) -> void:
	var old := {}
	for v in vehicles:
		old[v.node] = v
	vehicles.clear()
	for n in _vehicle_nodes():
		if not is_instance_valid(n):
			continue
		var p := Vector2((n as Node3D).global_position.x, (n as Node3D).global_position.z)
		var e: Dictionary = old.get(n, {})
		var half := Vector2(1.05, 2.4)
		if e.is_empty():
			for c in (n as Node).get_children():
				if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
					var sz: Vector3 = ((c as CollisionShape3D).shape as BoxShape3D).size
					half = Vector2(sz.x, sz.z) * 0.5
					break
		else:
			half = e.half
		var vel: Vector2 = (p - e.p) / dt if not e.is_empty() else Vector2.ZERO
		var bs := (n as Node3D).global_transform.basis
		vehicles.append({"node": n, "p": p, "vel": vel, "half": half, "fx": Vector2(bs.x.x, bs.x.z).normalized(), "fz": Vector2(bs.z.x, bs.z.z).normalized()})


func _signals() -> bool:
	var tr: Object = city.traffic
	return tr != null and tr.has_method("ped_green")


func _corridor_clear(l: RefCounted, horizon: float) -> bool:
	for v in vehicles:
		var tau := 0.0
		while tau <= horizon:
			var c: Vector2 = v.p + (v.vel as Vector2) * tau
			var pr: Vector3 = l.project(c.x, c.y)
			if pr.x > 0.5 and pr.x < l.length - 0.5 and absf(pr.y) < l.width * 0.5 + v.half.y + 0.6:
				return false
			if (v.vel as Vector2).length_squared() < 0.01:
				break
			tau += 0.4
	return true


func _in_vehicle(q: Vector2, ahead: float, pad: float) -> bool:
	for v in vehicles:
		var c: Vector2 = v.p + (v.vel as Vector2) * ahead
		var d := q - c
		if absf(d.dot(v.fx)) < v.half.x + pad and absf(d.dot(v.fz)) < v.half.y + pad:
			return true
	return false


func _update(w: Dictionary, dt: float, pp: Vector3) -> void:
	var p: Vector2 = w.pos
	var d2 := Vector2(pp.x - p.x, pp.z - p.y).length_squared()
	var near := d2 < NEAR * NEAR
	w.close = d2 < CLOSE * CLOSE
	w.st -= dt
	w.cool = maxf(float(w.cool) - dt, 0.0)
	if w.st <= 0.0:
		w.st = (0.15 if w.close else 0.25) if near else 1.0
		_think(w, pp, w.st)
	_move(w, dt, pp)
	var n: Node3D = w.node
	var c: Dictionary = w.c
	var ap: AnimationPlayer = c.ap
	if near != w.near:
		w.near = near
		if ap:
			ap.active = near
	w.shown = d2 < SHOW * SHOW
	n.visible = w.shown
	var moving: bool = w.v > 0.12
	var want: String = "walk" if moving else ("phone" if w.state == "pause" and c.anims.has("phone") else "idle")
	if want != w.anim:
		w.anim = want
		if want == "phone" and not c.has("phone"):
			katcho.phone(c)
		katcho.play(c, want)
		if c.has("phone"):
			(c.phone as Node3D).visible = want == "phone"
	if ap and moving:
		ap.speed_scale = clampf(w.v / float(c.stride), 0.45, 1.5)
	elif ap:
		ap.speed_scale = 1.0
	w.yt -= dt
	if w.yt <= 0.0:
		w.yt = 0.25 if near else 1.0
		w.ty = _floor(p.x, p.y, w.y)
	w.y = lerpf(w.y, w.get("ty", w.y), 1.0 - exp(-10.0 * dt))
	n.position = Vector3(p.x, w.y, p.y)
	n.rotation.y = w.h


func _think(w: Dictionary, pp: Vector3, step: float) -> void:
	var l: RefCounted = w.lane
	var p: Vector2 = w.pos
	var pr: Vector3 = l.project(p.x, p.y, w.seg)
	w.seg = int(pr.z)
	var prev: float = w.s
	w.s = pr.x
	var v0: float = w.speed
	var target := Vector3.ZERO
	var road: bool = l.kind == "crossing"
	match w.state:
		"walk":
			w.prog_t += step
			if w.prog_t > 3.0:
				if absf(w.s - float(w.prog_s)) < 0.8 and l.kind != "crossing":
					var half: float = maxf(l.width * 0.5 - 0.5, 0.0)
					w.tp = rng.randf_range(-half, half)
					w.fails += 1
					if w.fails >= 3:
						w.fails = 0
						w.dir = -w.dir
				else:
					w.fails = 0
				w.prog_t = 0.0
				w.prog_s = w.s
			w.timer -= step
			if w.timer <= 0.0 and l.kind != "crossing":
				w.timer = rng.randf_range(15.0, 40.0)
				if rng.randf() < 0.3:
					w.state = "pause"
					w.delay = rng.randf_range(3.0, 8.0)
					w.want_v = 0.0
					return
			if l.kind != "crossing" and w.cool <= 0.0 and _links(w, prev):
				return
			var end: float = l.length if w.dir > 0 else 0.0
			if absf(w.s - end) < 1.2:
				if l.kind == "crossing":
					_leave_crossing(w)
					return
				w.dir = -w.dir
				w.tp = -w.tp
			target = l.point(w.s + w.dir * 3.0, w.tp)
		"pause":
			w.delay -= step
			w.want_v = 0.0
			if w.delay <= 0.0:
				w.state = "walk"
			return
		"to_wait":
			target = w.spot
			var dd := Vector2(target.x - p.x, target.z - p.y).length()
			if dd < 0.45 or (dd < 2.5 and w.stuck > 1.5):
				w.state = "wait"
				w.delay = rng.randf_range(0.2, 1.4)
				w.want_v = 0.0
				return
			v0 = minf(v0, maxf(dd * 1.2, 0.3))
		"wait":
			w.want_v = 0.0
			w.want_h = w.face
			if not l.enabled:
				_leave_crossing(w)
				return
			w.timer -= step
			if w.timer < -45.0:
				w.timer = rng.randf_range(15.0, 40.0)
				_leave_crossing(w)
				return
			var go: bool = not l.light or (green(l.light_z) and green_left(l.light_z) > 8.0)
			if go and _corridor_clear(l, l.length / maxf(float(w.speed), 0.5) + 2.0 if not _signals() else 3.0):
				w.delay -= step
				if w.delay <= 0.0:
					w.state = "walk"
					w.timer = rng.randf_range(15.0, 40.0)
			return
	if road and w.state == "walk":
		v0 *= 1.3
	var dv := Vector2(target.x - p.x, target.z - p.y)
	if dv.length() < 0.05:
		w.want_v = 0.0
		return
	_steer(w, dv.normalized(), v0, pp, road)


func _links(w: Dictionary, prev: float) -> bool:
	var l: RefCounted = w.lane
	var s: float = w.s
	for k in l.links:
		var ls: float = k.s
		var passed: bool = (ls - prev) * w.dir >= -0.01 and (ls - s) * w.dir <= 0.0
		if not passed:
			continue
		var at_end: bool = ls < 0.5 or ls > l.length - 0.5
		var to: RefCounted = k.to
		if to.kind == "crossing":
			if not to.enabled or rng.randf() > 0.4:
				continue
			_enter_crossing(w, to, k.s2)
			return true
		if not at_end and rng.randf() > 0.3:
			continue
		if at_end and rng.randf() < 0.25:
			continue
		_switch(w, to, k.s2)
		return true
	return false


func _switch(w: Dictionary, to: RefCounted, s2: float) -> void:
	w.lane = to
	w.s = s2
	w.seg = to.seg_at(s2)
	if s2 < 1.0:
		w.dir = 1.0
	elif s2 > to.length - 1.0:
		w.dir = -1.0
	else:
		w.dir = -1.0 if rng.randf() < 0.5 else 1.0
	var half: float = maxf(to.width * 0.5 - 0.5, 0.0)
	w.tp = clampf(w.dir * rng.randf_range(0.3, 4.5), -half, half) if to.width > 4.0 else rng.randf_range(-half, half)
	w.state = "walk"
	w.cool = 8.0


func _enter_crossing(w: Dictionary, to: RefCounted, s2: float) -> void:
	w.lane = to
	w.dir = 1.0 if s2 < to.length * 0.5 else -1.0
	w.s = 0.0 if w.dir > 0 else to.length
	w.seg = to.seg_at(w.s)
	var half: float = maxf(to.width * 0.5 - 0.4, 0.0)
	w.tp = rng.randf_range(-half, half)
	w.spot = to.point(w.s + w.dir * 0.2, w.tp)
	var tg: Vector2 = to.tangent(w.seg) * w.dir
	w.face = atan2(-tg.x, -tg.y)
	w.state = "to_wait"
	w.stuck = 0.0
	w.timer = 0.0


func _leave_crossing(w: Dictionary) -> void:
	var l: RefCounted = w.lane
	var end: float = l.length if w.dir > 0 else 0.0
	if w.state == "wait":
		end = l.length - end
	for k in l.links:
		if absf(k.s - end) < 1.0 and k.to.kind != "crossing":
			_switch(w, k.to, k.s2)
			return
	w.state = "walk"
	w.dir = -w.dir


func _steer(w: Dictionary, des: Vector2, v0: float, pp: Vector3, road: bool) -> void:
	var p: Vector2 = w.pos
	var l: RefCounted = w.lane
	var half: float = l.width * 0.5 - 0.25
	var nb := _neighbors(p)
	var others := []
	for o in nb:
		if o != w and (o.pos as Vector2).distance_squared_to(p) < 9.0:
			others.append(o)
	var ppl := Vector2(pp.x, pp.z)
	var has_player := ppl.distance_squared_to(p) < 9.0 and absf(pp.y - w.y) < 2.0
	var base := atan2(des.x, des.y)
	var best := 8.0
	var best_a := base
	var best_v := 0.0
	if road:
		best = 6.0
		for tau in [0.0, 0.6, 1.2, 1.8]:
			if _in_vehicle(p, tau, 0.6):
				best += 12.0
				break
	var offs := [0.0, 0.35, -0.35, 0.7, -0.7, 1.1, -1.1, 1.6, -1.6, 2.3, -2.3]
	if not road and _straight_ok(w, p, des, v0, others, has_player, ppl, half):
		w.want_h = atan2(-des.x, -des.y)
		w.want_v = v0
		return
	if road:
		offs.append(PI)
	for off in offs:
		for f in [1.0, 0.5]:
			var a: float = base + off
			var dir := Vector2(sin(a), cos(a))
			var sp: float = v0 * f
			var cost: float = absf(off) * 1.2 + (1.0 - f) * 1.5 + absf(wrapf(atan2(-dir.x, -dir.y) - float(w.want_h), -PI, PI)) * 0.5
			var k := 0
			for tau in ([0.35, 0.8, 1.4, 2.0] if road else [0.35, 0.8, 1.4]):
				var q: Vector2 = p + dir * sp * tau
				if not grid.clear(q.x, q.y, RADIUS, road):
					cost += 9.0 / (k + 1)
					break
				if w.state != "to_wait":
					var lp: Vector3 = l.project(q.x, q.y, w.seg)
					if absf(lp.y) > half:
						cost += 2.5 / (k + 1)
				if road and _in_vehicle(q, tau, 0.6):
					cost += 12.0
					break
				k += 1
			var vel: Vector2 = dir * sp
			for o in others:
				cost += _threat(p, vel, o.pos, o.vel, GAP + 0.05)
			if has_player:
				cost += _threat(p, vel, ppl, Vector2.ZERO, GAP_PLAYER + 0.05)
			if cost < best:
				best = cost
				best_a = a
				best_v = sp
	w.want_h = atan2(-sin(best_a), -cos(best_a))
	w.want_v = best_v


func _straight_ok(w: Dictionary, p: Vector2, des: Vector2, v0: float, others: Array, has_player: bool, ppl: Vector2, half: float) -> bool:
	var l: RefCounted = w.lane
	for tau in [0.35, 0.8, 1.4, 2.0]:
		var q: Vector2 = p + des * v0 * tau
		if not grid.clear(q.x, q.y, RADIUS + 0.1):
			return false
		if w.state != "to_wait" and absf((l.project(q.x, q.y, w.seg) as Vector3).y) > half:
			return false
	var vel := des * v0
	for o in others:
		if _threat(p, vel, o.pos, o.vel, GAP + 0.35) > 0.0:
			return false
	if has_player and _threat(p, vel, ppl, Vector2.ZERO, GAP_PLAYER + 0.4) > 0.0:
		return false
	return true


func _threat(p: Vector2, v: Vector2, q: Vector2, vq: Vector2, r: float) -> float:
	var d0 := q - p
	var dv := vq - v
	var tc := 0.0
	var dd := dv.length_squared()
	if dd > 0.0001:
		tc = clampf(-d0.dot(dv) / dd, 0.0, 1.6)
	var dm := (d0 + dv * tc).length()
	if dm >= r:
		return 0.0
	return (r - dm) * 9.0 * (1.8 - tc)


func _move(w: Dictionary, dt: float, pp: Vector3) -> void:
	var diff := wrapf(float(w.want_h) - float(w.h), -PI, PI)
	var rate := 3.2 if w.v > 0.3 else 4.5
	w.h = wrapf(float(w.h) + clampf(diff, -rate * dt, rate * dt), -PI, PI)
	var fac := clampf(1.0 - absf(diff) / 1.4, 0.0, 1.0)
	w.v = move_toward(w.v, float(w.want_v) * fac, 2.2 * dt)
	var p: Vector2 = w.pos
	if w.v < 0.01:
		w.vel = Vector2.ZERO
		return
	var fw := Vector2(-sin(w.h), -cos(w.h))
	var road: bool = (w.lane as RefCounted).kind == "crossing" and w.state != "to_wait"
	for a in [0.0, 0.5, -0.5, 1.0, -1.0]:
		var dir := fw.rotated(a) if a != 0.0 else fw
		var sp: float = w.v * (1.0 if a == 0.0 else 0.6)
		var np: Vector2 = p + dir * sp * dt
		if _ok(w, p, np, pp, road):
			w.pos = np
			w.vel = dir * sp
			w.stuck = maxf(float(w.stuck) - dt, 0.0)
			return
	w.vel = Vector2.ZERO
	w.v = 0.0
	w.stuck = float(w.stuck) + dt
	if w.stuck > 6.0 and w.state == "walk":
		w.stuck = 0.0
		w.dir = -w.dir
		w.tp = -w.tp


func _ok(w: Dictionary, p: Vector2, np: Vector2, pp: Vector3, road: bool) -> bool:
	if grid.clear4(p.x, p.y, 0.25, true) and not grid.clear4(np.x, np.y, 0.25, road):
		return false
	var kx := floori(np.x * 0.5)
	var kz := floori(np.y * 0.5)
	for i in range(-1, 2):
		for j in range(-1, 2):
			var arr: Variant = bins.get(Vector2i(kx + i, kz + j))
			if arr == null:
				continue
			for o in arr:
				if o == w:
					continue
				var q: Vector2 = o.pos
				var dn := np.distance_squared_to(q)
				if dn < GAP * GAP and dn < p.distance_squared_to(q):
					return false
	var ppl := Vector2(pp.x, pp.z)
	var dp := np.distance_squared_to(ppl)
	if dp < GAP_PLAYER * GAP_PLAYER and dp < p.distance_squared_to(ppl) and absf(pp.y - w.y) < 2.0:
		return false
	if road and _in_vehicle(np, 0.0, 0.35):
		return false
	return true
