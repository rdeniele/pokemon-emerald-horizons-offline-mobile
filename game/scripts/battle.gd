extends Node








const CreatureDef: = preload("res://scripts/creature.gd")
const BattleArena: = preload("res://scripts/battle_arena.gd")
const ItemsData: = preload("res://scripts/items.gd")
const Growth: = preload("res://scripts/stats/growth.gd")
const DexData: = preload("res://scripts/dex.gd")
const UiKit: = preload("res://scripts/ui/kit/ui_kit.gd")


const WILD_OPENING_DELAY: = 0.5




const SPEED_FAST: = 1.0
const SPEED_SLOW: = 0.6

const ARENA_SIZE: = 12.0

const BATTLE_CAM_EXTRA: = 2.0

const ARENA_CAM_DIST: = 14.0


const WATER_LAND_BAR: = 0.4


const ARENA_BLOCK_LAYERS: = 1 | 2

const BATTLE_SIZE: = 2

const SUPPORT_HEAL_AT: = 0.5




func _zone_look() -> Dictionary:
	var s: = get_tree().get_first_node_in_group("zone_streamer")
	return s.active_look() if s and s.has_method("active_look") else {}


func _battle_cam_dist() -> float:
	var look: = _zone_look()
	if look.has("battle_camera_distance"):
		return float(look["battle_camera_distance"])
	var rig: = get_tree().get_first_node_in_group("camera_rig")
	if rig and rig.has_method("_base_dist"):
		return float(rig._base_dist()) + BATTLE_CAM_EXTRA
	return ARENA_CAM_DIST

var in_battle: = false


var speed: = SPEED_FAST

var trainer_battle: = {}



var online: = false
var online_guest: = false
var partner: CreatureDef
var allies: Array = []
var wild: CreatureDef
var _ambush: = false

var _static_uid: = ""
var _intro: = false
var _intro_skip: = false

var _battle_paused: = false
var _hidden: = {}
var _arena: Node3D

var _lead_spot: = Vector3.INF

var arena_rect: = Rect2()
var _combatants: Array = []
var _ending: = false
var _switching: = false

var _foe_switching: = false

var _participants: Array = []

var _exp_results: Array = []

var _awaiting_confirm: = false

var autopilot: = false





var tut_locked: = false
var tut_move: = -1
var tut_walk: = false
var tut_hold_foe: = false


var pause_for_evolution: = false


var _an_on: = false
var _an_started_ms: = 0
var _an_moves: = {}
var _an_hits_landed: = 0
var _an_hits_taken: = 0
var _an_switches: = 0
var _an_items: = 0
var _an_jumps: = 0
var _an_kind: = ""
var _an_trainer_id: = ""
var _an_attempts: = {}



func clear_tut_lock() -> void :
	tut_locked = false
	tut_move = -1
	tut_walk = false
	tut_hold_foe = false


func _ready() -> void :
	Game.battle_started.connect(_an_battle_started)
	Game.battle_ended.connect(_an_battle_ended)
	Game.item_used.connect(_an_item_used)





const MODAL_SLOW: = 0.2








func fight_speed() -> float:
	if not in_battle or _intro or _ending:
		return 1.0
	if online or online_guest:
		return 1.0
	if _battle_paused:
		return 0.0
	if Progression._capturing:
		return 1.0
	if Controls.items_page_held() or _ring_open():
		return speed * MODAL_SLOW
	return speed



func _ring_open() -> bool:
	var h: = Game.get_hud()
	if h == null:
		return false
	var ring: = h.get_node_or_null("party_ring")
	return ring != null and ring.is_open




func fight_scale() -> float:
	var s: = fight_speed()
	return 1.0 / s if s > 0.0 else 1000000000.0



func fight_timer(secs: float) -> SceneTreeTimer:
	return get_tree().create_timer(secs * fight_scale())




func fight_tween(n: Node) -> Tween:
	return n.create_tween().set_speed_scale(fight_speed())




func _process(_delta: float) -> void :
	if online_guest:
		return
	if in_battle and not _intro and not _ending:
		_support_heal()





func _next_healthy(prefer_out: = true) -> int:
	var busy: Array = allies.filter( func(a): return is_instance_valid(a)).map( func(a): return a.mon)
	for pass_out in ([true, false] if prefer_out else [false]):
		for i in Game.party.size():
			if Game.party[i].hp > 0 and not busy.has(Game.party[i]) and not Game._sending.has(i) and ( not pass_out or Game.state.is_out(i)):
				return i
	return -1



func ai_ally() -> CreatureDef:
	for a in allies:
		if is_instance_valid(a) and a != partner and a.mode != CreatureDef.Mode.FAINTED:
			return a
	return null


func _fighter_mode(c: CreatureDef) -> int:
	return CreatureDef.Mode.PLAYER if c == partner and not autopilot else CreatureDef.Mode.BATTLE_AI



func swap_control() -> void :
	if online_guest:
		return
	if not in_battle or _intro or _ending or _switching or Progression._capturing:
		return
	var other: = ai_ally()
	if other == null or other.evolving or (is_instance_valid(partner) and partner.evolving):
		return
	var old: = partner
	partner = other
	Audio.ui("sfx/ui/swap_control")
	for c in [old, other]:
		if is_instance_valid(c) and c.mode != CreatureDef.Mode.FAINTED:
			c.mode = _fighter_mode(c)
			c.velocity = Vector3.ZERO
	Dialogue.msg("Go, %s!" % other.mon.display_name, 1.0, "info")
	Game.party_changed.emit()



func cycle_ally_mode() -> void :
	Game.state.ally_mode = (Game.state.ally_mode + 1) % CreatureDef.ALLY_MODE_NAMES.size()
	var slot: String = ["sfx/ui/mode_attack", "sfx/ui/mode_defend", "sfx/ui/mode_support"][Game.state.ally_mode]
	Audio.ui(slot)
	var a: = ai_ally()
	if a:
		get_node("/root/Vfx").popup(a.global_position + Vector3(0, 1.4, 0), CreatureDef.ALLY_MODE_NAMES[Game.state.ally_mode], CreatureDef.ALLY_MODE_COLORS[Game.state.ally_mode], 1.0, "info")
	print("[battle] ally mode: ", CreatureDef.ALLY_MODE_NAMES[Game.state.ally_mode])



