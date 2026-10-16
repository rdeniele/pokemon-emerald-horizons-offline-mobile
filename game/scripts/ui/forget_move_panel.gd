class_name ForgetMovePanel
extends Control











const Dex: = preload("res://scripts/dex.gd")

signal picked(slot: int)


static var auto_pick: = 0

var _moves: Array = []
var _new_move: = ""
var _name: = ""
var _level: = 0
var _win: PkWindow
var _list: PkMenuList
var _card: PkInfoCard
var _hint: PkHintBar
var _auto_t: = 0.0
var _closing: = false


func _init() -> void :
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.setup_input()
	var dim: = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_win = PkWindow.new()
	_win.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_win.offset_left = -390
	_win.offset_right = 390
	_win.offset_top = -190
	_win.offset_bottom = 190
	add_child(_win)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_win.add_child(col)
	var q: = Label.new()
	q.text = "Which move should be forgotten?"
	col.add_child(q)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	_list = PkMenuList.new()
	_list.custom_minimum_size = Vector2(340, 0)
	_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_list.chosen.connect(_on_chosen)
	_list.cancelled.connect( func(): _pick(-1))
	_list.moved.connect(_on_moved)
	row.add_child(_list)
	_card = PkInfoCard.new()
	_card.custom_minimum_size = Vector2(340, 0)
	_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_card)
	var hints: = HBoxContainer.new()
	hints.alignment = BoxContainer.ALIGNMENT_END
	_hint = PkHintBar.new()
	_hint.set_hints([["pk_ok", "Forget"], ["pk_back", "Back"]])
	hints.add_child(_hint)
	col.add_child(hints)
	visible = false



func choose(m: RefCounted, new_move: String) -> int:
	_moves = m.moves.duplicate()
	_new_move = new_move
	_name = m.display_name
	_level = m.level
	_win.title = "%s  Lv %d" % [_name.to_upper(), _level]
	var items: Array = []
	for k in _moves.size():
		items.append({"id": str(k), "label": _move_name(_moves[k]).to_upper()})
	items.append({"id": "gap", "label": "", "disabled": true})
	items.append({"id": "new", "label": _move_name(new_move).to_upper() + "  · NEW"})
	_list.set_items(items)
	var new_label: Label = _list._rows[-1].get_child(0)
	new_label.add_theme_color_override("font_color", UiKit.BLUE)
	_show_info(_moves[0] if not _moves.is_empty() else new_move)
	visible = true
	UiKit.sfx("menu_open")
	UiKit.pop_in(_win)
	_list.active = true
	return await picked


func _move_name(id: String) -> String:
	return String(Dex.move(id).get("name", id))


func _move_at(i: int) -> String:
	return _moves[i] if i < _moves.size() else _new_move


func _on_moved(i: int) -> void :
	_show_info(_move_at(i))


func _on_chosen(id: String) -> void :
	_pick(-1 if id == "new" or id == "gap" else int(id))


func _show_info(id: String) -> void :
	var mv: = Dex.move(id)
	var power: = int(mv.get("power", 0))
	var acc: = int(mv.get("accuracy", 0))
	var uses: = int(mv.get("uses", 0))
	_card.title = _move_name(id).to_upper()
	_card.set_rows([
		["TYPE", String(mv.get("type", "?")).to_upper()], 
		["CATEGORY", String(mv.get("category", "?")).to_upper()], 
		["POWER", str(power) if power > 0 else "—"], 
		["ACCURACY", str(acc) if acc > 0 else "—"], 
		["PP", str(uses) if uses > 0 else "—"], 
	])


func _pick(slot: int) -> void :
	if _closing:
		return
	_closing = true
	_list.active = false
	UiKit.sfx("menu_close")
	await UiKit.pop_out(_win)
	picked.emit(slot)
	queue_free()


func _process(delta: float) -> void :
	if _closing or not visible:
		return
	if Debug.auto_dialog:
		_auto_t += delta
		if _auto_t > 0.6:
			_auto_t = 0.0
			_pick(auto_pick if auto_pick >= 0 and auto_pick < _moves.size() else -1)
