extends Node

signal car_spawned(node: Node3D)
signal car_recycled(node: Node3D)
signal honk(node: Node3D)

const Cars := preload("res://scripts/cars.gd")
const Lights := preload("res://scripts/traffic_light.gd")
const Layout := preload("res://scripts/layout.gd")
const RNG_STATE := -3323828461859993348
const CAR_LANES := [3.75, 7.25, 10.75]
const BUS_LANE := 14.25
const Z_LO := -1080.0
const Z_HI := 380.0
const PARK_GAP := 130.0
const HIDE_FAR := 440.0
const HIDE_NEAR := 300.0
const NEAR_PLACE := 200.0
const FAR_SIM := 460.0
const VIS_RANGE := 460.0
const ROAD_X := 16.3
const ACC := 1.8
const DEC := 3.0
const S0 := 2.0
const HEADWAY := 1.2
const MIN_GAP := 1.0
const PERSON_GAP := 0.45
const BUS_STOPS_DEFAULT := [Vector3(14.25, 0, -80.0), Vector3(14.25, 0, -262.0), Vector3(14.25, 0, -470.0), Vector3(-14.25, 0, -470.0), Vector3(-14.25, 0, -255.0), Vector3(-14.25, 0, -100.0)]


class Mover:
	var node: Node3D
	var kind := ""
	var d := 1
	var x := 0.0
	var s := 0.0
	var v := 0.0
	var v0 := 11.0
	var half := 2.25
	var half_w := 0.9
	var bus := false
	var wait := 0.0
	var served := {}
	var blocked := 0.0
	var honked := false

	var z: float:
		get:
			return s * d


var city: Node
var rng := RandomNumberGenerator.new()
var lights := Lights.new()
var movers := []
var parked := []
var lanes := []
var _obstacles := []
var bus_stops := {-1: [], 1: []}
var frame := 0
var cam_z := 0.0


func build(c: Node) -> void:
	city = c
	rng.state = RNG_STATE
	lights.build(c)
	_bus_stops()
	for d in [-1, 1]:
		for lx in CAR_LANES:
			_fill_lane(d * -lx, d, false)
		_fill_lane(d * -BUS_LANE, d, true)
	scan_parked()
	scan_parked.call_deferred()
	_hook_player.call_deferred()


func _bus_stops() -> void:
	var stops: Array = (Layout as Script).get_script_constant_map().get("BUS_STOPS", BUS_STOPS_DEFAULT)
	for p in stops:
		var d := -1 if p.x > 0 else 1
		bus_stops[d].append(float(p.z))
	for d in bus_stops:
		bus_stops[d].sort_custom(func(a: float, b: float) -> bool: return a * d < b * d)


func _s_start(d: int) -> float:
	return (Z_LO if d > 0 else Z_HI) * d


func _s_end(d: int) -> float:
	return (Z_HI if d > 0 else Z_LO) * d


func _fill_lane(x: float, d: int, bus: bool) -> void:
	var lane := {"x": x, "d": d, "bus": bus, "cars": []}
	lanes.append(lane)
	var s := _s_end(d) - rng.randf_range(5.0, 30.0)
	var stop := _s_start(d)
	while s > stop:
		var m := _spawn(x, d, bus)
		m.s = s
		m.v = minf(m.v0 * rng.randf_range(0.6, 1.0), _start_speed(m))
		lane.cars.append(m)
		_place(m)
		s -= m.half * 2.0 + (rng.randf_range(90.0, 200.0) if bus else rng.randf_range(12.0, 42.0))
		while not bus and _in_zone(s * d, 4.0) and s > stop:
			s -= 4.0


func _start_speed(m: Mover) -> float:
	for e in lights.list:
		var dist := _stop_s(e, m.d) - m.s - m.half
		if dist > -0.5 and dist < 90.0 and lights.car_state_of(e) != Lights.GREEN:
			return sqrt(2.0 * DEC * maxf(dist - 1.0, 0.0))
	return INF


