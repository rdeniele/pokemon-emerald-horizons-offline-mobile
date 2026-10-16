extends RefCounted







const POCKETS: = [["medicine", "Medicine"], ["berries", "Berries"], ["balls", "Poké Balls"], ["battle", "Battle Items"], ["key", "Key Items"]]

static var _items: = {}


static func _ensure() -> void :
	if not _items.is_empty():
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	for b in d.get("balls", []):
		var e: Dictionary = b.duplicate()
		e["category"] = "balls"
		_items[e.id] = e
	for it in d.get("items", []):
		_items[it.id] = it


static func item(id: String) -> Dictionary:
	_ensure()
	return _items.get(id, {"id": id, "name": id.capitalize(), "category": "key", "description": ""})


static func item_name(id: String) -> String:
	return item(id).get("name", id)


static func pocket_of(id: String) -> String:
	return item(id).get("category", "key")


static func all_ids() -> Array:
	_ensure()
	return _items.keys()
