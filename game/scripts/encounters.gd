extends Node



const CreatureDef: = preload("res://scripts/creature.gd")
const MonScript: = preload("res://scripts/stats/mon.gd")
const CREATURE_SCENE: = preload("res://scenes/creature.tscn")


var _tables: = {}

var _rates: = {}




func load_table(path: String) -> Array:
	if not _tables.has(path):
		var entries: Array = []
		var f: = FileAccess.open(path, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				entries = data.get("entries", [])
		_tables[path] = entries
	return _tables[path]





func table_rate(path: String) -> int:
	if not _rates.has(path):
		var rate: = 21
		var f: = FileAccess.open(path, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			if data is Dictionary and data.has("rate"):
				rate = int(data["rate"])
		_rates[path] = rate
	return _rates[path]



func roll(path: String, mode: String) -> Dictionary:
	var pool: Array = []
	var total: = 0.0
	for e in load_table(path):
		var m: String = e.get("mode", "both")
		if m == mode or m == "both":
			pool.append(e)
			total += float(e.get("weight", 1))
	if pool.is_empty():
		return {}
	var r: = randf() * total
	for e in pool:
		r -= float(e.get("weight", 1))
		if r <= 0.0:
			return e
	return pool[-1]



func spawn_creature(entry: Dictionary, parent: Node, pos: Vector3, is_wild: = true) -> CreatureDef:
	var lr: Array = entry.get("level_range", [2, 4])
	var lv: = int(entry.level) if entry.has("level") else randi_range(int(lr[0]), int(lr[1]))
	var m = MonScript.create(entry.get("species", "Bulbasaur"), lv)
	var behaviours: = {"passive": CreatureDef.Behaviour.PASSIVE, "flee": CreatureDef.Behaviour.FLEE, "aggressive": CreatureDef.Behaviour.AGGRESSIVE}
	return spawn_mon(m, parent, pos, is_wild, behaviours.get(entry.get("behaviour", "passive"), CreatureDef.Behaviour.PASSIVE))



func spawn_mon(m: RefCounted, parent: Node, pos: Vector3, is_wild: = true, behaviour: = 0) -> CreatureDef:
	var c: CreatureDef = CREATURE_SCENE.instantiate()
	c.mon = m
	c.is_wild = is_wild
	c.species = m.species
	c.level = m.level
	c.behaviour = behaviour
	c.position = pos
	parent.add_child(c)
	return c




func grass_encounter(p: Node3D, table: String) -> void :
	if Game.is_busy() or Game.party.is_empty():
		return
	var e: = roll(table, "grass")
	if e.is_empty():
		return
	Battle._ambush = true
	p.controls_enabled = false


	var grass = p.get("_grass")
	if grass is Array and not grass.is_empty():
		var g: Node = grass[-1]
		if g.has_method("shake"):
			g.shake(p.global_position)
	p.show_alert(true)
	await get_tree().create_timer(0.6).timeout
	p.show_alert(false)
	var target: Vector3 = p.global_position + p.facing_vector() * 2.2
	target.y = Transitions.ground_y(target, p.global_position.y)
	var c: = spawn_creature(e, p.get_parent(), target + Vector3(0, -0.8, 0))
	c.mode = CreatureDef.Mode.IDLE
	var tw: = create_tween()
	tw.tween_property(c, "position", target + Vector3(0, 1.3, 0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position", target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	Battle._ambush = false
	Battle.start_battle(c)
