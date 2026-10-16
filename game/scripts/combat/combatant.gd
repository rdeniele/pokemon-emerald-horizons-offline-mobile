class_name Combatant
extends RefCounted








const Dex: = preload("res://scripts/dex.gd")
const StatCalc: = preload("res://scripts/stats/stat_calc.gd")
const ItemsData: = preload("res://scripts/items.gd")

const LUNGE_SPEED: = 10.0
const LUNGE_TIME: = 0.2

const ARC_STEP_M: = 0.5
const ARC_STEP_TIME: = 0.12
const ATTACK_CD: = 0.8
const HIT_RANGE: = 1.2

const PP_REGEN: = 0.2







const AI_THINK_MIN: = 1.2
const AI_THINK_MAX: = 2.0
const AI_RECOVER: = 0.5



const AI_THINK_RETRY: = 0.25


const AI_SPRINT_MIN: = 0.4
const AI_SPRINT_KEEP: = 0.15

const AI_SPRINT_REACT: = 0.35

const AI_LOW_HP: = 0.35
const AI_KITE_MULT: = 1.5


const AI_MELEE_BAND: = 3.6
const AI_FAR_GAP: = 2.0



const AI_TACTIC_MISS_MULT: = 1.5

const AI_DODGE_TIME: = 0.35

const AI_WAIT_STRAFE: = 0.6
const AI_WAIT_RADIAL: = 0.35





const AI_JUMP_SHARP: = 0.8
const AI_JUMP_ERR: = 0.44
const AI_JUMP_ERR_SLOPE: = 0.28
const AI_JUMP_MISS_LIN: = 0.54
const AI_JUMP_MISS_QUAD: = 0.475
const AI_JUMP_MISS_MAX: = 0.52


const AI_JUMP_LATE: = 0.25


const AI_JUMP_CLEAR: = 0.95
const AI_JUMP_RESERVE: = 0.1


const AI_FLIGHT_MIN: = 0.35
const AI_FLIGHT_KEEP: = 0.12
const AI_FLIGHT_IDLE: = 2.5


const QUAKE_TAIL: = 0.11

const KNOCKBACK_SCALE: = 0.5

const BLOCK_LAYERS: = 1 | 2

const STAGGER_TIME: = 2.0

const BATTLE_MOVE_SPEED: = 4.5

const SPRINT_MULT: = 1.6
const SPRINT_DRAIN: = 0.3



const JUMP_HEIGHT_DEFAULT: = 0.9


const JUMP_G: = 23.8

const DASH_REACH_FACTOR: = 0.9



const HOVER_HEIGHT: = 0.35
const FLY_HEIGHT: = 1.4
const FLY_BOB: = 0.08
const FLY_BOB_SPEED: = 1.6
const SWOOP_HEIGHT: = 0.2
const ALT_SPRING: = 12.0
const ALT_MAX_VY: = 18.0
const FAINT_FALL_SPEED: = 6.0



const FLY_SPEED_MULT: = 1.25




const FLIGHT_TAKEOFF: = 0.1
const FLIGHT_DRAIN: = 0.02
const FLIGHT_MIN: = 0.15
const FLIGHT_FLOOR: = 0.1
const FLIGHT_LAND: = 0.25

const JUMP_STAMINA: = 0.15

const JUMP_LAND: = 0.3


const AIRBORNE_FRACTION: = 0.4
const AIRBORNE_FLOOR: = 0.12

const JUMP_STRETCH: = 0.28
const JUMP_SQUASH: = -0.24
const JUMP_DUST: = Color(0.55, 0.48, 0.38)


const PREPARE_STUN: = 0.25

const LUNGE_PREPARE: = 0.15


const STRUGGLE: = {"id": "struggle", "name": "Struggle", "type": "none", "category": "physical", "power": 50, "knockback": 5, "allowed_midair": false}

const LUNGE: = {"allowed_midair": false}

var body: Creature


var types: Array = ["normal"]
var stats: = {"atk": 10, "def": 10, "spa": 10, "spd": 10, "spe": 10}
var stages: = {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0, "acc": 0}
var moves: Array = []
var move_cd: = {}

var gcd_t: = 0.0

var sprinting: = false


var remote_intent: = {"move": Vector2.ZERO, "sprint": false, "jump": false, "slot": -1}


enum Flight{GROUNDED, AIRBORNE, LANDING}
var flight: = Flight.GROUNDED
var flight_t: = 0.0


var air_t: = 0.0
var air_h: = 0.0
var jump_height: = JUMP_HEIGHT_DEFAULT
var jump_time: = 0.55

var locomotion: = "ground"

var fly_height: = FLY_HEIGHT


var swimmer: = false
var fish: = false


var dive_t: = 0.0
var dive_land_t: = 0.0


var alt_override: = 0.0
var alt_override_t: = 0.0
var _bob_t: = 0.0

var land_t: = 0.0

var selected_move: = ""

var ai_uses_moves: = false

var ai_think_scale: = 1.0

var side: = 1



var pp_base: = 100.0
var pp_max: = 100.0
var stamina: = 100.0
var crit_stage: = 0
var stagger_t: = 0.0
var status: = ""
var status_t: = 0.0

const STATUS_TIME: = {"burn": 6.0, "poison": 6.0, "paralysis": 6.0, "sleep": 3.0, "leech": 6.0}


const STATUS_FX_PERIOD: = {"sleep": 1.2, "paralysis": 2.0}

const CONFUSE_FX_PERIOD: = 1.5

var confusion_t: = 0.0
var leech_source: Creature
var stun_t: = 0.0
var root_t: = 0.0
var prepare_t: = 0.0
var prepare_move: Dictionary = {}
var prepare_id: = ""
var prepare_gen: = 0
var prepare_interrupted: = false
var _prepare_fx: MeshInstance3D

var trap_t: = 0.0
var evasion_t: = 0.0
var evasion: = 0.0

var dummy_style: = 0
var dash_t: = 0.0
var dash_dir: = Vector3.ZERO
var dash_speed: = 0.0
var dash_move: Dictionary = {}
var dash_miss: Node
var _dash_hit: = false

var _dash_fx_done: = false

var _dash_dodged: = {}
var _status_tick: = 0.0

var _status_fx_t: = 0.0
var _confuse_fx_t: = 0.0
var _ai_think: = 0.0

var _ai_sprint_want: = false
var _ai_react_t: = 0.0
var _ai_sprint_seen: = false


var _ai_jump_threat: = ""
var _ai_jump_at: = 0.0
var _ai_jump_done: = false

var _ai_dodge_t: = 0.0
var _ai_punished: = false

var _ai_tactic_on: = true



var cast_move: Dictionary = {}
var cast_n: = 0
var last_hit_by: Creature
var _retarget_t: = 0.0
var _struggling: = false
var _cd: = 0.0
var _lunge_t: = 0.0
var _lunge_dir: = Vector3.ZERO

var _arc_step_t: = 0.0
var _arc_step_dir: = Vector3.ZERO
var _hit_done: = false
var _knock: = Vector3.ZERO
var _recover_t: = 0.0
var opponent: Creature


var ai_legacy_pick: = false


var is_trainer_mon: = false


var trainer_item: = ""
var _item_used: = false


func _init(b: Creature) -> void :
	body = b






func speed_factor() -> float:
	var fighting: = body.mode == Creature.Mode.BATTLE_AI or body.mode == Creature.Mode.PLAYER\
	or body.mode == Creature.Mode.REMOTE or body.mode == Creature.Mode.DUMMY
	if fighting and is_instance_valid(opponent) and opponent.alive():
		return StatCalc.battle_speed_factor(stat("spe"), opponent.stat("spe"))
	return 1.0




func battle_speed() -> float:
	var b: Node = body._battle()
	if b == null:
		return 1.0
	return b.fight_speed()



