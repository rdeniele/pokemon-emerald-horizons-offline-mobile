extends Node3D






































signal cover_changed(cover: Dictionary)

const WORLD_FILE: = "res://data/world.json"
const DATA_FILE: = "res://data/weather.json"
const PX: = 2.0
const UPDATE_HZ: = 4.0
const LOW_HZ: = 2.0
const SOFT: = 0.45
const FALLBACK_SCALE: = 20.0


const MAX_CATCHUP_MINUTES: = 240.0
const FOG_K: = 12.0
const OVERCAST_SUN: = 0.8
const OVERCAST_AMBIENT: = 0.35
const OVERCAST_GREY: = 0.7
const COVER_EPS: = 0.01
const FAMILIES: = ["wet", "snow", "fog", "cloud"]

const FLASH_SECS: = 0.15

var data: = {}
var origin: = Vector2(-136.0, -463.0)
var map_size: = Vector2i(92, 242)
var cells: Array = []

var flash_level: = 0.0

var _seed: = 1
var _spawn_n: = 0
var _rng: = RandomNumberGenerator.new()
var _minutes: = 0.0
var _last_minutes: = 0.0
var _dm_acc: = 0.0
var _acc: = 0.0
var _spawn_in: = 0.0

var _img: Image
var _tex: ImageTexture
var _bytes: = PackedByteArray()
var _wet: = PackedFloat32Array()
var _snow: = PackedFloat32Array()
var _wet_now: = PackedFloat32Array()
var _snow_now: = PackedFloat32Array()
var _cover: = {"wet": 0.0, "snow": 0.0, "fog": 0.0, "cloud": 0.0}
var _ms: = 0.0
var _updates: = 0



var spawn_enabled: = true


var _demo: = {}
var _demo_now: = false
var _overlay: CanvasLayer
var _overlay_rect: TextureRect
var _overlay_dot: ColorRect
var _debug_img: Image
var _debug_tex: ImageTexture
var _debug_bytes: = PackedByteArray()
var _pending: = ""
var _pending_clear: = false
var _want_overlay: = false





static func texel(pos: Vector2, o: Vector2, px: float) -> Vector2i:
	return Vector2i(int(floor((pos.x - o.x) / px)), int(floor((pos.y - o.y) / px)))



static func map_dims(size: Vector2, px: float) -> Vector2i:
	return Vector2i(int(ceil(size.x / px)), int(ceil(size.y / px)))



static func bounds_from_zones(zones: Array) -> Dictionary:
	if zones.is_empty():
		return {"origin": Vector2(-136.0, -463.0), "size": Vector2(184.0, 484.0)}
	var lo: = Vector2(INF, INF)
	var hi: = Vector2( - INF, - INF)
	for z in zones:
		var r: Array = z["rect"]
		lo = lo.min(Vector2(float(r[0]), float(r[1])))
		hi = hi.max(Vector2(float(r[0]) + float(r[2]), float(r[1]) + float(r[3])))
	return {"origin": lo, "size": hi - lo}



static func falloff(dist: float, r: float, soft: = SOFT) -> float:
	if r <= 0.0:
		return 0.0
	var t: = clampf(dist / r, 0.0, 1.0)
	return 1.0 - smoothstep(1.0 - soft, 1.0, t)



static func strength(age: float, life: float, fade: float) -> float:
	if age <= 0.0 or age >= life or fade <= 0.0:
		return 0.0
	return minf(smoothstep(0.0, fade, age), smoothstep(0.0, fade, life - age))



static func wet_step(prev: float, feed: float, dry_per_hour: float, dt_hours: float) -> float:
	return maxf(clampf(feed, 0.0, 1.0), maxf(prev - dry_per_hour * dt_hours, 0.0))



static func snow_step(prev: float, feed: float, accum_per_hour: float, melt_per_hour: float, dt_hours: float) -> float:
	var f: = clampf(feed, 0.0, 1.0)
	if f > 0.0:
		return minf(1.0, prev + f * accum_per_hour * dt_hours)
	return maxf(prev - melt_per_hour * dt_hours, 0.0)




