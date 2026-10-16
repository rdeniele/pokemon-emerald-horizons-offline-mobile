class_name BattleGuest
extends Node










const CreatureDef: = preload("res://scripts/creature.gd")
const BattleArena: = preload("res://scripts/battle_arena.gd")
const MonScript: = preload("res://scripts/stats/mon.gd")


const GO_TIMEOUT: = 15.0

const SNAP_TIMEOUT: = 15.0

const SNAP_BUFFER: = 1.0

var go_timeout: = GO_TIMEOUT

var _net
var _my_team: Array = []
var _their_team: Array = []
var _peer: = ""
var _go: Dictionary = {}
var _active: = false
var _result: = ""
var _closed: = ""
var _center: = Vector3.ZERO
var _arena_size: = Vector2(12, 8)
var _mine: Node3D = null
var _theirs: Node3D = null
var _npc: Node3D = null
var _arena: Node3D = null
var _snaps: Array = []
var _last_snap_ms: = 0
var _last_input_ms: = 0
var _seq: = 0
var _music: = false
var _touched_player: = false
var _player_controls: = true




func run(net, my_team: Array, their_team: Array, peer_name: String) -> String:
	add_to_group("online_battle_engine")
	_net = net
	_my_team = my_team
	_their_team = their_team
	_peer = peer_name
	if _net != null:
		_net.message.connect(_on_message)
		_net.rt.connect(_on_rt)
		_net.closed.connect(_on_closed)
	var t0: = Time.get_ticks_msec()
	var limit: = int(maxf(go_timeout, 0.05) * 1000.0)
	while _go.is_empty() and _closed == "" and Time.get_ticks_msec() - t0 < limit:
		await get_tree().process_frame
	if _go.is_empty():
		_cleanup()
		return "aborted"
	_setup()
	while _result == "":
		if _closed != "":
			_result = "aborted"
			break
		if Time.get_ticks_msec() - _last_snap_ms > int(SNAP_TIMEOUT * 1000.0):
			_result = "aborted"
			break
		await get_tree().process_frame
	_cleanup()
	return _result



func forfeit() -> void :
	if _net != null:
		_net.send({"t": "bt_forfeit"})



func request_switch(slot: int) -> void :
	if _active and _net != null:
		_net.send({"t": "bi", "k": "switch", "slot": slot})




func _on_message(msg: Dictionary) -> void :
	var t: = String(msg.get("t", ""))
	if t == "bt_go":
		_go = msg
		return
	if t == "be" and _active:
		_event(msg)


func _on_rt(arr: Array) -> void :
	if not _active or arr.is_empty() or int(arr[0]) != BattleProto.RT_SNAP:
		return
	var f0 = arr[2] if arr.size() > 2 else {}
	var f1 = arr[3] if arr.size() > 3 else {}
	_snaps.append({"t": _now(), "f0": f0 if f0 is Dictionary else {}, "f1": f1 if f1 is Dictionary else {}})
	_last_snap_ms = Time.get_ticks_msec()
	var cut: = _now() - SNAP_BUFFER
	while not _snaps.is_empty() and float(_snaps[0].t) < cut:
		_snaps.pop_front()


func _on_closed(reason: String) -> void :
	_closed = reason




func _setup() -> void :
	_center = BattleProto.v3(_go.get("center", []))
	_arena_size = BattleProto.v2(_go.get("arena", [12.0, 8.0]))
	var host_spot: = _xz(_go.get("host_spot", []))
	var guest_spot: = _xz(_go.get("guest_spot", []))
	var my_at: = BattleProto.mirror(guest_spot, _center)
	var their_at: = BattleProto.mirror(host_spot, _center)
	var p: = Dialogue.player()
	var parent: Node = p.get_parent() if p != null else get_tree().current_scene
	if p != null:
		_touched_player = true
		_player_controls = p.controls_enabled
		p.controls_enabled = false
		p.global_position = _on_ground(my_at)
		if p.has_method("face_toward"):
			p.face_toward(_center)
	_npc = load("res://scenes/npc.tscn").instantiate()
	_npc.npc_name = _peer
	_npc.wander_radius = 0.0
	_npc.scripted = true
	parent.add_child(_npc)
	_npc.global_position = _on_ground(their_at)
	_npc.face((_center - _npc.global_position).normalized())
	_arena = BattleArena.new()
	parent.add_child(_arena)
	_arena.setup(_center, _arena_size, BattleArena.COLOR)
	var cam: = Dialogue.camera_rig()
	if cam:
		cam.focus_fixed(_center, Battle._battle_cam_dist())
	Audio.push_music("battle", "music/battle_trainer", 0.2)
	_music = true
	_spawn_puppet(BattleProto.SIDE_GUEST, _team_mon(_my_team, 0), my_at)
	_spawn_puppet(BattleProto.SIDE_HOST, _team_mon(_their_team, 0), their_at)
	Battle.online_guest = true
	Battle.in_battle = true
	Battle._intro = false
	Battle.partner = _mine
	Battle.allies = [_mine]
	Battle.wild = _theirs
	Battle.trainer_battle = {"name": _peer, "center": _center, "arena": _arena_size, 
		"mons": _their_team, "index": 0, "total": maxi(_their_team.size(), 1), "fainted": 0, "class": ""}
	_last_snap_ms = Time.get_ticks_msec()
	_last_input_ms = 0
	_seq = 0
	_active = true






