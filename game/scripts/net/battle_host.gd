class_name BattleHost
extends Node









const BattleProtoScript: = preload("res://scripts/net/battle_proto.gd")
const CreatureDef: = preload("res://scripts/creature.gd")
const MonScript: = preload("res://scripts/stats/mon.gd")
const NpcScene: = preload("res://scenes/npc.tscn")

var net: Node
var peer_name: = ""

var _saved: Array = []
var _npc: Node3D
var _wild_body: Node = null
var _center: = Vector3.ZERO
var _arena: = Vector2(12, 8)
var _sent_go: = false
var _snap_t: = 0.0
var _last_seq: = -1
var _partner_id: = 0
var _wild_id: = 0
var _partner_seen: = false
var _wild_seen: = false


func _ready() -> void :
	add_to_group("online_battle_engine")




func run(net_: Node, my_team: Array, their_team: Array, center: Vector3, peer_name_: String) -> String:
	net = net_
	peer_name = peer_name_
	_center = center

	_saved = Game.party.map( func(m): return m.to_dict())
	for k in Game.companions.keys().duplicate():
		if Game.is_out(k):
			Game.recall(k)
	Game.state.party = my_team.map( func(d):
		var m = MonScript.from_dict(d)
		m.heal_full()
		return m)
	Game.party_changed.emit()
	var their_mons: Array = their_team.map( func(d):
		var m = MonScript.from_dict(d)
		m.heal_full()
		return m)

	_npc = NpcScene.instantiate()
	_npc.npc_name = peer_name
	_npc.wander_radius = 0.0
	_npc.scripted = true
	var parent: Node = Dialogue.player().get_parent() if Dialogue.player() != null else get_parent()
	parent.add_child(_npc)
	_npc.global_position = _center + Vector3(2.0, 0.0, 0.0)

	net.rt.connect(_on_rt)
	net.message.connect(_on_message)
	net.closed.connect(_on_closed)
	var moves: = get_node("/root/Moves")
	moves.move_released.connect(_on_move_released)
	moves.hit_landed.connect(_on_hit_landed)
	moves.move_missed.connect(_on_move_missed)

	var res: String = await Battle.start_trainer_battle(_npc, peer_name, their_mons, 
		{"online": true, "center": _center, "arena": _arena, "scripted": true, 
			"intro_text": "%s wants to battle!" % peer_name})

	net.send({"t": "be", "k": "end", "winner": _winner_side(res)})
	_cleanup()
	return res



func forfeit() -> void :
	if Battle.in_battle and Battle.online:
		Battle.end_battle("lost")



func _process(delta: float) -> void :
	if not Battle.online or not Battle.in_battle:
		return
	if not _sent_go:
		_send_go()
	_snap_t += delta
	if _snap_t >= 1.0 / float(BattleProtoScript.SNAP_HZ):
		_snap_t = 0.0
		_send_snap()
	_check_sides()





func _send_go() -> void :
	var p: = Dialogue.player()
	if p == null or not is_instance_valid(_npc):
		return
	_sent_go = true
	var tb: Dictionary = Battle.trainer_battle
	var c: Vector3 = tb.get("center", _center)
	var a: Vector2 = tb.get("arena", _arena)
	var host_spot: = Vector2(p.global_position.x, p.global_position.z)
	var guest_spot: = Vector2(_npc.global_position.x, _npc.global_position.z)
	net.send({"t": "bt_go", "center": [c.x, c.y, c.z], "arena": [a.x, a.y], 
		"host_spot": [host_spot.x, host_spot.y], "guest_spot": [guest_spot.x, guest_spot.y]})
	net.send({"t": "be", "k": "banner", "text": "%s wants to battle!" % peer_name})


func _send_snap() -> void :
	net.send_rt([BattleProtoScript.RT_SNAP, Time.get_ticks_msec(), 
		BattleProtoScript.snap_fighter(Battle.partner, BattleProtoScript.SIDE_HOST), 
		BattleProtoScript.snap_fighter(Battle.wild, BattleProtoScript.SIDE_GUEST)])




func _check_sides() -> void :
	var p = Battle.partner
	if is_instance_valid(p):
		if not _partner_seen:
			_partner_seen = true
			_partner_id = p.get_instance_id()
			_watch(p)
		elif p.get_instance_id() != _partner_id:
			_partner_id = p.get_instance_id()
			_watch(p)
			_send_mon(BattleProtoScript.SIDE_HOST, Game.party.find(p.mon), p.mon)
	var w = Battle.wild
	if is_instance_valid(w):
		_wild_body = w
		if not _wild_seen:
			_wild_seen = true
			_wild_id = w.get_instance_id()
			_watch(w)
		elif w.get_instance_id() != _wild_id:
			_wild_id = w.get_instance_id()
			_watch(w)
			_send_mon(BattleProtoScript.SIDE_GUEST, int(Battle.trainer_battle.get("index", 0)), w.mon)


