class_name OnlineBattle
extends Node















const COLOSSEUM_SCENE: = "res://scenes/interiors/cable_club_interiors.tscn"
const COLOSSEUM_SPAWN: = "cc_colosseum_in"
const HOST_ENGINE: = "res://scripts/net/battle_host.gd"
const GUEST_ENGINE: = "res://scripts/net/battle_guest.gd"

const LOAD_TIMEOUT: = 30.0


const MESSAGE_TIMEOUT: = 8.0


signal finished(result: String)

signal changed


var host_engine_script: Script
var guest_engine_script: Script


var abort_grace: = 2.0



var step: = ""
var size: = 0
var my_team: Array = []
var their_team: Array = []
var role: = ""

var reason: = ""

var result: = ""

var _net
var _peer: = "your friend"
var _return_scene: = ""
var _return_spawn: = ""
var _save_was: = true
var _t0: = 0
var _done: = false
var _tripped: = false
var _loaded: = false
var _my_ready: = false
var _their_ready: = false
var _engine: Node





func begin(net, role_: String, peer_name: String) -> void :
	_net = net
	role = role_
	if peer_name != "":
		_peer = peer_name
	if is_inside_tree():
		add_to_group("online_battle")
	else:
		add_to_group.call_deferred("online_battle")
	_t0 = Time.get_ticks_msec()
	if host_engine_script == null:
		host_engine_script = _load_script(HOST_ENGINE)
	if guest_engine_script == null:
		guest_engine_script = _load_script(GUEST_ENGINE)
	if _net != null:
		if not _net.message.is_connected(_on_msg):
			_net.message.connect(_on_msg)
		if not _net.closed.is_connected(_on_closed):
			_net.closed.connect(_on_closed)
	_set_step("settings" if role == "host" else "wait_settings")



func choose_size(n: int) -> void :
	if step != "settings":
		return
	size = n
	_send({"t": "bt_settings", "arena": BattleProto.ARENA, "weather": BattleProto.WEATHER, "size": n})
	_set_step("wait_settings")



func answer_settings(ok: bool) -> void :
	if step != "answer":
		return
	if ok:
		_send({"t": "bt_settings_ok"})
		_set_step("team")
	else:
		_send({"t": "bt_decline"})
		_finish("declined")



func choose_team(slots: Array) -> void :
	if step != "team":
		return
	my_team.clear()
	for i in slots:
		if int(i) >= 0 and int(i) < Game.party.size():
			my_team.append(Game.party[int(i)].to_dict())
	_send({"t": "bt_team", "mons": my_team})
	_set_step("wait_team")
	_maybe_preview()



func ready() -> void :
	if step != "preview":
		return
	_my_ready = true
	_send({"t": "bt_ready"})
	_set_step("wait_ready")
	_maybe_start()



func forfeit() -> void :
	if step == "fighting" and _engine != null and is_instance_valid(_engine)\
	and _engine.has_method("forfeit"):
		_engine.forfeit()



func cancel() -> void :
	if _done:
		return
	_done = true
	_set_step("done")
	_disconnect()
	if is_instance_valid(_engine):
		_engine.queue_free()
	_engine = null
	finished.emit("cancelled")
	queue_free()


func is_done() -> bool:
	return _done



func wait_step_change(from_step: String) -> void :
	while step == from_step and not _done:
		await changed




func _on_msg(m: Dictionary) -> void :
	if _done or _net == null:
		return
	match String(m.get("t", "")):
		"bt_settings":
			if role != "guest" or step != "wait_settings":
				return
			size = int(m.get("size", 1))
			_set_step("answer")
		"bt_settings_ok":
			if role != "host" or step != "wait_settings":
				return
			_set_step("team")
		"bt_decline":
			if role == "host":
				_finish("declined")
		"bt_team":
			their_team = m.get("mons", [])
			_maybe_preview()
		"bt_ready":
			_their_ready = true
			_maybe_start()
		"bt_start":
			if role == "guest":
				_trip()
		"bt_loaded":
			if role == "host":
				_loaded = true


func _maybe_preview() -> void :
	if step == "wait_team" and not their_team.is_empty():
		_set_step("preview")


func _maybe_start() -> void :
	if role != "host" or step != "wait_ready":
		return
	if _my_ready and _their_ready:
		_send({"t": "bt_start"})
		_trip()


