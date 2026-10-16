extends Control











const Items: = preload("res://scripts/items.gd")
const PartyRow: = preload("res://scripts/ui/party_row.gd")



signal pick_done(result: Dictionary)

const PARTY_POS: = Vector2(36, 24)
const PARTY_SIZE: = Vector2(700, 660)
const ACTION_POS: = Vector2(760, 24)
const ACTION_SIZE: = Vector2(484, 300)

var sel: = 0
var mode: = "slots"
var switch_from: = -1
var _pick_id: = ""
var _open: = false
var _armed: = -1
var _item_ids: Array = []
var _rows: Array = []
var _party_window: PkWindow
var _slot_box: VBoxContainer
var _action_window: PkWindow
var _context: Label
var _list: PkMenuList
var _note: Label
var _hints: PkHintBar


func _ready() -> void :
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.setup_input()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_party_window = PkWindow.new()
	_party_window.title = "POKéMON"
	_party_window.position = PARTY_POS
	_party_window.size = PARTY_SIZE
	add_child(_party_window)
	_slot_box = VBoxContainer.new()
	_slot_box.add_theme_constant_override("separation", 2)
	_party_window.add_child(_slot_box)

	_action_window = PkWindow.new()
	_action_window.position = ACTION_POS
	_action_window.size = ACTION_SIZE
	add_child(_action_window)
	var av: = VBoxContainer.new()
	av.add_theme_constant_override("separation", 10)
	_action_window.add_child(av)
	_context = Label.new()
	_context.theme_type_variation = "SmallLabel"
	_context.add_theme_color_override("font_color", UiKit.BLUE)
	_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	av.add_child(_context)
	_list = PkMenuList.new()
	_list.active = false
	_list.chosen.connect(_on_chosen)
	av.add_child(_list)
	_note = Label.new()
	_note.theme_type_variation = "SmallLabel"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(0, 46)
	_note.add_theme_color_override("font_color", UiKit.INK)
	av.add_child(_note)

	_hints = PkHintBar.new()
	_hints.position = Vector2(ACTION_POS.x, ACTION_POS.y + ACTION_SIZE.y + 16)
	_hints.custom_minimum_size = Vector2(ACTION_SIZE.x, 28)
	add_child(_hints)
	_hints.set_hints([[["pk_up", "pk_down"], "Choose"], ["pk_ok", "Select"], ["pk_back", "Back"]])

	visible = false





func open() -> void :
	_open = true
	visible = true
	_armed = Engine.get_process_frames()
	sel = clampi(sel, 0, maxi(Game.party.size() - 1, 0))
	switch_from = -1
	_rebuild()
	_show_slots()
	Game.menu_open = true
	var p: = Game.get_player()
	if p:
		p.controls_enabled = false
	UiKit.sfx("menu_open")




func open_pick(item_id: String) -> bool:
	if Game.party.is_empty():
		return false
	_pick_id = item_id
	open()
	mode = "pick"
	_context.text = "Use %s on which POKéMON?" % Items.item_name(item_id)
	_note.text = "↑ ↓ choose · Enter use · Esc back"
	_sync_rows()
	return true


func close() -> void :
	if not _open:
		return
	_open = false
	visible = false
	mode = "slots"
	_pick_id = ""
	Game.menu_open = false
	var p: = Game.get_player()
	if p and not Game.cutscene:
		p.controls_enabled = true
	UiKit.sfx("menu_close")



func demo() -> void :
	_open = true
	visible = true
	_armed = Engine.get_process_frames()
	sel = 0
	_rebuild()
	_show_actions()




func _show_slots() -> void :
	mode = "slots"
	switch_from = -1
	_context.text = "Choose a Pokémon."
	_list.set_items([])
	_note.text = ""
	_sync_rows()


func _show_actions() -> void :
	mode = "actions"
	_context.text = Game.party[sel].display_name.to_upper() + ("   ·   following you" if Game.is_out(sel) else "")
	_list.set_items([
		{"id": "summary", "label": "SUMMARY"}, 
		{"id": "switch", "label": "SWITCH"}, 
		{"id": "item", "label": "ITEM"}, 
		{"id": "cancel", "label": "CANCEL"}, 
	])
	_note.text = ""
	_sync_rows()


func _show_switch() -> void :
	mode = "switch"
	switch_from = sel
	_context.text = "Move %s where?" % Game.party[sel].display_name
	_list.set_items([])
	_note.text = "Pick another slot, then Enter to swap. Slot 1 is the lead."
	_sync_rows()


