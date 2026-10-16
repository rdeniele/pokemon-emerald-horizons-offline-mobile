extends Control












const Dex: = preload("res://scripts/dex.gd")
const PokemonSprites: = preload("res://scripts/pokemon_sprites.gd")

const ENCOUNTER_DIR: = "res://data/encounters"
const ROW_H: = 30



class BallMark extends Control:
	const UI: = preload("res://scripts/ui/ui_draw.gd")
	var on: = false:
		set(v):
			on = v
			queue_redraw()
	func _init() -> void :
		custom_minimum_size = Vector2(20, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void :
		if on:
			UI.item_icon(self, "poke_ball", Rect2(Vector2.ZERO, size))


static var _areas: = {}
static var _areas_loaded: = false

var mode: = "list"
var selected: = 0
var entries: Array = []
var entry_species: = ""

var _win: Control
var _header: Label
var _list_view: Control
var _scroll: ScrollContainer
var _rows_box: VBoxContainer
var _rows: Array = []
var _entry_view: Control
var _sprite: TextureRect
var _no: Label
var _name: Label
var _category: Label
var _types: HBoxContainer
var _height: Label
var _weight: Label
var _flavor: Label
var _cry: Button
var _area: Label
var _hints: PkHintBar
var _cry_slot: = ""
var _armed_frame: = -1


func _ready() -> void :
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	refresh_list()


func _build() -> void :
	_win = PkWindow.new()
	_win.title = "POKéDEX"
	_win.anchor_left = 0.5
	_win.anchor_right = 0.5
	_win.anchor_top = 0.5
	_win.anchor_bottom = 0.5
	_win.offset_left = -390
	_win.offset_right = 390
	_win.offset_top = -300
	_win.offset_bottom = 300
	add_child(_win)
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_win.add_child(v)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 20)
	_header.add_theme_color_override("font_color", UiKit.INK)
	v.add_child(_header)


	_list_view = VBoxContainer.new()
	_list_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_list_view)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 440)
	_list_view.add_child(_scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 0)
	_scroll.add_child(_rows_box)


	_entry_view = VBoxContainer.new()
	_entry_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entry_view.add_theme_constant_override("separation", 12)
	_entry_view.visible = false
	v.add_child(_entry_view)
	var top: = HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	_entry_view.add_child(top)
	_sprite = TextureRect.new()
	_sprite.custom_minimum_size = Vector2(225, 225)
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top.add_child(_sprite)
	var info: = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	top.add_child(info)
	_no = _label(18, UiKit.BLUE)
	info.add_child(_no)
	_name = Label.new()
	_name.theme_type_variation = "HeaderLabel"
	info.add_child(_name)
	_category = _label(18, UiKit.INK)
	info.add_child(_category)
	_types = HBoxContainer.new()
	_types.add_theme_constant_override("separation", 8)
	info.add_child(_types)
	_height = _label(18, UiKit.INK)
	info.add_child(_height)
	_weight = _label(18, UiKit.INK)
	info.add_child(_weight)
	_cry = Button.new()
	_cry.text = "♪ CRY"
	_cry.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_cry.pressed.connect(_play_cry)
	top.add_child(_cry)
	_flavor = Label.new()
	_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flavor.custom_minimum_size = Vector2(0, 60)
	_flavor.add_theme_font_size_override("font_size", 19)
	_flavor.add_theme_constant_override("line_spacing", 6)
	_entry_view.add_child(_flavor)
	_area = _label(18, UiKit.INK)
	_entry_view.add_child(_area)

	_hints = PkHintBar.new()
	_hints.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(_hints)


func _label(size: int, col: Color) -> Label:
	var l: = Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l




func open() -> void :
	visible = true
	mode = "list"
	_list_view.visible = true
	_entry_view.visible = false
	Game.menu_open = true
	var p: = Game.get_player()
	if p:
		p.controls_enabled = false
	refresh_list()
	UiKit.sfx("menu_open")
	UiKit.pop_in(_win)
	_armed_frame = Engine.get_process_frames()


func close() -> void :
	if not visible:
		return
	visible = false
	mode = "list"
	entry_species = ""
	Game.menu_open = false
	var p: = Game.get_player()
	if p and not Game.cutscene:
		p.controls_enabled = true
	UiKit.sfx("menu_close")



