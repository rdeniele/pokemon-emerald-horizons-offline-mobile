extends PkWindow











const StatCalc: = preload("res://scripts/stats/stat_calc.gd")
const Dex: = preload("res://scripts/dex.gd")
const PokemonSprites: = preload("res://scripts/pokemon_sprites.gd")

const PAGES: = ["INFO", "SKILLS", "MOVES"]
const MAX_MOVES: = 4

var index: = 0

var mon_override: RefCounted
var footer: = ""
var page: = 0

var read_only: = false

var move_index: = 0
var move_held: = -1

var show_iv_ev: = false

var _sprite: TextureRect
var _heading: Label
var _tabs: Label
var _footer: Label
var _body: VBoxContainer
var _hints: PkHintBar


func _init() -> void :
	super ()
	title = "POKéMON"
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -410
	offset_right = 410
	offset_top = -300
	offset_bottom = 300
	var root: = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var top: = HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	root.add_child(top)
	_sprite = TextureRect.new()
	_sprite.custom_minimum_size = Vector2(160, 160)
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_sprite)
	var col: = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	top.add_child(col)
	_heading = Label.new()
	_heading.theme_type_variation = "HeaderLabel"
	col.add_child(_heading)
	_tabs = Label.new()
	_tabs.theme_type_variation = "SmallLabel"
	_tabs.add_theme_color_override("font_color", UiKit.BLUE)
	col.add_child(_tabs)
	_footer = Label.new()
	_footer.theme_type_variation = "SmallLabel"
	_footer.add_theme_color_override("font_color", UiKit.DIM)
	col.add_child(_footer)
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	root.add_child(_body)
	_hints = PkHintBar.new()
	root.add_child(_hints)
	visible = false



func open(i: = 0, ro: = false, start_page: = 0) -> void :
	index = i
	mon_override = null
	footer = ""
	read_only = ro
	page = clampi(start_page, 0, PAGES.size() - 1)
	move_index = 0
	move_held = -1
	visible = true
	refresh()



func show_mon(m: RefCounted, footer_text: = "", start_page: = 1) -> void :
	mon_override = m
	footer = footer_text
	read_only = true
	page = clampi(start_page, 0, PAGES.size() - 1)
	move_index = 0
	move_held = -1
	visible = true
	refresh()



func step(d: int) -> void :
	var n: int = Game.party.size()
	if n <= 0:
		return
	var i: = posmod(index + d, n)
	if i != index:
		index = i
		move_index = 0
		move_held = -1
		Audio.ui("sfx/ui/cursor")
	refresh()



func set_page(i: int) -> void :
	var n: = posmod(i, PAGES.size())
	if n == page:
		return
	page = n
	move_held = -1
	refresh()


func toggle_iv_ev() -> void :
	show_iv_ev = not show_iv_ev
	refresh()



func move_selected(d: int) -> void :
	if read_only:
		return
	var m = _mon()
	if m == null or m.moves.is_empty():
		return
	var n: = mini(m.moves.size(), MAX_MOVES)
	if move_held >= 0:
		var to: = move_held + d
		if to < 0 or to >= n:
			return
		_swap_moves(m, move_held, to)
		move_held = to
		move_index = to
		UiKit.sfx("cursor")
	else:
		var i: = clampi(move_index + d, 0, n - 1)
		if i == move_index:
			return
		move_index = i
		UiKit.sfx("cursor")
	refresh()



func confirm_move() -> void :
	if read_only:
		return
	if _mon() == null:
		return
	move_held = -1 if move_held >= 0 else move_index
	UiKit.sfx("confirm")
	refresh()


func refresh() -> void :
	var m = _mon()
	if m == null:
		return
	var sp: = Dex.species(m.species)
	_sprite.texture = PokemonSprites.icon(m.species)
	_sprite.modulate = PokemonSprites.tint(m.species)
	_heading.text = "%s     Lv %d" % [m.display_name, m.level]
	_tabs.text = _tabs_text()
	_footer.text = footer
	_footer.visible = footer != ""
	_clear(_body)
	match page:
		0: _build_info(m, sp)
		1: _build_skills(m, sp)
		_: _build_moves(m)
	_update_hints()