func _support_heal() -> void :
	if online or online_guest:
		return
	if Game.state.ally_mode != CreatureDef.AllyMode.SUPPORT or Progression.item_cd > 0.0 or Progression._capturing or _switching:
		return
	var a: = ai_ally()
	if a == null or not a.can_act() or not is_instance_valid(partner) or partner.evolving or partner.mode == CreatureDef.Mode.FAINTED:
		return
	if float(partner.hp) / maxf(partner.max_hp, 1) >= SUPPORT_HEAL_AT:
		return
	var id: = Game.state.best_heal_item(partner.max_hp - partner.hp)
	if id == "":
		return
	var r: = Progression.use_item(id, Game.party.find(partner.mon))
	if r.ok:
		Progression.item_cd = Game.ITEM_CD
		get_node("/root/Vfx").burst(partner.global_position + Vector3(0, 0.6, 0), Color(0.6, 1.0, 0.65), 20, 0.7, 2.0, 0.1)
		Dialogue.msg("%s used a %s! %s" % [a.mon.display_name, ItemsData.item_name(id), r.text], 1.8, "item")
		Debug.log("[item] support: %s on %s" % [id, partner.species])




func start_battle(w: CreatureDef) -> void :
	if in_battle or not is_instance_valid(w) or w.mode == CreatureDef.Mode.FAINTED:
		return
	var p: = Dialogue.player()
	if p == null:
		return
	if Game.party.is_empty():
		w.peace_timer = 4.0
		w.mode = CreatureDef.Mode.IDLE if w.static_uid != "" else CreatureDef.Mode.WANDER
		if not Game.cutscene:
			p.controls_enabled = true
		Dialogue.msg("You don't have any Pokémon! Get one at the lab first.")
		return
	var idx: = Game.state.first_healthy()
	if idx < 0:
		w.peace_timer = 4.0
		w.mode = CreatureDef.Mode.IDLE if w.static_uid != "" else CreatureDef.Mode.WANDER
		if not Game.cutscene:
			p.controls_enabled = true
		Dialogue.msg("All your Pokémon have fainted! Press H to heal.")
		return
	in_battle = true
	allies.clear()
	_ending = false
	_intro = true

	speed = Settings.battle_speed_value()
	_intro_skip = false
	_participants.clear()
	_exp_results.clear()
	wild = w
	_static_uid = String(w.static_uid)
	Game.state.mark_seen(w.species)
	p.controls_enabled = false

	wild.mode = CreatureDef.Mode.IDLE
	wild.velocity = Vector3.ZERO
	wild.opponent = null
	wild.ai_uses_moves = true
	_join_fight(wild)
	var to_p: = p.global_position - wild.global_position
	to_p.y = 0.0
	if to_p.length() > 0.01:
		wild.facing = to_p.normalized()
	if not wild.fainted.is_connected(_on_fainted):
		wild.fainted.connect(_on_fainted)
	var keep: Array = [wild]
	if Game.state.is_out(idx):
		keep.append(Game.companions[idx])


	var idx2: = -1
	if BATTLE_SIZE > 1 and trainer_battle.is_empty() and Game.state.is_out(idx):
		for i in Game.party.size():
			if i != idx and Game.state.is_out(i) and Game.party[i].hp > 0 and not Game.companions[i].evolving:
				idx2 = i
				break
	if idx2 >= 0 and Game.state.is_out(idx2):
		keep.append(Game.companions[idx2])
	_hide_others(keep)


	var look: = _zone_look()
	var zone_arena: = float(look.get("arena_size", ARENA_SIZE))
	var asz: Vector2 = trainer_battle.get("arena", Vector2(zone_arena, zone_arena))
	var mid: Vector3
	var wild_spot = null
	var pl: = {}
	_lead_spot = Vector3.INF
	if trainer_battle.has("center"):
		mid = trainer_battle.center
		mid.y = Transitions.ground_y(mid, mid.y)
		arena_rect = Rect2(mid.x - asz.x * 0.5, mid.z - asz.y * 0.5, asz.x, asz.y)



		var lead_who = Game.companions[idx] if Game.state.is_out(idx) else Game.party[idx]
		var to_mid: Vector3 = mid - p.global_position
		to_mid.y = 0.0
		var at_lead: Vector3 = p.global_position + (to_mid.normalized() * 1.5 if to_mid.length() > 0.01 else Vector3(0, 0, 1.5))
		_lead_spot = nearest_ok(at_lead, lead_who, arena_rect, _blocked_at(mid.y))
	else:




		var level: = Transitions.ground_y(p.global_position, p.global_position.y)
		var blocked: Callable = _blocked_at(level)



		var lead_who = Game.companions[idx] if Game.state.is_out(idx) else Game.party[idx]
		var lead_ok: = _place_pred(lead_who)
		var wild_ok: = _place_pred(wild)


		var wild_pref: = wild_ok
		if _wild_keeps_water(wild):
			wild_pref = func(x: float, z: float) -> bool:
				return bool(wild_ok.call(x, z)) and Transitions.surface_at(x, z) != Water.Surface.GROUND
		elif _prefers_ground(wild):
			wild_pref = func(x: float, z: float) -> bool:
				return Transitions.surface_at(x, z) == Water.Surface.GROUND
		pl = BattleArena.plan(p.global_position, wild.global_position, asz, Transitions.ground_xz, p.facing_vector(), blocked, lead_ok, wild_pref)
		if not bool(wild_pref.call(pl.wild_spot.x, pl.wild_spot.z)):
			pl = BattleArena.plan(p.global_position, wild.global_position, asz, Transitions.ground_xz, p.facing_vector(), blocked, lead_ok, wild_ok)
		if _land_fraction(pl.rect) < WATER_LAND_BAR:

			blocked = _blocked_at(level, true)
			pl = BattleArena.plan(p.global_position, wild.global_position, asz, Transitions.ground_xz, p.facing_vector(), blocked, lead_ok, wild_ok)
		mid = pl.center
		asz = pl.rect.size
		arena_rect = pl.rect
		wild_spot = pl.wild_spot
		_lead_spot = nearest_ok(pl.lead_spot, lead_who, pl.rect, blocked)
	var cam: = Dialogue.camera_rig()
	if cam:
		cam.focus_fixed(mid, _battle_cam_dist())
	_arena = BattleArena.new()
	p.get_parent().add_child(_arena)
	_arena.setup(mid, asz, trainer_battle.get("arena_color", BattleArena.COLOR))
	if Debug.arena_debug and not pl.is_empty():
		_arena.add_child(BattleArena.debug_mesh(pl))
	var hud: = Dialogue.hud()
	if hud:
		hud.intro.bars(true)
	print("[battle] start vs %s Lv%d" % [wild.species, wild.level])


	if trainer_battle.is_empty():
		Audio.push_music("battle", "music/battle_wild", 0.2)
	await _wild_appears(w)
	if not _intro_ok(w):
		return
	if wild_spot != null:
		await _hop_to(w, wild_spot)
		_settle(w, wild)
		if not _intro_ok(w):
			return
		var face_p: = p.global_position - w.global_position
		face_p.y = 0.0
		if face_p.length() > 0.01:
			w.facing = face_p.normalized()
	if hud:
		if trainer_battle.is_empty():
			hud.intro.banner("A wild %s appeared!" % w.species)
		else:
			hud.intro.banner("%s sent out %s!" % [trainer_battle.name, w.species])
	await _intro_wait(1.2)
	if not _intro_ok(w):
		return
	if hud:
		hud.intro.hide_banner()
	if Game.state.is_out(idx):
		if _lead_spot.is_finite():
			Game.companions[idx].global_position = Vector3(_lead_spot.x, Transitions.ground_y(_lead_spot, _lead_spot.y), _lead_spot.z)
		_set_fighter(Game.companions[idx])
	else:
		await _deploy_fighter(idx)
	if not _intro_ok(w):
		return
	if idx2 >= 0:
		if Game.state.is_out(idx2):
			_set_fighter(Game.companions[idx2], false)
		else:
			await _deploy_fighter(idx2, false)
		if not _intro_ok(w):
			return
	await _intro_wait(0.35)
	if not _intro_ok(w):
		return
	if hud:
		hud.intro.fight()
		hud.intro.bars(false)



	var extra: Array = []
	if allies.size() > 1:
		extra = [["control_other", "control other fighter"], ["party_ring", "hold: 2nd fighter"]]
	if hud and not extra.is_empty():
		hud.battle_hud.show_hint(extra, 3.5)

	await get_tree().process_frame
	if not _intro_ok(w):
		return
	_intro = false
	_intro_skip = false
	for a in allies:
		if is_instance_valid(a):
			a.mode = _fighter_mode(a)

	w.mode = _foe_mode()
	w.hold_attacks(WILD_OPENING_DELAY)
	print("[battle] fight! (%s vs %s)" % [partner.species if is_instance_valid(partner) else "?", w.species])
	Game.battle_started.emit(partner, wild)












