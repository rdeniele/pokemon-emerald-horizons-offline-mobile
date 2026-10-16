extends Node3D


















const RAIN_HIGH: = 1200
const SPLASH_HIGH: = 240
const ON_EPS: = 0.02
const SPLASH_EPS: = 0.15
const STORM_EPS: = 0.05
const STRIKE_MIN: = 4.0
const STRIKE_MAX: = 10.0
const BOLT_HEIGHT: = 6.0
const BOLT_SECS: = 1.0
const BOLT_DIST_MIN: = 6.0
const BOLT_DIST_MAX: = 12.0
const THUNDER_DELAY_MIN: = 0.7
const THUNDER_DELAY_MAX: = 2.0


var wet: = 0.0

var storm: = 0.0

var _rain: GPUParticles3D
var _splash: GPUParticles3D
var _rain_pm: ParticleProcessMaterial
var _audio: AudioStreamPlayer
var _rng: = RandomNumberGenerator.new()
var _strike_in: = 0.0
var _bolts: = 0
var _was_on: = false
var _beam_script: GDScript



static func amount_for(high: bool, base: int) -> int:
	return base if high else maxi(1, base / 4)



static func intensity(wet_cover: float) -> float:
	return clampf(wet_cover, 0.0, 1.0)


func _ready() -> void :
	_rng.randomize()
	_beam_script = load("res://scripts/vfx_beam.gd")
	_build_rain()
	_build_splash()
	_build_audio()
	_apply_quality()
	var s: = get_node_or_null("/root/Settings")
	if s != null and s.has_signal("changed"):
		s.changed.connect(_on_setting_changed)




func _build_rain() -> void :
	_rain = GPUParticles3D.new()
	_rain.name = "Drops"
	_rain.local_coords = false
	_rain.emitting = false
	_rain.amount_ratio = 0.0
	_rain.lifetime = 1.0
	_rain.preprocess = 1.0
	_rain.visibility_aabb = AABB(Vector3(-18.0, -12.0, -18.0), Vector3(36.0, 24.0, 36.0))
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(15.0, 0.5, 15.0)
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 2.0
	pm.initial_velocity_min = 13.0
	pm.initial_velocity_max = 18.0
	pm.gravity = Vector3(0.0, -8.0, 0.0)
	pm.angle_min = 0.0
	pm.angle_max = 0.0
	_rain.process_material = pm
	_rain_pm = pm
	_rain.draw_pass_1 = _card(Vector2(0.02, 0.4), Color(0.78, 0.84, 0.92, 0.5))
	add_child(_rain)


func _build_splash() -> void :
	_splash = GPUParticles3D.new()
	_splash.name = "Splashes"
	_splash.local_coords = false
	_splash.emitting = false
	_splash.amount_ratio = 0.0
	_splash.lifetime = 0.45
	_splash.preprocess = 0.45
	_splash.visibility_aabb = AABB(Vector3(-12.0, -1.0, -12.0), Vector3(24.0, 3.0, 24.0))
	_splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(10.0, 0.05, 10.0)
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 10.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0.0, -1.5, 0.0)
	pm.angle_min = 0.0
	pm.angle_max = 0.0

	var sc: = Curve.new()
	sc.add_point(Vector2(0.0, 0.4))
	sc.add_point(Vector2(1.0, 1.7))
	var sct: = CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var ac: = Curve.new()
	ac.add_point(Vector2(0.0, 0.0))
	ac.add_point(Vector2(0.15, 1.0))
	ac.add_point(Vector2(1.0, 0.0))
	var act: = CurveTexture.new()
	act.curve = ac
	pm.alpha_curve = act
	_splash.process_material = pm
	var q: = PlaneMesh.new()
	q.size = Vector2(0.13, 0.13)
	var m: = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _ring_texture()
	m.albedo_color = Color(0.75, 0.82, 0.92, 0.55)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	q.material = m
	_splash.draw_pass_1 = q
	add_child(_splash)



func _ring_texture() -> ImageTexture:
	var n: = 16
	var c: = (n - 1) * 0.5
	var img: = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d: = Vector2(x - c, y - c).length() / c
			var a: = smoothstep(0.45, 0.7, d) * (1.0 - smoothstep(0.85, 1.05, d))
			img.set_pixel(x, y, Color(0.86, 0.93, 1.0, a))
	return ImageTexture.create_from_image(img)




func _card(size: Vector2, color: Color) -> QuadMesh:
	var q: = QuadMesh.new()
	q.size = size
	var m: = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	q.material = m
	return q


func _build_audio() -> void :
	var audio: = get_node_or_null("/root/Audio")
	if audio == null or not audio.has_method("stream"):
		return
	var st: AudioStream = audio.stream("sfx/weather/rain")
	if st == null:
		return
	_audio = AudioStreamPlayer.new()
	_audio.name = "RainAudio"
	_audio.stream = st.duplicate() as AudioStream
	_audio.bus = "SFX"
	_audio.volume_db = -80.0
	add_child(_audio)
	_audio.play()


func _apply_quality() -> void :
	var s: = get_node_or_null("/root/Settings")
	var high: bool = s == null or bool(s.is_high())
	_set_amount(_rain, amount_for(high, RAIN_HIGH))
	_set_amount(_splash, amount_for(high, SPLASH_HIGH))


