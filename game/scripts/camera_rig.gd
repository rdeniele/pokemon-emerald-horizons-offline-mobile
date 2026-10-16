extends Node3D



@export var target_path: NodePath
@export_range(15.0, 75.0) var pitch_deg: = 38.0
@export var distance: = 16.0
@export var battle_extra_per_meter: = 0.9
@export var follow_sharpness: = 6.0

@export var dof_band: = 3.5

@export var occluder_alpha: = 0.05
@export var occluder_half_width: = 5.0

@export var building_alpha: = 0.25

var target: Node3D
var _a: Node3D
var _b: Node3D
var _dist: = 16.0
var _shake: = 0.0
var _fixed: = false
var _fixed_at: = Vector3.ZERO
var _fixed_dist: = 16.0

var _zone_dist: = 0.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void :
	add_to_group("camera_rig")
	target = get_node_or_null(target_path) as Node3D
	_dist = distance
	if target:
		global_position = target.global_position
	_apply()



func snap() -> void :
	if is_instance_valid(target):
		global_position = target.global_position
	_dist = _base_dist()
	_apply()




func set_zone_distance(d: float) -> void :
	_zone_dist = maxf(d, 0.0)


func _base_dist() -> float:
	return _zone_dist if _zone_dist > 0.0 else distance



func shake(amount: float) -> void :
	_shake = maxf(_shake, amount)


func focus_battle(a: Node3D, b: Node3D) -> void :
	if _fixed:
		return
	_a = a
	_b = b



func focus_fixed(at: Vector3, dist: float) -> void :
	_fixed = true
	_fixed_at = at
	_fixed_dist = dist
	_a = null
	_b = null






func visible_ground(dist: float) -> Vector2:
	var p: = deg_to_rad(pitch_deg)
	var f: = deg_to_rad(camera.fov * 0.5)
	var h: = dist * sin(p)
	return Vector2(dist * cos(p) - h / tan(p + f), dist * cos(p) - h / tan(maxf(p - f, 0.05)))


func focus_follow(t: Node3D) -> void :
	_fixed = false
	_a = null
	_b = null
	target = t


func _process(delta: float) -> void :
	var focus: = global_position
	var want: = _base_dist()
	if _fixed:
		focus = _fixed_at
		want = _fixed_dist
	elif is_instance_valid(_a) and is_instance_valid(_b):
		focus = (_a.global_position + _b.global_position) * 0.5
		want = distance * 0.85 + _a.global_position.distance_to(_b.global_position) * battle_extra_per_meter
	elif is_instance_valid(target):
		focus = target.global_position
	global_position = global_position.lerp(focus, 1.0 - exp( - follow_sharpness * delta))
	_dist = lerpf(_dist, want, 1.0 - exp(-3.0 * delta))
	_apply()
	if _shake > 0.0:
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake
		_shake = maxf(_shake - delta * 2.5, 0.0)
	_fade_occluders()
	_fade_buildings(delta)





const Props: = preload("res://scripts/world/props.gd")
const FADE_RADIUS: = 18.0
var _fading: = {}


func _fade_occluders() -> void :
	var f: = global_position

	for n in get_tree().get_nodes_in_group("fade_occluder"):
		var s: = n as Sprite3D
		if s == null:
			continue
		var dz: = s.global_position.z - f.z
		var cover: = dz > 0.8 and dz < _dist and absf(s.global_position.x - f.x) < occluder_half_width
		if cover and s.alpha_cut != SpriteBase3D.ALPHA_CUT_DISABLED:
			s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			s.modulate.a = occluder_alpha
		elif not cover and s.alpha_cut == SpriteBase3D.ALPHA_CUT_DISABLED:
			s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			s.modulate.a = 1.0



