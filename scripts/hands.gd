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
var custom_screen: Texture2D
var screen_img: Image
var screen_tex: ImageTexture
var screen_t := 0.0
var phone_target := Vector3(-42.0, 0.0, -337.0)
var phone_target_on := true
var rest := Vector3(0.22, -0.29, -0.46)
var aim := Vector2(0.05, 0.45)
var turn := -20.0


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


const DIGITS := [31599, 11415, 29671, 29647, 23497, 31183, 31215, 29257, 31727, 31695]
const SW := 24
const SH := 50


func _screen_tex() -> ImageTexture:
	screen_img = Image.create(SW, SH, false, Image.FORMAT_RGB8)
	screen_tex = ImageTexture.create_from_image(screen_img)
	_screen_draw()
	return screen_tex


func _px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < SW and y < SH:
		screen_img.set_pixel(x, y, c)


func _glyph(bits: int, x: int, y: int, c: Color) -> void:
	for r in 5:
		for col in 3:
			if bits & (1 << (14 - (r * 3 + col))):
				_px(x + col, y + r, c)


func _text_w(s: String) -> int:
	return s.length() * 4 - 1 + s.count("m") * 2


func _text(s: String, x: int, y: int, c: Color) -> void:
	for ch in s:
		if ch >= "0" and ch <= "9":
			_glyph(DIGITS[ch.unicode_at(0) - 48], x, y, c)
		elif ch == ":":
			_px(x + 1, y + 1, c)
			_px(x + 1, y + 3, c)
		elif ch == "m":
			for r in range(1, 5):
				_px(x, y + r, c)
				_px(x + 2, y + r, c)
				_px(x + 4, y + r, c)
			_px(x + 1, y + 1, c)
			_px(x + 3, y + 1, c)
			x += 2
		elif ch == "k":
			_glyph(19373, x, y, c)
		elif ch == ".":
			_px(x + 1, y + 4, c)
		x += 4


func _screen_draw() -> void:
	var top := Color(0.08, 0.1, 0.22)
	var bot := Color(0.16, 0.2, 0.36)
	for y in SH:
		var c := top.lerp(bot, float(y) / SH)
		for x in SW:
			screen_img.set_pixel(x, y, c)
	var tm := Time.get_time_dict_from_system()
	var clock := "%02d:%02d" % [tm.hour, tm.minute]
	_text(clock, (SW - _text_w(clock)) / 2, 2, Color(0.95, 0.95, 1.0))
	for x in range(2, SW - 2):
		_px(x, 9, Color(0.3, 0.34, 0.5))
	var cam := get_parent() as Node3D
	if not cam or not cam.is_inside_tree() or not phone_target_on:
		return
	var p := cam.global_position
	var to := phone_target - p
	to.y = 0.0
	var dist := to.length()
	var cx := SW / 2
	var cy := 23
	var ring := Color(0.42, 0.48, 0.66)
	for i in 48:
		var a := TAU * i / 48.0
		_px(cx + roundi(cos(a) * 9.0), cy + roundi(sin(a) * 9.0), ring)
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	var yaw := atan2(fwd.x, -fwd.z)
	var nx := sin(-yaw)
	var ny := -cos(-yaw)
	_px(cx + roundi(nx * 9.0), cy + roundi(ny * 9.0), Color(0.95, 0.3, 0.3))
	_px(cx + roundi(nx * 8.0), cy + roundi(ny * 8.0), Color(0.95, 0.3, 0.3))
	if dist < 15.0:
		var ok := Color(0.4, 0.95, 0.5)
		for q in [Vector2i(-4, 0), Vector2i(-3, 1), Vector2i(-2, 2), Vector2i(-1, 3), Vector2i(0, 2), Vector2i(1, 1), Vector2i(2, 0), Vector2i(3, -1), Vector2i(4, -2), Vector2i(5, -3)]:
			_px(cx + q.x, cy + q.y, ok)
			_px(cx + q.x, cy + q.y + 1, ok)
	else:
		var ang := atan2(to.x, -to.z) - yaw
		var dir := Vector2(sin(ang), -cos(ang))
		var arrow := Color(1.0, 0.78, 0.25)
		for i in 15:
			var f := -6.0 + i * 0.95
			_px(cx + roundi(dir.x * f), cy + roundi(dir.y * f), arrow)
		var side := Vector2(-dir.y, dir.x)
		for i in 5:
			var b := dir * (7.0 - i) + side * i * 0.8
			var b2 := dir * (7.0 - i) - side * i * 0.8
			_px(cx + roundi(b.x), cy + roundi(b.y), arrow)
			_px(cx + roundi(b2.x), cy + roundi(b2.y), arrow)
	var label := "%dm" % roundi(dist) if dist < 1000.0 else "%.1fk" % (dist / 1000.0)
	_text(label, (SW - _text_w(label)) / 2, 37, Color(1, 1, 1))
	var pin := Color(0.95, 0.35, 0.4)
	for q in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(0, 2)]:
		_px(cx + q.x, 45 + q.y, pin)


