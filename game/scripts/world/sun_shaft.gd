@tool
extends Node3D


















const SHAFT_SHADER: = preload("res://shaders/sun_shaft.gdshader")


const FALLBACK_TO_SUN: = Vector3(-0.562, 0.371, 0.74)

const MAX_TILT_DEG: = 15.0



@export var radius: = 2.2:
	set(v):
		radius = maxf(v, 0.2)
		_rebuild()

@export var height: = 9.0:
	set(v):
		height = maxf(v, 2.0)
		_rebuild()
@export var color: = Color(1.0, 0.82, 0.48)
@export var opacity: = 0.2
@export var pool_opacity: = 0.22
@export var pool_radius: = 0.0

@export var tilt_deg: = 10.0
@export var breathe_speed: = 0.32
@export var breathe_amount: = 0.22
@export var sway: = 0.7
@export var mote_count: = 14
@export var shaft_seed: = 0

@export var dimmed: = 0.35
@export var near_radius: = 1.5

var _beam: Node3D
var _pool: MeshInstance3D
var _motes: GPUParticles3D
var _mats: Array[ShaderMaterial] = []
var _phase: = 0.0
var _rng: = RandomNumberGenerator.new()
var _sun: Node3D
var _built: = false
var _dim: = 1.0
var _base_opacity: = -1.0
var _base_pool: = -1.0


func _ready() -> void :
	add_to_group("sun_shafts")
	_rebuild()
	var tod: = get_tree().get_first_node_in_group("time_of_day")
	if tod != null and tod.has_method("shafts_mult"):
		set_period_mult(tod.shafts_mult())



func set_period_mult(m: float) -> void :
	if _base_opacity < 0.0:
		_base_opacity = opacity
		_base_pool = pool_opacity
	opacity = _base_opacity * m
	pool_opacity = _base_pool * m
	if is_instance_valid(_motes):
		_motes.visible = m > 0.001




func _rebuild() -> void :
	if not is_inside_tree() or _built:
		return
	_built = true
	_rng.seed = shaft_seed if shaft_seed != 0 else int(absf(global_position.x * 13.0 + global_position.z * 7.0)) + 1
	_phase = _rng.randf() * TAU
	_sun = get_tree().get_first_node_in_group("sun")
	_orient(beam_axis(_sun_to(), tilt_deg))
	_beam = Node3D.new()
	_beam.name = "Beam"
	add_child(_beam)
	_build_beam()
	_build_pool()
	if _high():
		_build_motes()




static func beam_axis(to_sun: Vector3, tilt: float) -> Vector3:
	var lean: = Vector3(to_sun.x, 0.0, to_sun.z)
	if lean.length() < 0.001:
		lean = Vector3(0, 0, -1)
	lean = lean.normalized()
	return (Vector3.UP + lean * tan(deg_to_rad(clampf(tilt, 0.0, MAX_TILT_DEG)))).normalized()




func _sun_to() -> Vector3:
	if is_instance_valid(_sun):
		var z: Vector3 = _sun.global_transform.basis.z
		if z.length() > 0.01:
			return z.normalized()
	return FALLBACK_TO_SUN.normalized()



func _orient(axis: Vector3) -> void :
	var y: = axis.normalized()
	var x: = Vector3(0, 0, 1).cross(y)
	if x.length() < 0.01:
		x = Vector3(1, 0, 0).cross(y)
	x = x.normalized()
	basis = Basis(x, y, x.cross(y).normalized())


func _make_mat(pool: bool) -> ShaderMaterial:
	var m: = ShaderMaterial.new()
	m.shader = SHAFT_SHADER
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("strength", pool_opacity if pool else opacity)
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("seed", _rng.randf())
	m.set_shader_parameter("ground_pool", pool)
	_mats.append(m)
	return m



func _build_beam() -> void :
	var qm: = QuadMesh.new()
	qm.size = Vector2(radius * 1.4, height)
	for i in 2:
		var mi: = MeshInstance3D.new()
		mi.name = "Card%d" % i
		mi.mesh = qm
		mi.material_override = _make_mat(false)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation.y = i * PI / 2.0
		mi.position = Vector3(0, height / 2.0, 0)
		_beam.add_child(mi)




func _build_pool() -> void :
	var r: = pool_radius if pool_radius > 0.0 else radius
	var pm: = PlaneMesh.new()
	pm.size = Vector2(r * 2.0, r * 2.0)
	_pool = MeshInstance3D.new()
	_pool.name = "Pool"
	_pool.mesh = pm
	_pool.material_override = _make_mat(true)
	_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pool)


	_pool.global_transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 0.03, 0))



func _build_motes() -> void :
	var p: = GPUParticles3D.new()
	p.name = "Motes"
	p.amount = mote_count
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB( - Vector3(radius, height, radius) * 1.5, Vector3(radius, height, radius) * 3.0)
	var pm: = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radius * 0.6, height * 0.35, radius * 0.6)
	pm.gravity = Vector3(0, 0.015, 0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.14
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.35
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var fade: = Curve.new()
	fade.add_point(Vector2(0.0, 0.0))
	fade.add_point(Vector2(0.25, 1.0))
	fade.add_point(Vector2(0.75, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	var ct: = CurveTexture.new()
	ct.curve = fade
	pm.alpha_curve = ct
	p.process_material = pm
	var q: = QuadMesh.new()
	q.size = Vector2(0.055, 0.055)
	var m: = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color.lightened(0.2)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(0, height * 0.5, 0)
	_beam.add_child(p)
	_motes = p


func _process(delta: float) -> void :
	if not _built or _mats.is_empty():
		return

	var t: = Time.get_ticks_msec() / 1000.0
	var b: = 1.0 + breathe_amount * sin(TAU * breathe_speed * t + _phase)

	var want: = dimmed if _player_hidden() else 1.0
	_dim = move_toward(_dim, want, delta * 3.0)
	for m in _mats:
		var base: float = pool_opacity if bool(m.get_shader_parameter("ground_pool")) else opacity
		m.set_shader_parameter("strength", base * b * _dim)

	if is_instance_valid(_motes):
		var w: = _wind()
		if w != null:
			var d: Vector2 = w.dir
			var g: float = w.gust()
			var pm: = _motes.process_material as ParticleProcessMaterial
			pm.direction = Vector3(d.x, 0.2, d.y)
			pm.initial_velocity_min = 0.02 + 0.4 * g
			pm.initial_velocity_max = 0.14 + 1.0 * g




func _player_hidden() -> bool:
	var p: = _player()
	if p == null:
		return false
	var d: = Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z)
	if d.length() < near_radius:
		return true
	var cam: = get_viewport().get_camera_3d()
	if cam == null:
		return false
	var dz: = global_position.z - p.global_position.z
	return dz > 0.5 and absf(global_position.x - p.global_position.x) < radius + 1.0


func _player() -> Node3D:
	var g: = get_node_or_null("/root/Game")
	if g != null and g.has_method("get_player"):
		return g.get_player()
	return get_tree().get_first_node_in_group("player") as Node3D


func _wind() -> Node:
	return get_tree().get_first_node_in_group("wind")



func _high() -> bool:
	var s: = get_node_or_null("/root/Settings")
	return s == null or s.is_high()
