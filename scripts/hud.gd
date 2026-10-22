extends Node

const UI := preload("res://scripts/ui.gd")
const Menu := preload("res://scripts/menu.gd")
const GOAL_TEXT := "Chegar à Alameda Rio Claro"
const TARGET := Vector3(-42.0, 0.0, -337.0)
const NORTH_YAW := 125.0
const HINTS := "WASD ANDAR · SHIFT CORRER · ESPAÇO PULAR\nE CELULAR · TAB OBJETIVO · ESC PAUSA"

var city: Node
var layer: CanvasLayer
var menu: Menu
var goal_label: Label
var goal_box: Control
var dist_label: Label
var tip_label: Label
var time_label: Label
var hint_label: Label
var hint_box: PanelContainer
var banner: Label
var compass: Compass
var phone_vp: SubViewport
var phone_map: PhoneMap
var goal_done := false
var exploring := false
var run_time := 0.0
var goal_show := 8.0
var hint_show := 14.0
var start_pos := Vector3.ZERO
var start_yaw := 0.0
var title_t := 0.0
var best_d := INF
var stall := 0.0
var phone_t := 0.0
var banner_t := 0.0


func build(c: Node) -> void:
	city = c
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	root.theme = UI.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	compass = Compass.new()
	compass.hud = self
	compass.position = Vector2(320 - 120, 8)
	compass.size = Vector2(240, 22)
	root.add_child(compass)
	dist_label = _label(root, Vector2(0, 30), Vector2(640, 20), HORIZONTAL_ALIGNMENT_CENTER, 20, UI.INK)
	tip_label = _label(root, Vector2(0, 48), Vector2(640, 20), HORIZONTAL_ALIGNMENT_CENTER, 20, UI.HOT)
	time_label = _label(root, Vector2(520, 10), Vector2(110, 16), HORIZONTAL_ALIGNMENT_RIGHT, 16, UI.INK, UI.small())
	goal_box = PanelContainer.new()
	goal_box.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.02, 0.05, 0.7), Color(0.42, 0.34, 0.26), 1, 5))
	goal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gc := CenterContainer.new()
	gc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gc.position = Vector2(0, 74)
	gc.size = Vector2(640, 48)
	root.add_child(gc)
	gc.add_child(goal_box)
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 2)
	goal_box.add_child(gv)
	var gt := UI.label("OBJETIVO", 8, UI.HOT, UI.bold())
	gt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(gt)
	goal_label = UI.label(GOAL_TEXT, 20, UI.INK)
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(goal_label)
	hint_box = PanelContainer.new()
	hint_box.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.02, 0.05, 0.7), Color(0.42, 0.34, 0.26), 1, 6))
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_box)
	hint_label = UI.label(HINTS, 8, UI.INK, UI.small())
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_constant_override("line_spacing", 6)
	hint_box.add_child(hint_label)
	hint_box.reset_size()
	hint_box.position = Vector2(roundf(320 - hint_box.size.x * 0.5), 470 - hint_box.size.y)
	banner = _label(root, Vector2(0, 200), Vector2(640, 40), HORIZONTAL_ALIGNMENT_CENTER, 16, UI.HOT, UI.bold())
	banner.visible = false
	_phone()
	var ml := CanvasLayer.new()
	ml.layer = 10
	add_child(ml)
	menu = Menu.new()
	ml.add_child(menu)
	menu.start_pressed.connect(_start)
	menu.resume_pressed.connect(_resume)
	menu.restart_pressed.connect(_restart)
	menu.menu_pressed.connect(_to_menu)
	menu.explore_pressed.connect(_explore)
	Game.state_changed.connect(_on_state)
	start_pos = city.player.global_position
	start_yaw = city.player.rotation.y
	if Game.test_mode or Game.skip_title:
		Game.skip_title = false
		_start()
	else:
		Game.set_state(Game.TITLE)
		city.player.process_mode = Node.PROCESS_MODE_DISABLED
		city.player.hands.visible = false
		menu.show_page("title")


func _label(parent: Control, pos: Vector2, sz: Vector2, align: int, fsize: int, col: Color, font: Font = null) -> Label:
	var l := UI.label("", fsize, col, font)
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _on_state(s: int) -> void:
	layer.visible = s == Game.PLAYING


