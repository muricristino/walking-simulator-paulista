extends Node3D

const Geo := preload("res://scripts/geo.gd")
const Tex := preload("res://scripts/tex.gd")
const PS1 := preload("res://scripts/ps1.gdshader")

var arm_l: Node3D
var arm_r: Node3D
var grip: Node3D
var phone_light: OmniLight3D
var mats := {}
var t := 0.0
var phone := 0.0
var phone_on := false
var lag := Vector2.ZERO


func _ready() -> void:
	_materials()
	arm_l = _relaxed(-1.0)
	arm_r = _relaxed(1.0)
	grip = _grip()
	for n in [arm_l, arm_r, grip]:
		add_child(n)
	grip.visible = false


func _mat(tex: Texture2D, unshaded := 0.28, emit := Color.BLACK) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("tint", Color.WHITE)
	m.set_shader_parameter("unshaded", unshaded)
	m.set_shader_parameter("emit", Vector3(emit.r, emit.g, emit.b))
	m.set_shader_parameter("squash", 0.92)
	m.set_shader_parameter("affine", 0.3)
	return m


func _materials() -> void:
	mats.skin = _mat(Tex.flat(Color(0.78, 0.55, 0.42), 8, 0.035, 0.35, 201))
	mats.knuckle = _mat(Tex.flat(Color(0.7, 0.47, 0.37), 8, 0.03, 0.3, 202))
	mats.sleeve = _mat(Tex.flat(Color(0.2, 0.23, 0.27), 16, 0.05, 0.55, 203))
	mats.stripe = _mat(Tex.flat(Color(0.82, 0.62, 0.18), 8, 0.04, 0.3, 204))
	mats.cuff = _mat(_ribs(Color(0.13, 0.15, 0.18), Color(0.2, 0.22, 0.26)))
	mats.case = _mat(Tex.flat(Color(0.08, 0.08, 0.09), 8, 0.02, 0.2, 205))
	mats.screen = _mat(_screen_tex(), 1.0)


func _ribs(a: Color, b: Color) -> ImageTexture:
	var img := Image.create(8, 4, false, Image.FORMAT_RGB8)
	for y in 4:
		for x in 8:
			img.set_pixel(x, y, a if x % 2 == 0 else b)
	return ImageTexture.create_from_image(img)


func _screen_tex() -> ImageTexture:
	var w := 14
	var h := 28
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var top := Color(0.2, 0.12, 0.42)
	var bot := Color(0.95, 0.45, 0.3)
	for y in h:
		for x in w:
			img.set_pixel(x, y, top.lerp(bot, float(y) / h))
	for x in range(4, 10):
		for y in range(3, 6):
			if not (y == 4 and x == 7):
				img.set_pixel(x, y, Color(1, 1, 0.95))
	var icons := [Color(0.3, 0.8, 0.4), Color(0.2, 0.55, 0.95), Color(0.95, 0.8, 0.2), Color(0.95, 0.3, 0.35), Color(0.75, 0.75, 0.8), Color(0.55, 0.3, 0.9)]
	var k := 0
	for row in 3:
		for col in 3:
			var c: Color = icons[k % icons.size()]
			k += 1
			for yy in 2:
				for xx in 2:
					img.set_pixel(2 + col * 4 + xx, 9 + row * 4 + yy, c)
	for x in range(1, w - 1):
		for y in range(23, 26):
			img.set_pixel(x, y, Color(0.12, 0.1, 0.16))
	for col in 3:
		for xx in 2:
			img.set_pixel(3 + col * 4 + xx, 24, icons[col])
	return ImageTexture.create_from_image(img)


func _obox(g: Geo, key: String, a: Vector3, b: Vector3, w0: float, t0: float, w1: float, t1: float, side := Vector3.RIGHT) -> void:
	var f := (b - a).normalized()
	var r := (side - f * side.dot(f)).normalized()
	var u := r.cross(f).normalized()
	var offs := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var A := []
	var B := []
	for o in offs:
		A.append(a + r * o.x * w0 * 0.5 + u * o.y * t0 * 0.5)
		B.append(b + r * o.x * w1 * 0.5 + u * o.y * t1 * 0.5)
	var unit := Vector2(0.06, 0.06)
	for i in 4:
		var j := (i + 1) % 4
		var n: Vector3 = ((A[i] + A[j]) * 0.5 - a).normalized()
		g.quad(key, A[i], A[j], B[j], B[i], n, unit, Vector2.ZERO, 1.0)
	g.quad(key, A[0], A[1], A[2], A[3], -f, unit, Vector2.ZERO, 1.0)
	g.quad(key, B[0], B[1], B[2], B[3], f, unit, Vector2.ZERO, 1.0)


