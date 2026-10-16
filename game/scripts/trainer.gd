extends "res://scripts/npc.gd"




const Trainers: = preload("res://scripts/trainers.gd")
const MonScript: = preload("res://scripts/stats/mon.gd")


const SIGHT_BLOCK_LAYERS: = 1 | 2

const SIGHT_HALF: = 0.9

const STOP_SHORT: = 1.2
const ROW_VEC: = [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)]


@export var trainer_id: = ""

@export var sight: = 5.0

var _def: = {}
var _alert: Label3D
var _spot_home: = Vector3.ZERO
var _spot_facing: = 0
var _spotting: = false
var _sight_cd: = 0.0


func _ready() -> void :
	super._ready()
	if not is_inside_tree():
		return
	_def = Trainers.get_def(trainer_id)
	if not _def.is_empty():
		if not _armed():
			queue_free()
			return
		npc_name = Trainers.display_name(trainer_id)
		lines = PackedStringArray(_def.get("intro", []))
		if sight <= 0.0:
			sight = float(_def.get("sight", 5.0))
	_spot_home = global_position
	_spot_facing = start_facing
	_alert = Label3D.new()
	_alert.name = "Alert"
	_alert.text = "!"
	_alert.font_size = 96
	_alert.outline_size = 18
	_alert.modulate = Color(1.0, 0.85, 0.2)
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.no_depth_test = true


	var frame_h: = 0.0
	if sprite.texture:
		frame_h = float(sprite.texture.get_height()) / float(maxi(sprite.vframes, 1)) * sprite.pixel_size * 0.6
	_alert.position = Vector3(0, frame_h + 0.4, 0)
	_alert.visible = false
	add_child(_alert)


func _physics_process(delta: float) -> void :
	super._physics_process(delta)
	if _sight_cd > 0.0:
		_sight_cd -= delta
	if _walk_target != null:
		return
	var p: = Dialogue.player()
	if p != null and can_see(p):
		_spot_sequence()






func can_see(p: Node3D) -> bool:
	if _def.is_empty() or _spotting or talking or _beaten():
		return false
	if _sight_cd > 0.0 or Game.is_busy() or Battle.in_battle or Game.cutscene:
		return false
	if Game.state.first_healthy() < 0:
		return false
	return _in_corridor(p) and _sight_clear(p)


func _in_corridor(p: Node3D) -> bool:
	var f: Vector3 = ROW_VEC[row]
	var to: Vector3 = p.global_position - global_position
	to.y = 0.0
	var along: = to.dot(f)
	if along <= 0.0 or along > sight:
		return false
	return absf(to.dot(Vector3( - f.z, 0.0, f.x))) <= SIGHT_HALF


func _sight_clear(p: Node3D) -> bool:
	var world: = get_viewport().world_3d if get_viewport() else null
	if world == null:
		return true
	var q: = PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 1.0, 0), p.global_position + Vector3(0, 1.0, 0), SIGHT_BLOCK_LAYERS)
	var ex: Array[RID] = [get_rid()]
	if p is CollisionObject3D:
		ex.append(p.get_rid())
	q.exclude = ex
	return world.direct_space_state.intersect_ray(q).is_empty()


func _beaten() -> bool:
	return trainer_id != "" and Game.flags.get("trainer_%s" % trainer_id, false)






func _spot_sequence() -> void :
	if _spotting:
		return
	_spotting = true
	var p: = Dialogue.player()
	if p == null:
		_spotting = false
		return
	Game.cutscene = true
	p.controls_enabled = false
	p.velocity = Vector3.ZERO
	p.face_toward(global_position)
	face(p.global_position - global_position)
	_alert.visible = true

	Audio.jingle(Audio.resolve(["music/eyes_meet", "music/encounter"]))
	await get_tree().create_timer(0.7).timeout
	_alert.visible = false
	var to: Vector3 = p.global_position - global_position
	to.y = 0.0
	if to.length() > STOP_SHORT:
		await walk_to(global_position + to.normalized() * (to.length() - STOP_SHORT), 6.0)
	face(p.global_position - global_position)
	await _battle_sequence(true)



func talk_to(p: Node3D) -> PackedStringArray:
	talking = true
	face(p.global_position - global_position)
	if _beaten():
		return PackedStringArray(_def.get("after", ["..."]))
	return lines



func finish_talk() -> void :
	talking = false
	if _beaten() or _spotting:
		return
	await _battle_sequence(false)