func start_trainer_battle(trainer: Node3D, trainer_name: String, mons: Array, opts: = {}) -> String:
	var p: = Dialogue.player()
	if p == null or mons.is_empty() or in_battle or Game.state.first_healthy() < 0:
		return "aborted"
	online = bool(opts.get("online", false))






	var plan: Dictionary = {}
	var center: Vector3
	var asz: Vector2 = opts.get("arena", Vector2(10, 6))
	if opts.has("center"):
		center = opts.center
	else:


		var rig: = Dialogue.camera_rig()
		if rig and rig.camera:
			var near: float = rig.visible_ground(_battle_cam_dist()).x - BattleArena.TRAINER_STAND_OFF
			asz.x = clampf(floorf(near * 2.0), 6.0, asz.x)
		var level: = Transitions.ground_y(p.global_position, p.global_position.y)
		plan = BattleArena.plan_trainer(p.global_position, trainer.global_position, asz, 
			Transitions.ground_xz, p.facing_vector(), _blocked_at(level))
		center = plan.center
		asz = plan.size
	trainer_battle = {"name": trainer_name, "node": trainer, "center": center, "arena": asz, 
		"axis": plan.get("axis", Vector3.RIGHT), 
		"player_spot": plan.get("player_spot", Vector3.INF), 
		"trainer_spot": plan.get("trainer_spot", Vector3.INF), 
		"arena_color": opts.get("arena_color", BattleArena.COLOR), 
		"class": String(opts.get("trainer_class", "")), "scripted": bool(opts.get("scripted", false)), 
		"lose": opts.get("lose", []), 
		"mons": mons, "index": 0, "total": mons.size(), "fainted": 0, "spot": Vector3.INF, 
		"ai_scale": float(opts.get("ai_think_scale", 1.0)), "item": String(opts.get("item", ""))}
	p.controls_enabled = false

	var battle_music: = "music/battle_trainer"
	if String(trainer_battle.get("class", "")) == "gym_leader":
		battle_music = Audio.resolve(["music/battle_gym_leader", "music/battle_trainer"])
	Audio.push_music("battle", battle_music, 0.2)
	var hud: = Dialogue.hud()
	if hud:
		hud.intro.bars(true)

	await Transitions.fade(1.0, 0.25)


	var lead: = Game.state.first_healthy()
	for k in Game.companions.keys().duplicate():
		if Game.state.is_out(k) and k != lead:
			Game.recall(k)
	var axis: Vector3 = trainer_battle.get("axis", Vector3.RIGHT)
	var spread: = maxf(asz.x, asz.y) * 0.5 + 0.3
	if plan.is_empty():
		_place_trainer(p, center + Vector3( - spread, 0, 0), Vector3.RIGHT)
		_place_trainer(trainer, center + Vector3(spread, 0, 0), Vector3.LEFT)
	else:
		_place_trainer(p, plan.player_spot, axis)
		_place_trainer(trainer, plan.trainer_spot, - axis)
	for i in Game.companions.keys():
		if Game.state.is_out(i):
			Game.companions[i].global_position = p.global_position + Vector3(0.6, 0, 0.9)
	var cam: = Dialogue.camera_rig()
	if cam:
		cam.focus_fixed(center, _battle_cam_dist())
		cam.global_position = center
	await Transitions.fade(0.0, 0.25)
	if hud:
		hud.intro.banner(String(opts.get("intro_text", "%s wants to battle!" % trainer_name)))
	await get_tree().create_timer(1.2).timeout
	if hud:
		hud.intro.hide_banner()
	var at: Vector3 = center + axis * (spread * 0.4)


	at = nearest_ok(at, mons[0], _trainer_rect(trainer_battle), _blocked_at(at.y))
	at.y = Transitions.ground_y(at, trainer.global_position.y)
	trainer_battle["spot"] = at
	await _throw_pose(trainer, at)
	await Game._throw_ball(trainer.global_position + Vector3(0, 1.0, 0), at)
	var w: = Encounters.spawn_mon(mons[0], p.get_parent(), at, true)
	Game.state.mark_seen(w.species)
	w.remove_from_group("wild")
	w.ai_think_scale = float(opts.get("ai_think_scale", 1.0))

	w.combat.is_trainer_mon = true
	w.combat.trainer_item = String(opts.get("item", ""))
	Audio.cry(w.species, at)
	start_battle(w)
	var result: String = await Game.battle_ended
	if is_instance_valid(w):
		w.queue_free()
	trainer_battle = {}
	return result



func _throw_pose(t: Node3D, at: Vector3) -> void :
	if not is_instance_valid(t):
		return
	if t.has_method("face"):
		t.face(at - t.global_position)
	var spr: = t.get_node_or_null("Sprite3D") as Sprite3D
	if spr == null:
		return
	var f: = spr.frame
	spr.frame = (f / 3) * 3 + 1
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(spr):
		spr.frame = f





func _send_next_trainer_mon() -> void :
	var next_i: = _next_trainer_mon()
	if next_i < 0:
		return
	await _send_trainer_mon(next_i)



func _next_trainer_mon() -> int:
	var tb: = trainer_battle
	var mons: Array = tb.get("mons", [])
	var cur: = int(tb.get("index", 0))
	for i in mons.size():
		if i != cur and int(mons[i].hp) > 0:
			return i
	return -1



