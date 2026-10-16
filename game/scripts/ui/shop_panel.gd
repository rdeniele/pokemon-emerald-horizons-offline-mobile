extends Control








const Items: = preload("res://scripts/items.gd")
const Shop: = preload("res://scripts/state/shop.gd")
const UiDraw: = preload("res://scripts/ui/ui_draw.gd")

const ROW_H: = 46.0

var shop_id: = "viridian"
var mode: = "menu"
var sell_mode: = false
var list_sel: = 0
var qty: = 1
var _ids: Array = []
var _busy: = false
var _open: = false

var _menu_window: PkWindow
var _menu: PkMenuList
var _money_window: PkWindow
var _money: Label
var _list_window: PkWindow
var _list_scroll: ScrollContainer
var _list: VBoxContainer
var _rows: Array = []
var _desc_window: PkWindow
var _desc_icon: Control
var _desc_text: Label
var _desc_bag: Label
var _qty_window: PkWindow
var _qty_label: Label
var _qty_price: Label
var _hints: PkHintBar




class ItemRow extends Control:
	const Items: = preload("res://scripts/items.gd")
	const Shop: = preload("res://scripts/state/shop.gd")
	const UiDraw: = preload("res://scripts/ui/ui_draw.gd")
	var id: = ""
	var selected: = false:
		set(v):
			selected = v
			queue_redraw()

	func _init(item_id: String) -> void :
		id = item_id
		custom_minimum_size = Vector2(0, 46)

	func _draw() -> void :
		var r: = Rect2(Vector2.ZERO, size)
		if selected:
			draw_style_box(UiKit.pill(UiKit.RED_SOFT, UiKit.RED, r.size.y * 0.5), r)
		var f: = UiKit.body_font()
		var fs: = UiKit.SIZE_BODY
		var baseline: = size.y * 0.5 + fs * 0.36
		if id == "":
			draw_string(f, Vector2(16, baseline), "CANCEL", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.INK)
			return
		UiDraw.item_icon(self, id, Rect2(Vector2(8, (size.y - 30) * 0.5), Vector2(30, 30)))
		draw_string(f, Vector2(48, baseline), Items.item_name(id), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.INK)
		draw_string(f, Vector2(size.x - 150, baseline), "₽%d" % Shop.price(id), HORIZONTAL_ALIGNMENT_RIGHT, 140, fs, UiKit.BLUE)



class IconView extends Control:
	const UiDraw: = preload("res://scripts/ui/ui_draw.gd")
	var id: = "":
		set(v):
			id = v
			queue_redraw()

	func _init() -> void :
		custom_minimum_size = Vector2(56, 56)

	func _draw() -> void :
		if id != "":
			UiDraw.item_icon(self, id, Rect2(Vector2.ZERO, size))


