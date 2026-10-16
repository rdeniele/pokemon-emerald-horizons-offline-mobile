extends RefCounted
class_name Water







const SHALLOW_WIDTH: = 1.2




enum Surface{GROUND, SHALLOW, DEEP}





const SWIM_SPEED: = 1.25
const WADE_SPEED: = 0.6
const FISH_LAND_SPEED: = 0.4

const FISH_LEASH: = 2.0
const DIVE_TIME: = 0.9
const DIVE_LAND: = 0.3
const DIVE_STAMINA: = 0.15



const WADE_SINK: = 0.22
const SWIM_SINK: = 0.45
const DIVE_SINK: = 1.0



static func _depth(r: Rect2, x: float, z: float) -> float:
	var dx: = maxf(r.position.x - x, x - r.end.x)
	var dz: = maxf(r.position.y - z, z - r.end.y)
	if dx <= 0.0 and dz <= 0.0:
		return maxf(dx, dz)
	return Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length()




static func surface(rects: Array, x: float, z: float) -> int:
	var shallow: = false
	for r in rects:
		var d: = _depth(r, x, z)
		if d >= 0.0:
			continue
		if - d < SHALLOW_WIDTH:
			shallow = true
		else:
			return Surface.DEEP
	return Surface.SHALLOW if shallow else Surface.GROUND



static func distance_to_water(rects: Array, x: float, z: float) -> float:
	var best: = INF
	for r in rects:
		best = minf(best, maxf(_depth(r, x, z), 0.0))
	return 0.0 if best == INF else best




static func nearest_point(rects: Array, x: float, z: float, deep: = false) -> Vector2:
	var best: = Vector2.INF
	var best_d: = INF
	for r in rects:
		var p: = Vector2(clampf(x, r.position.x, r.end.x), clampf(z, r.position.y, r.end.y))
		var d: = p.distance_to(Vector2(x, z))
		if d < best_d:
			best_d = d
			best = r.get_center() if deep else p
	return best
