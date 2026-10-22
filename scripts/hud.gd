extends Node

const GOAL_TEXT := "Objetivo: chegar à Alameda Rio Claro"

var city: Node
var layer: CanvasLayer
var goal_label: Label
var goal_done := false
var goal_t := 0.0


func build(c: Node) -> void:
	city = c
	layer = CanvasLayer.new()
	add_child(layer)
	goal_label = Label.new()
	goal_label.text = GOAL_TEXT
	goal_label.add_theme_font_size_override("font_size", 26)
	goal_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	goal_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02))
	goal_label.add_theme_constant_override("outline_size", 6)
	goal_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_label.position = Vector2(-300, 14)
	goal_label.size = Vector2(600, 40)
	layer.add_child(goal_label)


func in_goal(p: Vector3) -> bool:
	return p.x < -38.0 and absf(p.z + 337.0) < 30.0


func _physics_process(dt: float) -> void:
	if not city or not city.player or not goal_label:
		return
	var p: Vector3 = city.player.global_position
	if not goal_done and in_goal(p):
		goal_done = true
		goal_t = 6.0
		goal_label.text = "Você chegou à Alameda Rio Claro!"
		goal_label.add_theme_font_size_override("font_size", 40)
	if goal_done and goal_t > 0.0:
		goal_t -= dt
		if goal_t <= 0.0:
			goal_label.text = "Alameda Rio Claro"
			goal_label.add_theme_font_size_override("font_size", 22)