func _ready() -> void :
	add_to_group("weather")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_FILE))
	if parsed is Dictionary:
		data = parsed
	else:
		push_error("[weather] cannot read %s" % DATA_FILE)
		set_process(false)
		return
	_bounds()
	_build_arrays()

	var g: = get_node_or_null("/root/Game")
	var saved: Dictionary = {}
	if g != null and g.get("state") != null and g.state.get("weather") is Dictionary:
		saved = g.state.weather
	if saved.has("cells"):
		from_dict(saved)
	else:
		_seed = randi()
		_rng.seed = _seed
		_minutes = _now_minutes(0.0)
		_last_minutes = _minutes
		_spawn_in = _next_interval()
		_demo = {"start": _roll_demo_start(), "done": false}
		refresh()
		_write_state()
	if _demo.is_empty():
		_demo = {"start": _roll_demo_start(), "done": false}
		_write_state()
	_debug_print_schedule()
	_parse_args()


	var rain_script = load("res://scripts/world/rain.gd")
	if rain_script != null:
		var rain: Node3D = rain_script.new()
		rain.name = "Rain"
		add_child(rain)
	_apply_look()


func _process(delta: float) -> void :
	_apply_pending()
	if flash_level > 0.0:
		flash_level = maxf(0.0, flash_level - delta / FLASH_SECS)
		_apply_look()
	var dm: = _tick_clock(delta)
	if dm > 0.0:
		_advance(dm)
	_dm_acc += dm
	_acc += delta
	if _acc >= _interval():
		refresh()
		_write_state()
	if _overlay != null and _overlay.visible:
		_move_dot()


func _interval() -> float:
	return 1.0 / (LOW_HZ if _low_quality() else UPDATE_HZ)


func _low_quality() -> bool:
	var s: = get_node_or_null("/root/Settings")
	return s != null and not s.is_high()



func _now_minutes(delta: float) -> float:
	var c: = get_node_or_null("/root/Clock")
	if c != null and "minutes" in c:
		return float(c.minutes)
	return _minutes + delta * FALLBACK_SCALE / 60.0




func _tick_clock(delta: float) -> float:
	var m: = _now_minutes(delta)
	var dm: = m - _last_minutes
	_last_minutes = m
	_minutes = m
	return clampf(dm, 0.0, MAX_CATCHUP_MINUTES)


func _bounds() -> void :
	var atlas = JSON.parse_string(FileAccess.get_file_as_string(WORLD_FILE))
	var zones: Array = atlas.zones if atlas is Dictionary and atlas.has("zones") else []
	var b: = bounds_from_zones(zones)
	origin = b["origin"]
	map_size = map_dims(b["size"], PX)


func _build_arrays() -> void :
	var n: = map_size.x * map_size.y
	_bytes.resize(n * 4)
	_wet.resize(n)
	_snow.resize(n)
	_wet_now.resize(n)
	_snow_now.resize(n)
	_img = Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)




func _advance(dm: float) -> void :
	var hours: = dm / 60.0
	var dir: = Vector2(1.0, -0.35).normalized()
	var gust: = 0.0
	var wind: = get_tree().get_first_node_in_group("wind") if is_inside_tree() else null
	if wind != null:
		dir = wind.dir
		gust = wind.gust()
	var speed: = float(data["drift_speed"]) * (0.7 + 0.3 * gust)
	var dead: Array = []
	for c in cells:

		var df: = float(c.get("drift", data["types"][c["type"]]["drift"]))
		c["pos"] += dir * (speed * df * hours)
		c["age"] += hours
		if c["age"] >= c["life"]:
			dead.append(c)
	for c in dead:
		cells.erase(c)
	_spawn_in -= dm
	if not spawn_enabled:
		return
	if _demo_mode():
		_tick_demo()
	elif _spawn_in <= 0.0:
		if cells.size() < int(data["max_cells"]):
			_spawn()
		_spawn_in = _next_interval()


func _spawn() -> void :
	_spawn_n += 1
	_rng.seed = _seed + _spawn_n * 7919
	var t: = _pick_type()
	if t != "":
		_add_cell(t, _spawn_pos(), 0.0)


func _next_interval() -> float:
	var s: Dictionary = data["spawn_interval_hours"]
	return _rng.randf_range(float(s["min"]), float(s["max"]))