func _show_items(note: = "") -> void :
	_item_ids = []
	for id in Items.all_ids():
		if Game.item_count(id) > 0 and Game.item_targets_party(id):
			_item_ids.append(id)
	for id in Game.bag.keys():
		if not _item_ids.has(id) and Game.item_count(id) > 0 and Game.item_targets_party(id):
			_item_ids.append(id)
	if _item_ids.is_empty():
		_show_actions()
		_note.text = note if note != "" else "No items you can use on a Pokémon."
		return
	mode = "item"
	_context.text = "Use on %s:" % Game.party[sel].display_name
	var rows: Array = []
	for id in _item_ids:
		rows.append({"id": id, "label": "%s  ×%d" % [Items.item_name(id), Game.item_count(id)]})
	rows.append({"id": "", "label": "CANCEL"})
	_list.set_items(rows)
	_note.text = note
	_sync_rows()




func _rebuild() -> void :
	for r in _rows:
		if is_instance_valid(r):
			_slot_box.remove_child(r)
			r.queue_free()
	_rows.clear()
	for i in Game.party.size():
		var row: = PartyRow.new(Game.party[i])
		_slot_box.add_child(row)
		_rows.append(row)
	_sync_rows()


func _sync_rows() -> void :
	for i in _rows.size():
		_rows[i].selected = i == sel
		_rows[i].source = mode == "switch" and i == switch_from
		_rows[i].out = Game.is_out(i)
		_rows[i].status = _status_key(i)



func _status_key(i: int) -> String:
	if i >= Game.party.size():
		return ""
	if Game.party[i].hp <= 0:
		return "faint"
	if not Game.is_out(i):
		return ""
	var c = Game.companions[i]
	if c == null or not is_instance_valid(c):
		return ""
	return String(c.status)


func _step(d: int) -> void :
	var n: = Game.party.size()
	if n == 0:
		return
	var ns: = posmod(sel + d, n)
	if ns != sel:
		sel = ns
		UiKit.sfx("cursor")
		_sync_rows()



func swap_to(j: int) -> bool:
	var ok: bool = Game.state.swap_party(switch_from, j)
	if ok:
		Game.party_changed.emit()
		sel = clampi(switch_from, 0, maxi(Game.party.size() - 1, 0))
		UiKit.sfx("confirm")
	_rebuild()
	_show_slots()
	return ok


func _ok() -> void :
	if mode == "slots":
		_show_actions()
	elif mode == "switch":
		swap_to(sel)
	elif mode == "pick":
		_use_pick()



func _use_pick() -> void :
	var id: = _pick_id
	var r: Dictionary = Progression.use_item(id, sel)
	UiKit.sfx("confirm" if r.get("ok", false) else "error")
	_pick_id = ""
	close()
	pick_done.emit(r)


func _on_chosen(id: String) -> void :
	if mode == "actions":
		match id:
			"summary":
				Analytics.track("menu_opened", {"menu": "summary"})
				close()
				Game.get_hud().open_summary(sel)
			"switch":
				_show_switch()
			"item":
				_show_items()
			"cancel":
				_show_slots()
	elif mode == "item":
		if id == "":
			_show_actions()
			return
		var r: Dictionary = Progression.use_item(id, sel)
		UiKit.sfx("confirm" if r.get("ok", false) else "error")
		_rebuild()
		_show_items(String(r.get("text", "")))


func _back() -> void :
	match mode:
		"pick":
			_pick_id = ""
			close()
			pick_done.emit({"ok": false, "text": "", "cancelled": true})
		"item", "switch":
			_show_actions()
		"actions":
			_show_slots()
		_:
			close()


func _process(_delta: float) -> void :
	if not _open or Engine.get_process_frames() == _armed:
		return
	if Input.is_action_just_pressed("pk_back"):
		_back()
		return
	var up: = Input.is_action_just_pressed("pk_up")
	var down: = Input.is_action_just_pressed("pk_down")
	var ok: = Input.is_action_just_pressed("pk_ok")
	if mode == "actions" or mode == "item":
		if up:
			_list.move(-1)
		elif down:
			_list.move(1)
		elif ok:
			_list.confirm()
	else:
		if up:
			_step(-1)
		elif down:
			_step(1)
		elif ok:
			_ok()