func _spawn(x: float, d: int, bus: bool) -> Mover:
	var m := Mover.new()
	m.d = d
	m.x = x
	m.bus = bus
	var model := Cars.make_bus(-1, rng) if bus else Cars.make_car("", -1, rng)
	var size: Vector3 = model.get_meta("size")
	m.kind = model.get_meta("kind")
	m.half = size.z * 0.5
	m.half_w = size.x * 0.5
	m.v0 = rng.randf_range(8.5, 10.5) if bus else rng.randf_range(10.0, 13.5)
	var body := AnimatableBody3D.new()
	body.name = "Bus" if bus else "Car"
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = false
	body.add_to_group("vehicle")
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(size.x + 0.05, size.y * 0.9, size.z + 0.05)
	cs.shape = b
	cs.position = Vector3(0, size.y * 0.45 + 0.05, 0)
	body.add_child(cs)
	body.add_child(model)
	var mi := model.get_node("Body") as GeometryInstance3D
	mi.visibility_range_end = VIS_RANGE
	body.rotation.y = 0.0 if d < 0 else PI
	body.set_meta("mover", m)
	m.node = body
	city.world.add_child(body)
	movers.append(m)
	car_spawned.emit(body)
	return m


func _place(m: Mover) -> void:
	m.node.position = Vector3(m.x, 0.0, m.s * m.d)


func make_car(kind := "", variant := -1) -> Node3D:
	return Cars.make_car(kind, variant, rng)


func park(xf: Transform3D, kind := "", variant := -1) -> StaticBody3D:
	var model := Cars.make_car(kind, variant, rng)
	var size: Vector3 = model.get_meta("size")
	var body := StaticBody3D.new()
	body.name = "Parked"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("vehicle")
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(size.x, size.y * 0.9, size.z)
	cs.shape = b
	cs.position = Vector3(0, size.y * 0.45, 0)
	body.add_child(cs)
	body.add_child(model)
	(model.get_node("Body") as GeometryInstance3D).visibility_range_end = VIS_RANGE
	body.transform = xf
	city.world.add_child(body)
	parked.append(body)
	return body


func scan_parked() -> void:
	if not is_inside_tree():
		return
	var spots := get_tree().get_nodes_in_group("parked_spot")
	if spots.is_empty():
		return
	var rio = city.get("rio") if city else null
	var models = rio.get("models") if rio else null
	if models and models.has_method("clear_placeholders"):
		models.clear_placeholders()
	for n in spots:
		if not (n is Node3D) or n.has_meta("parked_car"):
			continue
		var spot := n as Node3D
		if not bool(spot.get_meta("occupied", true)) or str(spot.get_meta("kind", "car")) == "moto":
			continue
		var kind := ""
		var want := float(spot.get_meta("len", 0.0))
		if want > 0.0 and want < 4.2:
			kind = "hatch"
		var body := park(Transform3D(spot.global_transform.basis.orthonormalized(), spot.global_transform.origin), kind, -1)
		spot.set_meta("parked_car", body)


func park_points(points: Array) -> void:
	for p in points:
		if p is Transform3D:
			park(p)
		elif p is Array and p.size() >= 4:
			park(Transform3D(Basis(Vector3.UP, float(p[3])), Vector3(float(p[0]), float(p[1]), float(p[2]))))


func crossings() -> Array:
	var out := []
	for e in lights.list:
		out.append({"z": e.z, "half": e.half, "z0": e.walk0, "z1": e.walk1, "x0": -ROAD_X, "x1": ROAD_X, "zlo": e.zlo, "zhi": e.zhi, "stop_neg_z": float(e.zhi) + 0.8, "stop_pos_z": float(e.zlo) - 0.8})
	return out


func ped_green(cross_z: float) -> bool:
	var e := lights.find(cross_z)
	return not e.is_empty() and lights.walk_of(e)


func is_walk_open(z: float) -> bool:
	return ped_green(z)


