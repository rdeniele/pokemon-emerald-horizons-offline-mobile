extends RefCounted













const Dex: = preload("res://scripts/dex.gd")
const StatCalc: = preload("res://scripts/stats/stat_calc.gd")
const Growth: = preload("res://scripts/stats/growth.gd")
const SELF_PATH: = "res://scripts/stats/mon.gd"
const DEFAULT_SPRITE: = "res://assets/sprites/critter_green.png"

var species: = ""
var nickname: = ""
var level: = 1
var nature: = "hardy"
var ivs: = {}
var evs: = {}

var stats: = {}
var hp: = 0



var status: = ""

const PERSIST_STATUS: = ["burn", "poison", "paralysis", "sleep"]

var pp: = 0.0

var owner: = ""
var ball: = "poke_ball"

var gender: = ""


var ability_slot: = 0
var moves: Array = []

var xp: = 0

var evo_cancelled_level: = 0



var evo_pending: = false


var met_level: = 0
var met_zone: = ""

var display_name: String:
	get:
		return nickname if nickname != "" else species
var max_hp: int:
	get:
		return int(stats.get("hp", 1))
var pp_base: float:
	get:
		return float(_sp().get("pp", 100))
var sprite: String:
	get:
		return _sp().get("sprite", DEFAULT_SPRITE)
var types: Array:
	get:
		return _sp().get("types", ["normal"])
var growth: String:
	get:
		return _sp().get("growth", "medium_fast")

var ability: String:
	get:
		var abil: Array = _sp().get("abilities", [])
		if abil.is_empty():
			return ""
		return String(abil[clampi(ability_slot, 0, abil.size() - 1)])

var ability_name: String:
	get:
		var a: = ability
		return "" if a == "" else String(Dex.ability(a).get("name", a))
var ability_desc: String:
	get:
		var a: = ability
		return "" if a == "" else String(Dex.ability(a).get("desc", ""))

var exp_this_level: int:
	get:
		return Growth.exp_for_level(growth, level)
var exp_next_level: int:
	get:
		return Growth.exp_for_level(growth, mini(level + 1, Growth.MAX_LEVEL))



static func create(sp_name: String, lv: int, rng: RandomNumberGenerator = null) -> RefCounted:
	var m = load(SELF_PATH).new()
	m.species = sp_name
	m.level = lv
	m.ivs = StatCalc.random_ivs(rng)
	m.evs = StatCalc.zero_evs()
	m.nature = StatCalc.random_nature(rng)
	m.gender = _roll_gender(sp_name, rng)
	m.ability_slot = _roll_ability_slot(sp_name, rng)
	m.moves = Dex.moves_at(sp_name, lv)
	m.xp = Growth.exp_for_level(m.growth, lv)
	m.recalc()
	m.heal_full()
	return m


func _sp() -> Dictionary:
	return Dex.species(species)



static func _roll_gender(sp_name: String, rng: RandomNumberGenerator = null) -> String:
	var ratio: = float(Dex.species(sp_name).get("gender_ratio", 0.5))
	if ratio < 0.0:
		return ""
	var roll: = (rng.randf() if rng else randf())
	return "female" if roll < ratio else "male"



static func _roll_ability_slot(sp_name: String, rng: RandomNumberGenerator = null) -> int:
	if Dex.species(sp_name).get("abilities", []).size() < 2:
		return 0
	var roll: = (rng.randf() if rng else randf())
	return 1 if roll < 0.5 else 0



func recalc() -> void :
	var old_max: = int(stats.get("hp", 0))
	var base: Dictionary = _sp().get("base", {})
	for s in StatCalc.STATS:
		stats[s] = StatCalc.stat(s, int(base.get(s, 50)), int(ivs.get(s, 0)), int(evs.get(s, 0)), level, nature)
	if old_max > 0:
		hp = clampi(hp + (max_hp - old_max), 0, max_hp)


func heal_full() -> void :
	hp = max_hp
	pp = pp_base
	status = ""


func is_fainted() -> bool:
	return hp <= 0




func ev_total() -> int:
	var t: = 0
	for s in evs:
		t += int(evs[s])
	return t



func ev_yield() -> Dictionary:
	return _sp().get("ev_yield", {})



func catch_rate() -> int:
	return int(_sp().get("catch_rate", 190))



func add_evs(gain: Dictionary) -> Dictionary:
	var got: = {}
	for s in gain:
		var room: = mini(StatCalc.EV_MAX_STAT - int(evs.get(s, 0)), StatCalc.EV_MAX_TOTAL - ev_total())
		var add: = clampi(int(gain[s]), 0, maxi(room, 0))
		if add > 0:
			evs[s] = int(evs.get(s, 0)) + add
			got[s] = add
	if not got.is_empty():
		recalc()
	return got