func _process(_delta: float) -> void :
	if not _active or _snaps.is_empty():
		return
	var t: = _now() - BattleProto.INTERP_DELAY
	var old: Dictionary = _snaps[0]
	var new: Dictionary = _snaps[0]
	for i in range(_snaps.size() - 1, -1, -1):
		if float(_snaps[i].t) <= t:
			old = _snaps[i]
			new = _snaps[i + 1] if i + 1 < _snaps.size() else _snaps[i]
			break
	var a: = 0.0
	var span: = float(new.t) - float(old.t)
	if span > 0.0001:
		a = clampf((t - float(old.t)) / span, 0.0, 1.0)
	_draw_puppet(BattleProto.SIDE_GUEST, old.get("f1", {}), new.get("f1", {}), a)
	_draw_puppet(BattleProto.SIDE_HOST, old.get("f0", {}), new.get("f0", {}), a)


func _draw_puppet(side: int, d_old: Dictionary, d_new: Dictionary, a: float) -> void :
	if d_new.is_empty():
		return
	var c: Node3D = _puppet(side)
	if not is_instance_valid(c):
		return
	var pos_new: = _vec3(d_new, "pos", c.global_position)
	var pos_old: = _vec3(d_old, "pos", pos_new)
	c.global_position = BattleProto.mirror(pos_old.lerp(pos_new, a), _center)
	if d_new.has("vel"):
		c.velocity = BattleProto.mirror_dir(_vec3(d_old, "vel", _vec3(d_new, "vel", Vector3.ZERO)).lerp(_vec3(d_new, "vel", Vector3.ZERO), a))
	if d_new.has("facing"):
		var f: = _vec3(d_old, "facing", _vec3(d_new, "facing", Vector3.FORWARD)).lerp(_vec3(d_new, "facing", Vector3.FORWARD), a)
		if f.length() > 0.01:
			c.facing = BattleProto.mirror_dir(f.normalized())
	BattleProto.apply_fighter(c, d_new)




