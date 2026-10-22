extends CharacterBody3D

signal footstep(speed: float)
signal landed(impact: float)
signal bumped(body: Node3D, speed: float)

const Hands := preload("res://scripts/hands.gd")
const SETTINGS := "user://settings.cfg"
const WALK := 1.7
const RUN := 3.6
const SPRINT := 5.6
const EYE := 1.62
const GRAV := 17.0
const JUMP := 5.0
const SENS := 0.0022
const STEP := 0.35
const RADIUS := 0.3
const HEIGHT := 1.8
const FLOOR_NY := 0.7
const COYOTE := 0.12
const BUFFER := 0.14
const LAYER := 8

var head: Node3D
var cam: Camera3D
var hands: Node3D
var steps: AudioStreamPlayer
var pitch := 0.0
var vy := 0.0
var grounded := true
var phase := 0.0
var amp := 0.0
var run_k := 0.0
var sprint_k := 0.0
var eye_y := 0.0
var land := 0.0
var roll := 0.0
var hvel := Vector3.ZERO
var knock := Vector3.ZERO
var shake := 0.0
var look_acc := Vector2.ZERO
var look_vel := Vector2.ZERO
var jump_q := 0.0
var coyote := 0.0
var sim := {}
var auto := false
var sensitivity := 1.0
var invert_y := false
var base_fov := 64.0
var floor_body: Object
var on_real_floor := true
var last_floor_y := 0.0
var safe_pos := Vector3.ZERO
var safe_t := 0.0
var shift_tap := 0.0
var sprinting := false
var bodies := {}
var last_pos := Vector3.ZERO


func setup(feet: Vector3, target: Vector3) -> void:
	collision_layer = LAYER
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	safe_margin = 0.02
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT - STEP
	shape.shape = cap
	shape.position = Vector3(0, STEP + cap.height * 0.5, 0)
	add_child(shape)
	head = Node3D.new()
	head.position = Vector3(0, EYE, 0)
	add_child(head)
	cam = Camera3D.new()
	cam.fov = base_fov
	cam.near = 0.05
	cam.far = 900.0
	cam.current = true
	head.add_child(cam)
	hands = Hands.new()
	cam.add_child(hands)
	steps = AudioStreamPlayer.new()
	steps.stream = _step_sound()
	steps.volume_db = -20.0
	add_child(steps)
	reload_settings()
	position = feet
	eye_y = feet.y
	last_floor_y = feet.y
	safe_pos = feet
	last_pos = feet
	var d := target - (feet + Vector3(0, EYE, 0))
	rotation.y = atan2(-d.x, -d.z)
	pitch = atan2(d.y, Vector2(d.x, d.z).length())
	head.rotation.x = pitch


func reload_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) != OK:
		return
	apply_settings(cf.get_value("controls", "mouse_sensitivity", 1.0), cf.get_value("controls", "invert_y", false), cf.get_value("video", "fov", 64.0))


func apply_settings(sens: float, invert: bool, fov: float) -> void:
	sensitivity = clampf(sens, 0.1, 5.0)
	invert_y = invert
	base_fov = clampf(fov, 50.0, 90.0)
	if cam:
		cam.fov = base_fov


func capture(on: bool) -> void:
	if auto or (on and not Game.test_mode and not Game.input_enabled):
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func look(rel: Vector2) -> void:
	var d := rel * SENS * sensitivity
	if invert_y:
		d.y = -d.y
	look_acc += d
	rotation.y = wrapf(rotation.y - d.x, -PI, PI)
	pitch = clampf(pitch - d.y, -1.45, 1.45)
	if head:
		head.rotation.x = pitch


func _input(e: InputEvent) -> void:
	if auto:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(e.relative)
	elif e is InputEventMouseButton and e.pressed:
		capture(true)
	elif e is InputEventKey and not e.echo:
		if e.pressed:
			match e.physical_keycode:
				KEY_ESCAPE:
					if Game.test_mode:
						capture(false)
				KEY_SPACE:
					jump_q = BUFFER
				KEY_E:
					hands.toggle_phone()
				KEY_SHIFT:
					sprinting = shift_tap > 0.0
					shift_tap = 0.3
		elif e.physical_keycode == KEY_SHIFT:
			sprinting = false


func _ready() -> void:
	capture.call_deferred(true)


func _notification(what: int) -> void:
	if auto:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		capture(true)


func _keys() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		v.x -= 1.0
	return v


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, depth: float) -> Dictionary:
	var to := from + Vector3(0, -depth, 0)
	for i in 4:
		var q := PhysicsRayQueryParameters3D.create(from, to, 3)
		var r := space.intersect_ray(q)
		if r.is_empty():
			return {}
		if r.normal.y >= FLOOR_NY:
			return r
		from = r.position + Vector3(0, -0.02, 0)
		if from.y <= to.y:
			return {}
	return {}


