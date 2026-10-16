class_name PkGenderPick
extends PkWindow







signal done(gender: String)

const OPTIONS: = [
	{"id": "red", "label": "BOY", "sheet": "res://assets/sprites/trainer.png"}, 
	{"id": "green", "label": "GIRL", "sheet": "res://assets/sprites/trainer_green.png"}, 
]

const FRAME: = Rect2(8, 11, 16, 20)
const PIXEL: = 7.0
const AUTO_SECS: = 0.6

var index: = 0
var _cards: Array[Control] = []
var _t: = 0.0
var _auto_t: = 0.0
var _armed_frame: = -1


func _init() -> void :
	super ()
	UiKit.setup_input()
	title = "Are you a boy? Or are you a girl?"
	custom_minimum_size = Vector2(440, 0)
	set_process(true)
	var root: = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var row: = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 48)
	root.add_child(row)
	for o in OPTIONS:
		row.add_child(_card(o))
	var hints: = PkHintBar.new()
	hints.set_hints([[["pk_left", "pk_right"], "Choose"], ["pk_ok", "OK"]])
	root.add_child(hints)
	visible = false



func _card(o: Dictionary) -> Control:
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var at: = AtlasTexture.new()
	at.atlas = load(String(o["sheet"]))
	at.region = FRAME
	var portrait: = TextureRect.new()
	portrait.texture = at
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.custom_minimum_size = FRAME.size * PIXEL
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(portrait)
	var l: = Label.new()
	l.text = String(o["label"])
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	_cards.append(col)
	return col



func ask(default_gender: = "red") -> String:
	index = 0 if default_gender != "green" else 1
	_auto_t = 0.0
	_refresh()
	visible = true
	UiKit.pop_in(self)
	_armed_frame = Engine.get_process_frames()
	var g: String = await done
	return g


func _refresh() -> void :
	for i in _cards.size():

		_cards[i].modulate = Color(1, 1, 1) if i == index else Color(0.8, 0.8, 0.85)
	queue_redraw()


func _finish() -> void :
	visible = false
	UiKit.sfx("confirm")
	done.emit(String(OPTIONS[index]["id"]))


func _move(d: int) -> void :
	var i: = wrapi(index + d, 0, OPTIONS.size())
	if i == index:
		return
	index = i
	UiKit.sfx("cursor")
	_refresh()


func _process(delta: float) -> void :
	_t += delta
	if not visible:
		return
	queue_redraw()
	if Debug.auto_dialog:
		_auto_t += delta
		if _auto_t >= AUTO_SECS:
			_auto_t = 0.0
			_finish()


func _unhandled_input(e: InputEvent) -> void :
	if not visible or Engine.get_process_frames() == _armed_frame:
		return
	if e.is_action_pressed("pk_left") or e.is_action_pressed("pk_up"):
		_move(-1)
	elif e.is_action_pressed("pk_right") or e.is_action_pressed("pk_down"):
		_move(1)
	elif e.is_action_pressed("pk_ok") or e.is_action_pressed("pk_back"):
		_finish()
	else:
		return
	get_viewport().set_input_as_handled()


func _draw() -> void :
	super ()
	if _cards.is_empty():
		return
	var frame: = _cards[index].get_child(0) as Control
	var pos: = frame.global_position - global_position
	draw_style_box(UiKit.pill(UiKit.RED_SOFT, UiKit.RED, 8), Rect2(pos, frame.size).grow(9))

	var c: = Vector2(pos.x - 18, pos.y + frame.size.y * 0.5 + sin(_t * TAU * 1.5) * 2.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -7), c + Vector2(7, 0), c + Vector2(-4, 7)]), 
		UiKit.RED)