func _on_closed(r: String) -> void :
	reason = r
	if _done:
		return
	if step == "fighting":


		_abort_soon()
		return
	_finish("aborted")


func _abort_soon() -> void :
	await get_tree().create_timer(maxf(abort_grace, 0.0)).timeout
	if not _done:
		_finish("aborted")




func _trip() -> void :
	if _done or _tripped:
		return
	_tripped = true
	_set_step("loading")
	_return_scene = _current_scene_path()
	_return_spawn = _center_spawn(_return_scene)
	_save_was = SaveGame.enabled
	SaveGame.enabled = false
	for i in Game.party.size():
		if Game.is_out(i):
			Game.recall(i)
	await Transitions.go_to(COLOSSEUM_SCENE, COLOSSEUM_SPAWN, true)
	if _done:
		return
	if role == "guest":
		_send({"t": "bt_loaded"})
		await _run_engine()
		return
	await _await_loaded()
	if _done:
		return
	if not _loaded:
		_finish("aborted")
		return
	await _run_engine()


func _await_loaded() -> void :
	var t: = Time.get_ticks_msec()
	while not _loaded and not _done and Time.get_ticks_msec() - t < int(LOAD_TIMEOUT * 1000.0):
		await get_tree().process_frame


func _run_engine() -> void :
	var engine_script: Script = host_engine_script if role == "host" else guest_engine_script
	if engine_script == null:
		_finish("aborted")
		return
	_set_step("fighting")
	_engine = Node.new()
	_engine.set_script(engine_script)
	var scene: = get_tree().current_scene
	if scene != null:
		scene.add_child(_engine)
	var r: = "aborted"
	if role == "host":
		r = await _engine.run(_net, my_team, their_team, _battle_spot(), _peer)
	else:
		r = await _engine.run(_net, my_team, their_team, _peer)
	if is_instance_valid(_engine):
		_engine.queue_free()
	_engine = null
	if not _done:
		_finish(r)




func _finish(r: String) -> void :
	if _done:
		return
	_done = true
	result = r
	_set_step("done")
	if not _tripped:

		_disconnect()
		finished.emit(r)
		return
	var text: = "The battle was interrupted."
	match r:
		"won":
			text = "You won against %s!" % _peer
		"lost":
			text = "You lost against %s." % _peer
	await _message([text])
	if _net != null:
		_net.leave()
	await Transitions.go_to(_return_scene, _return_spawn, true)
	SaveGame.enabled = _save_was
	Analytics.track("online_battle_end", {"team_size": size, 
		"result": r if r != "aborted" else "disconnect", 
		"duration_s": int((Time.get_ticks_msec() - _t0) / 1000.0), "role": role})
	finished.emit(r)
	queue_free()




func _message(lines: Array) -> void :
	var hud: = Game.get_hud()
	if hud == null or not hud.has_method("open_dialog"):
		return
	hud.open_dialog("", PackedStringArray(lines))
	var t: = Time.get_ticks_msec()
	while hud.is_dialog_open() and Time.get_ticks_msec() - t < int(MESSAGE_TIMEOUT * 1000.0):
		await get_tree().process_frame




func _set_step(s: String) -> void :
	step = s
	changed.emit()


func _send(msg: Dictionary) -> void :
	if _net != null:
		_net.send(msg)


func _disconnect() -> void :
	if _net == null or not is_instance_valid(_net):
		return
	if _net.message.is_connected(_on_msg):
		_net.message.disconnect(_on_msg)
	if _net.closed.is_connected(_on_closed):
		_net.closed.disconnect(_on_closed)


func _load_script(path: String) -> Script:
	return load(path) if ResourceLoader.exists(path) else null


func _current_scene_path() -> String:
	var cs: = get_tree().current_scene
	return cs.scene_file_path if cs != null else ""



func _center_spawn(path: String) -> String:
	return "pw_center_in" if path.contains("pewter") else "vc_center_in"



func _battle_spot() -> Vector3:
	var cs: = get_tree().current_scene
	if cs != null:
		var m: = cs.find_child("BattleSpot", true, false)
		if m is Node3D:
			return (m as Node3D).global_position
	return Vector3.ZERO