func _floor() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var top := global_position.y + STEP + 0.05
	var best := {}
	var offs := [Vector2.ZERO]
	for i in 8:
		var a := TAU * i / 8.0
		offs.append(Vector2(cos(a), sin(a)) * (RADIUS - 0.05))
	for o in offs:
		var r := _ray(space, Vector3(global_position.x + o.x, top, global_position.z + o.y), 40.0)
		if r.is_empty():
			continue
		if best.is_empty() or r.position.y > best.position.y:
			best = r
	return best


func _input_state(dt: float) -> Array:
	var mv := Vector2.ZERO
	var mode := 0
	if auto:
		mv = sim.get("move", Vector2.ZERO)
		if sim.get("run", false):
			mode = 2
		elif sim.get("jog", false):
			mode = 1
		var l: Vector2 = sim.get("look", Vector2.ZERO) * dt
		if l != Vector2.ZERO:
			look_acc += l
			rotation.y -= l.x
			pitch = clampf(pitch - l.y, -1.45, 1.45)
			head.rotation.x = pitch
		if sim.get("jump", false):
			jump_q = BUFFER
			sim.jump = false
		if sim.get("phone", false):
			hands.toggle_phone()
			sim.phone = false
	else:
		mv = _keys()
		if Input.is_physical_key_pressed(KEY_SHIFT):
			mode = 2 if sprinting else 1
		else:
			sprinting = false
	if mv.length() > 1.0:
		mv = mv.normalized()
	return [mv, mode]


func teleport(feet: Vector3) -> void:
	global_position = feet
	eye_y = feet.y
	last_floor_y = feet.y
	safe_pos = feet
	last_pos = feet
	hvel = Vector3.ZERO
	knock = Vector3.ZERO
	vy = 0.0
	grounded = false


func _physics_process(dt: float) -> void:
	if global_position.distance_to(last_pos) > 2.0:
		teleport(global_position)
	shift_tap = maxf(shift_tap - dt, 0.0)
	var st := _input_state(dt)
	var mv: Vector2 = st[0]
	var mode: int = st[1]
	var look_d := look_acc
	look_acc = Vector2.ZERO
	look_vel = look_vel.lerp(look_d / dt, 1.0 - exp(-12.0 * dt))
	var forward := mv.y > 0.1
	var speed := WALK
	if mode == 2 and forward:
		speed = SPRINT
	elif mode >= 1:
		speed = RUN
	if mv.y < -0.1:
		speed = minf(speed, RUN * 0.8)
	var want := global_basis * Vector3(mv.x, 0, -mv.y) * speed
	var rate := 4.0 if want.length() > 0.1 else 1.0
	if grounded:
		rate = 10.0 if want.length() > hvel.length() else 13.0
	hvel = hvel.lerp(want, 1.0 - exp(-rate * dt))
	_bump(dt)
	coyote = COYOTE if grounded else maxf(coyote - dt, 0.0)
	jump_q = maxf(jump_q - dt, 0.0)
	if jump_q > 0.0 and (grounded or coyote > 0.0) and vy <= 0.0:
		vy = JUMP
		grounded = false
		coyote = 0.0
		jump_q = 0.0
	if not grounded:
		vy -= GRAV * dt
	velocity = hvel + knock + Vector3(0, vy if not grounded else 0.0, 0)
	var before := global_position
	move_and_slide()
	hvel = Vector3(velocity.x, 0, velocity.z) - knock
	if not grounded and vy > 0.0 and velocity.y < vy * 0.5:
		vy = minf(vy, maxf(velocity.y, 0.0))
	knock = knock.lerp(Vector3.ZERO, 1.0 - exp(-5.0 * dt))
	_settle(dt)
	var moved := global_position - before
	moved.y = 0.0
	_feel(dt, moved, mv, mode, forward)
	last_pos = global_position


func _settle(dt: float) -> void:
	var f := _floor()
	var fh := last_floor_y
	on_real_floor = not f.is_empty()
	if on_real_floor:
		fh = f.position.y
		floor_body = f.collider
	var y := global_position.y
	if grounded:
		if fh < y - STEP:
			grounded = false
			vy = 0.0
		else:
			global_position.y = fh
	elif vy <= 0.0 and y <= fh + 0.01:
		global_position.y = fh
		grounded = true
		land = clampf(-vy * 0.018, 0.0, 0.12)
		landed.emit(-vy)
		vy = 0.0
		_step()
	if grounded:
		last_floor_y = global_position.y
		safe_t += dt
		if on_real_floor and safe_t > 0.5:
			safe_t = 0.0
			safe_pos = global_position
	if global_position.y < last_floor_y - 6.0 or global_position.y < safe_pos.y - 12.0:
		global_position = safe_pos
		eye_y = safe_pos.y
		vy = 0.0
		hvel = Vector3.ZERO
		knock = Vector3.ZERO
		grounded = true
		last_floor_y = safe_pos.y


