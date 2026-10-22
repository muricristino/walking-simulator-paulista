extends RefCounted

const PS1 := preload("res://scripts/ps1.gdshader")
const DIR := "res://assets/buildings/"

const STYLES := {
	"glass": {"tile": Vector2(16, 16)},
	"glass2": {"tile": Vector2(16, 16)},
	"brick": {"tile": Vector2(18, 18)},
	"pillar": {"tile": Vector2(18, 18)},
	"brise": {"tile": Vector2(14, 14)},
	"conjunto": {"tile": Vector2(30, 24)},
	"safra": {"photo": true},
	"fiesp": {"photo": true},
	"gazeta": {"photo": true},
	"center3": {"photo": true},
}
const COMMON := ["glass", "glass2", "brick", "pillar", "brise", "conjunto"]

var mats := {}
var roof: ShaderMaterial
var glow := 0.3


func _tex(path: String) -> ImageTexture:
	return ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))


func _mat(style: String) -> ShaderMaterial:
	if mats.has(style):
		return mats[style]
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter("tex", _tex(DIR + style + "_c.png"))
	m.set_shader_parameter("glow_tex", _tex(DIR + style + "_e.png"))
	m.set_shader_parameter("glow", glow)
	mats[style] = m
	return m


func set_glow(g: float) -> void:
	glow = g
	for k in mats:
		mats[k].set_shader_parameter("glow", g * (1.6 if k == "fiesp" else 1.0))


func build(path: String, roof_mat: Material) -> Node3D:
	roof = roof_mat
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var tools := {}
	var root := Node3D.new()
	for b in data.buildings:
		var style: String = b.style
		if style == "":
			var seed: int = b.seed
			style = COMMON[seed % COMMON.size()]
			if b.h < 20.0 and style.begins_with("glass"):
				style = "brick"
		if not tools.has(style):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[style] = st
		if not tools.has("roof"):
			var rt := SurfaceTool.new()
			rt.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools["roof"] = rt
		_extrude(tools[style], tools["roof"], b.p, b.h, style)
	for k in tools:
		var mi := MeshInstance3D.new()
		mi.mesh = tools[k].commit()
		mi.material_override = roof if k == "roof" else _mat(k)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


func _extrude(st: SurfaceTool, rt: SurfaceTool, pts: Array, h: float, style: String) -> void:
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(Vector2(p[0], p[1]))
	var area := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	var spec: Dictionary = STYLES[style]
	var photo: bool = spec.get("photo", false)
	var tile: Vector2 = spec.get("tile", Vector2(16, 16))
	var per := 0.0
	for i in poly.size():
		per += poly[i].distance_to(poly[(i + 1) % poly.size()])
	var u := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var len := a.distance_to(b)
		if len < 0.01:
			continue
		var d := (b - a) / len
		var n := Vector3(d.y, 0, -d.x) if area > 0.0 else Vector3(-d.y, 0, d.x)
		var u0 := u
		var u1 := u + len
		u = u1
		var uv0: Vector2
		var uv1: Vector2
		if photo:
			uv0 = Vector2(u0 / per * 4.0, 0.0)
			uv1 = Vector2(u1 / per * 4.0, 1.0)
		else:
			uv0 = Vector2(u0 / tile.x, -h / tile.y)
			uv1 = Vector2(u1 / tile.x, 0.0)
		var A := Vector3(a.x, 0, a.y)
		var B := Vector3(b.x, 0, b.y)
		var At := A + Vector3(0, h, 0)
		var Bt := B + Vector3(0, h, 0)
		var vs := [At, Bt, B, At, B, A]
		var uvs := [Vector2(uv0.x, uv0.y), Vector2(uv1.x, uv0.y), Vector2(uv1.x, uv1.y), Vector2(uv0.x, uv0.y), Vector2(uv1.x, uv1.y), Vector2(uv0.x, uv1.y)]
		for k in 6:
			st.set_normal(n)
			st.set_uv(uvs[k])
			st.add_vertex(vs[k])
	var idx := Geometry2D.triangulate_polygon(poly)
	for k in idx.size():
		var p := poly[idx[k]]
		rt.set_normal(Vector3.UP)
		rt.set_uv(p / 6.0)
		rt.add_vertex(Vector3(p.x, h, p.y))