func _build_info(m, sp: Dictionary) -> void :
	var card: = PkInfoCard.new()
	card.title = "TRAINER MEMO"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(card)
	var types: Array = []
	for t in sp.get("types", []):
		types.append(String(t).to_upper())
	card.set_rows([
		["No.", "%03d" % int(sp.get("dex_no", 0))], 
		["TYPE", " / ".join(types) if not types.is_empty() else "—"], 
		["OT", _ot(m)], 
		["ID No.", _trainer_id()], 
		["NATURE", StatCalc.nature_label(m.nature)], 
		["ABILITY", m.ability_name if m.ability_name != "" else "—"], 
		["MET", _met_text(m)], 
		["ITEM", "None"], 
	])




func _build_skills(m, sp: Dictionary) -> void :
	var base: Dictionary = sp.get("base", {})
	var marks: = stat_marks(m.nature)
	var hp_ratio: = float(m.hp) / maxf(m.max_hp, 1)
	var hp_line: = HBoxContainer.new()
	hp_line.add_theme_constant_override("separation", 10)
	_body.add_child(hp_line)
	var hp_l: = Label.new()
	hp_l.text = "HP"
	hp_l.custom_minimum_size = Vector2(70, 0)
	hp_line.add_child(hp_l)
	var hp_bar: = _bar(float(m.hp), float(m.max_hp), UiKit.hp_color(hp_ratio))
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_line.add_child(hp_bar)
	var hp_v: = Label.new()
	hp_v.text = "%d / %d" % [m.hp, m.max_hp]
	hp_v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_v.custom_minimum_size = Vector2(110, 0)
	hp_line.add_child(hp_v)

	var grid: = GridContainer.new()
	grid.columns = 5 if show_iv_ev else 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 0)
	_body.add_child(grid)
	_dims(grid, "STAT")
	if show_iv_ev:
		_dims(grid, "BASE")
		_dims(grid, "IV")
		_dims(grid, "EV")
	_dims(grid, "VALUE")
	for s in StatCalc.STATS:
		var mark: = ""
		if marks.get(s, "") == "up":
			mark = "  [color=#e0403a]↑[/color]"
		elif marks.get(s, "") == "down":
			mark = "  [color=#3870c8]↓[/color]"
		var name: = RichTextLabel.new()
		name.bbcode_enabled = true
		name.fit_content = true
		name.scroll_active = false
		name.custom_minimum_size = Vector2(150, 0)
		name.add_theme_color_override("default_color", UiKit.BLUE)
		name.text = StatCalc.STAT_NAMES[s] + mark
		grid.add_child(name)
		if show_iv_ev:
			grid.add_child(_num(int(base.get(s, 0))))
			grid.add_child(_num(int(m.ivs.get(s, 0)), UiKit.AMBER if int(m.ivs.get(s, 0)) == StatCalc.IV_MAX else UiKit.INK))
			grid.add_child(_num(int(m.evs.get(s, 0)), UiKit.GREEN))
		var val: = _num(int(m.stats.get(s, 0)))
		val.add_theme_font_size_override("font_size", UiKit.SIZE_BODY)
		grid.add_child(val)

	var total: = Label.new()
	total.theme_type_variation = "SmallLabel"
	total.add_theme_color_override("font_color", UiKit.DIM)
	total.text = "EVs %d / %d   (max %d per stat)%s" % [m.ev_total(), StatCalc.EV_MAX_TOTAL, StatCalc.EV_MAX_STAT, 
		"   [V] hide base/IV/EV" if show_iv_ev else "   [V] show base/IV/EV"]
	_body.add_child(total)

	var exp_head: = HBoxContainer.new()
	exp_head.add_theme_constant_override("separation", 10)
	_body.add_child(exp_head)
	var exp_l: = Label.new()
	exp_l.text = "EXP"
	exp_l.custom_minimum_size = Vector2(70, 0)
	exp_head.add_child(exp_l)
	var exp_span: = maxi(m.exp_next_level - m.exp_this_level, 1)
	var exp_cur: = clampi(m.xp - m.exp_this_level, 0, exp_span)
	var exp_bar: = _bar(float(exp_cur), float(exp_span), UiKit.PP_BLUE)
	exp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	exp_head.add_child(exp_bar)
	var exp_v: = Label.new()
	exp_v.text = "%d" % m.xp
	exp_v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	exp_v.custom_minimum_size = Vector2(110, 0)
	exp_head.add_child(exp_v)
	var next: = Label.new()
	next.theme_type_variation = "SmallLabel"
	next.add_theme_color_override("font_color", UiKit.DIM)
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var at_cap: bool = m.level >= 100
	next.text = "MAX level" if at_cap else "%d EXP to Lv %d" % [maxi(m.exp_next_level - m.xp, 0), m.level + 1]
	exp_head.add_child(next)


	var ability_box: = PanelContainer.new()
	var ability_box_sb: StyleBoxFlat = UiKit.pill(Color(UiKit.PAPER, 0.0), UiKit.RIM, 8)
	ability_box_sb.set_content_margin_all(5)
	ability_box.add_theme_stylebox_override("panel", ability_box_sb)
	ability_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ability_row: = HBoxContainer.new()
	ability_row.add_theme_constant_override("separation", 14)
	ability_box.add_child(ability_row)
	var ability_tag: = Label.new()
	ability_tag.theme_type_variation = "SmallLabel"
	ability_tag.add_theme_color_override("font_color", UiKit.BLUE)
	ability_tag.text = "ABILITY"
	ability_row.add_child(ability_tag)
	var ability_name_label: = Label.new()
	ability_name_label.text = m.ability_name if m.ability_name != "" else "—"
	ability_name_label.add_theme_color_override("font_color", UiKit.INK)
	ability_row.add_child(ability_name_label)
	var ability_desc_label: = Label.new()
	ability_desc_label.theme_type_variation = "SmallLabel"
	ability_desc_label.add_theme_color_override("font_color", UiKit.DIM)
	ability_desc_label.text = m.ability_desc
	ability_desc_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ability_row.add_child(ability_desc_label)
	_body.add_child(ability_box)




