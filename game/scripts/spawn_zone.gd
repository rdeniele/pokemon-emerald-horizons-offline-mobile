extends Node3D








@export_file("*.json") var encounter_table: = "res://data/encounters/route_1.json"
@export var radius: = 8.0
@export var max_alive: = 3
@export var respawn_min: = 20.0
@export var respawn_max: = 30.0
@export var min_player_dist: = 14.0


@export var mode: = "visible"


const WATER_LAYER: = 8

var _alive: Array = []
var _pending: Array = []
var _filled: = false


func _physics_process(delta: float) -> void :
	if Debug.no_encounters:
		return


	var zone: = get_parent().get_parent()
	if zone and zone.get("is_built") == false:
		return
	if zone and zone.get("is_decorated") == false:
		return
	var before: = _alive.size()
	_alive = _alive.filter( func(c): return is_instance_valid(c))
	for i in before - _alive.size():
		_pending.append(randf_range(respawn_min, respawn_max))
	if not _filled:
		_filled = true
		for i in max_alive:
			_spawn(false)
		return
	if Battle.in_battle:
		return
	for i in range(_pending.size() - 1, -1, -1):
		_pending[i] -= delta
		if _pending[i] > 0.0:
			continue
		if _alive.size() >= max_alive or _spawn(true):
			_pending.remove_at(i)
		else:
			_pending[i] = 5.0



func _spawn(hidden_from_player: bool) -> bool:
	var e: = Encounters.roll(encounter_table, mode)
	if e.is_empty():
		return false
	var pos: = _free_point(hidden_from_player)
	if pos == Vector3.INF:
		return false
	_alive.append(Encounters.spawn_creature(e, get_parent(), pos))
	return true



func _water_rects() -> Array:
	var zone: = get_parent().get_parent() if get_parent() else null
	var w: Node = zone.get_node_or_null("World") if is_instance_valid(zone) else null
	var out: Array = []
	if w == null or not w.data:
		return out
	for wt in w.data.get("water", []):
		var r: Array = wt.rect
		out.append(Rect2(r[0], r[1], r[2], r[3]))
	return out




func _free_point(hidden_from_player: = false) -> Vector3:
	var space: = get_world_3d().direct_space_state
	var shape: = SphereShape3D.new()
	shape.radius = 0.6
	var q: = PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collide_with_areas = false
	if mode == "swim":
		q.collision_mask = ~ WATER_LAYER
	var player: = Game.get_player()
	var water: Array = _water_rects() if mode == "swim" else []
	for attempt in 24:
		var p: Vector3
		if mode == "swim":
			if water.is_empty():
				return Vector3.INF
			var r: Rect2 = water[randi() % water.size()]
			p = Vector3(randf_range(r.position.x, r.end.x), 0.0, randf_range(r.position.y, r.end.y))
		else:
			var a: = randf() * TAU
			var rad: = sqrt(randf()) * radius
			p = global_position + Vector3(cos(a) * rad, 0.0, sin(a) * rad)
		p.y = Game.ground_y(p, global_position.y)
		if absf(p.y - global_position.y) > 0.6:
			continue
		if hidden_from_player and player and p.distance_to(player.global_position) < min_player_dist:
			continue
		q.transform = Transform3D(Basis(), p + Vector3(0, 0.8, 0))
		if space.intersect_shape(q, 1).is_empty():
			return p
	return Vector3.INF
