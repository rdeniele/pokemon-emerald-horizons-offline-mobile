class_name SaveGame
extends RefCounted





const DEFAULT_PATH: = "user://save.json"

static var path: = DEFAULT_PATH

static var enabled: = false



static func peek() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary and d.get("state") is Dictionary):
		push_warning("[save] %s is not a valid save" % path)
		return {}
	if not ResourceLoader.exists(String(d.get("scene", ""))):
		push_warning("[save] %s points at a missing scene: %s" % [path, d.get("scene")])
		return {}
	return d


static func exists() -> bool:
	return not peek().is_empty()



static func summary_rows(d: Dictionary) -> Array:
	var st: Dictionary = d.get("state", {})
	var party = st.get("party", [])
	return [
		["PLAYER", str(st.get("player_name", GameState.DEFAULT_PLAYER_NAME))], 
		["TIME", GameState.format_time(float(st.get("play_time", 0.0)))], 
		["POKéMON", str(party.size() if party is Array else 0)], 
		["LOCATION", str(d.get("location", "?"))], 
	]



static func snapshot() -> Dictionary:
	var tree: = Game.get_tree()
	var scene: = tree.current_scene
	var d: = {"state": Game.state.to_dict(), "scene": scene.scene_file_path if scene else "", 
		"spawn": "", "pos": null, "row": 0, "location": location_name(), 
		"saved_at": int(Time.get_unix_time_from_system())}
	var p: = Game.get_player()
	if p:
		d.spawn = nearest_spawn(p.global_position)
		d.pos = [p.global_position.x, p.global_position.y, p.global_position.z]
		d.row = int(p.row)
	return d


static func write(d: Dictionary) -> bool:
	var tmp: = path + ".tmp"
	var f: = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("[save] cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	var err: = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		push_warning("[save] rename failed: %s" % error_string(err))
	return err == OK


static func save_now() -> bool:
	var ok: = write(snapshot())
	Debug.log("[save] %s -> %s" % [path, "ok" if ok else "FAILED"])
	return ok


static func can_autosave() -> bool:
	return enabled and Game.get_player() != null and not Battle.in_battle and not Battle._ambush\
	and not Game.cutscene and not Game.talking and not Transitions.busy()



static func autosave() -> void :
	if not can_autosave():
		return
	if save_now():
		var h: = Game.get_hud()
		if h and h.has_method("show_saving"):
			h.show_saving()



static func restore() -> bool:
	var d: = peek()
	if d.is_empty():
		return false
	Game.state.from_dict(d.state)
	await Transitions.go_to(String(d.scene), String(d.get("spawn", "")), true)
	await _place_saved(d)
	enabled = true
	return true


static func _place_saved(d: Dictionary) -> void :
	var p: = Game.get_player()
	var pos = d.get("pos")
	if p == null or not (pos is Array and pos.size() == 3):
		return
	var v: = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	p.global_position = v
	p.row = clampi(int(d.get("row", 0)), 0, 3)
	p.sprite.frame = p.row * 3


	Transitions.snap_arrival_hooks()
	var cam: = Game.get_camera_rig()
	if cam:
		cam.snap()
	for _i in 3:
		await Game.get_tree().physics_frame
	if p.global_position.y < v.y - 2.0:
		push_warning("[save] saved position %s has no floor; using spawn %s" % [v, d.get("spawn")])
		Transitions.pending_spawn = String(d.get("spawn", ""))
		Transitions.place_player(p)



static func location_name() -> String:
	var tree: = Game.get_tree()
	var streamer: = tree.get_first_node_in_group("zone_streamer")
	if streamer and streamer.zones.has(streamer.active):
		return String(streamer.zones[streamer.active].name)
	var scene: = tree.current_scene
	if scene == null:
		return ""
	return scene.scene_file_path.get_file().get_basename().trim_suffix("_interiors").capitalize()



static func nearest_spawn(pos: Vector3) -> String:
	var tree: = Game.get_tree()
	var allowed: = {}
	var streamer: = tree.get_first_node_in_group("zone_streamer")
	if streamer and streamer.zones.has(streamer.active):
		for s in streamer.zones[streamer.active].spawns:
			allowed[String(s)] = true
	var best: = ""
	var best_d: = INF
	for sp in tree.get_nodes_in_group("spawn_point"):
		if not allowed.is_empty() and not allowed.has(String(sp.name)):
			continue
		var dist: float = pos.distance_squared_to(sp.global_position)
		if dist < best_d:
			best_d = dist
			best = String(sp.name)
	return best
