extends RefCounted






static var _defs: = {}
static var _loaded: = false


static func _ensure() -> void :
	if _loaded:
		return
	_loaded = true
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/trainers.json"))
	if d is Dictionary:
		_defs = d
		_defs.erase("_doc")


static func get_def(id: String) -> Dictionary:
	_ensure()
	return _defs.get(id, {})



static func display_name(id: String) -> String:
	var d: = get_def(id)
	if d.is_empty():
		return id
	var cls: = String(d.get("class", "")).replace("_", " ").to_upper()
	var nm: = String(d.get("name", "")).to_upper()
	return (cls + " " + nm).strip_edges()
