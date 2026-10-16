extends Node3D





const Dex: = preload("res://scripts/dex.gd")

const HIT_OFFSET: = 0.6

var user: Node
var mv: Dictionary
var vel: = Vector3.ZERO
var homing: = false
var speed: = 12.0
var range_m: = 10.0
var turn: = 4.0
var target: Node3D

var miss_target: Node



var hide_body: = false
var legacy_fx: = true
var _travelled: = 0.0
var _col: = Color.WHITE
var _moves: Node
var _vfx: Node
var _audio: Node


var _bsp: = 1.0
var fx: = ""
var _started: = false
var _lob_from_y: = 0.0
var _lob_to_y: = 0.0
var _lob_dist: = 1.0
var _spin_axis: = Vector3.RIGHT
var _bubble_t: = 0.0
var _hit_done: = false
var _rings: Array = []
var _strand_segs: Array = []
var _strand_mat: StandardMaterial3D


func setup(u: Node, m: Dictionary, dir: Vector3, is_homing: bool) -> void :
	user = u
	mv = m
	homing = is_homing
	speed = float(m.get("speed", 12.0))
	range_m = float(m.get("range", 10.0))
	turn = float(m.get("turn", 4.0))
	fx = String(m.get("fx", ""))
	vel = dir * speed
	_col = Dex.type_color(m.get("type", "normal"))


func _ready() -> void :
	_moves = get_node("/root/Moves")
	_vfx = get_node("/root/Vfx")
	_audio = get_node_or_null("/root/Audio")
	var b: = get_node_or_null("/root/Battle")
	_bsp = b.fight_speed() if b else 1.0
	if not hide_body:
		match fx:
			"rock":
				_build_rock()
			"silk":
				_build_silk()
			"bubble":
				_build_bubble()
			"rings":
				_build_rings()
			_:
				_build_generic()
	if is_instance_valid(user):
		if is_instance_valid(user.opponent):
			target = user.opponent
		else:
			var ts: Array = _moves.targets_of(user)
			target = ts[0] if not ts.is_empty() else null


func _unshaded(col: Color) -> StandardMaterial3D:
	var m: = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	return m


func _build_generic() -> void :
	var mi: = MeshInstance3D.new()
	var r: = 0.12 if homing else 0.17
	if mv.get("type", "") == "grass" or mv.get("category", "") == "status":
		r = 0.12
	var sm: = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	sm.material = _unshaded(_col.lightened(0.35))
	mi.mesh = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	add_child(_vfx.make_trail(_col))



func _build_rock() -> void :
	var piece: Dictionary = _vfx.rock_piece(self, 0.45, false, false)
	if piece.is_empty() or not is_instance_valid(piece.get("inst")):
		_build_generic()
		return
	_spin_axis = Vector3(0.5, 1.0, 0.3).normalized()



func _build_silk() -> void :
	_strand_mat = _unshaded(Color(0.957, 0.945, 0.902))
	_strand_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tip: = MeshInstance3D.new()
	var sm: = SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = _strand_mat
	tip.mesh = sm
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tip)
	for i in 5:
		var seg: = MeshInstance3D.new()
		var cm: = CylinderMesh.new()
		cm.top_radius = 0.025
		cm.bottom_radius = 0.025
		cm.height = 1.0
		cm.radial_segments = 5
		cm.material = _strand_mat
		seg.mesh = cm
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(seg)
		_strand_segs.append(seg)



func _build_bubble() -> void :
	var mi: = MeshInstance3D.new()
	var sm: = SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	sm.radial_segments = 16
	sm.rings = 8
	var m: = StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.8, 1.0, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	m.metallic_specular = 0.9
	sm.material = m
	mi.mesh = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var dot: = MeshInstance3D.new()
	var dm: = SphereMesh.new()
	dm.radius = 0.05
	dm.height = 0.1
	dm.radial_segments = 6
	dm.rings = 3
	dm.material = _unshaded(Color(1, 1, 1, 0.9))
	dot.mesh = dm
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dot.position = Vector3(0.1, 0.12, 0.1)
	add_child(dot)



func _build_rings() -> void :
	for i in 5:
		var mi: = MeshInstance3D.new()
		var tm: = TorusMesh.new()
		tm.inner_radius = 0.9
		tm.outer_radius = 1.0
		tm.rings = 24
		tm.ring_segments = 6
		var m: = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.965, 0.784, 0.9)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tm.material = m
		mi.mesh = tm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation.x = PI / 2.0
		mi.position = Vector3(0, 0, - speed * 0.07 * float(i))
		add_child(mi)
		_rings.append({"mi": mi, "mat": m, "i": i})
	rotation.y = atan2(vel.x, vel.z)


