extends Node3D


































const GRID: = 3
const CELL: = 15.0


const GRID_BIAS: = Vector3(0.0, 0.0, -4.0)
const HEIGHT: = 2.0
const BOX_Y: = 2.0
const FLAKES_HIGH: = 2160
const FLAKES_LOW: = 540
const FALL_MIN: = 0.9
const FALL_MAX: = 1.15
const WIND_K: = 0.6
const WIND_GUST_K: = 0.6
const SWAY: = 0.35
const SWAY_HZ: = 0.5
const EMIT_EPS: = 0.04
const FLAKE_SIZE: = 0.13
const SCALE_MIN: = 1.0
const SCALE_MAX: = 1.55
const FLAKE_COLOR: = Color(0.957, 0.973, 1.0)
const FLAKE_ALPHA: = 0.98
const LIFETIME: = 5.0
const WIND_SLOT: = "sfx/ambience/amb_snow"
const WIND_DB: = -14.0
const DUCK: = 0.25


var _emitters: Array[CPUParticles3D] = []
var _offsets: Array[Vector3] = []
var _phase: PackedFloat32Array = []
var _amounts: PackedInt32Array = []
var _on: Array[bool] = []

var _mesh: QuadMesh
var _rig: Node3D
var _weather: Node
var _wind_node: Node
var _wind_player: AudioStreamPlayer
var _time: = 0.0
var _cover: = 0.0
var _amb_idx: = -1
var _amb_base_db: = 0.0
var _amb_ducked: = false
var _duck_applied: = 0.0


func _ready() -> void :
	add_to_group("snowfall")
	_mesh = _build_mesh()
	for gx in GRID:
		for gz in GRID:
			var off: = Vector3((gx - (GRID - 1) * 0.5) * CELL, HEIGHT, (gz - (GRID - 1) * 0.5) * CELL)
			_offsets.append(off)
			_emitters.append(_build_emitter(off))
			_phase.append(randf() * TAU)
			_amounts.append(-1)
			_on.append(false)
	_amb_idx = AudioServer.get_bus_index("Ambience")
	_start_wind()





func _build_mesh() -> QuadMesh:
	var g: = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex: = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var m: = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.fog_enabled = false
	m.albedo_color = Color(FLAKE_COLOR.r, FLAKE_COLOR.g, FLAKE_COLOR.b, FLAKE_ALPHA)
	m.albedo_texture = tex
	m.emission_enabled = true
	m.emission = FLAKE_COLOR
	m.emission_energy_multiplier = 0.35
	var q: = QuadMesh.new()
	q.size = Vector2(FLAKE_SIZE, FLAKE_SIZE)
	q.material = m
	return q


func _build_emitter(off: Vector3) -> CPUParticles3D:
	var e: = CPUParticles3D.new()
	e.position = off
	e.emitting = false
	e.amount = 1
	e.lifetime = LIFETIME
	e.preprocess = LIFETIME
	e.local_coords = false
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.visibility_aabb = AABB(Vector3( - CELL * 1.5, - HEIGHT - BOX_Y, - CELL * 1.5), 
		Vector3(CELL * 3.0, 2.0 * (HEIGHT + BOX_Y), CELL * 3.0))
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	e.emission_box_extents = Vector3(CELL * 0.5, BOX_Y, CELL * 0.5)
	e.gravity = Vector3.ZERO
	e.direction = Vector3(0, -1, 0)
	e.spread = 8.0
	e.initial_velocity_min = FALL_MIN
	e.initial_velocity_max = FALL_MAX
	e.scale_amount_min = SCALE_MIN
	e.scale_amount_max = SCALE_MAX

	var ramp: = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.85, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), 
		Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	e.color_ramp = ramp
	e.mesh = _mesh
	add_child(e)
	return e