func _set_amount(p: GPUParticles3D, n: int) -> void :
	if p == null or p.amount == n:
		return
	var was: = p.emitting
	p.amount = n
	if was:
		p.restart()


func _on_setting_changed(key: String) -> void :
	if key == "quality":
		_apply_quality()




func _process(delta: float) -> void :
	var w: = get_parent()
	if w == null or not w.has_method("camera_cover"):
		return
	var focus: = _focus()
	wet = intensity(float(w.camera_cover()["wet"]))
	storm = w.type_at("thunderstorm", focus) if w.has_method("type_at") else 0.0
	_follow(focus)
	_slant_drops()
	var on: = wet > ON_EPS

	if _was_on and not on:
		_rain.restart()
		_splash.restart()
	_rain.emitting = on
	_rain.amount_ratio = wet if on else 0.0
	var splash_on: = wet > SPLASH_EPS
	_splash.emitting = splash_on
	_splash.amount_ratio = wet if splash_on else 0.0
	_was_on = on
	_set_audio(wet)
	if storm > STORM_EPS:
		_strike_in -= delta
		if _strike_in <= 0.0:
			_strike_in = _rng.randf_range(STRIKE_MIN, STRIKE_MAX)
			strike()
	else:
		_strike_in = _rng.randf_range(1.0, 2.5)


func _follow(focus: Vector3) -> void :
	if _rain != null:
		_rain.global_position = focus + Vector3(0.0, 6.0, 0.0)
	if _splash != null:
		_splash.global_position = focus + Vector3(0.0, 0.15, 0.0)



func _slant_drops() -> void :
	if _rain_pm == null:
		return
	var wind: = get_tree().get_first_node_in_group("wind")
	var d: Vector2 = Vector2(1.0, -0.35) if wind == null else wind.dir
	_rain_pm.direction = Vector3(d.x * 0.25, -1.0, d.y * 0.25).normalized()


func _focus() -> Vector3:
	var rig: = get_tree().get_first_node_in_group("camera_rig") as Node3D
	if rig != null:
		return rig.global_position
	var p: = get_tree().get_first_node_in_group("player") as Node3D
	if p != null:
		return p.global_position
	return global_position



func _set_audio(cover: float) -> void :
	if _audio == null:
		return
	var v: = clampf(cover, 0.0, 1.0) * 0.9
	_audio.volume_db = linear_to_db(v) if v > 0.001 else -80.0







func strike() -> Node3D:
	var w: = get_parent()
	var focus: = _focus()
	if w != null and w.has_method("flash"):
		w.flash(1.0)
	var a: = _rng.randf_range(0.0, TAU)

	var cam: = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var fwd: = - cam.global_transform.basis.z
		a = atan2(fwd.z, fwd.x) + _rng.randf_range(-0.35, 0.35)
	var dist: = _rng.randf_range(BOLT_DIST_MIN, BOLT_DIST_MAX)
	var at: = Vector3(focus.x + cos(a) * dist, focus.y, focus.z + sin(a) * dist)
	var g: = get_node_or_null("/root/Game")
	if g != null and g.has_method("ground_y"):
		at.y = g.ground_y(at + Vector3(0.0, 8.0, 0.0), at.y)
	var bolt: Node3D = null
	if _beam_script != null and _beam_script.has_method("sky"):
		bolt = _beam_script.sky("thunder", at, BOLT_HEIGHT, BOLT_SECS)
	_bolt_glow(at)
	_bolts += 1
	var delay: = _rng.randf_range(THUNDER_DELAY_MIN, THUNDER_DELAY_MAX)
	var audio: = get_node_or_null("/root/Audio")
	if audio != null and get_tree() != null:
		get_tree().create_timer(delay).timeout.connect( func():
			if is_instance_valid(audio):
				audio.play_at("sfx/moves/thunder", at, -6.0))
	return bolt




func _bolt_glow(at: Vector3) -> void :
	var q: = QuadMesh.new()
	q.size = Vector2(0.85, BOLT_HEIGHT)
	q.center_offset = Vector3(0.0, BOLT_HEIGHT * 0.5, 0.0)
	var m: = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _bolt_texture()
	q.material = m
	var mi: = MeshInstance3D.new()
	mi.name = "BoltGlow"
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = at
	var tw: = create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, BOLT_SECS).set_delay(0.12)
	tw.tween_callback(mi.queue_free)



func _bolt_texture() -> ImageTexture:
	var w: = 16
	var h: = 64
	var img: = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v: = float(y) / float(h - 1)
		var vert: = smoothstep(0.0, 0.12, v) * (1.0 - smoothstep(0.82, 1.0, v))
		for x in w:
			var u: = absf(float(x) / float(w - 1) - 0.5) * 2.0
			var core: = 1.0 - smoothstep(0.0, 0.3, u)
			var glow: = (1.0 - smoothstep(0.0, 1.0, u)) * 0.45
			var a: = clampf(core + glow, 0.0, 1.0) * vert
			img.set_pixel(x, y, Color(0.78, 0.88, 1.0, a))
	return ImageTexture.create_from_image(img)
