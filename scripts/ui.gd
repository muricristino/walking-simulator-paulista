extends RefCounted

const INK := Color(1.0, 0.93, 0.72)
const DIM := Color(0.72, 0.66, 0.55)
const HOT := Color(1.0, 0.62, 0.22)
const SHADE := Color(0.05, 0.03, 0.06)
const PANEL := Color(0.06, 0.05, 0.1, 0.86)
const SIGN := Color(0.07, 0.22, 0.55)

static var _pixel: FontFile
static var _term: FontFile
static var _small: FontFile
static var _bold: FontFile
static var _theme: Theme


static func _crisp(path: String) -> FontFile:
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	return f


static func pixel() -> FontFile:
	if not _pixel:
		_pixel = _crisp("res://assets/ui/PressStart2P-Regular.ttf")
	return _pixel


static func small() -> FontFile:
	if not _small:
		_small = _crisp("res://assets/ui/Silkscreen-Regular.ttf")
	return _small


static func bold() -> FontFile:
	if not _bold:
		_bold = _crisp("res://assets/ui/Silkscreen-Bold.ttf")
	return _bold


static func term() -> FontFile:
	if not _term:
		_term = _crisp("res://assets/ui/VT323-Regular.ttf")
	return _term


static func box(bg: Color, border: Color, w := 2, pad := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(w)
	s.set_content_margin_all(pad)
	s.anti_aliasing = false
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = term()
	t.default_font_size = 20
	t.set_color("font_color", "Label", INK)
	t.set_color("font_shadow_color", "Label", SHADE)
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_font("font", "Button", small())
	t.set_font_size("font_size", "Button", 16)
	t.set_color("font_color", "Button", DIM)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_focus_color", "Button", SHADE)
	t.set_color("font_pressed_color", "Button", SHADE)
	t.set_color("font_hover_pressed_color", "Button", SHADE)
	t.set_stylebox("normal", "Button", box(Color(0.03, 0.02, 0.05, 0.78), Color(0.36, 0.3, 0.24), 1, 4))
	t.set_stylebox("hover", "Button", box(Color(0.2, 0.14, 0.1, 0.9), HOT, 1, 4))
	t.set_stylebox("focus", "Button", box(HOT, INK, 1, 4))
	t.set_stylebox("pressed", "Button", box(INK, HOT, 1, 4))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, Color(0.42, 0.34, 0.26), 2, 12))
	t.set_stylebox("slider", "HSlider", box(Color(0, 0, 0, 0.6), Color(0.3, 0.26, 0.22), 1, 2))
	t.set_stylebox("grabber_area", "HSlider", box(HOT, HOT, 0, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(INK, INK, 0, 2))
	t.set_stylebox("focus", "HSlider", box(Color(0, 0, 0, 0), INK, 1, 2))
	var g := Image.create(8, 12, false, Image.FORMAT_RGBA8)
	g.fill(INK)
	g.fill_rect(Rect2i(1, 1, 6, 10), HOT)
	var gt := ImageTexture.create_from_image(g)
	t.set_icon("grabber", "HSlider", gt)
	t.set_icon("grabber_highlight", "HSlider", gt)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	_theme = t
	return t


static func label(text: String, size := 20, color := INK, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	return l
