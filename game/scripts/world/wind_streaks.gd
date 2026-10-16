extends Node3D
























const STREAKS: = 4
const SPEED: = 4.0
const TRAIL_TIME: = 0.55
const LIFE: = 1.25
const SEGMENTS: = 22
const WIDTH: = 0.04
const OPACITY: = 0.55
const LOOP_CHANCE: = 0.35
const LOOP_RADIUS_MAX: = 0.5
const WAVE_FREQ_MIN: = 1.5
const WAVE_FREQ_MAX: = 2.6
const VERT_AMP: = 0.12
const LOW_HEIGHT_MIN: = 0.4
const LOW_HEIGHT_MAX: = 1.5
const SPREAD: = Vector3(7.0, 0.0, 6.0)
const GUST_MIN: = 0.25
const SPAWN_MIN: = 0.9
const SPAWN_MAX: = 0.25
const LOW_FADE: = 0.25


const PILE_CELL: = 5.0
const SEED_RADIUS: = 16.0
const PILE_CHANCE: = 0.5
const MAX_PILES: = 8
const LINE_PILE_RADIUS: = 10.0
const LEAVES_MIN: = 8
const LEAVES_MAX: = 14
const LEAF_SIZE: = 0.24
const PETAL_SIZE: = 0.17
const LEAF_CAP: = MAX_PILES * LEAVES_MAX
const FLUTTER_HZ: = 7.0
const LIFT_DIST_MIN: = 3.0
const LIFT_DIST_MAX: = 7.0
const AIR_TIME_MIN: = 1.2
const AIR_TIME_MAX: = 1.9
const AIR_HEIGHT: = 1.1
const AIR_SWIRL: = 0.45
const SKITTER_RATE: = 0.12
const SKITTER_DIST_MIN: = 0.3
const SKITTER_DIST_MAX: = 0.9
const SKITTER_TIME: = 0.4
const PILE_FADE_IN: = 0.4





class Streak:
	var origin: = Vector3.ZERO
	var fwd: = Vector3.RIGHT
	var side: = Vector3.FORWARD
	var speed: = 4.0
	var amp: = 0.2
	var freq: = 2.0
	var phase: = 0.0
	var vert_amp: = 0.12
	var vert_freq: = 2.0
	var phase2: = 0.0
	var trail: = 0.55
	var life: = 1.25
	var age: = 0.0
	var loop: = false

	func point(t: float) -> Vector3:
		var th: = TAU * freq * t + phase
		var along: = speed * t
		if loop:


			along += amp * cos(th)
		return origin + fwd * along + side * (amp * sin(th))\
		+ Vector3.UP * (vert_amp * sin(TAU * vert_freq * t + phase2))


	func loops() -> bool:
		return loop and amp * TAU * freq > speed


	func head_t() -> float:
		return age



	func tail_t() -> float:
		var lag: = trail
		var retract_from: = life - trail
		if age > retract_from:
			lag *= clampf(1.0 - (age - retract_from) / trail, 0.0, 1.0)
		return clampf(age - lag, 0.0, age)

	func retracting() -> bool:
		return age > life - trail



	func envelope() -> float:
		var x: = clampf(age / life, 0.0, 1.0)
		var fade_out: = 1.0 - trail / life
		return smoothstep(0.0, 0.1, x) * (1.0 - smoothstep(fade_out, 1.0, x))





