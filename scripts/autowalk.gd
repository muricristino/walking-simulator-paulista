extends Node

var player: CharacterBody3D
var vp: SubViewport
var out := ""
var plan := []
var i := 0
var left := 0.0
var shooting := false
var stuck := 0.0
var nudge := 0.0
var last := Vector3.ZERO


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--rio"):
		plan = [
			{"t": 1.0, "shot": "r1_start"},
			{"t": 5.0, "move": Vector2(0, 1), "run": true, "shot": "r2_entrada"},
			{"t": 12.0, "move": Vector2(0, 1), "run": true, "shot": "r3_meio"},
			{"t": 14.0, "move": Vector2(0, 1), "run": true, "shot": "r4_fim"},
			{"t": 8.0, "move": Vector2(0, 1), "run": true, "shot": "r5_parede"},
		]
		_begin()
		return
	plan = [
		{"t": 1.2, "shot": "01_idle"},
		{"t": 1.4, "move": Vector2(0, 1), "shot": "02_walk"},
		{"t": 1.0, "look": Vector2(1.6, 0), "move": Vector2(0, 0.4)},
		{"t": 4.0, "move": Vector2(0, 1), "shot": "03_wall"},
		{"t": 1.0, "look": Vector2(-1.9, 0.1)},
		{"t": 0.1, "phone": true},
		{"t": 1.4, "shot": "04_phone"},
		{"t": 1.2, "move": Vector2(0, 1), "shot": "05_phone_walk"},
		{"t": 0.1, "phone": true},
		{"t": 1.0, "move": Vector2(0, 1)},
		{"t": 1.6, "move": Vector2(0, 1), "run": true, "shot": "06_run"},
		{"t": 0.05, "move": Vector2(0, 1), "run": true, "jump": true},
		{"t": 0.3, "move": Vector2(0, 1), "run": true, "shot": "07_jump"},
		{"t": 1.0, "look": Vector2(0.9, 0.0)},
		{"t": 6.0, "move": Vector2(0, 1), "run": true, "shot": "08_lamp"},
		{"t": 1.0, "look": Vector2(1.57, 0.0)},
		{"t": 5.0, "move": Vector2(0, 1), "run": true, "shot": "09_street"},
		{"t": 1.0, "look": Vector2(-1.79, 0.0)},
		{"t": 2.6, "move": Vector2(0, 1)},
		{"t": 1.0, "look": Vector2(-1.57, 0.0)},
		{"t": 12.0, "move": Vector2(0, 1), "run": true},
		{"t": 1.0, "look": Vector2(-1.2, -0.25), "shot": "10_masp"},
	]
	_begin()


func _begin() -> void:
	if i >= plan.size():
		print("autowalk done")
		get_tree().quit()
		return
	var s: Dictionary = plan[i]
	left = s.t
	player.sim = {"move": s.get("move", Vector2.ZERO), "look": s.get("look", Vector2.ZERO), "run": s.get("run", false), "jump": s.get("jump", false), "phone": s.get("phone", false)}


func _physics_process(dt: float) -> void:
	if shooting or i >= plan.size():
		return
	_unstick(dt)
	left -= dt
	if left > 0.0:
		return
	var s: Dictionary = plan[i]
	print("step %d pos %s yaw %.2f fps %d goal %s" % [i, player.global_position, player.rotation.y, Engine.get_frames_per_second(), str(get_parent().get("goal_done"))])
	if s.has("shot"):
		shooting = true
		player.sim = {}
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(out.path_join(s.shot + ".png"))
		shooting = false
	i += 1
	_begin()


func _unstick(dt: float) -> void:
	var want: Vector2 = plan[i].get("move", Vector2.ZERO)
	var pos := player.global_position
	var moved := Vector2(pos.x - last.x, pos.z - last.z).length()
	last = pos
	if want.length() < 0.1:
		stuck = 0.0
		return
	if nudge > 0.0:
		nudge -= dt
		player.sim.move = Vector2(1.0, 0.2) if nudge > 0.0 else want
		return
	stuck = stuck + dt if moved < 0.6 * dt else 0.0
	if stuck > 0.25:
		stuck = 0.0
		nudge = 0.5
