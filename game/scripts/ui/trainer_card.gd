class_name TrainerCard
extends PkWindow








signal closed

const PORTRAIT_PATH: = "res://assets/sprites/trainer.png"
const PORTRAIT_GREEN_PATH: = "res://assets/sprites/trainer_green.png"


const PORTRAIT_FRAME: = Rect2(8, 11, 16, 20)
const BADGE_DIR: = "res://assets/ui/badges/"

const BADGES: = [
	["boulder", "BOULDER"], ["cascade", "CASCADE"], ["thunder", "THUNDER"], ["rainbow", "RAINBOW"], 
	["soul", "SOUL"], ["marsh", "MARSH"], ["volcano", "VOLCANO"], ["earth", "EARTH"], 
]


@export var active: = false:
	set(v):
		active = v
		_armed_frame = Engine.get_process_frames()

var _front: = true
var _front_box: HBoxContainer
var _back_box: VBoxContainer
var _rows: GridContainer
var _time_value: Label
var _slots: Array = []
var _armed_frame: = -1
static var _portrait_tex: = {}


class BadgeSlot extends Control:


	var badge_id: = ""
	var earned: = false
	var _t: = 0.0
	static var _tex_cache: = {}

	func _ready() -> void :
		set_process(true)

	func _process(delta: float) -> void :
		if earned:
			_t += delta
			queue_redraw()

	func _draw() -> void :
		var c: = size * 0.5
		var r: = minf(size.x, size.y) * 0.42
		var tex: = _texture()
		if tex:
			draw_texture_rect(tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
		else:
			_draw_octagon(c, r)
		if earned:
			_draw_shine(c, r)

	func _texture() -> Texture2D:
		if _tex_cache.has(badge_id):
			return _tex_cache[badge_id]
		var p: = TrainerCard.BADGE_DIR + badge_id + ".png"
		var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
		_tex_cache[badge_id] = t
		return t

	func _draw_octagon(c: Vector2, r: float) -> void :
		var pts: = _ring(c, r)
		if earned:
			draw_colored_polygon(pts, Color("9aa0a8"))
			draw_colored_polygon(_ring(c, r * 0.72), Color("c8ccd4"))
		draw_polyline(_closed(pts), UiKit.INK if earned else UiKit.DIM, 3.0, true)

	func _draw_shine(c: Vector2, r: float) -> void :
		var s: = r * (0.2 + 0.05 * sin(_t * 3.0))
		var p: = c + Vector2(r * 0.42, - r * 0.42)
		var star: = PackedVector2Array([
			p + Vector2(0, - s * 2), p + Vector2(s * 0.5, - s * 0.5), p + Vector2(s * 2, 0), 
			p + Vector2(s * 0.5, s * 0.5), p + Vector2(0, s * 2), p + Vector2( - s * 0.5, s * 0.5), 
			p + Vector2( - s * 2, 0), p + Vector2( - s * 0.5, - s * 0.5)])
		draw_colored_polygon(star, Color(1, 1, 1, 0.8))

	func _ring(c: Vector2, r: float) -> PackedVector2Array:
		var pts: = PackedVector2Array()
		for i in 8:
			var a: = PI / 8.0 + TAU * float(i) / 8.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		return pts

	func _closed(pts: PackedVector2Array) -> PackedVector2Array:
		var out: = pts.duplicate()
		out.append(pts[0])
		return out


func _init() -> void :
	super ()
	title = "TRAINER CARD"
	custom_minimum_size = Vector2(440, 0)
	UiKit.setup_input()
	set_process(true)
	var root: = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	_build_front(root)
	_build_back(root)
	var hints: = PkHintBar.new()
	hints.set_hints([[["pk_left", "pk_right"], "Flip"], ["pk_back", "Close"]])
	root.add_child(hints)
	_update_sides()


func _build_front(parent: Control) -> void :
	_front_box = HBoxContainer.new()
	_front_box.add_theme_constant_override("separation", 20)
	parent.add_child(_front_box)
	var frame: = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiKit.pill(UiKit.RED_SOFT, UiKit.INK, 8))
	frame.custom_minimum_size = Vector2(112, 112)

	var pad: = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 11)
	pad.add_theme_constant_override("margin_right", 11)
	pad.add_theme_constant_override("margin_top", 11)
	pad.add_theme_constant_override("margin_bottom", 11)
	frame.add_child(pad)
	var portrait: = TextureRect.new()
	portrait.texture = _portrait()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pad.add_child(portrait)
	_front_box.add_child(frame)
	_rows = GridContainer.new()
	_rows.columns = 2
	_rows.add_theme_constant_override("h_separation", 40)
	_rows.add_theme_constant_override("v_separation", 8)
	_front_box.add_child(_rows)


