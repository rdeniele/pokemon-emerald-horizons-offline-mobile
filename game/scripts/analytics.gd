extends Node











signal tracked(event: String, props: Dictionary)

const DATA_PATH: = "res://data/analytics.json"
const DEFAULT_HOST: = "https://api-eu.mixpanel.com"

const BLOCKED_KEYS: = ["name", "player_name", "rival_name", "user_name", "user", "path", "file_path"]

const STORY_FLAGS: = ["oak_stopped", "starter_chosen", "rival_battle_done", "has_parcel", 
	"parcel_delivered", "has_pokedex", "old_man_lesson", "demo_end_seen"]
const BACKOFF_START: = 5.0
const BACKOFF_MAX: = 120.0
const PERF_WAIT: = 10.0
const PERF_SECS: = 5.0
const SAVE_EVERY: = 5.0
const MAX_ERRORS: = 3



var enabled: = false

var debug_force: = false
var data: = {}
var queue: Array = []

var queue_path: = "user://analytics_queue.json"
var id_path: = "user://analytics.cfg"
var max_batch: = 50
var flush_secs: = 30.0
var queue_cap: = 500

var distinct_id: = ""
var session_id: = ""
var session_start: = 0.0
var _consent: = 0
var _consent_sent: = false
var _first_launch: = true
var _last_zone: = ""
var _inflight: = false
var _sent: = 0
var _backoff: = 0.0
var _flush_t: = 0.0
var _save_t: = 0.0
var _errors: = 0
var _in_error: = false
var _shut: = false
var _app_sent: = false
var _quitting: = false
var _http: HTTPRequest
var _build_start: = {}
var _perf_wait: = -1.0
var _perf_left: = 0.0
var _perf_zone: = ""
var _perf_samples: Array = []


class _ErrLogger extends Logger:
	var host: Node

	func _init(h: Node) -> void :
		host = h


	func _log_error(function: String, file: String, line: int, msg: String, _rationale: String, 
			_editor_notify: bool, _error_type: int, _backtrace: Array) -> void :
		if host != null:
			host._on_error(function, file, line, msg)


func _ready() -> void :
	_load_data()
	_load_id()
	_first_launch = not FileAccess.file_exists(id_path)
	_consent = _settings_analytics()
	var args: = OS.get_cmdline_user_args() + OS.get_cmdline_args()
	debug_force = "--analytics-debug" in args
	var dbg: = _autoload("Debug")
	var checkpoint: = ("--start=" in " ".join(args)) or (dbg != null and String(dbg.checkpoint) != "")
	enabled = false # Offline mobile port: no telemetry or consent interruption.
	set_process(enabled)
	if enabled:
		get_tree().auto_accept_quit = false
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)
	session_id = _uuid()
	session_start = Time.get_unix_time_from_system()
	var settings: = _autoload("Settings")
	if settings != null:
		settings.changed.connect(_on_setting_changed)
	get_tree().node_added.connect(_on_node_added)
	OS.add_logger(_ErrLogger.new(self))
	_load_queue()




func track(event: String, props: = {}) -> void :
	tracked.emit(event, props)
	if not enabled or _consent != 1 or _shut:
		return
	queue.append(build_event(event, props))
	_trim()
	_defer_save()
	if queue.size() >= max_batch:
		flush()



func needs_consent() -> bool:
	return enabled and _consent == 0




func set_consent(yes: bool, source: String) -> void :
	if yes and distinct_id == "":
		distinct_id = _uuid()
		_save_id()
	_consent = 1 if yes else 2
	if not yes:
		queue.clear()
		_save_queue()
	var settings: = _autoload("Settings")
	if settings != null:
		settings.set_value("analytics", _consent)
	if yes and not _consent_sent:
		_consent_sent = true
		_save_id()
		track("analytics_consent", {"source": source})



func app_opened() -> void :
	if _app_sent:
		return
	_app_sent = true
	var size: = DisplayServer.window_get_size()
	track("app_opened", {
		"first_launch": _first_launch, 
		"screen_w": size.x, "screen_h": size.y, 
		"renderer": RenderingServer.get_current_rendering_method(), 
		"gpu": RenderingServer.get_video_adapter_name(), 
		"ram_mb": int(float(OS.get_memory_info().get("physical", 0)) / 1048576.0), 
		"locale": OS.get_locale(), 
	})




func quit_game() -> void :
	if _quitting:
		return
	_quitting = true
	_shutdown()
	if enabled and _consent == 1 and not queue.is_empty() and is_inside_tree():
		_inflight = false
		flush()
		var deadline: = Time.get_ticks_msec() + 2500
		while _inflight and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
	get_tree().quit()