func _process(delta: float) -> void :
	_time += delta
	var rig: = _rig_node()
	if rig != null:
		global_position = rig.global_position + GRID_BIAS
	var wind: = _wind()
	var dir: = Vector2(1.0, -0.35).normalized()
	var gust: = 0.0
	if wind != null:
		dir = wind.dir
		gust = wind.gust()
	var w: = WIND_K + WIND_GUST_K * gust
	_cover = _coverage(rig.global_position if rig != null else global_position)
	var high: = _high()
	var per: = int(round((FLAKES_HIGH if high else FLAKES_LOW) / float(_emitters.size())))
	for i in _emitters.size():
		var e: = _emitters[i]
		var cov: = _coverage(global_position + _offsets[i])
		var amount: = int(round(per * clampf(cov, 0.0, 1.0)))
		var on: = cov > EMIT_EPS

		if amount != _amounts[i]:
			_amounts[i] = amount
			e.amount = maxi(amount, 1)
		if on and not _on[i]:
			e.emitting = true
			e.restart()
		elif not on:
			e.emitting = false
		_on[i] = on
		var ph: float = _phase[i]
		var sway: = Vector2(sin(_time * TAU * SWAY_HZ + ph), 
			cos(_time * TAU * SWAY_HZ * 0.7 + ph * 1.7)) * SWAY
		e.direction = Vector3(dir.x * w + sway.x, -1.0, dir.y * w + sway.y).normalized()
	_update_wind(_cover)
	_update_duck(_cover)




func _start_wind() -> void :
	var audio: = get_node_or_null("/root/Audio")
	if audio == null:
		return
	var st: AudioStream = audio.stream(WIND_SLOT)
	if st == null:
		return
	_wind_player = AudioStreamPlayer.new()
	_wind_player.bus = "SFX"
	_wind_player.stream = st
	_wind_player.volume_db = -80.0
	add_child(_wind_player)



func _update_wind(cov: float) -> void :
	if _wind_player == null:
		return
	if cov > EMIT_EPS:
		if not _wind_player.playing:
			_wind_player.play()
		_wind_player.volume_db = WIND_DB + linear_to_db(clampf(cov, 0.0, 1.0))
	elif _wind_player.playing:
		_wind_player.stop()




func _update_duck(cov: float) -> void :
	if _amb_idx == -1:
		return
	var target: = clampf(cov, 0.0, 1.0) * DUCK
	if not _amb_ducked and target > 0.001:
		_amb_base_db = AudioServer.get_bus_volume_db(_amb_idx)
		_amb_ducked = true
	if not _amb_ducked:
		return
	if target <= 0.001:
		AudioServer.set_bus_volume_db(_amb_idx, _amb_base_db)
		_amb_ducked = false
		_duck_applied = 0.0
	elif absf(target - _duck_applied) > 0.001:
		_duck_applied = target
		AudioServer.set_bus_volume_db(_amb_idx, _amb_base_db + linear_to_db(1.0 - target))


func _exit_tree() -> void :
	if _amb_ducked and _amb_idx != -1:
		AudioServer.set_bus_volume_db(_amb_idx, _amb_base_db)




func _high() -> bool:
	var s: = get_node_or_null("/root/Settings")
	return s == null or s.is_high()


func _rig_node() -> Node3D:
	if not is_instance_valid(_rig):
		_rig = get_tree().get_first_node_in_group("camera_rig") as Node3D
	return _rig


func _wind() -> Node:
	if not is_instance_valid(_wind_node):
		_wind_node = get_tree().get_first_node_in_group("wind")
	return _wind_node


func _coverage(pos: Vector3) -> float:
	if not is_instance_valid(_weather):
		_weather = get_tree().get_first_node_in_group("weather")
	if _weather == null:
		return 0.0
	return float(_weather.coverage_at(pos)["snow"])



func emit_count() -> int:
	var n: = 0
	for e in _emitters:
		if e.emitting:
			n += 1
	return n



func flake_count() -> int:
	var n: = 0
	for e in _emitters:
		if e.emitting:
			n += e.amount
	return n



func coverage() -> float:
	return _cover


func wind_db() -> float:
	return _wind_player.volume_db if _wind_player != null else -80.0


func wind_playing() -> bool:
	return _wind_player != null and _wind_player.playing
