extends Node











signal zone_changed(zone_id: String, zone_name: String)

@export_file("*.json") var world_file: = "res://data/world.json"


@export var neighbor_range: = 40.0


@export var unload_margin: = 14.0

@export var announce: = true

var atlas: = {}
var zones: = {}
var loaded: = {}
var _loading: = {}
var _pending: = {}
var active: = ""
var _booted: = false
var _preparing: = ""

var debug_goto: = ""


var _threads: = OS.has_feature("threads")


func _ready() -> void :
	add_to_group("zone_streamer")
	atlas = JSON.parse_string(FileAccess.get_file_as_string(world_file))
	for z in atlas.zones:
		zones[z.id] = z

	for id in zones:
		for n in zones[id].neighbors:
			if not zones.has(n):
				push_warning("zones: %s lists neighbour %s, which no zone defines (yet)" % [id, n])
	P1Prof.note("streamer: %d zones in atlas" % zones.size())
	_boot.call_deferred()




func _boot() -> void :
	if Transitions.busy():
		return
	var p: Node3D = Game.get_player()
	if p:
		p.set_physics_process(false)
	var spawn: String = await prepare(Transitions.pending_spawn)
	Transitions.pending_spawn = spawn
	if p:
		Transitions.place_player(p)
		p.set_physics_process(true)




func prepare(spawn: String) -> String:
	var _p1_t0: = Time.get_ticks_usec()
	var zid: = ""
	for z in atlas.zones:
		if spawn != "" and z.spawns.has(spawn):
			zid = z.id
	if zid == "":
		zid = atlas.start.zone
		spawn = atlas.start.spawn
	_preparing = zid
	if not loaded.has(zid):
		var _p1_load: = Time.get_ticks_usec()
		_add_zone(zid, load(zones[zid].scene))
		P1Prof.span("zone prepare %s load+instantiate (SYNC)" % zid, Time.get_ticks_usec() - _p1_load)





	if not loaded[zid].is_built or not loaded[zid].is_decorated:
		var _p1_build: = Time.get_ticks_usec()
		var _p1_f: = Engine.get_frames_drawn()
		var w: Node = loaded[zid].get_node_or_null("World")
		if w and w.has_method("boost_build"):
			w.boost_build()
		if not loaded[zid].is_built:
			await loaded[zid].built
		if not loaded[zid].is_decorated:
			await loaded[zid].decorated
		P1Prof.step("zone", "%s await built+decorated" % zid, _p1_build, _p1_f)
	_preparing = ""
	_set_active(zid, false)
	_booted = true
	P1Prof.span("zone prepare %s TOTAL" % zid, Time.get_ticks_usec() - _p1_t0)
	P1Prof.snapshot("zone %s ready" % zid)
	return spawn



func teleport(spawn: String) -> void :
	var p: Node3D = Game.get_player()
	if p == null:
		return
	p.set_physics_process(false)
	Transitions.pending_spawn = await prepare(spawn)
	Transitions.place_player(p)
	p.set_physics_process(true)


func _process(_d: float) -> void :
	if debug_goto != "" and _booted:
		var target: = debug_goto
		debug_goto = ""
		teleport(target)
	_poll_loading()
	if not _booted:
		return
	var p: Node3D = Game.get_player()
	if p == null:
		return
	var here: = _zone_at(p.global_position)
	if here != "" and here != active:
		_set_active(here, announce)
	_request_nearby(p.global_position)
	_unload_far(p.global_position)


func _rect(id: String) -> Rect2:
	var r: Array = zones[id].rect
	return Rect2(r[0], r[1], r[2], r[3])



func _rect_dist(id: String, pos: Vector3) -> float:
	var r: = _rect(id)
	var p: = Vector2(pos.x, pos.z)
	return p.distance_to(Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y)))


func _zone_at(pos: Vector3) -> String:
	var pt: = Vector2(pos.x, pos.z)

	if active != "" and _rect(active).grow(1.0).has_point(pt):
		return active
	for id in zones:
		if _rect(id).has_point(pt):
			return id
	return ""





const DEFAULT_ENV: = "res://resources/look/overworld_env.tres"
const GROUND_TINTS: = {"tint_a": Color(1, 1, 0.92), "tint_b": Color(0.78, 0.9, 0.78), "tint_c": Color(1.06, 1.02, 0.8)}
const GROUND_DESATURATE: = 0.0

