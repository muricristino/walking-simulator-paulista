extends Node

const Layout := preload("res://scripts/layout.gd")

var player: CharacterBody3D
var vp: SubViewport
var out := ""
var plan := []
var i := 0
var shooting := false
var stuck := 0.0
var nudge := 0.0
var last := Vector3.ZERO
var t := 0.0
var leg_t := 0.0


func _ready() -> void:
	var city := get_parent()
	var cz := Layout.MASP_CROSSWALK_Z
	var rio_pts := _rio_points(city)
	if OS.get_cmdline_user_args().has("--rio"):
		player.teleport(Vector3(-24.0, 0.15, Layout.RIO_Z))
		plan = [{"to": Vector2(-26.0, Layout.RIO_Z), "shot": "r1_start", "look": Vector3(-80.0, 1.6, -333.0)}]
		plan.append_array(_rio_plan(rio_pts, "r"))
		return
	plan = [
		{"to": Vector2(21.5, -12.0), "shot": "01_idle", "look": Layout.SPAWN_LOOK},
		{"to": Vector2(21.5, -20.0), "shot": "02_walk"},
		{"phone": true, "to": Vector2(20.5, -30.0), "shot": "03_phone"},
		{"phone": true, "to": Vector2(19.0, cz + 0.5), "run": true, "shot": "04_crosswalk", "look": Vector3(-19.0, 1.6, cz)},
		{"wait_walk": cz, "to": Vector2(-19.0, cz), "shot": "05_crossed", "look": Vector3(-21.0, 1.6, -150.0)},
		{"to": Vector2(-21.5, -146.0), "run": true, "shot": "06_otavio"},
		{"to": Vector2(-21.5, Layout.RIO_GAP.y - 2.0), "run": true, "shot": "07_corner", "look": Vector3(-60.0, 1.6, Layout.RIO_Z)},
		{"to": Vector2(-40.0, Layout.RIO_Z + 2.5), "shot": "08_arrival"},
	]
	plan.append_array(_rio_plan(rio_pts, "09"))


func _rio_points(city: Node) -> Array:
	var out_pts := []
	var rio: Variant = city.get("rio")
	if not rio:
		return out_pts
	for q in rio.data.street:
		if q.p[0] < -45.0:
			out_pts.append(Vector2(q.p[0], q.p[1]))
	return out_pts


func _rio_plan(pts: Array, tag: String) -> Array:
	var steps := []
	if pts.is_empty():
		return steps
	var names := {pts.size() / 3: "_meio", 2 * pts.size() / 3: "_rua", pts.size() - 1: "_fim"}
	for k in pts.size():
		if k % 3 != 0 and not names.has(k):
			continue
		var s := {"to": pts[k]}
		if names.has(k):
			s.shot = tag + names[k]
		steps.append(s)
	return steps


func _physics_process(dt: float) -> void:
	if shooting:
		return
	if i >= plan.size():
		set_physics_process(false)
		print("autowalk done t %.1f pos %s goal %s" % [t, player.global_position, str(get_parent().get("goal_done"))])
		await Game.quit()
		return
	t += dt
	leg_t += dt
	var s: Dictionary = plan[i]
	if s.get("phone", false) != player.hands.phone_on:
		player.hands.set_phone(s.get("phone", false))
	if s.has("wait_walk") and not s.get("go", false):
		var tr: Variant = get_parent().get("traffic")
		if tr and tr.has_method("is_walk_open") and not (tr.is_walk_open(s.wait_walk) and tr.ped_time_left(s.wait_walk) > 8.0):
			player.sim = {}
			_face(s.to)
			return
		s.go = true
	var p := player.global_position
	var d := Vector2(s.to.x - p.x, s.to.y - p.z)
	if d.length() < 0.9 or leg_t > 120.0:
		await _arrive(s)
		return
	_face(s.to)
	player.sim = {"move": Vector2(0, 1), "run": s.get("run", false)}
	if OS.get_cmdline_user_args().has("--trace") and fmod(t, 1.0) < dt:
		print("trace t %.1f leg %d pos %s stuck %.2f nudge %.2f" % [t, i, p, stuck, nudge])
	_unstick(dt)


func _face(to: Vector2) -> void:
	var p := player.global_position
	player.rotation.y = atan2(-(to.x - p.x), -(to.y - p.z))


func _arrive(s: Dictionary) -> void:
	player.sim = {}
	print("step %d pos %s t %.1f leg %.1f goal %s" % [i, player.global_position, t, leg_t, str(get_parent().get("goal_done"))])
	if s.has("shot"):
		shooting = true
		if s.has("look"):
			var d: Vector3 = s.look - (player.global_position + Vector3(0, 1.62, 0))
			player.rotation.y = atan2(-d.x, -d.z)
			player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
			player.head.rotation.x = player.pitch
		for f in 3:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out.path_join(s.shot + ".png"))
		player.pitch = 0.0
		player.head.rotation.x = 0.0
		shooting = false
	i += 1
	leg_t = 0.0


func _unstick(dt: float) -> void:
	var pos := player.global_position
	var moved := Vector2(pos.x - last.x, pos.z - last.z).length()
	last = pos
	if nudge > 0.0:
		nudge -= dt
		player.sim.move = Vector2(1.0, 0.2)
		return
	stuck = stuck + dt if moved < 0.6 * dt else 0.0
	if stuck > 0.4:
		stuck = 0.0
		nudge = 0.5
