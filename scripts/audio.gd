extends Node

const Surface := preload("res://scripts/audio_surface.gd")
const Layout := preload("res://scripts/layout.gd")
const DIR := "res://assets/audio/"
const KINDS: Array[StringName] = [&"concrete", &"asphalt", &"paver", &"wood", &"grass"]
const STEP_DB := {&"concrete": -11.0, &"asphalt": -11.0, &"paver": -10.0, &"wood": -9.0, &"grass": -12.0}
const ENGINE_VOICES := 8
const NPC_VOICES := 6
const MASP := Rect2(-57.0, -131.0, 28.0, 78.0)
const TRIANON := Rect2(30.0, -131.0, 62.0, 78.0)
const AVENUE_Z := Layout.WALK_Z
const BUSES := [&"Ambience", &"SFX", &"UI"]

var city: Node
var debug := false
var surface := Surface.new()
var S := {}
var steps := {}
var beds := {}
var bed_db := {}
var engines := []
var tracked := {}
var npc_pool: Array[AudioStreamPlayer3D] = []
var npc_next := 0
var walker_last := {}
var walker_odo := {}
var birds: Array[AudioStreamPlayer3D] = []
var crowds: Array[AudioStreamPlayer3D] = []
var signals: Array[AudioStreamPlayer3D] = []
var flybys := []
var step_mode := ""
var own_steps: AudioStreamPlayer
var cur_kind := &""
var last_feet := Vector3.INF
var odo := 0.0
var was_grounded := true
var last_step_pos := 0.0
var phone_was := false
var goal_was := false
var reverb: AudioEffectReverb
var reverb_wet := 0.04
var t := 0.0
var assign_t := 0.0
var kind_t := 0.0
var horn_t := 12.0
var siren_t := 45.0
var heli_t := 100.0
var bird_t := 5.0
var beep_t := 0.0
var log_t := 0.0
var bump_cd := 0.0
var cache_t := 0.0
var vehicles := []
var external_honk := false
var rng := RandomNumberGenerator.new()
var counts := {}
var mix := {}
var closed := false


func build(c: Node) -> void:
	city = c
	rng.seed = 5150
	var args := OS.get_cmdline_user_args()
	debug = args.has("--audio-debug")
	_ensure_buses()
	set_lofi(args.has("--lofi"))
	_load()
	surface.setup(city)
	_beds()
	_birds()
	_crowds()
	_signals()
	_engines()
	_npc_pool()
	_hook_player()
	_hook_traffic()
	_hook_ui()
	if debug:
		print("[A] build buses=%s streams=%d beds=%d birds=%d crowds=%d signals=%d step_mode=%s honk=%s" % [_bus_desc(), S.size(), beds.size(), birds.size(), crowds.size(), signals.size(), step_mode, external_honk])


func play_at(stream: AudioStream, pos: Vector3, volume_db := 0.0, bus := &"SFX", unit := 10.0, max_dist := 0.0) -> AudioStreamPlayer3D:
	if not stream or closed:
		return null
	var p := _p3d(stream, volume_db, bus, unit, max_dist)
	p.position = pos
	p.finished.connect(p.queue_free)
	city.world.add_child(p)
	p.play()
	return p


func attach(node: Node3D, stream: AudioStream, volume_db := 0.0, bus := &"SFX") -> AudioStreamPlayer3D:
	var p := _p3d(stream, volume_db, bus, 10.0, 0.0)
	node.add_child(p)
	return p


func play_ui(stream: AudioStream, volume_db := 0.0, bus := &"UI") -> AudioStreamPlayer:
	if not stream or closed:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.bus = bus
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()
	return p


func set_lofi(on: bool) -> void:
	var m := AudioServer.get_bus_index(&"Master")
	for i in AudioServer.get_bus_effect_count(m):
		if AudioServer.get_bus_effect(m, i) is AudioEffectDistortion:
			AudioServer.set_bus_effect_enabled(m, i, on)


func stream(name: String) -> AudioStream:
	return S.get(name)


func step_stream(kind: StringName) -> AudioStream:
	return steps.get(kind, steps.get(&"concrete"))


func _p3d(stream: AudioStream, volume_db: float, bus: StringName, unit: float, max_dist: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.bus = bus
	p.unit_size = unit
	p.max_distance = max_dist
	p.attenuation_filter_cutoff_hz = 4000.0
	p.attenuation_filter_db = -16.0
	p.max_db = 3.0
	return p


func _ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, &"Master")
	var sfx := AudioServer.get_bus_index(&"SFX")
	for i in AudioServer.get_bus_effect_count(sfx):
		if AudioServer.get_bus_effect(sfx, i) is AudioEffectReverb:
			reverb = AudioServer.get_bus_effect(sfx, i)
	if not reverb:
		reverb = AudioEffectReverb.new()
		reverb.wet = 0.04
		reverb.room_size = 0.55
		AudioServer.add_bus_effect(sfx, reverb)