func _start() -> void:
	city.player.rotation.y = start_yaw
	city.player.process_mode = Node.PROCESS_MODE_INHERIT
	city.player.hands.visible = true
	menu.show_page("")
	run_time = 0.0
	goal_show = 8.0
	hint_show = 14.0
	Game.set_state(Game.PLAYING)


func _resume() -> void:
	menu.show_page("")
	Game.set_state(Game.PLAYING)


func _explore() -> void:
	exploring = true
	goal_label.text = "Explore à vontade · Esc abre o menu"
	goal_show = 6.0
	_resume()


func _restart() -> void:
	Game.skip_title = true
	_reload()


func _to_menu() -> void:
	Game.skip_title = false
	_reload()


func _reload() -> void:
	Game.set_state(Game.TITLE)
	get_tree().paused = false
	get_tree().reload_current_scene()


func in_goal(p: Vector3) -> bool:
	return p.x < -38.0 and absf(p.z + 337.0) < 30.0


func heading() -> float:
	return wrapf(NORTH_YAW - rad_to_deg(city.player.rotation.y), 0.0, 360.0)


func target_bearing() -> float:
	var d: Vector3 = TARGET - city.player.global_position
	return wrapf(NORTH_YAW - rad_to_deg(atan2(-d.x, -d.z)), 0.0, 360.0)


func _input(e: InputEvent) -> void:
	if Game.state != Game.PLAYING:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_TAB:
		goal_show = 5.0
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if not city or not city.player:
		return
	if Game.state == Game.TITLE:
		title_t += dt
		city.player.rotation.y = start_yaw + sin(title_t * 0.12) * 0.45
		return
	if Game.state != Game.PLAYING:
		return
	var p: Vector3 = city.player.global_position
	if not goal_done:
		run_time += dt
		if in_goal(p):
			_arrive()
	time_label.text = Game.clock(run_time)
	time_label.modulate = UI.HOT if goal_done else Color.WHITE
	var d := Vector2(p.x - TARGET.x, p.z - TARGET.z).length()
	if goal_done:
		dist_label.text = "AL. RIO CLARO" if in_goal(p) else "AL. RIO CLARO · %d m" % roundi(d)
		tip_label.text = ""
	else:
		dist_label.text = "AL. RIO CLARO · %d m" % roundi(d)
		if d < best_d - 4.0:
			best_d = d
			stall = 0.0
		else:
			stall += dt
		if p.x > 2.0 and d > 50.0:
			tip_label.text = "A Rio Claro fica do outro lado da avenida"
		elif stall > 20.0:
			tip_label.text = "Siga o marcador da bússola"
		else:
			tip_label.text = ""
	compass.nudge = stall > 20.0 and not goal_done
	goal_show -= dt
	goal_box.modulate.a = clampf(goal_show, 0.0, 1.0)
	hint_show -= dt
	if p.distance_to(start_pos) > 30.0:
		hint_show = minf(hint_show, 1.0)
	hint_box.modulate.a = clampf(hint_show, 0.0, 1.0)
	if banner_t > 0.0:
		banner_t -= dt
		banner.visible = banner_t > 0.0
	menu.set_run_time(run_time)
	phone_t -= dt
	if phone_t <= 0.0:
		phone_t = 0.2
		phone_map.queue_redraw()
		phone_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	compass.queue_redraw()


func _arrive() -> void:
	goal_done = true
	var prev := Game.best_time
	var rec := Game.record(run_time)
	goal_label.text = "Alameda Rio Claro · " + Game.clock(run_time)
	goal_show = 6.0
	_chime()
	if Game.test_mode:
		banner.text = "VOCÊ CHEGOU À\nALAMEDA RIO CLARO\n" + Game.clock(run_time)
		banner_t = 6.0
		banner.visible = true
		return
	Game.set_state(Game.ARRIVED)
	menu.show_arrival(run_time, rec, prev)


