class_name PkNameEntry
extends PkWindow









signal done(name: String)

const MAX_LEN: = 7
const COLS: = 8
const ROWS: = 4
const KEYS: = [
	"A", "B", "C", "D", "E", "F", "G", "H", 
	"I", "J", "K", "L", "M", "N", "O", "P", 
	"Q", "R", "S", "T", "U", "V", "W", "X", 
	"Y", "Z", ".", ",", "-", "DEL", "SPACE", "END", 
]



var keys: Array = KEYS
var max_len: = MAX_LEN
var cols: = COLS
var rows: = ROWS
var _code_len: = 0

var _value: = ""
var _default: = ""
var _label: Label
var _grid: GridContainer
var _cells: Array[Label] = []
var _col: = 0
var _row: = 0
var _t: = 0.0
var _auto_t: = 0.0
var _armed_frame: = -1


func _init() -> void :
	super ()
	custom_minimum_size = Vector2(440, 0)
	UiKit.setup_input()
	set_process(true)
	add_to_group("text_entry")
	var root: = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	_label = Label.new()
	_label.theme_type_variation = "HeaderLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(0, 46)
	root.add_child(_label)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	root.add_child(_grid)
	_build_grid()
	var hints: = PkHintBar.new()
	hints.set_hints([["pk_ok", "Type"], ["pk_back", "Delete"], ["pk_start", "End"]])
	root.add_child(hints)
	visible = false



func _build_grid() -> void :
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_cells.clear()
	_grid.columns = cols
	for k in keys:
		var cell: = Label.new()
		cell.text = k
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.custom_minimum_size = Vector2(46, 40)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(cell)
		_cells.append(cell)



func ask(title_text: String, default_name: String) -> String:
	title = title_text
	_reset_grid(KEYS, MAX_LEN)
	_default = default_name
	_value = default_name
	_col = 0
	_row = 0
	_auto_t = 0.0
	_refresh()
	visible = true
	UiKit.pop_in(self)
	_armed_frame = Engine.get_process_frames()
	var n: String = await done
	return n




func ask_code(title_text: String, alphabet: String, length: int) -> String:
	title = title_text
	var a: Array = []
	for i in alphabet.length():
		a.append(alphabet[i])
	a.append_array(["DEL", "END"])
	_reset_grid(a, length)
	_code_len = length
	_default = ""
	_value = ""
	_col = 0
	_row = 0
	_auto_t = 0.0
	_refresh()
	visible = true
	UiKit.pop_in(self)
	_armed_frame = Engine.get_process_frames()
	var n: String = await done
	_code_len = 0
	return n



func _reset_grid(list: Array, length: int) -> void :
	keys = list
	max_len = length
	cols = COLS
	rows = int(ceil(keys.size() / float(cols)))
	_code_len = 0
	_build_grid()



func finish_now() -> void :
	if visible:
		_finish()



func value() -> String:
	return _value



func type(ch: String) -> void :
	_add(ch)


func _refresh() -> void :
	_label.text = _value + ("_" if _value.length() < max_len else "")


func _finish() -> void :
	if _code_len > 0 and _value.length() != _code_len:
		UiKit.sfx("error")
		return
	visible = false
	UiKit.sfx("confirm")
	done.emit(_value if _value != "" else _default)


func _add(ch: String) -> void :
	if _value.length() >= max_len:
		UiKit.sfx("error")
		return
	_value += ch
	UiKit.sfx("confirm")
	_refresh()



func _backspace() -> void :
	if _value == "":
		if _code_len > 0:
			visible = false
			UiKit.sfx("cancel")
			done.emit("")
			return
		UiKit.sfx("error")
		return
	_value = _value.substr(0, _value.length() - 1)
	UiKit.sfx("cancel")
	_refresh()



func _to_end() -> void :
	var i: int = keys.find("END")
	if i < 0:
		return
	_row = i / cols
	_col = i % cols
	UiKit.sfx("cursor")
	queue_redraw()



func _key_index() -> int:
	return mini(_row * cols + _col, _cells.size() - 1)


func _activate() -> void :
	var i: = _row * cols + _col
	if i >= keys.size():
		UiKit.sfx("error")
		return
	var k: String = keys[i]
	match k:
		"DEL":
			_backspace()
		"SPACE":
			_add(" ")
		"END":
			_finish()
		_:
			_add(k)


func _move(dx: int, dy: int) -> void :
	var c: = wrapi(_col + dx, 0, cols)
	var r: = wrapi(_row + dy, 0, rows)
	if c == _col and r == _row:
		return
	_col = c
	_row = r
	UiKit.sfx("cursor")
	queue_redraw()


func _process(delta: float) -> void :
	_t += delta
	if not visible:
		return
	queue_redraw()
	if Debug.auto_dialog:
		_auto_t += delta
		if _auto_t >= 0.6:
			_auto_t = 0.0
			_finish()


func _unhandled_input(e: InputEvent) -> void :
	if not visible or Engine.get_process_frames() == _armed_frame:
		return
	if e.is_action_pressed("pk_up"):
		_move(0, -1)
	elif e.is_action_pressed("pk_down"):
		_move(0, 1)
	elif e.is_action_pressed("pk_left"):
		_move(-1, 0)
	elif e.is_action_pressed("pk_right"):
		_move(1, 0)
	elif e.is_action_pressed("pk_ok"):
		_activate()
	elif e.is_action_pressed("pk_back"):
		_backspace()
	elif e.is_action_pressed("pk_start"):
		_to_end()
	else:
		return
	get_viewport().set_input_as_handled()


func _draw() -> void :
	super ()
	if _cells.is_empty():
		return
	var cell: = _cells[_key_index()]
	var pos: = cell.global_position - global_position
	draw_style_box(UiKit.pill(UiKit.RED_SOFT, UiKit.RED, 6), Rect2(pos, cell.size))
	if fmod(_t, 1.0) < 0.6:
		draw_circle(pos + cell.size * Vector2(0.5, 0.85), 2.5, UiKit.RED)






func _gui_input(e: InputEvent) -> void :
	if not visible:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var i: = _cell_at(get_global_transform() * e.position)
		if i < 0:
			return
		_row = i / cols
		_col = i % cols
		_activate()
		get_viewport().set_input_as_handled()



func _cell_at(gp: Vector2) -> int:
	for i in _cells.size():
		if _cells[i].get_global_rect().has_point(gp):
			return i
	return -1
