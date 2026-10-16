class_name ControlsScreen
extends Control










signal closed


const ACTION_LABELS: = {
	"move_left": "Move left", "move_right": "Move right", 
	"move_up": "Move up", "move_down": "Move down", 
	"run": "Run", "jump": "Jump / Fly / Dive", "sprint": "Sprint (hold)", 
	"interact": "Interact", "party_ring": "Party ring", 
	"evo_cancel": "Stop evolution", 
	"move_1": "Move 1", "move_2": "Move 2", "move_3": "Move 3", "move_4": "Move 4", 
	"items_page": "Quick items (hold)", 
	"party_1": "Pokémon 1", "party_2": "Pokémon 2", "party_3": "Pokémon 3", 
	"party_4": "Pokémon 4", "party_5": "Pokémon 5", "party_6": "Pokémon 6", 
	"pause": "Battle pause", "confirm": "Confirm", "control_other": "Control other fighter", 
	"pk_pause": "Start menu", 
	"pk_up": "Menu up", "pk_down": "Menu down", "pk_left": "Menu left", "pk_right": "Menu right", 
	"pk_ok": "Confirm", "pk_back": "Back", "pk_start": "Name entry: jump to END", 
	"pk_prev": "Previous Pokémon", "pk_next": "Next Pokémon", "pk_alt": "Toggle IV/EV", 
}

const DIR_LETTERS: = {KEY_W: "W", KEY_A: "A", KEY_S: "S", KEY_D: "D"}
const DIR_ARROWS: = {KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→"}

const Controls: = preload("res://scripts/controls.gd")


const LEFT_LAYOUT: = [
	{"section": "OVERWORLD"}, 
	{"label": "Move", "actions": ["move_up", "move_left", "move_down", "move_right"]}, 
	{"actions": ["run"]}, 
	{"actions": ["interact"]}, 
	{"label": "Send out / recall", "actions": ["party_1", "party_2", "party_3", "party_4", "party_5", "party_6"]}, 
	{"actions": ["party_ring"]}, 
	{"actions": ["evo_cancel"]}, 
	{"actions": ["pk_pause"]}, 
	{"section": "MENUS"}, 
	{"label": "Navigate", "actions": ["pk_up", "pk_down"]}, 
	{"label": "Change", "actions": ["pk_left", "pk_right"]}, 
	{"actions": ["pk_ok"]}, 
	{"actions": ["pk_back"]}, 
	{"actions": ["pk_prev", "pk_next"]}, 
	{"actions": ["pk_alt"]}, 
	{"actions": ["pk_start"]}, 
]


const RIGHT_LAYOUT: = [
	{"section": "BATTLE"}, 
	{"label": "Move", "actions": ["move_up", "move_left", "move_down", "move_right"]}, 
	{"actions": ["sprint"]}, 
	{"actions": ["jump"], "note": "hop over ground moves"}, 
	{"label": "Moves", "actions": ["move_1", "move_2", "move_3", "move_4"], "note": "hold Z: quick items"}, 
	{"actions": ["items_page"]}, 
	{"label": "Switch Pokémon", "actions": ["party_1", "party_2", "party_3", "party_4", "party_5", "party_6"], 
		"note": "hold = 2nd fighter"}, 
	{"actions": ["party_ring"]}, 
	{"actions": ["pause"]}, 
	{"actions": ["confirm"]}, 
	{"actions": ["control_other"]}, 
]

const WIN_W: = 940.0
const BODY_H: = 430.0
const ROW_H: = 34.0
const HEADER_H: = 30.0
const LABEL_W: = 200.0

var active: = false

var _win: PkWindow
var _body: HBoxContainer
var _left: VBoxContainer
var _right: VBoxContainer
var _page_label: Label
var _pages: Array = []
var _page: = 0
var _armed_frame: = -1


func _init() -> void :
	theme = UiKit.theme()
	UiKit.setup_input()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim: = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_win = PkWindow.new()
	_win.title = "CONTROLS"
	_win.custom_minimum_size = Vector2(WIN_W, 0)
	center.add_child(_win)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_win.add_child(col)
	_page_label = Label.new()
	_page_label.theme_type_variation = "SmallLabel"
	_page_label.add_theme_color_override("font_color", UiKit.DIM)
	_page_label.text = "PAGE 1 / 1"
	col.add_child(_page_label)
	_body = HBoxContainer.new()
	_body.custom_minimum_size = Vector2(0, BODY_H)
	_body.add_theme_constant_override("separation", 36)
	col.add_child(_body)
	_left = _column()
	_body.add_child(_left)
	_right = _column()
	_body.add_child(_right)
	var hints: = PkHintBar.new()
	hints.set_hints([[["pk_left", "pk_right"], "Page"], ["pk_back", "Back"]])
	hints.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(hints)
	_build_pages()
	_show_page(0)


func _column() -> VBoxContainer:
	var c: = VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 4)
	return c



