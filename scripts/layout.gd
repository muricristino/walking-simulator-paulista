extends RefCounted

const CROSS := [40.0, -146.0, -429.0, -635.0]
const CROSS_HALF := 9.0
const STREETS := [
	{"z": 40.0, "half": 9.0, "walk": 3.0, "sides": [-1, 1], "names": {-1: "peixoto", 1: "peixoto"}},
	{"z": -36.0, "half": 4.5, "walk": 2.5, "sides": [-1], "names": {-1: "plinio"}},
	{"z": -146.0, "half": 9.0, "walk": 3.0, "sides": [-1, 1], "names": {-1: "otavio", 1: "casabranca"}, "len": {-1: 120.0}},
	{"z": -245.0, "half": 5.5, "walk": 2.5, "sides": [-1], "names": {-1: "itapeva"}},
	{"z": -429.0, "half": 9.0, "walk": 3.0, "sides": [-1, 1], "names": {-1: "pamplona", 1: "pamplona"}},
	{"z": -635.0, "half": 9.0, "walk": 3.0, "sides": [-1, 1], "names": {-1: "campinas", 1: "campinas"}},
]
const RIO_Z := -337.0
const RIO_GAP := Vector2(-348.0, -326.0)
const MASP_Z := Vector2(-131.0, -53.0)
const MASP_CROSSWALK_Z := -48.0
const MASP_STAIRS := Rect2(-41.0, -117.0, 6.0, 14.0)
const SPAWN_FEET := Vector3(21.5, 0.15, -12.0)
const SPAWN_LOOK := Vector3(-14.0, 9.0, -100.0)
const WALK_Z := Vector2(-700.0, 56.0)
const SIDEWALK_X := Vector2(16.0, 30.0)
const BUS_STOPS := [Vector3(14.25, 0.0, -80.0), Vector3(-14.25, 0.0, -196.0)]


static func crosswalks() -> Array:
	var out := [{"z": MASP_CROSSWALK_Z, "x0": -16.0, "x1": 16.0, "z0": MASP_CROSSWALK_Z - 3.0, "z1": MASP_CROSSWALK_Z + 3.0}]
	for c in CROSS:
		var z: float = c + CROSS_HALF + 3.5
		out.append({"z": z, "x0": -16.0, "x1": 16.0, "z0": z - 3.0, "z1": z + 3.0})
	return out


static func keep_clear() -> Array:
	var out := []
	for w in crosswalks():
		out.append(Rect2(-31.0, w.z0 - 1.5, 62.0, w.z1 - w.z0 + 3.0))
	for s in STREETS:
		var h: float = s.half + s.walk
		for sd in s.sides:
			var x0 := 15.0 if sd > 0 else -60.0
			out.append(Rect2(x0, s.z - h - 1.0, 45.0, 2.0 * h + 2.0))
	out.append(Rect2(-31.0, RIO_GAP.x - 2.0, 16.0, RIO_GAP.y - RIO_GAP.x + 4.0))
	out.append(MASP_STAIRS.grow(0.6))
	out.append(Rect2(SPAWN_FEET.x - 3.0, SPAWN_FEET.z - 3.0, 6.0, 6.0))
	return out


static func is_clear(x: float, z: float, pad := 0.0) -> bool:
	for r in keep_clear():
		if r.grow(pad).has_point(Vector2(x, z)):
			return false
	return true


static func in_cross(z0: float, z1: float, pad := 0.0) -> bool:
	for c in CROSS:
		if z1 > c - CROSS_HALF - pad and z0 < c + CROSS_HALF + pad:
			return true
	return false


static func in_street(z0: float, z1: float, side: int, pad := 0.0) -> bool:
	for s in STREETS:
		if not s.sides.has(side):
			continue
		if z1 > s.z - s.half - pad and z0 < s.z + s.half + pad:
			return true
	return false