func _ready() -> void :
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.setup_input()


	_menu_window = PkWindow.new()
	_menu_window.title = "MART"
	_menu_window.position = Vector2(110, 40)
	_menu_window.size = Vector2(320, 200)
	add_child(_menu_window)
	var mv: = VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	_menu_window.add_child(mv)
	var clerk_line: = Label.new()
	clerk_line.theme_type_variation = "SmallLabel"
	clerk_line.text = "Hi there! May I help you?"
	clerk_line.add_theme_color_override("font_color", UiKit.BLUE)
	mv.add_child(clerk_line)
	_menu = PkMenuList.new()
	_menu.set_items([{"id": "buy", "label": "BUY"}, {"id": "sell", "label": "SELL"}, {"id": "quit", "label": "SEE YA!"}])
	_menu.chosen.connect(_on_menu)
	_menu.cancelled.connect(_close)
	mv.add_child(_menu)


	_money_window = PkWindow.new()
	_money_window.title = "MONEY"
	_money_window.position = Vector2(960, 20)
	_money_window.size = Vector2(280, 96)
	add_child(_money_window)
	_money = Label.new()
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money.add_theme_font_size_override("font_size", UiKit.SIZE_HEADER)
	_money.add_theme_color_override("font_color", UiKit.INK)
	_money_window.add_child(_money)


	_list_window = PkWindow.new()
	_list_window.title = "BUY"
	_list_window.position = Vector2(600, 128)
	_list_window.size = Vector2(640, 410)
	add_child(_list_window)
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_window.add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	_list_scroll.add_child(_list)


	_desc_window = PkWindow.new()
	_desc_window.position = Vector2(40, 552)
	_desc_window.size = Vector2(1200, 108)
	add_child(_desc_window)
	var dh: = HBoxContainer.new()
	dh.add_theme_constant_override("separation", 16)
	_desc_window.add_child(dh)
	_desc_icon = IconView.new()
	dh.add_child(_desc_icon)
	var dv: = VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_theme_constant_override("separation", 4)
	dh.add_child(dv)
	_desc_text = Label.new()
	_desc_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(_desc_text)
	_desc_bag = Label.new()
	_desc_bag.add_theme_color_override("font_color", UiKit.BLUE)
	dv.add_child(_desc_bag)


	_qty_window = PkWindow.new()
	_qty_window.title = "HOW MANY?"
	_qty_window.position = Vector2(600, 552)
	_qty_window.size = Vector2(360, 116)
	add_child(_qty_window)
	var qh: = HBoxContainer.new()
	qh.add_theme_constant_override("separation", 20)
	_qty_window.add_child(qh)
	_qty_label = Label.new()
	_qty_label.add_theme_font_size_override("font_size", UiKit.SIZE_HEADER)
	qh.add_child(_qty_label)
	_qty_price = Label.new()
	_qty_price.add_theme_font_size_override("font_size", UiKit.SIZE_HEADER)
	_qty_price.add_theme_color_override("font_color", UiKit.BLUE)
	_qty_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_qty_price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qh.add_child(_qty_price)

	_hints = PkHintBar.new()
	_hints.position = Vector2(40, 672)
	add_child(_hints)
	_hints.set_hints([[["pk_up", "pk_down"], "Row"], [["pk_left", "pk_right"], "±10"], ["pk_ok", "Select"], ["pk_back", "Back"]])

	visible = false


func hud() -> Node:
	return Game.get_hud()





func open(id: String) -> void :
	shop_id = id if id != "" else "viridian"
	mode = "menu"
	sell_mode = false
	list_sel = 0
	qty = 1
	_busy = false
	_open = true
	visible = true
	Game.menu_open = true
	var p: = Game.get_player()
	if p:
		p.controls_enabled = false
	_apply_mode()
	UiKit.sfx("menu_open")


func _close() -> void :
	_open = false
	visible = false
	Game.menu_open = false
	var p: = Game.get_player()
	if p:
		p.controls_enabled = true
	UiKit.sfx("menu_close")



func demo(sell: bool, qty_open: bool) -> void :
	open("viridian")
	if sell:
		for id in ["potion", "poke_ball", "antidote"]:
			if Game.item_count(id) == 0:
				Game.add_item(id, 3)
	_enter_list(sell)
	if qty_open:
		mode = "qty"
		qty = 1
		_apply_mode()
		_refresh_qty()




func _on_menu(id: String) -> void :
	match id:
		"quit":
			_close()
		"buy":
			_enter_list(false)
		"sell":
			_enter_list(true)


func _enter_list(sell: bool) -> void :
	sell_mode = sell
	_ids = _sellable_ids() if sell else Shop.stock(shop_id)
	list_sel = 0
	qty = 1
	mode = "list"
	_refresh_list()
	_apply_mode()



func _sellable_ids() -> Array:
	var out: Array = []
	for id in Items.all_ids():
		if Shop.sell_price(id) > 0 and Game.item_count(id) > 0:
			out.append(id)
	return out


func _apply_mode() -> void :
	_menu_window.visible = true
	_list_window.visible = mode != "menu"

	_desc_window.visible = mode == "list"
	_qty_window.visible = mode == "qty"
	_menu.active = mode == "menu" and not _busy
	_list_window.title = "SELL" if sell_mode else "BUY"
	_money.text = GameState.format_money(Game.state.money)


func _refresh_list() -> void :
	for r in _rows:
		if is_instance_valid(r):
			_list.remove_child(r)
			r.queue_free()
	_rows.clear()
	for id in _ids:
		var row: = ItemRow.new(id)
		_list.add_child(row)
		_rows.append(row)
	var cancel: = ItemRow.new("")
	_list.add_child(cancel)
	_rows.append(cancel)
	_refresh_selection()


func _refresh_selection() -> void :
	for i in _rows.size():
		_rows[i].selected = i == list_sel
	if list_sel < _rows.size():
		_list_scroll.ensure_control_visible(_rows[list_sel])
	_refresh_desc()
	_refresh_qty()


