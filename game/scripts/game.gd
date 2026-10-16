extends Node




const CreatureDef: = preload("res://scripts/creature.gd")
const MonScript: = preload("res://scripts/stats/mon.gd")
const CaptureFX: = preload("res://scripts/capture_fx.gd")
const GameStateScript: = preload("res://scripts/state/game_state.gd")


const ControlsScript: = preload("res://scripts/controls.gd")

const MAX_PARTY: = 6

const ITEM_CD: = 3.0
const WORLD_SCENE: = "res://scenes/world/overworld.tscn"



const CHECKPOINTS: = {
	"route1": {"label": "Route 1", "spawn": "r1_south", "party": [["Bulbasaur", 8], ["Pidgey", 6]]}, 
	"viridian": {"label": "Viridian City", "spawn": "vc_center", "party": [["Charmander", 10], ["Rattata", 8]]}, 

	"viridian_center": {"label": "Viridian Pokémon Center (Cable Club)", "spawn": "vc_center_in", 
		"scene": "res://scenes/interiors/viridian_city_interiors.tscn", 
		"party": [["Charmander", 10], ["Rattata", 8], ["Pidgey", 6], ["Rattata", 5]]}, 
	"viridian_parcel": {"label": "Viridian (parcel)", "spawn": "vc_center", "party": [["Charmander", 10], ["Rattata", 8]], "bag": {"potion": 3}}, 
	"route2": {"label": "Route 2", "spawn": "vc_north", "party": [["Charmander", 10], ["Rattata", 8]], 
		"flags": ["has_parcel", "parcel_delivered", "has_pokedex"], "bag": {"potion": 3, "poke_ball": 5}}, 
	"forest": {"label": "Viridian Forest", "spawn": "vf_south", "party": [["Charmander", 12], ["Rattata", 10]], 
		"flags": ["has_parcel", "parcel_delivered", "has_pokedex"], "bag": {"potion": 3, "poke_ball": 5}}, 
	"pewter": {"label": "Pewter City", "spawn": "pw_south", "party": [["Charmander", 14], ["Pidgey", 11]], 
		"flags": ["has_parcel", "parcel_delivered", "has_pokedex"], "bag": {"potion": 3, "poke_ball": 5}}, 
	"gym": {"label": "Pewter Gym", "spawn": "pw_gym_front", 
		"party": [["Charmander", 14], ["Mankey", 13], ["Pidgey", 12]], 
		"flags": ["has_parcel", "parcel_delivered", "has_pokedex"], "bag": {"potion": 3, "poke_ball": 5}}, 
	"demo_end": {"label": "Demo end", "spawn": "pw_gym_door", 
		"party": [["Charmeleon", 20], ["Pidgeotto", 19], ["Mankey", 18], ["Pikachu", 17], ["Nidoking", 16], ["Geodude", 15]], 
		"flags": ["has_parcel", "parcel_delivered", "has_pokedex", "boulder_badge", "trainer_brock"], 
		"bag": {"potion": 5, "poke_ball": 10, "super_potion": 3}}, 
	"pallet": {"label": "Pallet Town", "spawn": "start", "party": [["Squirtle", 5]]}, 

	"route22": {"label": "Route 22", "spawn": "r22_grass", "party": [["Charmander", 10], ["Rattata", 8]], 
		"flags": ["has_parcel", "parcel_delivered", "has_pokedex"], "bag": {"potion": 3, "poke_ball": 5}}, 
	"route22_east": {"label": "Route 22 (east)", "spawn": "r22_east", "party": [["Charmander", 10], ["Rattata", 8]], 
		"flags": ["has_parcel", "parcel_delivered", "has_pokedex"], "bag": {"potion": 3, "poke_ball": 5}}, 

	"forest_north": {"label": "Viridian Forest (north gate)", "spawn": "vf_north", "party": [["Charmander", 12], ["Rattata", 10]], 
		"flags": ["has_parcel", "parcel_delivered", "has_pokedex"], "bag": {"potion": 3, "poke_ball": 5}}, 
}

signal battle_started(fighter, wild)
signal battle_ended(result)
signal party_changed
signal item_used(slot)


var state: = GameStateScript.new()

var whiteout_count: = 0

var _sending: = {}






var party: Array:
	get:
		return state.party
	set(v):
		state.party = v
