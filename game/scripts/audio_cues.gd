extends Node





const ZONE_MUSIC: = {
	"pallet_town": "music/pallet_town", 
	"route_1": "music/route_1", 
	"route_2": "music/route_1", 
	"route_2_north": "music/route_1", 
	"route_22": "music/route_1", 
	"viridian_city": "music/viridian", 
	"pewter_city": "music/viridian", 
	"viridian_forest": "music/viridian_forest", 
}
const ZONE_AMBIENCE: = {
	"pallet_town": "sfx/ambience/amb_town", 
	"route_1": "sfx/ambience/amb_route", 
	"viridian_city": "sfx/ambience/amb_town", 
	"pewter_city": "sfx/ambience/amb_town", 
}




const INTERIOR_MUSIC: = {
	"PokemonCenter": ["music/pokemon_center", "music/indoors"], 
	"PokeMart": ["music/poke_mart", "music/pokemon_center", "music/indoors"], 
	"PewterGym": ["music/pewter_gym", "music/viridian_forest"], 
}
const INTERIORS_DIR: = "res://scenes/interiors/"


const LAUNCH_SLOT: = {"fire": "sfx/moves/launch_fire", "water": "sfx/moves/launch_water", 
	"grass": "sfx/moves/launch_leaf", "flying": "sfx/moves/launch_wind"}




const MOVE_SFX: = {
	"bite": "sfx/moves/pack/bite", 
	"hyper_fang": "sfx/moves/pack/crunch", 
	"quick_attack": "sfx/moves/pack/quick-attack", 
	"pursuit": "sfx/moves/pack/quick-attack", 
	"flamethrower": "sfx/moves/pack/flamethrower", 
	"heat_wave": "sfx/moves/pack/flamethrower", 
	"thunder_shock": "sfx/moves/pack/thundershock", 
	"thunderbolt": "sfx/moves/pack/thundershock", 
	"thunder_wave": "sfx/moves/pack/thundershock", 
	"water_gun": "sfx/moves/pack/water-gun", 
	"bubble": "sfx/moves/pack/water-gun", 
	"mud_slap": "sfx/moves/pack/mud-shot", 
	"sand_attack": "sfx/moves/pack/mud-shot", 
	"wing_attack": "sfx/moves/pack/air-slash-release", 
	"aerial_ace": "sfx/moves/pack/air-slash-release", 
	"gust": "sfx/moves/pack/air-slash-release", 
	"peck": "sfx/moves/pack/air-slash-release", 
	"metal_claw": "sfx/moves/pack/dragon-claw", 
	"poison_sting": "sfx/moves/pack/acid", 
	"karate_chop": "sfx/moves/pack/shadow-punch-release", 
	"low_kick": "sfx/moves/pack/shadow-punch-release", 
	"double_kick": "sfx/moves/pack/shadow-punch-release", 
	"double_slap": "sfx/moves/pack/shadow-punch-release", 
	"submission": "sfx/moves/pack/shadow-punch-release", 
}

const ZoneStreamer: = preload("res://scripts/world/zone_streamer.gd")

var _poll_t: = 0.0
var _scene: Node
var _interior_area: = ""
var _outdoor_music: = ""
var _outdoor_ambience: = ""
var _low_hp_t: = 0.0


func _ready() -> void :
	var moves = get_node("/root/Moves")
	moves.move_used.connect(_on_move_used)
	moves.hit_landed.connect(_on_hit_landed)
	moves.move_missed.connect(_on_move_missed)


func _process(delta: float) -> void :
	_low_hp_t += delta
	if _low_hp_t >= 1.2:
		_low_hp_t = 0.0
		_low_hp_beep()
	_poll_t += delta
	if _poll_t < 0.25:
		return
	_poll_t = 0.0
	var scene: = get_tree().current_scene
	if scene != _scene:
		_scene = scene
		_enter_scene(scene)
	if scene and is_interiors_scene(scene.scene_file_path):
		_poll_interior(scene)



static func is_interiors_scene(path: String) -> bool:
	return path.begins_with(INTERIORS_DIR) and path.ends_with("_interiors.tscn")


func _enter_scene(scene: Node) -> void :
	_interior_area = ""
	if scene == null:
		return
	if is_interiors_scene(scene.scene_file_path):
		return
	var streamer: = _find_streamer(scene)
	if streamer:
		if not streamer.is_connected("zone_changed", _on_zone):
			streamer.connect("zone_changed", _on_zone)
		var active: String = streamer.get("active")
		if active != "":
			_on_zone(active)
		return

	Audio.set_area_music("", 1.0)
	Audio.set_ambience("")


