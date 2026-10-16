extends RefCounted




static var _species: = {}
static var _moves: = {}
static var _move_order: Array = []
static var _types: = {}
static var _abilities: = {}
static var _loaded: = false


static func _load_json(path: String) -> Variant:
	var f: = FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else null


static func _ensure() -> void :
	if _loaded:
		return
	_loaded = true
	var s = _load_json("res://data/species.json")
	_species = s if s is Dictionary else {}
	_species.erase("_doc")
	var m = _load_json("res://data/moves.json")
	if m is Dictionary:
		for mv in m.get("moves", []):
			_moves[mv.id] = mv
			_move_order.append(mv.id)
	var t = _load_json("res://data/types.json")
	_types = t if t is Dictionary else {}
	var a = _load_json("res://data/abilities.json")
	_abilities = a if a is Dictionary else {}
	_abilities.erase("_doc")


static func species(name: String) -> Dictionary:
	_ensure()
	return _species.get(name, {})





static func jump_height(name: String) -> float:
	var sp: = species(name)
	if sp.has("jump_height_override"):
		return float(sp.get("jump_height_override", 0.0))
	return float(sp.get("jump_height", 0.9))




static func locomotion(name: String) -> String:
	return String(species(name).get("locomotion", "ground"))





static func whip_reach(species_name: String, mv: Dictionary) -> float:
	var w: Dictionary = species(species_name).get("whip", {})
	return float(w.get("reach", mv.get("range", 4.0)))




static func whip_tips(species_name: String, mv: Dictionary) -> int:
	var w: Dictionary = species(species_name).get("whip", {})
	return int(w.get("tips", mv.get("tips", 1)))




static func fly_height(name: String) -> float:
	var sp: = species(name)
	if sp.has("fly_height_override"):
		return float(sp.get("fly_height_override", 0.0))
	return float(sp.get("fly_height", 0.0))




static func moves_at(species_name: String, level: int) -> Array:
	var sp: = species(species_name)
	var learned: Array = []
	for e in sp.get("learnset", []):
		if int(e[0]) <= level and not learned.has(e[1]) and _moves.has(e[1]):
			learned.append(e[1])
	if learned.is_empty():
		return sp.get("moves", []).duplicate()
	return learned.slice(maxi(learned.size() - 4, 0))


static func all_species() -> Array:
	_ensure()
	return _species.keys()


static func move(id: String) -> Dictionary:
	_ensure()
	return _moves.get(id, {})



static func ability(id: String) -> Dictionary:
	_ensure()
	return _abilities.get(id, {})


static func all_moves() -> Array:
	_ensure()
	return _move_order


static func all_types() -> Array:
	_ensure()
	return _types.get("colors", {}).keys()


static func type_color(t: String) -> Color:
	_ensure()
	var c: Array = _types.get("colors", {}).get(t, [1, 1, 1])
	return Color(c[0], c[1], c[2])



static func effectiveness(atk_type: String, def_types: Array) -> float:
	_ensure()
	var row: Dictionary = _types.get("chart", {}).get(atk_type, {})
	var m: = 1.0
	for t in def_types:
		m *= float(row.get(t, 1.0))
	return m



const PP_POOL_REF: = 100.0





static func pp_cost(mv: Dictionary) -> float:
	if mv.has("pp_cost"):
		return float(mv.pp_cost)
	if mv.has("uses"):
		return PP_POOL_REF / maxf(1.0, float(mv.uses))
	if mv.get("category", "") == "status":
		return 3.0
	var total: = float(mv.get("power", 0)) * maxf(1.0, float(mv.get("count", 1))) * maxf(1.0, float(mv.get("hits", 1)))
	if mv.get("kind", "") == "stream":
		total *= maxf(1.0, float(mv.get("duration", 1.0)) / float(mv.get("tick", 0.15)))
	return clampf(ceilf(total / 20.0), 1.0, 12.0)




const FATIGUE_ANCHORS: = [[5.0, 50.0], [10.0, 35.0], [40.0, 10.0]]




static func fatigue_for_uses(uses: float) -> float:
	var u: = maxf(1.0, uses)
	if u <= float(FATIGUE_ANCHORS[0][0]):
		return float(FATIGUE_ANCHORS[0][1])
	for i in range(1, FATIGUE_ANCHORS.size()):
		var lo: Array = FATIGUE_ANCHORS[i - 1]
		var hi: Array = FATIGUE_ANCHORS[i]
		if u <= float(hi[0]):
			var t: = (log(u) - log(float(lo[0]))) / (log(float(hi[0])) - log(float(lo[0])))
			return lerpf(float(lo[1]), float(hi[1]), t)
	return float(FATIGUE_ANCHORS[-1][1])




static func fatigue(mv: Dictionary) -> float:
	if mv.has("fatigue"):
		return float(mv.fatigue)
	if mv.has("uses"):
		return fatigue_for_uses(float(mv.uses))
	return pp_cost(mv) * 10.0











const COOLDOWN_SCALE: = 2.5
const MIN_COOLDOWN: = 1.6
const MIN_STATUS_COOLDOWN: = 3.0
const STAT_MOVE_COOLDOWN_MULT: = 2.5

const GLOBAL_COOLDOWN: = 1.0




const PREPARE_BY_KIND: = {
	"dash": 0.18, 
	"arc": 0.15, "multi_arc": 0.15, "whip": 0.15, 
	"projectile": 0.15, "homing": 0.15, 
	"stream": 0.2, 
	"self_buff": 0.2, "debuff_aoe": 0.2, "clones": 0.2, "zone": 0.2, 
}



static func prepare_time(mv: Dictionary) -> float:
	var kind: = String(mv.get("kind", ""))
	if kind in ["beam", "aoe_self", "aoe_target"]:
		return 0.0
	if mv.has("windup"):
		return float(mv.windup)
	return float(PREPARE_BY_KIND.get(kind, 0.15))



static func _cooldown_weight(mv: Dictionary) -> float:
	if mv.has("fatigue"):
		return float(mv.fatigue)
	return pp_cost(mv) * 10.0


static func cooldown(mv: Dictionary) -> float:
	if mv.has("cooldown"):
		return maxf(float(mv.cooldown), MIN_COOLDOWN)
	var cd: = (float(mv.get("windup", 0.0)) + float(mv.get("duration", 0.0)) + _cooldown_weight(mv) / 40.0) * COOLDOWN_SCALE
	cd = maxf(cd, MIN_STATUS_COOLDOWN if mv.get("category", "") == "status" else MIN_COOLDOWN)
	if is_stat_move(mv):
		cd *= STAT_MOVE_COOLDOWN_MULT
	return snappedf(cd, 0.1)



static func is_stat_move(mv: Dictionary) -> bool:
	if float(mv.get("power", 0)) > 0.0:
		return false
	if String(mv.get("kind", "")) in ["self_buff", "debuff_aoe"]:
		return true
	var fx: Dictionary = mv.get("effect", {})
	return fx.has("stat") and not fx.has("status")