func _bus_desc() -> String:
	var out := []
	for i in AudioServer.bus_count:
		var fx := []
		for e in AudioServer.get_bus_effect_count(i):
			fx.append("%s%s" % [AudioServer.get_bus_effect(i, e).get_class().trim_prefix("AudioEffect"), "" if AudioServer.is_bus_effect_enabled(i, e) else "(off)"])
		out.append("%s:%.0fdB>%s[%s]" % [AudioServer.get_bus_name(i), AudioServer.get_bus_volume_db(i), AudioServer.get_bus_send(i), ",".join(fx)])
	return " ".join(out)


func _load() -> void:
	var names := ["amb_city.ogg", "amb_avenue.ogg", "amb_wind.ogg", "amb_crowd.wav", "amb_heli.wav", "amb_siren.wav",
		"bird_loop_a.wav", "bird_loop_b.wav", "sfx_engine_car.wav", "sfx_engine_car_b.wav", "sfx_engine_bus.wav",
		"sfx_brake_squeal.wav", "sfx_air_brake.wav", "sfx_crossing_beep.wav", "ui_phone_open.wav", "ui_phone_close.wav", "ui_goal.wav"]
	for n in names:
		var s := _res(n)
		if s:
			S[n.get_basename()] = s
	S.horn = _rand(["sfx_horn_0.wav", "sfx_horn_1.wav", "sfx_horn_2.wav", "sfx_horn_3.wav"], 1.06, 2.0)
	S.maritaca = _rand(["bird_maritaca_0.wav", "bird_maritaca_1.wav", "bird_maritaca_2.wav"], 1.08, 2.0)
	S.bemtevi = _rand(["bird_bemtevi_0.wav", "bird_bemtevi_1.wav"], 1.04, 1.5)
	for k in KINDS:
		var files := []
		for i in 5:
			files.append("step_%s_%d.wav" % [k, i])
		steps[k] = _rand(files, 1.0, 1.5)
	S.npc_step = _rand(["step_concrete_0.wav", "step_concrete_1.wav", "step_concrete_2.wav", "step_concrete_3.wav", "step_concrete_4.wav"], 1.12, 2.0)


func _res(n: String) -> AudioStream:
	var path := DIR + n
	return load(path) if ResourceLoader.exists(path) else null


func _rand(files: Array, pitch: float, vol: float) -> AudioStreamRandomizer:
	var r := AudioStreamRandomizer.new()
	r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	r.random_pitch = pitch
	r.random_volume_offset_db = vol
	for f in files:
		var s := _res(f)
		if s:
			r.add_stream(-1, s)
	return r if r.streams_count > 0 else null


