extends Node3D















const BASE_DIR: = Vector2(1.0, -0.35)
const BASE_STRENGTH: = 1.0
const GUST_MIN: = 6.0
const GUST_MAX: = 12.0
const RISE: = 1.0
const HOLD: = 1.5
const DECAY: = 2.0



var forced_gust: = -1.0

var wind_time: = 0.0
var dir: = BASE_DIR.normalized()
var strength: = BASE_STRENGTH
var _since: = 0.0
var _period: = 0.0
var _gust_t: = -1.0
var _gust: = 0.0


func _ready() -> void :
	add_to_group("wind")
	RenderingServer.global_shader_parameter_set("wind_dir", dir)
	RenderingServer.global_shader_parameter_set("wind_strength", strength)
	RenderingServer.global_shader_parameter_set("wind_gust", 0.0)
	RenderingServer.global_shader_parameter_set("wind_time", 0.0)
	_period = randf_range(GUST_MIN, GUST_MAX)



func gust() -> float:
	return _gust


func _process(delta: float) -> void :
	wind_time += delta
	_since += delta
	if _gust_t < 0.0 and _since >= _period:
		_gust_t = 0.0
		_since = 0.0
		_period = randf_range(GUST_MIN, GUST_MAX)
	_gust = 0.0
	if _gust_t >= 0.0:
		_gust_t += delta
		if _gust_t < RISE:
			_gust = _gust_t / RISE
		elif _gust_t < RISE + HOLD:
			_gust = 1.0
		elif _gust_t < RISE + HOLD + DECAY:
			_gust = 1.0 - (_gust_t - RISE - HOLD) / DECAY
		else:
			_gust_t = -1.0
	if forced_gust >= 0.0:
		_gust = clampf(forced_gust, 0.0, 1.0)
	RenderingServer.global_shader_parameter_set("wind_gust", _gust)
	RenderingServer.global_shader_parameter_set("wind_time", wind_time)