func _battle_sequence(show_intro: bool) -> void :
	var p: = Dialogue.player()
	if p == null or _beaten():
		return
	Game.cutscene = true
	p.controls_enabled = false
	var hud: = Game.get_hud()
	if show_intro and hud:
		hud.open_dialog(npc_name, lines)
		await hud.dialog_closed
	var scripted: = bool(_def.get("scripted", false))
	if _def.has("reward"):
		Game.state.reward_override = int(_def["reward"])
	var result: String = await Battle.start_trainer_battle(self, npc_name, _mons(), _battle_opts(p))
	Game.state.reward_override = -1
	if result == "lost" and not scripted:

		return
	if result == "won":
		Game.flags["trainer_%s" % trainer_id] = true
		if not _def.get("defeat", []).is_empty():
			await _say(hud, _def.get("defeat", []))
		if _def.has("badge"):
			await _award_badge(hud, String(_def["badge"]))
	elif not _def.get("lose", []).is_empty():
		await _say(hud, _def.get("lose", []))
	if _def.has("done_flag"):
		Game.flags[String(_def["done_flag"])] = true
	if result == "won" and _def.has("won_flag"):
		Game.flags[String(_def["won_flag"])] = true
	if bool(_def.get("leave_after", false)):
		await _leave_and_free()
		return
	if result == "aborted":
		_sight_cd = 2.0
	await _return_home()
	_spotting = false
	Game.cutscene = false
	var np: = Dialogue.player()
	if np:
		np.controls_enabled = true




func _battle_opts(_p: Node3D) -> Dictionary:
	var opts: = {"trainer_class": String(_def.get("class", ""))}


	var marker: = String(_def.get("center", ""))
	if marker != "":
		var sc: = get_tree().current_scene
		var m: Node = sc.find_child(marker, true, false) if sc else null
		if m is Node3D:
			opts["center"] = (m as Node3D).global_position
	var ar = _def.get("arena")
	if ar is Array and ar.size() >= 2:
		opts["arena"] = Vector2(float(ar[0]), float(ar[1]))
	if _def.has("ai_think_scale"):
		opts["ai_think_scale"] = float(_def["ai_think_scale"])
	if _def.has("item"):
		opts["item"] = String(_def["item"])
	if _def.has("arena_color"):

		opts["arena_color"] = Color(String(_def["arena_color"]))
	if bool(_def.get("scripted", false)):
		opts["scripted"] = true
	if _def.has("lose"):

		opts["lose"] = _def.get("lose", [])
	if _def.has("intro_text"):
		opts["intro_text"] = String(_def["intro_text"])
	return opts



func _say(hud, lines) -> void :
	if hud == null:
		return
	hud.open_dialog(npc_name, PackedStringArray(lines))
	await hud.dialog_closed




func _award_badge(hud, badge: String) -> void :
	if not Game.state.badges.has(badge):
		Game.state.badges.append(badge)
	Game.flags["%s_badge" % badge] = true
	Audio.jingle("music/badge_get")
	var nm: = String(_def.get("name", npc_name)).to_upper()
	await _say(hud, ["%s received the %s BADGE from %s!" % [Game.state.player_name, badge.to_upper(), nm]])

	if not _def.get("badge_speech", []).is_empty():
		await _say(hud, _def.get("badge_speech", []))




func _leave_and_free() -> void :
	_spotting = false
	Game.cutscene = false
	var np: = Dialogue.player()
	if np:
		np.controls_enabled = true
	var to = _def.get("leave_to")
	if to is Array and to.size() >= 2:
		await walk_to(Vector3(float(to[0]), global_position.y, float(to[1])), 10.0)
	queue_free()



func _armed() -> bool:
	var rq: = String(_def.get("requires_flag", ""))
	if rq != "" and not Game.flags.get(rq, false):
		return false
	var hd: = String(_def.get("hidden_by_flag", ""))
	return hd == "" or not Game.flags.get(hd, false)


func _return_home() -> void :
	if global_position.distance_to(_spot_home) > 0.2:
		await walk_to(_spot_home, 8.0)
	row = _spot_facing
	if is_instance_valid(sprite):
		sprite.frame = row * 3




func _mons() -> Array:
	var out: Array = []
	for e in _def.get("party", []):
		if e is Array and e.size() >= 2:
			var sp: = String(e[0])
			if sp.begins_with("@"):
				sp = String(Game.flags.get(sp.substr(1), ""))
			if sp == "":
				continue
			var m = MonScript.create(sp, int(e[1]))
			m.owner = npc_name
			out.append(m)
	return out