func _physics_process(delta: float) -> void :
	if not is_instance_valid(user):
		queue_free()
		return
	var d: = delta * _bsp
	if not _started:
		_started = true



		_lob_from_y = global_position.y
		_lob_to_y = global_position.y
		_lob_dist = maxf(range_m, 0.01)
		if is_instance_valid(target) and target.alive():


			var aim_h: = HIT_OFFSET
			if target.has_method("look_height"):
				aim_h = target.look_height() * 0.4
			var aim: = target.global_position + Vector3(0, aim_h, 0)
			_lob_to_y = aim.y
			_lob_dist = maxf(Vector2(aim.x - global_position.x, aim.z - global_position.z).length(), 0.01)


			if not homing:
				var flat: = Vector3(vel.x, 0.0, vel.z)
				var hspeed: = flat.length()
				if hspeed > 0.01:
					vel.y = (aim.y - global_position.y) / maxf(_lob_dist / hspeed, 0.05)
	if homing and is_instance_valid(target) and target.alive():
		var aim_y: = HIT_OFFSET
		if target.has_method("look_height"):
			aim_y = target.look_height() * 0.4
		var want: = (target.global_position + Vector3(0, aim_y, 0) - global_position).normalized() * speed
		vel = vel.lerp(want, clampf(turn * d, 0.0, 1.0)).normalized() * speed
	var step: = vel * d
	match fx:
		"rock":
			global_position.x += step.x
			global_position.z += step.z
			_travelled += Vector2(step.x, step.z).length()
			var p: = clampf(_travelled / maxf(_lob_dist, 0.01), 0.0, 1.0)
			global_position.y = lerpf(_lob_from_y, _lob_to_y, p) + sin(p * PI) * 1.2
			rotate_object_local(_spin_axis, d * 9.0)
		"bubble":
			vel = vel.normalized() * maxf(vel.length() - 20.0 * d, 2.0)
			global_position += vel * d
			_travelled += vel.length() * d
			_bubble_t += d
			var w: = 1.0 + 0.08 * sin(_bubble_t * 10.0)
			scale = Vector3(w, 1.0 + 0.08 * sin(_bubble_t * 10.0 + 2.0), w)
		"rings":
			global_position += step
			_travelled += step.length()
			_update_rings()
		"silk":
			global_position += step
			_travelled += step.length()
			_update_silk()
		_:
			global_position += step
			_travelled += step.length()
	if fx != "rings" or not _hit_done:
		for t in _moves.targets_of(user):
			if t == miss_target:
				continue
			var th: = HIT_OFFSET
			if t.has_method("look_height"):
				th = t.look_height() * 0.4
			if (t.global_position + Vector3(0, th, 0)).distance_to(global_position) < 0.75:
				_moves.hit(user, t, mv, vel.normalized())
				if fx == "rings":
					_hit_done = true
				else:
					_on_hit(t)
					return
	if _travelled > range_m:
		_on_end()


func _on_hit(t: Node) -> void :
	if fx == "silk":
		if legacy_fx:
			_vfx.silk_wrap(t)
		_end_silk()
	elif fx == "bubble":
		_end()
	elif legacy_fx:
		_vfx.burst(global_position, _col, 16)
		queue_free()
	else:
		queue_free()


func _on_end() -> void :
	if fx == "silk":
		_end_silk()
	else:
		_end()


func _end() -> void :
	if fx == "bubble":
		if is_instance_valid(_audio):
			_audio.play_at("sfx/moves/launch_water", global_position, 0.0, 2.0)
		if legacy_fx:
			_vfx.bubble_pop(global_position)
	elif fx == "rock":
		if legacy_fx:
			_vfx.burst(global_position, Color(0.45, 0.4, 0.34), 10, 0.3, 2.0, 0.12, 180.0, Vector3.UP, Vector3(0, -8, 0), 0.2)
	elif legacy_fx:
		_vfx.burst(global_position, _col, 6, 0.3, 1.5)
	queue_free()



func _end_silk() -> void :
	set_physics_process(false)
	var tw: = Battle.fight_tween(self).set_parallel(true)
	tw.tween_property(_strand_mat, "albedo_color:a", 0.0, 0.15)
	for seg in _strand_segs:
		tw.tween_property(seg, "scale:y", 0.05, 0.15)
	tw.chain().tween_callback(queue_free)


func _update_silk() -> void :
	var mouth: Vector3 = user.global_position + Vector3(0, 0.5, 0) + vel.normalized() * 0.3
	var tip: Vector3 = global_position
	var n: = _strand_segs.size()
	for i in n:
		var s0: = float(i) / float(n)
		var s1: = float(i + 1) / float(n)
		var a: = _silk_point(mouth, tip, s0)
		var b: = _silk_point(mouth, tip, s1)
		var seg: MeshInstance3D = _strand_segs[i]
		seg.global_position = (a + b) * 0.5
		var d: = a.distance_to(b)
		seg.scale = Vector3(1, maxf(d, 0.001), 1)
		if d > 0.001:
			seg.look_at(b, Vector3.UP)
			seg.rotate_object_local(Vector3.RIGHT, PI / 2.0)


func _silk_point(mouth: Vector3, tip: Vector3, s: float) -> Vector3:
	var p: = mouth.lerp(tip, s)
	var d: = tip - mouth
	var perp: = Vector3( - d.z, 0.0, d.x)
	if perp.length() > 0.001:
		perp = perp.normalized()
	var bow: = sin(PI * s) * 0.06
	var wob: = sin(Time.get_ticks_msec() / 1000.0 * 18.0 + s * 4.0) * 0.02 * sin(PI * s)
	return p + perp * (bow + wob) + Vector3(0, - bow * 0.5, 0)


func _update_rings() -> void :
	for r in _rings:
		var mi: MeshInstance3D = r.mi
		var offset: float = speed * 0.07 * float(r.i)
		var p: = clampf((_travelled - offset) / maxf(range_m, 0.01), 0.0, 1.0)
		var rad: = lerpf(0.15, 0.9, p)
		mi.visible = _travelled >= offset
		mi.scale = Vector3(rad, rad, rad)
		var m: StandardMaterial3D = r.mat
		m.albedo_color.a = lerpf(0.9, 0.0, p)
