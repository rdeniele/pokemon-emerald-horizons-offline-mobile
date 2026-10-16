@tool
extends Node3D





@export var cookie: Texture2D:
	set(v):
		cookie = v
		_rebuild()
@export var win_size: = Vector2(1.6, 1.4):
	set(v):
		win_size = v
		_rebuild()
@export var length: = 8.0:
	set(v):
		length = v
		_rebuild()
@export var light_color: = Color(1.0, 0.93, 0.8):
	set(v):
		light_color = v
		_rebuild()
@export var energy: = 5.0:
	set(v):
		energy = v
		_rebuild()
@export var spot_angle: = 30.0:
	set(v):
		spot_angle = v
		_rebuild()
@export var dust: = true:
	set(v):
		dust = v
		_rebuild()
@export var dust_amount: = 42:
	set(v):
		dust_amount = v
		_rebuild()




const PERIOD_COLOR: = {
	"morning": Color(1.0, 0.95, 0.82), "midday": Color(1.0, 0.97, 0.9), 
	"afternoon": Color(1.0, 0.9, 0.72), "sunset": Color(1.0, 0.72, 0.5), 
	"night": Color(0.6, 0.72, 1.0), 
}


func _ready() -> void :
	_follow_period()
	if get_child_count() == 0:
		_build()
	var s: = get_node_or_null("/root/Settings")
	if s and s.has_signal("changed"):
		s.changed.connect( func(key: String) -> void :
			if key == "quality":
				_apply_quality())
	_apply_quality()





func _apply_quality() -> void :
	var l: = get_node_or_null("_gen_light") as SpotLight3D
	if l:
		l.shadow_enabled = _shadow_on()


func _shadow_on() -> bool:
	var s: = get_node_or_null("/root/Settings")
	return true if s == null else s.is_high()


func _follow_period() -> void :
	var clock: = get_node_or_null("/root/Clock")
	if clock == null or not clock.has_signal("period_changed"):
		return
	clock.period_changed.connect( func(p: String) -> void :
		if PERIOD_COLOR.has(p):
			light_color = PERIOD_COLOR[p])
	if clock.has_method("period") and PERIOD_COLOR.has(String(clock.period())):
		light_color = PERIOD_COLOR[String(clock.period())]


func _rebuild() -> void :
	if is_inside_tree():
		_build()


func _build() -> void :
	for c in get_children():
		remove_child(c)
		c.free()
	add_child(_light())
	if dust:
		add_child(_dust())


func _light() -> SpotLight3D:
	var l: = SpotLight3D.new()
	l.name = "_gen_light"
	l.light_color = light_color
	l.light_energy = energy
	l.spot_range = length
	l.spot_angle = spot_angle
	l.spot_angle_attenuation = 1.0
	l.shadow_enabled = _shadow_on()
	l.shadow_bias = 0.05
	l.light_volumetric_fog_energy = 3.0
	l.light_projector = cookie
	return l



func _dust() -> GPUParticles3D:
	var w: = win_size.x
	var h: = win_size.y
	var p: = GPUParticles3D.new()
	p.name = "_gen_dust"
	p.amount = dust_amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0, 0, - length * 0.35)
	p.visibility_aabb = AABB(Vector3( - w, - h, - length) * 2.0, Vector3(w, h, length) * 4.0)
	var pm: = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.5, h * 0.5, length * 0.35)
	pm.gravity = Vector3(0, -0.01, 0)
	pm.direction = Vector3(0.5, 0.2, -0.7)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.01
	pm.initial_velocity_max = 0.05
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var fade: = Curve.new()
	fade.add_point(Vector2(0.0, 0.0))
	fade.add_point(Vector2(0.3, 1.0))
	fade.add_point(Vector2(0.7, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	var ct: = CurveTexture.new()
	ct.curve = fade
	pm.alpha_curve = ct
	p.process_material = pm
	var q: = QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	var m: = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 0.9, 0.65, 0.5)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.5)
	m.emission_energy_multiplier = 2.0
	q.material = m
	p.draw_pass_1 = q
	return p
