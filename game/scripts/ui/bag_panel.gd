extends Control












const Items: = preload("res://scripts/items.gd")
const BattleHud: = preload("res://scripts/ui/battle_hud.gd")

const Controls: = preload("res://scripts/controls.gd")

const WIN_POS: = Vector2(300, 50)
const WIN_SIZE: = Vector2(680, 620)
const TOSS_SIZE: = Vector2(236, 96)



class Arrows extends Control:
	func _init() -> void :
		custom_minimum_size = Vector2(20, 48)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void :
		var cx: = size.x * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 7, 15), Vector2(cx + 7, 15), Vector2(cx, 5)]), UiKit.INK)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 7, size.y - 15), Vector2(cx + 7, size.y - 15), Vector2(cx, size.y - 5)]), UiKit.INK)


var pocket: = 0
var sel: = 0
var mode: = "items"
var toss_qty: = 1
var _note: = ""
var _win: PkWindow
var _tabs: HBoxContainer
var _money: Label
var _quick: Array = []
var _list: PkMenuList
var _empty: Label
var _desc_box: PanelContainer
var _desc: Label
var _note_label: Label
var _toss_win: PkWindow
var _toss_icon
var _toss_qty: Label
var _hints: PkHintBar
var _hint_key: = ""
var _dialog: PkDialogBox


func _ready() -> void :
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	UiKit.setup_input()
	visible = false

	_win = PkWindow.new()
	_win.title = "BAG"
	_win.position = WIN_POS
	_win.size = WIN_SIZE
	add_child(_win)
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_win.add_child(v)

	var head: = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(_small("MONEY"))
	_money = Label.new()
	_money.add_theme_font_size_override("font_size", 22)
	_money.add_theme_color_override("font_color", UiKit.GREEN)
	_money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_money)
	var sp: = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(_small("QUICK SLOTS"))
	for k in 4:
		var s: = BattleHud.ItemSlot.new()
		s.index = k
		s.custom_minimum_size = Vector2(52, 52 + 16)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(s)
		_quick.append(s)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	v.add_child(_tabs)

	_list = PkMenuList.new()
	_list.active = false
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.chosen.connect(_on_chosen)
	v.add_child(_list)

	_empty = Label.new()
	_empty.visible = false
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty.add_theme_color_override("font_color", UiKit.DIM)
	_empty.text = "Nothing in this pocket."
	v.add_child(_empty)


	_desc_box = PanelContainer.new()
	var sb: = UiKit.pill(UiKit.PAPER, UiKit.RIM, 8)
	sb.set_border_width_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_desc_box.add_theme_stylebox_override("panel", sb)
	_desc_box.custom_minimum_size = Vector2(0, 62)
	v.add_child(_desc_box)
	var dv: = VBoxContainer.new()
	dv.add_theme_constant_override("separation", 2)
	_desc_box.add_child(dv)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_color_override("font_color", UiKit.INK)
	dv.add_child(_desc)
	_note_label = Label.new()
	_note_label.visible = false
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.add_theme_color_override("font_color", UiKit.AMBER)
	dv.add_child(_note_label)


	_hints = PkHintBar.new()
	_hints.position = Vector2(WIN_POS.x, WIN_POS.y + WIN_SIZE.y + 8)
	add_child(_hints)


	_toss_win = PkWindow.new()
	_toss_win.title = "TOSS"
	_toss_win.custom_minimum_size = TOSS_SIZE
	_toss_win.position = Vector2(WIN_POS.x + WIN_SIZE.x - TOSS_SIZE.x - 20, 
		WIN_POS.y + WIN_SIZE.y - 196)
	_toss_win.visible = false
	add_child(_toss_win)
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	_toss_win.add_child(tv)
	var q: = Label.new()
	q.theme_type_variation = "SmallLabel"
	q.text = "Toss how many?"
	tv.add_child(q)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	tv.add_child(row)
	row.add_child(Arrows.new())
	_toss_icon = PkMenuList.RowIcon.new()
	_toss_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_toss_icon)
	_toss_qty = Label.new()
	_toss_qty.add_theme_font_size_override("font_size", 26)
	_toss_qty.add_theme_color_override("font_color", UiKit.INK)
	_toss_qty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_toss_qty)

	_dialog = PkDialogBox.new()
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_dialog.offset_left = 120
	_dialog.offset_right = -120
	_dialog.offset_top = -190
	_dialog.offset_bottom = -30
	add_child(_dialog)


