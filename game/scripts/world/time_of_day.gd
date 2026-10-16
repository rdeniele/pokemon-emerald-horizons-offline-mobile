extends Node



























const DATA: = "res://data/time_of_day.json"
const DEFAULT_PERIOD: = "midday"

const LOW_LAMPS: = 8

const FLASH_AMBIENT: = 9.0
const FLASH_SUN: = 4.0




static var _pristine: = {}



var extra: = {"ambient": 1.0, "sun": 1.0, "sky_grey": 0.0, "fog": 1.0, "flash": 0.0, "shadow_soft": 0.0}

var presets: = {}
var blend_secs: = 25.0
var period: = DEFAULT_PERIOD

var _ow: Node
var _sun: DirectionalLight3D
var _env_node: WorldEnvironment
var _env: Environment
var _post: Node
var _ground: ShaderMaterial
var _base: = {}
var _from: = {}
var _to: = {}
var _t: = 1.0
var _blend: = 0.0
var _shaft_mult: = 1.0
var _lamps_mult: = 0.0
var _windows_mult: = 0.0
var _budget_t: = 0.0


func _ready() -> void :
	add_to_group("time_of_day")
	_ow = get_parent()
	_sun = _ow.get_node_or_null("Sun") as DirectionalLight3D
	_env_node = _ow.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_post = _ow.get_node_or_null("PostFX")
	var g: = _ow.get_node_or_null("Ground") as MeshInstance3D
	if g and g.mesh and g.mesh.get_surface_count() > 0 and g.mesh.surface_get_material(0) is ShaderMaterial:
		_ground = g.mesh.surface_get_material(0)
	_load_presets()
	var flag: = _cmdline_period()
	if flag != "":
		period = flag
	else:
		var clock: = get_node_or_null("/root/Clock")
		if clock:
			if clock.has_method("period"):
				period = String(clock.period())
			if clock.has_signal("period_changed"):
				clock.period_changed.connect(_on_period_changed)

	var streamer: = get_tree().get_first_node_in_group("zone_streamer")
	if streamer and streamer.has_signal("zone_changed"):
		streamer.zone_changed.connect(_on_zone_changed)


func _load_presets() -> void :
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if typeof(d) != TYPE_DICTIONARY or not (d as Dictionary).has("periods"):
		push_error("time_of_day: %s is not the expected JSON" % DATA)
		return
	presets = (d as Dictionary)["periods"]
	blend_secs = float((d as Dictionary).get("blend_secs", 25.0))


func _cmdline_period() -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--period="):
			return a.substr("--period=".length())
	return ""



func _on_period_changed(name: String) -> void :
	apply_period(name, blend_secs)



func _on_zone_changed(_id: String, _name: String) -> void :
	_capture_base()
	apply_period(period, 0.0)




func apply_period(name: String, blend_secs: = 25.0) -> void :
	if not presets.has(name):
		name = DEFAULT_PERIOD
	if not presets.has(name):
		return
	period = name
	if _base.is_empty():
		return
	_to = _resolve(name)
	_from = _current()
	_blend = blend_secs
	_t = 0.0
	if blend_secs <= 0.0:
		_t = 1.0
		_write(_to)




func refresh() -> void :
	if _base.is_empty() or not presets.has(period):
		return
	_to = _resolve(period)
	if _t >= 1.0:
		_write(_to)


func _process(delta: float) -> void :


	_budget_t += delta
	if _budget_t >= 0.3:
		_budget_t = 0.0
		_apply_lamp_budget()
	if _t >= 1.0 or _base.is_empty():
		return
	_t = minf(1.0, _t + delta / maxf(_blend, 0.0001))
	_write(_to if _t >= 1.0 else _lerp(_from, _to, _t))




func _capture_base() -> void :
	if _sun == null or _env_node == null or _env_node.environment == null:
		return
	_env = _env_node.environment
	var key: = _env.resource_path
	if key == "":
		key = "id:%d" % _env.get_instance_id()
	var p: Environment = _pristine.get(key)
	if p == null:
		p = _env.duplicate(true)
		_pristine[key] = p
	_base = {
		"sun_energy": float(_sun.base_energy), 
		"shadow_opacity": float(_sun.shadow_opacity), 
		"sky_top": _sky_color(p, "sky_top_color"), 
		"sky_horizon": _sky_color(p, "sky_horizon_color"), 
		"ambient": p.ambient_light_color, 
		"ambient_energy": float(p.ambient_light_energy), 
		"fog_color": p.fog_light_color, 
		"fog_density": float(p.fog_density), 
		"shadow_tint": _post.shadow_tint if _post else Color(0.36, 0.42, 0.6), 
		"highlight_tint": _post.highlight_tint if _post else Color(1.0, 0.9, 0.72), 
		"ground": _ground_base(), 
	}