func _bump(dt: float) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS + 0.12
	cap.height = HEIGHT - STEP + 0.1
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, STEP + (HEIGHT - STEP) * 0.5, 0))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var seen := {}
	for hit in space.intersect_shape(q, 8):
		var b = hit.collider
		if not (b is AnimatableBody3D):
			continue
		var id: int = b.get_instance_id()
		var p: Vector3 = b.global_position
		seen[id] = p
		if not bodies.has(id):
			continue
		var v: Vector3 = (p - bodies[id]) / dt
		v.y = 0.0
		var s := v.length()
		if s < 0.6:
			continue
		var dir := v / s
		var r := global_position - p
		r.y = 0.0
		if r.dot(dir) < -0.3:
			continue
		var side := r - dir * r.dot(dir)
		if side.length() < 0.05:
			side = dir.cross(Vector3.UP) * (1.0 if hvel.dot(dir.cross(Vector3.UP)) >= 0.0 else -1.0)
		side = side.normalized()
		var strength := clampf(1.5 + s * 0.6, 1.5, 9.0)
		if knock.dot(side) < strength * 0.7:
			knock = side * strength + dir * minf(s, 2.0) * 0.3
			hvel = hvel - dir * maxf(hvel.dot(dir), 0.0)
			shake = maxf(shake, clampf(s * 0.012, 0.01, 0.09))
			bumped.emit(b, s)
	bodies = seen


func _feel(dt: float, moved: Vector3, mv: Vector2, mode: int, forward: bool) -> void:
	var spd := moved.length() / dt
	run_k = lerpf(run_k, 1.0 if mode >= 1 and spd > WALK + 0.3 else 0.0, 1.0 - exp(-6.0 * dt))
	sprint_k = lerpf(sprint_k, 1.0 if mode == 2 and forward and spd > RUN + 0.3 else 0.0, 1.0 - exp(-5.0 * dt))
	amp = lerpf(amp, clampf(spd / WALK, 0.0, 1.5) if grounded else 0.0, 1.0 - exp(-8.0 * dt))
	var stride := lerpf(lerpf(0.7, 0.95, run_k), 1.2, sprint_k)
	var prev := floori(phase / PI)
	phase += moved.length() * PI / stride
	if grounded and floori(phase / PI) != prev and spd > 0.4:
		_step()
		footstep.emit(spd)
	eye_y = lerpf(eye_y, global_position.y, 1.0 - exp(-14.0 * dt))
	land = lerpf(land, 0.0, 1.0 - exp(-7.0 * dt))
	var bob_a := 0.016 + run_k * 0.006 + sprint_k * 0.008
	var bob := Vector3(sin(phase) * bob_a * amp * 0.8, -cos(phase * 2.0) * bob_a * amp, 0)
	head.position = Vector3(bob.x, EYE + eye_y - global_position.y + bob.y - land, 0)
	roll = lerpf(roll, -mv.x * 0.02 + sin(phase) * 0.005 * amp, 1.0 - exp(-8.0 * dt))
	shake = lerpf(shake, 0.0, 1.0 - exp(-6.0 * dt))
	var t := Time.get_ticks_msec() * 0.001
	cam.rotation = Vector3(sin(t * 37.0) * shake, sin(t * 29.0 + 1.3) * shake, roll + sin(t * 23.0) * shake * 0.5)
	cam.fov = lerpf(cam.fov, base_fov + run_k * 2.0 + sprint_k * 4.0, 1.0 - exp(-6.0 * dt))
	var air := clampf(-vy * 0.012, -0.05, 0.05) if not grounded else 0.0
	hands.animate(dt, phase, amp, maxf(run_k * 0.5, sprint_k), air - land * 0.4, look_vel, pitch)


func _step() -> void:
	steps.pitch_scale = randf_range(0.85, 1.15)
	steps.play()


func _step_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.12)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var r := RandomNumberGenerator.new()
	r.seed = 11
	for i in n:
		var tt := float(i) / rate
		var env := exp(-tt * 38.0)
		lp = lerpf(lp, r.randf_range(-1.0, 1.0), 0.18)
		var s := lp * env * 0.9 + sin(tt * TAU * 85.0) * exp(-tt * 50.0) * 0.5
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
