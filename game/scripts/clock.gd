extends Node















const DATA_PATH: = "res://data/time.json"
const DAYS: = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
const MINUTES_PER_DAY: = 1440.0
const MINUTES_PER_WEEK: = 10080.0



signal period_changed(name: String)

signal minute_changed


var scale: = 20.0

var fast: = false

var running: = false

var _base_scale: = 20.0
var _fast_scale: = 600.0
var _last_minute: = -1
var _last_period: = ""
var _was_running: = false



var minutes: float:
	get:
		return Game.state.clock_minutes
	set(v):
		_apply(float(v), false)




static var _data: Dictionary = {}



static func data() -> Dictionary:
	if _data.is_empty():
		_data = _read_data()
	return _data


static func _read_data() -> Dictionary:
	var f: = FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("[clock] cannot read %s" % DATA_PATH)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if not (d is Dictionary):
		push_error("[clock] %s is not a JSON object" % DATA_PATH)
		return {}
	return d



static func periods() -> Array:
	var out: Array = []
	for p in data().get("periods", []):
		if p is Dictionary and p.get("id") != null and p.get("start") != null:
			out.append({"id": String(p.id), "start": String(p.start), "start_min": minutes_of_hhmm(String(p.start))})
	return out



static func minutes_of_hhmm(s: String) -> float:
	var parts: = s.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return 0.0
	return float(int(parts[0])) * 60.0 + float(int(parts[1]))



static func scale_of() -> float:
	return float(data().get("scale", 20.0))






static func period_at(minutes: float) -> String:
	var ps: = periods()
	if ps.is_empty():
		push_error("[clock] no periods in %s" % DATA_PATH)
		return "morning"
	var mod: = fposmod(minutes, MINUTES_PER_DAY)
	var pick: = String(ps[ps.size() - 1].id)
	for p in ps:
		if float(p.start_min) <= mod:
			pick = String(p.id)
	return pick



static func day_index_of(minutes: float) -> int:
	return int(fposmod(minutes, MINUTES_PER_WEEK) / MINUTES_PER_DAY)


static func day_name_of(minutes: float) -> String:
	return DAYS[day_index_of(minutes)]



static func day_index_of_name(s: String) -> int:
	var t: = s.strip_edges().to_upper()
	if t.is_valid_int():
		var i: = int(t)
		return i if i >= 0 and i <= 6 else -1
	return DAYS.find(t)



static func hour_of(minutes: float) -> int:
	return int(fposmod(minutes, MINUTES_PER_DAY) / 60.0)


static func minute_of(minutes: float) -> int:
	return int(fposmod(minutes, MINUTES_PER_DAY)) % 60



static func format(minutes: float) -> String:
	return "%s %d:%02d" % [day_name_of(minutes), hour_of(minutes), minute_of(minutes)]




func day_index() -> int:
	return day_index_of(minutes)


func day_name() -> String:
	return day_name_of(minutes)


func hour() -> int:
	return hour_of(minutes)


func minute() -> int:
	return minute_of(minutes)


func period() -> String:
	return period_at(minutes)



func set_time(day: int, hour: int, minute: int) -> void :
	var week: = floorf(minutes / MINUTES_PER_WEEK)
	_apply(week * MINUTES_PER_WEEK + float(clampi(day, 0, 6)) * MINUTES_PER_DAY
		+ float(clampi(hour, 0, 23)) * 60.0 + float(clampi(minute, 0, 59)), true)



func jump_to_period(id: String) -> bool:
	for p in periods():
		if String(p.id) == id:
			set_time(day_index(), int(p.start_min) / 60, int(p.start_min) % 60)
			return true
	return false



func next_period() -> String:
	var ps: = periods()
	var cur: = period()
	for i in ps.size():
		if String(ps[i].id) == cur:
			var nxt: = String(ps[(i + 1) % ps.size()].id)
			jump_to_period(nxt)
			return nxt
	return cur




func toggle_fast() -> void :
	fast = not fast
	scale = _fast_scale if fast else _base_scale




func should_run() -> bool:
	if Game.get_player() == null:
		return false
	if Game.menu_open or Game.cutscene or Game.talking:
		return false
	var t: = get_node_or_null("/root/Transitions")
	return t == null or not t.busy()




func _ready() -> void :
	_base_scale = scale_of()
	_fast_scale = float(data().get("fast_scale", 600.0))
	scale = _base_scale
	_last_minute = int(floorf(minutes))
	_last_period = period()


func _process(delta: float) -> void :
	running = should_run()
	if running and not _was_running:
		_emit(true)
	if running:
		_advance(delta / maxf(Engine.time_scale, 0.0001) * scale / 60.0)
	_was_running = running


func _advance(game_minutes: float) -> void :
	if game_minutes <= 0.0:
		return
	Game.state.clock_minutes += game_minutes
	_emit()


func _apply(v: float, force: bool) -> void :
	if not force and is_equal_approx(v, Game.state.clock_minutes):
		return
	Game.state.clock_minutes = v
	_emit(force)




func _emit(force: = false) -> void :
	var m: = Game.state.clock_minutes
	var mi: = int(floorf(m))
	if force or mi != _last_minute:
		_last_minute = mi
		minute_changed.emit()
	var p: = period_at(m)
	if force or p != _last_period:
		_last_period = p
		period_changed.emit(p)