func build_event(event: String, props: Dictionary) -> Dictionary:
	_load_data()
	var p: = super_props()
	var clean: = sanitize(props)
	for k in clean:
		p[k] = clean[k]
	p["time"] = int(Time.get_unix_time_from_system())
	p["$insert_id"] = _uuid()
	return {"event": event, "properties": p}



func sanitize(props: Dictionary) -> Dictionary:
	var out: = {}
	var names: = _player_names()
	for k in props:
		if BLOCKED_KEYS.has(k):
			continue
		var v = props[k]
		out[k] = _redact(v, names) if v is String else v
	return out



func super_props() -> Dictionary:
	var p: = {
		"token": String(data.get("token", "")), 
		"session_id": session_id, 
		"session_seconds": int(Time.get_unix_time_from_system() - session_start), 
		"platform": OS.get_name().to_lower(), 
		"build_version": String(ProjectSettings.get_setting("application/config/version", "")), 
		"input_mode": _input_mode(), 
	}
	if distinct_id != "":
		p["distinct_id"] = distinct_id
	var game: = _autoload("Game")
	if game != null:
		var st = game.state
		p["play_time_min"] = int(st.play_time / 60.0)
		p["badges"] = st.badges.size()
		p["party_size"] = st.party.size()
		p["party_top_level"] = _top_level(st.party)
		p["dex_caught"] = st.dex_caught.size()
		var cp: = checkpoint_of(st.flags)
		if cp != "":
			p["checkpoint"] = cp
	var settings: = _autoload("Settings")
	if settings != null:
		p["quality"] = String(settings.QUALITY_NAMES[settings.quality]).to_lower()
	var z: = _zone()
	if z != "":
		p["zone"] = z
	return p



static func checkpoint_of(flags: Dictionary) -> String:
	var out: = ""
	for f in STORY_FLAGS:
		if flags.get(f, false):
			out = f
	return out




func api_url() -> String:
	return "%s/track" % String(data.get("api_host", DEFAULT_HOST)).trim_suffix("/")


func flush() -> void :
	if not enabled or _consent != 1 or _inflight or queue.is_empty() or _http == null or not is_inside_tree():
		return
	_inflight = true
	_sent = mini(queue.size(), max_batch)
	if debug_force:
		print("[analytics] POST %s %s" % [api_url(), JSON.stringify(queue.slice(0, _sent))])
	_http.request(api_url(), ["Content-Type: application/json"], HTTPClient.METHOD_POST, 
		JSON.stringify(queue.slice(0, _sent)))


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void :
	_inflight = false
	var ok: = result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.get_string_from_utf8().strip_edges() == "1"
	if debug_force:
		print("[analytics] response %d body '%s'" % [code, body.get_string_from_utf8().strip_edges()])
	if ok:
		for i in _sent:
			if not queue.is_empty():
				queue.pop_front()
		_sent = 0
		_backoff = 0.0
		if not queue.is_empty():
			flush()
	else:

		_backoff = minf(maxf(_backoff * 2.0, BACKOFF_START), BACKOFF_MAX)
	_save_queue()


func _trim() -> void :
	while queue.size() > queue_cap:
		queue.pop_front()


func _defer_save() -> void :
	if _save_t <= 0.0:
		_save_t = SAVE_EVERY


func _save_queue() -> void :
	_save_t = 0.0
	var f: = FileAccess.open(queue_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(queue))
	f.close()


func _load_queue() -> void :
	if not FileAccess.file_exists(queue_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(queue_path))
	if parsed is Array:
		queue = parsed
		_trim()




func _process(delta: float) -> void :
	if _backoff > 0.0:
		_backoff = maxf(0.0, _backoff - delta)
	_flush_t += delta
	if _flush_t >= flush_secs:
		_flush_t = 0.0
		if _backoff <= 0.0:
			flush()
	if _save_t > 0.0:
		_save_t -= delta
		if _save_t <= 0.0:
			_save_queue()
	if _perf_wait >= 0.0:
		_perf_wait -= delta
		if _perf_wait <= 0.0:
			_perf_wait = -1.0
			_perf_left = PERF_SECS
			_perf_samples = []
	elif _perf_left > 0.0:
		_perf_left -= delta
		_perf_samples.append(Engine.get_frames_per_second())
		if _perf_left <= 0.0:
			_track_perf()


func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_shutdown()
		if enabled and _consent == 1 and not _inflight:
			flush()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_shut = false


func _shutdown() -> void :
	if _shut:
		return
	if enabled and _consent == 1:
		track("session_ended", {"session_seconds": int(Time.get_unix_time_from_system() - session_start)})
	_shut = true
	_save_queue()


func _on_node_added(n: Node) -> void :
	if not enabled:
		return
	if n.has_signal("zone_changed") and not n.zone_changed.is_connected(_on_zone_changed):
		n.zone_changed.connect(_on_zone_changed)
	if n.has_signal("built") and n.get_script() != null\
	and n.get_script().resource_path == "res://scripts/world/world_builder.gd":
		_build_start[n.get_instance_id()] = Time.get_ticks_msec()
		n.built.connect(_on_builder_built.bind(n), CONNECT_ONE_SHOT)


