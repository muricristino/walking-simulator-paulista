extends RefCounted

const Geo := preload("res://scripts/geo.gd")
const Tex := preload("res://scripts/tex.gd")
const Layout := preload("res://scripts/layout.gd")

const CYCLE := 50.0
const GREEN_END := 24.0
const AMBER_END := 27.0
const WALK_START := 29.0
const WALK_END := 44.0
const BLINK_END := 48.0
const GREEN := 0
const AMBER := 1
const RED := 2
const GROUPS := ["c_red", "c_amber", "c_green", "p_red", "p_green"]

var city: Node
var clock := 0.0
var list := []
var _on := {}
var _off := {}


func build(c: Node) -> void:
	city = c
	var poles := Geo.new()
	poles.add_mat("dark", city.M.dark)
	var white := Tex.flat(Color(0.85, 0.85, 0.85), 8, 0.03, 0.2, 61)
	var emit := {"c_red": Color(2.0, 0.08, 0.05), "c_amber": Color(1.9, 0.9, 0.05), "c_green": Color(0.1, 1.6, 0.6), "p_red": Color(2.0, 0.35, 0.08), "p_green": Color(0.25, 1.7, 0.7)}
	for g in GROUPS:
		_on[g] = city.mat(white, Color.WHITE, null, 0.0, emit[g], 1.0)
		var dim: Color = emit[g] * 0.08
		_off[g] = city.mat(white, Color(0.1, 0.1, 0.1) + Color(dim.r, dim.g, dim.b, 0.0))
	var offs := [0.0, 14.0, 30.0, 40.0, 7.0, 22.0]
	var specs := zones()
	for i in specs.size():
		var sp: Dictionary = specs[i]
		sp["offset"] = offs[i % offs.size()]
		sp["pos"] = [Vector3(16.6, 0, float(sp.zhi) + 1.0), Vector3(-16.6, 0, float(sp.zlo) - 1.0)]
	for s in specs:
		var g := Geo.new()
		for k in GROUPS:
			g.add_mat(k, _off[k])
		for p in s.pos:
			var facing := 1.0 if p.x > 0 else -1.0
			_pole(poles, p.x, p.z)
			_heads(g, p.x, p.z, facing)
			_ped_head(poles, g, p.x, p.z)
		var holder := Node3D.new()
		holder.name = "Signal%d" % int(-s.z)
		city.world.add_child(holder)
		g.build(holder)
		var mis := {}
		for k in GROUPS:
			mis[k] = holder.get_node_or_null(k)
		var e: Dictionary = s.duplicate()
		e.erase("pos")
		e["nodes"] = mis
		e["state"] = -1
		list.append(e)
	var ph := Node3D.new()
	ph.name = "SignalPoles"
	city.world.add_child(ph)
	poles.build(ph)
	update(0.0)


static func zones() -> Array:
	var cm := (Layout as Script).get_script_constant_map()
	var h: float = cm.get("CROSS_HALF", 9.0)
	var walks := []
	if cm.has("CROSS_HALF"):
		walks = (Layout as Script).callv("crosswalks", [])
	else:
		var zm: float = cm.get("MASP_CROSSWALK_Z", -48.0)
		walks.append({"z": zm, "z0": zm - 3.0, "z1": zm + 3.0})
		for c in Layout.CROSS:
			walks.append({"z": c, "z0": c - 3.0, "z1": c + 3.0})
	var out := []
	for w in walks:
		var lo: float = w.z0
		var hi: float = w.z1
		for c in Layout.CROSS:
			if c + h > lo - 6.0 and c - h < hi + 6.0:
				lo = minf(lo, c - h)
				hi = maxf(hi, c + h)
		out.append({"z": float(w.z), "half": (float(w.z1) - float(w.z0)) * 0.5, "walk0": float(w.z0), "walk1": float(w.z1), "zlo": lo, "zhi": hi})
	return out


func _pole(g: Geo, x: float, z: float) -> void:
	var sx := signf(x)
	g.box("dark", Vector3(x, 3.0, z), Vector3(0.2, 6.0, 0.2), Vector2(1, 4))
	city.solid(Vector3(x, 3.0, z), Vector3(0.25, 6.0, 0.25))
	g.box("dark", Vector3(x - sx * 3.0, 5.9, z), Vector3(6.0, 0.15, 0.15), Vector2(1, 1))
	for hx in [x - sx * 5.5, x]:
		var by: float = 5.0 if hx != x else 3.2
		g.box("dark", Vector3(hx, by, z), Vector3(0.38, 1.1, 0.3), Vector2(1, 1))


func _heads(g: Geo, x: float, z: float, facing: float) -> void:
	var sx := signf(x)
	for hx in [x - sx * 5.5, x]:
		var by: float = 5.0 if hx != x else 3.2
		var fz := z + facing * 0.17
		g.box("c_red", Vector3(hx, by + 0.34, fz), Vector3(0.25, 0.25, 0.07), Vector2(1, 1))
		g.box("c_amber", Vector3(hx, by, fz), Vector3(0.25, 0.25, 0.07), Vector2(1, 1))
		g.box("c_green", Vector3(hx, by - 0.34, fz), Vector3(0.25, 0.25, 0.07), Vector2(1, 1))


func _ped_head(poles: Geo, g: Geo, x: float, z: float) -> void:
	var sx := signf(x)
	poles.box("dark", Vector3(x - sx * 0.25, 2.55, z), Vector3(0.22, 0.66, 0.3), Vector2(1, 1))
	g.box("p_red", Vector3(x - sx * 0.37, 2.72, z), Vector3(0.04, 0.24, 0.24), Vector2(1, 1))
	g.box("p_green", Vector3(x - sx * 0.37, 2.4, z), Vector3(0.04, 0.24, 0.24), Vector2(1, 1))


func phase(e: Dictionary) -> float:
	return fposmod(clock + float(e.offset), CYCLE)


func car_state_of(e: Dictionary) -> int:
	var t := phase(e)
	if t < GREEN_END:
		return GREEN
	if t < AMBER_END:
		return AMBER
	return RED


func walk_of(e: Dictionary) -> bool:
	var t := phase(e)
	return t >= WALK_START and t < WALK_END


func walk_left_of(e: Dictionary) -> float:
	var t := phase(e)
	return WALK_END - t if t >= WALK_START and t < WALK_END else 0.0


func find(z: float, tol := 8.0) -> Dictionary:
	var best := {}
	var bd := tol
	for e in list:
		var d := absf(float(e.z) - z)
		if d <= bd:
			bd = d
			best = e
	return best


func update(dt: float) -> void:
	clock += dt
	for e in list:
		var t := phase(e)
		var cs := car_state_of(e)
		var walk := walk_of(e)
		var blink := t >= WALK_END and t < BLINK_END and fmod(t, 0.8) < 0.4
		var st := cs * 4 + (2 if walk else 0) + (1 if blink else 0)
		if st == e.state:
			continue
		e.state = st
		var n: Dictionary = e.nodes
		_lamp(n.c_red, cs == RED, "c_red")
		_lamp(n.c_amber, cs == AMBER, "c_amber")
		_lamp(n.c_green, cs == GREEN, "c_green")
		_lamp(n.p_green, walk, "p_green")
		_lamp(n.p_red, not walk and not blink, "p_red")


func _lamp(mi: MeshInstance3D, on: bool, g: String) -> void:
	if mi:
		mi.material_override = _on[g] if on else _off[g]
