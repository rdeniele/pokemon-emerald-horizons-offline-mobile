class_name GameState
extends RefCounted




const ItemsData: = preload("res://scripts/items.gd")
const Capture: = preload("res://scripts/stats/capture.gd")
const MonScript: = preload("res://scripts/stats/mon.gd")
const CreatureDef: = preload("res://scripts/creature.gd")
const DebugScript: = preload("res://scripts/debug.gd")

const SAVE_VERSION: = 2
const DEFAULT_PLAYER_NAME: = "RED"
const DEFAULT_RIVAL_NAME: = "BLUE"


const DEFAULT_GENDER: = "red"
const GENDERS: = ["red", "green"]
const MONTHS: = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

const NEW_GAME_MONEY: = 3000

const DEFAULT_CLOCK_MINUTES: = 540.0
const DEFAULT_BAG: = {"potion": 1}
const DEFAULT_QUICK_SLOTS: = ["potion", "super_potion", "poke_ball", "antidote"]


const TRAINER_PAYOUTS: = {
	"rival": 35, "youngster": 16, "bug_catcher": 12, "lass": 16, "camper": 20, 
	"picnicker": 20, "hiker": 36, "jr_trainer": 20, "gym_leader": 99, 
}

const HOME_HEAL_POINT: = {"scene": "res://scenes/interiors/pallet_town_interiors.tscn", 
	"pos": [38.4, 0.0, 1.2], "facing": 3, "home": true}


var party: Array = []
var box: Array = []
var bag: Dictionary = {}
var selected_ball: = "poke_ball"
var quick_slots: Array = []
var flags: Dictionary = {}

var badges: Array = []
var ally_mode: int = CreatureDef.AllyMode.ATTACK
var player_name: = DEFAULT_PLAYER_NAME

var player_gender: = DEFAULT_GENDER


var rival_name: = DEFAULT_RIVAL_NAME

var trainer_id: = ""

var started_at: = 0
var play_time: = 0.0

var clock_minutes: = DEFAULT_CLOCK_MINUTES
var money: int = NEW_GAME_MONEY
var dex_seen: Dictionary = {}
var dex_caught: Dictionary = {}
var last_heal_point: Dictionary = {}

var repel_steps: = 0


var reward_override: = -1


var weather: Dictionary = {}


var companions: Dictionary = {}
var talking: = false
var menu_open: = false
var cutscene: = false

func _init() -> void :
	reset_new_game()




func reset_new_game() -> void :
	party = []
	box = []
	bag = DEFAULT_BAG.duplicate()
	if DebugScript.enabled:
		bag["master_ball"] = 1
	selected_ball = "poke_ball"
	quick_slots = DEFAULT_QUICK_SLOTS.duplicate()
	flags = {}
	badges = []
	ally_mode = CreatureDef.AllyMode.ATTACK
	player_name = DEFAULT_PLAYER_NAME
	player_gender = DEFAULT_GENDER
	rival_name = DEFAULT_RIVAL_NAME
	trainer_id = new_trainer_id()
	started_at = int(Time.get_unix_time_from_system())
	play_time = 0.0
	clock_minutes = DEFAULT_CLOCK_MINUTES
	money = NEW_GAME_MONEY
	dex_seen = {}
	dex_caught = {}
	last_heal_point = {}
	repel_steps = 0
	reward_override = -1
	weather = {}
	reset_runtime()


func reset_runtime() -> void :
	companions = {}
	talking = false
	menu_open = false
	cutscene = false
	reward_override = -1


func to_dict() -> Dictionary:
	var p: Array = []
	for m in party:
		p.append(m.to_dict())
	var b: Array = []
	for m in box:
		b.append(m.to_dict())
	return {"v": SAVE_VERSION, "party": p, "box": b, "bag": bag.duplicate(), 
		"selected_ball": selected_ball, "quick_slots": quick_slots.duplicate(), 
		"flags": flags.duplicate(), "badges": badges.duplicate(), "ally_mode": ally_mode, 
		"player_name": player_name, "player_gender": player_gender, 
		"rival_name": rival_name, "trainer_id": trainer_id, "started_at": started_at, 
		"play_time": play_time, "clock_minutes": clock_minutes, 
		"money": money, "dex_seen": _sorted_keys(dex_seen), "dex_caught": _sorted_keys(dex_caught), 
		"last_heal_point": last_heal_point.duplicate(), "repel_steps": repel_steps, 
		"weather": weather.duplicate(true)}