func _physics_process(_delta: float) -> void :
	if not _active or _result != "" or _net == null:
		return
	var t: = Time.get_ticks_msec()
	if t - _last_input_ms >= int(1000.0 / BattleProto.INPUT_HZ):
		_last_input_ms = t
		_seq += 1
		var move: = BattleProto.mirror_stick(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
		_net.send_rt([BattleProto.RT_INPUT, _seq, move.x, move.y, Input.is_action_pressed("sprint")])
	if Input.is_action_just_pressed("jump"):
		_net.send({"t": "bi", "k": "jump"})
	if not Controls.items_page_held():
		for i in 4:
			if Input.is_action_just_pressed("move_%d" % (i + 1)):
				_net.send({"t": "bi", "k": "move", "slot": i})




func _event(msg: Dictionary) -> void :
	match String(msg.get("k", "")):
		"move":
			var id: = String(msg.get("id", ""))
			var d: = BattleProto.v2(msg.get("dir", []))
			var user: = _puppet(int(msg.get("side", BattleProto.SIDE_HOST)))
			if id != "" and is_instance_valid(user):
				_moves().replay(user, id, BattleProto.mirror_dir(Vector3(d.x, 0.0, d.y)))
		"hit":
			_hit_fx(int(msg.get("side", 0)), int(msg.get("dmg", 0)), 
				float(msg.get("eff", 1.0)), bool(msg.get("crit", false)))
		"miss":
			var target: = _puppet(_other_side(int(msg.get("side", 0))))
			if is_instance_valid(target):
				Vfx.popup(target.global_position + Vector3(0, 0.5, 0), "Miss!", Color(0.75, 0.85, 1.0), 1.0, "miss")
		"faint":
			var side: = int(msg.get("side", 0))
			var c: = _puppet(side)
			if is_instance_valid(c):
				c._pmd_faint()
				c.mode = CreatureDef.Mode.FAINTED
			if side == BattleProto.SIDE_HOST:
				Battle.trainer_battle["fainted"] = int(Battle.trainer_battle.get("fainted", 0)) + 1
		"send":
			_send_puppet(msg)
		"banner":
			var hud: = Dialogue.hud()
			if hud != null and hud.intro != null:
				hud.intro.banner(String(msg.get("text", "")))
		"end":
			var w: = int(msg.get("winner", -1))
			_result = "won" if w == BattleProto.SIDE_GUEST else ("lost" if w == BattleProto.SIDE_HOST else "aborted")




func _hit_fx(side: int, dmg: int, eff: float, crit: bool) -> void :
	var c: Node3D = _puppet(side)
	if not is_instance_valid(c):
		return
	c._pmd_hurt()
	c.sprite.modulate = Color(1.0, 0.35, 0.35)
	Battle.fight_tween(c).tween_property(c.sprite, "modulate", c.base_tint(), 0.25)
	var head: Vector3 = c.global_position + Vector3(0, 0.5, 0)
	var col: = Color(1, 0.75, 0.15) if eff > 1.0 else (Color(0.55, 0.58, 0.66) if eff < 1.0 else Color(0.9, 0.25, 0.22))
	if crit:
		col = Color(1, 0.45, 0.25)
	Vfx.popup(head, str(dmg), col, 1.5 if crit else 1.0, "damage")
	if crit:
		Vfx.popup(head + Vector3(0, 0.35, 0), "CRITICAL!", Color(1, 0.55, 0.3), 1.0, "crit")
		Vfx.shake(0.25)
	if eff > 1.0:
		Vfx.popup(head + Vector3(0, -0.35, 0), "SUPER EFFECTIVE!", Color(1, 0.8, 0.2), 1.0, "super", 2)
	elif eff < 1.0:
		Vfx.popup(head + Vector3(0, -0.35, 0), "Not very effective", Color(0.7, 0.7, 0.8), 1.0, "weak")



func _send_puppet(msg: Dictionary) -> void :
	var side: = int(msg.get("side", 0))
	var d = msg.get("mon", {})
	if not (d is Dictionary) or d.is_empty():
		return
	var m = MonScript.from_dict(d)
	m.heal_full()
	var old: Node3D = _puppet(side)
	var at: Vector3 = old.global_position if is_instance_valid(old) else _center
	var face: Vector3 = old.facing if is_instance_valid(old) else Vector3.FORWARD
	_spawn_puppet(side, m, at, face)
	if side == BattleProto.SIDE_GUEST:
		Battle.partner = _mine
		Battle.allies = [_mine]
	else:
		Battle.wild = _theirs
	if is_instance_valid(old):
		old.queue_free()




func _spawn_puppet(side: int, m, at: Vector3, facing: = Vector3.FORWARD) -> void :
	var parent: Node = get_parent()
	if parent == null:
		parent = get_tree().current_scene
	var c: Node3D = Encounters.spawn_mon(m, parent, _on_ground(at), false)
	c.mode = CreatureDef.Mode.PUPPET
	c.collision_layer = 0
	c.collision_mask = 0
	c.facing = facing
	if side == BattleProto.SIDE_GUEST:
		_mine = c
	else:
		_theirs = c
	if is_instance_valid(_mine) and is_instance_valid(_theirs):
		_mine.opponent = _theirs
		_theirs.opponent = _mine


func _puppet(side: int) -> Node3D:
	return _mine if side == BattleProto.SIDE_GUEST else _theirs


static func _other_side(side: int) -> int:
	return BattleProto.SIDE_HOST if side == BattleProto.SIDE_GUEST else BattleProto.SIDE_GUEST



func _team_mon(team: Array, i: int):
	var d = team[i] if i < team.size() else {}
	var m = MonScript.from_dict(d) if d is Dictionary and not d.is_empty() else MonScript.create("Pidgey", 5)
	m.heal_full()
	return m


func _vec3(d: Dictionary, key: String, fallback: Vector3) -> Vector3:
	var v = d.get(key)
	return v if v is Vector3 else fallback


func _xz(a) -> Vector3:
	if a is Array and a.size() >= 2:
		return Vector3(float(a[0]), _center.y, float(a[1]))
	return _center


func _on_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, Transitions.ground_y(p, _center.y), p.z)


func _now() -> float:
	return Time.get_ticks_msec() * 0.001


func _moves():
	return get_node("/root/Moves")




func _cleanup() -> void :
	_active = false
	if _net != null:
		if _net.message.is_connected(_on_message):
			_net.message.disconnect(_on_message)
		if _net.rt.is_connected(_on_rt):
			_net.rt.disconnect(_on_rt)
		if _net.closed.is_connected(_on_closed):
			_net.closed.disconnect(_on_closed)
	if _music:
		Audio.pop_music("battle", 1.0)
		_music = false
	if is_instance_valid(_arena):
		_arena.close()
		_arena.queue_free()
	_arena = null
	for c in [_mine, _theirs, _npc]:
		if is_instance_valid(c):
			c.queue_free()
	_mine = null
	_theirs = null
	_npc = null
	var p: = Dialogue.player()
	var cam: = Dialogue.camera_rig()
	if cam and p != null:
		cam.focus_follow(p)
	if _touched_player and p != null and not Game.cutscene:
		p.controls_enabled = _player_controls
	_touched_player = false
	Battle.online_guest = false
	Battle.in_battle = false
	Battle._intro = false
	Battle.partner = null
	Battle.allies = []
	Battle.wild = null
	Battle.trainer_battle = {}
	remove_from_group("online_battle_engine")
