class_name CableClubPanel
extends Control


















const REASON_TEXT: = {
	"left": "Your friend left the Cable Club.", 
	"timeout": "The connection was lost.", 
	"ice_timeout": "Couldn't connect. One of your networks blocks direct connections.", 
	"expired": "Nobody joined. The room has closed.", 
	"not_found": "There's no room with that ID.", 
	"bad_pin": "That PIN is wrong.", 
	"full": "That room is already in use.", 
	"kind": "That room is for a different activity.", 
	"version": "Your friend's game is a different version.", 
	"http": "Couldn't reach the Cable Club.", 
	"cancelled": "", 
}

const ID_ALPHABET: = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const PIN_ALPHABET: = "0123456789"
const WIN_POS: = Vector2(36, 24)
const WIN_SIZE: = Vector2(680, 300)
const PartyRow: = preload("res://scripts/ui/party_row.gd")
const MonScript: = preload("res://scripts/stats/mon.gd")
const PokemonSprites: = preload("res://scripts/pokemon_sprites.gd")

signal _chosen(id: String)
signal _done


var screen: = ""

var net

var kind: = ""

var _open: = false
var _armed: = -1
var _pin: = ""
var _room: = ""
var _win: PkWindow
var _context: Label
var _list: PkMenuList
var _entry: PkNameEntry
var _dialog: PkDialogBox
var _hints: PkHintBar


var _trade: TradeSession
var _trade_win: PkWindow
var _my_col: VBoxContainer
var _their_col: VBoxContainer
var _trade_status: Label
var _trade_menu: PkMenuList

var _picking: = false

var _trade_asked: = false

var _trade_finished: = false

var _checking: = false



var _ob: OnlineBattle

var battle_host_script: Script
var battle_guest_script: Script

var _team_pick: Array = []

var _battle_started: = false


func _init() -> void :
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.setup_input()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_win = PkWindow.new()
	_win.position = WIN_POS
	_win.size = WIN_SIZE
	add_child(_win)
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_win.add_child(v)
	_context = Label.new()
	_context.theme_type_variation = "SmallLabel"
	_context.add_theme_color_override("font_color", UiKit.BLUE)
	_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_context)
	_list = PkMenuList.new()
	_list.active = false
	_list.chosen.connect(_on_chosen)
	_list.cancelled.connect(_on_back)
	_list.disabled_chosen.connect(_on_disabled)
	v.add_child(_list)

	_entry = PkNameEntry.new()
	_entry.position = WIN_POS
	add_child(_entry)

	_dialog = PkDialogBox.new()
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_dialog.offset_left = 120
	_dialog.offset_right = -120
	_dialog.offset_top = -190
	_dialog.offset_bottom = -30
	add_child(_dialog)

	_hints = PkHintBar.new()
	_hints.position = Vector2(WIN_POS.x, WIN_POS.y + WIN_SIZE.y + 16)
	_hints.custom_minimum_size = Vector2(WIN_SIZE.x, 28)
	add_child(_hints)
	_hints.set_hints([["pk_ok", "Select"], ["pk_back", "Back"]])


	_trade_win = PkWindow.new()
	_trade_win.position = WIN_POS
	_trade_win.size = WIN_SIZE
	_trade_win.visible = false
	add_child(_trade_win)
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 8)
	_trade_win.add_child(tv)
	var cols: = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	tv.add_child(cols)
	var left: = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	cols.add_child(left)
	left.add_child(_trade_heading("YOUR POKéMON"))
	_my_col = VBoxContainer.new()
	_my_col.add_theme_constant_override("separation", 2)
	left.add_child(_my_col)
	var right: = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	cols.add_child(right)
	right.add_child(_trade_heading("THEIR OFFER"))
	_their_col = VBoxContainer.new()
	_their_col.add_theme_constant_override("separation", 2)
	right.add_child(_their_col)
	_trade_status = Label.new()
	_trade_status.theme_type_variation = "SmallLabel"
	_trade_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_trade_status)
	_trade_menu = PkMenuList.new()
	_trade_menu.active = false
	_trade_menu.chosen.connect(_on_trade_chosen)
	_trade_menu.cancelled.connect(_on_trade_back)
	tv.add_child(_trade_menu)

	visible = false






