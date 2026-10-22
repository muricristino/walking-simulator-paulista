extends CharacterBody3D

const Hands := preload("res://scripts/hands.gd")
const WALK := 2.3
const RUN := 5.2
const EYE := 1.62
const GRAV := 17.0
const JUMP := 4.4
const SENS := 0.0022

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
var eye_y := 0.0
var land := 0.0
var roll := 0.0
var hvel := Vector3.ZERO
var look_acc := Vector2.ZERO
var look_vel := Vector2.ZERO
var jump_q := false
var sim := {}
var auto := false


func setup(feet: Vector3, target: Vector3) -> void:
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.3
	shape.shape = cap
	shape.position = Vector3(0, 1.1, 0)
	add_child(shape)
	head = Node3D.new()
	head.position = Vector3(0, EYE, 0)
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 64.0
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
	position = feet
	eye_y = feet.y
	var d := target - (feet + Vector3(0, EYE, 0))
	rotation.y = atan2(-d.x, -d.z)
	pitch = atan2(d.y, Vector2(d.x, d.z).length())
	head.rotation.x = pitch


func capture(on: bool) -> void:
	if auto:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _input(e: InputEvent) -> void:
	if auto:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_acc += e.relative
	elif e is InputEventMouseButton and e.pressed:
		capture(true)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_ESCAPE:
				capture(false)
			KEY_SPACE:
				jump_q = true
			KEY_E:
				hands.toggle_phone()


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


func _floor_h() -> float:
	var from := global_position + Vector3(0, 0.6, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -4.0, 0), 2)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r.position.y if r else 0.0


func _physics_process(dt: float) -> void:
	var mv := Vector2.ZERO
	var run := false
	var look := look_acc * SENS
	look_acc = Vector2.ZERO
	if auto:
		mv = sim.get("move", Vector2.ZERO)
		run = sim.get("run", false)
		look += sim.get("look", Vector2.ZERO) * dt
		if sim.get("jump", false):
			jump_q = true
			sim.jump = false
		if sim.get("phone", false):
			hands.toggle_phone()
			sim.phone = false
	else:
		mv = _keys()
		run = Input.is_physical_key_pressed(KEY_SHIFT)
	if mv.length() > 1.0:
		mv = mv.normalized()
	rotation.y -= look.x
	pitch = clampf(pitch - look.y, -1.45, 1.45)
	head.rotation.x = pitch
	look_vel = look_vel.lerp(look / dt, 1.0 - exp(-12.0 * dt))
	var running := run and mv.y > 0.1
	var want := global_basis * Vector3(mv.x, 0, -mv.y) * (RUN if running else WALK)
	hvel = hvel.lerp(want, 1.0 - exp(-(10.0 if grounded else 1.5) * dt))
	velocity = hvel
	var before := global_position
	move_and_slide()
	hvel = Vector3(velocity.x, 0, velocity.z)
	var moved := global_position - before
	moved.y = 0.0
	var fh := _floor_h()
	if grounded:
		if jump_q:
			vy = JUMP
			grounded = false
		elif fh < global_position.y - 0.35:
			grounded = false
			vy = 0.0
		else:
			global_position.y = fh
	jump_q = false
	if not grounded:
		vy -= GRAV * dt
		global_position.y += vy * dt
		if vy <= 0.0 and global_position.y <= fh:
			global_position.y = fh
			grounded = true
			land = clampf(-vy * 0.018, 0.0, 0.12)
			vy = 0.0
			_step()
	var spd := moved.length() / dt
	run_k = lerpf(run_k, 1.0 if running and spd > WALK else 0.0, 1.0 - exp(-6.0 * dt))
	amp = lerpf(amp, clampf(spd / WALK, 0.0, 1.6) if grounded else 0.0, 1.0 - exp(-8.0 * dt))
	var stride := lerpf(0.72, 1.05, run_k)
	var prev := floori(phase / PI)
	phase += moved.length() * PI / stride
	if grounded and floori(phase / PI) != prev and spd > 0.4:
		_step()
	eye_y = lerpf(eye_y, global_position.y, 1.0 - exp(-14.0 * dt))
	land = lerpf(land, 0.0, 1.0 - exp(-7.0 * dt))
	var bob := Vector3(sin(phase) * 0.022 * amp, -cos(phase * 2.0) * 0.022 * amp, 0)
	head.position = Vector3(bob.x, EYE + eye_y - global_position.y + bob.y - land, 0)
	roll = lerpf(roll, -mv.x * 0.025 + sin(phase) * 0.006 * amp, 1.0 - exp(-8.0 * dt))
	cam.rotation.z = roll
	cam.fov = lerpf(cam.fov, 64.0 + run_k * 5.0, 1.0 - exp(-6.0 * dt))
	var air := clampf(-vy * 0.012, -0.05, 0.05) if not grounded else 0.0
	hands.animate(dt, phase, amp, run_k, air - land * 0.4, look_vel)


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