func _fade_target(n: Node3D, f: Vector3) -> float:
	if n.is_in_group("fade_building") and n.has_meta("rect"):
		var r: Rect2 = n.get_meta("rect")
		var height: float = n.get_meta("height", 5.0)
		var back_z: float = n.get_meta("back_z", r.position.y)
		var tan_p: = tan(deg_to_rad(pitch_deg))
		var hidden: = f.x > r.position.x and f.x < r.end.x and f.z < back_z and f.z > back_z - height / tan_p
		return 1.0 - building_alpha if hidden else 0.0
	if _in_battle():
		return 1.0 if _in_battle_view(n, f) else 0.0
	var p: = n.global_position
	var dz: = p.z - f.z
	var cover: = dz > 0.8 and dz < _dist * 0.8
	if n.has_meta("rect"):


		var r2: Rect2 = n.get_meta("rect")
		cover = cover and f.x > r2.position.x and f.x < r2.end.x
	else:
		cover = cover and absf(p.x - f.x) < occluder_half_width
	return 1.0 - occluder_alpha if cover else 0.0




func _in_battle() -> bool:
	return _fixed or (is_instance_valid(_a) and is_instance_valid(_b))




func _in_battle_view(n: Node3D, f: Vector3) -> bool:
	var r: Rect2
	if n.has_meta("rect"):
		r = n.get_meta("rect")
	else:
		r = Rect2(n.global_position.x - 1.0, n.global_position.z - 1.0, 2.0, 2.0)
	var cam_z: = f.z + cos(deg_to_rad(pitch_deg)) * _dist
	if r.end.y < f.z + 0.5 or r.position.y > cam_z + 2.0:
		return false
	var size: = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(16, 9)

	var aspect: = maxf(size.x / maxf(size.y, 1.0), 16.0 / 9.0)
	var half_w: = _dist * tan(deg_to_rad(camera.fov) * 0.5) * aspect + 1.0
	return r.end.x > f.x - half_w and r.position.x < f.x + half_w


func _fade_buildings(delta: float) -> void :
	var f: = global_position

	var radius: = maxf(FADE_RADIUS, _dist + 4.0) if _in_battle() else FADE_RADIUS
	for n in Props.faders_near(f, radius):
		_fading[n] = true
	var eye: = camera.global_position
	var at: = target.global_position if is_instance_valid(target) else f
	for n in _fading.keys():
		if not is_instance_valid(n):
			_fading.erase(n)
			continue
		var want: = _fade_target(n, f)
		var cur: float = n.get_meta("fade", 0.0)
		var nv: = cur
		if is_equal_approx(cur, want):
			if want == 0.0:
				_fading.erase(n)
				if cur > 0.0:
					_set_fade(n, 0.0, eye, at)
				continue
		else:
			nv = move_toward(cur, want, delta * 4.0)
			n.set_meta("fade", nv)
		_set_fade(n, nv, eye, at)





func _set_fade(n: Node3D, nv: float, eye: Vector3, at: Vector3) -> void :
	var partial: = nv > 0.0 and not _in_battle() and n.is_in_group("fade_building")
	for g in n.get_meta("geoms", []):
		if not is_instance_valid(g):
			continue
		var gi: = g as GeometryInstance3D
		var a: = nv
		if partial:
			var inv: = gi.global_transform.affine_inverse()
			if gi.get_aabb().intersects_segment(inv * eye, inv * at) == null:
				a = 0.0
		gi.transparency = a
		if a > 0.0:
			if not gi.has_meta("fade_shadow"):
				gi.set_meta("fade_shadow", gi.cast_shadow)
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif gi.has_meta("fade_shadow"):
			gi.cast_shadow = gi.get_meta("fade_shadow")
			gi.remove_meta("fade_shadow")


func _apply() -> void :
	var p: = deg_to_rad(pitch_deg)
	camera.position = Vector3(0.0, sin(p) * _dist, cos(p) * _dist)
	camera.rotation = Vector3( - p, 0.0, 0.0)


	RenderingServer.global_shader_parameter_set("main_cam_pos", camera.global_position)
	var attr: = camera.attributes as CameraAttributesPractical
	if attr:
		attr.dof_blur_far_distance = _dist + dof_band
		attr.dof_blur_near_distance = maxf(_dist - dof_band, 0.5)