func open() -> void :
	if _open:
		return
	if net == null:
		net = get_node_or_null("/root/Net")
	_open = true
	visible = true
	_armed = Engine.get_process_frames()
	Game.menu_open = true
	var p: = Game.get_player()
	if p:
		p.controls_enabled = false
	UiKit.sfx("menu_open")
	UiKit.pop_in(_win)
	if net == null:
		screen = "message"
		await _say(["The Cable Club is closed right now."])
		close()
		return
	_connect_net()


	screen = "save"
	if SaveGame.enabled:
		if not await _dialog.ask_yes_no("", "Before connecting, your game must be saved.\nSave now?"):
			close()
			return
		SaveGame.save_now()
		var hud: = Game.get_hud()
		if hud and hud.has_method("show_saving"):
			hud.show_saving()
	else:
		await _say(["(Dev run: saving is off, skipping the save.)"])


	while _open:
		var m: String = await _choose("mode", "What would you like to do?", [
			{"id": "trade", "label": "TRADE", "disabled": Game.party.size() < 2}, 
			{"id": "battle", "label": "BATTLE", "disabled": Game.state.healthy_count() < 1}, 
			{"id": "cancel", "label": "CANCEL"}])
		if not _open or m == "cancel" or m == "back":
			close()
			return
		kind = m
		var r: String = await _choose("role", "Host or join a room?", [
			{"id": "host", "label": "HOST A ROOM"}, 
			{"id": "join", "label": "JOIN A ROOM"}, 
			{"id": "back", "label": "BACK"}])
		if not _open:
			return
		if r == "back" or r == "cancel":
			continue
		_pin = ""
		if r == "host":
			_pin = await _ask_code("pin", "Choose a 4-digit PIN", PIN_ALPHABET, 4)
			if not _open:
				return
			if _pin == "":
				continue
			_show_waiting("Opening a room…")
			net.host(kind, _pin)
		else:
			var rid: String = await _ask_code("id", "Enter the room ID", ID_ALPHABET, 6)
			if not _open:
				return
			if rid == "":
				continue
			_pin = await _ask_code("pin", "Enter the room's PIN", PIN_ALPHABET, 4)
			if not _open:
				return
			if _pin == "":
				continue
			_show_waiting("Connecting…")
			net.join(kind, rid, _pin)

		if not _open:
			return
		await _done
		return


func close() -> void :
	if not _open:
		return
	_open = false
	visible = false
	screen = ""
	_list.active = false
	_entry.visible = false
	_dialog.close()
	_trade = null
	_trade_win.visible = false
	_trade_menu.active = false
	_picking = false
	_trade_asked = false
	_trade_finished = false
	_checking = false
	var ob: = _ob
	_ob = null
	if ob != null and is_instance_valid(ob):
		if not _battle_started and not ob.is_done():
			ob.cancel()
		_chosen.emit("cancel")
	_disconnect_net()
	Game.menu_open = false
	var p: = Game.get_player()
	if p and not Game.cutscene:
		p.controls_enabled = true
	UiKit.sfx("menu_close")
	_done.emit()





func _choose(sid: String, question: String, items: Array) -> String:
	screen = sid
	_dialog.close()
	_entry.visible = false
	_win.visible = true
	_context.text = question
	_list.set_items(items)
	_list.active = true
	var id: String = await _chosen
	_list.active = false
	return id



func _ask_code(sid: String, title_text: String, alphabet: String, length: int) -> String:
	screen = sid
	_list.active = false
	_win.visible = false
	_dialog.close()
	var s: String = await _entry.ask_code(title_text, alphabet, length)
	_entry.visible = false
	return s


func _show_waiting(msg: String) -> void :
	screen = "waiting"
	_win.visible = true
	_context.text = msg
	_list.set_items([{"id": "cancel", "label": "CANCEL"}])
	_list.active = true



func _say(lines: Array) -> void :
	_list.active = false
	_win.visible = false
	await _dialog.say("", lines)





func _start_trade() -> void :
	screen = "trade"
	_trade = TradeSession.new()
	_picking = false
	_trade_asked = false
	_trade_finished = false
	_checking = false
	_win.visible = false
	_list.active = false
	_entry.visible = false
	_dialog.close()
	_trade_win.title = "TRADE WITH %s" % _peer_name()
	_trade_win.visible = true
	UiKit.pop_in(_trade_win)
	_refresh_trade()


