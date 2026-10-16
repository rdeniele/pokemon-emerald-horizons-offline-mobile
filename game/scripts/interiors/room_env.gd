extends WorldEnvironment





const DEFAULT_ENV: = "res://resources/look/interior_env.tres"

var _poll: = 0.0
var _path: = ""


func _process(delta: float) -> void :
	_poll += delta
	if _poll < 0.25:
		return
	snap()





func snap() -> void :
	_poll = 0.0
	var path: = _env_for_player()
	if path == _path:
		return
	_path = path
	environment = load(path)


	var s: = get_node_or_null("/root/Settings")
	if s and s.has_method("apply_quality"):
		s.apply_quality()


func _env_for_player() -> String:
	var p: = get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return DEFAULT_ENV
	var pos: = Vector2(p.global_position.x, p.global_position.z)
	for b in get_parent().get_children():
		var room: = b.get_node_or_null("Room") as Node3D
		if room == null:
			continue
		var size = room.get("size")
		if size == null:
			continue
		if Rect2(Vector2(room.global_position.x, room.global_position.z) - size * 0.5, size).has_point(pos):
			return String(b.get_meta("env", DEFAULT_ENV))
	return DEFAULT_ENV