func _new_geo() -> Geo:
	var g := Geo.new()
	for k in mats:
		g.add_mat(k, mats[k])
	return g


func _sleeve(g: Geo, elbow: Vector3, wrist: Vector3, side: Vector3, m: float) -> void:
	var f := (wrist - elbow).normalized()
	var mid := elbow.lerp(wrist, 0.45)
	_obox(g, "sleeve", elbow - f * 0.06, mid, 0.122, 0.114, 0.116, 0.108, side)
	_obox(g, "sleeve", mid - f * 0.01, wrist - f * 0.04, 0.118, 0.11, 0.104, 0.096, side)
	_obox(g, "cuff", wrist - f * 0.045, wrist - f * 0.005, 0.096, 0.088, 0.092, 0.084, side)
	var r := (side - f * side.dot(f)).normalized()
	var u := r.cross(f).normalized()
	var s := r * m * 0.058
	_obox(g, "stripe", elbow - f * 0.06 + s, wrist - f * 0.05 + s * 0.9, 0.006, 0.018, 0.006, 0.016, side)
	_obox(g, "stripe", elbow - f * 0.06 + s + u * 0.026, wrist - f * 0.05 + s * 0.9 + u * 0.022, 0.006, 0.01, 0.006, 0.009, side)


func _relaxed(m: float) -> Node3D:
	var g := _new_geo()
	var x := Vector3(m, 1, 1)
	_sleeve(g, Vector3.ZERO, Vector3(0, 0.002, -0.262), Vector3.RIGHT, m)
	_obox(g, "skin", Vector3(0, 0, -0.205), Vector3(0, -0.002, -0.262), 0.054, 0.044, 0.064, 0.036)
	_obox(g, "skin", Vector3(0, -0.004, -0.256), Vector3(0, -0.008, -0.336), 0.074, 0.034, 0.086, 0.027)
	_obox(g, "knuckle", Vector3(0, -0.006, -0.33), Vector3(0, -0.008, -0.346), 0.084, 0.028, 0.082, 0.026)
	var fx := [-0.03, -0.01, 0.01, 0.029]
	var pl := [0.042, 0.047, 0.043, 0.033]
	var dl := [0.033, 0.036, 0.034, 0.027]
	var fw := [0.019, 0.02, 0.019, 0.016]
	for i in 4:
		var base := Vector3(fx[i], -0.008, -0.342) * x
		var a1 := deg_to_rad(18.0 + i * 4.0)
		var a2 := deg_to_rad(62.0 + i * 6.0)
		var j: Vector3 = base + Vector3(fx[i] * 0.12 * m, -sin(a1), -cos(a1)) * pl[i]
		var tip: Vector3 = j + Vector3(0, -sin(a2), -cos(a2)) * dl[i]
		_obox(g, "skin", base, j, fw[i], 0.018, fw[i] * 0.95, 0.017)
		_obox(g, "skin", j, tip, fw[i] * 0.92, 0.016, fw[i] * 0.85, 0.014)
	var t0 := Vector3(-0.034, -0.012, -0.262) * x
	var t1 := Vector3(-0.058, -0.024, -0.3) * x
	var t2 := Vector3(-0.062, -0.04, -0.334) * x
	_obox(g, "skin", t0, t1, 0.026, 0.024, 0.023, 0.021, Vector3.UP)
	_obox(g, "skin", t1, t2, 0.022, 0.02, 0.019, 0.017, Vector3.UP)
	var n := Node3D.new()
	g.build(n)
	_tune(n)
	return n