func _peer_name() -> String:
	var peer = net.peer if net != null else null
	if peer is Dictionary and String(peer.get("name", "")) != "":
		return String(peer["name"])
	return "your friend"



func _flush() -> void :
	if _trade == null or net == null:
		return
	var msgs: Array = _trade.outbox.duplicate()
	_trade.outbox.clear()
	for m in msgs:
		net.send(m)


func _on_trade_msg(msg: Dictionary) -> void :
	if _trade == null or screen != "trade" or not _open:
		return
	_trade.handle(msg)
	_flush()
	_refresh_trade()


func _on_trade_chosen(id: String) -> void :
	if _trade == null or not _open:
		return
	match id:
		"offer":
			_picking = true
			_refresh_trade()
		"summary":
			_check_their_mon()
		"accept":
			_trade.accept()
			_flush()
			_refresh_trade()
		"unaccept":
			_trade.unaccept()
			_flush()
			_refresh_trade()
		"cancel":
			_trade.cancel()
			_flush()
			_refresh_trade()
		"back":
			_picking = false
			_refresh_trade()
		_:
			if id.begins_with("slot:"):
				_choose_offer(int(id.substr(5)))



func _on_trade_back() -> void :
	if _picking:
		_picking = false
		_refresh_trade()


func _choose_offer(i: int) -> void :
	if _trade == null or i < 0 or i >= Game.party.size():
		return
	if not _trade.offer(i, TradeApply.offer_dict(i)):
		return
	_picking = false
	_flush()
	_refresh_trade()



func _refresh_trade() -> void :
	if _trade == null or screen != "trade" or not _open:
		return
	if _trade.state == TradeSession.State.DONE:
		_maybe_commit_trade()
		return
	if _trade.state == TradeSession.State.CANCELLED:
		_maybe_cancel_trade()
		return
	_build_my_column()
	_build_their_column()
	_trade_status.text = _trade_status_text()
	if _picking:
		var rows: Array = []
		for i in Game.party.size():
			rows.append({"id": "slot:%d" % i, "label": "%s  Lv %d" % [
				Game.party[i].display_name.to_upper(), Game.party[i].level]})
		rows.append({"id": "back", "label": "BACK"})
		_trade_menu.set_items(rows)
		_trade_menu.active = true
		return
	if _trade.state == TradeSession.State.CONFIRMING or _trade.state == TradeSession.State.CONFIRMED:
		_trade_menu.set_items([])
		_trade_menu.active = false
		if _trade.state == TradeSession.State.CONFIRMING and not _trade_asked:
			_maybe_ask()
		return
	var can_accept: bool = ( not _trade.my_mon.is_empty()) and ( not _trade.their_mon.is_empty())\
	and TradeApply.valid_offer(_trade.their_mon)
	_trade_menu.set_items([
		{"id": "offer", "label": "OFFER A POKéMON"}, 
		{"id": "summary", "label": "CHECK THEIR POKéMON", "disabled": _trade.their_mon.is_empty()}, 
		{"id": "unaccept" if _trade.my_accept else "accept", 
			"label": "CHANGE MY MIND" if _trade.my_accept else "ACCEPT", 
			"disabled": ( not _trade.my_accept) and not can_accept}, 
		{"id": "cancel", "label": "CANCEL TRADE"}])
	_trade_menu.active = true


func _build_my_column() -> void :
	_clear(_my_col)
	for i in Game.party.size():
		var row = PartyRow.new(Game.party[i])
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.selected = i == _trade.my_slot
		_my_col.add_child(row)


func _build_their_column() -> void :
	_clear(_their_col)
	if not TradeApply.valid_offer(_trade.their_mon):
		var l: = Label.new()
		l.text = "Waiting for their choice…" if _trade.their_mon.is_empty() else "???"
		l.theme_type_variation = "SmallLabel"
		_their_col.add_child(l)
		return
	var row = PartyRow.new(MonScript.from_dict(_trade.their_mon))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_their_col.add_child(row)


func _clear(box: Node) -> void :
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _trade_status_text() -> String:
	if not _trade.their_mon.is_empty() and not TradeApply.valid_offer(_trade.their_mon):
		return "That POKéMON can't be traded."
	if _trade.state == TradeSession.State.CONFIRMED:
		return "Waiting for %s…" % _peer_name()
	if _trade.their_accept:
		return "They accepted."
	if _trade.my_accept:
		return "Waiting for them to accept…"
	if not _trade.their_mon.is_empty():
		return "They offered %s." % _mon_name(_trade.their_mon)
	return "Waiting for their choice…"