func from_dict(d: Dictionary) -> void :
	reset_runtime()
	party = []
	for md in d.get("party", []):
		if md is Dictionary:
			party.append(MonScript.from_dict(md))
	box = []
	for md in d.get("box", []):
		if md is Dictionary:
			box.append(MonScript.from_dict(md))
	var b = d.get("bag", DEFAULT_BAG)
	bag = b.duplicate() if b is Dictionary else DEFAULT_BAG.duplicate()
	selected_ball = str(d.get("selected_ball", "poke_ball"))
	var q = d.get("quick_slots", DEFAULT_QUICK_SLOTS)
	quick_slots = q.duplicate() if q is Array and q.size() == 4 else DEFAULT_QUICK_SLOTS.duplicate()
	var f = d.get("flags", {})
	flags = f.duplicate() if f is Dictionary else {}
	var bd = d.get("badges", [])
	badges = bd.duplicate() if bd is Array else []
	ally_mode = int(d.get("ally_mode", CreatureDef.AllyMode.ATTACK))
	var n: = str(d.get("player_name", DEFAULT_PLAYER_NAME)).strip_edges()
	player_name = n if n != "" else DEFAULT_PLAYER_NAME
	var pg: = str(d.get("player_gender", DEFAULT_GENDER))
	player_gender = pg if GENDERS.has(pg) else DEFAULT_GENDER
	var rn: = str(d.get("rival_name", DEFAULT_RIVAL_NAME)).strip_edges()
	rival_name = rn if rn != "" else DEFAULT_RIVAL_NAME
	var tid: = str(d.get("trainer_id", "")).strip_edges()
	trainer_id = tid if tid != "" else new_trainer_id()
	started_at = maxi(int(d.get("started_at", 0)), 0)
	var pt = d.get("play_time", 0.0)
	play_time = maxf(0.0, float(pt)) if (pt is float or pt is int) else 0.0
	var cm = d.get("clock_minutes", DEFAULT_CLOCK_MINUTES)
	clock_minutes = float(cm) if (cm is float or cm is int) else DEFAULT_CLOCK_MINUTES
	money = maxi(int(d.get("money", NEW_GAME_MONEY)), 0)
	dex_seen = _set_from(d.get("dex_seen", []))
	dex_caught = _set_from(d.get("dex_caught", []))
	var hp = d.get("last_heal_point", {})
	last_heal_point = hp.duplicate() if hp is Dictionary else {}
	repel_steps = maxi(int(d.get("repel_steps", 0)), 0)
	var wd = d.get("weather", {})
	weather = wd.duplicate(true) if wd is Dictionary else {}



static func new_trainer_id() -> String:
	return "%05d" % randi_range(0, 99999)



static func format_started(ts: int) -> String:
	if ts <= 0:
		return ""
	var d: = Time.get_datetime_dict_from_unix_time(ts)
	return "%s %d, %d" % [MONTHS[d.month - 1], d.day, d.year]



static func format_time(secs: float) -> String:
	var m: = floori(secs / 60.0)
	return "%d:%02d" % [floori(m / 60.0), m % 60]



static func _sorted_keys(set: Dictionary) -> Array:
	var out: Array = set.keys()
	out.sort()
	return out



static func _set_from(v) -> Dictionary:
	var out: = {}
	if v is Array:
		for s in v:
			if s is String and s != "":
				out[s] = true
	elif v is Dictionary:
		for s in v:
			if v[s]:
				out[s] = true
	return out




func is_green() -> bool:
	return player_gender == "green"

func is_out(i: int) -> bool:
	return companions.has(i) and is_instance_valid(companions[i])





