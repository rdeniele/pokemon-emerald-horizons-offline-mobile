class_name DemoEndCard
extends Control









signal choice(action: String)

const PokemonSprites: = preload("res://scripts/pokemon_sprites.gd")

var active: = false:
	set(v):
		active = v
		_armed_frame = Engine.get_process_frames()

var _armed_frame: = -1
var _win: PkWindow
var _name_value: Label
var _time_value: Label
var _dex_value: Label
var _badge: TrainerCard.BadgeSlot
var _party_row: HBoxContainer


func _init() -> void :
	theme = UiKit.theme()
	UiKit.setup_input()
	name = "DemoEndCard"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var bg: = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.62)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center: = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_win = PkWindow.new()
	_win.custom_minimum_size = Vector2(780, 0)
	center.add_child(_win)
	var root: = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	_win.add_child(root)

	var top_pad: = Control.new()
	top_pad.custom_minimum_size = Vector2(0, 6)
	root.add_child(top_pad)

	var title: = Label.new()
	title.theme_type_variation = "TitleLabel"
	title.text = "THANKS FOR PLAYING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var sub: = Label.new()
	sub.theme_type_variation = "SmallLabel"
	sub.text = "POKéMON · BATTLE ADVANCED"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", UiKit.DIM)
	root.add_child(sub)


	var top: = HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	root.add_child(top)
	_badge = TrainerCard.BadgeSlot.new()
	_badge.badge_id = "boulder"
	_badge.custom_minimum_size = Vector2(72, 72)
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_badge)
	var rows: = GridContainer.new()
	rows.columns = 2
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("h_separation", 40)
	rows.add_theme_constant_override("v_separation", 6)
	top.add_child(rows)
	_name_value = _row(rows, "NAME")
	_time_value = _row(rows, "PLAY TIME")
	_dex_value = _row(rows, "POKéDEX")

	var party_label: = Label.new()
	party_label.theme_type_variation = "SmallLabel"
	party_label.text = "YOUR PARTY"
	party_label.add_theme_color_override("font_color", UiKit.BLUE)
	root.add_child(party_label)
	_party_row = HBoxContainer.new()
	_party_row.add_theme_constant_override("separation", 12)
	root.add_child(_party_row)

	var tail: = Label.new()
	tail.text = "Your adventure continues in the full game. Feel free to keep exploring!"
	tail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(tail)

	var hints: = PkHintBar.new()
	hints.set_hints([["pk_ok", "Continue"], ["pk_back", "Title"]])
	root.add_child(hints)


func _row(parent: Control, key: String) -> Label:
	var k: = Label.new()
	k.text = key
	k.add_theme_color_override("font_color", UiKit.BLUE)
	parent.add_child(k)
	var v: = Label.new()
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	return v



func open() -> void :
	refresh()
	visible = true
	active = true
	UiKit.pop_in(_win)


func refresh() -> void :
	_name_value.text = Game.state.player_name
	_time_value.text = GameState.format_time(Game.state.play_time)
	_dex_value.text = "%d seen / %d caught" % [Game.state.dex_seen_count(), Game.state.dex_caught_count()]
	_badge.earned = Game.state.badges.has("boulder") or bool(Game.flags.get("boulder_badge", false))
	_badge.queue_redraw()
	for c in _party_row.get_children():
		_party_row.remove_child(c)
		c.queue_free()
	for m in Game.party:
		_party_row.add_child(_party_cell(m))


func _party_cell(m) -> Control:
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var icon: = TextureRect.new()
	icon.texture = PokemonSprites.icon_fitted(String(m.species), 64)
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	col.add_child(icon)
	var lv: = Label.new()
	lv.theme_type_variation = "SmallLabel"
	lv.text = "Lv %d" % int(m.level)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lv)
	return col



func press(action: String) -> void :
	Analytics.track("demo_end_choice", {"action": action})
	if action == "title":
		active = false
		choice.emit("title")
	else:
		active = false
		choice.emit("continue")


func _unhandled_input(e: InputEvent) -> void :
	if not active or not is_visible_in_tree() or Engine.get_process_frames() == _armed_frame:
		return
	if e.is_action_pressed("pk_ok"):
		get_viewport().set_input_as_handled()
		press("continue")
	elif e.is_action_pressed("pk_back"):
		get_viewport().set_input_as_handled()
		press("title")