func _maybe_ask() -> void :
	if _trade_asked or _trade == null or _trade.state != TradeSession.State.CONFIRMING:
		return
	_trade_asked = true
	_trade_menu.active = false
	_trade_status.text = "…"
	var yes: bool = await _dialog.ask_yes_no("", "Trade your %s for %s's %s?" % [
		_mon_name(_trade.my_mon), _peer_name(), _mon_name(_trade.their_mon)])
	if _trade == null or not _open or screen != "trade":
		return
	_trade_asked = false
	if _trade.state == TradeSession.State.CONFIRMING:
		if yes:
			_trade.confirm()
		else:
			_trade.decline()
		_flush()
	_refresh_trade()


func _maybe_commit_trade() -> void :
	if _trade_finished or _trade == null:
		return
	_trade_finished = true
	var gave: = String(_trade.my_mon.get("species", ""))
	var slot: int = _trade.my_slot
	var r: Dictionary = TradeApply.apply(slot, _trade.their_mon)
	if not bool(r.get("ok", false)):
		await _say(["The trade failed."])
		net.leave()
		close()
		return
	var into: String = String(r.get("evolve_into", ""))
	Analytics.track("online_trade_done", {"gave_species": gave, 
		"got_species": r.mon.species, "evolved": into != ""})
	await _play_swap(gave, r.mon.species)
	await _say(["%s sent over %s.\nTake good care of %s!" % [_peer_name(), r.mon.display_name, r.mon.display_name]])
	net.leave()
	close()
	if into != "":
		await Progression.trade_evolve(slot, into)


func _maybe_cancel_trade() -> void :
	if _trade_finished or _trade == null:
		return
	_trade_finished = true
	Analytics.track("online_trade_cancelled", {"step": _trade.step_name()})
	await _say(["The trade was cancelled."])
	net.leave()



func _play_swap(gave_species: String, got_species: String) -> void :
	var center: = _trade_win.position + _trade_win.size * 0.5
	var a: = _swap_icon(gave_species, center)
	var b: = _swap_icon(got_species, center + Vector2(200, 0))
	b.modulate.a = 0.0
	var tw: = create_tween()
	tw.tween_interval(0.4)
	tw.set_parallel(true)
	tw.tween_property(a, "position:x", a.position.x - 200.0, 1.1)
	tw.tween_property(a, "modulate:a", 0.0, 1.1)
	tw.tween_property(b, "position:x", center.x - 48.0, 1.1)
	tw.tween_property(b, "modulate:a", 1.0, 1.1)
	tw.chain().tween_interval(1.0)
	await tw.finished
	a.queue_free()
	b.queue_free()


func _swap_icon(species: String, at: Vector2) -> TextureRect:
	var tr: = TextureRect.new()
	tr.texture = PokemonSprites.icon_fitted(species, 96)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size = Vector2(96, 96)
	tr.position = at - Vector2(48, 48)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr



func _check_their_mon() -> void :
	if _trade == null or not TradeApply.valid_offer(_trade.their_mon):
		return
	var hud: = Game.get_hud()
	if hud == null:
		return
	_checking = true
	_trade_menu.active = false
	hud.summary_panel().show_mon(MonScript.from_dict(_trade.their_mon), 
		"OFFERED BY %s" % _peer_name().to_upper())
	Game.menu_open = true
	var p: = Game.get_player()
	if p:
		p.controls_enabled = false
	Audio.ui("sfx/ui/menu_open")


func _mon_name(d: Dictionary) -> String:
	var n: = String(d.get("nickname", ""))
	return n if n != "" else String(d.get("species", ""))


func _trade_heading(text: String) -> Label:
	var l: = Label.new()
	l.text = text
	l.theme_type_variation = "SmallLabel"
	l.add_theme_color_override("font_color", UiKit.BLUE)
	return l



