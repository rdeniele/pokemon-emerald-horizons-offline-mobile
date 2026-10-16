extends Node3D




const HEIGHT: = 8.0
const COLOR: = Color(1.0, 0.86, 0.45, 0.9)

static var _tex: ImageTexture

var _decal: Decal



static func square_texture() -> ImageTexture:
	if _tex:
		return _tex
	var n: = 256
	var img: = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var line: = 0.022
	var inset: = 0.012
	for y in n:
		for x in n:
			var u: = float(x) / (n - 1)
			var v: = float(y) / (n - 1)
			var edge: = minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
			var a: = 0.0
			if edge >= inset and edge < inset + line:
				a = 0.85

			var cu: = minf(u, 1.0 - u)
			var cv: = minf(v, 1.0 - v)
			if (cu < 0.14 and cv < inset + line * 2.6 and cv >= inset) or (cv < 0.14 and cu < inset + line * 2.6 and cu >= inset):
				a = 1.0

			if edge >= inset + line * 2.2 and edge < inset + line * 3.0:
				var along: = u if (minf(v, 1.0 - v) < minf(u, 1.0 - u)) else v
				a = maxf(a, 0.5 if fmod(along * 24.0, 1.0) < 0.5 else 0.0)

			if edge > inset:
				a = maxf(a, 0.06 + 0.08 * (1.0 - smoothstep(0.0, 0.25, edge)))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_tex = ImageTexture.create_from_image(img)
	return _tex





func setup(center: Vector3, size, color: = COLOR) -> void :
	var sz: Vector2 = size if size is Vector2 else Vector2(size, size)
	global_position = center
	_decal = Decal.new()
	_decal.texture_albedo = square_texture()
	_decal.modulate = Color(color.r, color.g, color.b, 0.0)
	_decal.albedo_mix = 1.0
	_decal.normal_fade = 0.6
	_decal.upper_fade = 0.2
	_decal.lower_fade = 0.2
	_decal.size = Vector3(sz.x, HEIGHT, sz.y)
	add_child(_decal)
	var tw: = create_tween().set_parallel(true)
	tw.tween_property(_decal, "modulate:a", color.a, 0.4)
	tw.tween_property(self, "scale", Vector3.ONE, 0.4).from(Vector3(1.15, 1, 1.15)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)



func track(_a: Node3D, _b: Node3D) -> void :
	pass









const PLACE_STEP: = 1.0
const BATTLE_START_GAP: = 6.0
const GAP_MIN: = 4.0
const GAP_MAX: = 8.0
const FREE_BAR: = 0.8
const SIZE_FLOOR: = 8.0
const FOREST_SIZE: = 7.0
const SEARCH_RINGS: = 7
const BODY_CELLS: = 1
const TRAINER_STAND_OFF: = 0.3



static func _axis(v: Vector3, fallback: = Vector3.ZERO) -> Vector3:
	v.y = 0.0
	if v.length() < 0.05:
		v = fallback
		v.y = 0.0
	if v.length() < 0.05:
		v = Vector3(0, 0, -1)
	return Vector3(signf(v.x), 0, 0) if absf(v.x) > absf(v.z) else Vector3(0, 0, signf(v.z))



static func _flat(center: Vector3, size: Vector2, level: float, height_at: Callable) -> bool:
	var n: = maxi(int(ceil(maxf(size.x, size.y) / PLACE_STEP)), 2)
	var hx: = size.x * 0.5
	var hz: = size.y * 0.5
	for i in n + 1:
		for j in n + 1:
			var x: = center.x - hx + size.x * i / n
			var z: = center.z - hz + size.y * j / n
			if absf(float(height_at.call(x, z)) - level) > 0.01:
				return false
	return true




static func _blocked(blocked_at: Callable, height_at: Callable, level: float) -> Callable:
	if not blocked_at.is_valid():
		blocked_at = func(_x: float, _z: float) -> bool: return false
	var cache: = {}
	return func(x: float, z: float) -> bool:
		var key: = Vector2i(roundi(x * 100.0), roundi(z * 100.0))
		if cache.has(key):
			return cache[key]
		var b: = absf(float(height_at.call(x, z)) - level) > 0.01 or bool(blocked_at.call(x, z))
		cache[key] = b
		return b