func _send_trainer_mon(index: int) -> void :
	var old: = wild
	wild = null
	if is_instance_valid(old):
		_combatants.erase(old)
		_fade_body(old, true)
		await get_tree().create_timer(0.35).timeout
		if is_instance_valid(old):
			old.queue_free()
	if not in_battle or _ending:
		return
	var tb: = trainer_battle
	var mons: Array = tb.get("mons", [])
	if index < 0 or index >= mons.size():
		return
	tb["index"] = index
	var trainer: Node3D = tb.get("node")
	var species: = String(mons[index].species)
	var hud: = Dialogue.hud()
	if hud:
		hud.intro.banner("%s is about to send out %s!" % [tb.get("name", "The trainer"), species])
		Dialogue.msg("%s is about to send out %s!" % [tb.get("name", "The trainer"), species], 1.4, "trainer")
	await get_tree().create_timer(1.4).timeout
	if not in_battle or _ending:
		return
	if hud:
		hud.intro.hide_banner()
	var at: Vector3 = tb.get("spot", tb.get("center", Vector3.ZERO))
	at = nearest_ok(at, mons[index], _trainer_rect(tb), _blocked_at(at.y))
	at.y = Transitions.ground_y(at, at.y)
	if is_instance_valid(trainer):
		await _throw_pose(trainer, at)
		await Game._throw_ball(trainer.global_position + Vector3(0, 1.0, 0), at)
	var p: = Dialogue.player()
	var w: = Encounters.spawn_mon(mons[index], p.get_parent(), at, true)
	Game.state.mark_seen(w.species)
	w.remove_from_group("wild")
	w.ai_think_scale = float(tb.get("ai_scale", 1.0))
	w.combat.is_trainer_mon = true
	w.combat.trainer_item = String(tb.get("item", ""))
	Audio.cry(w.species, at)
	_bind_foe(w)




func switch_foe(slot: int) -> bool:
	if not online or not in_battle or _ending or _intro or _foe_switching:
		return false
	var mons: Array = trainer_battle.get("mons", [])
	if slot < 0 or slot >= mons.size() or slot == int(trainer_battle.get("index", 0)):
		return false
	if int(mons[slot].hp) <= 0:
		return false
	_foe_switching = true
	_foe_switch_to(slot)
	return true


func _foe_switch_to(slot: int) -> void :
	await _send_trainer_mon(slot)
	_foe_switching = false



func _foe_mode() -> int:
	return CreatureDef.Mode.REMOTE if online else CreatureDef.Mode.BATTLE_AI




func _bind_foe(w: CreatureDef) -> void :
	wild = w
	w.mode = _foe_mode()
	w.velocity = Vector3.ZERO
	w.opponent = null
	w.ai_uses_moves = true
	_join_fight(w)
	var p: = Dialogue.player()
	if p:
		var to_p: Vector3 = p.global_position - w.global_position
		to_p.y = 0.0
		if to_p.length() > 0.01:
			w.facing = to_p.normalized()
	if not w.fainted.is_connected(_on_fainted):
		w.fainted.connect(_on_fainted)
	for a in allies:
		if is_instance_valid(a) and a.mode != CreatureDef.Mode.FAINTED:
			a.opponent = w
			a.last_hit_by = null
			var to_w: Vector3 = w.global_position - a.global_position
			to_w.y = 0.0
			if to_w.length() > 0.01:
				a.facing = to_w.normalized()
			if is_instance_valid(_arena):
				_arena.track(a, w)
	if is_instance_valid(partner) and partner.alive():
		w.opponent = partner
	else:
		var a: = ai_ally()
		if a:
			w.opponent = a
	w.hold_attacks(WILD_OPENING_DELAY)
	w.refresh_label()
	print("[battle] next trainer mon: %s Lv%d" % [w.species, w.level])



func _trainer_rect(tb: Dictionary) -> Rect2:
	var c: Vector3 = tb.get("center", Vector3.ZERO)
	var a: Vector2 = tb.get("arena", Vector2(10, 6))
	return Rect2(c.x - a.x * 0.5, c.z - a.y * 0.5, a.x, a.y)



func _place_trainer(t: Node3D, pos: Vector3, dir: Vector3) -> void :
	pos.y = Transitions.ground_y(pos, t.global_position.y)
	t.global_position = pos
	if t.has_method("face"):
		t.face(dir)
	elif t.has_method("face_toward"):
		t.face_toward(pos + dir)





