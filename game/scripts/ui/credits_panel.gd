class_name CreditsPanel
extends Control




signal closed

const CREDITS: = "res://data/credits.json"
const WINDOW: = Vector2(620, 534)
const IDLE_BEFORE_SCROLL: = 1.5
const PAUSE_AFTER_INPUT: = 3.0
const AUTO_SCROLL: = 30.0

var _win: PkWindow
var _scroll: ScrollContainer
var _wait: = IDLE_BEFORE_SCROLL
var _acc: = 0.0


func _init() -> void :
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim: = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_win = PkWindow.new()
	_win.title = "CREDITS"
	_win.custom_minimum_size = WINDOW
	center.add_child(_win)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_win.add_child(col)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	var body: = VBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)
	_fill(body)
	var hints: = PkHintBar.new()
	hints.set_hints([[["pk_up", "pk_down"], "Scroll"], ["pk_back", "Back"]])
	hints.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(hints)


func _fill(body: VBoxContainer) -> void :
	var data = JSON.parse_string(FileAccess.get_file_as_string(CREDITS))
	if not data is Dictionary:
		push_warning("[credits] %s did not parse" % CREDITS)
		return
	for section in data.get("sections", []):
		var head: = Label.new()
		head.theme_type_variation = "HeaderLabel"
		head.text = String(section.get("title", ""))
		head.add_theme_color_override("font_color", UiKit.BLUE)
		body.add_child(head)
		for line in section.get("lines", []):
			var l: = _line(String(line), UiKit.SIZE_SMALL, UiKit.INK)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.add_child(l)
		for e in section.get("entries", []):
			body.add_child(_entry(String(e.get("name", "")), String(e.get("detail", ""))))


func _line(text: String, size: int, color: Color) -> Label:
	var l: = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l



func _entry(name: String, detail: String) -> HBoxContainer:
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var n: = _line(name, UiKit.SIZE_BODY, UiKit.INK)
	n.custom_minimum_size.x = 220
	n.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(n)
	var d: = _line(detail, UiKit.SIZE_SMALL, UiKit.DIM)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(d)
	return row


func open() -> void :
	_wait = IDLE_BEFORE_SCROLL
	_scroll.scroll_vertical = 0
	visible = true
	UiKit.sfx("menu_open")
	UiKit.pop_in(_win)


func _close() -> void :
	UiKit.sfx("menu_close")
	await UiKit.pop_out(_win)
	visible = false
	closed.emit()


func _unhandled_input(e: InputEvent) -> void :
	if not visible:
		return
	if e.is_action_pressed("pk_back"):
		_close()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("pk_up", true) or e.is_action_pressed("pk_down", true):
		_nudge(-60.0 if e.is_action_pressed("pk_up", true) else 60.0)



func _input(e: InputEvent) -> void :
	if visible and e is InputEventMouseButton and e.pressed\
	and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_wait = PAUSE_AFTER_INPUT


func _nudge(by: float) -> void :
	_scroll.scroll_vertical += int(by)
	_acc = 0.0
	_wait = PAUSE_AFTER_INPUT


func _process(delta: float) -> void :
	if not visible:
		return
	if _wait > 0.0:
		_wait -= delta
		return

	_acc += AUTO_SCROLL * delta
	var step: = int(_acc)
	if step > 0:
		_scroll.scroll_vertical += step
		_acc -= step
