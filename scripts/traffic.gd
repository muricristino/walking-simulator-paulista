extends Node

const Geo := preload("res://scripts/geo.gd")
const Tex := preload("res://scripts/tex.gd")
const Layout := preload("res://scripts/layout.gd")
const RNG_STATE := -3323828461859993348
const LANES := [3.75, 7.25, 10.75]
const CAR_COLORS := [Color(0.85, 0.85, 0.83), Color(0.6, 0.62, 0.64), Color(0.1, 0.1, 0.11), Color(0.6, 0.08, 0.07), Color(0.12, 0.18, 0.35), Color(0.35, 0.36, 0.38), Color(0.9, 0.9, 0.88)]

var city: Node
var geo: Geo
var rng := RandomNumberGenerator.new()
var movers := []


func build(c: Node) -> void:
	city = c
	geo = c.geo
	rng.state = RNG_STATE
	for lx in LANES:
		var z := rng.randf_range(-22, -40)
		var v := -rng.randf_range(8.0, 11.5)
		z = 50.0
		while z > -420.0:
			moving_car(lx, z, v)
			z -= rng.randf_range(18, 42)
		z = rng.randf_range(-62, -70)
		while z > -520.0:
			if not Layout.in_cross(z - 3, z + 3):
				car(-lx, z, true)
			z -= rng.randf_range(7, 22)
	bus(14.25, -46.0, false)
	bus(14.25, -120.0, false)
	bus(-14.25, -66.0, true)
	bus(-14.25, -200.0, true)


func car(x: float, z: float, toward: bool, g: Geo = null) -> void:
	var M: Dictionary = city.M
	var gg := g if g else geo
	var key := "car%d" % (rng.randi() % CAR_COLORS.size())
	if not M.has(key):
		M[key] = city.mat(Tex.flat(CAR_COLORS[int(key.substr(3))], 8, 0.03, 0.2, 40), Color.WHITE)
		geo.add_mat(key, M[key])
		gg.add_mat(key, M[key])
	var f := 1.0 if toward else -1.0
	gg.box(key, Vector3(x, 0.72, z), Vector3(1.8, 0.75, 4.3), Vector2(2, 1))
	if not g:
		city.solid(Vector3(x, 0.85, z), Vector3(1.9, 1.7, 4.4))
	gg.box(key, Vector3(x, 1.38, z - f * 0.2), Vector3(1.6, 0.56, 2.2), Vector2(2, 1))
	gg.box("dark", Vector3(x, 1.38, z - f * 0.2 + f * 1.11), Vector3(1.5, 0.48, 0.02), Vector2(1, 1))
	gg.box("dark", Vector3(x, 1.38, z - f * 0.2 - f * 1.11), Vector3(1.5, 0.48, 0.02), Vector2(1, 1))
	gg.box("dark", Vector3(x, 0.32, z), Vector3(1.86, 0.5, 3.2), Vector2(1, 1))
	var front := z + f * 2.16
	var back := z - f * 2.16
	for side in [-0.65, 0.65]:
		gg.box("head", Vector3(x + side, 0.85, front), Vector3(0.35, 0.16, 0.04), Vector2(1, 1))
		gg.box("tail", Vector3(x + side, 0.9, back), Vector3(0.35, 0.14, 0.04), Vector2(1, 1))


func bus(x: float, z: float, toward: bool) -> void:
	var M: Dictionary = city.M
	if not M.has("bus"):
		M.bus = city.mat(Tex.stripes(Color(0.88, 0.88, 0.86), Color(0.15, 0.35, 0.6), 2, 8, 6, 41))
		geo.add_mat("bus", M.bus)
		M.bus_win = city.mat(Tex.flat(Color(0.15, 0.17, 0.2), 8, 0.02, 0.2, 42), Color.WHITE, null, 0.0, Color(0.35, 0.33, 0.25))
		geo.add_mat("bus_win", M.bus_win)
	var f := 1.0 if toward else -1.0
	geo.box("bus", Vector3(x, 1.75, z), Vector3(2.6, 3.0, 12.5), Vector2(4, 3.0))
	city.solid(Vector3(x, 1.6, z), Vector3(2.7, 3.2, 12.6))
	for sx in [-1.31, 1.31]:
		geo.quad("bus_win", Vector3(x + sx, 1.9, z - 5.5), Vector3(x + sx, 1.9, z + 5.5), Vector3(x + sx, 2.9, z + 5.5), Vector3(x + sx, 2.9, z - 5.5), Vector3(signf(sx), 0, 0), Vector2(2, 1))
	var front := z + f * 6.26
	var back := z - f * 6.26
	geo.quad("bus_win", Vector3(x - 1.2, 1.6, front), Vector3(x + 1.2, 1.6, front), Vector3(x + 1.2, 2.8, front), Vector3(x - 1.2, 2.8, front), Vector3(0, 0, f), Vector2(2, 1))
	geo.box("sign", Vector3(x, 3.0, front), Vector3(2.0, 0.3, 0.04), Vector2(1, 1))
	geo.box("dark", Vector3(x, 0.4, z), Vector3(2.66, 0.5, 9.0), Vector2(1, 1))
	for side in [-1.0, 1.0]:
		geo.box("head", Vector3(x + side, 0.8, front), Vector3(0.3, 0.18, 0.04), Vector2(1, 1))
		geo.box("tail", Vector3(x + side * 1.05, 1.0, back), Vector3(0.22, 0.4, 0.04), Vector2(1, 1))


func moving_car(x: float, z: float, v: float) -> AnimatableBody3D:
	var g := Geo.new()
	for k in geo.mats:
		g.add_mat(k, geo.mats[k])
	car(0.0, 0.0, false, g)
	var body := AnimatableBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.9, 1.7, 4.4)
	cs.shape = b
	cs.position = Vector3(0, 0.85, 0)
	body.add_child(cs)
	g.build(body)
	body.position = Vector3(x, 0, z)
	city.world.add_child(body)
	movers.append({"node": body, "v": v, "z0": -420.0, "z1": 50.0})
	return body


func _physics_process(dt: float) -> void:
	for c in movers:
		var n: Node3D = c.node
		var z: float = n.position.z + c.v * dt
		if z < c.z0:
			z += c.z1 - c.z0
		n.position.z = z