func _chime() -> void:
	var audio = city.get("audio")
	if not audio or not audio.has_method("play_ui"):
		return
	var rate := 22050
	var notes := [659.25, 830.61, 987.77, 1318.5]
	var n := int(rate * 1.1)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		for k in notes.size():
			var t0 := k * 0.11
			if t >= t0:
				var tt := t - t0
				v += sin(TAU * notes[k] * tt) * exp(-tt * 4.0) * 0.22
		v = clampf(round(v * 12.0) / 12.0, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	audio.play_ui(w, -6.0)


func _phone() -> void:
	phone_vp = SubViewport.new()
	phone_vp.size = Vector2i(56, 112)
	phone_vp.disable_3d = true
	phone_vp.transparent_bg = false
	phone_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(phone_vp)
	phone_map = PhoneMap.new()
	phone_map.hud = self
	phone_map.size = Vector2(56, 112)
	phone_vp.add_child(phone_map)


func phone_texture() -> Texture2D:
	return phone_vp.get_texture()


class Compass extends Control:
	var hud: Node
	var nudge := false
	const SPAN := 70.0
	const NAMES := {0: "N", 45: "NE", 90: "L", 135: "SE", 180: "S", 225: "SO", 270: "O", 315: "NO"}

	func _draw() -> void:
		var w := size.x
		var k := w / (SPAN * 2.0)
		var cx := w * 0.5
		var font: Font = UI.small()
		draw_rect(Rect2(0, 0, w, 16), Color(0.03, 0.02, 0.05, 0.72))
		draw_rect(Rect2(0, 0, w, 16), Color(0.42, 0.34, 0.26), false, 1.0)
		var h: float = hud.heading()
		var b0 := int(floor((h - SPAN) / 15.0)) * 15
		var b := b0
		while b <= h + SPAN:
			var x := cx + wrapf(b - h, -180.0, 180.0) * k
			if x > 2 and x < w - 2:
				var deg := posmod(b, 360)
				if NAMES.has(deg):
					var s: String = NAMES[deg]
					var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
					draw_string(font, Vector2(roundf(x - tw * 0.5), 12), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI.INK if deg % 90 == 0 else UI.DIM)
				else:
					draw_rect(Rect2(roundf(x), 6, 1, 4), UI.DIM)
			b += 15
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 3, 0), Vector2(cx + 4, 0), Vector2(cx, 4)]), UI.INK)
		if hud.goal_done and hud.in_goal(hud.city.player.global_position):
			return
		var rel := wrapf(hud.target_bearing() - h, -180.0, 180.0)
		var on := true
		if nudge:
			on = fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.4
		var col := UI.HOT if on else UI.INK
		if absf(rel) <= SPAN - 4.0:
			var x := roundf(cx + rel * k)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 5, 17), Vector2(x + 6, 17), Vector2(x, 22)]), col)
			draw_rect(Rect2(x - 1, 1, 2, 14), col)
		else:
			var s := signf(rel)
			var x := w + 3.0 if s > 0 else -3.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 2), Vector2(x, 14), Vector2(x + 7 * s, 8)]), col)


class PhoneMap extends Control:
	var hud: Node
	const X0 := -200.0
	const X1 := 60.0
	const Z0 := -430.0
	const Z1 := 60.0

	func _map(p: Vector3) -> Vector2:
		return Vector2((p.x - X0) / (X1 - X0) * size.x, (p.z - Z0) / (Z1 - Z0) * size.y)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.16))
		var road := Color(0.45, 0.45, 0.5)
		var a := _map(Vector3(-16, 0, Z1))
		var b := _map(Vector3(16, 0, Z0))
		draw_rect(Rect2(a.x, b.y, b.x - a.x, a.y - b.y), road)
		for z in [-150.0, -380.0]:
			var c := _map(Vector3(X0, 0, z - 6))
			var d := _map(Vector3(X1, 0, z + 6))
			draw_rect(Rect2(c.x, c.y, d.x - c.x, d.y - c.y), Color(0.3, 0.3, 0.34))
		var r0 := _map(Vector3(-200, 0, -341))
		var r1 := _map(Vector3(-16, 0, -333))
		draw_rect(Rect2(r0.x, r0.y, r1.x - r0.x, r1.y - r0.y), Color(0.35, 0.6, 0.35))
		var m0 := _map(Vector3(-40, 0, -131))
		var m1 := _map(Vector3(-18, 0, -53))
		draw_rect(Rect2(m0.x, m0.y, m1.x - m0.x, m1.y - m0.y), Color(0.75, 0.15, 0.12))
		var t := _map(TARGET)
		draw_rect(Rect2(t.x - 2, t.y - 2, 5, 5), UI.HOT)
		var pl: Node3D = hud.city.player
		var p := _map(pl.global_position)
		p = p.clamp(Vector2(2, 2), size - Vector2(2, 2))
		var f := Vector2(-sin(pl.rotation.y), -cos(pl.rotation.y))
		draw_line(p, p + f * 6.0, Color.WHITE, 1.0)
		draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), Color(1, 0.3, 0.3))