static func covered_actions() -> PackedStringArray:
	var out: = PackedStringArray()
	for layout in [LEFT_LAYOUT, RIGHT_LAYOUT]:
		for e in layout:
			if e.has("section"):
				continue
			for a in e.actions:
				var id: = String(a)
				if not out.has(id):
					out.append(id)
	return out




static func key_names(action: String) -> PackedStringArray:
	var out: = PackedStringArray()
	if not InputMap.has_action(action):
		return out
	for ev in InputMap.action_get_events(action):
		if not (ev is InputEventKey):
			continue
		var name: = Controls.event_label(ev)
		if name != "" and not out.has(name):
			out.append(name)
	return out





static func display_keys(actions: Array) -> PackedStringArray:
	if Controls.is_pad():
		return display_pad_keys(actions)
	var codes: Array = []
	for a in actions:
		for ev in InputMap.action_get_events(String(a)):
			if ev is InputEventKey:
				var code: Key = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
				if not codes.has(code):
					codes.append(code)
	var out: = PackedStringArray()
	if codes.size() >= 3 and _all_numbers(codes):
		out.append("%s-%s" % [OS.get_keycode_string(codes[0]), OS.get_keycode_string(codes[codes.size() - 1])])
		return out
	var letters: = 0
	var arrows: = 0
	var others: = 0
	for c in codes:
		if DIR_LETTERS.has(c):
			letters += 1
		elif DIR_ARROWS.has(c):
			arrows += 1
		else:
			others += 1
	if others == 0 and letters + arrows > 0:
		if letters > 0:
			out.append(_letter_cap(codes))
		if arrows > 0:
			out.append(_arrow_cap(codes))
		return out
	for c in codes:
		var n: = OS.get_keycode_string(c).replace("Escape", "Esc").replace("Kp Enter", "Enter")
		if n != "" and not out.has(n):
			out.append(n)
	return out


static func _all_numbers(codes: Array) -> bool:
	for c in codes:
		if int(c) < int(KEY_1) or int(c) > int(KEY_9):
			return false
	return true


static func _letter_cap(codes: Array) -> String:
	if codes.has(KEY_W) and codes.has(KEY_A) and codes.has(KEY_S) and codes.has(KEY_D):
		return "WASD"
	var parts: = PackedStringArray()
	for c in [KEY_W, KEY_A, KEY_S, KEY_D]:
		if codes.has(c):
			parts.append(String(DIR_LETTERS[c]))
	return "/".join(parts)


static func _arrow_cap(codes: Array) -> String:
	var all: = true
	for c in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		if not codes.has(c):
			all = false
	if all:
		return "↑↓←→"
	var parts: = PackedStringArray()
	for c in [KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]:
		if codes.has(c):
			parts.append(String(DIR_ARROWS[c]))
	return "".join(parts)



static func display_pad_keys(actions: Array) -> PackedStringArray:
	const DIRS: = ["move_left", "move_right", "move_up", "move_down"]
	var all_dirs: = actions.size() > 0
	for a in actions:
		if not DIRS.has(String(a)):
			all_dirs = false
	if all_dirs:
		return PackedStringArray(["L-stick"])
	var out: = PackedStringArray()
	for a in actions:
		var g: = Controls.pad_glyph(String(a))
		if g != "" and not out.has(g):
			out.append(g)
	return out


func page_count() -> int:
	return _pages.size()


func open() -> void :
	visible = true
	active = true
	_armed_frame = Engine.get_process_frames()
	_build_pages()
	_show_page(0)
	UiKit.sfx("menu_open")
	UiKit.pop_in(_win)