func _bed(key: String, name: String) -> void:
	if not S.has(name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = S[name]
	p.bus = &"Ambience"
	p.volume_db = -80.0
	add_child(p)
	p.play(rng.randf() * S[name].get_length())
	beds[key] = p
	bed_db[key] = -40.0


func _beds() -> void:
	_bed("city", "amb_city")
	_bed("avenue", "amb_avenue")
	_bed("wind", "amb_wind")


func _loop3d(name: String, pos: Vector3, db: float, unit: float, max_dist: float, bus := &"Ambience") -> AudioStreamPlayer3D:
	if not S.has(name):
		return null
	var p := _p3d(S[name], db, bus, unit, max_dist)
	p.position = pos
	p.pitch_scale = rng.randf_range(0.96, 1.04)
	city.world.add_child(p)
	p.play(rng.randf() * S[name].get_length())
	return p


func _bird_spots() -> Array:
	var spots := [Vector3(42, 9, -66), Vector3(68, 10, -88), Vector3(50, 9, -118), Vector3(82, 10, -110)]
	var rio: Variant = city.get("rio")
	if rio and "data" in rio and rio.data is Dictionary and rio.data.has("street"):
		var st: Array = rio.data.street
		var acc := 0.0
		var next := 20.0
		var side := 1.0
		for k in st.size() - 1:
			var a := Vector3(st[k].p[0], st[k].y, st[k].p[1])
			var b := Vector3(st[k + 1].p[0], st[k + 1].y, st[k + 1].p[1])
			var l := a.distance_to(b)
			while acc + l >= next:
				var q := a.lerp(b, (next - acc) / maxf(l, 0.001))
				var d := (b - a).normalized()
				spots.append(q + Vector3(-d.z, 0, d.x) * 6.0 * side + Vector3(0, 7.0, 0))
				side = -side
				next += 55.0
			acc += l
	return spots


func _birds() -> void:
	var i := 0
	for p in _bird_spots():
		var b := _loop3d("bird_loop_a" if i % 2 == 0 else "bird_loop_b", p, -4.0, 9.0, 75.0)
		if b:
			birds.append(b)
		i += 1


func _crowds() -> void:
	var crowd: Variant = city.get("crowd")
	if not crowd or not ("statics" in crowd):
		return
	var cells := {}
	for s in crowd.statics:
		var p: Variant = null
		if s is Dictionary:
			p = s.get("pos")
			if p == null and s.get("node") is Node3D:
				p = (s.node as Node3D).global_position
		elif s is Node3D:
			p = (s as Node3D).global_position
		if not (p is Vector3):
			continue
		var key := Vector2i(floori(p.x / 10.0), floori(p.z / 10.0))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(p)
	for key in cells:
		var pts: Array = cells[key]
		if pts.size() < 3:
			continue
		var c := Vector3.ZERO
		for q in pts:
			c += q
		c /= pts.size()
		var db := -9.0 + 3.0 * log(pts.size() / 3.0) / log(2.0)
		var p3 := _loop3d("amb_crowd", c + Vector3(0, 1.5, 0), minf(db, -2.0), 3.5, 42.0, &"SFX")
		if p3:
			crowds.append(p3)


func _signal_spots() -> Array:
	var out := []
	var tr: Variant = city.get("traffic")
	if tr and tr.has_method("crossings"):
		for e in tr.crossings():
			out.append(Vector3(16.6, 2.4, float(e.zhi) + 1.0))
			out.append(Vector3(-16.6, 2.4, float(e.zlo) - 1.0))
	else:
		for w in Layout.crosswalks():
			out.append(Vector3(16.6, 2.4, float(w.z1) + 1.0))
			out.append(Vector3(-16.6, 2.4, float(w.z0) - 1.0))
	return out


func _signals() -> void:
	if not S.has("sfx_crossing_beep"):
		return
	for p in _signal_spots():
		var s := _p3d(S.sfx_crossing_beep, -14.0, &"SFX", 2.0, 24.0)
		s.position = p
		city.world.add_child(s)
		signals.append(s)


func _engines() -> void:
	for i in ENGINE_VOICES:
		var p := _p3d(S.get("sfx_engine_car"), -4.0, &"SFX", 5.0, 90.0)
		p.attenuation_filter_cutoff_hz = 3500.0
		city.world.add_child(p)
		engines.append({"p": p, "node": null, "kind": &""})


func _npc_pool() -> void:
	for i in NPC_VOICES:
		var p := _p3d(S.get("npc_step"), -15.0, &"SFX", 1.6, 18.0)
		city.world.add_child(p)
		npc_pool.append(p)


func _hook_player() -> void:
	var pl: Node = city.get("player")
	if not pl:
		return
	var sp: Variant = pl.get("steps")
	if pl.has_signal("footstep") or pl.has_signal("stepped"):
		pl.connect("footstep" if pl.has_signal("footstep") else "stepped", _on_player_stepped)
		step_mode = "signal"
		if pl.has_signal("landed"):
			pl.connect("landed", _on_player_landed)
		if sp is AudioStreamPlayer:
			(sp as AudioStreamPlayer).stream = null
			(sp as AudioStreamPlayer).volume_db = -80.0
	elif sp is AudioStreamPlayer:
		step_mode = "swap"
		(sp as AudioStreamPlayer).bus = &"SFX"
	else:
		step_mode = "odometer"
	if pl.has_signal("bumped"):
		pl.connect("bumped", _on_player_bumped)
	if step_mode != "swap":
		own_steps = AudioStreamPlayer.new()
		own_steps.bus = &"SFX"
		add_child(own_steps)


func _hook_ui() -> void:
	var hud: Variant = city.get("hud")
	if hud and hud.has_signal("goal_reached"):
		hud.connect("goal_reached", _on_goal)
		goal_was = true
	var pl: Node = city.get("player")
	var hands: Variant = pl.get("hands") if pl else null
	if hands and hands.has_signal("phone_toggled"):
		hands.connect("phone_toggled", _on_phone)


func _on_goal(_a: Variant = null) -> void:
	play_ui(S.get("ui_goal"), 0.0)
	_count("ui_goal")


func _on_phone(on: Variant = null) -> void:
	play_ui(S.get("ui_phone_open" if on else "ui_phone_close"), -6.0)
	_count("ui_phone")


func _on_player_stepped(speed: Variant = null, _b: Variant = null) -> void:
	var v := float(speed) if (speed is float or speed is int) else 2.3
	_play_step(_feet_kind(), clampf((v - 2.3) / 3.0, 0.0, 1.0))


func _on_player_landed(impact: Variant = null) -> void:
	var v := float(impact) if (impact is float or impact is int) else 3.0
	_play_step(_feet_kind(), clampf(v / 6.0, 0.3, 1.5))


func _on_player_bumped(body: Variant = null, speed: Variant = null) -> void:
	var v := float(speed) if (speed is float or speed is int) else 3.0
	if bump_cd > 0.0 or v < 0.5:
		return
	bump_cd = 1.2
	var pos := _feet() + Vector3(0, 0.8, 0)
	if body is Node3D and is_instance_valid(body):
		pos = (body as Node3D).global_position + Vector3(0, 0.8, 0)
		var id: int = (body as Node3D).get_instance_id()
		if tracked.has(id):
			tracked[id].hcd = 4.0
	if not (external_honk and body is Node and (body as Node).has_meta("mover")):
		play_at(S.get("horn"), pos, 0.0, &"SFX", 10.0, 300.0)
	if v > 3.0:
		play_at(S.get("sfx_brake_squeal"), pos, -8.0, &"SFX", 5.0, 90.0)
	_count("bumped")


func _play_step(k: StringName, loud: float) -> void:
	if not own_steps or closed:
		return
	own_steps.stream = step_stream(k)
	own_steps.volume_db = STEP_DB.get(k, -11.0) + loud * 3.0
	own_steps.pitch_scale = rng.randf_range(0.92, 1.08)
	own_steps.play()
	_count("step_" + String(k))


func _count(k: String) -> void:
	counts[k] = counts.get(k, 0) + 1
	if debug and not k.begins_with("npc") and not k.begins_with("step"):
		print("[A] %.2f event %s" % [t, k])


func _feet() -> Vector3:
	var pl: Node3D = city.get("player")
	return pl.global_position if pl else Vector3.ZERO


func _feet_kind() -> StringName:
	return surface.at(_feet() + Vector3(0, 0.02, 0))


func _physics_process(dt: float) -> void:
	if not city or not city.get("player"):
		return
	_track(dt)
	_engines_update()
	_walkers(dt)
	_player_steps(dt)
	_flybys(dt)


func _process(dt: float) -> void:
	if not city or not city.get("player"):
		return
	t += dt
	bump_cd = maxf(0.0, bump_cd - dt)
	if not surface.done:
		surface.step(3.0)
	var p := _feet()
	_mix(p, dt)
	_events(p, dt)
	_ui()
	if debug:
		log_t -= dt
		if log_t <= 0.0:
			log_t = 1.0
			print("[A] %s" % JSON.stringify(snapshot()))


func zone(p: Vector3) -> Dictionary:
	var dx := maxf(0.0, absf(p.x) - 16.0)
	var dz := maxf(0.0, maxf(p.z - AVENUE_Z.y, AVENUE_Z.x - p.z))
	var avenue := clampf(1.0 - sqrt(dx * dx + dz * dz) / 150.0, 0.0, 1.0)
	var rio := clampf((-p.x - 34.0) / 40.0, 0.0, 1.0) * clampf(1.0 - (absf(p.z + 337.0) - 60.0) / 40.0, 0.0, 1.0)
	var masp := 1.0 if MASP.has_point(Vector2(p.x, p.z)) and p.y < 8.0 else 0.0
	var tri := clampf(1.0 - _rect_dist(TRIANON, p) / 40.0, 0.0, 1.0)
	return {"avenue": avenue, "rio": rio, "masp": masp, "trianon": tri}


func _rect_dist(r: Rect2, p: Vector3) -> float:
	var dx := maxf(0.0, maxf(r.position.x - p.x, p.x - r.end.x))
	var dz := maxf(0.0, maxf(r.position.y - p.z, p.z - r.end.y))
	return sqrt(dx * dx + dz * dz)


func _mix(p: Vector3, dt: float) -> void:
	var z := zone(p)
	var a: float = z.avenue
	var target := {
		"city": -13.0 + 3.0 * a - 3.0 * z.rio,
		"avenue": lerpf(-40.0, -7.0, pow(a, 0.8)),
		"wind": -17.0 + 5.0 * z.masp + 3.0 * clampf((p.y - 4.0) / 10.0, 0.0, 1.0) - 4.0 * z.rio,
	}
	var k := 1.0 - exp(-2.5 * dt)
	for key in beds:
		bed_db[key] = lerpf(bed_db[key], target[key], k)
		(beds[key] as AudioStreamPlayer).volume_db = bed_db[key]
	var wet: float = 0.04 + 0.22 * z.masp + 0.06 * z.rio
	reverb_wet = lerpf(reverb_wet, wet, k)
	if reverb:
		reverb.wet = reverb_wet
	mix = z


func _vehicle_nodes() -> Array:
	var out := []
	var seen := {}
	var tr: Variant = city.get("traffic")
	var src: Variant = tr.get("movers") if tr else null
	if src is Array:
		for m in src:
			var n: Variant = null
			var kind: Variant = null
			var bus: Variant = null
			if m is Dictionary:
				n = m.get("node")
				kind = m.get("kind")
				bus = m.get("bus")
			elif m is Node3D:
				n = m
			elif m is Object:
				n = m.get("node")
				kind = m.get("kind")
				bus = m.get("bus")
			if n == null or not is_instance_valid(n) or not (n is Node3D):
				continue
			seen[n.get_instance_id()] = true
			var k := _kind_of(n)
			if bus is bool and bus:
				k = &"bus"
			elif kind != null:
				k = &"bus" if str(kind).to_lower().contains("bus") else (k if k == &"bus" else &"car")
			out.append([n, k])
	for n in get_tree().get_nodes_in_group(&"vehicle"):
		if n is Node3D and not seen.has(n.get_instance_id()):
			out.append([n, _kind_of(n)])
	return out


func _kind_of(n: Node) -> StringName:
	if n.has_meta(&"kind") and str(n.get_meta(&"kind")).to_lower().contains("bus"):
		return &"bus"
	if n.is_in_group(&"bus") or String(n.name).to_lower().contains("bus"):
		return &"bus"
	return &"car"


func _hook_traffic() -> void:
	var tr: Variant = city.get("traffic")
	if not tr or not (tr is Object):
		return
	if tr.has_signal("honk"):
		tr.connect("honk", _on_honk)
		external_honk = true
	if tr.has_signal("car_recycled"):
		tr.connect("car_recycled", _on_recycled)
	if tr.has_signal("car_spawned"):
		tr.connect("car_spawned", _on_spawned)


func _on_spawned(_n: Variant = null) -> void:
	cache_t = 0.0


func _on_recycled(n: Variant = null) -> void:
	if n is Object and is_instance_valid(n):
		tracked.erase((n as Object).get_instance_id())
		for e in engines:
			if e.node == n:
				e.node = null
	cache_t = 0.0


func _on_honk(n: Variant = null) -> void:
	if not (n is Node3D) or not is_instance_valid(n):
		return
	var pos: Vector3 = (n as Node3D).global_position
	if pos.distance_to(_feet()) > 300.0:
		return
	play_at(S.get("horn"), pos + Vector3(0, 1.0, 0), 0.0, &"SFX", 10.0, 300.0)
	_count("horn_traffic")


func _track(dt: float) -> void:
	var pp := _feet()
	var alive := {}
	cache_t -= dt
	if cache_t <= 0.0:
		cache_t = 0.5
		vehicles = _vehicle_nodes()
	for e in vehicles:
		var n: Variant = e[0]
		if not is_instance_valid(n):
			continue
		var pos: Vector3 = (n as Node3D).global_position
		if pos.distance_squared_to(pp) > 25600.0:
			continue
		var id: int = (n as Node3D).get_instance_id()
		alive[id] = true
		if not tracked.has(id):
			tracked[id] = {"node": n, "kind": e[1], "last": pos, "speed": 0.0, "acc": 0.0, "stop": 0.0, "cd": rng.randf_range(0.0, 3.0), "hcd": 0.0, "fast": 0.0}
			continue
		var tr: Dictionary = tracked[id]
		tr.kind = e[1]
		var d := pos - (tr.last as Vector3)
		d.y = 0.0
		tr.last = pos
		var v := d.length() / dt
		if v > 40.0:
			continue
		var prev: float = tr.speed
		tr.speed = lerpf(prev, v, 1.0 - exp(-10.0 * dt))
		tr.acc = lerpf(tr.acc, (tr.speed - prev) / dt, 1.0 - exp(-8.0 * dt))
		tr.fast = maxf(tr.fast - dt, tr.speed)
		tr.cd = maxf(0.0, tr.cd - dt)
		tr.hcd = maxf(0.0, tr.hcd - dt)
		var dist := pos.distance_to(pp)
		if tr.acc < -3.5 and tr.speed > 3.0 and tr.cd <= 0.0 and dist < 70.0:
			tr.cd = 8.0
			if tr.kind == &"bus":
				play_at(S.get("sfx_air_brake"), pos + Vector3(0, 0.6, 0), -6.0, &"SFX", 6.0, 90.0)
				_count("air_brake")
			else:
				play_at(S.get("sfx_brake_squeal"), pos + Vector3(0, 0.4, 0), -10.0, &"SFX", 5.0, 90.0)
				_count("brake")
		var blocked: bool = tr.speed < 0.4 and tr.fast > 2.0 and dist < 9.0 and absf(pp.x - pos.x) < 2.2 and absf(pp.x) < 16.0
		tr.stop = tr.stop + dt if blocked else 0.0
		if tr.stop > 1.5 and tr.hcd <= 0.0 and not external_honk:
			tr.hcd = 5.0
			tr.stop = 0.0
			play_at(S.get("horn"), pos + Vector3(0, 1.0, 0), 0.0, &"SFX", 10.0, 300.0)
			_count("horn_blocked")
	for id in tracked.keys():
		if not alive.has(id):
			tracked.erase(id)


func _engines_update() -> void:
	var pp := _feet()
	assign_t -= get_physics_process_delta_time()
	if assign_t <= 0.0:
		assign_t = 0.2
		_assign(pp)
	for e in engines:
		var p: AudioStreamPlayer3D = e.p
		var n: Variant = e.node
		if n == null or not is_instance_valid(n):
			if p.playing:
				p.stop()
			e.node = null
			continue
		var tr: Dictionary = tracked.get(n.get_instance_id(), {})
		var spd: float = tr.get("speed", 0.0)
		var bus: bool = e.kind == &"bus"
		p.global_position = (n as Node3D).global_position + Vector3(0, 0.7 if not bus else 1.0, 0)
		var k := clampf(spd / 12.0, 0.0, 1.0)
		p.pitch_scale = (lerpf(0.72, 1.35, k) if not bus else lerpf(0.8, 1.15, k)) * e.get("detune", 1.0)
		p.volume_db = (lerpf(-12.0, -3.0, k) if not bus else lerpf(-6.0, 0.0, k))


func _assign(pp: Vector3) -> void:
	var near := []
	for id in tracked:
		var tr: Dictionary = tracked[id]
		var n: Node3D = tr.node
		if not is_instance_valid(n):
			continue
		var d := n.global_position.distance_squared_to(pp)
		if d < 8100.0:
			near.append([d, n, tr.kind])
	near.sort_custom(func(a, b): return a[0] < b[0])
	near = near.slice(0, ENGINE_VOICES)
	var want := {}
	for e in near:
		want[e[1].get_instance_id()] = e
	var free := []
	for e in engines:
		var n: Variant = e.node
		if n != null and is_instance_valid(n) and want.has(n.get_instance_id()):
			want.erase(n.get_instance_id())
		else:
			e.node = null
			free.append(e)
	for id in want:
		if free.is_empty():
			break
		var e: Dictionary = free.pop_back()
		var w: Array = want[id]
		e.node = w[1]
		e.kind = w[2]
		var name := "sfx_engine_bus" if w[2] == &"bus" else ("sfx_engine_car" if id % 2 == 0 else "sfx_engine_car_b")
		var p: AudioStreamPlayer3D = e.p
		p.stream = S.get(name)
		p.unit_size = 7.0 if w[2] == &"bus" else 5.0
		e.detune = rng.randf_range(0.93, 1.07)
		p.global_position = (w[1] as Node3D).global_position
		if p.stream:
			p.play(rng.randf() * p.stream.get_length())
	for e in free:
		if e.node == null and (e.p as AudioStreamPlayer3D).playing:
			(e.p as AudioStreamPlayer3D).stop()


func _walkers(dt: float) -> void:
	var crowd: Variant = city.get("crowd")
	if not crowd or not ("walkers" in crowd) or npc_pool.is_empty():
		return
	var pp := _feet()
	for w in crowd.walkers:
		var n: Variant = w.get("node") if w is Dictionary else w
		if n == null or not is_instance_valid(n) or not (n is Node3D):
			continue
		var id: int = n.get_instance_id()
		var pos: Vector3 = (n as Node3D).global_position
		var last: Vector3 = walker_last.get(id, pos)
		walker_last[id] = pos
		if pos.distance_squared_to(pp) > 196.0:
			walker_odo[id] = rng.randf() * 0.7
			continue
		var d := Vector2(pos.x - last.x, pos.z - last.z).length()
		if d > 2.0:
			continue
		var o: float = walker_odo.get(id, 0.0) + d
		if o >= 0.72:
			o -= 0.72
			var p := npc_pool[npc_next]
			npc_next = (npc_next + 1) % npc_pool.size()
			p.global_position = pos + Vector3(0, 0.05, 0)
			p.play()
			_count("npc_step")
		walker_odo[id] = o


func _player_steps(dt: float) -> void:
	var pl: Node3D = city.get("player")
	var feet := pl.global_position
	kind_t -= dt
	if kind_t <= 0.0:
		kind_t = 0.1
		cur_kind = _feet_kind() if surface.done else &"concrete"
	if step_mode == "swap":
		var sp: AudioStreamPlayer = pl.get("steps")
		if not sp:
			return
		var run: float = pl.get("run_k") if pl.get("run_k") != null else 0.0
		var want := step_stream(cur_kind)
		if sp.stream != want and not sp.playing:
			sp.stream = want
		sp.volume_db = STEP_DB.get(cur_kind, -11.0) + 3.0 * clampf(run, 0.0, 1.0)
		var pos := sp.get_playback_position() if sp.playing else -1.0
		if sp.playing and (pos < last_step_pos or last_step_pos < 0.0):
			_count("step_" + String(cur_kind))
		last_step_pos = pos
	elif step_mode == "odometer":
		if last_feet == Vector3.INF:
			last_feet = feet
		var d := Vector2(feet.x - last_feet.x, feet.z - last_feet.z).length()
		var dy := feet.y - last_feet.y
		last_feet = feet
		var g: Variant = pl.get("grounded")
		var grounded: bool = g if g is bool else absf(dy) < 0.05
		if grounded and not was_grounded:
			_play_step(cur_kind, 0.5)
		was_grounded = grounded
		if not grounded or d > 2.0:
			return
		var spd := d / dt
		odo += d
		var stride := 1.05 if spd > 3.5 else 0.72
		if odo >= stride and spd > 0.4:
			odo = 0.0
			_play_step(cur_kind, 1.0 if spd > 3.5 else 0.0)


func _ui() -> void:
	var pl: Node = city.get("player")
	var hands: Variant = pl.get("hands") if pl else null
	if hands and not hands.has_signal("phone_toggled") and hands.get("phone_on") != null:
		var on: bool = hands.phone_on
		if on != phone_was:
			phone_was = on
			_on_phone(on)
	var hud: Variant = city.get("hud")
	if hud and not hud.has_signal("goal_reached") and hud.get("goal_done") != null:
		var g: bool = hud.goal_done
		if g and not goal_was:
			_on_goal()
		goal_was = g


func _events(p: Vector3, dt: float) -> void:
	var a: float = mix.get("avenue", 0.0)
	horn_t -= dt
	if horn_t <= 0.0:
		horn_t = rng.randf_range(16.0, 38.0) if a > 0.3 else rng.randf_range(45.0, 100.0)
		_ambient_horn(p)
	siren_t -= dt
	if siren_t <= 0.0:
		siren_t = rng.randf_range(90.0, 200.0)
		_siren(p)
	heli_t -= dt
	if heli_t <= 0.0:
		heli_t = rng.randf_range(140.0, 280.0)
		_heli(p)
	bird_t -= dt
	if bird_t <= 0.0:
		bird_t = rng.randf_range(5.0, 14.0)
		_bird_call(p)
	beep_t -= dt
	if beep_t <= 0.0:
		beep_t = _beep(p)


func _ambient_horn(p: Vector3) -> void:
	var cands := []
	for id in tracked:
		var n: Node3D = tracked[id].node
		if is_instance_valid(n):
			var d := n.global_position.distance_to(p)
			if d > 20.0 and d < 130.0:
				cands.append(n.global_position)
	var pos: Vector3
	if not cands.is_empty():
		pos = cands[rng.randi() % cands.size()]
	else:
		pos = Vector3(rng.randf_range(-12.0, 12.0), 0.0, clampf(p.z + rng.randf_range(-120.0, 120.0), AVENUE_Z.x, AVENUE_Z.y))
	play_at(S.get("horn"), pos + Vector3(0, 1.0, 0), rng.randf_range(-4.0, 1.0), &"SFX", 12.0, 450.0)
	_count("horn")


func _flyby(name: String, from: Vector3, vel: Vector3, dur: float, db: float, unit: float) -> void:
	if not S.has(name):
		return
	var pl := _p3d(S[name], -60.0, &"Ambience", unit, 2000.0)
	pl.attenuation_filter_cutoff_hz = 2500.0
	pl.attenuation_filter_db = -24.0
	pl.position = from
	city.world.add_child(pl)
	pl.play(rng.randf() * S[name].get_length())
	flybys.append({"p": pl, "vel": vel, "t": 0.0, "dur": dur, "db": db})
	_count(name)


func _siren(p: Vector3) -> void:
	var sx := -1.0 if rng.randf() < 0.5 else 1.0
	var dir := -1.0 if rng.randf() < 0.5 else 1.0
	var from := Vector3(sx * rng.randf_range(160.0, 320.0), 3.0, p.z - dir * 420.0)
	_flyby("amb_siren", from, Vector3(0, 0, dir * 18.0), 46.0, -6.0, 45.0)


func _heli(p: Vector3) -> void:
	var ang := rng.randf() * TAU
	var dir := Vector3(cos(ang), 0, sin(ang))
	var side := Vector3(-dir.z, 0, dir.x) * rng.randf_range(-150.0, 150.0)
	var from := p - dir * 700.0 + side + Vector3(0, rng.randf_range(110.0, 180.0), 0)
	_flyby("amb_heli", from, dir * 38.0, 37.0, -3.0, 70.0)


func _flybys(dt: float) -> void:
	var lp := _feet() + Vector3(0, 1.6, 0)
	for f in flybys.duplicate():
		var p: AudioStreamPlayer3D = f.p
		f.t += dt
		var vel: Vector3 = f.vel
		p.position += vel * dt
		var to_l := (lp - p.position).normalized()
		p.pitch_scale = clampf(343.0 / (343.0 - vel.dot(to_l)), 0.8, 1.25)
		var fade := clampf(f.t / 6.0, 0.0, 1.0) * clampf((f.dur - f.t) / 6.0, 0.0, 1.0)
		p.volume_db = lerpf(-60.0, f.db, sqrt(fade))
		if f.t >= f.dur:
			flybys.erase(f)
			p.queue_free()


func _bird_call(p: Vector3) -> void:
	var near := []
	for b in birds:
		if b.global_position.distance_to(p) < 60.0:
			near.append(b.global_position)
	if near.is_empty():
		return
	var at: Vector3 = near[rng.randi() % near.size()] + Vector3(rng.randf_range(-6, 6), rng.randf_range(-2, 3), rng.randf_range(-6, 6))
	if rng.randf() < 0.45:
		play_at(S.get("maritaca"), at, -3.0, &"Ambience", 9.0, 140.0)
		_count("maritaca")
	else:
		play_at(S.get("bemtevi"), at, -6.0, &"Ambience", 8.0, 110.0)
		_count("bemtevi")


func _beep(p: Vector3) -> float:
	if signals.is_empty():
		return 1.0
	var tr: Variant = city.get("traffic")
	var fast := false
	for s in signals:
		if s.global_position.distance_to(p) > 26.0:
			continue
		var open := false
		if tr and tr.has_method("is_walk_open"):
			open = tr.is_walk_open(s.global_position.z)
		fast = fast or open
		s.play()
	return 0.28 if fast else 1.2


func snapshot() -> Dictionary:
	var pl: Node3D = city.get("player")
	var e := []
	for v in engines:
		var p: AudioStreamPlayer3D = v.p
		if p.playing and v.node != null and is_instance_valid(v.node):
			e.append({"kind": String(v.kind), "d": snappedf(p.global_position.distance_to(pl.global_position), 0.1), "pitch": snappedf(p.pitch_scale, 0.01), "db": snappedf(p.volume_db, 0.1), "spd": snappedf(tracked.get(v.node.get_instance_id(), {}).get("speed", 0.0), 0.1)})
	var b := {}
	for k in beds:
		b[k] = snappedf((beds[k] as AudioStreamPlayer).volume_db, 0.1)
	var fly := []
	for f in flybys:
		fly.append({"stream": (f.p as AudioStreamPlayer3D).stream.resource_path.get_file(), "d": snappedf((f.p as AudioStreamPlayer3D).global_position.distance_to(pl.global_position), 1.0), "db": snappedf((f.p as AudioStreamPlayer3D).volume_db, 0.1)})
	var z := {}
	for k in mix:
		z[k] = snappedf(mix[k], 0.01)
	var near_birds := 0
	for x in birds:
		if x.global_position.distance_to(pl.global_position) < x.max_distance:
			near_birds += 1
	var near_crowds := 0
	for x in crowds:
		if x.global_position.distance_to(pl.global_position) < x.max_distance:
			near_crowds += 1
	return {"t": snappedf(t, 0.01), "pos": [snappedf(pl.global_position.x, 0.1), snappedf(pl.global_position.y, 0.01), snappedf(pl.global_position.z, 0.1)], "surface": String(cur_kind), "zone": z, "beds": b, "reverb": snappedf(reverb_wet, 0.01), "engines": e, "tracked": tracked.size(), "birds_in_range": near_birds, "crowds_in_range": near_crowds, "flybys": fly, "counts": counts, "surface_map": surface.stats() if not surface.done or t < 2.0 else {"tris": surface.kinds.size()}}




func shutdown() -> void:
	closed = true
	set_process(false)
	set_physics_process(false)
	var all: Array = find_children("*", "AudioStreamPlayer", true, false) + city.world.find_children("*", "AudioStreamPlayer3D", true, false)
	var pl: Variant = city.get("player")
	if pl and pl.get("steps") is AudioStreamPlayer:
		all.append(pl.steps)
	for p in all:
		p.stop()
		p.queue_free()
	beds.clear()
	engines.clear()
	flybys.clear()
	await get_tree().create_timer(0.25, true, false, true).timeout
