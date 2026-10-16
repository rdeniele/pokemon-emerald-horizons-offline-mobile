extends Control












const PartyRow: = preload("res://scripts/ui/party_row.gd")

const PARTY_POS: = Vector2(36, 24)
const PARTY_SIZE: = Vector2(700, 620)
const BOX_POS: = Vector2(760, 24)
const BOX_SIZE: = Vector2(484, 330)
const MENU_POS: = Vector2(760, 370)
const MENU_SIZE: = Vector2(484, 274)

const ROW_H: = 92

var mode: = "boot"
var party_sel: = 0
var box_sel: = 0
var move_from: = -1
var _open: = false
var _armed: = -1
var _note: = ""
var _party_rows: Array = []
var _box_rows: Array = []
var _party_window: PkWindow
var _slot_box: VBoxContainer
var _box_window: PkWindow
var _box_count: Label
var _box_scroll: ScrollContainer
var _box_list: VBoxContainer
var _menu_window: PkWindow
var _context: Label
var _list: PkMenuList
var _note_label: Label
var _hints: PkHintBar


func _ready() -> void :
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.setup_input()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_party_window = PkWindow.new()
	_party_window.title = "PARTY"
	_party_window.position = PARTY_POS
	_party_window.size = PARTY_SIZE
	add_child(_party_window)
	_slot_box = VBoxContainer.new()
	_slot_box.add_theme_constant_override("separation", 2)
	_party_window.add_child(_slot_box)

	_box_window = PkWindow.new()
	_box_window.title = "BOX 1"
	_box_window.position = BOX_POS
	_box_window.size = BOX_SIZE
	add_child(_box_window)
	var box_v: = VBoxContainer.new()
	box_v.add_theme_constant_override("separation", 6)
	_box_window.add_child(box_v)
	_box_count = Label.new()
	_box_count.theme_type_variation = "SmallLabel"
	_box_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_box_count.add_theme_color_override("font_color", UiKit.BLUE)
	box_v.add_child(_box_count)
	_box_scroll = ScrollContainer.new()
	_box_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box_v.add_child(_box_scroll)
	_box_list = VBoxContainer.new()
	_box_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box_list.add_theme_constant_override("separation", 2)
	_box_scroll.add_child(_box_list)

	_menu_window = PkWindow.new()
	_menu_window.position = MENU_POS
	_menu_window.size = MENU_SIZE
	add_child(_menu_window)
	var mv: = VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	_menu_window.add_child(mv)
	_context = Label.new()
	_context.theme_type_variation = "SmallLabel"
	_context.add_theme_color_override("font_color", UiKit.BLUE)
	_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mv.add_child(_context)
	_list = PkMenuList.new()
	_list.active = false
	_list.chosen.connect(_on_chosen)
	_list.cancelled.connect(_back)
	mv.add_child(_list)
	_note_label = Label.new()
	_note_label.theme_type_variation = "SmallLabel"
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.custom_minimum_size = Vector2(0, 40)
	_note_label.add_theme_color_override("font_color", UiKit.INK)
	mv.add_child(_note_label)

	_hints = PkHintBar.new()
	_hints.position = Vector2(PARTY_POS.x, PARTY_POS.y + PARTY_SIZE.y + 16)
	_hints.custom_minimum_size = Vector2(PARTY_SIZE.x, 28)
	add_child(_hints)
	_hints.set_hints([[["pk_up", "pk_down"], "Choose"], ["pk_ok", "Select"], ["pk_back", "Back"]])

	visible = false





func open() -> void :
	_open = true
	visible = true
	_armed = Engine.get_process_frames()
	party_sel = 0
	box_sel = 0
	_rebuild()
	_show_boot()
	Game.menu_open = true
	Analytics.track("pc_opened")
	var p: = Game.get_player()
	if p:
		p.controls_enabled = false
	UiKit.sfx("menu_open")


func close() -> void :
	if not _open:
		return
	_open = false
	visible = false
	mode = "boot"
	Game.menu_open = false
	var p: = Game.get_player()
	if p and not Game.cutscene:
		p.controls_enabled = true
	UiKit.sfx("menu_close")



func demo() -> void :
	open()
	_show_menu()
	_armed = Engine.get_process_frames()




func _show_boot(msg: = "") -> void :
	mode = "boot"
	move_from = -1
	_note = msg
	_context.text = "Booted up the PC."
	_list.active = true
	_list.set_items([
		{"id": "someone", "label": "SOMEONE'S PC"}, 
		{"id": "player", "label": "%s's PC" % Game.state.player_name}, 
		{"id": "logoff", "label": "LOG OFF"}, 
	])
	_note_label.text = _note
	_sync_rows()


func _show_menu(msg: = "") -> void :
	mode = "menu"
	move_from = -1
	_note = msg
	_context.text = "What would you like to do?"
	_list.active = true
	_list.set_items([
		{"id": "withdraw", "label": "WITHDRAW POKéMON"}, 
		{"id": "deposit", "label": "DEPOSIT POKéMON"}, 
		{"id": "move", "label": "MOVE POKéMON"}, 
		{"id": "seeya", "label": "SEE YA!"}, 
	])
	_note_label.text = _note
	_sync_rows()


