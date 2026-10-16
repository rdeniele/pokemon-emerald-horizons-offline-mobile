extends Node




signal changed(key: String)

const TEXT_SPEEDS: = ["Slow", "Mid", "Fast", "Instant"]
const TEXT_CPS: = [25.0, 45.0, 90.0, 0.0]
const WINDOW_MODES: = ["Windowed", "Fullscreen"]


const QUALITY_NAMES: = ["Low", "High"]

const LOW_RENDER_SCALE: = 0.75


const BATTLE_SPEED_NAMES: = ["Slow", "Fast"]
const BATTLE_SPEED_MULT: = [0.6, 1.0]


const TOUCH_MODES: = ["Auto", "On", "Off"]

const ANALYTICS_MAX: = 2


var path: = "user://settings.cfg"
var text_speed: = 1
var window_mode: = 0
var battle_tips: = true
var quality: = 1
var battle_speed: = 0
var touch_controls: = 0
var analytics: = 0


func _ready() -> void :
	load_cfg()
	apply_window_mode()

	get_tree().node_added.connect(_on_node_added)
	apply_quality.call_deferred()


func _on_node_added(n: Node) -> void :
	if n is WorldEnvironment:
		apply_quality.call_deferred()



func text_cps() -> float:
	return TEXT_CPS[clampi(text_speed, 0, TEXT_CPS.size() - 1)]



func text_instant() -> bool:
	return text_cps() <= 0.0


func set_value(key: String, v) -> void :
	match key:
		"text_speed":
			text_speed = clampi(int(v), 0, TEXT_SPEEDS.size() - 1)
		"window_mode":
			window_mode = clampi(int(v), 0, WINDOW_MODES.size() - 1)
			apply_window_mode()
		"battle_tips":
			battle_tips = bool(v)
		"quality":
			quality = clampi(int(v), 0, QUALITY_NAMES.size() - 1)
			apply_quality()
		"battle_speed":
			battle_speed = clampi(int(v), 0, BATTLE_SPEED_MULT.size() - 1)
		"touch_controls":
			touch_controls = clampi(int(v), 0, TOUCH_MODES.size() - 1)
		"analytics":
			analytics = clampi(int(v), 0, ANALYTICS_MAX)
		_:
			push_warning("[settings] unknown key '%s'" % key)
			return
	save_cfg()
	changed.emit(key)




func default_quality(is_mobile: = OS.has_feature("mobile")) -> int:
	return 0 if is_mobile else 1



func load_cfg() -> void :
	text_speed = 1
	window_mode = 0
	battle_tips = true


	quality = default_quality()
	battle_speed = 0
	touch_controls = 0
	analytics = 0
	var cfg: = ConfigFile.new()
	if cfg.load(path) != OK:
		return
	text_speed = clampi(int(cfg.get_value("options", "text_speed", 1)), 0, TEXT_SPEEDS.size() - 1)
	window_mode = clampi(int(cfg.get_value("options", "window_mode", 0)), 0, WINDOW_MODES.size() - 1)
	battle_tips = bool(cfg.get_value("options", "battle_tips", true))
	quality = clampi(int(cfg.get_value("options", "quality", quality)), 0, QUALITY_NAMES.size() - 1)
	battle_speed = clampi(int(cfg.get_value("options", "battle_speed", 0)), 0, BATTLE_SPEED_MULT.size() - 1)
	touch_controls = clampi(int(cfg.get_value("options", "touch_controls", 0)), 0, TOUCH_MODES.size() - 1)
	analytics = clampi(int(cfg.get_value("options", "analytics", 0)), 0, ANALYTICS_MAX)


func save_cfg() -> void :
	var cfg: = ConfigFile.new()
	cfg.set_value("options", "text_speed", text_speed)
	cfg.set_value("options", "window_mode", window_mode)
	cfg.set_value("options", "battle_tips", battle_tips)
	cfg.set_value("options", "quality", quality)
	cfg.set_value("options", "battle_speed", battle_speed)
	cfg.set_value("options", "touch_controls", touch_controls)
	cfg.set_value("options", "analytics", analytics)
	cfg.save(path)



func battle_speed_value() -> float:
	return BATTLE_SPEED_MULT[clampi(battle_speed, 0, BATTLE_SPEED_MULT.size() - 1)]


func apply_window_mode() -> void :
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if window_mode == 1 else DisplayServer.WINDOW_MODE_WINDOWED)




func is_high() -> bool:
	return quality >= 1




func apply_quality_to(env: Environment, sun: Node = null, attrs: CameraAttributes = null) -> void :
	if env == null:
		return
	var high: = is_high()





	var forward_plus: = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	env.ssao_enabled = high and forward_plus
	env.ssil_enabled = high and forward_plus


	env.ssr_enabled = high and forward_plus
	if env.ssr_enabled:
		env.ssr_max_steps = 96
		env.ssr_fade_in = 0.1
		env.ssr_fade_out = 8.0
		env.ssr_depth_tolerance = 0.3
	env.glow_enabled = high and forward_plus
	env.volumetric_fog_enabled = high and forward_plus

	if sun is Light3D:
		var l: = sun as Light3D


		if not l.has_meta("q_shadow"):
			l.set_meta("q_shadow", l.shadow_enabled)
		l.shadow_enabled = bool(l.get_meta("q_shadow")) and high
	if sun is DirectionalLight3D:
		var d: = sun as DirectionalLight3D






		d.directional_shadow_max_distance = 24.0
		d.shadow_blur = 0.25
		d.light_angular_distance = 0.05
	if attrs is CameraAttributesPractical:
		var a: = attrs as CameraAttributesPractical


		a.dof_blur_far_enabled = false
		a.dof_blur_near_enabled = false
	if sun is DirectionalLight3D and not high:


		(sun as DirectionalLight3D).directional_shadow_max_distance = 14.0



func apply_quality() -> void :
	if is_inside_tree():
		var vp: = get_viewport()
		if vp:
			vp.scaling_3d_scale = 1.0 if is_high() else LOW_RENDER_SCALE
			vp.msaa_3d = Viewport.MSAA_2X if is_high() else Viewport.MSAA_DISABLED



			if is_high():
				vp.positional_shadow_atlas_size = int(ProjectSettings.get_setting_with_override(
					"rendering/lights_and_shadows/positional_shadow/atlas_size"))
			else:
				vp.positional_shadow_atlas_size = 1024
		_walk(get_tree().root)


func _walk(n: Node) -> void :
	if n is WorldEnvironment and n.environment:
		apply_quality_to(n.environment, _sun_under(get_tree().root), _camera_attrs())
	for c in n.get_children():
		_walk(c)


func _sun_under(root: Node) -> Node:
	for n in root.find_children("*", "DirectionalLight3D", true, false):
		return n
	return null


func _camera_attrs() -> CameraAttributes:
	var cam: = get_tree().root.get_viewport().get_camera_3d() if get_tree() else null
	return cam.attributes if cam else null