class Leaf:
	enum State{REST, AIR}

	var state: = State.REST
	var pos: = Vector3.ZERO
	var home: = Vector3.ZERO
	var ground: = 0.0
	var start: = Vector3.ZERO
	var land: = Vector3.ZERO
	var t: = 0.0
	var dur: = 0.0
	var arc: = 0.0
	var swirl: = 0.0
	var side: = Vector3.FORWARD
	var phase: = 0.0
	var spin: = 5.0
	var spin2: = 3.0
	var yaw: = 0.0
	var tilt: = -1.25
	var variant: = 0
	var tint: = 1.0
	var grow: = 0.0
	var pending_lift: = false
	var delay: = 0.0



	func begin_air(from: Vector3, to: Vector3, dur_s: float, arc_h: float, swirl_a: float, 
			side_v: Vector3, ph: float) -> void :
		state = State.AIR
		start = from
		land = to
		pos = from
		t = 0.0
		dur = maxf(dur_s, 0.01)
		arc = arc_h
		swirl = swirl_a
		side = side_v
		phase = ph


	func advance(delta: float) -> void :
		t += delta
		if state == State.REST:
			pos = home
			return
		if t >= dur:
			state = State.REST
			home = land
			pos = land
			ground = land.y
			return
		var f: = clampf(t / dur, 0.0, 1.0)
		var p: = start.lerp(land, f)
		p.y += arc * sin(PI * f)
		p += side * (swirl * sin(TAU * 1.25 * f + phase))
		pos = p



class Pile:
	var anchor: = Vector3.ZERO
	var leaves: Array = []
	var age: = 0.0
	var lifted: = false


var _streaks: Array[Streak] = []
var _piles: = {}
var _im: ImmediateMesh
var _lines: MeshInstance3D
var _leaf_mm: Array = []
var _leaf_scale: = LEAF_SIZE
var _buckets: = [0, 0, 0, 0, 0, 0]
var _theme_id: = ""
var _streamer: Node
var _rng: = RandomNumberGenerator.new()
var _timer: = 0.0


func _ready() -> void :
	_rng.randomize()
	_im = ImmediateMesh.new()
	_lines = MeshInstance3D.new()
	_lines.mesh = _im
	_lines.material_override = _line_material()
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lines)
	_build_leaf_meshes(_theme())


func _exit_tree() -> void :
	_clear()



func _line_material() -> StandardMaterial3D:
	var m: = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = Color(1, 1, 1, 1)
	return m


func _process(delta: float) -> void :
	_watch_zone()
	var w: = _wind()
	var g: float = w.gust() if w != null else 0.0
	var high: = _high()


	_timer -= delta
	if emit_ok(g, high) and _timer <= 0.0 and _streaks.size() < STREAKS:
		_spawn(w)
	if not high:
		_fast_fade()
	_advance(delta)
	_draw()
	_update_piles(delta, g, high, w)
	_render_leaves()


func _advance(delta: float) -> void :
	for i in range(_streaks.size() - 1, -1, -1):
		_streaks[i].age += delta
		if not line_alive(_streaks[i].age, _streaks[i].life):
			_streaks.remove_at(i)




static func line_alive(age: float, life: float) -> bool:
	return age < life



func _fast_fade() -> void :
	for s in _streaks:
		s.life = minf(s.life, s.age + LOW_FADE)



func _spawn(w: Node) -> void :
	_timer = lerpf(SPAWN_MIN, SPAWN_MAX, w.gust()) * _rng.randf_range(0.7, 1.3)
	_spawn_at(_spawn_origin(), w)




func _spawn_origin() -> Vector3:
	var focus: = _focus()
	var d: = _wind_dir()
	var fwd: = Vector3(d.x, 0.0, d.y).normalized()
	var lat: = Vector3(fwd.z, 0.0, - fwd.x)
	var near: Array = []
	for key in _piles:
		var p: Pile = _piles[key]
		if Vector2(p.anchor.x - focus.x, p.anchor.z - focus.z).length() <= LINE_PILE_RADIUS:
			near.append(p)
	if not near.is_empty() and _rng.randf() < 0.6:
		return (near[_rng.randi() % near.size()] as Pile).anchor + Vector3.UP * _rng.randf_range(0.1, 0.4)
	var at: = focus + lat * _rng.randf_range( - SPREAD.x, SPREAD.x)\
	+ fwd * _rng.randf_range( - SPREAD.z * 0.4, SPREAD.z)
	return Vector3(at.x, _ground(at, focus.y) + _rng.randf_range(LOW_HEIGHT_MIN, LOW_HEIGHT_MAX), at.z)