func _show_withdraw() -> void :
	if Game.state.box.is_empty():
		_show_menu("The box is empty.")
		return
	mode = "withdraw"
	box_sel = clampi(box_sel, 0, Game.state.box.size() - 1)
	_context.text = "Withdraw which Pokémon?"
	_list.active = false
	_list.set_items([])
	_note_label.text = ""
	_sync_rows()
	_scroll_box()


func _show_deposit() -> void :
	if Game.party.is_empty():
		_show_menu("You have no Pokémon to deposit.")
		return
	mode = "deposit"
	party_sel = clampi(party_sel, 0, Game.party.size() - 1)
	_context.text = "Deposit which Pokémon?"
	_list.active = false
	_list.set_items([])
	_note_label.text = ""
	_sync_rows()


func _show_move(msg: = "") -> void :
	if Game.party.size() < 2:
		_show_menu("You need at least two Pokémon to reorder.")
		return
	mode = "move"
	move_from = -1
	_context.text = "Move which Pokémon?"
	_list.active = false
	_list.set_items([])
	_note_label.text = msg if msg != "" else "Pick a slot, then a slot to swap it with. Slot 1 is the lead."
	_sync_rows()




func _rebuild() -> void :
	for r in _party_rows:
		if is_instance_valid(r):
			_slot_box.remove_child(r)
			r.queue_free()
	_party_rows.clear()
	for m in Game.party:
		var row: = PartyRow.new(m)
		row.custom_minimum_size = Vector2(0, ROW_H)
		_slot_box.add_child(row)
		_party_rows.append(row)
	for r in _box_rows:
		if is_instance_valid(r):
			_box_list.remove_child(r)
			r.queue_free()
	_box_rows.clear()
	for m in Game.state.box:
		var row: = PartyRow.new(m)
		row.custom_minimum_size = Vector2(0, ROW_H)
		_box_list.add_child(row)
		_box_rows.append(row)
	_box_count.text = "%d / %d" % [Game.state.box.size(), GameState.BOX_CAPACITY]


func _sync_rows() -> void :
	for i in _party_rows.size():
		_party_rows[i].selected = (mode == "deposit" or mode == "move") and i == party_sel
		_party_rows[i].source = mode == "move" and i == move_from
		_party_rows[i].out = Game.is_out(i)
		_party_rows[i].status = _status_key(i)
	for j in _box_rows.size():
		_box_rows[j].selected = mode == "withdraw" and j == box_sel



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


func _scroll_box() -> void :
	if box_sel < _box_rows.size():
		_box_scroll.ensure_control_visible(_box_rows[box_sel])




func _step(d: int) -> void :
	var n: = Game.state.box.size() if mode == "withdraw" else Game.party.size()
	if n == 0:
		return
	if mode == "withdraw":
		box_sel = posmod(box_sel + d, n)
		_scroll_box()
	else:
		party_sel = posmod(party_sel + d, n)
	UiKit.sfx("cursor")
	_sync_rows()


func _ok() -> void :
	match mode:
		"withdraw":
			var mon = Game.state.box[box_sel] if box_sel < Game.state.box.size() else null
			var r: Dictionary = Game.state.withdraw_from_box(box_sel)
			UiKit.sfx("confirm" if r.ok else "error")
			if r.ok:
				if mon != null:
					Analytics.track("pokemon_withdrawn", {"species": mon.species, "level": mon.level})
				Game.party_changed.emit()
				_rebuild()
				box_sel = clampi(box_sel, 0, maxi(Game.state.box.size() - 1, 0))
				_show_menu(String(r.text))
			else:
				_note_label.text = String(r.text)
		"deposit":
			var mon = Game.state.party[party_sel] if party_sel < Game.state.party.size() else null
			var r: Dictionary = Game.state.deposit_to_box(party_sel)
			UiKit.sfx("confirm" if r.ok else "error")
			if r.ok:
				if mon != null:
					Analytics.track("pokemon_deposited", {"species": mon.species, "level": mon.level})
				Game.party_changed.emit()
				_rebuild()
				party_sel = clampi(party_sel, 0, maxi(Game.party.size() - 1, 0))
				_show_menu(String(r.text))
			else:
				_note_label.text = String(r.text)
		"move":
			if move_from < 0:
				move_from = party_sel
				UiKit.sfx("confirm")
				_sync_rows()
			elif move_from == party_sel:
				move_from = -1
				UiKit.sfx("cancel")
				_sync_rows()
			else:
				Game.state.swap_party(move_from, party_sel)
				Game.party_changed.emit()
				_rebuild()
				_show_menu("The party order changed.")


func _on_chosen(id: String) -> void :
	match id:
		"someone":
			_show_menu()
		"player":
			_show_boot("No items stored.")
		"logoff":
			close()
		"withdraw":
			_show_withdraw()
		"deposit":
			_show_deposit()
		"move":
			_show_move()
		"seeya":
			_show_boot()


func _back() -> void :
	match mode:
		"withdraw", "deposit", "move":
			_show_menu()
		"menu":
			_show_boot()
		_:
			close()


func _process(_delta: float) -> void :
	if not _open or Engine.get_process_frames() == _armed:
		return

	if mode == "boot" or mode == "menu":
		return
	if Input.is_action_just_pressed("pk_back"):
		_back()
	elif Input.is_action_just_pressed("pk_up"):
		_step(-1)
	elif Input.is_action_just_pressed("pk_down"):
		_step(1)
	elif Input.is_action_just_pressed("pk_ok"):
		_ok()