var flags: Dictionary:
	get:
		return state.flags
	set(v):
		state.flags = v
var companions: Dictionary:
	get:
		return state.companions
	set(v):
		state.companions = v
var bag: Dictionary:
	get:
		return state.bag
	set(v):
		state.bag = v
var selected_ball: String:
	get:
		return state.selected_ball
	set(v):
		state.selected_ball = v
var quick_slots: Array:
	get:
		return state.quick_slots
	set(v):
		state.quick_slots = v
var box: Array:
	get:
		return state.box
	set(v):
		state.box = v
var talking: bool:
	get:
		return state.talking
	set(v):
		state.talking = v
var menu_open: bool:
	get:
		return state.menu_open
	set(v):
		state.menu_open = v
var cutscene: bool:
	get:
		return state.cutscene
	set(v):
		state.cutscene = v
var ally_mode: int:
	get:
		return state.ally_mode
	set(v):
		state.ally_mode = v


var item_cd: float:
	get:
		return Progression.item_cd
	set(v):
		Progression.item_cd = v
var _capturing: bool:
	get:
		return Progression._capturing
	set(v):
		Progression._capturing = v
var _evolving: Dictionary:
	get:
		return Progression._evolving
	set(v):
		Progression._evolving = v




func _ready() -> void :
	ControlsScript.setup(MAX_PARTY)




func _input(event: InputEvent) -> void :
	ControlsScript.note_device(event)


func _process(delta: float) -> void :
	if get_player() != null:
		state.play_time += delta
		_regen_pp(delta)
	ControlsScript.handle_input(self)




const PP_WORLD_REGEN: = 0.005


func _regen_pp(delta: float) -> void :
	if Battle.in_battle:
		return
	for i in party.size():
		var m = party[i]
		if m.hp <= 0 or m.pp >= m.pp_base:
			continue
		m.pp = minf(m.pp_base, m.pp + m.pp_base * PP_WORLD_REGEN * delta)


		var c = companions.get(i)
		if is_instance_valid(c) and c.mon == m:
			c.combat.pp_max = minf(m.pp, c.combat.pp_base)


func is_busy() -> bool:
	return Battle.in_battle or Battle._ambush or state.talking or Transitions.busy() or state.menu_open or state.cutscene




func get_player() -> Node3D:
	return Dialogue.player()



func hero_name() -> String:
	return state.player_name


func get_camera_rig() -> Node:
	return Dialogue.camera_rig()


func get_hud() -> Node:
	return Dialogue.hud()


func _msg(text: String, secs: = 2.5, kind: = "info") -> void :
	Dialogue.msg(text, secs, kind)


func start_dialogue(npc: Node) -> void :
	await Dialogue.start(npc)


func ground_y(pos: Vector3, fallback: = 0.0) -> float:
	return Transitions.ground_y(pos, fallback)



func surface_at(x: float, z: float) -> int:
	return Transitions.surface_at(x, z)



func water_rects() -> Array:
	return Transitions.water_rects()


func is_out(i: int) -> bool:
	return state.is_out(i)


func item_count(id: String) -> int:
	return state.item_count(id)


func add_item(id: String, n: = 1) -> void :
	state.add_item(id, n)
	party_changed.emit()


func remove_item(id: String, n: = 1) -> bool:
	if not state.remove_item(id, n):
		return false
	party_changed.emit()
	return true


func set_quick_slot(k: int, id: String) -> void :
	state.set_quick_slot(k, id)
	party_changed.emit()


func item_targets_party(id: String) -> bool:
	return state.item_targets_party(id)


func item_battle_usable(id: String) -> bool:
	return state.item_battle_usable(id)


func ball_name(id: String) -> String:
	return state.ball_name(id)






func start_checkpoint(id: String) -> void :
	var cp: Dictionary = CHECKPOINTS.get(id, {})
	if cp.is_empty():
		push_warning("[debug] unknown checkpoint '%s' (have: %s)" % [id, ", ".join(CHECKPOINTS.keys())])
		return
	Debug.log("[debug] checkpoint %s -> %s" % [id, cp.get("spawn", "")])
	_apply_checkpoint(cp)
	SaveGame.enabled = false
	await Transitions.go_to(String(cp.get("scene", WORLD_SCENE)), String(cp.get("spawn", "")), true)