func _small(text: String) -> Label:
	var l: = Label.new()
	l.theme_type_variation = "SmallLabel"
	l.add_theme_color_override("font_color", UiKit.DIM)
	l.text = text
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _tab(text: String, active: bool) -> Control:
	var p: = PanelContainer.new()
	var sb: = UiKit.pill(UiKit.RED_SOFT if active else Color(UiKit.INK, 0.0), 
		UiKit.RED if active else Color.TRANSPARENT, 10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var l: = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", UiKit.INK if active else UiKit.DIM)
	l.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	p.add_child(l)
	return p




func open() -> void :
	visible = true
	mode = "items"
	_note = ""
	sel = 0

	if _ids().is_empty():
		for i in Items.POCKETS.size():
			pocket = i
			if not _ids().is_empty():
				break
	refresh()
	UiKit.pop_in(_win)



func demo(toss_mode: = false) -> void :
	Game.state.money = 3000
	var b: Dictionary = Game.state.bag
	b["potion"] = maxi(int(b.get("potion", 0)), 5)
	b["oaks_parcel"] = 1
	b["pokedex"] = 1
	visible = true
	mode = "items"
	pocket = 0
	sel = 0
	_note = ""
	_list.active = true
	refresh()
	if toss_mode:
		toss()



func modal() -> bool:
	return _dialog != null and _dialog.visible





func _ids() -> Array:
	var pk: String = Items.POCKETS[pocket][0]
	var out: Array = []
	for id in Items.all_ids():
		if Items.pocket_of(id) == pk and Game.item_count(id) > 0:
			out.append(id)
	for id in Game.bag.keys():
		if not out.has(id) and Items.pocket_of(id) == pk and Game.item_count(id) > 0:
			out.append(id)
	return out


func _selected() -> String:
	var ids: = _ids()
	return ids[sel] if sel < ids.size() else ""




func step_pocket(d: int) -> void :
	if mode != "items":
		return
	var np: = posmod(pocket + d, Items.POCKETS.size())
	if np == pocket:
		return
	pocket = np
	sel = 0
	Audio.ui("sfx/ui/cursor")
	refresh()


func step_item(d: int) -> void :
	if mode == "toss":
		toss_step(d)
		return
	_list.move(d)
	if _list.index != sel:
		sel = _list.index
		refresh()



func confirm() -> void :
	if mode == "toss":
		_ask_toss()
		return
	if _selected() != "":
		_list.confirm()


func _on_chosen(id: String) -> void :
	if id == "":
		return
	if Items.pocket_of(id) == "balls":
		Game.selected_ball = id
		var k: = 2
		for j in Game.quick_slots.size():
			if Game.quick_slots[j] != "" and Items.pocket_of(Game.quick_slots[j]) == "balls":
				k = j
				break
		assign_slot(k)
		return
	if Game.item_targets_party(id):
		if Game.party.is_empty():
			_fail("You don't have any POKéMON.")
		elif not Game.get_hud().open_party_pick(id):
			_fail("You don't have any POKéMON.")
		return
	var effect: Dictionary = Items.item(id).get("effect", {})
	if effect.has("repel"):
		Game.state.repel_steps = int(effect.get("repel", 100))
		Game.remove_item(id)
		_note = "Repel used! Wild Pokémon won't appear for a while."
		Audio.ui("sfx/ui/confirm")
		refresh()
		return
	if effect.has("escape"):
		Game.remove_item(id)
		_note = "Used an Escape Rope!"
		Audio.ui("sfx/ui/confirm")
		Game.use_escape_rope()
		refresh()
		return
	_fail("You can't use that here.")


func _fail(msg: String) -> void :
	_note = msg
	Audio.ui("sfx/ui/error")
	refresh()



func assign_slot(k: int) -> void :
	var id: = _selected()
	if id == "" or mode != "items":
		return
	if not Game.item_battle_usable(id):
		_note = "%s can't be used in battle." % Items.item_name(id)
	else:
		Game.set_quick_slot(k, id)
		Audio.ui("sfx/ui/quick_slot")
		_note = "%s → quick slot %s" % [Items.item_name(id), OS.get_keycode_string(Controls.ITEM_KEYS[k])]
	refresh()



func on_use_result(r: Dictionary) -> void :
	mode = "items"
	_note = String(r.get("text", ""))
	visible = true
	refresh()



func back() -> bool:
	if mode == "toss":
		mode = "items"
		_note = ""
		Audio.ui("sfx/ui/cancel")
		refresh()
		return true
	return false





func toss() -> bool:
	if mode != "items":
		return false
	var id: = _selected()
	if id == "":
		return false
	if Items.pocket_of(id) == "key":
		_note = "That's too important to toss!"
		Audio.ui("sfx/ui/error")
		refresh()
		return false
	toss_qty = 1
	mode = "toss"
	_note = ""
	Audio.ui("sfx/ui/cursor")
	refresh()
	return true



func toss_step(d: int) -> void :
	if mode != "toss":
		return
	var id: = _selected()
	var top: = maxi(Game.item_count(id), 1)
	var nq: = clampi(toss_qty + d, 1, top)
	if nq != toss_qty:
		toss_qty = nq
		Audio.ui("sfx/ui/cursor")
		refresh()



func confirm_toss() -> void :
	if mode != "toss":
		return
	var id: = _selected()
	if id == "":
		return
	_do_toss(id, mini(toss_qty, Game.item_count(id)))


func _ask_toss() -> void :
	var id: = _selected()
	if id == "":
		return
	var n: = mini(toss_qty, Game.item_count(id))
	if n <= 0:
		return
	var yes: bool = await _dialog.ask_yes_no("BAG", "Toss %d %s?" % [n, Items.item_name(id)])
	if yes:
		_do_toss(id, n)
	else:
		mode = "items"
		refresh()


func _do_toss(id: String, n: int) -> void :
	Game.remove_item(id, n)
	_note = "Tossed %d %s." % [n, Items.item_name(id)]
	mode = "items"
	Audio.ui("sfx/ui/confirm")
	refresh()




func _hints_for(m: String) -> Array:
	if m == "toss":
		return [[["pk_up", "pk_down"], "Amount"], ["pk_ok", "Toss"], ["pk_back", "Cancel"]]
	return [[["pk_left", "pk_right"], "Pocket"], 
		[["pk_up", "pk_down"], "Item"], 
		["pk_ok", "Use"], 
		["pk_alt", "Toss"], 
		[["move_1", "move_2", "move_3", "move_4"], "Quick"], 
		["pk_back", "Back"]]


func refresh() -> void :
	_money.text = GameState.format_money(Game.state.money)
	for s in _quick:
		s.queue_redraw()
	for c in _tabs.get_children():
		c.queue_free()
	for i in Items.POCKETS.size():
		_tabs.add_child(_tab(Items.POCKETS[i][1], i == pocket))
	if _hint_key != mode:
		_hint_key = mode
		_hints.set_hints(_hints_for(mode))
	var ids: = _ids()
	sel = clampi(sel, 0, maxi(ids.size() - 1, 0))
	var rows: Array = []
	for id in ids:
		var slot: = Game.quick_slots.find(id)
		var tag: = ("   [%s]" % OS.get_keycode_string(Controls.ITEM_KEYS[slot])) if slot >= 0 else ""
		rows.append({"id": id, "icon": id, 
			"label": "%s   ×%d%s" % [Items.item_name(id).to_upper(), Game.item_count(id), tag]})
	_list.set_items(rows)
	_list.index = clampi(sel, 0, maxi(rows.size() - 1, 0))
	_list.queue_redraw()
	_list.visible = not ids.is_empty()
	_empty.visible = ids.is_empty()
	var tossing: = mode == "toss" and not ids.is_empty()
	if ids.is_empty():
		_desc.text = ""
	elif tossing:
		_desc.text = "Toss %s?" % Items.item_name(ids[sel])
	else:
		_desc.text = String(Items.item(ids[sel]).get("description", ""))
	_note_label.text = _note
	_note_label.visible = _note != ""
	_toss_win.visible = tossing
	if tossing:
		_toss_icon.id = ids[sel]
		_toss_qty.text = "× %d" % toss_qty
