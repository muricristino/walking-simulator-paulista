extends Control

const UI := preload("res://scripts/ui.gd")
const SCREEN := Vector2(640, 480)

signal start_pressed
signal resume_pressed
signal restart_pressed
signal menu_pressed
signal explore_pressed

var page := ""
var back_to := ""
var pages := {}
var pause_time: Label
var arrival_time: Label
var arrival_best: Label
var title_best: Label
var blink := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UI.theme()
	_fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title()
	_pause()
	_options()
	_credits()
	_arrival()
	show_page("")


func _fill(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.position = Vector2.ZERO
	c.size = SCREEN


func show_page(p: String) -> void:
	page = p
	visible = p != ""
	for k in pages:
		pages[k].visible = k == p
	if p != "":
		var b := _first_button(pages[p])
		if b:
			b.grab_focus.call_deferred()


func _first_button(n: Node) -> Control:
	for c in n.get_children():
		if (c is Button or c is HSlider) and c.visible:
			return c
		var r := _first_button(c)
		if r:
			return r
	return null


func _input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE):
		return
	match page:
		"":
			if Game.state == Game.PLAYING and not Game.test_mode:
				open_pause()
				get_viewport().set_input_as_handled()
		"pause":
			resume_pressed.emit()
			get_viewport().set_input_as_handled()
		"options", "credits":
			show_page(back_to)
			get_viewport().set_input_as_handled()


func open_pause() -> void:
	Game.set_state(Game.PAUSED)
	show_page("pause")


func _process(dt: float) -> void:
	blink += dt
	if page == "arrival" and arrival_best and arrival_best.has_meta("record"):
		arrival_best.modulate.a = 1.0 if fmod(blink, 0.8) < 0.5 else 0.25


func set_run_time(t: float) -> void:
	if pause_time:
		pause_time.text = "TEMPO DE CAMINHADA  " + Game.clock(t)


func show_arrival(t: float, record: bool, prev_best: float) -> void:
	arrival_time.text = "TEMPO  " + Game.clock(t)
	if record:
		arrival_best.text = "NOVO RECORDE!" if prev_best < 0.0 else "NOVO RECORDE!  (antes " + Game.clock(prev_best) + ")"
		arrival_best.add_theme_color_override("font_color", UI.HOT)
		arrival_best.set_meta("record", true)
	else:
		arrival_best.text = "MELHOR  " + Game.clock(Game.best_time)
		arrival_best.add_theme_color_override("font_color", UI.DIM)
		arrival_best.modulate.a = 1.0
		arrival_best.remove_meta("record")
	show_page("arrival")


func _page(n: String, dim := 0.55) -> Control:
	var root := Control.new()
	_fill(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim > 0.0:
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, dim)
		_fill(bg)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bg)
	add_child(root)
	pages[n] = root
	return root


func _column(parent: Control, center: Vector2, width := 260.0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(width, 0)
	v.position = center - Vector2(width * 0.5, 0)
	v.size = Vector2(width, 0)
	parent.add_child(v)
	return v


func _panel(parent: Control, width := 300.0) -> VBoxContainer:
	var c := CenterContainer.new()
	_fill(c)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return v


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(cb)
	b.mouse_entered.connect(b.grab_focus)
	parent.add_child(b)
	return b


func _heading(parent: Control, text: String, size := 16, color := UI.INK) -> Label:
	var l := UI.label(text, size, color, UI.bold())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(l)
	return l


func _gap(parent: Control, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)


func _title() -> void:
	var root := _page("title", 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0.02, 0.01, 0.04, 0.9))
	g.add_point(0.45, Color(0, 0, 0, 0.15))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	var shade := TextureRect.new()
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	_fill(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 0.45)
	top.position = Vector2(0, 0)
	top.size = Vector2(640, 128)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var t := UI.label("CITY LOOK", 40, UI.HOT, UI.pixel())
	t.add_theme_color_override("font_shadow_color", Color(0.35, 0.05, 0.08))
	t.add_theme_constant_override("shadow_offset_x", 4)
	t.add_theme_constant_override("shadow_offset_y", 4)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(0, 36)
	t.size = Vector2(640, 48)
	root.add_child(t)
	var sub := UI.label("AV. PAULISTA  ·  SÃO PAULO  ·  ENTARDECER", 20, UI.INK)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 92)
	sub.size = Vector2(640, 20)
	root.add_child(sub)
	var col := _column(root, Vector2(320, 286), 200)
	_button(col, "INICIAR", func(): start_pressed.emit())
	_button(col, "OPÇÕES", func(): _open("options", "title"))
	_button(col, "CRÉDITOS", func(): _open("credits", "title"))
	_button(col, "SAIR", func(): get_tree().quit())
	var goal := UI.label("Objetivo: caminhar do MASP até a Alameda Rio Claro", 20, UI.DIM)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal.position = Vector2(0, 236)
	goal.size = Vector2(640, 20)
	root.add_child(goal)
	title_best = UI.label("", 20, UI.INK)
	title_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_best.position = Vector2(0, 446)
	title_best.size = Vector2(640, 20)
	root.add_child(title_best)
	root.visibility_changed.connect(func():
		title_best.text = "Melhor tempo: " + Game.clock(Game.best_time) if Game.best_time >= 0.0 else "Ainda sem tempo registrado")


