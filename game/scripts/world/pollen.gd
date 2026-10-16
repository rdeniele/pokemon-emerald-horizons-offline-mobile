extends GPUParticles3D



@export var box: = Vector3(16.0, 3.0, 16.0)

var _rig: Node3D
var _pm: ParticleProcessMaterial
var _wind_node: Node
var _weather_node: Node


func _ready() -> void :
	amount = 180
	lifetime = 9.0
	preprocess = 9.0
	local_coords = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB( - box, box * 2.0)
	var pm: = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box * 0.5
	pm.gravity = Vector3(0, -0.02, 0)
	pm.direction = Vector3(1, 0.3, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.2
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	_pm = pm
	var fade: = Curve.new()
	fade.add_point(Vector2(0.0, 0.0))
	fade.add_point(Vector2(0.2, 1.0))
	fade.add_point(Vector2(0.8, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	var ct: = CurveTexture.new()
	ct.curve = fade
	pm.alpha_curve = ct
	process_material = pm
	var q: = QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m: = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 0.9, 0.6)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.5)
	m.emission_energy_multiplier = 3.0
	q.material = m
	draw_pass_1 = q


func _process(_d: float) -> void :
	if not is_instance_valid(_rig):
		_rig = get_tree().get_first_node_in_group("camera_rig") as Node3D
	if _rig:
		global_position = _rig.global_position + Vector3(0, 1.5, 0)

	if _pm:
		var w: = _wind()
		if w != null:
			var dir: Vector2 = w.dir
			var g: float = w.gust()
			_pm.direction = Vector3(dir.x, 0.25, dir.y)
			_pm.initial_velocity_min = 0.05 + 0.5 * g
			_pm.initial_velocity_max = 0.2 + 1.2 * g
	_gate_weather()




func _gate_weather() -> void :
	var w: = _weather()
	if w == null:
		amount_ratio = 1.0
		return
	var c: Dictionary = w.camera_cover()
	var hide: = maxf(float(c.get("wet", 0.0)), float(c.get("snow", 0.0)))
	amount_ratio = clampf(1.0 - hide, 0.0, 1.0)
	emitting = amount_ratio > 0.01


func _wind() -> Node:
	if not is_instance_valid(_wind_node):
		_wind_node = get_tree().get_first_node_in_group("wind")
	return _wind_node


func _weather() -> Node:
	if not is_instance_valid(_weather_node):
		_weather_node = get_tree().get_first_node_in_group("weather")
	return _weather_node
