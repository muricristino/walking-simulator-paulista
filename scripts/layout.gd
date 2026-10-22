extends RefCounted

const CROSS := [-150.0, -380.0, -560.0]
const MASP_Z := Vector2(-131.0, -53.0)
const SPAWN_FEET := Vector3(21.5, 0.15, -12.0)
const SPAWN_LOOK := Vector3(-14.0, 9.0, -100.0)


static func in_cross(z0: float, z1: float, pad := 0.0) -> bool:
	for c in CROSS:
		if z1 > c - 9.0 - pad and z0 < c + 9.0 + pad:
			return true
	return false