func _spawn_at(origin: Vector3, w: Node) -> void :
	if _streaks.size() >= STREAKS:
		return
	var focus: = _focus()
	var d: = _wind_dir()
	var fwd: = Vector3(d.x, 0.0, d.y).normalized()


	var to_cam: = (_camera_pos() - focus).normalized()
	var side: = fwd.cross(to_cam)
	side = side.normalized() if side.length_squared() > 1e-06 else Vector3(0.0, -1.0, 0.0)
	var s: = Streak.new()
	s.origin = origin
	s.fwd = fwd
	s.side = side
	s.speed = SPEED
	s.trail = TRAIL_TIME
	s.freq = _rng.randf_range(WAVE_FREQ_MIN, WAVE_FREQ_MAX)

	s.loop = _rng.randf() < LOOP_CHANCE
	var ratio: = _rng.randf_range(1.35, 1.8) if s.loop else _rng.randf_range(0.35, 0.75)
	s.amp = minf(SPEED * ratio / (TAU * s.freq), LOOP_RADIUS_MAX)
	s.phase = _rng.randf() * TAU
	s.vert_amp = VERT_AMP * _rng.randf_range(0.5, 1.4)
	s.vert_freq = s.freq * _rng.randf_range(0.5, 1.5)
	s.phase2 = _rng.randf() * TAU
	s.life = LIFE * _rng.randf_range(0.85, 1.15)
	_streaks.append(s)



func _draw() -> void :
	_im.clear_surfaces()
	if _streaks.is_empty():
		return
	var cam: = _camera_pos()
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in _streaks:
		_emit(s, cam)
	_im.surface_end()


func _emit(s: Streak, cam: Vector3) -> void :
	var head: = s.head_t()
	var tail: = s.tail_t()
	if head - tail < 0.0001:
		return

	var pos: Array[Vector3] = []
	var half: Array[float] = []
	var alpha: Array[float] = []
	var side: Array[Vector3] = []
	for i in SEGMENTS + 1:
		var f: = float(i) / float(SEGMENTS)
		var t: = lerpf(tail, head, f)
		var p: = s.point(t)
		var dt: = 0.01
		var tangent: = s.point(t + dt) - s.point(maxf(t - dt, 0.0))
		if tangent.length_squared() < 1e-08:
			tangent = s.fwd
		var view: = cam - p
		var sd: = tangent.cross(view)
		if sd.length_squared() < 1e-06:
			sd = tangent.cross(Vector3.UP)
		if sd.length_squared() < 1e-06:
			sd = s.side
		pos.append(p)
		side.append(sd.normalized())
		half.append(WIDTH * smoothstep(0.0, 0.3, f) * (1.0 - 0.35 * smoothstep(0.75, 1.0, f)))
		alpha.append(OPACITY * s.envelope() * (0.08 + 0.92 * f))
	for i in SEGMENTS:
		_quad(pos[i], side[i], half[i], alpha[i], pos[i + 1], side[i + 1], half[i + 1], alpha[i + 1])



func _quad(p0: Vector3, s0: Vector3, w0: float, a0: float, 
		p1: Vector3, s1: Vector3, w1: float, a1: float) -> void :
	var l0: = p0 - s0 * w0
	var r0: = p0 + s0 * w0
	var l1: = p1 - s1 * w1
	var r1: = p1 + s1 * w1
	var c0: = Color(1, 1, 1, 0.0)
	var c1: = Color(1, 1, 1, 0.0)
	var m0: = Color(1, 1, 1, a0)
	var m1: = Color(1, 1, 1, a1)
	_tri(l0, c0, p0, m0, p1, m1)
	_tri(l0, c0, p1, m1, l1, c1)
	_tri(p0, m0, r0, c0, r1, c1)
	_tri(p0, m0, r1, c1, p1, m1)


func _tri(a: Vector3, ca: Color, b: Vector3, cb: Color, c: Vector3, cc: Color) -> void :
	_im.surface_set_color(ca)
	_im.surface_add_vertex(a)
	_im.surface_set_color(cb)
	_im.surface_add_vertex(b)
	_im.surface_set_color(cc)
	_im.surface_add_vertex(c)