func battle_move_speed() -> float:
	return BATTLE_MOVE_SPEED * speed_factor()



func gain_evs_from(defeated: Node) -> Dictionary:
	if body.mon == null or defeated == null or defeated.mon == null:
		return {}
	var old_max: = body.max_hp
	var got: Dictionary = body.mon.add_evs(defeated.mon.ev_yield())
	if got.is_empty():
		return got
	for k in StatCalc.BATTLE_STATS:
		stats[k] = int(body.mon.stats.get(k, 10))
	body.max_hp = body.mon.max_hp
	body.hp = clampi(body.hp + (body.max_hp - old_max), 0, body.max_hp)
	body.mon.hp = body.hp
	var parts: Array = []
	for s in got:
		parts.append("+%d %s EV" % [got[s], StatCalc.STAT_SHORT[s]])
	body._vfx().popup(body.head_pos(1.1), "  ".join(parts), Color(0.6, 1.0, 0.8), 0.8)
	body.refresh_label()
	return got



func min_move_cost() -> float:
	var best: = INF
	for id in moves + ([selected_move] if selected_move != "" else []):
		var mv: = Dex.move(id)
		if not mv.is_empty():
			best = minf(best, Dex.pp_cost(mv))
	return best if best < INF else 1.0


func out_of_pp() -> bool:
	return pp_max < min_move_cost()



func stagger() -> void :
	Audio.play_at("sfx/battle/stagger", body.global_position)
	stagger_t = STAGGER_TIME
	stamina = 0.0
	print("[pp] %s staggered for %.1fs (PP left %.1f)" % [body.species, STAGGER_TIME, pp_max])
	body.sprite.modulate = body.base_tint() * Color(0.7, 0.7, 0.85)
	body._vfx().popup(body.head_pos(1.1), "Exhausted!", Color(1, 0.75, 0.35))
	body._vfx().burst(body.head_pos(0.4), Color(1, 0.95, 0.5), 8, 1.2, 0.8, 0.1, 30.0, Vector3.UP, Vector3.ZERO, 0.4)
	body.refresh_label()


func restore_pp() -> void :
	stagger_t = 0.0
	pp_max = pp_base
	stamina = pp_base
	if body.mon:
		body.mon.pp = pp_max




func crit_stat(k: String, attacking: bool) -> float:
	var st: = int(stages.get(k, 0))
	st = maxi(st, 0) if attacking else mini(st, 0)
	var v: = float(stats.get(k, 10)) * StatCalc.stage_mult(st)
	if k == "atk" and status == "burn":
		v *= 0.5
	return v


func stat(k: String) -> float:
	var v: = float(stats.get(k, 10)) * StatCalc.stage_mult(int(stages.get(k, 0)))
	if k == "atk" and status == "burn":
		v *= 0.5
	return v


func can_act() -> bool:
	return not body.evolving and body.mode != Creature.Mode.FAINTED and stun_t <= 0.0 and stagger_t <= 0.0 and status != "sleep"




func apply_status(s: String, source: Creature = null) -> bool:
	if body.mode == Creature.Mode.FAINTED or body.evolving:
		return false
	if s == "flinch":
		stun_t = maxf(stun_t, 0.5)
		Audio.play_at("sfx/status/" + s, body.global_position)
		return true
	if s == "confusion":
		return confuse()
	if status != "":
		return false
	status = s
	status_t = STATUS_TIME.get(s, 4.0)
	_status_tick = 1.0
	_status_fx_t = float(STATUS_FX_PERIOD.get(s, 0.0))
	if s == "leech":
		leech_source = source
	if body.mon and body.mon.PERSIST_STATUS.has(s):
		body.mon.status = s
	body.refresh_label()
	Audio.play_at("sfx/status/" + s, body.global_position)
	body._moves().play_status_fx(body, s)
	return true



func confuse() -> bool:
	if confusion_t > 0.0 or body.mode == Creature.Mode.FAINTED or body.evolving:
		return false
	confusion_t = 4.0
	_confuse_fx_t = CONFUSE_FX_PERIOD
	Audio.play_at("sfx/status/flinch", body.global_position)
	body._moves().play_status_fx(body, "confusion")
	return true



func entomb(secs: float) -> void :
	trap_t = maxf(secs, 0.0)


func clear_status() -> void :
	var had: = status != ""
	status = ""
	status_t = 0.0
	_status_fx_t = 0.0
	leech_source = null
	if body.mon:
		body.mon.status = ""
	body.sprite.modulate = body.base_tint()
	body.refresh_label()
	if had:
		Audio.play_at("sfx/battle/cure", body.global_position)




func sync_status_from_mon() -> void :
	if body.mon == null:
		return
	var want: = String(body.mon.status)
	if want == "":
		if status != "" and status != "leech":
			clear_status()
	elif status == "":
		apply_status(want)


func _tick_status(delta: float) -> void :
	if status == "":
		return
	status_t -= delta
	_status_tick -= delta
	if _status_tick <= 0.0:
		_status_tick = 1.0
		match status:
			"burn":
				_dot(maxi(1, int(body.max_hp / 16.0)), "burn")
			"poison":
				_dot(maxi(1, int(body.max_hp / 12.0)), "poison")
			"leech":
				var d: = maxi(1, int(body.max_hp / 16.0))
				_dot(d, "leech")
				if is_instance_valid(leech_source) and leech_source.mode != Creature.Mode.FAINTED:
					leech_source.heal(d)


	_status_fx_t -= delta
	if _status_fx_t <= 0.0 and STATUS_FX_PERIOD.has(status):
		_status_fx_t = float(STATUS_FX_PERIOD[status])
		body._moves().play_status_fx(body, status, status == "sleep")
	if status_t <= 0.0:
		clear_status()


func _dot(amount: int, why: String) -> void :
	Audio.play_at("sfx/status/tick_" + why, body.global_position)
	body._vfx().popup(body.head_pos(0.6), "-%d %s" % [amount, why], Dex.type_color({"burn": "fire", "poison": "poison", "leech": "grass"}.get(why, "normal")))
	body._moves().play_status_fx(body, why)
	body.take_damage(amount, Vector3.ZERO, 0.0)





func reset_battle_mods() -> void :
	for k in stages:
		stages[k] = 0
	evasion_t = 0.0
	evasion = 0.0
	crit_stage = 0
	confusion_t = 0.0
	trap_t = 0.0
	gcd_t = 0.0
	flight = Flight.GROUNDED
	flight_t = 0.0
	dive_t = 0.0
	dive_land_t = 0.0





func _arena() -> Rect2:
	var g: Node = body._battle()
	if g == null or not g.in_battle or g.arena_rect.size.x <= 0.0:
		return Rect2()
	if not g.allies.has(body) and body != g.wild:
		return Rect2()
	return g.arena_rect



func clamp_arena() -> void :
	var r: = _arena()
	if r.size.x <= 0.0:
		return
	r = r.grow(-0.5)
	var p: = body.global_position
	var cx: = clampf(p.x, r.position.x, r.end.x)
	var cz: = clampf(p.z, r.position.y, r.end.y)
	if cx != p.x or cz != p.z:
		body.global_position = Vector3(cx, p.y, cz)




func arena_push() -> Vector3:
	var r: = _arena()
	if r.size.x <= 0.0:
		return Vector3.ZERO
	var p: = Vector2(body.global_position.x, body.global_position.z)
	var push: = Vector2.ZERO
	var m: = 2.0
	push.x += maxf(0.0, m - (p.x - r.position.x)) - maxf(0.0, m - (r.end.x - p.x))
	push.y += maxf(0.0, m - (p.y - r.position.y)) - maxf(0.0, m - (r.end.y - p.y))
	push += _obstacle_push()
	return Vector3(push.x, 0.0, push.y) / m



