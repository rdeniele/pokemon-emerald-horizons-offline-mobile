extends Node3D












signal built
signal decorated

@export var zone_id: = ""
@export var display_name: = ""

var is_built: = false
var is_decorated: = false


func _ready() -> void :
	var w: = get_node_or_null("World")
	if w == null:
		_on_built()
		_on_decorated()
		return

	if w.is_built:
		_on_built()
	else:
		w.built.connect(_on_built, CONNECT_ONE_SHOT)
	if w.is_decorated:
		_on_decorated()
	else:
		w.decorated.connect(_on_decorated, CONNECT_ONE_SHOT)


func _on_built() -> void :
	is_built = true
	built.emit()


func _on_decorated() -> void :
	is_decorated = true
	decorated.emit()






func set_canopy_visible(show_canopy: bool) -> void :
	var w: = get_node_or_null("World")
	if w == null or w.canopy == null:
		return
	w.canopy.visible = show_canopy
	var spawns: = get_node_or_null("SpawnZones")
	if spawns:
		spawns.visible = not show_canopy