func cycle_checkpoint() -> void :
	if is_busy():
		return
	Debug._checkpoint_i = (Debug._checkpoint_i + 1) % CHECKPOINTS.size()
	var id: String = CHECKPOINTS.keys()[Debug._checkpoint_i]
	_msg("Checkpoint: %s" % CHECKPOINTS[id].get("label", id), 2.0)
	start_checkpoint(id)


func _apply_checkpoint(cp: Dictionary) -> void :
	Debug.party = false
	party.clear()
	companions.clear()
	for e in cp.get("party", []):
		var m = MonScript.create(String(e[0]), int(e[1]))
		m.owner = "player"
		party.append(m)
	if not party.is_empty():
		flags["starter_" + String(party[0].species).to_lower()] = true
	flags["oak_stopped"] = true
	flags["starter_chosen"] = true
	flags["rival_battle_done"] = true
	flags["rival_battle_won"] = true
	flags["rival_starter"] = "Charmander"
	for f in cp.get("flags", []):
		flags[String(f)] = true

	var b = cp.get("bag", {"potion": 3})
	bag = b.duplicate() if b is Dictionary else {}
	party_changed.emit()





func receive_starter(sp_name: String, lv: = 5, m = null) -> void :
	if flags.get("starter_chosen", false):
		return
	var mon = state.add_starter(sp_name, lv, m)
	state.mark_caught(sp_name)
	_msg("You received %s!" % sp_name, 3.0)
	Audio.jingle("music/item_get")
	print("[story] starter: %s Lv%d (%s)" % [sp_name, lv, mon.nature])
	party_changed.emit()


func _party_key(i: int, shift: = false) -> void :
	if Battle.online_guest:

		var eng: = get_tree().get_first_node_in_group("online_battle_engine")
		if eng != null:
			eng.request_switch(i)
		return
	if i >= party.size() or state.talking or state.menu_open or Battle._ambush or Battle._intro or Battle._ending or Battle._switching or Progression._capturing or _sending.has(i):
		return
	if is_out(i) and companions[i].evolving:
		_msg("%s is evolving! It can't go back in its ball now." % party[i].display_name, 1.8)
		return
	if Battle.in_battle and is_instance_valid(Battle.partner) and Battle.partner.evolving:
		_msg("%s is evolving!" % Battle.partner.mon.display_name, 1.5)
		return
	if Battle.in_battle:
		if shift:
			Battle._ally_slot(i)
			return
		if is_out(i) and companions[i] == Battle.partner:
			return
		if is_out(i) and Battle.allies.has(companions[i]):
			Battle.swap_control()
			return
		if party[i].hp <= 0:
			_msg("%s has fainted and can't battle!" % party[i].species)
			return
		Battle._switch_fighter(i)
		return
	if is_out(i):
		recall(i)
	else:
		send_out(i)


func heal_party() -> void :
	state.heal_all()
	for i in party.size():
		if is_out(i):
			companions[i].sync_from_mon()
	_msg("Your party is fully healed!")
	Audio.jingle("music/heal")
	party_changed.emit()



func heal_with_fade() -> void :
	await Transitions.fade(1.0, 0.35)
	heal_party()
	await get_tree().create_timer(1.8).timeout
	await Transitions.fade(0.0, 0.35)




func remember_heal_point(home: = false) -> void :
	var p: = get_player()
	if p == null:
		return
	state.last_heal_point = {
		"scene": get_tree().current_scene.scene_file_path, 
		"pos": [p.global_position.x, p.global_position.y, p.global_position.z], 
		"facing": p.row, 
		"home": home, 
	}