func _demo_mode() -> bool:
	return String(data.get("mode", "random")) == "demo"



static func _hhmm(s: String) -> float:
	var p: = s.split(":")
	if p.size() != 2 or not p[0].is_valid_int() or not p[1].is_valid_int():
		return 0.0
	return float(int(p[0])) * 60.0 + float(int(p[1]))




func _roll_demo_start() -> float:
	var dr: Dictionary = data.get("demo_rain", {})
	var lo: = _hhmm(String(dr.get("start_min", "11:30")))
	var hi: = _hhmm(String(dr.get("start_max", "14:00")))
	var day: = floorf(_minutes / 1440.0) * 1440.0
	var s: = day + _rng.randf_range(lo, hi)
	return s + 1440.0 if s <= _minutes else s



func _can_shower() -> bool:
	var g: = get_node_or_null("/root/Game")
	if g == null or g.get("state") == null:
		return false
	if g.get("cutscene") or g.get("talking") or g.get("menu_open"):
		return false
	if get_tree().get_first_node_in_group("player") == null:
		return false
	var t: = get_node_or_null("/root/Transitions")
	return t == null or not t.busy()



func _tick_demo() -> void :
	if bool(_demo.get("done", false)) or float(_demo.get("start", 0.0)) <= 0.0:
		return
	if _minutes < float(_demo["start"]) or not _can_shower():
		return
	_spawn_demo_rain()
	_demo["done"] = true
	_write_state()




func _spawn_demo_rain() -> Dictionary:
	var dr: Dictionary = data.get("demo_rain", {})
	var wind: = get_tree().get_first_node_in_group("wind") if is_inside_tree() else null
	var dir: = Vector2(1.0, -0.35).normalized()
	if wind != null:
		dir = Vector2(wind.dir).normalized()
	var c: = _add_cell("rain", _focus_pos() - dir * float(dr.get("upwind_m", 44.0)), 0.0)
	c["r"] = float(dr.get("radius", 40.0))
	c["life"] = float(dr.get("life_hours", 2.0))
	c["drift"] = float(dr.get("drift", 0.6))
	refresh()
	return c


func _pick_type() -> String:
	var types: Dictionary = data["types"]
	var total: = 0.0
	for k in types:
		total += float(types[k]["weight"])
	if total <= 0.0:
		return ""
	var roll: = _rng.randf() * total
	for k in types:
		roll -= float(types[k]["weight"])
		if roll <= 0.0:
			return k
	return types.keys()[0]





func _spawn_pos() -> Vector2:
	var p: = _focus_pos()
	var lo: = origin + Vector2(12.0, 12.0)
	var hi: = origin + Vector2(map_size) * PX - Vector2(12.0, 12.0)
	for i in 8:
		var a: = _rng.randf_range(0.0, TAU)
		var q: = p + Vector2(cos(a), sin(a)) * _rng.randf_range(float(data["spawn_near"]), float(data["spawn_far"]))
		if q.x >= lo.x and q.x <= hi.x and q.y >= lo.y and q.y <= hi.y:
			return q
	return Vector2(clampf(p.x, lo.x, hi.x), clampf(p.y, lo.y, hi.y))


func _add_cell(type: String, pos: Vector2, age: float) -> Dictionary:
	var rr: Dictionary = data["radius"]
	var ll: Dictionary = data["lifetime_hours"]
	var c: = {"type": type, "pos": pos, 
		"r": _rng.randf_range(float(rr["min"]), float(rr["max"])), 
		"age": age, 
		"life": _rng.randf_range(float(ll["min"]), float(ll["max"]))}
	cells.append(c)
	return c




func spawn_cell(type: String, pos: Vector2, radius: = -1.0, life: = -1.0) -> Dictionary:
	if not data.has("types") or not data["types"].has(type):
		push_warning("[weather] unknown cell type '%s'" % type)
		return {}
	var c: = _add_cell(type, pos, float(data["fade_hours"]))
	if radius > 0.0:
		c["r"] = radius
	if life > 0.0:
		c["life"] = life
	refresh()
	_write_state()
	return c



func clear() -> void :
	cells = []
	_spawn_in = _next_interval()
	refresh()
	_write_state()