func _resolve(name: String) -> Dictionary:
	var p: Dictionary = presets[name]
	var b: = _base
	var flash: = clampf(float(extra.get("flash", 0.0)), 0.0, 1.5)
	var soft: = clampf(float(extra.get("shadow_soft", 0.0)), 0.0, 1.0)
	var el: = float(p["sun_elevation"])
	var base_sun: Color = _sun.sun_color(el)
	var d: = {
		"sun_elevation": el, 
		"sun_azimuth": float(p["sun_azimuth"]), 
		"sun_color": base_sun.lerp(Color(String(p["sun_color"])), float(p["sun_color_weight"])), 
		"sun_energy": float(b["sun_energy"]) * float(p["sun_energy_mult"]) * float(extra["sun"]) * (1.0 + FLASH_SUN * flash), 
		"sky_top": (b["sky_top"] as Color).lerp(Color(String(p["sky_top"])), float(p["sky_top_weight"])), 
		"sky_horizon": (b["sky_horizon"] as Color).lerp(Color(String(p["sky_horizon"])), float(p["sky_horizon_weight"])), 
		"ambient": (b["ambient"] as Color).lerp(Color(String(p["ambient_color"])), float(p["ambient_weight"])), 
		"ambient_energy": float(b["ambient_energy"]) * float(p["ambient_energy_mult"]) * float(extra["ambient"]) * (1.0 + FLASH_AMBIENT * flash), 
		"fog_color": (b["fog_color"] as Color).lerp(Color(String(p["fog_color"])), float(p["fog_weight"])), 
		"fog_density": float(b["fog_density"]) * float(p["fog_density_mult"]) * float(extra.get("fog", 1.0)), 
		"shadow_tint": (b["shadow_tint"] as Color).lerp(Color(String(p["shadow_tint"])), float(p["post_weight"])), 
		"highlight_tint": (b["highlight_tint"] as Color).lerp(Color(String(p["highlight_tint"])), float(p["post_weight"])), 
		"shadow_blur": float(p["shadow_blur"]) + 6.0 * soft, 
		"shadow_opacity": float(b.get("shadow_opacity", 1.0)) * (1.0 - 0.75 * soft), 
		"shafts": float(p["shafts"]), 
		"lamps": float(p.get("lamps", 0.0)), 
		"windows": float(p.get("windows", 0.0)), 
	}

	var grey: = float(extra["sky_grey"])
	if grey > 0.0:
		d["sky_top"] = _grey(d["sky_top"], grey)
		d["sky_horizon"] = _grey(d["sky_horizon"], grey)


	if flash > 0.0:
		d["ambient"] = (d["ambient"] as Color).lerp(Color(0.8, 0.86, 1.0), minf(flash, 1.0))
		d["sky_top"] = (d["sky_top"] as Color).lerp(Color(1.0, 1.0, 1.0), minf(0.7 * flash, 0.9))
		d["sky_horizon"] = (d["sky_horizon"] as Color).lerp(Color(1.0, 1.0, 1.0), minf(0.8 * flash, 0.95))
	var gm: = Color(String(p["ground_mult"]))
	var gb: Dictionary = b.get("ground", {})
	for key in ["tint_a", "tint_b", "tint_c"]:
		if gb.has(key):
			d["ground_" + key] = (gb[key] as Color) * gm
	if gb.has("desaturate"):
		d["ground_desaturate"] = float(gb["desaturate"]) + float(p["ground_desaturate"])
	return d