func whiteout() -> void :
	whiteout_count += 1
	var tid: String = Battle._an_trainer_id_of()
	Analytics.track("whiteout", {"zone": _analytics_zone(), "trainer_id": tid, 
		"attempt_n": int(Battle._an_attempts.get(tid, 1)) if tid != "" else whiteout_count})
	var p: = get_player()
	if p:
		p.controls_enabled = false
	var nm: = hero_name()
	var loss: = state.whiteout_loss()
	var lines: = PackedStringArray(["%s is out of usable Pokémon!" % nm])
	if loss > 0:
		lines.append("%s panicked and lost %s..." % [nm, GameStateScript.format_money(loss)])
	lines.append("... ... ... ...")
	lines.append("%s scurried %s, protecting the exhausted Pokémon from further harm..." % [
		nm, "home" if state.is_home_heal_point() else "to a Pokémon Center"])
	var hud: = get_hud()
	if hud:
		hud.open_dialog("", lines)
		await hud.dialog_closed
	Audio.clear_jingles()
	Audio.jingle("music/blackout")
	await Transitions.fade(1.0, 0.6)
	state.whiteout()
	Audio.jingle("music/heal")
	var point: = state.heal_point()
	await Transitions.go_to_at(String(point.get("scene", "")), _heal_pos(point), int(point.get("facing", 0)))
	await get_tree().create_timer(1.0).timeout
	await Transitions.fade(0.0, 0.6)



	cutscene = false
	var np: = get_player()
	if np:
		np.controls_enabled = true



func _analytics_zone() -> String:
	var s: = get_tree().get_first_node_in_group("zone_streamer")
	if s and String(s.get("active")) != "":
		return String(s.get("active"))
	var sc: = get_tree().current_scene
	return String(sc.scene_file_path).get_file().get_basename() if sc else ""



func use_escape_rope() -> bool:
	var p: = get_player()
	if p == null or Battle.in_battle:
		return false
	state.repel_steps = 0
	menu_open = false
	talking = false
	cutscene = true
	var point: = state.heal_point()
	await Transitions.fade(1.0, 0.35)
	await Transitions.go_to_at(String(point.get("scene", "")), _heal_pos(point), int(point.get("facing", 0)))
	await Transitions.fade(0.0, 0.35)
	cutscene = false
	var np: = get_player()
	if np:
		np.controls_enabled = true
	return true



func _heal_pos(point: Dictionary) -> Vector3:
	var a = point.get("pos", [])
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO



func send_out(i: int, at = null) -> CreatureDef:
	if is_out(i) or _sending.has(i):
		return companions.get(i)
	if party[i].hp <= 0:
		_msg("%s has fainted!" % party[i].species)
		return null
	var p: = get_player()
	if p == null:
		return null
	_sending[i] = true
	var target: Vector3 = at if at != null else p.global_position + p.facing_vector() * 2.0
	target.y = Transitions.ground_y(target, p.global_position.y)


	if Battle.in_battle and Battle.arena_rect.size.x > 0.0:
		target = Battle.nearest_ok(target, party[i], Battle.arena_rect, Battle._blocked_at(target.y))
		target.y = Transitions.ground_y(target, target.y)
	await _throw_ball(p.global_position + Vector3(0, 1.2, 0), target, party[i].ball)
	if not is_instance_valid(p):
		_sending.erase(i)
		return null
	var c: = Encounters.spawn_mon(party[i], p.get_parent(), target, false)
	Audio.cry(party[i].species, target)
	c.mode = CreatureDef.Mode.IDLE
	companions[i] = c
	var spr: Node3D = c.get_node("Sprite3D")
	spr.scale = Vector3.ONE * 0.05
	var tw: = Battle.fight_tween(self)
	tw.tween_property(spr, "scale", Vector3.ONE * 1.15, 0.15)
	tw.tween_property(spr, "scale", Vector3.ONE, 0.1)
	await tw.finished
	_sending.erase(i)
	if is_instance_valid(c) and c.mode == CreatureDef.Mode.IDLE:
		c.mode = CreatureDef.Mode.FOLLOW
		c.follow_slot = i
	party_changed.emit()
	return c


func recall(i: int) -> void :
	if not is_out(i):
		companions.erase(i)
		return
	var c: CreatureDef = companions[i]
	Audio.play_at("sfx/pokemon/recall", c.global_position)
	companions.erase(i)
	c.mode = CreatureDef.Mode.IDLE
	var p: = get_player()
	var tw: = Battle.fight_tween(self).set_parallel(true)
	tw.tween_property(c.get_node("Sprite3D"), "scale", Vector3.ONE * 0.05, 0.25)
	if p:
		tw.tween_property(c, "global_position", p.global_position + Vector3(0, 1.0, 0), 0.25)
	tw.chain().tween_callback(c.queue_free)
	party_changed.emit()


func _throw_ball(from: Vector3, to: Vector3, ball_id: = "poke_ball") -> void :

	await CaptureFX.send_out(self, get_player().get_parent(), from, to, ball_id)