func ped_time_left(cross_z: float) -> float:
	var e := lights.find(cross_z)
	return 0.0 if e.is_empty() else lights.walk_left_of(e)


func car_light(cross_z: float) -> int:
	var e := lights.find(cross_z)
	return Lights.GREEN if e.is_empty() else lights.car_state_of(e)


func is_red(z: float, _dir := 0) -> bool:
	return car_light(z) != Lights.GREEN


func _hook_player() -> void:
	var p = city.player if city else null
	if p and p.has_signal("bumped") and not p.is_connected("bumped", _on_bumped):
		p.connect("bumped", _on_bumped)


func _on_bumped(body: Node, _speed: float) -> void:
	if body and body.has_meta("mover"):
		var m: Mover = body.get_meta("mover")
		if not m.honked:
			m.honked = true
			honk.emit(m.node)


func _cam() -> Camera3D:
	return city.player.cam if city and city.player else null


func _hidden(p: Vector3, cam: Camera3D) -> bool:
	if not cam:
		return true
	var d := p.distance_to(cam.global_position)
	if d > HIDE_FAR:
		return true
	if d < HIDE_NEAR:
		return false
	return not cam.is_position_in_frustum(p + Vector3(0, 1, 0))


func _gather() -> void:
	_obstacles.clear()
	if city.player:
		var p: Vector3 = city.player.global_position
		if absf(p.x) < ROAD_X + 0.5 and p.y < 3.0:
			_obstacles.append([p, true])
	for n in get_tree().get_nodes_in_group("pedestrian"):
		if n is Node3D:
			var q: Vector3 = (n as Node3D).global_position
			if absf(q.x) < ROAD_X + 0.5:
				_obstacles.append([q, false])


func _idm(v: float, v0: float, gap: float, dv: float) -> float:
	var ss := S0 + maxf(0.0, v * HEADWAY + v * dv / (2.0 * sqrt(ACC * DEC)))
	var g := maxf(gap, 0.05)
	return ACC * (1.0 - pow(v / v0, 4.0) - (ss / g) * (ss / g))


func _physics_process(dt: float) -> void:
	if not city:
		return
	lights.update(dt)
	_gather()
	var cam := _cam()
	frame += 1
	cam_z = cam.global_position.z if cam else 0.0
	for lane in lanes:
		_step_lane(lane, dt, cam)


func _step_lane(lane: Dictionary, dt: float, cam: Camera3D) -> void:
	var cars: Array = lane.cars
	var d: int = lane.d
	var lx: float = lane.x
	var obs := []
	for o in _obstacles:
		var p: Vector3 = o[0]
		if absf(p.x - lx) < 2.4:
			obs.append([p.z * d, absf(p.x - lx), o[1]])
	var s_end := _s_end(d)
	for i in cars.size():
		var m: Mover = cars[i]
		var far := absf(m.s * d - cam_z) > FAR_SIM
		if far and (frame + i) % 4 != 0:
			continue
		var h := dt * 4.0 if far else dt
		var lead: Mover = cars[i - 1] if i > 0 else null
		var front := m.s + m.half
		var a := ACC * (1.0 - pow(m.v / m.v0, 4.0))
		var limit := INF
		if lead:
			var gap := lead.s - lead.half - front
			a = minf(a, _idm(m.v, m.v0, gap, m.v - lead.v))
			limit = lead.s - lead.half - MIN_GAP - m.half
		else:
			var park_s := s_end + PARK_GAP
			a = minf(a, _idm(m.v, m.v0, park_s - front + S0, m.v))
		var person := INF
		var touching := false
		for o in obs:
			if o[1] > m.half_w + 0.55:
				continue
			var os: float = o[0]
			if os < m.s - m.half - 0.3:
				continue
			if os < front + PERSON_GAP:
				touching = true
			person = minf(person, os)
		if person < INF:
			var pg := person - PERSON_GAP - front
			a = minf(a, _idm(m.v, m.v0, pg, m.v))
			limit = minf(limit, person - PERSON_GAP - 0.3 - m.half)
		a = minf(a, _signal_acc(m, lead, front))
		if m.bus:
			a = minf(a, _bus_acc(m, front, h))
		if touching:
			m.v = 0.0
			a = 0.0
		m.v = clampf(m.v + maxf(a, -9.0) * h, 0.0, m.v0)
		var ns := m.s + m.v * h
		if ns > limit:
			ns = maxf(m.s, limit)
			m.v = minf(m.v, maxf(0.0, (ns - m.s) / h))
		m.s = ns
		if person < INF and person - front < 12.0 and m.v < 0.3:
			m.blocked += h
			if m.blocked > 1.5 and not m.honked:
				m.honked = true
				honk.emit(m.node)
		else:
			m.blocked = 0.0
			m.honked = false
		if absf(m.s * d - cam_z) < NEAR_PLACE or (frame + i) % 4 == 0:
			_place(m)
	_recycle(lane, cam)