func _obstacle_push() -> Vector2:
	var world: = body.get_world_3d()
	var space: = world.direct_space_state if world else null
	if space == null:
		return Vector2.ZERO
	var origin: = body.global_position + Vector3(0, 0.6, 0)
	var exclude: = _dynamic_rids()
	var push: = Vector2.ZERO
	for i in 8:
		var a: = i * TAU / 8.0
		var dir: = Vector3(cos(a), 0.0, sin(a))
		var q: = PhysicsRayQueryParameters3D.create(origin, origin + dir, BLOCK_LAYERS)
		q.exclude = exclude
		var hit: = space.intersect_ray(q)
		if not hit.is_empty():
			push += Vector2( - dir.x, - dir.z) * (1.0 - origin.distance_to(hit.position))
	return push




func _dynamic_rids() -> Array:
	var out: Array = [body.get_rid()]
	var tree: = body.get_tree()
	if tree == null:
		return out
	var b: Node = body._battle()
	if b:
		for c in b.allies + [b.wild]:
			if is_instance_valid(c) and c is CollisionObject3D and not out.has(c.get_rid()):
				out.append(c.get_rid())
	var game: Node = body._game()
	var p: Node = game.get_player() if game else null
	if p is CollisionObject3D and not out.has(p.get_rid()):
		out.append(p.get_rid())
	for grp in ["wild", "npc"]:
		for n in tree.get_nodes_in_group(grp):
			if n is CollisionObject3D and not out.has(n.get_rid()):
				out.append(n.get_rid())
	return out



func hold_attacks(secs: float) -> void :
	_cd = maxf(_cd, secs)
	_ai_think = maxf(_ai_think, secs)



func _ally_mode() -> int:
	var g: Node = body._game()
	var b: Node = body._battle()
	if body.is_wild or b == null or not b.in_battle:
		return -1
	return g.ally_mode





const TARGET_FINISH_HP: = 0.35
const TARGET_STICKY: = 0.5


func _pick_target(delta: float) -> void :
	_retarget_t -= delta
	if is_instance_valid(opponent) and opponent.alive() and _retarget_t > 0.0:
		return
	_retarget_t = randf_range(2.0, 4.0)
	var g: Node = body._game()
	var best: Creature = null
	var best_w: = - INF
	for t in body._moves().targets_of(body):
		if not t.alive():
			continue
		var w: = 2.0 / maxf(body.global_position.distance_to(t.global_position), 1.0)
		if t == last_hit_by:
			w += 1.5
		if float(t.hp) / maxf(t.max_hp, 1) <= TARGET_FINISH_HP:
			w += 1.0
		if t == opponent:
			w += TARGET_STICKY
		if g and t.mode == Creature.Mode.BATTLE_AI and g.ally_mode == Creature.AllyMode.DEFEND:
			w += 2.0
		w += randf() * 0.2
		if w > best_w:
			best_w = w
			best = t
	if best:
		opponent = best


func _is_support_move(id: String) -> bool:
	var mv: = Dex.move(id)
	return mv.get("category", "") == "status" or mv.get("effect") is Dictionary



func _stat_move_maxed(id: String) -> bool:
	var mv: = Dex.move(id)
	match mv.get("kind", ""):
		"self_buff":
			return int(stages.get(String(mv.get("stat", "")), 0)) >= 6
		"debuff_aoe":
			return is_instance_valid(opponent) and int(opponent.stages.get(String(mv.get("stat", "")), 0)) <= -6
	return false





const AI_SLOP_BASE: = 0.8
const AI_SLOP_MAX: = 1.0
const AI_SLOP_KNEE: = 1.3
const AI_SLOP_KNEE_VALUE: = 0.8



const KIT_LOW_HP: = 0.5
const KIT_STAT_DEPTH: = 2


const KIT_STAT_SLOP: = 0.4

const TRAINER_ITEM_HP: = 0.35






func _ai_pick(avail: Array) -> String:
	if _ally_mode() >= 0:
		var useful: Array = avail.filter( func(id): return not _stat_move_maxed(id))
		if not useful.is_empty():
			avail = useful
	var pref: Array = []
	match _ally_mode():
		Creature.AllyMode.ATTACK:
			pref = avail.filter( func(id): return float(Dex.move(id).get("power", 0)) > 0.0)
		Creature.AllyMode.DEFEND:
			if randf() < 0.5:
				pref = avail.filter( func(id): return Dex.move(id).get("kind", "") == "self_buff")
		Creature.AllyMode.SUPPORT:
			pref = avail.filter(_is_support_move)
	if not pref.is_empty():
		avail = pref

	if ai_legacy_pick:
		return String(avail.pick_random())



	var dmg: = {}
	for id in avail:
		var mv: = Dex.move(id)
		if float(mv.get("power", 0.0)) > 0.0:
			dmg[id] = body._moves().expected_damage(body, opponent, mv)
	var usable: Array = avail.filter( func(id): return not dmg.has(id) or dmg[id] > 0.0)
	var pool: Array = usable if not usable.is_empty() else avail
	var best: = _best_move(pool, dmg)

	if best != "" and is_instance_valid(opponent) and dmg.get(best, 0.0) >= float(opponent.hp):
		return best
	if randf() < ai_error_chance():
		return String(pool.pick_random())

	var has_hit: = not dmg.values().filter( func(v): return v > 0.0).is_empty()
	var kit: Array = pool.filter( func(id): return _worth_status(id, has_hit))
	if not kit.is_empty():
		return String(kit.pick_random())
	return best if best != "" else String(pool.pick_random())



func ai_error_chance() -> float:
	if ai_think_scale <= AI_SLOP_BASE:
		return 0.0
	if ai_think_scale <= AI_SLOP_KNEE:
		var t: = (ai_think_scale - AI_SLOP_BASE) / (AI_SLOP_KNEE - AI_SLOP_BASE)
		return AI_SLOP_KNEE_VALUE * t * t * (3.0 - 2.0 * t)
	var u: = clampf((ai_think_scale - AI_SLOP_KNEE) / (1.6 - AI_SLOP_KNEE), 0.0, 1.0)
	return lerpf(AI_SLOP_KNEE_VALUE, AI_SLOP_MAX, u)





func _worth_status(id: String, has_damage: bool) -> bool:
	var mv: = Dex.move(id)
	if float(mv.get("power", 0.0)) > 0.0 or _stat_move_maxed(id):
		return false
	if float(body.hp) / maxf(body.max_hp, 1) < KIT_LOW_HP:
		return false


	var stack_ok: = not has_damage or ai_error_chance() >= KIT_STAT_SLOP
	match mv.get("kind", ""):
		"self_buff":
			var stat: = String(mv.get("stat", ""))
			var delta: = int(mv.get("stages", 1))
			var cur: = crit_stage if stat == "crit" else int(stages.get(stat, 0))
			var moved: = cur * signi(delta)
			return delta != 0 and (moved <= 0 or stack_ok) and moved < KIT_STAT_DEPTH
		"debuff_aoe":
			if not is_instance_valid(opponent):
				return false
			var cur2: = int(opponent.stages.get(String(mv.get("stat", "")), 0))
			return (cur2 >= 0 or stack_ok) and cur2 > - KIT_STAT_DEPTH
	var ef = mv.get("effect")
	if ef is Dictionary and ef.has("status"):
		var st: = String(ef.status)
		if not is_instance_valid(opponent) or opponent.status != "":
			return false
		return body._moves().STATUS_IMMUNE.get(st, "") not in opponent.types
	return false