func _clear() -> void :
	_streaks.clear()
	_piles.clear()
	_im.clear_surfaces()
	_hide_leaves()





func _build_leaf_meshes(theme_id: String) -> void :
	for n in _leaf_mm:
		if is_instance_valid(n):
			n.queue_free()
	_leaf_mm.clear()
	_theme_id = theme_id
	_leaf_scale = PETAL_SIZE if theme_id == "petal_pink" else LEAF_SIZE
	var quad: = QuadMesh.new()
	quad.size = Vector2.ONE
	for v in 3:
		var strip: Texture2D = load("res://assets/textures/fx/%s_%d.png" % [theme_id, v])
		if strip == null:
			continue
		var frame: = strip.get_width() / 2
		for f in 2:
			var at: = AtlasTexture.new()
			at.atlas = strip
			at.region = Rect2(f * frame, 0, frame, frame)
			var m: = StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.albedo_texture = at
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			m.vertex_color_use_as_albedo = true
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			var mm: = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = quad
			mm.instance_count = LEAF_CAP
			mm.visible_instance_count = 0
			var mi: = MultiMeshInstance3D.new()
			mi.multimesh = mm
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_leaf_mm.append(mi)


func _hide_leaves() -> void :
	for mi in _leaf_mm:
		if is_instance_valid(mi):
			mi.multimesh.visible_instance_count = 0



func _update_piles(delta: float, g: float, high: bool, w: Node) -> void :
	var focus: = _focus()
	var lifting: = lift_ok(g, high)
	var d: = _wind_dir()
	var strength: float = w.strength if w != null else 1.0
	var cell: = Vector2i(floori(focus.x / PILE_CELL), floori(focus.z / PILE_CELL))
	var reach: = int(ceil(SEED_RADIUS / PILE_CELL))


	for key in _piles.keys():
		var p: Pile = _piles[key]
		if Vector2(p.anchor.x - focus.x, p.anchor.z - focus.z).length() > SEED_RADIUS + PILE_CELL:
			_piles.erase(key)

	if _piles.size() < MAX_PILES:
		var cells: Array = []
		for dz in range( - reach, reach + 1):
			for dx in range( - reach, reach + 1):
				var key: = cell + Vector2i(dx, dz)
				if _piles.has(key):
					continue
				var center: = Vector3((key.x + 0.5) * PILE_CELL, 0.0, (key.y + 0.5) * PILE_CELL)
				var dist: = Vector2(center.x - focus.x, center.z - focus.z).length()
				if dist <= SEED_RADIUS:
					cells.append([dist, key, center])
		cells.sort_custom( func(a, b): return a[0] < b[0])
		for c in cells:
			if _piles.size() >= MAX_PILES:
				break
			var pile: = _try_seed(c[1], c[2], focus)
			if pile != null:
				_piles[c[1]] = pile
	for key in _piles.keys():
		var pile: Pile = _piles[key]
		pile.age += delta
		if lifting and not pile.lifted:
			pile.lifted = true
			for leaf in pile.leaves:
				leaf.pending_lift = true
				leaf.delay = _rng.randf_range(0.0, 0.5)
			_spawn_at(pile.anchor + Vector3.UP * 0.15, w)
		elif not lifting:
			pile.lifted = false
		for leaf in pile.leaves:
			leaf.grow = minf(1.0, leaf.grow + delta / PILE_FADE_IN)
			if leaf.state == Leaf.State.REST:
				if leaf.pending_lift:
					leaf.delay -= delta
					if leaf.delay <= 0.0:
						leaf.pending_lift = false
						_lift(leaf, d, g)
				elif not lifting and _rng.randf() < SKITTER_RATE * strength * delta:
					_skitter(leaf, d)
			leaf.advance(delta)