static func _free_score(center: Vector3, size: Vector2, blocked: Callable) -> float:
	var nx: = maxi(int(round(size.x / PLACE_STEP)), 2)
	var nz: = maxi(int(round(size.y / PLACE_STEP)), 2)
	var free: = 0
	for i in nx:
		for j in nz:
			var x: = center.x - size.x * 0.5 + size.x * (i + 0.5) / nx
			var z: = center.z - size.y * 0.5 + size.y * (j + 0.5) / nz
			if not bool(blocked.call(x, z)):
				free += 1
	return float(free) / float(nx * nz)



static func _cell_clear(x: float, z: float, blocked: Callable) -> bool:
	for i in range( - BODY_CELLS, BODY_CELLS + 1):
		for j in range( - BODY_CELLS, BODY_CELLS + 1):
			if bool(blocked.call(x + i * PLACE_STEP, z + j * PLACE_STEP)):
				return false
	return true




static func _ok(pred: Callable, p: Vector2) -> bool:
	return not pred.is_valid() or bool(pred.call(p.x, p.y))



static func _snap(x: float, z: float, blocked: Callable, rings: = 4, ok: = Callable()) -> Vector2:
	for r in rings + 1:
		for i in range( - r, r + 1):
			for j in range( - r, r + 1):
				if maxi(absi(i), absi(j)) != r:
					continue
				var px: = x + i * PLACE_STEP
				var pz: = z + j * PLACE_STEP
				if _cell_clear(px, pz, blocked) and _ok(ok, Vector2(px, pz)):
					return Vector2(px, pz)
	return Vector2.INF



static func _line_clear(a: Vector2, b: Vector2, blocked: Callable) -> bool:
	var n: = maxi(int(ceil(a.distance_to(b) / (PLACE_STEP * 0.5))), 1)
	for i in n + 1:
		var p: = a.lerp(b, float(i) / n)
		if not _cell_clear(p.x, p.y, blocked):
			return false
	return true



static func _line_free(a: Vector2, b: Vector2, blocked: Callable) -> bool:
	var n: = maxi(int(ceil(a.distance_to(b) / (PLACE_STEP * 0.5))), 1)
	for i in n + 1:
		var p: = a.lerp(b, float(i) / n)
		if bool(blocked.call(p.x, p.y)):
			return false
	return true






static func _pair(center: Vector3, size: Vector2, axis: Vector3, start: Vector3, blocked: Callable, 
		wild_start: = Vector3.INF, wild_blocked: = Callable(), 
		lead_ok: = Callable(), wild_ok: = Callable()) -> Dictionary:
	var half: = BATTLE_START_GAP * 0.5


	var a: = _snap(center.x + axis.x * half, center.z + axis.z * half, blocked, 4, wild_ok)
	var b: = _snap(center.x - axis.x * half, center.z - axis.z * half, blocked, 4, lead_ok)
	if not a.is_finite() or not b.is_finite():
		return {}
	var rect: = Rect2(center.x - size.x * 0.5, center.z - size.y * 0.5, size.x, size.y)
	if not rect.has_point(a) or not rect.has_point(b):
		return {}
	var sp: = Vector2(start.x, start.z)
	var lead: = a if a.distance_to(sp) <= b.distance_to(sp) else b
	var wild: = b if lead == a else a


	if not _ok(lead_ok, lead):
		lead = _snap(lead.x, lead.y, blocked, 4, lead_ok)
	if not _ok(wild_ok, wild):
		wild = _snap(wild.x, wild.y, blocked, 4, wild_ok)
	if not lead.is_finite() or not wild.is_finite():
		return {}
	if not rect.has_point(lead) or not rect.has_point(wild):
		return {}
	var gap: = lead.distance_to(wild)
	if gap < GAP_MIN or gap > GAP_MAX or not _line_clear(lead, wild, blocked):
		return {}




	if wild_start.is_finite() and wild_blocked.is_valid():
		var wf: = Vector2(wild_start.x, wild_start.z)
		if not bool(wild_blocked.call(wf.x, wf.y)) and not _line_free(wf, wild, wild_blocked):
			return {}
	return {
		"lead_spot": Vector3(lead.x, center.y, lead.y), 
		"wild_spot": Vector3(wild.x, center.y, wild.y), 
	}