func _want_trainer_item() -> bool:
	if not is_trainer_mon or trainer_item == "" or _item_used:
		return false
	if not body.alive():
		return false
	var e: Dictionary = ItemsData.item(trainer_item).get("effect", {})
	if e.has("hp"):
		return float(body.hp) / maxf(body.max_hp, 1) <= TRAINER_ITEM_HP
	if e.has("cure"):
		return body.status != "" and (String(e.cure) == "all" or body.status == String(e.cure))
	return false




func _use_trainer_item() -> void :
	_item_used = true
	var e: Dictionary = ItemsData.item(trainer_item).get("effect", {})
	if e.has("hp"):
		var amount: int = body.max_hp if str(e.hp) == "full" else int(e.hp)
		body.heal(mini(amount, body.max_hp - body.hp))
	elif e.has("cure") and (String(e.cure) == "all" or body.status == String(e.cure)):
		body.clear_status()
	var dlg: Node = body.get_node_or_null("/root/Dialogue")
	if dlg:
		dlg.msg("%s used a %s!" % ["The trainer", ItemsData.item_name(trainer_item)], 1.4, "item")
	Debug.log("[item] trainer: %s on %s" % [trainer_item, body.species])





func _best_move(pool: Array, dmg: Dictionary) -> String:
	var best: = ""
	var best_turns: = INF
	var best_dmg: = 0.0
	var hp: = maxf(float(opponent.hp), 1.0) if is_instance_valid(opponent) else 1.0
	for id in pool:
		var d: float = dmg.get(id, 0.0)
		if d <= 0.0:
			continue
		var turns: = ceilf(hp / d)
		if turns < best_turns or (turns == best_turns and d > best_dmg):
			best = id
			best_turns = turns
			best_dmg = d
	return best if best != "" else String(pool.pick_random())



func _guard_steer() -> Vector3:
	var g: Node = body._battle()
	var lead: Creature = g.partner if g else null
	if not is_instance_valid(lead) or lead == body or not lead.alive():
		return Vector3.INF
	var to_f: = opponent.global_position - lead.global_position
	to_f.y = 0.0
	var spot: = lead.global_position + to_f.normalized() * minf(1.5, to_f.length() * 0.5)
	var v: = spot - body.global_position
	v.y = 0.0
	if v.length() < 0.4:
		return Vector3.ZERO
	return v.normalized() * minf(1.0, v.length())


func battle_ai(delta: float) -> Vector3:
	sprinting = false
	if Battle.tut_hold_foe:
		return Vector3.ZERO
	if body.is_wild:
		_pick_target(delta)
	if not is_instance_valid(opponent) or opponent.mode == Creature.Mode.FAINTED:
		return Vector3.ZERO
	if _want_trainer_item():
		_use_trainer_item()
		_recover_t = AI_RECOVER
		return Vector3.ZERO
	if _recover_t > 0.0:
		_recover_t -= delta
		_ai_think -= delta
		return Vector3.ZERO
	var to_o: = opponent.global_position - body.global_position
	to_o.y = 0.0
	var d: = to_o.length()
	var dir: = to_o / maxf(d, 0.001)
	if ai_uses_moves and not moves.is_empty():
		var punish: = _ai_punish(d)
		if not punish:
			_ai_punished = false
		_ai_think -= delta
		var fire: = _ai_think <= 0.0

		if punish and not _ai_punished and _ai_tactic_on:
			fire = true
			_ai_punished = true
		if fire and can_act():
			_ai_tactic_on = _ai_tactic_ok()
			var used: bool = _ai_use_best_move(d)
			var base: = randf_range(AI_THINK_MIN, AI_THINK_MAX) if used else AI_THINK_RETRY
			_ai_think = base * (0.75 if _ally_mode() == Creature.AllyMode.ATTACK else 1.0) * ai_think_scale
	elif _cd <= 0.0 and _lunge_t <= 0.0 and gcd_t <= 0.0 and d < 3.2 and may_start(LUNGE) and randf() < 0.04:
		_start_lunge(dir)
		return Vector3.ZERO
	if ai_uses_moves and out_of_pp() and d > 1.4:
		return dir

	var back: = _water_retreat()
	if back != Vector3.ZERO:
		sprinting = _ai_sprint(delta, true) and can_sprint(true)
		return back
	if _ally_mode() == Creature.AllyMode.DEFEND:
		var guard: = _guard_steer()
		if guard != Vector3.INF:
			return guard
	if randf() < 0.002:
		body._strafe *= -1.0
	var side_v: = Vector3( - dir.z, 0.0, dir.x) * body._strafe
	var band: = _ai_band()
	var reach: = _ai_reach()
	if _ally_mode() == Creature.AllyMode.SUPPORT:
		band = Vector2(band.y * 0.9, band.y * 1.25)
	var low_hp: = body.max_hp > 0 and float(body.hp) <= float(body.max_hp) * AI_LOW_HP
	var kite: = band
	if low_hp:
		kite = Vector2(band.x * 1.2, band.y * AI_KITE_MULT)
	var slip: = _windup_slip(d, band)
	var want: Vector3
	if slip:
		want = (side_v - dir * 0.4).normalized()
	elif d > kite.y:
		want = (dir + side_v * 0.3).normalized()
	elif d < kite.x:

		want = ( - dir + side_v * 0.5).normalized() * (1.0 if low_hp else 0.8)
	else:


		if _ai_move_ready(d) and _ai_tactic_on:
			want = Vector3.ZERO
		elif _ai_tactic_on:
			var centre: = (band.x + band.y) * 0.5
			var radial: = dir * clampf((centre - d) / maxf(band.y - band.x, 0.1), -1.0, 1.0)
			want = (side_v * AI_WAIT_STRAFE + radial * AI_WAIT_RADIAL).normalized()
		else:
			want = side_v * 0.35

	_ai_flight(delta, want)

	var closing: = d > kite.y and (reach <= AI_MELEE_BAND or d > reach + AI_FAR_GAP)
	var reason: = closing or slip or (low_hp and d < band.y)

	var dodge: = _ai_dodge(delta, d, side_v)
	if dodge != Vector3.ZERO:
		sprinting = can_sprint(true)
		return dodge

	if _ai_try_jump(delta, d):
		sprinting = false
		return want
	sprinting = _ai_sprint(delta, reason) and can_sprint(want.length() > 0.1)
	return want







func _ai_try_jump(delta: float, d: float) -> bool:
	var threat: = _jump_threat(d)
	if threat == "":
		_ai_jump_threat = ""
		_ai_jump_done = false
		return false
	if threat != _ai_jump_threat:
		_ai_jump_threat = threat
		_ai_jump_done = false
		var err: = randf_range(-1.0, 1.0) * _ai_jump_error() * jump_time
		_ai_jump_at = maxf(_jump_lead(threat, d) - jump_time * 0.5 + err, 0.0)
		if randf() < _ai_jump_miss():
			_ai_jump_at += AI_JUMP_LATE + _ai_jump_error() * jump_time

	if _ai_jump_done or air_t > 0.0 or land_t > 0.0 or dash_t > 0.0 or _lunge_t > 0.0:
		return false
	_ai_jump_at -= delta
	if _ai_jump_at > 0.0:
		return false
	if stamina < pp_max * (JUMP_STAMINA + AI_JUMP_RESERVE):
		return false
	if can_fly():

		if take_flight():
			_ai_jump_done = true
			return true
		return false
	if swimmer and surface() == Water.Surface.DEEP:

		if start_dive():
			_ai_jump_done = true
			return true
		return false
	if start_jump():
		_ai_jump_done = true
		return true
	return false