func _apply_look(id: String) -> void :
	var look: Dictionary = zones[id].get("look", {})
	var ow: = get_parent()
	var env: = ow.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env:
		var path: = String(look.get("env", ""))
		env.environment = load(path if path != "" and ResourceLoader.exists(path) else DEFAULT_ENV)
	var ground: = ow.get_node_or_null("Ground") as MeshInstance3D
	if ground and ground.mesh and ground.mesh.get_surface_count() > 0:
		var gm: = ground.mesh.surface_get_material(0)
		if gm is ShaderMaterial:
			var g: Dictionary = look.get("ground", {})
			for key in GROUND_TINTS:
				var c: Variant = g.get(key, null)
				gm.set_shader_parameter(key, Color(String(c)) if c != null else GROUND_TINTS[key])
			gm.set_shader_parameter("desaturate", float(g.get("desaturate", GROUND_DESATURATE)))
	var sun: = ow.get_node_or_null("Sun")
	if sun and "base_energy" in sun:
		sun.base_energy = float(look.get("sun_energy", 1.6))

	var rig: = get_tree().get_first_node_in_group("camera_rig")
	if rig and rig.has_method("set_zone_distance"):
		rig.set_zone_distance(float(look.get("camera_distance", 0.0)))

	Settings.apply_quality()



func active_look() -> Dictionary:
	return zones.get(active, {}).get("look", {})



func active_name() -> String:
	return String(zones.get(active, {}).get("name", ""))


func _set_active(id: String, show_name: bool) -> void :
	var _p1_look: = Time.get_ticks_usec()
	_apply_look(id)
	P1Prof.span("streamer _set_active %s _apply_look" % id, Time.get_ticks_usec() - _p1_look)
	active = id

	if id == "viridian_forest":
		AnalyticsBeats.beat_once("forest_entered")
	elif id == "pewter_city":
		AnalyticsBeats.beat_once("pewter_reached")
	zone_changed.emit(id, zones[id].name)
	if show_name:
		Game._msg(zones[id].name, 2.0)
	_apply_canopies()
	print("[zones] active: %s (loaded: %s)" % [id, ", ".join(loaded.keys())])





func _request_nearby(pos: Vector3) -> void :
	if active == "":
		return
	for n in [active] + Array(zones[active].neighbors):
		if not zones.has(n) or loaded.has(n) or _in_flight(n):
			continue
		if n != active and _rect_dist(n, pos) > neighbor_range:
			continue
		_start_load(n)
		break





func _apply_canopies() -> void :
	for zid in loaded:
		var z: Node = loaded[zid]
		if z.has_method("set_canopy_visible"):
			z.set_canopy_visible(zid != active)


func _start_load(id: String) -> void :
	_loading[id] = zones[id].scene
	if _threads:
		ResourceLoader.load_threaded_request(zones[id].scene)
	else:


		_loading.erase(id)
		_pending[id] = ResourceLoader.load(zones[id].scene)


func _poll_loading() -> void :
	var p: Node3D = Game.get_player()
	var pos: = p.global_position if p else Vector3.INF


	for id in _pending.keys():
		if not _in_range(id, pos):
			continue
		var scene: PackedScene = _pending[id]
		_pending.erase(id)
		if not loaded.has(id) and scene != null:
			_add_zone(id, scene)
		return
	for id in _loading.keys():
		var path: String = _loading[id]
		var st: = ResourceLoader.load_threaded_get_status(path)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			if not _in_range(id, pos):
				continue
			_loading.erase(id)
			if not loaded.has(id):
				var _p1_get: = Time.get_ticks_usec()
				var _p1_scene: PackedScene = ResourceLoader.load_threaded_get(path)
				P1Prof.span("streamer threaded_get %s" % id, Time.get_ticks_usec() - _p1_get)
				_add_zone(id, _p1_scene)
				return
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading.erase(id)
			push_error("zones: failed to load %s" % path)


func _in_flight(id: String) -> bool:
	return _loading.has(id) or _pending.has(id)


func _in_range(id: String, pos: Vector3) -> bool:
	return id == active or not pos.is_finite() or _rect_dist(id, pos) <= neighbor_range


func _add_zone(id: String, scene: PackedScene) -> void :
	var _p1_i: = Time.get_ticks_usec()
	var z: Node3D = scene.instantiate()
	P1Prof.span("streamer _add_zone %s instantiate" % id, Time.get_ticks_usec() - _p1_i)
	loaded[id] = z



	if z.has_signal("decorated"):
		z.decorated.connect( func() -> void :
			if loaded.get(id) == z and z.has_method("set_canopy_visible"):
				z.set_canopy_visible(id != active))
	if get_parent().is_node_ready():
		get_parent().add_child(z)
	else:
		get_parent().add_child.call_deferred(z)






func _unload_far(pos: Vector3) -> void :
	if active == "":
		return
	var keep: = [active] + Array(zones[active].neighbors)
	if _preparing != "":
		keep.append(_preparing)
	var free_at: = neighbor_range + unload_margin
	for id in loaded.keys():
		if keep.has(id) or not loaded[id].is_decorated:
			continue
		if _rect_dist(id, pos) <= free_at:
			continue
		print("[zones] unload %s" % id)
		loaded[id].queue_free()
		loaded.erase(id)