func _current() -> Dictionary:
	var d: = {
		"sun_elevation": float(_sun.elevation_deg), 
		"sun_azimuth": float(_sun.azimuth_deg), 
		"sun_color": _sun.light_color, 
		"sun_energy": float(_sun.base_energy), 
		"shadow_blur": float(_sun.shadow_blur), 
		"shadow_opacity": float(_sun.shadow_opacity), 
		"shafts": _shaft_mult, 
		"lamps": _lamps_mult, 
		"windows": _windows_mult, 
	}
	if _env:
		d["sky_top"] = _sky_color(_env, "sky_top_color")
		d["sky_horizon"] = _sky_color(_env, "sky_horizon_color")
		d["ambient"] = _env.ambient_light_color
		d["ambient_energy"] = float(_env.ambient_light_energy)
		d["fog_color"] = _env.fog_light_color
		d["fog_density"] = float(_env.fog_density)
	if _post:
		d["shadow_tint"] = _post.shadow_tint
		d["highlight_tint"] = _post.highlight_tint
	if _ground:
		for key in ["tint_a", "tint_b", "tint_c"]:
			d["ground_" + key] = _ground.get_shader_parameter(key)
		d["ground_desaturate"] = float(_ground.get_shader_parameter("desaturate"))
	return d


func _lerp(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var d: = {}
	for k in b:
		var bv = b[k]
		var av = a.get(k, bv)
		d[k] = (av as Color).lerp(bv, t) if bv is Color else lerpf(float(av), float(bv), t)
	return d


func _write(d: Dictionary) -> void :
	if _sun:
		_sun.override_angles = true
		_sun.elevation_override = float(d["sun_elevation"])
		_sun.azimuth_override = float(d["sun_azimuth"])
		_sun.base_energy = float(d["sun_energy"])
		_sun.light_color = d["sun_color"]
		_sun.shadow_blur = float(d["shadow_blur"])
		_sun.shadow_opacity = float(d.get("shadow_opacity", 1.0))
	if _env:
		_sky_set(_env, "sky_top_color", d["sky_top"])
		_sky_set(_env, "sky_horizon_color", d["sky_horizon"])
		_env.ambient_light_color = d["ambient"]
		_env.ambient_light_energy = float(d["ambient_energy"])
		_env.fog_light_color = d["fog_color"]
		_env.fog_density = float(d["fog_density"])
	if _post:
		_post.shadow_tint = d["shadow_tint"]
		_post.highlight_tint = d["highlight_tint"]
	if _ground:
		for key in ["tint_a", "tint_b", "tint_c"]:
			if d.has("ground_" + key):
				_ground.set_shader_parameter(key, d["ground_" + key])
		if d.has("ground_desaturate"):
			_ground.set_shader_parameter("desaturate", d["ground_desaturate"])
	_shaft_mult = float(d.get("shafts", _shaft_mult))
	_apply_shafts()
	_lamps_mult = float(d.get("lamps", _lamps_mult))
	_windows_mult = float(d.get("windows", _windows_mult))
	_apply_night_lights()




func _apply_shafts() -> void :
	for n in get_tree().get_nodes_in_group("sun_shafts"):
		if n.has_method("set_period_mult"):
			n.set_period_mult(_shaft_mult)



func shafts_mult() -> float:
	return _shaft_mult




func _apply_night_lights() -> void :
	for n in get_tree().get_nodes_in_group("night_lights"):
		if n.has_method("set_period_mult"):
			n.set_period_mult(_lamps_mult, _windows_mult)



func night_mult() -> Dictionary:
	return {"lamps": _lamps_mult, "windows": _windows_mult}





func _apply_lamp_budget() -> void :
	var lamps: Array = []
	for n in get_tree().get_nodes_in_group("night_lights"):
		if n.light != null:
			lamps.append(n)
	var cam: = get_viewport().get_camera_3d()
	if Settings.is_high() or _lamps_mult <= 0.001 or cam == null:
		for n in lamps:
			n.set_budget(true)
		return
	var eye: = cam.global_position
	lamps.sort_custom( func(a, b):
		return a.global_position.distance_squared_to(eye) < b.global_position.distance_squared_to(eye))
	for i in lamps.size():
		lamps[i].set_budget(i < LOW_LAMPS)




func _ground_base() -> Dictionary:
	if _ground == null:
		return {}
	var g: = {}
	for key in ["tint_a", "tint_b", "tint_c"]:
		g[key] = _ground.get_shader_parameter(key)
	g["desaturate"] = float(_ground.get_shader_parameter("desaturate"))
	return g


func _sky_color(env: Environment, prop: String) -> Color:
	if env and env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		return env.sky.sky_material.get(prop)
	return Color(0.5, 0.5, 0.5)


func _sky_set(env: Environment, prop: String, c: Color) -> void :
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		env.sky.sky_material.set(prop, c)


func _grey(c: Color, w: float) -> Color:
	var l: = c.get_luminance()
	return c.lerp(Color(l, l, l), w)