func type_at(type: String, pos: Vector3) -> float:
	var p: = Vector2(pos.x, pos.z)
	var fade: = float(data.get("fade_hours", 0.1))
	var out: = 0.0
	for c in cells:
		if c["type"] != type:
			continue
		var st: = strength(float(c["age"]), float(c["life"]), fade)
		if st <= 0.0:
			continue
		out = maxf(out, st * falloff(p.distance_to(c["pos"]), float(c["r"])))
	return out



func flash(strength_v: = 1.0) -> void :
	flash_level = maxf(flash_level, clampf(strength_v, 0.0, 1.5))
	_apply_look()


func _focus_pos() -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	var rig: = get_tree().get_first_node_in_group("camera_rig") as Node3D
	if rig != null:
		return Vector2(rig.global_position.x, rig.global_position.z)
	var p: = get_tree().get_first_node_in_group("player") as Node3D
	if p != null:
		return Vector2(p.global_position.x, p.global_position.z)
	return Vector2.ZERO





func refresh() -> void :
	_update_coverage(_dm_acc)
	_dm_acc = 0.0
	_acc = 0.0
	_publish()
	_emit_cover()






func _update_coverage(dm: float) -> void :
	var t0: = Time.get_ticks_usec()
	var w: = map_size.x
	var h: = map_size.y
	var dh: = dm / 60.0
	_bytes.fill(0)
	_wet_now.fill(0.0)
	_snow_now.fill(0.0)
	var fade: = float(data["fade_hours"])
	var plateau: = 1.0 - SOFT
	for c in cells:
		var st: = strength(float(c["age"]), float(c["life"]), fade)
		if st <= 0.0:
			continue
		var ch: Dictionary = data["types"][c["type"]]["channels"]
		var wet_ch: = float(ch.get("wet", 0.0))
		var snow_ch: = float(ch.get("snow", 0.0))
		var fog_ch: = float(ch.get("fog", 0.0))
		var cloud_ch: = float(ch.get("cloud", 0.0))
		var r: = float(c["r"])
		var cp: Vector2 = c["pos"]
		var cx: = cp.x
		var cz: = cp.y
		var x0: = maxi(0, int(floor((cx - r - origin.x) / PX)))
		var x1: = mini(w - 1, int(ceil((cx + r - origin.x) / PX)))
		var z0: = maxi(0, int(floor((cz - r - origin.y) / PX)))
		var z1: = mini(h - 1, int(ceil((cz + r - origin.y) / PX)))
		for py in range(z0, z1 + 1):
			var dz: = origin.y + (py + 0.5) * PX - cz
			var row: = py * w
			for px in range(x0, x1 + 1):
				var dx: = origin.x + (px + 0.5) * PX - cx
				var t: = sqrt(dx * dx + dz * dz) / r
				if t >= 1.0:
					continue
				var f: = st
				if t > plateau:
					var u: = (t - plateau) / SOFT
					f *= 1.0 - u * u * (3.0 - 2.0 * u)
				var i: = row + px
				if wet_ch > 0.0:
					var wv: = f * wet_ch
					if wv > _wet_now[i]:
						_wet_now[i] = wv
				if snow_ch > 0.0:
					var sv: = f * snow_ch
					if sv > _snow_now[i]:
						_snow_now[i] = sv
				if fog_ch > 0.0:
					var fi: = i * 4 + 2
					var fv: = int(f * fog_ch * 255.0)
					if fv > _bytes[fi]:
						_bytes[fi] = fv
				if cloud_ch > 0.0:
					var ci: = i * 4 + 3
					var cv: = int(f * cloud_ch * 255.0)
					if cv > _bytes[ci]:
						_bytes[ci] = cv
	var dry_dh: = (1.0 / float(data["dry_hours"])) * dh
	var accum_dh: = (1.0 / float(data["snow_accum_hours"])) * dh
	var melt_dh: = (1.0 / float(data["snow_melt_hours"])) * dh
	for i in w * h:
		var feed: = _wet_now[i]
		var wet: = _wet[i] - dry_dh
		if feed > wet:
			wet = feed
		if wet < 0.0:
			wet = 0.0
		_wet[i] = wet
		var sfeed: = _snow_now[i]
		var snow: = _snow[i]
		if sfeed > 0.0:
			snow = minf(1.0, snow + sfeed * accum_dh)
		else:
			snow = maxf(0.0, snow - melt_dh)
		_snow[i] = snow
		if wet > 0.0 or snow > 0.0:
			var b: = i * 4
			_bytes[b] = int(wet * 255.0)
			_bytes[b + 1] = int(snow * 255.0)
	_img.set_data(w, h, false, Image.FORMAT_RGBA8, _bytes)
	_tex.update(_img)
	_ms = (Time.get_ticks_usec() - t0) / 1000.0
	_updates += 1
	if _overlay != null and _overlay.visible:
		_update_debug_image()


