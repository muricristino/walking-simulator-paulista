extends Node

const People := preload("res://scripts/people.gd")
const Katcho := preload("res://scripts/katcho.gd")
const Layout := preload("res://scripts/layout.gd")
const RNG_STATE := -7827248741660285753

var city: Node
var rng := RandomNumberGenerator.new()
var people := People.new()
var katcho := Katcho.new()
var ped_vars := []
var walkers := []
var statics := []
var placed := []
var lod_t := 0.0


func build(c: Node) -> void:
	city = c
	rng.state = RNG_STATE
	var mz: Vector2 = Layout.MASP_Z
	for i in 70:
		var sx := -1.0 if rng.randf() < 0.5 else 1.0
		var z := rng.randf_range(-6, -320)
		if Layout.in_cross(z - 1, z + 1):
			continue
		person(Vector3(sx * rng.randf_range(23.2, 29), 0.15, z))
	for i in 40:
		person(Vector3(rng.randf_range(-56, -31), 0.16, rng.randf_range(mz.x + 2, mz.y - 2)))
	for i in 10:
		person(Vector3(rng.randf_range(-15, -5), 0.0, rng.randf_range(-46, -50)))
	for i in 14:
		person(Vector3(rng.randf_range(23.2, 28.0), 0.15, rng.randf_range(-24, -60)))
	for sx in [-1.0, 1.0]:
		for i in 16:
			walker(sx * rng.randf_range(20.4, 22.2), rng.randf_range(-320, 40), -1.0 if rng.randf() < 0.5 else 1.0)


func civilian(height: float) -> Dictionary:
	if ped_vars.is_empty():
		ped_vars = katcho.variants()
	var v: Array = ped_vars[rng.randi() % ped_vars.size()]
	var c := katcho.make(v[0], v[1], height)
	var sh := MeshInstance3D.new()
	sh.mesh = people._shadow()
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.root.add_child(sh)
	return c


func walker(x: float, z: float, dir: float) -> Dictionary:
	var hs := rng.randf_range(0.95, 1.05)
	var c := civilian(1.72 * hs)
	var body := AnimatableBody3D.new()
	body.collision_layer = 1
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
	body.position = Vector3(x, 0.15, z)
	body.rotation.y = 0.0 if dir < 0.0 else PI
	city.world.add_child(body)
	var speed: float = c.spec.stride * rng.randf_range(0.95, 1.1)
	katcho.play(c, true, rng.randf() * 2.0)
	var w := {"node": body, "c": c, "dir": dir, "speed": speed, "v": speed, "walking": true}
	walkers.append(w)
	return w


func person(p: Vector3) -> void:
	for q in placed:
		if Vector2(p.x - q.x, p.z - q.z).length_squared() < 0.64:
			return
	placed.append(p)
	var hs := rng.randf_range(0.95, 1.05)
	var c := civilian(1.72 * hs)
	var r: Node3D = c.root
	r.position = p
	r.rotation.y = rng.randf() * TAU
	city.world.add_child(r)
	katcho.play(c, false, rng.randf() * 4.0, rng.randf_range(0.85, 1.1))
	statics.append({"ap": c.ap, "pos": p})
	city.solid(p + Vector3(0, 0.875 * hs, 0), Vector3(0.5, 1.75 * hs, 0.32))


func _physics_process(dt: float) -> void:
	if not city:
		return
	for w in walkers:
		_walk(w, dt)
	lod_t -= dt
	var player: Node3D = city.player
	if lod_t <= 0.0 and player:
		lod_t = 0.4
		var pp := player.global_position
		for st in statics:
			var ap: AnimationPlayer = st.ap
			if ap:
				ap.active = (st.pos as Vector3).distance_squared_to(pp) < 900.0


func _walk(w: Dictionary, dt: float) -> void:
	var n: Node3D = w.node
	var want: float = w.speed
	var player: Node3D = city.player
	if player:
		var d := player.global_position - n.position
		if absf(d.x) < 0.75 and d.z * w.dir > 0.0 and d.z * w.dir < 1.5:
			want = 0.0
	w.v = lerpf(w.v, want, 1.0 - exp(-6.0 * dt))
	var z: float = n.position.z + w.dir * w.v * dt
	if z < -330.0:
		w.dir = 1.0
		n.rotation.y = PI
	elif z > 45.0:
		w.dir = -1.0
		n.rotation.y = 0.0
	n.position = Vector3(n.position.x, 0.0 if Layout.in_cross(z, z) else 0.15, z)
	var c: Dictionary = w.c
	var moving: bool = w.v > 0.25
	if moving != w.walking:
		w.walking = moving
		katcho.play(c, moving)
	var ap: AnimationPlayer = c.ap
	if ap:
		ap.speed_scale = maxf(w.v, 0.3) / c.spec.stride if moving else 1.0