func _jump_threat(d: float) -> String:
	if not is_instance_valid(opponent) or not can_act():
		return ""


	if locomotion != "ground" and not (can_fly() and flight == Flight.GROUNDED):
		return ""
	if jump_height <= 0.0 and not can_fly():
		return ""
	var sig: = "@%d" % opponent.combat.cast_n
	var mv: Dictionary = opponent.combat.cast_move
	if opponent.root_t > 0.0 and String(mv.get("kind", "")) == "aoe_self"\
	and String(mv.get("type", "")) == "ground" and d <= float(mv.get("radius", 0.0)):
		return "quake" + sig
	if _incoming_body_attack(d) != Vector3.ZERO and _can_clear(opponent):
		return "dash" + sig
	return ""




func _ai_jump_error() -> float:
	return maxf(AI_JUMP_ERR + AI_JUMP_ERR_SLOPE * (ai_think_scale - AI_JUMP_SHARP), 0.0)





func _ai_jump_miss() -> float:
	var d: = maxf(ai_think_scale - AI_JUMP_SHARP, 0.0)
	return minf(AI_JUMP_MISS_MAX, AI_JUMP_MISS_LIN * d + AI_JUMP_MISS_QUAD * d * d)




func _incoming_body_attack(d: float) -> Vector3:
	var oc: Combatant = opponent.combat
	if oc.dash_t > 0.0 and d - HIT_RANGE <= float(oc.dash_move.get("range", 0.0)):
		return oc.dash_dir if _aimed_at_me(oc.dash_dir) else Vector3.ZERO
	if oc._lunge_t > 0.0 and d - HIT_RANGE <= LUNGE_SPEED * LUNGE_TIME:
		return oc._lunge_dir if _aimed_at_me(oc._lunge_dir) else Vector3.ZERO
	return Vector3.ZERO


func _aimed_at_me(dir: Vector3) -> bool:
	var to_me: = body.global_position - opponent.global_position
	to_me.y = 0.0
	if to_me.length() < 0.01:
		return true
	return to_me.normalized().dot(Vector3(dir.x, 0.0, dir.z).normalized()) > 0.6





func _can_clear(att: Node) -> bool:
	if can_fly() and flight == Flight.GROUNDED:
		return true
	return jump_height * AI_JUMP_CLEAR >= att.look_height() * DASH_REACH_FACTOR



func _jump_lead(threat: String, d: float) -> float:
	if threat.begins_with("quake"):
		return maxf(opponent.root_t - QUAKE_TAIL, 0.0)
	var oc: Combatant = opponent.combat
	if oc.dash_t > 0.0:
		return maxf((d - HIT_RANGE) / maxf(oc.dash_speed, 1.0), 0.0)
	return maxf((d - HIT_RANGE) / LUNGE_SPEED, 0.0)




func _windup_slip(d: float, band: Vector2) -> bool:
	return is_instance_valid(opponent) and opponent.root_t > 0.0 and d < band.y + 1.0





func _ai_sprint(delta: float, reason: bool) -> bool:
	var pool: = stamina / maxf(pp_max, 0.001)
	if _ai_sprint_want and not (reason and pool > AI_SPRINT_KEEP):
		_ai_sprint_want = false
	if not reason or pool <= 0.0:
		_ai_sprint_seen = false
		return false
	if _ai_sprint_want:
		return true
	if pool < AI_SPRINT_MIN:
		return false
	if not _ai_sprint_seen:
		_ai_sprint_seen = true
		_ai_react_t = AI_SPRINT_REACT * maxf(ai_think_scale, 0.05)
	_ai_react_t -= delta
	if _ai_react_t > 0.0:
		return false
	_ai_react_t = AI_SPRINT_REACT * maxf(ai_think_scale, 0.05)
	_ai_sprint_want = true
	return true




func _ai_tactic_ok() -> bool:
	return randf() >= minf(1.0, _ai_jump_miss() * AI_TACTIC_MISS_MULT)



func _ai_move_ready(d: float) -> bool:
	if not ai_uses_moves or moves.is_empty() or gcd_t > 0.0:
		return false
	for id in moves:
		if float(move_cd.get(id, 0.0)) <= 0.0 and _in_range(id, d) and stamina >= Dex.fatigue(Dex.move(id)):
			return true
	return false




func _ai_use_best_move(d: float) -> bool:
	if out_of_pp():
		if d < 2.2:
			struggle()
			return true
		return false
	var avail: Array = moves.filter( func(id): return gcd_t <= 0.0 and move_cd.get(id, 0.0) <= 0.0 and _in_range(id, d) and body._moves().can_afford(body, id))



	if not avail.is_empty() and _immune_only(avail) and _has_connecting_move():
		return false
	if not avail.is_empty() and body._moves().use(body, _ai_pick(avail)):
		_recover_t = AI_RECOVER
		return true
	return false




func _immune_only(avail: Array) -> bool:
	for id in avail:
		var mv: = Dex.move(id)
		if float(mv.get("power", 0.0)) <= 0.0:
			return false
		if body._moves().expected_damage(body, opponent, mv) > 0.0:
			return false
	return true



func _has_connecting_move() -> bool:
	for id in moves:
		var mv: = Dex.move(id)
		if float(mv.get("power", 0.0)) > 0.0 and body._moves().expected_damage(body, opponent, mv) > 0.0:
			return true
	return false






func _ai_dodge(delta: float, d: float, side_v: Vector3) -> Vector3:
	var incoming: = not floats() and is_instance_valid(opponent)\
	and _incoming_body_attack(d) != Vector3.ZERO and not _can_clear(opponent)
	if not incoming or not can_act():
		_ai_dodge_t = 0.0
		return Vector3.ZERO
	if _ai_dodge_t <= 0.0:
		if not _ai_tactic_on:
			return Vector3.ZERO
		_ai_dodge_t = AI_DODGE_TIME
	_ai_dodge_t -= delta
	return side_v.normalized()




func _ai_flight(delta: float, want: Vector3) -> void :
	if not can_fly():
		return

	var pool: = pp_max / maxf(pp_base, 0.001)
	match flight:
		Flight.AIRBORNE:
			if pool < AI_FLIGHT_KEEP or (want.length() < 0.1 and flight_t > AI_FLIGHT_IDLE):
				begin_landing()
		Flight.GROUNDED:



			if pool > AI_FLIGHT_MIN and want.length() > 0.1 and can_take_flight():
				take_flight()




func _ai_punish(d: float) -> bool:
	if not is_instance_valid(opponent) or not can_act():
		return false
	var oc: Combatant = opponent.combat
	if oc == null or (oc._recover_t <= 0.0 and oc.gcd_t <= 0.0):
		return false
	return _ai_move_ready(d)






const AI_BAND_MAX: = 3.5
const AI_BAND_NEAR_RATIO: = 0.7




func _ai_reach() -> float:
	if not ai_uses_moves or moves.is_empty():
		return 0.0
	var reach: = 0.0
	for id in moves:
		var mv: = Dex.move(id)
		if float(mv.get("power", 0)) <= 0.0:
			continue
		match mv.get("kind", ""):
			"dash", "arc", "multi_arc":
				reach = maxf(reach, float(mv.get("range", 2.0)) + 0.6)
			"whip":


				reach = maxf(reach, Dex.whip_reach(body.species, mv))
			"aoe_self":
				reach = maxf(reach, float(mv.get("radius", 3.0)))
			_:
				reach = maxf(reach, minf(float(mv.get("range", 10.0)), 6.0))
	return reach


func _ai_band() -> Vector2:
	var reach: = _ai_reach()
	if reach <= 0.0:
		return Vector2(1.8, 3.0)
	var far: = minf(reach * 0.9, AI_BAND_MAX)
	return Vector2(far * AI_BAND_NEAR_RATIO, far)


func _in_range(id: String, d: float) -> bool:
	var mv: = Dex.move(id)
	match mv.get("kind", ""):
		"dash", "arc", "multi_arc":
			return d < float(mv.get("range", 2.0)) + 0.6
		"whip":
			return d < Dex.whip_reach(body.species, mv) + 0.6
		"aoe_self", "debuff_aoe":
			return d < float(mv.get("radius", 3.0))
		"stream":
			return d < float(mv.get("range", 5.0))
		"self_buff", "clones":
			return true
		_:
			return d < float(mv.get("range", 10.0))


