extends Node





const CreatureDef: = preload("res://scripts/creature.gd")
const MonScript: = preload("res://scripts/stats/mon.gd")
const Dex: = preload("res://scripts/dex.gd")
const Growth: = preload("res://scripts/stats/growth.gd")
const TEST_PARTY: = [["Bulbasaur", 6], ["Rattata", 5], ["Pidgey", 5]]



static var enabled: = OS.is_debug_build() and not ("--no-debug" in OS.get_cmdline_user_args() + OS.get_cmdline_args())

var cycle: = 0.0
var battle: = false
var engage: = false
var battle_after: = 0.0
var quick_item: = -1
var slowmo_all: = false
var slowmo: = 0.0
var send_all: = false
var talk: = false
var summary: = false
var captures: = 0
var party: = false
var checkpoint: = ""


var time_arg: = ""
var bag: = false
var auto_dialog: = false
var bag_use: = ""
var exp: = 0
var ally_slot: = -1
var auto_test_party: = true
var arena_debug: = false
var no_encounters: = false
var autoplay_sturdy: = true
var autoplay_force_lose: = false
var recording: = false

var _cycle_t: = 0.0
var _checkpoint_i: = -1
var _f10_held: = false
var _f5_held: = false
var _f6_held: = false
var _f7_held: = false
var _f8_held: = false
var _scene_checked: = false


func _ready() -> void :
	if not enabled:
		set_process(false)
		return
	_parse_start_arg()




static func log(msg) -> void :
	if enabled:
		print(msg)




func autoplay_boost(level: int) -> void :
	if not enabled:
		return
	var story: = get_node_or_null("/root/Story")
	if story == null or not story.debug_autoplay:
		return
	for m in Game.party:
		if m.level < level:
			m.level = level
			m.moves = Dex.moves_at(String(m.species), level)
			m.xp = Growth.exp_for_level(String(m.growth), level)
			m.recalc()
		m.heal_full()
	Game.party_changed.emit()
	Debug.log("[debug] autoplay boost -> Lv%d" % level)




func _parse_start_arg() -> void :
	if not enabled:
		return
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--start="):
			checkpoint = a.substr("--start=".length())
		elif a.begins_with("--time="):
			time_arg = a.substr("--time=".length())




func _apply_time(arg: String) -> void :
	var clock: = get_node_or_null("/root/Clock")
	if clock == null:
		return
	var parts: = arg.split(",")
	if parts.size() == 2:
		var day: = Clock.day_index_of_name(parts[0])
		var hm: = parts[1].split(":")
		if day >= 0 and hm.size() == 2 and hm[0].is_valid_int() and hm[1].is_valid_int():
			clock.set_time(day, int(hm[0]), int(hm[1]))
			Debug.log("[debug] --time=%s -> %s" % [arg, Clock.format(clock.minutes)])
			return
	if clock.jump_to_period(arg):
		Debug.log("[debug] --time=%s -> %s" % [arg, Clock.format(clock.minutes)])
		return
	printerr("[debug] --time=%s: want a period (morning|midday|afternoon|sunset|night) or <day>,<HH:MM>" % arg)