func swap_party(a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0 or a >= party.size() or b >= party.size():
		return false
	var tmp = party[a]
	party[a] = party[b]
	party[b] = tmp
	var ca = companions.get(a)
	var cb = companions.get(b)
	companions.erase(a)
	companions.erase(b)
	if cb != null:
		companions[a] = cb
	if ca != null:
		companions[b] = ca
	return true



func first_healthy(prefer_out: = true) -> int:
	if prefer_out:
		for i in party.size():
			if is_out(i) and party[i].hp > 0:
				return i
	for i in party.size():
		if party[i].hp > 0:
			return i
	return -1



func best_heal_item(missing: int) -> String:
	var best: = ""
	var best_amt: = 0
	for id in bag:
		if bag[id] <= 0:
			continue
		var e: Dictionary = ItemsData.item(id).get("effect", {})
		if not e.has("hp"):
			continue
		var amt: int = 9999 if str(e.hp) == "full" else int(e.hp)
		var better: = best == "" or (amt >= missing and (best_amt < missing or amt < best_amt)) or (best_amt < missing and amt > best_amt)
		if better:
			best = id
			best_amt = amt
	return best



func add_starter(sp_name: String, lv: int, m = null) -> RefCounted:
	if flags.get("starter_chosen", false):
		return null
	if m == null:
		m = MonScript.create(sp_name, lv)
	m.owner = "player"
	if m.met_level <= 0:
		m.met_level = m.level
	if m.met_zone == "":
		m.met_zone = SaveGame.location_name()
	party.append(m)
	flags["starter_chosen"] = true
	flags["starter_" + sp_name.to_lower()] = true
	return m


func heal_all() -> void :
	for i in party.size():
		party[i].heal_full()





const BOX_CAPACITY: = 30

const PARTY_CAPACITY: = 6



func healthy_count() -> int:
	var n: = 0
	for m in party:
		if m.hp > 0:
			n += 1
	return n




func deposit_to_box(i: int) -> Dictionary:
	if i < 0 or i >= party.size():
		return {"ok": false, "text": "There's nothing to deposit."}
	if is_out(i):
		return {"ok": false, "text": "%s is out of its ball. Recall it first." % party[i].display_name}
	if box.size() >= BOX_CAPACITY:
		return {"ok": false, "text": "The box is full!"}
	if party[i].hp > 0 and healthy_count() <= 1:
		return {"ok": false, "text": "You can't deposit your last Pokémon!"}
	var m = party[i]

	var rekeyed: = {}
	for k in companions:
		if k < i:
			rekeyed[k] = companions[k]
		elif k > i:
			rekeyed[k - 1] = companions[k]
	companions = rekeyed
	party.remove_at(i)
	m.heal_full()
	box.append(m)
	return {"ok": true, "text": "%s was stored in the box." % m.display_name}



func withdraw_from_box(j: int) -> Dictionary:
	if j < 0 or j >= box.size():
		return {"ok": false, "text": "There's nothing to withdraw."}
	if party.size() >= PARTY_CAPACITY:
		return {"ok": false, "text": "Your party is full!"}
	var m = box[j]
	box.remove_at(j)
	m.heal_full()
	party.append(m)
	return {"ok": true, "text": "%s joined your party." % m.display_name}





static func format_money(amount: int) -> String:
	return "₽%d" % amount



static func base_payout(trainer_class: String) -> int:
	return int(TRAINER_PAYOUTS.get(trainer_class, 16))



func trainer_payout(trainer_class: String, last_level: int) -> int:
	if reward_override >= 0:
		return reward_override
	return base_payout(trainer_class) * maxi(last_level, 1)





func mark_seen(sp_name: String) -> void :
	if sp_name == "":
		return
	var first: = not dex_seen.has(sp_name)
	dex_seen[sp_name] = true
	if first:
		Analytics.track("dex_new_species", {"species": sp_name, "kind": "seen", 
			"seen_total": dex_seen.size(), "caught_total": dex_caught.size()})



func mark_caught(sp_name: String) -> void :
	if sp_name == "":
		return
	var first: = not dex_caught.has(sp_name)
	dex_seen[sp_name] = true
	dex_caught[sp_name] = true
	if first:
		Analytics.track("dex_new_species", {"species": sp_name, "kind": "caught", 
			"seen_total": dex_seen.size(), "caught_total": dex_caught.size()})


func dex_seen_count() -> int:
	return dex_seen.size()


func dex_caught_count() -> int:
	return dex_caught.size()





func whiteout_loss() -> int:
	return floori(money / 2.0)



func whiteout() -> int:
	var loss: = whiteout_loss()
	money -= loss
	heal_all()
	return loss



func heal_point() -> Dictionary:
	return last_heal_point if not last_heal_point.is_empty() else HOME_HEAL_POINT



func is_home_heal_point() -> bool:
	return last_heal_point.is_empty() or bool(last_heal_point.get("home", false))




func ball_name(id: String) -> String:
	return Capture.ball(id).get("name", id)


func item_count(id: String) -> int:
	return int(bag.get(id, 0))


func add_item(id: String, n: = 1) -> void :
	bag[id] = item_count(id) + n
	print("[bag] +%d %s (now %d)" % [n, id, bag[id]])


func remove_item(id: String, n: = 1) -> bool:
	if item_count(id) < n:
		return false
	bag[id] = item_count(id) - n
	if bag[id] <= 0:
		bag.erase(id)
	return true



func item_targets_party(id: String) -> bool:
	var it: = ItemsData.item(id)
	var e: Dictionary = it.get("effect", {})
	return e.has("hp") or e.has("cure") or e.has("level")



func item_battle_usable(id: String) -> bool:
	if ItemsData.pocket_of(id) == "balls":
		return true
	var e: Dictionary = ItemsData.item(id).get("effect", {})
	return e.has("hp") or e.has("cure")


func set_quick_slot(k: int, id: String) -> void :
	if k < 0 or k >= 4:
		return
	var old: = quick_slots.find(id)
	if old >= 0 and old != k:
		quick_slots[old] = quick_slots[k]
	quick_slots[k] = id