static var _offsets_cache: = {}
static func _offsets(rings: int) -> Array:
	if _offsets_cache.has(rings):
		return _offsets_cache[rings]
	var out: Array = []
	for i in range( - rings, rings + 1):
		for j in range( - rings, rings + 1):
			out.append(Vector2i(i, j))
	out.sort_custom( func(a: Vector2i, b: Vector2i) -> bool: return a.length_squared() < b.length_squared())
	_offsets_cache[rings] = out
	return out




static func _best_square(mid: Vector3, size: Vector2, start: Vector3, dir: Vector3, level: float, 
		height_at: Callable, blocked: Callable, bar: float, keep_out: bool, strict: = true, 
		wild_start: = Vector3.INF, wild_blocked: = Callable(), 
		lead_ok: = Callable(), wild_ok: = Callable()) -> Dictionary:
	var half: = size * 0.5
	var best: = {}
	var best_score: = -1.0
	var best_d: = INF
	for o in _offsets(SEARCH_RINGS):
		var c: = Vector3(mid.x + o.x * PLACE_STEP, mid.y, mid.z + o.y * PLACE_STEP)
		if keep_out and absf(start.x - c.x) < half.x and absf(start.z - c.z) < half.y:
			continue
		var score: = _free_score(c, size, blocked)
		if score < bar:
			continue
		var d: = float(o.length_squared())

		if best_score >= 0.0 and score <= best_score * 1.05 and d >= best_d:
			continue
		var pair: = _pair(c, size, dir, start, blocked, wild_start, wild_blocked, lead_ok, wild_ok)
		if pair.is_empty():
			var alt: = _axis(Vector3( - dir.z, 0.0, dir.x))
			pair = _pair(c, size, alt, start, blocked, wild_start, wild_blocked, lead_ok, wild_ok)
			if pair.is_empty():
				continue
			pair["dir"] = alt
		else:
			pair["dir"] = dir
		if strict and not _flat(c, size, level, height_at):
			continue
		best = {"center": c, "size": size, "score": score}
		best.merge(pair)
		best_score = score
		best_d = d
		if score >= 0.999:
			break
	return best



static func _cells(center: Vector3, size: Vector2, blocked: Callable) -> Array:
	var nx: = maxi(int(round(size.x / PLACE_STEP)), 2)
	var nz: = maxi(int(round(size.y / PLACE_STEP)), 2)
	var out: Array = []
	for i in nx:
		for j in nz:
			var x: = center.x - size.x * 0.5 + size.x * (i + 0.5) / nx
			var z: = center.z - size.y * 0.5 + size.y * (j + 0.5) / nz
			out.append({"pos": Vector2(x, z), "free": not bool(blocked.call(x, z))})
	return out



static func _result(c: Dictionary, level: float, blocked: Callable) -> Dictionary:
	var center: Vector3 = c.center
	var size: Vector2 = c.size
	return {
		"level": level, 
		"center": center, 
		"rect": Rect2(center.x - size.x * 0.5, center.z - size.y * 0.5, size.x, size.y), 
		"lead_spot": c.lead_spot, 
		"wild_spot": c.wild_spot, 
		"dir": c.dir, 
		"score": c.score, 
		"cells": _cells(center, size, blocked), 
	}