func _process(delta: float) -> void :
	if not enabled:
		return
	if not _scene_checked and get_tree().current_scene:
		_scene_checked = true
		var main: String = ProjectSettings.get_setting("application/run/main_scene", "")
		if auto_test_party and Game.party.is_empty() and get_tree().current_scene.scene_file_path != main:
			party = true
			Debug.log("[debug] test scene: giving TEST_PARTY")


	var story: = get_node_or_null("/root/Story")
	if story != null and story.debug_autoplay and Battle.in_battle and is_instance_valid(Battle.partner)\
	and Battle.partner.hp > 0 and not Battle._ending and not Battle._intro:
		if autoplay_force_lose:
			Battle.partner.take_damage(999999, Vector3.ZERO)
		elif autoplay_sturdy:
			var floor_hp: = int(ceil(0.5 * Battle.partner.max_hp))
			if Battle.partner.hp < floor_hp:
				Battle.partner.heal(floor_hp - Battle.partner.hp)
	if checkpoint != "" and get_tree().current_scene and not Game.is_busy():
		var cp_id: = checkpoint
		checkpoint = ""
		Game.start_checkpoint(cp_id)
	if time_arg != "" and Game.get_player() != null and not Game.is_busy():
		var arg: = time_arg
		time_arg = ""
		_apply_time(arg)
	if Input.is_physical_key_pressed(KEY_F10):
		if not _f10_held:
			_f10_held = true
			Game.cycle_checkpoint()
	else:
		_f10_held = false

	if Input.is_physical_key_pressed(KEY_F8):
		if not _f8_held:
			_f8_held = true
			var w: = get_tree().get_first_node_in_group("weather")
			if w != null:
				w.toggle_overlay()
	else:
		_f8_held = false
	if Input.is_physical_key_pressed(KEY_F9) and Game.party.is_empty():
		party = true
		Dialogue.msg("Debug: test party given.", 1.5)

	if Input.is_physical_key_pressed(KEY_F5):
		if not _f5_held:
			_f5_held = true
			Dialogue.msg("Debug: time -> %s" % Clock.next_period().to_upper(), 1.5)
	else:
		_f5_held = false
	if Input.is_physical_key_pressed(KEY_F6):
		if not _f6_held:
			_f6_held = true
			Clock.toggle_fast()
			Dialogue.msg("Debug: time x%d" % int(Clock.scale), 1.5)
	else:
		_f6_held = false
	if Input.is_physical_key_pressed(KEY_F7):
		if not _f7_held:
			_f7_held = true
			Clock.set_time(0, 9, 0)
			Dialogue.msg("Debug: time -> MON 9:00", 1.5)
	else:
		_f7_held = false
	if exp > 0 and not Game.party.is_empty():
		Progression._report_exp(Game.party[0], Game.party[0].add_exp(exp), exp)
		exp = 0
	if party:
		party = false
		if Game.party.is_empty():
			for e in TEST_PARTY:
				var tm = MonScript.create(e[0], e[1])
				tm.owner = "player"
				Game.party.append(tm)
			Game.flags["starter_chosen"] = true
			Game.party_changed.emit()
	if slowmo > 0.0:
		Engine.time_scale = slowmo if (Battle._intro or (slowmo_all and Battle.in_battle)) else 1.0
	if quick_item >= 0 and Battle.in_battle and not Battle._intro and is_instance_valid(Battle.partner)\
	and Battle.partner.hp < Battle.partner.max_hp and Progression.item_cd <= 0.0:
		Progression.use_quick_item(quick_item)
		quick_item = -1
	if Battle.in_battle and not Battle._intro and not Battle._ending:
		if cycle > 0.0:
			_cycle_t += delta
			if _cycle_t >= cycle:
				_cycle_t = 0.0
				Battle.swap_control()
				Battle.cycle_ally_mode()
		if ally_slot >= 0 and not Battle._switching:
			var k: = ally_slot
			ally_slot = -1
			Battle._ally_slot(k)
	if captures > 0 and Battle.in_battle and is_instance_valid(Battle.partner) and not Progression._capturing and not Battle._ending:
		captures -= 1
		Progression.throw_capture()
	if talk and not Game.is_busy() and Dialogue.player() and Dialogue.player()._focus_npc:
		talk = false
		Dialogue.start(Dialogue.player()._focus_npc)
	if send_all and Dialogue.player():
		send_all = false
		for i in Game.party.size():
			Game.send_out(i, Dialogue.player().global_position + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 2.0)
	if battle_after > 0.0:
		battle_after -= delta
		if battle_after <= 0.0:
			battle = true
	if engage and not Game.is_busy() and Game._sending.is_empty():
		var pe: = Dialogue.player()
		var near: CreatureDef = null
		for n in get_tree().get_nodes_in_group("wild"):
			if pe and n.visible and n.alive() and (near == null or n.global_position.distance_to(pe.global_position) < near.global_position.distance_to(pe.global_position)):
				near = n
		if near:
			engage = false
			Debug.log("[debug] engage %s at %s" % [near.species, near.global_position])
			Battle.engage(near)
	if battle and not Game.is_busy() and Game._sending.is_empty():
		var p: = Dialogue.player()
		var best: CreatureDef = null
		for n in get_tree().get_nodes_in_group("wild"):
			if p and (best == null or n.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position)):
				best = n
		if best:
			battle = false
			Debug.log("[debug] battle with %s at %s" % [best.species, best.global_position])
			Battle.start_battle(best)








static var ai_log: Array = []
var _ai_hooked: = false

func ai_hook() -> void :
	if _ai_hooked:
		return
	var moves: = get_node_or_null("/root/Moves")
	if moves == null:
		return
	_ai_hooked = true
	moves.move_used.connect(_on_ai_move_used)

func _on_ai_move_used(user, mv: Dictionary) -> void :
	if not enabled or user == null or not is_instance_valid(user) or not (user is Node):
		return
	var opp = user.get("opponent")
	var hp_frac: = -1.0
	var exp_dmg: = 0.0
	if is_instance_valid(opp) and opp is Node:
		hp_frac = float(opp.hp) / maxf(float(opp.max_hp), 1.0)
		if user.has_method("_moves"):
			exp_dmg = user._moves().expected_damage(user, opp, mv)
	var trainer: = false
	if user.get("combat") != null:
		trainer = bool(user.combat.is_trainer_mon)
	var dist: = -1.0
	if is_instance_valid(opp) and opp is Node:
		dist = user.global_position.distance_to(opp.global_position)
	var cds: Dictionary = {}
	if user.get("move_cd") is Dictionary:
		cds = (user.move_cd as Dictionary).duplicate()


	var dmg_all: Dictionary = {}
	if is_instance_valid(opp) and opp is Node and user.get("moves") != null and user.has_method("_moves"):
		for id in user.moves:
			dmg_all[String(id)] = user._moves().expected_damage(user, opp, Dex.move(String(id)))
	ai_log.append({
		"species": String(user.species), "move": String(mv.get("id", "")), 
		"mode": int(user.mode), "wild": bool(user.is_wild), "trainer": trainer, 
		"target": String(opp.species) if is_instance_valid(opp) else "", 
		"hp_frac": hp_frac, "exp_dmg": exp_dmg, "dist": dist, "cd": cds, 
		"stamina": float(user.stamina), "pp": float(user.pp_max), "dmg_all": dmg_all, 
	})
	Debug.log("[ai] %s(%s) used %s -> %s (hp %.2f, dmg %.1f)" % [
		String(user.species), "wild" if bool(user.is_wild) else "ally", String(mv.get("id", "")), 
		String(opp.species) if is_instance_valid(opp) else "-", hp_frac, exp_dmg])