func _grip() -> Node3D:
	var g := _new_geo()
	g.box("case", Vector3(0, 0, -0.005), Vector3(0.07, 0.142, 0.01), Vector2(0.07, 0.07))
	g.quad("screen", Vector3(-0.032, -0.067, 0.0006), Vector3(0.032, -0.067, 0.0006), Vector3(0.032, 0.067, 0.0006), Vector3(-0.032, 0.067, 0.0006), Vector3.BACK, Vector2(0.064, 0.134), Vector2.ZERO, 1.0)
	var wrist := Vector3(0.075, -0.085, -0.03)
	var elbow := Vector3(0.21, -0.3, 0.06)
	_sleeve(g, elbow, wrist + (wrist - elbow).normalized() * 0.03, Vector3(0, 0, -1), 1.0)
	_obox(g, "skin", wrist - (wrist - elbow).normalized() * 0.02, Vector3(0.052, -0.06, -0.026), 0.056, 0.046, 0.062, 0.036, Vector3(0, 0, -1))
	_obox(g, "skin", Vector3(0.05, -0.058, -0.026), Vector3(-0.022, -0.03, -0.024), 0.082, 0.03, 0.086, 0.027, Vector3(0, 1, 0))
	var ys := [-0.062, -0.042, -0.022, -0.003]
	var lens := [0.03, 0.034, 0.032, 0.026]
	for i in 4:
		var y: float = ys[i] + 0.022
		var base := Vector3(-0.024, y, -0.022)
		var j: Vector3 = base + Vector3(-1, 0.05, 0.25).normalized() * lens[i]
		var tip: Vector3 = j + Vector3(0.15, 0.04, 1).normalized() * (0.024 + i * 0.002)
		_obox(g, "skin", base, j, 0.018, 0.017, 0.017, 0.016, Vector3(0, 1, 0))
		_obox(g, "skin", j, tip, 0.016, 0.015, 0.014, 0.013, Vector3(0, 1, 0))
	var t0 := Vector3(0.05, -0.07, -0.012)
	var t1 := Vector3(0.046, -0.04, 0.004)
	var t2 := Vector3(0.033, -0.014, 0.008)
	_obox(g, "skin", t0, t1, 0.026, 0.024, 0.022, 0.02, Vector3(0, 0, 1))
	_obox(g, "skin", t1, t2, 0.021, 0.018, 0.018, 0.015, Vector3(0, 0, 1))
	var n := Node3D.new()
	g.build(n)
	_tune(n)
	phone_light = OmniLight3D.new()
	phone_light.position = Vector3(0, 0, 0.08)
	phone_light.light_color = Color(0.75, 0.7, 1.0)
	phone_light.light_energy = 0.25
	phone_light.omni_range = 0.6
	n.add_child(phone_light)
	return n


func _tune(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.extra_cull_margin = 1.0


func toggle_phone() -> void:
	phone_on = not phone_on


func _relaxed_pose(m: float, swing: float, breath: float, amp: float, run: float) -> Transform3D:
	var pos := Vector3(0.25 * m, -0.29 - run * 0.03, -0.1)
	var rot := Vector3(24.0 - run * 6.0, 8.0 * m, -68.0 * m)
	pos.z += swing * 0.035 * m
	pos.y += absf(swing) * 0.012
	rot.x += swing * m * 5.0 + breath * 0.7
	rot.z += swing * 3.0
	pos.y += breath * 0.004
	return Transform3D(Basis.from_euler(rot * PI / 180.0), pos)


func _grip_pose(swing: float, breath: float) -> Transform3D:
	var pos := Vector3(0.035, -0.07, -0.3)
	pos.y += breath * 0.003 + swing * 0.004
	pos.x += swing * 0.004
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(-14.0 + breath * 0.5), deg_to_rad(-8.0), deg_to_rad(-6.0))), pos)


func animate(dt: float, phase: float, amp: float, run: float, air: float, look_vel: Vector2) -> void:
	t += dt
	phone = move_toward(phone, 1.0 if phone_on else 0.0, dt * 2.4)
	lag = lag.lerp(look_vel.clamp(Vector2(-6, -6), Vector2(6, 6)) * 0.006, 1.0 - exp(-10.0 * dt))
	var breath := sin(t * 1.7) * (1.0 - clampf(amp, 0.0, 1.0) * 0.6)
	var swing := sin(phase) * amp * (1.0 + run * 0.8)
	var bounce := Vector3(sin(phase) * 0.006 * amp, -cos(phase * 2.0) * 0.008 * amp + air, 0)
	var shift := Vector3(-lag.x, lag.y, 0) + bounce
	var lt := _relaxed_pose(-1.0, swing, breath, amp, run)
	lt.origin += shift
	arm_l.transform = lt
	var drop := smoothstep(0.0, 0.5, phone) if phone < 0.5 else 1.0 - smoothstep(0.5, 1.0, phone)
	var down := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-25.0 * drop), 0, 0)), Vector3(0.05, -0.42, 0.06) * drop)
	var holding := phone >= 0.5
	arm_r.visible = not holding
	grip.visible = holding
	if holding:
		var gt := _grip_pose(swing * 0.4, breath)
		gt.origin += shift * 0.6
		grip.transform = Transform3D(down.basis * gt.basis, gt.origin + down.origin)
	else:
		var rt := _relaxed_pose(1.0, swing, breath, amp, run)
		rt.origin += shift
		arm_r.transform = Transform3D(down.basis * rt.basis, rt.origin + down.origin)