func engage(w: CreatureDef) -> void :
	if Game.is_busy() or not is_instance_valid(w) or not w.alive():
		return
	var p: = Dialogue.player()
	if p == null:
		return
	if Game.party.is_empty():
		Dialogue.msg("You don't have any Pokémon! Get one at the lab first.")
		return
	var idx: = Game.state.first_healthy()
	if idx < 0:
		Dialogue.msg("All your Pokémon have fainted! Press H to heal.")
		return
	_ambush = true
	p.controls_enabled = false
	p.face_toward(w.global_position)
	w.mode = CreatureDef.Mode.IDLE
	w.velocity = Vector3.ZERO
	var to_w: Vector3 = w.global_position - p.global_position
	to_w.y = 0.0
	var at: Vector3 = p.global_position + to_w.normalized() * minf(1.6, to_w.length() * 0.5)


	at = nearest_ok(at, Game.party[idx], Rect2(), _blocked_at(at.y))
	if Game.state.is_out(idx):
		var c: CreatureDef = Game.companions[idx]
		c.mode = CreatureDef.Mode.IDLE
		at.y = Transitions.ground_y(at, c.global_position.y)
		var tw: = create_tween()
		tw.tween_property(c, "global_position", at, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tw.finished
	else:
		await Game.send_out(idx, at)
	_ambush = false
	if is_instance_valid(w) and w.alive():
		start_battle(w)
	else:
		p.controls_enabled = true




func _dynamic_rids() -> Array[RID]:
	var out: Array[RID] = []
	var p: = Dialogue.player()
	if p is CollisionObject3D:
		out.append(p.get_rid())
	for w in get_tree().get_nodes_in_group("wild"):
		if w is CollisionObject3D:
			out.append(w.get_rid())
	for n in get_tree().get_nodes_in_group("npc"):
		if n is CollisionObject3D:
			out.append(n.get_rid())
	return out



func _water_rects() -> Array:
	return Transitions.water_rects()



func _land_fraction(rect: Rect2) -> float:
	if rect.size.x <= 0.0:
		return 1.0
	var n: = 5
	var dry: = 0
	for i in n:
		for j in n:
			var x: = rect.position.x + rect.size.x * (i + 0.5) / n
			var z: = rect.position.y + rect.size.y * (j + 0.5) / n
			if Transitions.surface_at(x, z) != Water.Surface.DEEP:
				dry += 1
	return float(dry) / float(n * n)










func place_ok(who, x: float, z: float) -> bool:
	var f: = _flags_of(who)
	if f.is_empty() or String(f.locomotion) != "ground":
		return true
	var s: = Transitions.surface_at(x, z)
	if bool(f.fish):
		return s != Water.Surface.GROUND
	if bool(f.swimmer):
		return true
	return s != Water.Surface.DEEP



func _flags_of(who) -> Dictionary:
	if who == null:
		return {}
	if who is String:
		return _species_flags(who)
	if not is_instance_valid(who):
		return {}
	if who.get("combat") != null:
		var c = who.combat
		return {"locomotion": c.locomotion, "swimmer": c.swimmer, "fish": c.fish}
	if who.get("swimmer") != null:
		return {"locomotion": who.locomotion, "swimmer": who.swimmer, "fish": who.fish}
	if who.get("species") != null:
		return _species_flags(String(who.species))
	return {}


func _species_flags(name: String) -> Dictionary:
	var sp: = DexData.species(name)
	if sp.is_empty():
		return {}
	return {"locomotion": DexData.locomotion(name), 
		"swimmer": bool(sp.get("swimmer", false)), "fish": bool(sp.get("fish", false))}



func _place_pred(who) -> Callable:
	return func(x: float, z: float) -> bool: return place_ok(who, x, z)



func _wild_keeps_water(w: CreatureDef) -> bool:
	var f: = _flags_of(w)
	return bool(f.get("swimmer", false))\
	and Transitions.surface_at(w.global_position.x, w.global_position.z) != Water.Surface.GROUND





func nearest_ok(spot: Vector3, who, rect: Rect2, blocked: = Callable(), rings: = 8) -> Vector3:
	var ground_only: = _prefers_ground(who)
	for pass_i in 2:
		var found: = _nearest_pass(spot, who, rect, blocked, rings, pass_i == 0 and ground_only)
		if found.is_finite():
			return found
	return spot


func _prefers_ground(who) -> bool:
	var f: = _flags_of(who)
	return not f.is_empty() and String(f.locomotion) == "ground"\
	and not bool(f.swimmer) and not bool(f.fish)


func _nearest_pass(spot: Vector3, who, rect: Rect2, blocked: Callable, rings: int, ground_only: bool) -> Vector3:
	if _spot_ok(spot, who, rect, blocked)\
	and ( not ground_only or Transitions.surface_at(spot.x, spot.z) == Water.Surface.GROUND):
		return spot
	for r in range(1, rings + 1):
		for i in range( - r, r + 1):
			for j in range( - r, r + 1):
				if maxi(absi(i), absi(j)) != r:
					continue
				var p: = Vector3(spot.x + i, spot.y, spot.z + j)
				if not _spot_ok(p, who, rect, blocked):
					continue
				if ground_only and Transitions.surface_at(p.x, p.z) != Water.Surface.GROUND:
					continue
				return p
	return Vector3.INF


func _spot_ok(p: Vector3, who, rect: Rect2, blocked: Callable) -> bool:
	if rect.size.x > 0.0 and not rect.has_point(Vector2(p.x, p.z)):
		return false
	if blocked.is_valid() and bool(blocked.call(p.x, p.z)):
		return false
	return place_ok(who, p.x, p.z)



func _settle(c: CreatureDef, who) -> void :
	if not is_instance_valid(c) or arena_rect.size.x <= 0.0:
		return
	if place_ok(who, c.global_position.x, c.global_position.z):
		return
	var at: = nearest_ok(c.global_position, who, arena_rect, _blocked_at(c.global_position.y))
	c.global_position = Vector3(at.x, Transitions.ground_y(at, c.global_position.y), at.z)





func _blocked_at(level: float, block_water: = false) -> Callable:
	var world: = get_viewport().world_3d if get_viewport() else null
	var space: = world.direct_space_state if world else null
	var shape: = SphereShape3D.new()
	shape.radius = 0.35
	var water: = _water_rects() if block_water else []
	var exclude: = _dynamic_rids()
	return func(x: float, z: float) -> bool:
		for r in water:
			if r.has_point(Vector2(x, z)):
				return true
		if space == null:
			return false
		var params: = PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.transform = Transform3D(Basis(), Vector3(x, level + 0.6, z))
		params.collision_mask = ARENA_BLOCK_LAYERS
		params.exclude = exclude
		params.collide_with_areas = false
		return not space.intersect_shape(params, 1).is_empty()




func _checked_target(from: Vector3, to: Vector3) -> Vector3:
	var world: = get_viewport().world_3d if get_viewport() else null
	if world == null:
		return to
	var a: = Vector3(from.x, to.y + 0.6, from.z)
	var b: = Vector3(to.x, to.y + 0.6, to.z)
	var d: = b - a
	if d.length() < 0.05:
		return to
	var q: = PhysicsRayQueryParameters3D.create(a, b, ARENA_BLOCK_LAYERS)
	q.exclude = _dynamic_rids()
	var hit: = world.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return to
	var land: Vector3 = hit.position - d.normalized() * 0.6
	land.y = Transitions.ground_y(land, to.y)
	return land



func _hop_to(c: Node3D, to: Vector3, secs: = 0.35) -> void :



	var checked: = _checked_target(c.global_position, to)
	if checked != to:
		var lvl: = Transitions.ground_y(checked, checked.y)
		var blk: Callable = _blocked_at(lvl)
		if bool(blk.call(checked.x, checked.z)):
			checked = to
	to = checked
	to.y = Transitions.ground_y(to, c.global_position.y)
	var from: = c.global_position
	var tw: = create_tween()
	tw.tween_method( func(t: float):
		if is_instance_valid(c):
			c.global_position = from.lerp(to, t) + Vector3(0, sin(t * PI) * 0.9, 0), 0.0, 1.0, secs)
	await tw.finished



func _join_fight(c: Node) -> void :
	if not c.is_in_group("combatant"):
		c.add_to_group("combatant")
	if not _combatants.has(c):
		_combatants.append(c)



func _intro_ok(w: CreatureDef) -> bool:
	if in_battle and not _ending and wild == w and is_instance_valid(w):
		return true
	if _intro and in_battle and not _ending:
		end_battle("aborted")
	return false



func _intro_wait(secs: float) -> void :
	var t: = 0.0
	while t < secs and not _intro_skip:
		await get_tree().process_frame
		t += get_process_delta_time()



func _wild_appears(w: CreatureDef) -> void :
	Audio.cry(w.species, w.global_position)
	var spr: Node3D = w.get_node("Sprite3D")
	var lbl: Node3D = w.get_node_or_null("Label3D")
	var bang: = Label3D.new()
	bang.text = "!"
	bang.font_size = 110
	bang.outline_size = 20
	bang.modulate = Color(1.0, 0.35, 0.25)
	bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bang.no_depth_test = true
	bang.position = Vector3(0, (lbl.position.y if lbl else 1.8) + 0.7, 0)
	w.add_child(bang)
	var base: = spr.position
	var tw: = create_tween()
	tw.tween_property(bang, "scale", Vector3.ONE, 0.15).from(Vector3.ONE * 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "position", base + Vector3(0, 0.45, 0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "position", base, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(spr, "position", base + Vector3(0, 0.25, 0), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "position", base, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var cam: = Dialogue.camera_rig()
	if cam:
		cam.shake(0.08)
	await tw.finished
	await _intro_wait(0.25)
	if is_instance_valid(bang):
		bang.queue_free()






func _hide_others(keep: Array) -> void :
	var list: Array = get_tree().get_nodes_in_group("wild")
	for c in Game.companions.values():
		list.append(c)
	for c in list:
		if not is_instance_valid(c) or keep.has(c) or _hidden.has(c) or c.evolving:
			continue
		_hidden[c] = [c.collision_layer, c.collision_mask, c.process_mode]
		c.velocity = Vector3.ZERO
		c.collision_layer = 0
		c.collision_mask = 0
		c.process_mode = Node.PROCESS_MODE_DISABLED
		_fade_body(c, true)


func _unhide(c: Node) -> void :
	if not _hidden.has(c):
		return
	var s: Array = _hidden[c]
	_hidden.erase(c)
	if not is_instance_valid(c):
		return
	c.collision_layer = s[0]
	c.collision_mask = s[1]
	c.process_mode = s[2]
	c.visible = true
	if c.is_wild:
		c.peace_timer = maxf(c.peace_timer, 3.0)
	_fade_body(c, false)


func _show_hidden() -> void :
	for c in _hidden.keys():
		_unhide(c)


func _fade_body(c: Node3D, out: bool) -> void :
	var tw: = create_tween().set_parallel(true)
	for g in c.find_children("*", "GeometryInstance3D", true, false):
		tw.tween_property(g, "transparency", 1.0 if out else 0.0, 0.3).from(0.0 if out else 1.0)
	if out:
		tw.chain().tween_callback( func():
			if is_instance_valid(c) and _hidden.has(c):
				c.visible = false)


func _deploy_fighter(i: int, control: = true) -> void :
	var p: = Dialogue.player()
	var at: Vector3
	if _lead_spot.is_finite():
		at = _lead_spot
		if not control:

			var side: = Vector3(_lead_spot.z - p.global_position.z, 0, p.global_position.x - _lead_spot.x)
			at += side.normalized() * 1.6 if side.length() > 0.01 else Vector3(1.6, 0, 0)
	else:
		at = p.global_position
		if is_instance_valid(wild):
			var to_w: = wild.global_position - p.global_position
			to_w.y = 0.0
			at += to_w.normalized() * minf(1.5, to_w.length() * 0.5) if to_w.length() > 0.01 else Vector3(0, 0, -1.2)
		if not control and is_instance_valid(wild):
			var to_w2: = wild.global_position - p.global_position
			to_w2.y = 0.0
			if to_w2.length() > 0.01:
				at += Vector3( - to_w2.z, 0.0, to_w2.x).normalized() * 1.6
	Dialogue.msg("Go, %s!" % Game.party[i].species, 1.5, "info")


	if p and not (control and _lead_spot.is_finite()):
		at = _checked_target(p.global_position + Vector3(0, 1.2, 0), at)
	var c: = await Game.send_out(i, at)
	if c and in_battle and not _ending:
		_set_fighter(c, control)


func _set_fighter(c: CreatureDef, control: = true) -> void :
	if control:
		partner = c
	if not allies.has(c):
		allies.append(c)
	if c.mon and not _participants.has(c.mon):
		_participants.append(c.mon)
	_unhide(c)
	c.ai_uses_moves = true
	_join_fight(c)
	if not c.moves.is_empty() and not c.moves.has(c.selected_move):
		c.selected_move = String(c.moves[0])
	if _intro:
		c.mode = CreatureDef.Mode.IDLE
		c.velocity = Vector3.ZERO
	else:
		c.mode = _fighter_mode(c)
	if is_instance_valid(wild):
		c.opponent = wild
		if not is_instance_valid(wild.opponent) or not wild.opponent.alive():
			wild.opponent = c
		var to_w: = wild.global_position - c.global_position
		to_w.y = 0.0
		if to_w.length() > 0.01:
			c.facing = to_w.normalized()
		if is_instance_valid(_arena):
			_arena.track(c, wild)
	if not c.fainted.is_connected(_on_fainted):
		c.fainted.connect(_on_fainted)
	c.refresh_label()
	var cam: = Dialogue.camera_rig()
	if cam and is_instance_valid(wild):
		cam.focus_battle(c, wild)
	Game.party_changed.emit()


func _switch_fighter(i: int) -> void :
	if online_guest:
		return
	_switching = true
	_an_switches += 1
	var old: = partner
	partner = null
	allies.erase(old)
	if is_instance_valid(wild) and wild.opponent == old:
		wild.opponent = null
	if is_instance_valid(old):
		for k in Game.companions.keys():
			if Game.companions[k] == old:
				Game.recall(k)
	await _deploy_fighter(i)
	_switching = false




func _ally_slot(i: int) -> void :
	if BATTLE_SIZE < 2 or _switching or Progression._capturing or _ending or _intro:
		return
	if not trainer_battle.is_empty():
		return
	if Game.state.is_out(i) and allies.has(Game.companions[i]):
		return
	if Game.party[i].hp <= 0:
		Dialogue.msg("%s has fainted and can't battle!" % Game.party[i].species, 2.5, "faint")
		return
	_an_switches += 1
	var old: = ai_ally()
	_switching = true
	if old:
		allies.erase(old)
		if is_instance_valid(wild) and wild.opponent == old:
			wild.opponent = null
		for k in Game.companions.keys():
			if Game.companions[k] == old:
				Game.recall(k)
	await _deploy_fighter(i, not is_instance_valid(partner))
	_switching = false


func _on_fainted(c: CreatureDef) -> void :
	if not in_battle or _ending or Progression._capturing:
		return
	if c == wild:
		var killer = wild.last_hit_by
		if not online and is_instance_valid(killer) and allies.has(killer):
			var evs: Dictionary = killer.gain_evs_from(wild)
			print("[ev] %s landed the last hit: %s" % [killer.species, evs])
		var is_trainer: = not trainer_battle.is_empty()
		var has_next: = is_trainer and _next_trainer_mon() >= 0
		if has_next:


			if not online:
				Progression.award_exp(wild.mon, true, true)
			Game.party_changed.emit()
			trainer_battle["fainted"] = int(trainer_battle.get("fainted", 0)) + 1
			await _send_next_trainer_mon()
			return
		Audio.clear_jingles()
		Audio.jingle("music/victory" if not is_trainer else "music/victory_trainer")

		if not online:
			_exp_results = Progression.award_exp(wild.mon, is_trainer, true)
		Game.party_changed.emit()
		end_battle("won")
		return
	if not allies.has(c):
		return
	var was_controlled: = c == partner
	allies.erase(c)
	if was_controlled:
		partner = null
	if is_instance_valid(wild) and wild.opponent == c:
		wild.opponent = null
	Dialogue.msg("%s fainted!" % c.species, 2.0, "faint")
	if not online:
		Analytics.track("pokemon_fainted", {"species": c.species, "level": c.level, 
			"foe": wild.species if is_instance_valid(wild) else "", "battle_kind": _an_kind})
	Game.party_changed.emit()
	await fight_timer(1.0).timeout
	for k in Game.companions.keys():
		if Game.companions[k] == c:
			Game.recall(k)
	if not in_battle or _ending:
		return
	var a: = ai_ally()
	if was_controlled and a:
		partner = a
		a.mode = _fighter_mode(a)
		Dialogue.msg("Go, %s!" % a.mon.display_name, 1.2, "info")
		Game.party_changed.emit()
		return
	if is_instance_valid(partner) or a:
		return
	var nxt: = _next_healthy(false)
	if nxt >= 0:
		_switching = true
		await _deploy_fighter(nxt)
		_switching = false
	else:
		end_battle("lost")



func _auto() -> bool:
	return Debug.auto_dialog or autopilot





func wait_confirm() -> void :
	UiKit.setup_input()
	if _auto():
		await get_tree().create_timer(0.35).timeout
		return
	await get_tree().process_frame
	while not Input.is_action_just_pressed("pk_ok"):
		await get_tree().process_frame




func _confirm() -> void :
	var hud: = Dialogue.hud()
	var bhud: Node = hud.battle_hud if hud else null
	if bhud:
		bhud.hint_hold([[bhud.confirm_key(), "continue"]])
	_awaiting_confirm = not _auto()
	await wait_confirm()
	_awaiting_confirm = false
	if bhud:
		bhud.hint_clear()






func _results_sequence(prize_text: String) -> void :
	var hud: = Dialogue.hud()
	var bhud: Node = hud.battle_hud if hud else null
	if bhud == null:
		return
	var results: Array = _exp_results
	for i in results.size():
		var r: Dictionary = results[i]
		var m: RefCounted = r.get("mon")
		var gain: int = int(r.get("gain", 0))
		var card: Control = bhud.card_for(m)
		if card == null:
			continue
		card.begin_scripted(m, gain)
		Game._msg("%s gained %d EXP." % [m.display_name, gain], 2.5, "exp")
		var growth: = String(m.growth)
		var evs: Array = r.get("events", [])
		Audio.start_loop("exp_fill", "sfx/battle/exp_fill")
		var ei: = 0
		while ei < evs.size():
			var e: Dictionary = evs[ei]
			if e.type != "level":
				ei += 1
				continue
			var lv: = int(e.level)
			await card.fill_to(float(Growth.exp_for_level(growth, lv)), not _auto())
			Audio.stop_loop("exp_fill", 0.06)
			card.announce_level(lv)
			Audio.jingle("music/level_up", true)
			Game._msg("%s grew to Lv %d!" % [m.display_name, lv], 2.5, "level")
			await _confirm()
			ei += 1
			while ei < evs.size() and evs[ei].type == "move":
				var me: Dictionary = evs[ei]
				if me.learned:
					Game._msg("%s learned %s!" % [m.display_name, String(DexData.move(me.move).get("name", me.move))], 2.5, "level")
					await _confirm()
				ei += 1
			card.resume_after_level()
			Audio.start_loop("exp_fill", "sfx/battle/exp_fill")
		await card.fill_to(float(m.xp), not _auto())
		Audio.stop_loop("exp_fill", 0.06)
		card.end_scripted()
		await _confirm()
	if prize_text != "":
		Game._msg(prize_text, 2.5, "money")
		await _confirm()


func end_battle(result: String) -> void :
	if not in_battle or _ending:
		return
	_ending = true
	if result == "fled" or result == "lost" or result == "aborted":
		Audio.clear_jingles()
	match result:
		"lost": Audio.jingle("music/defeat")
		"fled": Audio.play("sfx/battle/flee")
	Audio.pop_music("battle", 1.0 if result == "fled" or result == "aborted" else 0.6)
	print("[battle] end: ", result)
	var w_name: String = wild.species if is_instance_valid(wild) else "The wild creature"
	var scripted: bool = bool(trainer_battle.get("scripted", false))
	var whiteout: = result == "lost" and not scripted


	if _static_uid != "":
		if result == "won" or result == "caught":
			Game.flags["static_" + _static_uid] = true
		elif (result == "fled" or result == "lost") and is_instance_valid(wild):
			if wild.mon:
				wild.mon.heal_full()
			wild.sync_from_mon()
	var payout: = 0
	var text: = {}
	if trainer_battle.is_empty():
		text = {"caught": "", "won": "Wild %s fainted!" % w_name, "lost": "", "fled": "Got away safely!"}
	else:
		var t_name: String = String(trainer_battle.get("name", "The trainer"))
		text = {"caught": "", "won": "%s's %s fainted!" % [t_name, w_name], "lost": "You lost to %s..." % t_name, "fled": ""}
	if whiteout:
		text["lost"] = ""
	elif result == "won" and not trainer_battle.is_empty() and not online:


		var last_level: int = wild.mon.level if is_instance_valid(wild) and wild.mon else 1
		payout = Game.state.trainer_payout(String(trainer_battle.get("class", "")), last_level)
		Game.state.money += payout
	if text.get(result, "") != "":
		Dialogue.msg(text[result], 2.5, "trainer" if not trainer_battle.is_empty() else "info")
	if result != "fled" and result != "caught":
		await get_tree().create_timer(1.0).timeout



	if result == "won" and not online:
		for a in allies:
			if is_instance_valid(a) and a.mode != CreatureDef.Mode.FAINTED:
				a.mode = CreatureDef.Mode.IDLE
				a.velocity = Vector3.ZERO
		var prize: = ""
		if payout > 0:
			prize = "You got %s for winning!" % GameState.format_money(payout)
		await _results_sequence(prize)
		Audio.clear_jingles()
	for b in allies + [wild]:
		if is_instance_valid(b):
			b.reset_battle_mods()
	for a in allies:
		if is_instance_valid(a) and a.mode != CreatureDef.Mode.FAINTED:
			a.opponent = null
			a.last_hit_by = null
			a.mode = CreatureDef.Mode.FOLLOW
			a.refresh_label()
	if is_instance_valid(wild) and wild.mode != CreatureDef.Mode.FAINTED:
		wild.opponent = null
		if trainer_battle.is_empty():

			wild.mode = CreatureDef.Mode.IDLE if wild.static_uid != "" else CreatureDef.Mode.WANDER
			wild.peace_timer = 4.0
		else:
			wild.mode = CreatureDef.Mode.IDLE
			wild.velocity = Vector3.ZERO
		wild.refresh_label()
	for b in _combatants:
		if is_instance_valid(b):
			b.remove_from_group("combatant")
	_combatants.clear()
	partner = null
	allies.clear()
	wild = null
	_static_uid = ""
	_intro = false
	_intro_skip = false
	_show_hidden()
	if is_instance_valid(_arena):
		_arena.close()
	_arena = null
	arena_rect = Rect2()
	_lead_spot = Vector3.INF
	clear_tut_lock()
	pause_for_evolution = false
	var hud: = Dialogue.hud()
	if hud:
		hud.intro.reset()
	var p: = Dialogue.player()
	if p:
		if not Game.cutscene:
			p.controls_enabled = true
		var cam: = Dialogue.camera_rig()
		if cam:
			cam.focus_follow(p)
	in_battle = false
	online = false
	_ending = false
	Game.party_changed.emit()
	Game.battle_ended.emit(result)
	if whiteout:

		var lose: Array = trainer_battle.get("lose", [])
		if not lose.is_empty() and hud:
			hud.open_dialog(String(trainer_battle.get("name", "")), PackedStringArray(Dialogue.fill_lines(lose)))
			await hud.dialog_closed
		await Game.whiteout()





func note_jump(c) -> void :
	if in_battle and allies.has(c):
		_an_jumps += 1


func _an_item_used(_slot: int) -> void :
	if in_battle:
		_an_items += 1




func _an_battle_started(fighter, foe) -> void :
	if online:
		_an_on = false
		return
	_an_on = not _an_lab_scene()
	if not _an_on:
		return
	_an_started_ms = Time.get_ticks_msec()
	_an_moves.clear()
	_an_hits_landed = 0
	_an_hits_taken = 0
	_an_switches = 0
	_an_items = 0
	_an_jumps = 0
	_an_kind = _an_kind_of()
	_an_trainer_id = _an_trainer_id_of()
	if _an_trainer_id != "":
		_an_attempts[_an_trainer_id] = int(_an_attempts.get(_an_trainer_id, 0)) + 1
	var moves: = get_node("/root/Moves")
	moves.move_used.connect(_an_on_move)
	moves.hit_landed.connect(_an_on_hit)
	Analytics.track("battle_started", {
		"kind": _an_kind, 
		"foe_species": foe.species if is_instance_valid(foe) else "", 
		"foe_level": foe.level if is_instance_valid(foe) else 0, 
		"trainer_id": _an_trainer_id, 
		"terrain": _an_terrain(), 
		"weather": _an_weather(), 
		"fighter_species": fighter.species if is_instance_valid(fighter) else "", 
		"fighter_level": fighter.level if is_instance_valid(fighter) else 0})


func _an_battle_ended(result: String) -> void :
	var moves: = get_node("/root/Moves")
	if moves.move_used.is_connected(_an_on_move):
		moves.move_used.disconnect(_an_on_move)
	if moves.hit_landed.is_connected(_an_on_hit):
		moves.hit_landed.disconnect(_an_on_hit)
	if not _an_on:
		return
	_an_on = false
	if result == "aborted":
		return
	Analytics.track("battle_ended", {
		"result": result, 
		"duration_s": (Time.get_ticks_msec() - _an_started_ms) / 1000.0, 
		"party_hp_pct_end": _an_party_hp_pct(), 
		"switches": _an_switches, 
		"items_used": _an_items, 
		"jumps": _an_jumps, 
		"moves_used": _an_moves.duplicate(), 
		"hits_landed": _an_hits_landed, 
		"hits_taken": _an_hits_taken, 
		"ally_mode": CreatureDef.ALLY_MODE_NAMES[clampi(Game.state.ally_mode, 0, CreatureDef.ALLY_MODE_NAMES.size() - 1)], 
		"battle_speed": Settings.BATTLE_SPEED_NAMES[clampi(Settings.battle_speed, 0, Settings.BATTLE_SPEED_NAMES.size() - 1)].to_lower()})
	if result == "won" and _an_kind != "wild" and _an_trainer_id != "":
		Analytics.track("trainer_defeated", {"trainer_id": _an_trainer_id, 
			"attempts": int(_an_attempts.get(_an_trainer_id, 0))})
		if _an_trainer_id == "brock":
			AnalyticsBeats.beat_once("brock_defeated")


func _an_on_move(user: Node, move: Dictionary) -> void :
	if not allies.has(user):
		return
	var id: = String(move.get("id", ""))
	if id != "":
		_an_moves[id] = int(_an_moves.get(id, 0)) + 1


func _an_on_hit(user: Node, target: Node, _info: Dictionary) -> void :
	if allies.has(user):
		_an_hits_landed += 1
	if allies.has(target):
		_an_hits_taken += 1


func _an_kind_of() -> String:
	if trainer_battle.is_empty():
		return "wild"
	match String(trainer_battle.get("class", "")):
		"rival":
			return "rival"
		"gym_leader":
			return "gym"
	return "trainer"


func _an_trainer_id_of() -> String:
	var t = trainer_battle.get("node")
	if not is_instance_valid(t):
		return ""
	var id = t.get("trainer_id")
	return String(id) if id != null else ""


func _an_party_hp_pct() -> int:
	var hp: = 0
	var mx: = 0
	for m in Game.party:
		hp += maxi(int(m.hp), 0)
		mx += maxi(int(m.max_hp), 1)
	return int(round(100.0 * hp / mx)) if mx > 0 else 0


func _an_terrain() -> String:
	if arena_rect.size.x <= 0.0:
		return "ground"
	var c: = arena_rect.get_center()
	match Transitions.surface_at(c.x, c.y):
		Water.Surface.SHALLOW:
			return "shallow"
		Water.Surface.DEEP:
			return "deep"
	return "ground"


func _an_weather() -> String:
	var w: = get_tree().get_first_node_in_group("weather")
	if w == null or not w.has_method("camera_cover"):
		return "clear"
	var c: Dictionary = w.camera_cover()
	var best: = ""
	var v: = 0.4
	for k in ["wet", "snow", "fog"]:
		if float(c.get(k, 0.0)) > v:
			v = float(c[k])
			best = {"wet": "rain", "snow": "snow", "fog": "fog"}[k]
	if best != "":
		return best
	return "overcast" if float(c.get("cloud", 0.0)) > 0.4 else "clear"



func _an_lab_scene() -> bool:
	var sc: = get_tree().current_scene
	return sc != null and String(sc.scene_file_path).begins_with("res://scenes/tests/")