func _send_mon(side: int, slot: int, mon) -> void :
	var d: Dictionary = mon.to_dict() if mon != null else {}
	net.send({"t": "be", "k": "send", "side": side, "slot": slot, "mon": d})
	var who: = String(d.get("species", "?"))
	var text: = "Go, %s!" % who
	if side == BattleProtoScript.SIDE_GUEST:
		text = "%s is about to send out %s!" % [peer_name, who]
	net.send({"t": "be", "k": "banner", "text": text})




func _watch(c) -> void :
	if c != null and is_instance_valid(c) and not c.fainted.is_connected(_on_fainted_event):
		c.fainted.connect(_on_fainted_event)


func _on_fainted_event(c) -> void :
	if _active() and is_instance_valid(c):
		net.send({"t": "be", "k": "faint", "side": _side_of(c)})




func _on_rt(arr: Array) -> void :
	if arr.size() < 5 or int(arr[0]) != BattleProtoScript.RT_INPUT:
		return
	var seq: = int(arr[1])
	if seq <= _last_seq:
		return
	_last_seq = seq
	var w = Battle.wild
	if not is_instance_valid(w) or w.mode != CreatureDef.Mode.REMOTE:
		return
	var it: Dictionary = w.combat.remote_intent

	it["move"] = BattleProtoScript.mirror_stick(Vector2(float(arr[2]), float(arr[3])))
	it["sprint"] = bool(arr[4])


func _on_message(msg: Dictionary) -> void :
	var t: = String(msg.get("t", ""))
	if t == "bt_forfeit":
		if Battle.in_battle and Battle.online:
			Battle.end_battle("won")
		return
	if t != "bi" or not Battle.in_battle or not Battle.online:
		return
	match String(msg.get("k", "")):
		"move":
			_set_edge("slot", int(msg.get("slot", -1)))
		"jump":
			_set_edge("jump", true)
		"switch":
			Battle.switch_foe(int(msg.get("slot", -1)))


func _set_edge(key: String, value) -> void :
	var w = Battle.wild
	if not is_instance_valid(w) or w.mode != CreatureDef.Mode.REMOTE:
		return
	w.combat.remote_intent[key] = value


func _on_closed(_reason: String) -> void :
	if Battle.in_battle and Battle.online:
		Battle.end_battle("aborted")




func _on_move_released(user, move) -> void :
	if not _active() or not is_instance_valid(user):
		return
	var f: Vector3 = user.facing
	net.send({"t": "be", "k": "move", "side": _side_of(user), "id": String(move.get("id", "")), 
		"dir": [f.x, f.z]})


func _on_hit_landed(_user, target, info: Dictionary) -> void :
	if not _active() or not is_instance_valid(target):
		return
	net.send({"t": "be", "k": "hit", "side": _side_of(target), "dmg": int(info.get("damage", 0)), 
		"eff": float(info.get("eff", 1.0)), "crit": bool(info.get("crit", false)), 
		"status": String(info.get("status", ""))})


func _on_move_missed(user, _target, _move) -> void :
	if _active() and is_instance_valid(user):
		net.send({"t": "be", "k": "miss", "side": _side_of(user)})


func _active() -> bool:
	return net != null and Battle.online and Battle.in_battle



func _side_of(c) -> int:
	return BattleProtoScript.SIDE_HOST if int(c.side) == 0 else BattleProtoScript.SIDE_GUEST


func _winner_side(res: String) -> int:
	if res == "won":
		return BattleProtoScript.SIDE_HOST
	if res == "lost":
		return BattleProtoScript.SIDE_GUEST
	return -1




func _cleanup() -> void :
	set_process(false)
	var moves: = get_node_or_null("/root/Moves")
	if moves != null:
		if moves.move_released.is_connected(_on_move_released):
			moves.move_released.disconnect(_on_move_released)
		if moves.hit_landed.is_connected(_on_hit_landed):
			moves.hit_landed.disconnect(_on_hit_landed)
		if moves.move_missed.is_connected(_on_move_missed):
			moves.move_missed.disconnect(_on_move_missed)
	if net != null:
		if net.rt.is_connected(_on_rt):
			net.rt.disconnect(_on_rt)
		if net.message.is_connected(_on_message):
			net.message.disconnect(_on_message)
		if net.closed.is_connected(_on_closed):
			net.closed.disconnect(_on_closed)

	for k in Game.companions.keys().duplicate():
		if Game.is_out(k):
			Game.recall(k)
	if is_instance_valid(_wild_body):
		_wild_body.queue_free()
	_wild_body = null
	if is_instance_valid(_npc):
		_npc.queue_free()
	_npc = null
	Game.state.party = _saved.map( func(d): return MonScript.from_dict(d))
	Game.party_changed.emit()
	net = null
