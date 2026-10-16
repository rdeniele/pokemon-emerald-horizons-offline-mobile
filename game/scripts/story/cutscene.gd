extends Node


const NPC_SCENE: = preload("res://scenes/npc.tscn")
const Items: = preload("res://scripts/items.gd")
const INTERIORS: = "res://scenes/interiors/pallet_town_interiors.tscn"
const OVERWORLD: = "res://scenes/world/overworld.tscn"




static func receive_jingle(id: String) -> String:
	if id == "pokedex":
		return "music/pokedex_obtained"
	if Items.pocket_of(id) == "key":
		return "music/key_item"
	return "music/item_get"

var running: = false



func begin(wait_free: = true) -> void :
	while wait_free and Game.is_busy():
		await get_tree().process_frame
	running = true
	Game.cutscene = true
	var p: = player()
	if p:
		p.controls_enabled = false


func end() -> void :
	Game.cutscene = false
	running = false
	var p: = player()
	if p:
		p.script_move = Vector2.ZERO
		p.controls_enabled = true
		var cam: = Game.get_camera_rig()
		if cam:
			cam.focus_follow(p)
	SaveGame.autosave()


func player() -> Node3D:
	return Game.get_player()


func hud() -> Node:
	return Game.get_hud()


func say(speaker: String, lines: Array) -> void :
	var h: = hud()
	if h == null:
		return
	h.open_dialog(speaker, PackedStringArray(lines))
	await h.dialog_closed


func ask(speaker: String, question: String) -> bool:
	var h: = hud()
	if h == null:
		return false
	return await h.ask_yes_no(speaker, question)


func wait(secs: float) -> void :
	await get_tree().create_timer(secs).timeout



func receive_item(id: String, n: int, label: String, from: = "") -> void :
	Game.add_item(id, n)
	Audio.jingle(receive_jingle(id))
	var tail: = (" from %s" % from) if from != "" else ""
	await say("", ["%s received %s%s!" % [Game.state.player_name, label, tail]])


func goto(scene_path: String, spawn: String) -> void :
	await Transitions.go_to(scene_path, spawn, true)


func find_npc(npc_name: String) -> Node3D:
	for n in get_tree().get_nodes_in_group("npc"):
		if n.get("npc_name") == npc_name and n is CharacterBody3D and not n.is_queued_for_deletion():
			return n
	return null



func spawn_npc(npc_name: String, sprite_path: String, pos: Vector3) -> Node3D:
	var n: = NPC_SCENE.instantiate()
	n.npc_name = npc_name
	n.sprite_sheet = load(sprite_path)
	n.scripted = true
	player().get_parent().add_child(n)
	n.global_position = pos
	return n


func face_each_other(a: Node3D, b: Node3D) -> void :
	if a.has_method("face"):
		a.face(b.global_position - a.global_position)
	if b.has_method("face_toward"):
		b.face_toward(a.global_position)
	elif b.has_method("face"):
		b.face(a.global_position - b.global_position)
