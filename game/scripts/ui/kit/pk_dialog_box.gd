class_name PkDialogBox
extends PkWindow






signal line_done
signal finished
signal answered(yes: bool)

var auto_advance: = 0.0

var _label: Label
var _lines: PackedStringArray = []
var _i: = 0
var _chars: = 0.0
var _blip: = 0
var _complete: = false
var _asking: = false
var _open_frame: = -1
var _done_t: = 0.0
var _t: = 0.0
var _choice_win: PkWindow
var _choice: PkMenuList


func _init() -> void :
	super ()
	custom_minimum_size = Vector2(0, 150)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_label)
	_choice_win = PkWindow.new()
	_choice_win.top_level = true
	_choice_win.visible = false
	add_child(_choice_win)
	_choice = PkMenuList.new()
	_choice.set_items([{"id": "yes", "label": "YES"}, {"id": "no", "label": "NO"}])
	_choice.active = false
	_choice.chosen.connect( func(id): _answer(id == "yes"))
	_choice.cancelled.connect( func(): _answer(false))
	_choice_win.add_child(_choice)
	visible = false
	UiKit.setup_input()


func say(speaker: String, lines: Array) -> void :
	_open(speaker, lines)
	await finished


func ask_yes_no(speaker: String, question: String) -> bool:
	_open(speaker, [question])
	_asking = true
	var yes: bool = await answered
	return yes


func current_line() -> int:
	return _i



func is_choice_open() -> bool:
	return _choice_win.visible




func choice_tap(gp: Vector2) -> bool:
	if not _choice_win.visible:
		return false
	var i: = _choice.index_at(gp)
	if i < 0:
		return false
	_choice.index = i
	_choice.confirm()
	return true


func line_complete() -> bool:
	return _complete


func _open(speaker: String, lines: Array) -> void :
	_lines = PackedStringArray(lines) if not lines.is_empty() else PackedStringArray(["..."])
	_i = 0
	_asking = false
	_choice_win.visible = false
	_choice.active = false
	title = speaker
	visible = true
	_open_frame = Engine.get_process_frames()
	_show_line()


func _show_line() -> void :
	_label.text = _lines[_i]
	_label.visible_characters = 0
	_chars = 0.0
	_blip = 0
	_complete = false
	_done_t = 0.0
	if Settings.text_instant():
		_finish_line()


func _finish_line() -> void :
	_label.visible_characters = -1
	_complete = true
	_done_t = 0.0
	line_done.emit()
	if _asking:
		_show_choice()


func _show_choice() -> void :
	_choice_win.reset_size()
	var w: = _choice_win.get_combined_minimum_size()
	_choice_win.global_position = global_position + Vector2(size.x - w.x - 12, - w.y - 10)
	_choice.index = 0
	_choice_win.visible = true
	_choice.active = true
	UiKit.pop_in(_choice_win)


func _answer(yes: bool) -> void :
	_choice.active = false
	close()
	answered.emit(yes)


func advance() -> void :
	if not visible:
		return
	if not _complete:
		_finish_line()
		return
	if _asking:
		return
	_i += 1
	UiKit.sfx("confirm")
	if _i >= _lines.size():
		close()
		finished.emit()
	else:
		_show_line()


func close() -> void :
	visible = false
	_choice_win.visible = false
	_asking = false




func skip() -> void :
	if not visible:
		return
	if _asking:
		_answer(false)
	else:
		close()
		finished.emit()


func _process(delta: float) -> void :
	_t += delta
	if not visible:
		return
	if not _complete:
		_chars += delta * Settings.text_cps()
		_label.visible_characters = int(_chars)
		if _label.visible_characters - _blip >= 3:
			_blip = _label.visible_characters
			UiKit.sfx("text_blip")
		if _label.visible_characters >= _label.get_total_character_count():
			_finish_line()
	else:
		var auto: = auto_advance if auto_advance > 0.0 else (0.4 if Debug.auto_dialog else 0.0)
		if auto > 0.0:
			_done_t += delta
			if _done_t >= auto:
				if _asking and _choice_win.visible:
					_choice.index = 0
					_choice.confirm()
				elif not _asking:
					advance()
	queue_redraw()


func _unhandled_input(e: InputEvent) -> void :
	if not visible or _choice_win.visible or Engine.get_process_frames() == _open_frame:
		return
	if e.is_action_pressed("pk_ok") or e.is_action_pressed("pk_back"):
		advance()
		get_viewport().set_input_as_handled()


func _draw() -> void :
	super ()
	if visible and _complete and not _asking:
		var c: = Vector2(size.x - 34, size.y - 26 + sin(_t * TAU * 1.5) * 3.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -5), c + Vector2(8, -5), c + Vector2(0, 6)]), UiKit.RED)