static func plan(start: Vector3, wild_pos: Vector3, size: Vector2, height_at: Callable, 
		fallback_dir: = Vector3.ZERO, blocked_at: = Callable(), 
		lead_ok: = Callable(), wild_ok: = Callable()) -> Dictionary:
	var level: = float(height_at.call(start.x, start.z))
	var dir: = _axis(wild_pos - start, fallback_dir)
	var blocked: = _blocked(blocked_at, height_at, level)


	var wild_blocked: = blocked_at
	if not wild_blocked.is_valid():
		wild_blocked = func(_x: float, _z: float) -> bool: return false
	var mid: = (start + wild_pos) * 0.5
	mid.y = level

	var sizes: Array = []
	var s: = size
	while s.x >= SIZE_FLOOR and s.y >= SIZE_FLOOR:
		sizes.append(s)
		s -= Vector2(PLACE_STEP * 2.0, PLACE_STEP * 2.0)
	for keep_out in [true, false]:
		for sz in sizes:
			var c: = _best_square(mid, sz, start, dir, level, height_at, blocked, FREE_BAR, keep_out, true, wild_pos, wild_blocked, lead_ok, wild_ok)
			if not c.is_empty():
				return _result(c, level, blocked)

	var fb: = Vector2(FOREST_SIZE, FOREST_SIZE)
	var best: = _best_square(mid, fb, start, dir, level, height_at, blocked, 0.0, true, false, wild_pos, wild_blocked, lead_ok, wild_ok)
	if best.is_empty():
		best = _best_square(mid, fb, start, dir, level, height_at, blocked, 0.0, false, false, wild_pos, wild_blocked, lead_ok, wild_ok)
	if not best.is_empty():
		return _result(best, level, blocked)

	best = {
		"center": Vector3(start.x, level, start.z), "size": fb, "score": 0.0, "dir": dir, 
		"lead_spot": Vector3(start.x, level, start.z), 
		"wild_spot": Vector3(start.x + dir.x * BATTLE_START_GAP, level, start.z + dir.z * BATTLE_START_GAP), 
	}
	return _result(best, level, blocked)












static func _trainer_pair(center: Vector3, size: Vector2, axis: Vector3, blocked: Callable) -> Dictionary:
	var long: float = size.x if absf(axis.x) > absf(axis.z) else size.y
	var half: = long * 0.5 + TRAINER_STAND_OFF
	var c2: = Vector2(center.x, center.z)
	var ax: = Vector2(axis.x, axis.z)


	var a_ok: = func(x: float, z: float) -> bool: return (Vector2(x, z) - c2).dot(ax) >= long * 0.5
	var b_ok: = func(x: float, z: float) -> bool: return (Vector2(x, z) - c2).dot(ax) <= - long * 0.5
	var a: = _snap(center.x + axis.x * half, center.z + axis.z * half, blocked, 4, a_ok)
	var b: = _snap(center.x - axis.x * half, center.z - axis.z * half, blocked, 4, b_ok)
	if not a.is_finite() or not b.is_finite():
		return {}
	if not _line_clear(a, c2, blocked) or not _line_clear(b, c2, blocked):
		return {}
	return {"player_spot": Vector3(b.x, center.y, b.y), "trainer_spot": Vector3(a.x, center.y, a.y)}





static func _best_trainer(mid: Vector3, size: Vector2, start: Vector3, axis: Vector3, level: float, 
		height_at: Callable, blocked: Callable, bar: float, keep_out: bool, strict: bool) -> Dictionary:
	var half: = size * 0.5
	var best: = {}
	var best_score: = -1.0
	var best_d: = INF
	for o in _offsets(SEARCH_RINGS):
		var c: = Vector3(mid.x + o.x * PLACE_STEP, mid.y, mid.z + o.y * PLACE_STEP)
		if keep_out and absf(start.x - c.x) < half.x and absf(start.z - c.z) < half.y:
			continue
		var score: = _free_score(c, size, blocked)
		if score < bar:
			continue
		var d: = float(o.length_squared())
		if best_score >= 0.0 and score <= best_score * 1.05 and d >= best_d:
			continue
		var pair: = _trainer_pair(c, size, axis, blocked)
		if pair.is_empty():
			continue
		if strict and not _flat(c, size, level, height_at):
			continue
		best = {"center": c, "size": size, "score": score}
		best.merge(pair)
		best_score = score
		best_d = d
		if score >= 0.999:
			break
	return best