func _find_streamer(scene: Node) -> Node:
	if scene.get_script() == ZoneStreamer:
		return scene
	for n in scene.find_children("*", "Node", true, false):
		if n.get_script() == ZoneStreamer:
			return n
	return null





func _on_zone(zone_id: String, _zone_name: = "") -> void :
	_outdoor_music = String(ZONE_MUSIC.get(zone_id, _outdoor_music))
	_outdoor_ambience = String(ZONE_AMBIENCE.get(zone_id, _outdoor_ambience))
	Audio.set_area_music(_outdoor_music)
	Audio.set_ambience(_outdoor_ambience)



func _move_slot(mv: Dictionary) -> String:
	var t: String = String(mv.get("type", ""))
	match String(mv.get("kind", "")):
		"dash":
			return "sfx/moves/dash"
		"arc":
			return "sfx/moves/bite" if String(mv.get("id", "")) == "bite" else "sfx/moves/slash"
		"whip":
			return "sfx/moves/slash"
		"multi_arc":
			return "sfx/moves/multi_slash"
		"projectile", "homing":
			return String(LAUNCH_SLOT.get(t, "sfx/moves/launch_star"))
		"stream":
			return "sfx/moves/stream_fire" if t == "fire" else String(LAUNCH_SLOT.get(t, "sfx/moves/launch_star"))
		"beam":
			return "sfx/moves/beam_charge"
		"aoe_self":
			return "sfx/moves/rumble"
		"aoe_target":
			return "sfx/moves/thunder" if t == "electric" else "sfx/moves/rumble"
		"zone":
			return "sfx/moves/powder"
		"clones":
			return "sfx/moves/shimmer"
		_:
			return ""


func _on_move_used(user, mv: Dictionary) -> void :
	var id: = String(mv.get("id", ""))
	if MOVE_SFX.has(id):
		Audio.play_at(String(MOVE_SFX[id]), user.global_position)
		return
	if id == "growl":
		Audio.cry(user.species, user.global_position)
		return
	if id == "string_shot":
		Audio.play_at("sfx/moves/launch_wind", user.global_position, 0.0, 1.8)
		return
	var slot: String = _move_slot(mv)
	if slot != "":
		Audio.play_at(slot, user.global_position)


func _on_hit_landed(user, target, info: Dictionary) -> void :
	var dmg: int = int(info.get("damage", 0))
	var eff: float = float(info.get("eff", 1.0))
	if dmg <= 0 and eff != 0.0:
		return
	var slot: String
	if eff == 0.0:
		slot = "sfx/battle/no_effect"
	elif bool(info.get("crit", false)):
		slot = "sfx/battle/hit_crit"
	elif eff > 1.0:
		slot = "sfx/battle/hit_super"
	elif eff < 1.0:
		slot = "sfx/battle/hit_weak"
	else:
		slot = "sfx/battle/hit_normal"
	Audio.play_at(slot, target.global_position)


func _on_move_missed(user, target, mv: Dictionary) -> void :
	var pos: Vector3 = target.global_position if is_instance_valid(target) else user.global_position
	Audio.play_at("sfx/battle/miss", pos)



func _low_hp_beep() -> void :
	var g = get_node("/root/Battle")
	if not g.in_battle or g._intro:
		return
	var p = g.partner
	if is_instance_valid(p) and p.alive() and p.hp > 0 and p.hp <= p.max_hp * 0.2:
		Audio.ui("sfx/ui/low_hp")




func _interior_slot(b: Node) -> String:
	var chain = INTERIOR_MUSIC.get(String(b.name))
	if chain is Array:
		return Audio.resolve(chain)
	return String(b.get_meta("music", "music/indoors"))




func snap_interior() -> void :
	var scene: = get_tree().current_scene
	if scene and is_interiors_scene(scene.scene_file_path):
		_poll_interior(scene)


func _poll_interior(scene: Node) -> void :
	var p: = get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var pos: = Vector2(p.global_position.x, p.global_position.z)
	var area: = ""
	for b in scene.get_children():
		var room: = b.get_node_or_null("Room") as Node3D
		if room == null:
			continue
		var size = room.get("size")
		if size == null:
			continue
		var r: = Rect2(Vector2(room.global_position.x, room.global_position.z) - size * 0.5, size)
		if r.has_point(pos):
			area = _interior_slot(b)
			break
	if area == "" or area == _interior_area:
		return
	_interior_area = area
	Audio.set_area_music(area)
	Audio.set_ambience("sfx/ambience/amb_indoors")