func _publish() -> void :
	RenderingServer.global_shader_parameter_set(&"weather_map", _tex)
	RenderingServer.global_shader_parameter_set(&"weather_origin", origin)
	RenderingServer.global_shader_parameter_set(&"weather_px", PX)
	RenderingServer.global_shader_parameter_set(&"weather_time", _minutes)



func coverage_at(pos: Vector3) -> Dictionary:
	var t: = texel(Vector2(pos.x, pos.z), origin, PX)
	var out: = {"wet": 0.0, "snow": 0.0, "fog": 0.0, "cloud": 0.0}
	if t.x < 0 or t.y < 0 or t.x >= map_size.x or t.y >= map_size.y:
		return out
	var i: = (t.y * map_size.x + t.x) * 4
	out["wet"] = _bytes[i] / 255.0
	out["snow"] = _bytes[i + 1] / 255.0
	out["fog"] = _bytes[i + 2] / 255.0
	out["cloud"] = _bytes[i + 3] / 255.0
	return out



func camera_cover() -> Dictionary:
	return _cover.duplicate()



func perf() -> Dictionary:
	return {"ms": _ms, "updates": _updates, "cells": cells.size(), "px": map_size.x * map_size.y}


func _emit_cover() -> void :
	var p: = _focus_pos()
	var c: = coverage_at(Vector3(p.x, 0.0, p.y))
	var changed: = false
	for k in FAMILIES:
		if absf(float(c[k]) - float(_cover[k])) > COVER_EPS:
			changed = true
	_cover = c
	if changed:
		_apply_look()
		cover_changed.emit(c.duplicate())







func _apply_look() -> void :
	var cloud: = float(_cover["cloud"])
	var tod: = get_parent().get_node_or_null("TimeOfDay") if get_parent() else null
	if tod != null and tod.get("extra") is Dictionary:
		tod.extra = {"ambient": 1.0 - OVERCAST_AMBIENT * cloud, "sun": 1.0 - OVERCAST_SUN * cloud, 
			"sky_grey": OVERCAST_GREY * cloud, "fog": 1.0 + FOG_K * float(_cover["fog"]), 
			"flash": flash_level, "shadow_soft": cloud}
		tod.refresh()

	var cs: = get_parent().get_node_or_null("CloudShadow") as MeshInstance3D if get_parent() else null
	if cs != null and cs.material_override is ShaderMaterial:
		var m: = cs.material_override as ShaderMaterial
		m.set_shader_parameter("coverage", 0.3 + 0.5 * cloud)
		m.set_shader_parameter("darken", 0.18 + 0.25 * cloud)




func to_dict() -> Dictionary:
	var out: Array = []
	for c in cells:
		var cd: = {"type": c["type"], "x": c["pos"].x, "z": c["pos"].y, 
			"r": c["r"], "age": c["age"], "life": c["life"]}
		if c.has("drift"):
			cd["drift"] = c["drift"]
		out.append(cd)
	return {"seed": _seed, "spawns": _spawn_n, "minutes": _minutes, "cells": out, 
		"demo": _demo.duplicate()}