func _pause() -> void:
	var root := _page("pause")
	var v := _panel(root, 280)
	_heading(v, "PAUSA", 16)
	pause_time = UI.label("", 20, UI.DIM)
	pause_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pause_time)
	_gap(v, 4)
	_button(v, "CONTINUAR", func(): resume_pressed.emit())
	_button(v, "REINICIAR", func(): restart_pressed.emit())
	_button(v, "OPÇÕES", func(): _open("options", "pause"))
	_button(v, "SAIR PARA O MENU", func(): menu_pressed.emit())
	_button(v, "SAIR DO JOGO", func(): get_tree().quit())


func _open(p: String, from: String) -> void:
	back_to = from
	show_page(p)


func _slider(parent: Control, text: String, lo: float, hi: float, step: float, value: float, fmt: Callable, cb: Callable) -> void:
	var l := UI.label("", 20, UI.INK)
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0, 14)
	s.focus_mode = Control.FOCUS_ALL
	s.mouse_entered.connect(s.grab_focus)
	parent.add_child(s)
	var upd := func(x: float):
		l.text = text + "  " + fmt.call(x)
	upd.call(value)
	s.value_changed.connect(func(x: float):
		upd.call(x)
		cb.call(x))


func _check(parent: Control, text: String, value: bool, cb: Callable) -> void:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = value
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(b.grab_focus)
	var upd := func(on: bool):
		b.text = text + ("  [X]" if on else "  [ ]")
	upd.call(value)
	b.toggled.connect(func(on: bool):
		upd.call(on)
		cb.call(on))
	parent.add_child(b)


func _options() -> void:
	var root := _page("options")
	var v := _panel(root, 320)
	_heading(v, "OPÇÕES", 16)
	_gap(v, 4)
	_slider(v, "Sensibilidade do mouse", 0.2, 3.0, 0.05, Game.mouse_sensitivity, func(x): return "%.2fx" % x, func(x):
		Game.mouse_sensitivity = x
		_changed())
	_slider(v, "Volume", 0.0, 1.0, 0.05, Game.volume, func(x): return "%d%%" % roundi(x * 100.0), func(x):
		Game.volume = x
		_changed())
	_slider(v, "Campo de visão", 50.0, 90.0, 1.0, Game.fov, func(x): return "%d°" % roundi(x), func(x):
		Game.fov = x
		_changed())
	_gap(v, 4)
	_check(v, "INVERTER EIXO Y", Game.invert_y, func(on):
		Game.invert_y = on
		_changed())
	_check(v, "TELA CHEIA", Game.fullscreen, func(on):
		Game.fullscreen = on
		_changed())
	_gap(v, 4)
	_button(v, "VOLTAR", func(): show_page(back_to))


func _changed() -> void:
	Game.apply()
	Game.save_settings()


func _credits() -> void:
	var root := _page("credits", 0.75)
	var v := _panel(root, 560)
	_heading(v, "CRÉDITOS", 16)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 330)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	v.add_child(sc)
	var l := UI.label(_credits_text(), 20, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(l)
	var b := _button(v, "VOLTAR", func(): show_page(back_to))
	b.gui_input.connect(func(e: InputEvent):
		if e is InputEventKey and e.pressed and e.physical_keycode in [KEY_UP, KEY_DOWN, KEY_W, KEY_S]:
			sc.scroll_vertical += 48 if e.physical_keycode in [KEY_DOWN, KEY_S] else -48
			b.accept_event())


func _credits_text() -> String:
	var out := "CITY LOOK — um passeio pela Av. Paulista ao entardecer.\n\n"
	var f := FileAccess.open("res://CREDITS.md", FileAccess.READ)
	if not f:
		return out + "Veja CREDITS.md."
	for line in f.get_as_text().split("\n"):
		var s := line.strip_edges()
		if s.begins_with("#"):
			s = s.lstrip("# ").to_upper()
			out += "\n" + s + "\n"
		elif s != "":
			out += s.replace("**", "") + "\n"
	return out


func _arrival() -> void:
	var root := _page("arrival", 0.45)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_fill(col)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	_heading(col, "VOCÊ CHEGOU À", 16)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cc)
	var plate := PanelContainer.new()
	var st := UI.box(UI.SIGN, Color(0.95, 0.95, 0.95), 3, 10)
	st.content_margin_left = 22
	st.content_margin_right = 22
	plate.add_theme_stylebox_override("panel", st)
	cc.add_child(plate)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	plate.add_child(sv)
	var street := UI.label("AL. RIO CLARO", 32, Color.WHITE, UI.bold())
	street.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	street.add_theme_constant_override("shadow_offset_x", 0)
	street.add_theme_constant_override("shadow_offset_y", 0)
	sv.add_child(street)
	var bairro := UI.label("BELA VISTA", 16, Color(0.85, 0.9, 1.0))
	bairro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(bairro)
	_gap(col, 4)
	arrival_time = _heading(col, "", 16)
	arrival_best = UI.label("", 16, UI.DIM, UI.bold())
	arrival_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(arrival_best)
	_gap(col, 8)
	var bc := CenterContainer.new()
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bc)
	var bv := VBoxContainer.new()
	bv.custom_minimum_size = Vector2(260, 0)
	bv.add_theme_constant_override("separation", 6)
	bc.add_child(bv)
	_button(bv, "CONTINUAR EXPLORANDO", func(): explore_pressed.emit())
	_button(bv, "JOGAR DE NOVO", func(): restart_pressed.emit())
	_button(bv, "VOLTAR AO MENU", func(): menu_pressed.emit())
