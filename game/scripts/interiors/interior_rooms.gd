extends Node3D
















@export_file("*.json") var manifest: = ""

var rooms: = {}
var order: Array = []
var built: = {}

var _failed: = {}

var _holding: = ""

var _holding_all: = false
var _player: Node3D


func _ready() -> void :
	_load_manifest()
	_player = get_tree().get_first_node_in_group("player") as Node3D





	var t: = get_node_or_null("/root/Transitions")
	if t:
		prepare_arrival(String(t.pending_spawn), t.pending_point)
	else:
		sync_rooms()


func _process(_delta: float) -> void :
	sync_rooms()






func prepare_arrival(spawn: = "", point: = Vector3.INF) -> void :
	if rooms.is_empty():
		_load_manifest()
	var want: = ""
	if point.is_finite():
		want = room_at(point)
	if want == "" and spawn != "":
		for name in order:
			if spawn in rooms[name].get("spawns", []):
				want = name
				break
	if want != "":
		_own(want)





func sync_rooms() -> void :
	if _holding_all:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return
	var want: = room_at(_player.global_position)
	if want == "":
		return
	_own(want)



func _own(room_name: String) -> void :
	if _holding_all or room_name == "" or not rooms.has(room_name):
		return
	if room_name == _holding and built.has(room_name):
		return
	_holding = room_name
	if room_name == "PewterGym":
		AnalyticsBeats.beat_once("gym_entered")
	var keep: = {room_name: true}
	for n in rooms[room_name].get("next", []):
		keep[String(n)] = true
	for name in built.keys():
		if not keep.has(name):
			_free_room(name)
	for name in rooms:
		if keep.has(name):
			ensure_room(name)



func room_at(pos: Vector3) -> String:
	var p: = Vector2(pos.x, pos.z)
	for name in order:
		var r: Array = rooms[name]["rect"]
		if Rect2(r[0], r[1], r[2], r[3]).has_point(p):
			return name
	return ""



func ensure_room(room_name: String) -> Node3D:
	var live: Node3D = built.get(room_name)
	if is_instance_valid(live):
		return live
	if rooms.is_empty():
		_load_manifest()
	var spec: Dictionary = rooms.get(room_name, {})
	if spec.is_empty():
		push_error("interiors: no room '%s' in %s" % [room_name, manifest])
		return null
	if _failed.has(room_name):
		return null
	var scene: PackedScene = load(String(spec["scene"]))
	if scene == null:
		push_error("interiors: cannot load room scene %s" % spec["scene"])
		_failed[room_name] = true
		return null
	live = scene.instantiate()
	add_child(live)
	built[room_name] = live
	return live




func build_all() -> void :
	_holding_all = true
	if rooms.is_empty():
		_load_manifest()
	for name in rooms:
		ensure_room(name)



func release_all() -> void :
	_holding_all = false
	_holding = ""
	sync_rooms()


func _free_room(room_name: String) -> void :
	var live: Node3D = built.get(room_name)
	built.erase(room_name)
	if live == null or not is_instance_valid(live):
		return


	remove_child(live)
	live.queue_free()


func _load_manifest() -> void :
	if manifest.is_empty() or not FileAccess.file_exists(manifest):
		push_error("interiors: no room manifest at '%s'" % manifest)
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	if d == null or not (d.get("rooms") is Array):
		push_error("interiors: bad room manifest %s" % manifest)
		return
	for r in d["rooms"]:
		var name: = String(r["node"])
		rooms[name] = r
		order.append(name)
