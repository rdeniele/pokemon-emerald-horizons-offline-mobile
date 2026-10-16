class_name PkOptionList
extends VBoxContainer



signal cancelled

@export var active: = true:
	set(v):
		active = v
		_armed_frame = Engine.get_process_frames()

var rows: Array[PkOptionRow] = []
var index: = 0
var _armed_frame: = -1


func _init() -> void :
	theme = UiKit.theme()
	add_theme_constant_override("separation", 6)
	UiKit.setup_input()
	add_to_group("pk_list")



func index_at(gp: Vector2) -> int:
	for i in rows.size():
		if rows[i].get_global_rect().has_point(gp):
			return i
	return -1


func add_row(r: PkOptionRow) -> void :
	rows.append(r)
	add_child(r)
	_refresh()


func move(d: int) -> void :
	if rows.is_empty():
		return
	index = wrapi(index + d, 0, rows.size())
	UiKit.sfx("cursor")
	_refresh()


func step(d: int) -> void :
	if not rows.is_empty():
		rows[index].step(d)


func _refresh() -> void :
	for i in rows.size():
		rows[i].selected = i == index


func _unhandled_input(e: InputEvent) -> void :
	if not active or not is_visible_in_tree() or Engine.get_process_frames() == _armed_frame:
		return
	if e.is_action_pressed("pk_up", true):
		move(-1)
	elif e.is_action_pressed("pk_down", true):
		move(1)
	elif e.is_action_pressed("pk_left", true):
		step(-1)
	elif e.is_action_pressed("pk_right", true):
		step(1)
	elif e.is_action_pressed("pk_ok"):
		if rows[index].kind == PkOptionRow.Kind.ACTION:
			rows[index].activated.emit()
		else:
			step(1)
	elif e.is_action_pressed("pk_back"):
		UiKit.sfx("cancel")
		cancelled.emit()
	else:
		return
	get_viewport().set_input_as_handled()
