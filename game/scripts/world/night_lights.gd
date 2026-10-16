extends Node3D





















const GLOW_OFF: = Color(0.2, 0.17, 0.13)
const GLOW_ON: = Color(1.0, 0.8, 0.5)

const WINDOW_ENERGY: = 1.0


const WINDOW_DARK: = Color(0.16, 0.08, 0.02)

var light: OmniLight3D
var glow: MeshInstance3D
var window_mats: Array = []

var _light_base: = 0.0
var _glow_mat: StandardMaterial3D
var _glow_base: = 0.0
var _lamps: = 0.0
var _windows: = 0.0
var _budget: = true


func _ready() -> void :
	add_to_group("night_lights")
	if light:
		_light_base = light.light_energy
	if glow:
		_glow_mat = glow.get_active_material(0) as StandardMaterial3D
		if _glow_mat:
			_glow_base = _glow_mat.emission_energy_multiplier
	var tod: = get_tree().get_first_node_in_group("time_of_day")
	if tod and tod.has_method("night_mult"):
		var m: Dictionary = tod.night_mult()
		_lamps = float(m["lamps"])
		_windows = float(m["windows"])
	_apply()



func set_period_mult(lamps: float, windows: float) -> void :
	_lamps = lamps
	_windows = windows
	_apply()



func set_budget(on: bool) -> void :
	_budget = on
	_apply()


func _apply() -> void :
	var lit: = _lamps > 0.001 and _budget
	if light:
		light.light_energy = _light_base * _lamps * (1.0 if _budget else 0.0)
		light.visible = lit
	if glow:
		if _glow_mat:
			_glow_mat.emission_energy_multiplier = _glow_base * _lamps
			_glow_mat.albedo_color = GLOW_OFF.lerp(GLOW_ON, _lamps)


		glow.scale = Vector3.ONE * clampf(_lamps, 0.0, 1.0)
	for m in window_mats:
		m.emission_energy_multiplier = WINDOW_ENERGY * _windows
		var base: Color = m.get_meta("window_base", Color.WHITE)
		m.albedo_color = base.lerp(WINDOW_DARK, _windows)
