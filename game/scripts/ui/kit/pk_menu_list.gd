class_name PkMenuList
extends VBoxContainer






signal chosen(id: String)
signal cancelled
signal moved(index: int)


signal disabled_chosen(id: String)

const ARROW_X: = 14.0

@export var active: = true:
	set(v):
		active = v
		_armed_frame = Engine.get_process_frames()
		queue_redraw()
@export var cancellable: = true

var items: Array = []
var index: = 0
var _rows: Array[Control] = []
var _t: = 0.0
var _armed_frame: = -1



class RowIcon extends Control:
	const UI: = preload("res://scripts/ui/ui_draw.gd")
	var id: = "":
		set(v):
			id = v
			queue_redraw()

	func _init(item_id: = "") -> void :
		id = item_id
		custom_minimum_size = Vector2(32, 32)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void :
		UI.item_icon(self, id, Rect2(Vector2.ZERO, size))


func _init() -> void :
	theme = UiKit.theme()
	add_theme_constant_override("separation", 2)
	UiKit.setup_input()
	add_to_group("pk_list")
	sort_children.connect(queue_redraw)


func set_items(list: Array) -> void :
	items = []
	for r in _rows:
		remove_child(r)
		r.queue_free()
	_rows.clear()
	for it in list:
		var d: Dictionary = it if it is Dictionary else {"id": str(it), "label": str(it)}
		items.append(d)
		var m: = MarginContainer.new()
		m.add_theme_constant_override("margin_left", 40)
		m.add_theme_constant_override("margin_right", 18)
		m.add_theme_constant_override("margin_top", 4)
		m.add_theme_constant_override("margin_bottom", 4)
		var l: = Label.new()
		l.text = String(d.get("label", d.get("id", "")))
		if d.get("disabled", false):
			l.add_theme_color_override("font_color", UiKit.DIM)
			l.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		if d.has("icon"):
			var h: = HBoxContainer.new()
			h.add_theme_constant_override("separation", 10)
			var ic: = RowIcon.new(String(d["icon"]))
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(ic)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(l)
			m.add_child(h)
		else:
			m.add_child(l)
		add_child(m)
		_rows.append(m)
	index = 0
	if not items.is_empty() and items[0].get("disabled", false):
		move(1)
	_armed_frame = Engine.get_process_frames()
	queue_redraw()


func selected_id() -> String:
	return "" if items.is_empty() else String(items[index].get("id", ""))



func index_at(gp: Vector2) -> int:
	for i in _rows.size():
		if _rows[i].get_global_rect().has_point(gp):
			return i
	return -1


func move(d: int) -> void :
	if items.is_empty():
		return
	var i: = index
	for _n in items.size():
		i = wrapi(i + d, 0, items.size())
		if not items[i].get("disabled", false):
			break
	if i != index and not items[i].get("disabled", false):
		index = i
		UiKit.sfx("cursor")
		moved.emit(index)
		queue_redraw()


func confirm() -> void :
	if items.is_empty():
		return
	if items[index].get("disabled", false):
		UiKit.sfx("error")
		disabled_chosen.emit(selected_id())
		return
	UiKit.sfx("confirm")
	chosen.emit(selected_id())


func back() -> void :
	if not cancellable:
		return
	UiKit.sfx("cancel")
	cancelled.emit()


func _process(delta: float) -> void :
	_t += delta
	if active and is_visible_in_tree():
		queue_redraw()


func _unhandled_input(e: InputEvent) -> void :
	if not active or not is_visible_in_tree() or Engine.get_process_frames() == _armed_frame:
		return
	if e.is_action_pressed("pk_up", true):
		move(-1)
	elif e.is_action_pressed("pk_down", true):
		move(1)
	elif e.is_action_pressed("pk_ok"):
		confirm()
	elif e.is_action_pressed("pk_back"):
		back()
	else:
		return
	get_viewport().set_input_as_handled()


func _draw() -> void :
	if items.is_empty() or index >= _rows.size():
		return
	var r: = _rows[index].get_rect()
	draw_style_box(UiKit.pill(UiKit.RED_SOFT, UiKit.RED, r.size.y * 0.5), r.grow_individual(-28, 0, 0, 0))
	if not active:
		return
	var c: = Vector2(ARROW_X + sin(_t * TAU * 1.5) * 2.0, r.get_center().y)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -8), c + Vector2(7, 0), c + Vector2(-6, 8)]), UiKit.INK)