func _build_moves(m) -> void :
	if m.moves.is_empty():
		var none: = Label.new()
		none.text = "No moves."
		_body.add_child(none)
		return
	for i in m.moves.size():
		_body.add_child(_move_row(m, i))


func _move_row(m, i: int) -> PanelContainer:
	var id: = String(m.moves[i])
	var mv: = Dex.move(id)
	var tcol: = Dex.type_color(String(mv.get("type", "normal")))
	var row: = PanelContainer.new()
	var bg: = UiKit.RED_SOFT if i == move_index and not read_only else Color(UiKit.PAPER, 0.0)
	var border: = UiKit.GREEN if i == move_held else (UiKit.RED if i == move_index and not read_only else Color.TRANSPARENT)
	var sb: StyleBoxFlat = UiKit.pill(bg, border, 8)
	sb.set_content_margin_all(8)
	row.add_theme_stylebox_override("panel", sb)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var head: = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	var cursor: = Label.new()
	cursor.text = "▶" if i == move_index and not read_only else "  "
	cursor.custom_minimum_size = Vector2(20, 0)
	head.add_child(cursor)
	var nm: = Label.new()
	nm.text = String(mv.get("name", id))
	nm.custom_minimum_size = Vector2(190, 0)
	head.add_child(nm)
	if tcol.get_luminance() > 0.85:
		tcol = tcol.darkened(0.25)
	head.add_child(_pill(String(mv.get("type", "normal")).to_upper(), tcol))
	head.add_child(_kv("PP", "%d" % int(round(Dex.pp_cost(mv))), UiKit.PP_BLUE))
	head.add_child(_kv("POWER", "—" if int(mv.get("power", 0)) <= 0 else str(int(mv.get("power", 0)))))
	head.add_child(_kv("ACC", "—" if not mv.has("accuracy") else "%d%%" % int(mv.get("accuracy", 0))))
	head.add_child(_kv("CD", "%.1fs" % Dex.cooldown(mv)))
	var kind: = Label.new()
	kind.theme_type_variation = "SmallLabel"
	kind.add_theme_color_override("font_color", UiKit.DIM)
	kind.text = String(mv.get("kind", "")).replace("_", " ")
	head.add_child(kind)
	var desc: = Label.new()
	desc.theme_type_variation = "SmallLabel"
	desc.add_theme_color_override("font_color", UiKit.DIM)
	desc.text = "        " + String(mv.get("desc", ""))
	col.add_child(desc)
	return row