static func _trainer_result(c: Dictionary, axis: Vector3, level: float, blocked: Callable) -> Dictionary:
	var center: Vector3 = c.center
	var size: Vector2 = c.size
	return {
		"level": level, 
		"center": center, 
		"size": size, 
		"rect": Rect2(center.x - size.x * 0.5, center.z - size.y * 0.5, size.x, size.y), 
		"axis": axis, 
		"player_spot": c.player_spot, 
		"trainer_spot": c.trainer_spot, 
		"score": c.score, 
		"cells": _cells(center, size, blocked), 
	}







static func plan_trainer(start: Vector3, trainer_pos: Vector3, size: Vector2, height_at: Callable, 
		fallback_dir: = Vector3.ZERO, blocked_at: = Callable()) -> Dictionary:
	var level: = float(height_at.call(start.x, start.z))
	var blocked: = _blocked(blocked_at, height_at, level)
	var mid: = (start + trainer_pos) * 0.5
	mid.y = level
	var primary: = _axis(trainer_pos - start, fallback_dir)
	var sizes: Array = [size]
	var s: = size
	while s.x - PLACE_STEP * 2.0 >= SIZE_FLOOR and s.y - PLACE_STEP * 2.0 >= SIZE_FLOOR:
		s -= Vector2(PLACE_STEP * 2.0, PLACE_STEP * 2.0)
		sizes.append(s)
	var axes: = [primary, _axis(Vector3( - primary.z, 0.0, primary.x))]


	for keep_out in [true, false]:
		for sz in sizes:
			for axis in axes:
				var rs: Vector2 = sz if absf(axis.x) > absf(axis.z) else Vector2(sz.y, sz.x)
				var c: = _best_trainer(mid, rs, start, axis, level, height_at, blocked, FREE_BAR, keep_out, true)
				if not c.is_empty():
					return _trainer_result(c, axis, level, blocked)
	for axis in axes:
		var fb: = Vector2(FOREST_SIZE, FOREST_SIZE)
		var best: = _best_trainer(mid, fb, start, axis, level, height_at, blocked, 0.0, true, false)
		if best.is_empty():
			best = _best_trainer(mid, fb, start, axis, level, height_at, blocked, 0.0, false, false)
		if not best.is_empty():
			return _trainer_result(best, axis, level, blocked)

	var rs0: Vector2 = size if absf(primary.x) > absf(primary.z) else Vector2(size.y, size.x)
	var c0: = {"center": Vector3(start.x, level, start.z), "size": rs0, "score": 0.0, 
		"player_spot": Vector3(start.x, level, start.z), 
		"trainer_spot": Vector3(trainer_pos.x, level, trainer_pos.z)}
	return _trainer_result(c0, primary, level, blocked)




static func debug_mesh(pl: Dictionary) -> MeshInstance3D:
	var im: = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell in pl.get("cells", []):
		var p: Vector2 = cell.pos
		var col: = Color(0.15, 0.95, 0.25, 0.55) if cell.free else Color(0.95, 0.1, 0.05, 0.8)
		_quad(im, Vector3(p.x, float(pl.level) + 0.05, p.y), 0.92, col)
	for key in ["lead_spot", "wild_spot"]:
		var s: Vector3 = pl[key]
		_quad(im, Vector3(s.x, s.y + 0.08, s.z), 1.6, Color(1.0, 0.9, 0.2, 0.85))
	im.surface_end()
	var mi: = MeshInstance3D.new()
	mi.mesh = im
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi



static func _quad(im: ImmediateMesh, c: Vector3, s: float, col: Color) -> void :
	var h: = s * 0.5
	im.surface_set_color(col)
	for v in [Vector3( - h, 0, - h), Vector3( - h, 0, h), Vector3(h, 0, h), 
			Vector3( - h, 0, - h), Vector3(h, 0, h), Vector3(h, 0, - h)]:
		im.surface_add_vertex(c + v)


func close() -> void :
	var tw: = create_tween()
	tw.tween_property(_decal, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