func _on_zone_changed(zone_id: String, _zone_name: String) -> void :
	track("zone_entered", {
		"zone": zone_id, "from": _last_zone, 
		"period": _period(), "weather": _weather_name(), 
	})
	_last_zone = zone_id
	_perf_zone = zone_id
	_perf_wait = PERF_WAIT


func _on_builder_built(b: Node) -> void :
	var t0: int = _build_start.get(b.get_instance_id(), 0)
	_build_start.erase(b.get_instance_id())
	track("load_time", {
		"ms": 0.0 if t0 == 0 else float(Time.get_ticks_msec() - t0), 
		"zone": String(b.map_file).get_file().get_basename(), 
	})


func _on_setting_changed(key: String) -> void :
	var settings: = _autoload("Settings")
	track("setting_changed", {"key": key, "value": settings.get(key) if settings != null else null})


func _on_error(function: String, file: String, line: int, msg: String) -> void :
	if not enabled or _consent != 1 or _errors >= MAX_ERRORS or _in_error:
		return
	_in_error = true
	_errors += 1
	track("error_logged", {
		"message": _strip_paths(msg).substr(0, 200), 
		"file": String(file).get_file(), "line": line, 
	})
	_in_error = false


func _track_perf() -> void :
	if _perf_samples.is_empty():
		return
	var sorted: = _perf_samples.duplicate()
	sorted.sort()
	var sum: = 0.0
	for f in _perf_samples:
		sum += f
	track("perf_sample", {
		"fps_avg": sum / _perf_samples.size(), 
		"fps_p5": sorted[clampi(int(sorted.size() * 0.05), 0, sorted.size() - 1)], 
		"zone": _perf_zone, "quality": _quality(), "weather": _weather_name(), "period": _period(), 
	})




func _load_data() -> void :
	if not data.is_empty():
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		data = parsed
	max_batch = maxi(1, int(data.get("max_batch", 50)))
	flush_secs = maxf(1.0, float(data.get("flush_secs", 30)))


func _load_id() -> void :
	var cfg: = ConfigFile.new()
	if cfg.load(id_path) != OK:
		return
	distinct_id = String(cfg.get_value("analytics", "distinct_id", ""))
	_consent_sent = bool(cfg.get_value("analytics", "consent_sent", false))


func _save_id() -> void :
	var cfg: = ConfigFile.new()
	cfg.set_value("analytics", "distinct_id", distinct_id)
	cfg.set_value("analytics", "consent_sent", _consent_sent)
	cfg.save(id_path)


func _settings_analytics() -> int:
	var s: = _autoload("Settings")
	return clampi(int(s.analytics), 0, 2) if s != null else 0



func _autoload(n: String) -> Node:
	return get_node_or_null("/root/" + n) if is_inside_tree() else null


func _zone() -> String:
	var streamer: = get_tree().get_first_node_in_group("zone_streamer") if is_inside_tree() else null
	return String(streamer.active) if streamer != null else ""


func _period() -> String:
	var clock: = _autoload("Clock")
	return clock.period() if clock != null else ""


func _quality() -> String:
	var s: = _autoload("Settings")
	return String(s.QUALITY_NAMES[s.quality]).to_lower() if s != null else ""


func _weather_name() -> String:
	if not is_inside_tree():
		return ""
	var w: = get_tree().get_first_node_in_group("weather")
	if w == null:
		return ""
	var c: Dictionary = w.camera_cover()
	var best: = ""
	var best_v: = 0.05
	for k in ["snow", "wet", "fog", "cloud"]:
		if float(c.get(k, 0.0)) > best_v:
			best_v = float(c[k])
			best = k
	return best if best != "" else "clear"


static func _top_level(party: Array) -> int:
	var top: = 0
	for m in party:
		top = maxi(top, int(m.level))
	return top


static func _input_mode() -> String:
	match Controls.device():
		"pad":
			return "gamepad"
		"touch":
			return "touch"
	return "keyboard"


func _player_names() -> Array:
	var game: = _autoload("Game")
	if game == null:
		return []
	return [String(game.state.player_name), String(game.state.rival_name)]



static func _redact(v: Variant, names: Array) -> Variant:
	if not (v is String):
		return v
	var s: = _strip_paths(v)
	for n in names:
		if String(n) != "":
			s = s.replace(String(n), "<name>")
	return s


static func _strip_paths(s: String) -> String:
	var home: = OS.get_environment("HOME")
	if home != "":
		s = s.replace(home, "<path>")
	return s



static func _uuid() -> String:
	var b: = Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 15) | 64
	b[8] = (b[8] & 63) | 128
	var h: = b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]