func _stop_s(e: Dictionary, d: int) -> float:
	return float(e.zlo) - 0.8 if d > 0 else -(float(e.zhi) + 0.8)


func _exit_s(e: Dictionary, d: int) -> float:
	return float(e.zhi) if d > 0 else -float(e.zlo)


func _in_zone(z: float, pad: float) -> bool:
	for e in lights.list:
		if z > float(e.zlo) - pad and z < float(e.zhi) + pad:
			return true
	return false


func _signal_acc(m: Mover, lead: Mover, front: float) -> float:
	var best := INF
	for e in lights.list:
		var stop_s := _stop_s(e, m.d)
		var dist := stop_s - front
		if dist < -0.5 or dist > 90.0:
			continue
		var st := lights.car_state_of(e)
		var must := false
		if st == Lights.RED:
			must = dist > m.v * m.v / (2.0 * 7.0) - 0.5 or m.v < 1.0
		elif st == Lights.AMBER:
			must = dist > m.v * m.v / (2.0 * DEC)
		if not must and lead and lead.v < 2.0:
			var exit_s := _exit_s(e, m.d)
			var room := lead.s - lead.half - exit_s
			if lead.s - lead.half > stop_s and room < m.half * 2.0 + 2.5:
				must = true
		if must:
			best = minf(best, _idm(m.v, m.v0, dist + S0 - 0.8, m.v))
		break
	return best


func _bus_acc(m: Mover, front: float, dt: float) -> float:
	if m.wait > 0.0:
		m.wait -= dt
		if m.wait <= 0.0:
			m.wait = 0.0
		return -INF
	for zs in bus_stops[m.d]:
		var ss: float = zs * m.d
		if m.served.has(ss):
			continue
		var dist := ss - m.s
		if dist < -2.0:
			continue
		if dist > 80.0:
			break
		if dist < 1.0 and m.v < 0.4:
			m.served[ss] = true
			m.wait = rng.randf_range(6.0, 11.0)
			return -INF
		return _idm(m.v, m.v0, dist + S0, m.v)
	return INF


func _recycle(lane: Dictionary, cam: Camera3D) -> void:
	var cars: Array = lane.cars
	if cars.is_empty():
		return
	var m: Mover = cars[0]
	if m.s < _s_end(m.d) or not _hidden(m.node.position, cam):
		return
	var last: Mover = cars[cars.size() - 1]
	var start := minf(_s_start(m.d), last.s - last.half - m.half - (rng.randf_range(90.0, 200.0) if m.bus else rng.randf_range(14.0, 40.0)))
	var p := Vector3(m.x, 0.0, start * m.d)
	if not _hidden(p, cam):
		return
	cars.pop_front()
	m.s = start
	m.v = m.v0 * 0.8
	m.served.clear()
	m.wait = 0.0
	cars.append(m)
	_place(m)
	car_recycled.emit(m.node)