func dummy_logic() -> Vector3:
	if not is_instance_valid(opponent):
		return Vector3.ZERO
	var to_o: = opponent.global_position - body.global_position
	to_o.y = 0.0
	var d: = to_o.length()
	var dir: = to_o / maxf(d, 0.001)
	match dummy_style:
		1:
			return Vector3( - dir.z, 0.0, dir.x) * body._strafe
		2:
			if randf() < 0.01:
				body._strafe *= -1.0
			return dir * (0.8 if body._strafe > 0.0 else -0.8) if d > 2.0 or body._strafe < 0.0 else - dir * 0.8
	return Vector3.ZERO


func aim_dir() -> Vector3:
	if is_instance_valid(opponent):
		var d: = opponent.global_position - body.global_position
		d.y = 0.0
		if d.length() > 0.01:
			return d.normalized()
	return body.facing



func can_sprint(moving: bool) -> bool:


	return not floats() and moving and can_act() and root_t <= 0.0 and trap_t <= 0.0 and stamina > 0.0



func locomotion_speed_mult() -> float:
	return FLY_SPEED_MULT if is_flying() else 1.0




func terrain_speed_mult() -> float:
	if locomotion != "ground":
		return 1.0
	match surface():
		Water.Surface.DEEP:
			return Water.SWIM_SPEED if swimmer else 1.0
		Water.Surface.SHALLOW:
			return 1.0 if swimmer else Water.WADE_SPEED
		_:
			return Water.FISH_LAND_SPEED if fish else 1.0





func surface() -> int:
	var g: Node = body._game()
	if g == null:
		return Water.Surface.GROUND
	return g.surface_at(body.global_position.x, body.global_position.z)


func is_diving() -> bool:
	return dive_t > 0.0






func water_ok(x: float, z: float) -> bool:
	if locomotion != "ground":
		return true
	var g: Node = body._game()
	if g == null:
		return true
	var s: int = g.surface_at(x, z)
	if fish:
		return s != Water.Surface.GROUND or Water.distance_to_water(g.water_rects(), x, z) <= Water.FISH_LEASH
	if swimmer:
		return s != Water.Surface.GROUND or not body.is_wild or _in_fight()
	return s != Water.Surface.DEEP



func _in_fight() -> bool:
	var b: Node = body._battle()
	if b == null or not b.in_battle:
		return false
	return b.allies.has(body) or body == b.wild





func water_clamp(prev: Vector3) -> Vector3:
	var p: = body.global_position
	if water_ok(p.x, p.z):
		return p
	var a: = Vector3(p.x, p.y, prev.z)
	if water_ok(a.x, a.z):
		return a
	var b: = Vector3(prev.x, p.y, p.z)
	if water_ok(b.x, b.z):
		return b
	return Vector3(prev.x, p.y, prev.z)



func clamp_to_water(p: Vector3) -> Vector3:
	var g: Node = body._game()
	if g == null:
		return p
	var t: = Water.nearest_point(g.water_rects(), p.x, p.z)
	if not t.is_finite():
		return p
	return Vector3(t.x, p.y, t.y)




func _water_retreat() -> Vector3:
	if locomotion != "ground":
		return Vector3.ZERO
	var s: = surface()
	if fish and s == Water.Surface.GROUND:
		return _toward_water(false)
	if swimmer and not fish and s != Water.Surface.DEEP\
	and body.max_hp > 0 and float(body.hp) <= float(body.max_hp) * AI_LOW_HP:
		return _toward_water(true)
	return Vector3.ZERO



func _toward_water(deep: bool) -> Vector3:
	var g: Node = body._game()
	if g == null:
		return Vector3.ZERO
	var p: = Vector2(body.global_position.x, body.global_position.z)
	var target: Vector2 = Water.nearest_point(g.water_rects(), p.x, p.y, deep)
	if not target.is_finite():
		return Vector3.ZERO
	var v: = Vector3(target.x - p.x, 0.0, target.y - p.y)
	return v.normalized() if v.length() > 0.2 else Vector3.ZERO



func airborne_min() -> float:
	return maxf(AIRBORNE_FLOOR, jump_height * AIRBORNE_FRACTION)



func can_fly() -> bool:
	return locomotion == "fly"



func is_flying() -> bool:
	return can_fly() and flight == Flight.AIRBORNE and body.mode != Creature.Mode.FAINTED


func is_hovering() -> bool:
	return locomotion == "hover"




func floats() -> bool:
	return body.mode != Creature.Mode.FAINTED and (is_hovering() or flight != Flight.GROUNDED)





func float_target_height() -> float:
	if is_flying():
		if alt_override_t > 0.0:
			return alt_override
		if dash_t > 0.0 or _lunge_t > 0.0:
			return SWOOP_HEIGHT
		return fly_height + sin(_bob_t) * FLY_BOB
	if flight == Flight.LANDING:
		return 0.0
	return HOVER_HEIGHT + sin(_bob_t * 0.7) * FLY_BOB * 0.5



func lift_for(to: float, secs: float) -> void :
	alt_override = to
	alt_override_t = maxf(secs, 0.0)



func hold_altitude(delta: float) -> void :
	var bsp: = battle_speed()
	var d: = delta * bsp
	alt_override_t = maxf(alt_override_t - d, 0.0)
	_bob_t += d * FLY_BOB_SPEED
	var target: = body.ground_y() + float_target_height()
	body.velocity.y = clampf((target - body.global_position.y) * ALT_SPRING, - ALT_MAX_VY, ALT_MAX_VY) * bsp
	air_h = maxf(body.global_position.y - body.ground_y(), 0.0)


	if flight == Flight.LANDING and body.global_position.y <= body.ground_y() + 0.03:
		_touch_down()




func is_airborne() -> bool:
	if is_diving():
		return true
	if floats():
		return true
	return air_t > 0.0 and air_h > airborne_min()



static func jump_time_for(h: float) -> float:
	return sqrt(8.0 * h / JUMP_G) if h > 0.0 else 0.0



func jump_vy() -> float:
	return sqrt(2.0 * JUMP_G * jump_height)




func dash_reach() -> float:
	return body.look_height() * DASH_REACH_FACTOR








func passes_under(t: Node) -> bool:
	if t.combat.is_diving():
		return true
	return t.is_airborne() and (t.combat.air_h - air_h) >= dash_reach()






func hop_to_reach(t: Node) -> void :
	if not is_instance_valid(t) or not t.combat.is_airborne() or not passes_under(t):
		return
	if not can_jump():
		return
	if t.combat.air_h - jump_height >= dash_reach():
		return
	start_jump()




func dodge_tell(t: Node, id: = "") -> void :
	body._moves().dodge_tell(t, id)




func _may_jump_here() -> bool:
	var s: = surface()
	if s == Water.Surface.DEEP:
		return not swimmer
	if s == Water.Surface.SHALLOW:
		return swimmer
	return not fish





func can_jump() -> bool:
	return locomotion == "ground" and jump_height > 0.0 and can_act() and root_t <= 0.0 and trap_t <= 0.0\
	and stamina > 0.0 and air_t <= 0.0 and land_t <= 0.0 and dash_t <= 0.0 and _lunge_t <= 0.0\
	and _may_jump_here()







func jump_verb() -> String:
	if is_flying():
		return "Land"
	if can_fly():
		return "Fly"
	if swimmer and surface() == Water.Surface.DEEP:
		return "Dive"
	if locomotion == "ground" and jump_height > 0.0:
		return "Jump"
	return ""