func back() -> bool:
	if mode == "entry":
		mode = "list"
		_list_view.visible = true
		_entry_view.visible = false
		Audio.ui("sfx/ui/cancel")
		_highlight()
		_update_hints()
		return true
	close()
	return false


func _unhandled_input(e: InputEvent) -> void :
	if not visible or not is_visible_in_tree() or Engine.get_process_frames() == _armed_frame:
		return
	var handled: = true
	if mode == "entry":
		if e.is_action_pressed("pk_back"):
			back()
		elif e.is_action_pressed("pk_up"):
			step_entry(-1)
		elif e.is_action_pressed("pk_down"):
			step_entry(1)
		elif e.is_action_pressed("pk_ok"):
			_play_cry()
		else:
			handled = false
	else:
		if e.is_action_pressed("pk_up"):
			step(-1)
		elif e.is_action_pressed("pk_down"):
			step(1)
		elif e.is_action_pressed("pk_ok"):
			confirm()
		elif e.is_action_pressed("pk_back"):
			back()
		else:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()





func refresh_list() -> void :
	_rebuild_entries()
	_header.text = "SEEN %d / OWN %d" % [Game.state.dex_seen_count(), Game.state.dex_caught_count()]
	for r in _rows:
		r.node.queue_free()
	_rows.clear()
	for e in entries:
		_rows.append(_make_row(e))
	selected = 0
	for i in entries.size():
		if String(entries[i].species) != "":
			selected = i
			break
	_highlight()
	_update_hints()


func _rebuild_entries() -> void :
	var names: = {}
	for k in Game.state.dex_seen:
		names[k] = true
	for k in Game.state.dex_caught:
		names[k] = true
	var by_no: = {}
	var highest: = 0
	for k in names:
		var sp: = Dex.species(String(k))
		if sp.is_empty():
			continue
		var n: = int(sp.get("dex_no", 0))
		if n <= 0:
			continue
		by_no[n] = String(k)
		highest = maxi(highest, n)
	entries = []
	for n in range(1, highest + 1):
		var species: = String(by_no.get(n, ""))
		entries.append({"no": n, "species": species, "caught": species != "" and Game.state.dex_caught.has(species)})


func _make_row(e: Dictionary) -> Dictionary:
	var species: = String(e.species)
	var row: = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.add_theme_constant_override("separation", 8)
	var cur: = _label(18, UiKit.RED)
	cur.custom_minimum_size = Vector2(20, 0)
	row.add_child(cur)
	var no: = _label(18, UiKit.DIM)
	no.text = "%03d" % int(e.no)
	no.custom_minimum_size = Vector2(48, 0)
	row.add_child(no)
	var mark: = BallMark.new()
	mark.on = e.caught
	row.add_child(mark)
	var icon: = TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if species != "":
		icon.texture = PokemonSprites.front(species)
		icon.modulate = PokemonSprites.tint(species) if e.caught else Color(0.42, 0.45, 0.5, 0.85)
	row.add_child(icon)
	var name: = _label(19, UiKit.INK)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.text = species if species != "" else "-----"
	if species == "":
		name.add_theme_color_override("font_color", UiKit.DIM)
	row.add_child(name)
	_rows_box.add_child(row)
	return {"node": row, "cur": cur, "name": name, "icon": icon, "mark": mark, "entry": e}


func _highlight() -> void :
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var sel: = i == selected
		r.cur.text = "▶" if sel else ""
		var species: = String(r.entry.species)
		if species == "":
			r.name.add_theme_color_override("font_color", UiKit.DIM)
		else:
			r.name.add_theme_color_override("font_color", UiKit.RED if sel else UiKit.INK)
	if selected >= 0 and selected < _rows.size():
		_scroll.ensure_control_visible(_rows[selected].node)



func step(d: int) -> void :
	if entries.is_empty():
		return
	var i: = selected
	for _n in entries.size():
		i = wrapi(i + d, 0, entries.size())
		if String(entries[i].species) != "":
			break
	if i != selected and String(entries[i].species) != "":
		selected = i
		Audio.ui("sfx/ui/cursor")
		_highlight()