func _close() -> void :
	active = false
	UiKit.sfx("menu_close")
	await UiKit.pop_out(_win)
	visible = false
	_win.visible = true
	closed.emit()


func _show_page(i: int) -> void :
	if _pages.is_empty():
		return
	_page = wrapi(i, 0, _pages.size())
	for c in _left.get_children():
		_left.remove_child(c)
	for c in _right.get_children():
		_right.remove_child(c)
	for c in _pages[_page].left:
		_left.add_child(c)
	for c in _pages[_page].right:
		_right.add_child(c)
	_page_label.text = "PAGE %d / %d" % [_page + 1, _pages.size()]


func _unhandled_input(e: InputEvent) -> void :
	if not active or not is_visible_in_tree() or Engine.get_process_frames() == _armed_frame:
		return
	if e.is_action_pressed("pk_left"):
		_show_page(_page - 1)
		UiKit.sfx("cursor")
	elif e.is_action_pressed("pk_right"):
		_show_page(_page + 1)
		UiKit.sfx("cursor")
	elif e.is_action_pressed("pk_back"):
		_close()
	else:
		return
	get_viewport().set_input_as_handled()




func _build_pages() -> void :
	for c in _left.get_children():
		_left.remove_child(c)
		c.queue_free()
	for c in _right.get_children():
		_right.remove_child(c)
		c.queue_free()
	_pages.clear()
	var left: = _paginate(_entries(LEFT_LAYOUT))
	var right: = _paginate(_entries(RIGHT_LAYOUT))
	for i in maxi(left.size(), right.size()):
		_pages.append({
			"left": _build_controls(left[i]) if i < left.size() else [], 
			"right": _build_controls(right[i]) if i < right.size() else [], 
		})


func _build_controls(page: Array) -> Array:
	var ctrls: Array = []
	for e in page:
		ctrls.append(_make_header(String(e.section)) if e.type == "section" else _make_row(e))
	return ctrls



func _entries(layout: Array) -> Array:
	var out: Array = []
	var section: = ""
	for e in layout:
		if e.has("section"):
			section = String(e.section)
			out.append({"type": "section", "section": section})
		else:
			out.append({"type": "row", "section": section, "actions": e.actions, 
				"label": e.get("label", ""), "note": e.get("note", "")})
	return out



func _paginate(entries: Array) -> Array:
	var pages: Array = []
	var cur: Array = []
	var h: = 0.0
	for i in entries.size():
		var e: Dictionary = entries[i]
		if e.type == "section":
			var next_row: bool = i + 1 < entries.size() and entries[i + 1].type == "row"
			var need: = HEADER_H + (ROW_H if next_row else 0.0)
			if not cur.is_empty() and h + need > BODY_H:
				pages.append(cur)
				cur = []
				h = 0.0
			cur.append(e)
			h += HEADER_H
		else:
			if not cur.is_empty() and h + ROW_H > BODY_H:
				pages.append(cur)
				cur = []
				h = 0.0
				cur.append({"type": "section", "section": e.section})
				h = HEADER_H
			cur.append(e)
			h += ROW_H
	if not cur.is_empty():
		pages.append(cur)
	return pages


func _make_header(text: String) -> Control:
	var l: = Label.new()
	l.theme_type_variation = "HeaderLabel"
	l.add_theme_color_override("font_color", UiKit.BLUE)
	l.text = text
	l.custom_minimum_size = Vector2(0, HEADER_H)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _make_row(e: Dictionary) -> Control:
	var row: = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.add_theme_constant_override("separation", 6)
	var label: = Label.new()
	label.text = _row_label(e)
	label.custom_minimum_size = Vector2(LABEL_W, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	row.add_child(label)
	for name in display_keys(e.actions):
		row.add_child(PkHintBar.KeyCap.new(name))
	if String(e.get("note", "")) != "":
		var note: = Label.new()
		note.theme_type_variation = "SmallLabel"
		note.text = String(e.note)
		note.add_theme_color_override("font_color", UiKit.DIM)
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(note)
	return row


func _row_label(e: Dictionary) -> String:
	var l: = String(e.get("label", ""))
	if l != "":
		return l
	var acts: Array = e.actions
	return String(ACTION_LABELS.get(String(acts[0]), String(acts[0])))