func from_dict(d: Dictionary) -> void :
	_seed = maxi(int(d.get("seed", 1)), 1)
	_spawn_n = maxi(int(d.get("spawns", 0)), 0)
	_rng.seed = _seed
	cells = []
	for cd in d.get("cells", []):
		if not cd is Dictionary:
			continue
		var t: = String(cd.get("type", ""))
		if not data["types"].has(t):
			continue
		var c: = {"type": t, "pos": Vector2(float(cd.get("x", 0.0)), float(cd.get("z", 0.0))), 
			"r": float(cd.get("r", 30.0)), "age": float(cd.get("age", 0.0)), 
			"life": float(cd.get("life", 1.0))}
		if cd.has("drift"):
			c["drift"] = float(cd["drift"])
		cells.append(c)
	_demo = d.get("demo", {}).duplicate() if d.get("demo") is Dictionary else {}
	_minutes = float(d.get("minutes", _minutes))
	_last_minutes = _minutes
	_spawn_in = _next_interval()
	refresh()



func _write_state() -> void :
	var g: = get_node_or_null("/root/Game")
	if g != null and g.get("state") != null:
		g.state.weather = to_dict()




func _parse_args() -> void :
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--weather="):
			var v: = a.substr("--weather=".length())
			if v == "clear":
				_pending_clear = true
			elif data["types"].has(v):
				_pending = v
			else:
				push_warning("[weather] --weather=%s: no such cell type" % v)
		elif a == "--rain-now":
			_demo_now = true
		elif a == "--weather-map":
			_want_overlay = true



func _apply_pending() -> void :
	if _pending == "" and not _pending_clear and not _demo_now:
		if _want_overlay and _overlay == null:
			_want_overlay = false
			toggle_overlay()
		return
	if get_tree().get_first_node_in_group("player") == null:
		return
	if _pending_clear:
		_pending_clear = false
		clear()
	if _pending != "":
		var p: = get_tree().get_first_node_in_group("player") as Node3D
		spawn_cell(_pending, Vector2(p.global_position.x, p.global_position.z))
		_pending = ""
	if _demo_now:
		_demo_now = false
		_spawn_demo_rain()
		_demo["done"] = true
		_write_state()



func _debug_print_schedule() -> void :
	var dbg: = get_node_or_null("/root/Debug")
	if dbg == null or not dbg.get("enabled"):
		return
	var c: = get_node_or_null("/root/Clock")
	var at: = str(_demo.get("start", 0.0))
	if c != null:
		at = c.format(float(_demo.get("start", 0.0)))
	print("[weather] demo rain scheduled for %s" % at)



func toggle_overlay() -> void :
	if _overlay == null:
		_build_overlay()
	_overlay.visible = not _overlay.visible
	if _overlay.visible:
		_update_debug_image()
		_move_dot()


func _build_overlay() -> void :
	_overlay = CanvasLayer.new()
	_overlay.layer = 5
	add_child(_overlay)
	_debug_bytes.resize(map_size.x * map_size.y * 4)
	_debug_img = Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	_debug_tex = ImageTexture.create_from_image(_debug_img)
	_overlay_rect = TextureRect.new()
	_overlay_rect.texture = _debug_tex
	_overlay_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_overlay_rect.position = Vector2(12.0, 12.0)
	_overlay_rect.size = Vector2(map_size)
	_overlay.add_child(_overlay_rect)
	_overlay_dot = ColorRect.new()
	_overlay_dot.color = Color(1.0, 1.0, 1.0)
	_overlay_dot.size = Vector2(3.0, 3.0)
	_overlay.add_child(_overlay_dot)
	_overlay.visible = false




func _update_debug_image() -> void :
	var n: = map_size.x * map_size.y
	for i in n:
		var b: = i * 4
		var cloud: = _bytes[b + 3]
		var r: = maxi(_bytes[b], cloud / 2)
		var g: = maxi(_bytes[b + 1], cloud / 2)
		var bl: = maxi(_bytes[b + 2], cloud / 2)
		_debug_bytes[b] = r
		_debug_bytes[b + 1] = g
		_debug_bytes[b + 2] = bl
		_debug_bytes[b + 3] = 255
	_debug_img.set_data(map_size.x, map_size.y, false, Image.FORMAT_RGBA8, _debug_bytes)
	_debug_tex.update(_debug_img)


func _move_dot() -> void :
	var p: = _focus_pos()
	var t: = texel(p, origin, PX)
	_overlay_dot.position = _overlay_rect.position + Vector2(t) - Vector2(1.0, 1.0)