func exp_yield(winner_level: int, trainer: = false) -> int:
	return Growth.exp_gain(int(_sp().get("base_exp", 50)), level, winner_level, trainer)






func add_exp(amount: int) -> Array:
	var events: Array = []
	if level >= Growth.MAX_LEVEL or amount <= 0:
		return events
	xp += amount
	while level < Growth.MAX_LEVEL and xp >= Growth.exp_for_level(growth, level + 1):
		level += 1
		recalc()
		events.append({"type": "level", "level": level})
		if evolution_target() != "":
			evo_pending = true
		for e in _sp().get("learnset", []):
			if int(e[0]) == level and not moves.has(e[1]):
				var ok: bool = moves.size() < 4
				if ok:
					moves.append(e[1])
				events.append({"type": "move", "move": e[1], "learned": ok})
	if level >= Growth.MAX_LEVEL:
		xp = Growth.exp_for_level(growth, Growth.MAX_LEVEL)
	return events




func evolution_target() -> String:
	var evo: Dictionary = _sp().get("evolution", {})
	if evo.is_empty() or String(evo.get("method", "level")) != "level":
		return ""
	if level < int(evo.get("level", 999)) or level <= evo_cancelled_level:
		return ""
	return String(evo.get("into", ""))







func evolve(into: String) -> Array:
	species = into
	evo_cancelled_level = 0
	evo_pending = false
	var candidates: Array = []
	for e in _sp().get("learnset", []):
		if int(e[0]) == level:
			candidates.append(e[1])
	for id in _sp().get("evo_moves", []):
		candidates.append(id)
	var missed: Array = []
	for id in candidates:
		if moves.has(id) or missed.has(id):
			continue
		if moves.size() < 4:
			moves.append(id)
		else:
			missed.append(id)
	recalc()
	return missed



func replace_move(k: int, id: String) -> void :
	if k >= 0 and k < moves.size():
		moves[k] = id




func to_dict() -> Dictionary:
	return {"species": species, "nickname": nickname, "level": level, "nature": nature, 
		"ivs": ivs.duplicate(), "evs": evs.duplicate(), "hp": hp, "pp": pp, "status": status, "owner": owner, "ball": ball, "gender": gender, "ability_slot": ability_slot, "moves": moves.duplicate(), "xp": xp, "evo_cancelled_level": evo_cancelled_level, 
		"evo_pending": evo_pending, "met_level": met_level, "met_zone": met_zone}


static func from_dict(d: Dictionary) -> RefCounted:
	var m = load(SELF_PATH).new()
	m.species = d.get("species", "")
	m.nickname = d.get("nickname", "")
	m.level = int(d.get("level", 1))
	m.nature = d.get("nature", "hardy")
	m.ivs = d.get("ivs", StatCalc.random_ivs())
	m.evs = d.get("evs", StatCalc.zero_evs())
	m.owner = d.get("owner", "")
	m.ball = d.get("ball", "poke_ball")


	if d.has("gender"):
		m.gender = str(d.get("gender", ""))
		if m.gender != "male" and m.gender != "female":
			m.gender = ""
	else:
		var gr: = RandomNumberGenerator.new()
		gr.seed = hash("%s|%s|%s" % [m.species, m.nature, m.ivs])
		m.gender = _roll_gender(m.species, gr)

	if d.has("ability_slot"):
		m.ability_slot = clampi(int(d.get("ability_slot", 0)), 0, 1)
	else:
		var ar: = RandomNumberGenerator.new()
		ar.seed = hash("%s|%s|%s|ability" % [m.species, m.nature, m.ivs])
		m.ability_slot = _roll_ability_slot(m.species, ar)
	m.moves = d.get("moves", Dex.moves_at(m.species, m.level))
	m.xp = int(d.get("xp", Growth.exp_for_level(m.growth, m.level)))
	m.evo_cancelled_level = int(d.get("evo_cancelled_level", 0))
	m.evo_pending = bool(d.get("evo_pending", false))
	m.met_level = int(d.get("met_level", 0))
	m.met_zone = String(d.get("met_zone", ""))

	m.status = String(d.get("status", ""))
	if not PERSIST_STATUS.has(m.status):
		m.status = ""
	m.recalc()
	m.hp = int(d.get("hp", m.max_hp))
	m.pp = float(d.get("pp", m.pp_base))
	return m
