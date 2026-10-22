extends Node

signal state_changed(s: int)
signal settings_changed

enum { TITLE, PLAYING, PAUSED, ARRIVED }

const SETTINGS := "user://settings.cfg"
const SAVE := "user://save.cfg"
const TEST_ARGS := ["--autowalk", "--rio", "--at", "--shot", "--scenario"]

var state := TITLE
var test_mode := false
var skip_title := false
var mouse_sensitivity := 1.0
var invert_y := false
var fov := 64.0
var volume := 0.8
var fullscreen := false
var best_time := -1.0

var paused: bool:
	get:
		return state != PLAYING
var input_enabled: bool:
	get:
		return state == PLAYING


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	for a in TEST_ARGS:
		if args.has(a):
			test_mode = true
	_load()
	apply()
	get_tree().set_auto_accept_quit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()


func set_state(s: int) -> void:
	state = s
	get_tree().paused = s == PAUSED or s == ARRIVED
	_mouse()
	state_changed.emit(s)


func _process(_dt: float) -> void:
	_mouse()


func _mouse() -> void:
	if test_mode or not get_window().has_focus():
		return
	var want := Input.MOUSE_MODE_CAPTURED if state == PLAYING else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want


func apply() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	if not test_mode:
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		if fs != fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	settings_changed.emit()


func quit() -> void:
	var scene := get_tree().current_scene
	var audio: Variant = scene.get("audio") if scene else null
	if audio and audio.has_method("shutdown"):
		await audio.shutdown()
	get_tree().quit()


func save_settings() -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	c.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	c.set_value("controls", "invert_y", invert_y)
	c.set_value("video", "fov", fov)
	c.set_value("video", "fullscreen", fullscreen)
	c.set_value("audio", "volume", volume)
	c.save(SETTINGS)


func record(t: float) -> bool:
	if test_mode:
		return best_time < 0.0 or t < best_time
	var better := best_time < 0.0 or t < best_time
	if better:
		best_time = t
		var c := ConfigFile.new()
		c.load(SAVE)
		c.set_value("best", "rio_claro", t)
		c.save(SAVE)
	return better


func _load() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS) == OK:
		mouse_sensitivity = c.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
		invert_y = c.get_value("controls", "invert_y", invert_y)
		fov = c.get_value("video", "fov", fov)
		fullscreen = c.get_value("video", "fullscreen", fullscreen)
		volume = c.get_value("audio", "volume", volume)
	var s := ConfigFile.new()
	if s.load(SAVE) == OK:
		best_time = s.get_value("best", "rio_claro", -1.0)


static func clock(t: float) -> String:
	if t < 0.0:
		return "--:--.-"
	var m := int(t / 60.0)
	return "%d:%04.1f" % [m, t - m * 60.0]