func _build_back(parent: Control) -> void :
	_back_box = VBoxContainer.new()
	_back_box.add_theme_constant_override("separation", 14)
	parent.add_child(_back_box)
	var head: = Label.new()
	head.theme_type_variation = "HeaderLabel"
	head.text = "KANTO BADGES"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back_box.add_child(head)
	var grid: = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	_back_box.add_child(grid)
	for b in BADGES:
		grid.add_child(_make_slot(String(b[0]), String(b[1])))


func _make_slot(id: String, label: String) -> Control:
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var slot: = BadgeSlot.new()
	slot.badge_id = id
	slot.custom_minimum_size = Vector2(72, 72)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(slot)
	_slots.append(slot)
	var l: = Label.new()
	l.theme_type_variation = "SmallLabel"
	l.text = label
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	return col


func _portrait() -> Texture2D:
	var green: = Game.state.is_green()
	if _portrait_tex.has(green):
		return _portrait_tex[green]
	var at: = AtlasTexture.new()
	at.atlas = load(PORTRAIT_GREEN_PATH if green else PORTRAIT_PATH)
	at.region = PORTRAIT_FRAME
	_portrait_tex[green] = at
	return at





func open_card() -> void :
	preview(true)
	UiKit.pop_in(self)
	active = true



func preview(show_front: = true) -> void :
	_front = show_front
	refresh()
	_update_sides()
	visible = true
	active = false


func flip() -> void :
	if not visible:
		return
	_front = not _front
	UiKit.sfx("cursor")
	_update_sides()


func close() -> void :
	if not visible:
		return
	active = false
	visible = false
	closed.emit()



func refresh() -> void :
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	_row("NAME", Game.state.player_name)
	_row("RIVAL", Game.state.rival_name)
	_row("ID No.", Game.state.trainer_id)
	_row("MONEY", GameState.format_money(Game.state.money))
	if Game.flags.get("has_pokedex", false):
		_row("POKéDEX", "%d caught" % Game.state.dex_caught_count())
	_time_value = _row("PLAY TIME", GameState.format_time(Game.state.play_time))
	var started: = GameState.format_started(Game.state.started_at)
	if started != "":
		_row("STARTED", started)
	for s in _slots:
		s.earned = has_badge(s.badge_id)
		s.queue_redraw()



func has_badge(id: String) -> bool:
	return bool(Game.flags.get("%s_badge" % id, false)) or Game.state.badges.has(id)


func badge_count() -> int:
	var n: = 0
	for b in BADGES:
		if has_badge(String(b[0])):
			n += 1
	return n




func _row(key: String, value: String) -> Label:
	var k: = Label.new()
	k.text = key
	k.add_theme_color_override("font_color", UiKit.BLUE)
	_rows.add_child(k)
	var v: = Label.new()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(v)
	return v


func _update_sides() -> void :
	_front_box.visible = _front
	_back_box.visible = not _front


func _process(_delta: float) -> void :
	if visible and is_instance_valid(_time_value):
		_time_value.text = GameState.format_time(Game.state.play_time)


func _unhandled_input(e: InputEvent) -> void :
	if not active or not is_visible_in_tree() or Engine.get_process_frames() == _armed_frame:
		return
	if e.is_action_pressed("pk_left") or e.is_action_pressed("pk_right") or e.is_action_pressed("pk_ok"):
		flip()
	elif e.is_action_pressed("pk_back"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()