func jump_ready() -> bool:
	match jump_verb():
		"Land":
			return true
		"Fly":
			return can_take_flight()
		"Dive":
			return can_dive()
		"Jump":
			return can_jump()
	return false






func may_start(mv: Dictionary) -> bool:



	if floats():
		return true
	return not is_airborne() or bool(mv.get("allowed_midair", true))



func start_jump() -> bool:
	if not can_jump():
		return false
	air_t = jump_time
	air_h = 0.0
	stamina = maxf(stamina - pp_max * JUMP_STAMINA, 0.0)
	body.squash = JUMP_STRETCH
	body._vfx().burst(body.global_position + Vector3(0, 0.05, 0), JUMP_DUST, 6, 0.3, 1.4, 0.12, 180.0, Vector3.UP, Vector3(0, -2.5, 0))
	return true







func can_dive() -> bool:
	return swimmer and locomotion != "fly" and surface() == Water.Surface.DEEP and can_act()\
	and root_t <= 0.0 and trap_t <= 0.0 and stamina > 0.0 and dive_t <= 0.0\
	and dive_land_t <= 0.0 and air_t <= 0.0 and land_t <= 0.0 and dash_t <= 0.0 and _lunge_t <= 0.0




func start_dive() -> bool:
	if not can_dive():
		return false
	dive_t = Water.DIVE_TIME
	stamina = maxf(stamina - pp_max * Water.DIVE_STAMINA, 0.0)
	body.squash = JUMP_SQUASH
	body._vfx().shockwave(body.global_position, 0.6, Color(0.78, 0.93, 1.0), 0.06)
	return true




func can_take_flight() -> bool:
	return can_fly() and flight == Flight.GROUNDED and can_act()\
	and root_t <= 0.0 and trap_t <= 0.0 and land_t <= 0.0 and air_t <= 0.0\
	and dash_t <= 0.0 and _lunge_t <= 0.0 and stamina > pp_max * FLIGHT_MIN



func take_flight() -> bool:
	if not can_take_flight():
		return false
	flight = Flight.AIRBORNE
	flight_t = 0.0
	stamina = maxf(stamina - pp_max * FLIGHT_TAKEOFF, 0.0)
	body.squash = JUMP_STRETCH
	body._vfx().burst(body.global_position + Vector3(0, 0.05, 0), JUMP_DUST, 6, 0.3, 1.4, 0.12, 180.0, Vector3.UP, Vector3(0, -2.5, 0))
	return true




func begin_landing() -> void :
	if flight == Flight.AIRBORNE:
		flight = Flight.LANDING



func _touch_down() -> void :
	flight = Flight.GROUNDED
	flight_t = 0.0
	land_t = FLIGHT_LAND
	body.squash = JUMP_SQUASH
	body._vfx().burst(body.global_position + Vector3(0, 0.05, 0), JUMP_DUST, 9, 0.4, 2.0, 0.14, 180.0, Vector3.UP, Vector3(0, -3, 0))






func read_local_intent() -> Dictionary:
	var lock: = Battle.tut_locked
	var slot: = -1


	for k in mini(moves.size(), 4):
		if lock and k != Battle.tut_move:
			continue
		if not Input.is_action_just_pressed("move_%d" % (k + 1)):
			continue
		if Controls.items_page_held():
			Progression.use_quick_item(k)
		else:
			slot = k
			break
	return {
		"move": Input.get_vector("move_left", "move_right", "move_up", "move_down"), 
		"sprint": Input.is_action_pressed("sprint"), 
		"jump": Input.is_action_just_pressed("jump"), 
		"slot": slot, 
	}






func apply_intent(it: Dictionary) -> Vector3:
	var lock: = Battle.tut_locked
	if not lock and bool(it.get("jump", false)):
		var jumped: = false
		if is_flying():
			begin_landing()
		elif can_fly():
			jumped = take_flight()
		elif swimmer and surface() == Water.Surface.DEEP:
			jumped = start_dive()
		else:
			jumped = start_jump()
		if jumped:
			Battle.note_jump(body)
	var i: Vector2 = it.get("move", Vector2.ZERO)
	if lock and not Battle.tut_walk:
		i = Vector2.ZERO
	sprinting = not lock and bool(it.get("sprint", false)) and can_sprint(i.length() > 0.1)
	var slot: = int(it.get("slot", -1))
	if slot >= 0 and slot < mini(moves.size(), 4) and ( not lock or slot == Battle.tut_move):
		selected_move = String(moves[slot])
		if can_act():
			if selected_move != "" and out_of_pp():
				if gcd_t > 0.0:
					Audio.ui("sfx/ui/error")
				else:
					struggle()
			elif selected_move != "":
				body._moves().use(body, selected_move, true)
	return Vector3(i.x, 0.0, i.y)


func player_input() -> Vector3:
	return apply_intent(read_local_intent())



func start_dash(mv: Dictionary, dir: Vector3, miss: Node = null) -> void :
	dash_move = mv
	dash_miss = miss
	dash_dir = dir
	dash_speed = float(mv.get("speed", 12.0))
	dash_t = float(mv.get("range", 3.0)) / dash_speed
	_dash_hit = false
	_dash_fx_done = false
	_dash_dodged.clear()
	body.facing = dir


func _check_dash_hit() -> void :
	if _dash_hit:
		return
	for t in body._moves().targets_of(body):
		if t == dash_miss:
			continue
		if body.global_position.distance_to(t.global_position) < HIT_RANGE:

			if passes_under(t):
				if not _dash_dodged.has(t.get_instance_id()):
					_dash_dodged[t.get_instance_id()] = true
					dodge_tell(t, dash_move.get("id", ""))
				continue
			_dash_hit = true
			dash_t = 0.0
			body._moves().hit(body, t, dash_move, dash_dir)
			return






func begin_prepare(id: String, mv: Dictionary, prepare: float) -> int:
	prepare_gen += 1
	prepare_id = id
	prepare_move = mv
	prepare_t = prepare
	prepare_interrupted = false
	root_t = maxf(root_t, prepare)
	body.squash = JUMP_SQUASH
	_prepare_fx = body._vfx().prepare_ring(body.global_position, Dex.type_color(String(mv.get("type", "normal"))), prepare)
	return prepare_gen




func wait_prepare(gen: int) -> bool:
	var t: = prepare_t
	if t > 0.0:
		await Battle.fight_timer(t).timeout
	if prepare_gen != gen:
		return false
	if not is_instance_valid(body) or not can_act():
		_clear_prepare()
		return false
	return true



func _clear_prepare() -> void :
	prepare_t = 0.0
	prepare_move = {}
	prepare_id = ""
	prepare_gen += 1
	if is_instance_valid(_prepare_fx):
		_prepare_fx.queue_free()
	_prepare_fx = null



func end_prepare() -> void :
	_clear_prepare()
	body.squash = JUMP_STRETCH



func cancel_prepare() -> void :
	_clear_prepare()




func interrupt_prepare() -> void :
	if prepare_move.is_empty():
		return
	var id: = prepare_id
	_clear_prepare()
	prepare_interrupted = true
	root_t = 0.0
	stun_t = maxf(stun_t, PREPARE_STUN)
	if id != "":
		move_cd[id] = minf(float(move_cd.get(id, 0.0)), gcd_t)
	body._vfx().popup(body.head_pos(0.9), "Interrupted!", Color(0.6, 0.6, 0.6), 1.0, "miss")
	print("[prepare] %s interrupted" % body.species)



func clear_cooldowns() -> void :
	move_cd.clear()
	gcd_t = 0.0
	root_t = 0.0
	cancel_prepare()



func struggle() -> void :
	if _cd > 0.0 or _lunge_t > 0.0 or gcd_t > 0.0 or not may_start(STRUGGLE):
		return
	body._vfx().popup(body.head_pos(1.0), "No PP left! Struggle!", Color(1, 0.6, 0.4))
	_start_lunge(aim_dir())
	_cd = 1.0
	_struggling = true