func _try_seed(key: Vector2i, center: Vector3, focus: Vector3) -> Pile:
	var rng: = RandomNumberGenerator.new()
	rng.seed = _cell_seed(key)
	if rng.randf() > PILE_CHANCE:
		return null
	var pos: = center + Vector3(rng.randf_range( - PILE_CELL * 0.4, PILE_CELL * 0.4), 0.0, 
		rng.randf_range( - PILE_CELL * 0.4, PILE_CELL * 0.4))
	if not _spot_ok(pos):
		return null
	var gy: = _ground(pos, focus.y)
	pos.y = gy
	var pile: = Pile.new()
	pile.anchor = pos
	var n: = rng.randi_range(LEAVES_MIN, LEAVES_MAX)
	for i in n:
		var leaf: = Leaf.new()
		var off: = Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35))
		leaf.home = Vector3(pos.x + off.x, 0.0, pos.z + off.z)
		leaf.home.y = _ground(leaf.home, gy) + 0.02
		leaf.pos = leaf.home
		leaf.ground = leaf.home.y
		leaf.variant = rng.randi() % 3
		leaf.yaw = rng.randf() * TAU
		leaf.tilt = deg_to_rad(rng.randf_range(-82.0, -58.0))
		leaf.phase = rng.randf() * TAU
		leaf.spin = rng.randf_range(3.0, 7.0)
		leaf.spin2 = rng.randf_range(2.0, 6.0)
		leaf.tint = rng.randf_range(0.85, 1.05)
		leaf.grow = 0.0
		pile.leaves.append(leaf)
	return pile


func _cell_seed(key: Vector2i) -> int:
	return (key.x * 73856093) ^ (key.y * 19349663) ^ hash(_theme_id)



func _spot_ok(pos: Vector3) -> bool:
	var game: = get_node_or_null("/root/Game")
	if game != null and game.surface_at(pos.x, pos.z) != Water.Surface.GROUND:
		return false
	if _streamer == null:
		return true
	for id in _streamer.loaded:
		var zn: Node = _streamer.loaded[id]
		var wd: Node = zn.get_node_or_null("World") if is_instance_valid(zn) else null
		if wd == null or not wd.data:
			continue
		for r in wd.data.paths:
			if pos.x > r[0] - 0.3 and pos.x < r[0] + r[2] + 0.3\
			and pos.z > r[1] - 0.3 and pos.z < r[1] + r[3] + 0.3:
				return false
		for b in wd.data.buildings:
			if absf(pos.x - b.pos[0]) < 6.0 and absf(pos.z - b.pos[1]) < 5.5:
				return false
	return true



func _lift(leaf: Leaf, dir: Vector2, g: float) -> void :
	var lateral: = Vector2( - dir.y, dir.x)
	var dist: = _rng.randf_range(LIFT_DIST_MIN, LIFT_DIST_MAX) * (0.7 + 0.6 * g)
	var land_xz: = Vector2(leaf.pos.x, leaf.pos.z) + dir * dist + lateral * _rng.randf_range(-1.0, 1.0)
	var game: = get_node_or_null("/root/Game")
	for i in 4:
		if game == null or game.surface_at(land_xz.x, land_xz.y) == Water.Surface.GROUND:
			break
		land_xz = Vector2(leaf.pos.x, leaf.pos.z) + dir * (dist * (1.0 - 0.25 * (i + 1)))
	var land: = Vector3(land_xz.x, _ground(Vector3(land_xz.x, 0.0, land_xz.y), leaf.ground), land_xz.y)
	leaf.begin_air(leaf.pos, land, _rng.randf_range(AIR_TIME_MIN, AIR_TIME_MAX), 
		AIR_HEIGHT * _rng.randf_range(0.7, 1.2), AIR_SWIRL * _rng.randf_range(0.6, 1.3), 
		Vector3(lateral.x, 0.0, lateral.y), _rng.randf() * TAU)