func _mon() -> RefCounted:
	if mon_override != null:
		return mon_override
	if Game.party.is_empty():
		return null
	index = clampi(index, 0, Game.party.size() - 1)
	return Game.party[index]


func _clear(n: Node) -> void :
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _tabs_text() -> String:
	var parts: Array = []
	for i in PAGES.size():
		parts.append(("▶ %s" % PAGES[i]) if i == page else ("  %s" % PAGES[i]))
	return "       ".join(parts)


func _ot(m) -> String:
	if m.owner != "" and m.owner != "player":
		return m.owner
	return Game.state.player_name


func _trainer_id() -> String:
	var id = Game.state.get("trainer_id")
	if id != null:
		return "%05d" % int(id)
	return "%05d" % (absi(Game.state.player_name.hash()) % 100000)


func _met_text(m) -> String:
	if m.met_zone == "":
		return "—"
	if m.met_level <= 0:
		return "In %s" % m.met_zone
	return "Lv %d in %s" % [m.met_level, m.met_zone]


func _dims(grid: GridContainer, text: String) -> void :
	var l: = Label.new()
	l.theme_type_variation = "SmallLabel"
	l.add_theme_color_override("font_color", UiKit.DIM)
	l.text = text
	grid.add_child(l)


func _num(v: int, col: = UiKit.INK) -> Label:
	var l: = Label.new()
	l.text = str(v)
	l.add_theme_color_override("font_color", col)
	return l


func _kv(key: String, value: String, col: = UiKit.INK) -> Label:
	var l: = Label.new()
	l.theme_type_variation = "SmallLabel"
	l.add_theme_color_override("font_color", col)
	l.text = "%s %s" % [key, value]
	return l


func _pill(text: String, col: Color) -> PanelContainer:
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.pill(col, UiKit.INK, 6))
	var l: = Label.new()
	l.theme_type_variation = "SmallLabel"
	l.text = text
	l.add_theme_color_override("font_color", UiKit.PAPER if col.get_luminance() < 0.6 else UiKit.INK)
	p.add_child(l)
	return p


func _bar(value: float, maxv: float, col: Color) -> ProgressBar:
	var b: = ProgressBar.new()
	b.max_value = maxf(maxv, 1.0)
	b.value = clampf(value, 0.0, b.max_value)
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 14)
	b.add_theme_stylebox_override("background", _bar_box(UiKit.RIM))
	b.add_theme_stylebox_override("fill", _bar_box(col))
	return b


func _bar_box(col: Color) -> StyleBoxFlat:
	var sb: = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(7)
	return sb




func stat_marks(nature: String) -> Dictionary:
	var out: = {}
	var n: Array = StatCalc.NATURES.get(nature, [])
	if not n.is_empty():
		out[n[0]] = "up"
		out[n[1]] = "down"
	return out


func _swap_moves(m, a: int, b: int) -> void :
	var tmp = m.moves[a]
	m.moves[a] = m.moves[b]
	m.moves[b] = tmp
	Game.party_changed.emit()


func _update_hints() -> void :
	var list: Array = [[["pk_left", "pk_right"], "Page"], [["pk_prev", "pk_next"], "Pokémon"], ["pk_back", "Close"]]
	if page == 1:
		list.insert(0, ["pk_alt", "IV/EV"])
	if page == 2 and not read_only:
		list = [[["pk_up", "pk_down"], "Select"], ["pk_ok", "Swap"]] + list
	_hints.set_hints(list)