func _screen_update(dt: float) -> void:
	if custom_screen:
		return
	screen_t -= dt
	if screen_t > 0.0:
		return
	screen_t = 0.1
	_screen_draw()
	screen_tex.update(screen_img)


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
	var flex := deg_to_rad(16.0)
	var hd := Vector3(0, -sin(flex), -cos(flex))
	var hu := Vector3(0, cos(flex), -sin(flex))
	var w := Vector3(0, 0, -0.262)
	_sleeve(g, Vector3(0, 0, -0.14), w, Vector3.RIGHT, m)
	_obox(g, "skin", Vector3(0, 0, -0.2), w + hd * 0.004, 0.054, 0.044, 0.06, 0.038)
	var k := w + hd * 0.088
	_obox(g, "skin", w - hd * 0.004, k, 0.072, 0.032, 0.08, 0.026, Vector3.RIGHT)
	_obox(g, "knuckle", k - hd * 0.006, k + hd * 0.01, 0.08, 0.026, 0.078, 0.024, Vector3.RIGHT)
	var fx := [-0.028, -0.009, 0.01, 0.028]
	var pl := [0.04, 0.045, 0.042, 0.032]
	var dl := [0.032, 0.035, 0.033, 0.026]
	var fw := [0.018, 0.019, 0.018, 0.015]
	for i in 4:
		var base: Vector3 = (k + hd * 0.006 + Vector3(fx[i], 0, 0)) * x
		var a1 := deg_to_rad(12.0 + i * 5.0)
		var a2 := deg_to_rad(30.0 + i * 7.0)
		var d1 := (hd * cos(a1) - hu * sin(a1) + Vector3(fx[i] * 0.6 * m, 0, 0)).normalized()
		var d2 := (hd * cos(a1 + a2) - hu * sin(a1 + a2)).normalized()
		var j: Vector3 = base + d1 * pl[i]
		var tip: Vector3 = j + d2 * dl[i]
		_obox(g, "skin", base, j, fw[i], 0.017, fw[i] * 0.95, 0.016, Vector3.RIGHT)
		_obox(g, "skin", j, tip, fw[i] * 0.92, 0.015, fw[i] * 0.82, 0.013, Vector3.RIGHT)
	var t0 := (w + hd * 0.02 + Vector3(-0.034, -0.012, 0)) * x
	var t1 := (w + hd * 0.06 + Vector3(-0.05, -0.03, 0)) * x
	var t2 := (w + hd * 0.09 + Vector3(-0.046, -0.05, 0)) * x
	_obox(g, "skin", t0, t1, 0.025, 0.023, 0.022, 0.02, Vector3.UP)
	_obox(g, "skin", t1, t2, 0.021, 0.019, 0.018, 0.016, Vector3.UP)
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


func set_phone(on: bool) -> void:
	phone_on = on


func is_phone_up() -> bool:
	return phone >= 0.5


func set_phone_screen(tex: Texture2D) -> void:
	custom_screen = tex
	mats.screen.set_shader_parameter("tex", tex if tex else screen_tex)


func set_phone_target(p: Vector3, on := true) -> void:
	phone_target = p
	phone_target_on = on


func _arm_pose(m: float, swing: float, breath: float, run: float, low: float) -> Transform3D:
	var w := Vector3(rest.x * m, rest.y - run * 0.02 - low, rest.z)
	w.z -= swing * 0.045
	w.y += swing * 0.012 + breath * 0.003
	w.x += absf(swing) * 0.004 * m
	var d := Vector3(aim.x * m, aim.y + run * 0.15 + swing * 0.25, -1.0).normalized()
	var b := Basis.looking_at(d, Vector3.UP)
	b = Basis(d, deg_to_rad(turn * m + swing * 4.0 + breath * 0.6)) * b
	return Transform3D(b, w - d * 0.262)


func _in_view(xf: Transform3D) -> bool:
	var a := xf * Vector3(0, 0, -0.08)
	var b := xf * Vector3(0, 0, -0.38)
	return a.z < -0.08 and b.y > b.z * 1.2


func _grip_pose(swing: float, breath: float) -> Transform3D:
	var pos := Vector3(0.035, -0.07, -0.3)
	pos.y += breath * 0.003 + swing * 0.004
	pos.x += swing * 0.004
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(-14.0 + breath * 0.5), deg_to_rad(-8.0), deg_to_rad(-6.0))), pos)


func animate(dt: float, phase: float, amp: float, run: float, air: float, look_vel: Vector2, pitch := 0.0) -> void:
	t += dt
	phone = move_toward(phone, 1.0 if phone_on else 0.0, dt * 2.4)
	lag = lag.lerp(look_vel.clamp(Vector2(-6, -6), Vector2(6, 6)) * 0.004, 1.0 - exp(-10.0 * dt))
	var breath := sin(t * 1.7) * (1.0 - clampf(amp, 0.0, 1.0) * 0.6)
	var swing := sin(phase) * clampf(amp, 0.0, 1.2) * (0.7 + run * 0.6)
	var bounce := Vector3(0, -cos(phase * 2.0) * 0.006 * amp + air, 0)
	var shift := Vector3(-lag.x, lag.y, 0) + bounce
	var k := 0.9 if pitch > 0.0 else 0.3
	var tilt := Transform3D(Basis(Vector3.RIGHT, -pitch * k), Vector3.ZERO)
	var lt := _arm_pose(-1.0, swing, breath, run, smoothstep(0.0, 1.0, phone) * 0.05)
	lt.origin += shift
	arm_l.transform = tilt * lt
	arm_l.visible = _in_view(arm_l.transform)
	var drop := smoothstep(0.0, 0.5, phone) if phone < 0.5 else 1.0 - smoothstep(0.5, 1.0, phone)
	var down := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-25.0 * drop)), Vector3(0.05, -0.42, 0.06) * drop)
	var holding := phone >= 0.5
	grip.visible = holding
	if holding:
		var gt := _grip_pose(swing * 0.3, breath)
		gt.origin += shift * 0.6
		grip.transform = Transform3D(down.basis * gt.basis, gt.origin + down.origin)
		_screen_update(dt)
	else:
		var rt := _arm_pose(1.0, -swing, breath, run, 0.0)
		rt.origin += shift
		rt = tilt * rt
		arm_r.transform = Transform3D(down.basis * rt.basis, rt.origin + down.origin)
	arm_r.visible = not holding and _in_view(arm_r.transform)