func _refresh_desc() -> void :
	if _ids.is_empty() or list_sel >= _ids.size():
		_desc_icon.id = ""
		_desc_text.text = "Which one would you like?"
		_desc_bag.text = ""
		return
	var id: String = _ids[list_sel]
	_desc_icon.id = id
	_desc_text.text = String(Items.item(id).get("description", ""))
	_desc_bag.text = "IN BAG: %d" % Game.item_count(id)


func _refresh_qty() -> void :
	if mode != "qty" or _ids.is_empty() or list_sel >= _ids.size():
		return
	var id: String = _ids[list_sel]
	var unit: = Shop.sell_price(id) if sell_mode else Shop.price(id)
	_qty_label.text = "×%02d" % qty
	_qty_price.text = GameState.format_money(unit * qty)




func _process(_delta: float) -> void :
	if not _open or _busy or mode == "menu":
		return
	if Input.is_action_just_pressed("pk_back"):
		_back()
	elif Input.is_action_just_pressed("pk_up"):
		_move(-1)
	elif Input.is_action_just_pressed("pk_down"):
		_move(1)
	elif Input.is_action_just_pressed("pk_left") and mode == "qty":
		_qty(-10)
	elif Input.is_action_just_pressed("pk_right") and mode == "qty":
		_qty(10)
	elif Input.is_action_just_pressed("pk_ok"):
		_ok()


func _move(d: int) -> void :
	if mode == "qty":
		_qty(d)
		return
	list_sel = posmod(list_sel + d, _ids.size() + 1)
	UiKit.sfx("cursor")
	_refresh_selection()


func _qty(d: int) -> void :
	if _ids.is_empty() or list_sel >= _ids.size():
		return
	var id: String = _ids[list_sel]
	qty = Shop.max_sell(Game.state, id, qty + d) if sell_mode else Shop.max_buy(Game.state, id, qty + d)
	UiKit.sfx("cursor")
	_refresh_qty()


func _ok() -> void :
	if mode == "list":
		if list_sel >= _ids.size():
			mode = "menu"
			_apply_mode()
			UiKit.sfx("cancel")
		else:
			mode = "qty"
			qty = 1
			_apply_mode()
			_refresh_qty()
			UiKit.sfx("confirm")
	else:
		_confirm()


func _back() -> void :
	if mode == "qty":
		mode = "list"
	elif mode == "list":
		mode = "menu"
	else:
		_close()
		return
	_apply_mode()
	UiKit.sfx("cancel")


func _say(line: String) -> void :
	var h: = hud()
	if h == null:
		return
	h.open_dialog("Clerk", PackedStringArray([line]))
	await h.dialog_closed


func _confirm() -> void :
	if _ids.is_empty() or list_sel >= _ids.size():
		return
	var h: = hud()
	if h == null:
		return
	var id: String = _ids[list_sel]
	var n: = qty
	_busy = true
	if sell_mode:
		var total: = Shop.sell_price(id) * n
		if await h.ask_yes_no("Clerk", "I can pay %s. Would that be okay?" % GameState.format_money(total)):
			var ok: = Shop.sell(Game.state, id, n)
			await _say("Here's your money. Thank you!" if ok else "Oh, no. I can't buy that.")
			if ok:
				Analytics.track("shop_transaction", {"mode": "sell", "item": id, "qty": n, 
					"price_total": total, "money_after": Game.state.money})
	else:
		var total: = Shop.price(id) * n
		var q: = "%s, and you want %d. That will be %s. Okay?" % [Items.item_name(id), n, GameState.format_money(total)]
		if await h.ask_yes_no("Clerk", q):
			var ok: = Shop.buy(Game.state, id, n)
			await _say("Here you are! Thank you!" if ok else "You don't have enough money.")
			if ok:
				Analytics.track("shop_transaction", {"mode": "buy", "item": id, "qty": n, 
					"price_total": total, "money_after": Game.state.money})
	_busy = false

	if sell_mode:
		_ids = _sellable_ids()
		if _ids.is_empty():
			mode = "menu"
			_apply_mode()
			return
		list_sel = clampi(list_sel, 0, _ids.size())
		_refresh_list()
	else:
		mode = "list"
		_refresh_selection()
	_apply_mode()
	qty = 1
