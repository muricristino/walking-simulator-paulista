extends RefCounted

const CELL := 4.0
const KINDS := {
	"asphalt": &"asphalt", "b_128": &"asphalt", "paint": &"asphalt", "paint_y": &"asphalt",
	"paint_white": &"asphalt", "paint_yellow": &"asphalt", "bike": &"asphalt", "road": &"asphalt",
	"mosaic": &"concrete", "concrete": &"concrete", "curb": &"concrete", "slab": &"concrete",
	"walk": &"concrete", "sidewalk": &"concrete", "paving": &"concrete", "granite": &"concrete",
	"ground": &"concrete", "stone": &"concrete", "concrete_wall": &"concrete", "plates": &"concrete",
	"paver": &"paver", "pavers": &"paver", "intertravado": &"paver",
	"deck": &"wood", "slats": &"wood", "cut__slats": &"wood", "wood": &"wood",
	"grass": &"grass", "soil": &"grass", "planter": &"grass", "lawn": &"grass",
}
const FALLBACK := &"concrete"

var tris := PackedVector3Array()
var kinds := PackedByteArray()
var names: Array[StringName] = []
var cells := {}
var pending: Array = []
var mat_keys := {}
var done := false


func setup(city: Node) -> void:
	_collect_keys(city)
	pending.clear()
	_scan(city.world)
	done = pending.is_empty()


func _collect_keys(city: Node) -> void:
	var sources: Array = []
	if "M" in city and city.M is Dictionary:
		sources.append(city.M)
	var rio: Variant = city.get("rio")
	if rio:
		if "mats" in rio and rio.mats is Dictionary:
			sources.append(rio.mats)
		var models: Variant = rio.get("models")
		if models and "mats" in models and models.mats is Dictionary:
			sources.append(models.mats)
	for d in sources:
		for k in d:
			if d[k] is Material:
				mat_keys[d[k]] = String(k)


func _scan(n: Node) -> void:
	if n is MeshInstance3D:
		pending.append(n)
	for c in n.get_children():
		_scan(c)


func step(budget_ms := 4.0) -> void:
	var t0 := Time.get_ticks_usec()
	while not pending.is_empty():
		var mi: Variant = pending.pop_back()
		if is_instance_valid(mi) and mi.is_inside_tree() and mi.mesh:
			_index(mi)
		if (Time.get_ticks_usec() - t0) * 0.001 > budget_ms:
			return
	done = true


func classify_key(key: String) -> StringName:
	var k := key.to_lower()
	if KINDS.has(k):
		return KINDS[k]
	for name in KINDS:
		if k.begins_with(name + "_") or k.ends_with("_" + name):
			return KINDS[name]
	return &""


func _surface_kind(mi: MeshInstance3D, s: int) -> StringName:
	var m: Material = mi.material_override
	if not m:
		m = mi.get_surface_override_material(s)
	if m and mat_keys.has(m):
		var k := classify_key(mat_keys[m])
		if k != &"":
			return k
	var src: Material = mi.mesh.surface_get_material(s)
	if src and src.resource_name != "":
		var k2 := classify_key(src.resource_name)
		if k2 != &"":
			return k2
	if m and m.resource_name != "":
		var k3 := classify_key(m.resource_name)
		if k3 != &"":
			return k3
	return classify_key(String(mi.name))


func _kind_id(k: StringName) -> int:
	var i := names.find(k)
	if i < 0:
		names.append(k)
		i = names.size() - 1
	return i


func _index(mi: MeshInstance3D) -> void:
	var xf := mi.global_transform
	var mesh := mi.mesh
	for s in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var k := _surface_kind(mi, s)
		if k == &"":
			continue
		var kid := _kind_id(k)
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := idx.size() if idx.size() > 0 else v.size()
		var i := 0
		while i + 2 < count:
			var a := xf * (v[idx[i]] if idx.size() > 0 else v[i])
			var b := xf * (v[idx[i + 1]] if idx.size() > 0 else v[i + 1])
			var c := xf * (v[idx[i + 2]] if idx.size() > 0 else v[i + 2])
			i += 3
			var nrm := (b - a).cross(c - a)
			var l := nrm.length()
			if l < 1e-6 or absf(nrm.y) / l < 0.7:
				continue
			_add(a, b, c, kid)


func _add(a: Vector3, b: Vector3, c: Vector3, kid: int) -> void:
	var t := kinds.size()
	tris.append(a)
	tris.append(b)
	tris.append(c)
	kinds.append(kid)
	var x0 := floori(minf(a.x, minf(b.x, c.x)) / CELL)
	var x1 := floori(maxf(a.x, maxf(b.x, c.x)) / CELL)
	var z0 := floori(minf(a.z, minf(b.z, c.z)) / CELL)
	var z1 := floori(maxf(a.z, maxf(b.z, c.z)) / CELL)
	for cx in range(x0, x1 + 1):
		for cz in range(z0, z1 + 1):
			var key := Vector2i(cx, cz)
			if not cells.has(key):
				cells[key] = []
			cells[key].append(t)


func at(p: Vector3, above := 0.3, below := 0.6) -> StringName:
	var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
	if not cells.has(key):
		return FALLBACK
	var best_y := -INF
	var best := -1
	for t in cells[key]:
		var a := tris[t * 3]
		var b := tris[t * 3 + 1]
		var c := tris[t * 3 + 2]
		var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(d) < 1e-9:
			continue
		var w0 := ((b.z - c.z) * (p.x - c.x) + (c.x - b.x) * (p.z - c.z)) / d
		var w1 := ((c.z - a.z) * (p.x - c.x) + (a.x - c.x) * (p.z - c.z)) / d
		var w2 := 1.0 - w0 - w1
		if w0 < -0.001 or w1 < -0.001 or w2 < -0.001:
			continue
		var y := a.y * w0 + b.y * w1 + c.y * w2
		if y > p.y + above or y < p.y - below:
			continue
		if y > best_y:
			best_y = y
			best = t
	return names[kinds[best]] if best >= 0 else FALLBACK


func stats() -> Dictionary:
	var by := {}
	for k in kinds:
		var n := String(names[k])
		by[n] = by.get(n, 0) + 1
	return {"tris": kinds.size(), "cells": cells.size(), "by_kind": by, "pending": pending.size()}