func _skitter(leaf: Leaf, dir: Vector2) -> void :
	var dist: = _rng.randf_range(SKITTER_DIST_MIN, SKITTER_DIST_MAX)
	var land: = leaf.pos + Vector3(dir.x, 0.0, dir.y) * dist\
	+ Vector3(_rng.randf_range(-0.2, 0.2), 0.0, _rng.randf_range(-0.2, 0.2))
	land.y = _ground(land, leaf.ground)
	leaf.begin_air(leaf.pos, land, SKITTER_TIME * _rng.randf_range(0.8, 1.2), 0.12, 0.08, 
		Vector3( - dir.y, 0.0, dir.x), _rng.randf() * TAU)



func _render_leaves() -> void :
	if _leaf_mm.is_empty():
		return
	for i in _buckets.size():
		_buckets[i] = 0
	for key in _piles:
		var pile: Pile = _piles[key]
		for leaf in pile.leaves:
			var b: int = leaf.variant * 2 + _leaf_frame(leaf)
			if b >= _leaf_mm.size() or _buckets[b] >= LEAF_CAP:
				continue
			_leaf_mm[b].multimesh.set_instance_transform(_buckets[b], _leaf_xform(leaf))
			_leaf_mm[b].multimesh.set_instance_color(_buckets[b], Color(leaf.tint, leaf.tint, leaf.tint))
			_buckets[b] += 1
	for i in _leaf_mm.size():
		_leaf_mm[i].multimesh.visible_instance_count = _buckets[i]



func _leaf_frame(leaf: Leaf) -> int:
	var hz: = FLUTTER_HZ if leaf.state == Leaf.State.AIR else 1.6
	return int(leaf.t * hz + leaf.phase) % 2


func _leaf_xform(leaf: Leaf) -> Transform3D:
	var s: = _leaf_scale * maxf(leaf.grow, 0.001)
	var basis: Basis
	if leaf.state == Leaf.State.AIR:
		basis = Basis(Vector3.UP, leaf.yaw + leaf.t * leaf.spin)\
		* Basis(Vector3.RIGHT, leaf.t * leaf.spin2 + leaf.phase)
	else:

		basis = Basis(Vector3.UP, leaf.yaw) * Basis(Vector3.RIGHT, leaf.tilt)
	var flip: = -1.0 if _leaf_frame(leaf) == 1 else 1.0
	basis = basis.scaled(Vector3(s * flip, s, s))
	return Transform3D(basis, leaf.pos)




static func emit_ok(gust: float, high: bool) -> bool:
	return high and gust > GUST_MIN



static func lift_ok(gust: float, high: bool) -> bool:
	return high and gust > GUST_MIN


func _watch_zone() -> void :
	if _streamer == null:
		_streamer = get_tree().get_first_node_in_group("zone_streamer")
		if _streamer != null:
			_streamer.zone_changed.connect(_on_zone_changed)

			_retint()
	elif _theme() != _theme_id:
		_retint()



func _retint() -> void :
	var t: = _theme()
	if t != _theme_id:
		_clear()
		_build_leaf_meshes(t)



func _on_zone_changed(_id: String, _name: String) -> void :
	_clear()
	_retint()


func _focus() -> Vector3:
	var rig: = get_tree().get_first_node_in_group("camera_rig") as Node3D
	return rig.global_position if rig != null else Vector3.ZERO


func _camera_pos() -> Vector3:
	var cam: = get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam != null else _focus() + Vector3(0, 8, 12)


func _wind() -> Node:
	return get_tree().get_first_node_in_group("wind")


func _wind_dir() -> Vector2:
	var w: = _wind()
	return w.dir if w != null else Vector2(1, 0)



func _ground(pos: Vector3, fallback: float) -> float:
	var game: = get_node_or_null("/root/Game")
	return game.ground_y(pos, fallback) if game != null else fallback



func _high() -> bool:
	var s: = get_node_or_null("/root/Settings")
	return s == null or s.is_high()




func _theme() -> String:
	var zid: = ""
	if _streamer != null:
		zid = _streamer.active
	match zid:
		"pallet_town":
			return "petal_pink"
		"viridian_forest":
			return "leaf_green"
		_:
			return "leaf_autumn"