func _on_disabled(id: String) -> void :
	if not _open:
		return
	var msg: = ""
	if screen == "mode" and id == "trade":
		msg = "You need at least two POKéMON to trade."
	elif screen == "bt_settings" and id.begins_with("size:"):
		msg = "You need %d healthy POKéMON." % int(id.substr(5))
	elif screen == "bt_answer" and id == "accept":
		msg = "You need %d healthy POKéMON." % (int(_ob.size) if _ob != null else 0)
	elif screen == "bt_team" and id.begins_with("slot:"):
		var i: = int(id.substr(5))
		msg = "%s has fainted." % (Game.party[i].display_name if i < Game.party.size() else "That POKéMON")
	if msg == "":
		return
	await _say([msg])
	if not _open:
		return
	_win.visible = true
	_list.active = true





func _start_battle(role_str: String) -> void :
	screen = "battle"
	_win.visible = false
	_list.active = false
	_entry.visible = false
	_dialog.close()
	_team_pick.clear()
	_battle_started = false
	var ob: = OnlineBattle.new()
	if battle_host_script != null:
		ob.host_engine_script = battle_host_script
	if battle_guest_script != null:
		ob.guest_engine_script = battle_guest_script
	ob.finished.connect(_on_battle_finished)
	_ob = ob
	get_tree().root.add_child(ob)
	ob.begin(net, role_str, _peer_name())
	_drive_battle(ob)



func _drive_battle(ob: OnlineBattle) -> void :
	while _open and _ob == ob and not ob.is_done():
		var s: String = ob.step
		match s:
			"settings":
				await _screen_settings(ob)
			"answer":
				await _screen_answer(ob)
			"team":
				await _screen_team(ob)
			"preview":
				await _screen_preview(ob)
			"wait_settings", "wait_team", "wait_ready":
				await _screen_wait(ob, s)
			_:
				_battle_started = true
				close()
				return



func _screen_settings(ob: OnlineBattle) -> void :
	var healthy: int = Game.state.healthy_count()
	var items: Array = []
	for n in BattleProto.SIZES:
		items.append({"id": "size:%d" % n, "label": "TEAM SIZE: %d" % n, "disabled": healthy < n})
	items.append({"id": "back", "label": "BACK"})
	var id: String = await _choose("bt_settings", 
		"ARENA: COLOSSEUM · WEATHER: SUNNY\nHow many POKéMON will you use?", items)
	if not _open or _ob != ob or ob.is_done():
		return
	if id.begins_with("size:"):
		ob.choose_size(int(id.substr(5)))
	elif id == "back":
		close()



func _screen_answer(ob: OnlineBattle) -> void :
	var n: int = ob.size
	var ok: bool = Game.state.healthy_count() >= n
	var id: String = await _choose("bt_answer", 
		"%s wants to battle!\nColosseum · Sunny · %d vs %d" % [_peer_name(), n, n], 
		[{"id": "accept", "label": "ACCEPT", "disabled": not ok}, 
		{"id": "decline", "label": "DECLINE"}])
	if not _open or _ob != ob or ob.is_done():
		return
	if id == "accept" and ok:
		ob.answer_settings(true)
	elif id == "decline":
		ob.answer_settings(false)



func _screen_team(ob: OnlineBattle) -> void :
	while _open and _ob == ob and not ob.is_done() and ob.step == "team":
		var items: Array = []
		for i in Game.party.size():
			var m = Game.party[i]
			var pos: int = _team_pick.find(i)
			var label: = "%s  Lv %d" % [m.display_name, m.level]
			if pos >= 0:
				label = "%d. %s" % [pos + 1, label]
			items.append({"id": "slot:%d" % i, "label": label, "disabled": m.hp <= 0})
		items.append({"id": "done", "label": "DONE", "disabled": _team_pick.size() != ob.size})
		items.append({"id": "back", "label": "BACK"})
		var id: String = await _choose("bt_team", 
			"Choose %d POKéMON, in the order they fight." % ob.size, items)
		if not _open or _ob != ob or ob.is_done():
			return
		if id.begins_with("slot:"):
			var i: = int(id.substr(5))
			var at: int = _team_pick.find(i)
			if at >= 0:
				_team_pick.remove_at(at)
			else:
				_team_pick.append(i)
		elif id == "done" and _team_pick.size() == ob.size:
			ob.choose_team(_team_pick.duplicate())
			return
		elif id == "back":
			_team_pick.clear()