func step_entry(d: int) -> void :
	if entries.is_empty():
		return
	var i: = selected
	for _n in entries.size():
		i = wrapi(i + d, 0, entries.size())
		if String(entries[i].species) != "":
			break
	if i != selected and String(entries[i].species) != "":
		selected = i
		entry_species = String(entries[i].species)
		Audio.ui("sfx/ui/cursor")
		_refresh_entry()



func _update_hints() -> void :
	if _hints == null:
		return
	if mode == "entry":
		var h: Array = [[["pk_up", "pk_down"], "Prev/Next"], ["pk_back", "Back"]]
		if _cry_slot != "":
			h.append(["pk_ok", "Cry"])
		_hints.set_hints(h)
	else:
		_hints.set_hints([[["pk_up", "pk_down"], "Move"], ["pk_ok", "Open"], ["pk_back", "Close"]])


func confirm() -> void :
	if selected < 0 or selected >= entries.size():
		return
	var species: = String(entries[selected].species)
	if species == "":
		Audio.ui("sfx/ui/error")
		return
	show_entry(species)


func _index_of(species: String) -> int:
	for i in entries.size():
		if String(entries[i].species) == species:
			return i
	return -1




func show_entry(species: String) -> void :
	var i: = _index_of(species)
	if i < 0:
		return
	selected = i
	mode = "entry"
	entry_species = species
	_list_view.visible = false
	_entry_view.visible = true
	_refresh_entry()
	UiKit.sfx("confirm")


func _refresh_entry() -> void :
	var sp: = Dex.species(entry_species)
	var caught: = Game.state.dex_caught.has(entry_species)
	_sprite.texture = PokemonSprites.front(entry_species)
	_sprite.modulate = PokemonSprites.tint(entry_species) if caught else Color(0.42, 0.45, 0.5, 0.85)
	_no.text = "No.%03d" % int(sp.get("dex_no", 0))
	_name.text = entry_species
	_category.text = String(sp.get("category", ""))
	for c in _types.get_children():
		_types.remove_child(c)
		c.queue_free()
	if caught:
		for t in sp.get("types", []):
			_types.add_child(_type_pill(String(t)))
	_types.visible = caught
	_height.text = "HT  %.1f m" % float(sp.get("height_m", 0.0))
	_weight.text = "WT  %.1f kg" % float(sp.get("weight_kg", 0.0))
	_flavor.text = String(sp.get("flavor", "")) if caught else ""
	_flavor.visible = caught
	_cry_slot = cry_slot(entry_species)
	_cry.visible = _cry_slot != ""
	var areas: = area_names(entry_species)
	_area.text = "AREA   %s" % ("  ·  ".join(areas) if not areas.is_empty() else "Unknown")
	_update_hints()


func _type_pill(type_name: String) -> Label:
	var col: = Dex.type_color(type_name)
	var l: = Label.new()
	l.text = type_name.to_upper()
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", UiKit.PAPER)
	var sb: = UiKit.pill(col.darkened(0.15), col.lightened(0.35), 10)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", sb)
	return l


func _play_cry() -> void :
	if _cry_slot == "":
		return
	Audio.cry(entry_species)





static func cry_slot(species: String) -> String:
	var base: = "res://assets/audio/cries/" + species.to_lower()
	for ext in ["ogg", "mp3", "wav"]:
		var p: = "%s.%s" % [base, ext]
		if ResourceLoader.exists(p) or FileAccess.file_exists(p):
			return "cries/" + species.to_lower()
	return ""



static func area_names(species: String) -> Array:
	if not _areas_loaded:
		_load_areas()
	return _areas.get(species, [])


static func _load_areas() -> void :
	_areas_loaded = true
	var dir: = DirAccess.open(ENCOUNTER_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(ENCOUNTER_DIR + "/" + f))
		if not (data is Dictionary):
			continue
		var area: = String(data.get("area", f.get_basename()))
		for e in data.get("entries", []):
			var s: = String(e.get("species", ""))
			if s == "":
				continue
			if not _areas.has(s):
				_areas[s] = []
			if not _areas[s].has(area):
				_areas[s].append(area)