func _start_lunge(dir: Vector3) -> void :
	hop_to_reach(opponent)
	_lunge_dir = dir
	_cd = ATTACK_CD
	gcd_t = Dex.GLOBAL_COOLDOWN / speed_factor()
	var gen: = begin_prepare("", LUNGE, LUNGE_PREPARE)
	_release_lunge(gen)



func _release_lunge(gen: int) -> void :
	if not await wait_prepare(gen):
		return
	end_prepare()
	_lunge_t = LUNGE_TIME
	_hit_done = false







func start_arc_step(dir: Vector3) -> void :
	if air_t > 0.0 or floats() or is_diving() or dash_t > 0.0 or _lunge_t > 0.0:
		return
	if is_instance_valid(opponent):
		var to_o: = opponent.global_position - body.global_position
		to_o.y = 0.0
		if to_o.length() <= HIT_RANGE:
			return
	_arc_step_dir = dir
	_arc_step_t = ARC_STEP_TIME


func _check_hit() -> void :
	if _hit_done or not is_instance_valid(opponent) or opponent.mode == Creature.Mode.FAINTED:
		return
	if body.global_position.distance_to(opponent.global_position) < HIT_RANGE:
		if passes_under(opponent):
			_hit_done = true
			_lunge_t = 0.0
			dodge_tell(opponent, STRUGGLE.id if _struggling else "lunge")
			return
		_hit_done = true
		_lunge_t = 0.0
		if not _struggling:
			opponent.last_hit_by = body
			opponent.take_damage(randi_range(3, 5) + int(body.level / 2.0), _lunge_dir)
			return
		_struggling = false
		body._moves().hit(body, opponent, STRUGGLE, _lunge_dir)
		var recoil: = maxi(1, int(body.max_hp / 4.0))
		body._vfx().popup(body.head_pos(0.6), "-%d recoil" % recoil, Color(1, 0.6, 0.4))
		Audio.play_at("sfx/battle/recoil", body.global_position)
		body.take_damage(recoil, - _lunge_dir, 3.0)





func tick(delta: float) -> void :

	delta *= battle_speed()
	_cd = maxf(_cd - delta, 0.0)
	body.peace_timer = maxf(body.peace_timer - delta, 0.0)
	stun_t = maxf(stun_t - delta, 0.0)
	root_t = maxf(root_t - delta, 0.0)
	prepare_t = maxf(prepare_t - delta, 0.0)
	if prepare_t > 0.0:
		body.squash = JUMP_SQUASH
	trap_t = maxf(trap_t - delta, 0.0)
	land_t = maxf(land_t - delta, 0.0)
	if dive_t > 0.0:
		dive_t = maxf(dive_t - delta, 0.0)
		if dive_t == 0.0:
			dive_land_t = Water.DIVE_LAND
			body.squash = JUMP_STRETCH
			body._vfx().shockwave(body.global_position, 0.5, Color(0.82, 0.95, 1.0), 0.06)
	dive_land_t = maxf(dive_land_t - delta, 0.0)
	evasion_t = maxf(evasion_t - delta, 0.0)
	confusion_t = maxf(confusion_t - delta, 0.0)
	if confusion_t > 0.0:
		_confuse_fx_t -= delta
		if _confuse_fx_t <= 0.0:
			_confuse_fx_t = CONFUSE_FX_PERIOD
			body._moves().play_status_fx(body, "confusion")
	for k in move_cd.keys():
		move_cd[k] = maxf(move_cd[k] - delta, 0.0)
	gcd_t = maxf(gcd_t - delta, 0.0)
	_tick_status(delta)
	if flight != Flight.GROUNDED:
		flight_t += delta
		if flight == Flight.AIRBORNE:


			pp_max = maxf(pp_max - pp_base * FLIGHT_DRAIN * delta, 0.0)
			if body.mon:
				body.mon.pp = pp_max
			if pp_max <= pp_base * FLIGHT_FLOOR:
				begin_landing()
	if stagger_t > 0.0:
		stagger_t = maxf(stagger_t - delta, 0.0)
		if stagger_t == 0.0:
			stamina = 0.0
			body.sprite.modulate = body.base_tint()
			body.refresh_label()
	elif sprinting and not floats():
		stamina = maxf(stamina - pp_max * SPRINT_DRAIN * delta, 0.0)
		if stamina <= 0.0:
			sprinting = false
	elif stamina < pp_max:
		stamina = minf(pp_max, stamina + pp_max * PP_REGEN * speed_factor() * delta)
	elif stamina > pp_max:
		stamina = pp_max




func drive_velocity(delta: float, want: Vector3, speed: float, fighting: bool) -> void :




	var bsp: = battle_speed()
	var d: = delta * bsp
	var in_fight: = fighting and is_instance_valid(opponent)
	if fighting:
		speed *= speed_factor()
	speed *= locomotion_speed_mult()
	speed *= terrain_speed_mult()
	if status == "paralysis":
		speed *= 0.5



	if (fighting and not can_act()) or root_t > 0.0:
		want = Vector3.ZERO
	if trap_t > 0.0:

		want = Vector3.ZERO
		dash_t = 0.0
		_lunge_t = 0.0
		_knock = Vector3.ZERO


	if air_t > 0.0:
		air_t = maxf(air_t - d, 0.0)
		var t: = jump_time - air_t
		air_h = maxf(jump_vy() * t - 0.5 * JUMP_G * t * t, 0.0)
		body.velocity.y = (jump_vy() - JUMP_G * t) * bsp
		if air_t <= 0.0:
			air_h = 0.0
			land_t = JUMP_LAND
			body.squash = JUMP_SQUASH
			body._vfx().burst(body.global_position + Vector3(0, 0.05, 0), JUMP_DUST, 9, 0.4, 2.0, 0.14, 180.0, Vector3.UP, Vector3(0, -3, 0))
	elif floats():
		hold_altitude(delta)
	if dash_t > 0.0:
		dash_t -= d
		body.velocity.x = dash_dir.x * dash_speed * bsp
		body.velocity.z = dash_dir.z * dash_speed * bsp
		_check_dash_hit()

		if dash_t <= 0.0 and not _dash_hit and not _dash_fx_done:
			_dash_fx_done = true
			body._moves().play_dash_reach_fx(body, dash_move, dash_dir)
	elif _lunge_t > 0.0:
		_lunge_t -= d
		body.velocity.x = _lunge_dir.x * LUNGE_SPEED * bsp
		body.velocity.z = _lunge_dir.z * LUNGE_SPEED * bsp
		_check_hit()
	elif _arc_step_t > 0.0:

		_arc_step_t -= d
		var step: = ARC_STEP_M / ARC_STEP_TIME
		if is_instance_valid(opponent):
			var to_t: = opponent.global_position - body.global_position
			to_t.y = 0.0
			step = minf(step, (to_t.length() - HIT_RANGE) / maxf(d, 0.0001))
		step = maxf(step, 0.0)
		if step == 0.0:
			_arc_step_t = 0.0
		body.velocity.x = _arc_step_dir.x * step * bsp
		body.velocity.z = _arc_step_dir.z * step * bsp
	else:
		body.velocity.x = (want.x * speed + _knock.x) * bsp
		body.velocity.z = (want.z * speed + _knock.z) * bsp
		if in_fight:
			var to_o: = opponent.global_position - body.global_position
			to_o.y = 0.0
			if to_o.length() > 0.01:
				body.facing = to_o.normalized()
		elif want.length() > 0.1:
			body.facing = want.normalized()
	_knock = _knock.move_toward(Vector3.ZERO, 30.0 * d)