func _screen_preview(ob: OnlineBattle) -> void :
	var id: String = await _choose("bt_preview", 
		"YOUR TEAM\n%s\n\nTHEIR TEAM\n%s" % [_team_text(ob.my_team), _team_text(ob.their_team)], 
		[{"id": "ready", "label": "READY"}])
	if not _open or _ob != ob or ob.is_done():
		return
	if id == "ready":
		ob.ready()



func _screen_wait(ob: OnlineBattle, from_step: String) -> void :
	if not _open or _ob != ob:
		return
	screen = "bt_wait"
	_dialog.close()
	_entry.visible = false
	_win.visible = true
	_context.text = "Waiting for %s…" % _peer_name()
	_list.set_items([])
	_list.active = false
	await ob.wait_step_change(from_step)


func _team_text(mons: Array) -> String:
	if mons.is_empty():
		return "…"
	var parts: = PackedStringArray()
	for d in mons:
		parts.append("%s Lv %d" % [String(d.get("species", "?")).to_upper(), int(d.get("level", 0))])
	return " · ".join(parts)



func _on_battle_finished(result: String) -> void :
	var ob: = _ob
	_ob = null
	if not _open:
		return
	_disconnect_net()
	net.leave()
	var lines: Array = []
	match result:
		"declined":
			if ob != null and ob.role == "host":
				lines = ["%s declined." % _peer_name()]
		"aborted":
			var text: String = String(REASON_TEXT.get(ob.reason, "")) if ob != null else ""
			lines = [text if text != "" else "The battle was interrupted."]
	if not lines.is_empty():
		screen = "message"
		await _say(lines)
	close()




func _connect_net() -> void :
	if not net.room_ready.is_connected(_on_room_ready):
		net.room_ready.connect(_on_room_ready)
	if not net.connected.is_connected(_on_connected):
		net.connected.connect(_on_connected)
	if not net.closed.is_connected(_on_closed):
		net.closed.connect(_on_closed)
	if not net.message.is_connected(_on_trade_msg):
		net.message.connect(_on_trade_msg)


func _disconnect_net() -> void :
	if net == null or not is_instance_valid(net):
		return
	if net.room_ready.is_connected(_on_room_ready):
		net.room_ready.disconnect(_on_room_ready)
	if net.connected.is_connected(_on_connected):
		net.connected.disconnect(_on_connected)
	if net.closed.is_connected(_on_closed):
		net.closed.disconnect(_on_closed)
	if net.message.is_connected(_on_trade_msg):
		net.message.disconnect(_on_trade_msg)


func _on_room_ready(id: String) -> void :
	if not _open or screen != "waiting":
		return
	_room = id
	_context.text = "Room %s · PIN %s\nTell your friend both codes.\nWaiting for a friend…" % [_room, _pin]


func _on_connected(role_str: String) -> void :
	if not _open:
		return
	if kind == "trade":
		_start_trade()
		return
	_start_battle(role_str)


func _on_closed(reason: String) -> void :
	if not _open:
		return
	if _ob != null and not _ob.is_done():
		return
	if _trade != null and _trade.state == TradeSession.State.DONE:
		return
	var text: String = String(REASON_TEXT.get(reason, REASON_TEXT["http"]))
	if text == "":
		close()
		return
	screen = "message"
	_list.active = false
	await _say([text])
	close()


func _on_chosen(id: String) -> void :
	if screen == "waiting" and id == "cancel":
		net.leave()
		return
	_chosen.emit(id)


func _on_back() -> void :
	if screen == "waiting":
		net.leave()
		return
	_chosen.emit("back")


func _process(delta: float) -> void :
	if not _open or Engine.get_process_frames() == _armed:
		return
	if screen == "trade" and _checking:
		var hud: = Game.get_hud()
		if hud == null or not hud.summary_visible():
			_checking = false
			Game.menu_open = true
			var p: = Game.get_player()
			if p:
				p.controls_enabled = false
			_refresh_trade()





func pick(id: String) -> void :
	for list in [_list, _trade_menu]:
		if list == null or not list.active:
			continue
		for i in list.items.size():
			if String(list.items[i].get("id", "")) == id:
				list.index = i
				list.confirm()
				return



func pick_slot(i: int) -> void :
	_choose_offer(i)



func enter_code(s: String) -> void :
	for i in s.length():
		_entry.type(s[i])
	_entry.finish_now()
