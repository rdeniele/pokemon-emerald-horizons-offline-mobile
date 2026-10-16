extends Node




var _closed_ms: = 0




func fill_text(text: String) -> String:
	return text.replace("{PLAYER}", Game.state.player_name).replace("{RIVAL}", Game.state.rival_name)


func fill_lines(lines) -> PackedStringArray:
	var out: = PackedStringArray()
	for l in lines:
		out.append(fill_text(String(l)))
	return out


func player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func camera_rig() -> Node:
	return get_tree().get_first_node_in_group("camera_rig")


func hud() -> Node:
	return get_tree().get_first_node_in_group("hud")


func msg(text: String, secs: = 2.5, kind: = "info") -> void :
	var h: = hud()
	if h:
		h.show_message(text, secs, kind)


func start(npc: Node) -> void :
	if Game.is_busy() or Time.get_ticks_msec() - _closed_ms < 250:
		return
	var p: = player()
	var h: = hud()
	if p == null or h == null:
		return
	Game.talking = true
	p.controls_enabled = false
	p.face_toward(npc.global_position)
	if npc.has_method("interact"):
		await npc.interact(p)
		_closed_ms = Time.get_ticks_msec()
		Game.talking = false
		if not Game.cutscene:
			p.controls_enabled = true
		return
	var lines: PackedStringArray = npc.talk_to(p)
	h.open_dialog(npc.npc_name, lines)
	await h.dialog_closed
	await npc.finish_talk()
	_closed_ms = Time.get_ticks_msec()
	Game.talking = false
	if not Game.cutscene and not Game.menu_open:
		p.controls_enabled = true
