extends Node3D










const Dex: = preload("res://scripts/dex.gd")
const PPBar: = preload("res://scripts/pp_bar.gd")
const StatCalc: = preload("res://scripts/stats/stat_calc.gd")
const MonScript: = preload("res://scripts/stats/mon.gd")
const BEHAVIOURS: = ["Still", "Strafe", "Approach"]

const WINDOW: = 22
const PAGE: = 10

const Kit: = preload("res://scripts/tests/test_kit.gd")
const BRAINS: = ["Still", "Strafe", "Approach", "AI"]

const TIERS: = [["bug_catcher", 1.3], ["rival_oak", 1.6], ["rival_route22", 0.9], ["brock", 0.8]]
const DUEL_ARENA: = Vector2(18, 12)
const DUEL_CENTER: = Vector3(0, 0, 0.1)
const SLOWS: = [1.0, 0.5, 0.25]

@export var attacker_level: = 25
@export var dummy_level: = 25

@export var start_in_duel: = false

@onready var attacker: Creature = $Attacker
@onready var dummy: Creature = $Dummy
@onready var cam: Node = $CameraRig

var _moves: Array = []
var _sel: = 0
var _species: Array = []
var _sp_i: = 0
var _types: Array = []
var _type_i: = -1
var _dummy_fights: = false
var _log: Array = []

var debug_cast: = ""

var debug_cycle: = false

var debug_repeat: = ""
var debug_repeat_n: = 20
var _misses: = 0
var _casts: = 0
const ACC_MODES: = [["normal", 1.0, false], ["half accuracy", 0.5, false], ["always miss", 1.0, true]]
var _acc_mode: = 0
var debug_cycle_secs: = 1.6
var _cycle_i: = 0
var _cycle_t: = 0.0

var _list: VBoxContainer
var _rows: Array = []
var _win_start: = 0
var _title_l: Label
var _info: RichTextLabel
var _status: RichTextLabel
var _log_l: Label
var _pp_rows: = {}


var _duel: = false
var _you_species: = "Charmander"
var _you_level: = 8
var _you_moves: Array = []
var _foe_species: = "Pidgey"
var _foe_level: = 7
var _foe_moves: Array = []
var _brain_i: = 3
var _tier_i: = 1
var _sturdy: = true
var _foe_immortal: = false
var _ranges: = false
var _levels: Array = []
var _left_panel: PanelContainer
var _right_panel: PanelContainer
var _bottom_panel: PanelContainer
var _duel_ui: CanvasLayer
var _setup_win: PkWindow
var _setup_scroll: ScrollContainer
var _setup_list: PkOptionList
var _setup_rows: = {}
var _readout_win: PanelContainer
var _readout: RichTextLabel

var _hints_setup: PkHintBar
var _hints_game: PkHintBar
var _hints_lab: PkHintBar
var _hints_state: = ""
var _readout_on: = false

const DUEL_ENV: = preload("res://resources/look/overworld_env.tres")
var _dirt: MeshInstance3D
var _lab_env: Environment
var _duel_world: Node3D
var _duel_player: Node3D
var _duel_foe_npc: Node3D
var _duel_hud: CanvasLayer
var _duel_busy: = false
var _duel_started: = false
var _fight_t0: = 0
var _restart_wanted: = false
var _duel_result: = ""
var _duel_hits: Array = []
var _duel_rate: = {}
var _foe_body: Creature = null
var _foe_frozen: = false
var _swapped: = false
var _slow_i: = 0
var _rings: Array = []

var debug_duel: = false
var debug_fight: = false


func _ready() -> void :
	_moves = Dex.all_moves()
	_species = Dex.all_species()
	_types = Dex.all_types()
	_build_arena()
	for c in [attacker, dummy]:
		c.add_to_group("combatant")
		c.is_wild = false
		c.remove_from_group("wild")
	attacker.side = 0
	dummy.side = 1
	dummy.immortal = true
	attacker.immortal = true
	attacker.opponent = dummy
	dummy.opponent = attacker
	_set_attacker_species(0)
	_reset()
	cam.focus_battle(attacker, dummy)
	_build_ui()
	get_node("/root/Moves").hit_landed.connect(_on_hit)
	get_node("/root/Moves").move_missed.connect( func(u, t, mv):
		_misses += 1
		if _duel_started:
			_duel_note_miss(u, t, mv))
	get_node("/root/Moves").knocked_out.connect(_on_ko)
	get_node("/root/Moves").move_missed.connect( func(u, t, mv): _note("%s → %s: %s MISSED (accuracy %s%%)" % [u.species, t.species, mv.name, mv.get("accuracy", 100)]))
	for i in range(2, 101):
		_levels.append(str(i))
	_you_moves = _default_kit(_you_species, _you_level)
	_foe_moves = _default_kit(_foe_species, _foe_level)
	Game.battle_started.connect(_on_duel_battle_started)
	get_node("/root/Moves").move_used.connect(_on_duel_move_used)
	_select(0)
	_maybe_shot()
	if start_in_duel:
		_enter_duel.call_deferred()





func _maybe_shot() -> void :
	var cast: = ""
	var shot: = ""
	var delay: = 0.5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cast="):
			cast = a.substr(7)
		elif a.begins_with("--shot="):
			shot = a.substr(7)
		elif a.begins_with("--delay="):
			delay = float(a.substr(8))
	if cast == "" or shot == "":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var i: = _moves.find(cast)
	if i >= 0:
		_select(i)
		attacker.clear_cooldowns()

		var mv: = Dex.move(attacker.selected_move)
		var dist: = 3.2
		if String(mv.get("kind", "")) in ["arc", "multi_arc"]:
			dist = maxf(1.2, float(mv.get("range", 1.8)) * 0.75)
		attacker.global_position = dummy.global_position + Vector3(0, 0, dist)
		get_node("/root/Moves").use(attacker, attacker.selected_move)
	await get_tree().create_timer(maxf(delay, 0.0)).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(shot.get_base_dir())
	get_viewport().get_texture().get_image().save_png(shot)
	print("[move_lab] wrote ", shot)
	get_tree().quit()




func _build_arena() -> void :
	var ground: = MeshInstance3D.new()
	var pm: = PlaneMesh.new()
	pm.size = Vector2(60, 60)
	var m: = StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/ground_grass.png")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	pm.material = m
	ground.mesh = pm
	add_child(ground)
	var ring: = MeshInstance3D.new()
	var rm: = PlaneMesh.new()
	rm.size = Vector2(22, 22)
	var m2: = StandardMaterial3D.new()
	m2.albedo_texture = load("res://assets/textures/ground_path.png")
	m2.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m2.uv1_triplanar = true
	m2.uv1_world_triplanar = true
	rm.material = m2
	ring.mesh = rm
	ring.position.y = 0.01
	add_child(ring)
	_dirt = ring
	_wall(Vector3(0, 1, -11.5), Vector3(23, 2, 1))
	_wall(Vector3(0, 1, 11.5), Vector3(23, 2, 1), false)
	_wall(Vector3(-11.5, 1, 0), Vector3(1, 2, 23))
	_wall(Vector3(11.5, 1, 0), Vector3(1, 2, 23))
	_wall(Vector3(0, -0.5, 0), Vector3(60, 1, 60), false)
	for p in [Vector3(-5, 0, -4), Vector3(5, 0, 4)]:
		_wall(p + Vector3(0, 0.75, 0), Vector3(1.2, 1.5, 1.2))


func _wall(pos: Vector3, size: Vector3, visible_mesh: = true) -> void :
	var sb: = StaticBody3D.new()
	sb.position = pos
	var cs: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	if visible_mesh:
		var mi: = MeshInstance3D.new()
		var bm: = BoxMesh.new()
		bm.size = size
		var m: = StandardMaterial3D.new()
		m.albedo_color = Color(0.62, 0.58, 0.52)
		bm.material = m
		mi.mesh = bm
		sb.add_child(mi)
	add_child(sb)


func _set_attacker_species(i: int) -> void :
	_sp_i = posmod(i, _species.size())
	var sp: String = _species[_sp_i]
	attacker.species = sp
	attacker.level = attacker_level
	attacker.apply_species()
	attacker.moves = []
	attacker.refresh_label()


func _reset() -> void :
	attacker.global_position = Vector3(0, 0.1, 4)
	dummy.global_position = Vector3(0, 0.1, -3)
	dummy.level = dummy_level
	dummy.apply_species()
	if _type_i >= 0:
		dummy.types = [_types[_type_i]]
	for c in [attacker, dummy]:
		c.hp = c.max_hp
		c.mon.hp = c.hp
		c.clear_status()
		c.clear_cooldowns()
		c.root_t = 0.0
		c.stun_t = 0.0
		c.evasion_t = 0.0
		c.confusion_t = 0.0
		for k in c.stages.keys():
			c.stages[k] = 0
		c.restore_pp()
		c.refresh_label()
	attacker.moves = []
	attacker.mode = Creature.Mode.PLAYER
	_apply_dummy_mode()


func _apply_dummy_mode() -> void :
	if _dummy_fights:
		dummy.mode = Creature.Mode.BATTLE_AI
		dummy.ai_uses_moves = true
	else:
		dummy.mode = Creature.Mode.DUMMY
		dummy.ai_uses_moves = false




func _unhandled_input(e: InputEvent) -> void :
	if _duel:
		_duel_input(e)
		return
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select(_sel - 1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select(_sel + 1)
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var k: int = e.physical_keycode
	match k:
		KEY_G:
			_toggle_duel()
		KEY_Q:
			_select(_sel - 1)
		KEY_E:
			_select(_sel + 1)
		KEY_SPACE:
			_use_selected()
		KEY_PAGEUP:
			_select(_sel - PAGE)
		KEY_PAGEDOWN:
			_select(_sel + PAGE)
		KEY_TAB:
			_set_attacker_species(_sp_i + 1)
			_note("Attacker is now %s (%s)" % [attacker.species, "/".join(attacker.types)])
		KEY_V:
			_type_i += 1
			if _type_i >= _types.size():
				_type_i = -1
			dummy.apply_species()
			dummy.types = [_types[_type_i]] if _type_i >= 0 else dummy.types
			dummy.hp = dummy.max_hp
			_note("Dummy type: %s" % "/".join(dummy.types))
		KEY_B:
			dummy.dummy_style = (dummy.dummy_style + 1) % BEHAVIOURS.size()
			_note("Dummy behaviour: %s" % BEHAVIOURS[dummy.dummy_style])
		KEY_F:
			_dummy_fights = not _dummy_fights
			_apply_dummy_mode()
			_note("Dummy fights back: %s" % ("ON (uses its species moves)" if _dummy_fights else "OFF"))
		KEY_N:
			attacker.mon = MonScript.create(attacker.species, attacker.level)
			attacker.apply_species()
			attacker.moves = []
			_note("New %s: %s, IVs %s" % [attacker.species, StatCalc.nature_label(attacker.mon.nature), _iv_str(attacker.mon)])
		KEY_M:
			_acc_mode = (_acc_mode + 1) % ACC_MODES.size()
			var mv_node: = get_node("/root/Moves")
			mv_node.accuracy_scale = ACC_MODES[_acc_mode][1]
			mv_node.debug_force_miss = ACC_MODES[_acc_mode][2]
			_note("Accuracy test mode: %s" % ACC_MODES[_acc_mode][0])
			_show_info()
		KEY_R:
			_reset()
			_note("Reset")
		_:
			if k >= KEY_1 and k <= KEY_9:
				_select(k - KEY_1)
	get_viewport().set_input_as_handled()


func _select(i: int) -> void :
	_sel = posmod(i, _moves.size())
	attacker.selected_move = _moves[_sel]
	_win_start = clampi(_sel - WINDOW / 2, 0, maxi(0, _moves.size() - WINDOW))
	for j in _rows.size():
		var mi: = _win_start + j
		var sel: = mi == _sel
		_rows[j].add_theme_color_override("font_color", Color(1, 1, 1) if sel else Color(1, 1, 1, 0.55))
		_rows[j].text = ("▶ " if sel else "   ") + _row_text(_moves[mi])
	if _title_l != null:
		_title_l.text = "MOVES  %d / %d  (Q/E · wheel · PgUp/PgDn)" % [_sel + 1, _moves.size()]
	_show_info()



func _use_selected() -> void :
	if attacker != null and attacker.selected_move != "":
		get_node("/root/Moves").use(attacker, attacker.selected_move)



func _on_ko(user, target) -> void :
	if user == attacker and target == dummy:
		var got: Dictionary = attacker.gain_evs_from(dummy)
		if not got.is_empty():
			_note("KO! %s gained %s EVs (total %d/%d)" % [attacker.species, str(got), attacker.mon.ev_total(), StatCalc.EV_MAX_TOTAL])


func _note(t: String) -> void :
	_log.push_front(t)
	_log = _log.slice(0, 6)
	_log_l.text = "\n".join(_log)


func _on_hit(user, target, info: Dictionary) -> void :
	if _duel_started:
		_duel_note_hit(user, target, info)
	if info.damage == 0 and not info.has("status") and info.eff != 0.0:
		return
	var eff: float = info.eff
	var tag: = ""
	if eff == 0.0:
		tag = " (no effect)"
	elif eff > 1.0:
		tag = " (x%s super effective)" % eff
	elif eff < 1.0:
		tag = " (x%s)" % eff
	var st: = " +%s" % info.status if info.has("status") else ""
	_note("%s → %s: %s  %d dmg%s%s" % [user.species, target.species, Dex.move(info.move).get("name", info.move), info.damage, tag, st])




func _build_ui() -> void :
	var layer: = CanvasLayer.new()
	add_child(layer)
	_left_panel = _panel(layer, Vector2(12, 12), Vector2(300, 0))
	var left: = _left_panel
	var lv: = VBoxContainer.new()
	left.add_child(lv)
	_title_l = _title("MOVES")
	lv.add_child(_title_l)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	lv.add_child(_list)
	for i in WINDOW:
		var l: = Label.new()
		l.add_theme_font_size_override("font_size", 14)
		_list.add_child(l)
		_rows.append(l)
	_right_panel = _panel(layer, Vector2(0, 12), Vector2(330, 0))
	var right: = _right_panel
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -342
	right.offset_right = -12
	var rv: = VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right.add_child(rv)
	_info = _rich(rv)
	_status = _rich(rv)
	for c in [attacker, dummy]:
		var l: = Label.new()
		l.add_theme_font_size_override("font_size", 13)
		rv.add_child(l)
		var bar: Control = PPBar.new()
		bar.custom_minimum_size = Vector2(306, 12)
		rv.add_child(bar)
		_pp_rows[c] = [l, bar]
	_bottom_panel = _panel(layer, Vector2(0, 0), Vector2(0, 0))
	var bottom: = _bottom_panel
	bottom.anchor_left = 0.0
	bottom.anchor_right = 0.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 12
	bottom.offset_right = 600
	bottom.offset_top = -170
	bottom.offset_bottom = -12
	var bv: = VBoxContainer.new()
	bottom.add_child(bv)
	var help: = Label.new()
	help.text = "G  DUEL MODE — pick both Pokémon and fight the real battle\nWASD move · SPACE use · Q/E or wheel move list · PgUp/PgDn jump 10 · 1-9 pick move · TAB attacker species · V dummy type · B dummy behaviour · F dummy fights back · M accuracy test mode · N new individual (IVs/nature) · R reset"
	help.add_theme_font_size_override("font_size", 13)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(560, 0)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	bv.add_child(help)
	_log_l = Label.new()
	_log_l.add_theme_font_size_override("font_size", 14)
	bv.add_child(_log_l)


func _panel(layer: CanvasLayer, pos: Vector2, min_size: Vector2) -> PanelContainer:
	var p: = PanelContainer.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.12, 0.8)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.custom_minimum_size = min_size
	layer.add_child(p)
	return p


func _title(t: String) -> Label:
	var l: = Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	return l


func _rich(parent: Control) -> RichTextLabel:
	var r: = RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(306, 0)
	r.add_theme_font_size_override("normal_font_size", 14)
	r.add_theme_font_size_override("bold_font_size", 16)
	parent.add_child(r)
	return r


func _row_text(id: String) -> String:
	var mv: = Dex.move(id)
	return "%-14s %-9s %-10s %4.1f PP" % [mv.name, mv.type, mv.kind, Dex.pp_cost(mv)]


func _hex(t: String) -> String:
	return Dex.type_color(t).to_html(false)


func _show_info() -> void :
	var mv: = Dex.move(_moves[_sel])
	var lines: = ["[b][color=#%s]%s[/color][/b]" % [_hex(mv.type), mv.name], 
		"Type: [color=#%s]%s[/color]   Category: %s" % [_hex(mv.type), mv.type, mv.category], 
		"Delivery: [b]%s[/b]" % mv.kind]
	lines.append("cooldown: %.1fs%s" % [Dex.cooldown(mv), " (manual)" if mv.has("cooldown") else ""])
	for k in ["power", "windup", "range", "radius", "speed", "count", "spread", "angle", "hits", "duration", "tick", "width", "knockback", "root", "stat", "stages", "evasion"]:
		if mv.has(k):
			lines.append("%s: %s" % [k, mv[k]])
	if mv.has("effect"):
		var ef: Dictionary = mv.effect
		if ef.has("stat"):
			lines.append("effect: %s %+d%s (%d%%)" % [ef.stat, int(ef.stages), " (self)" if ef.get("self", false) else "", int(float(ef.chance) * 100)])
		elif ef.has("status"):
			lines.append("effect: %s (%d%%)" % [ef.status, int(float(ef.chance) * 100)])
	lines.append("accuracy: %s%s" % [(("%s%%" % mv.accuracy) if mv.has("accuracy") else "never misses"), ("   [color=#ffbb55](test mode: %s)[/color]" % ACC_MODES[_acc_mode][0]) if _acc_mode != 0 else ""])
	lines.append("[color=#8cc8ff]PP cost: %.1f (%s uses)   fatigue: %d[/color]" % [Dex.pp_cost(mv), mv.get("uses", "?"), int(Dex.fatigue(mv))])
	var eff: = Dex.effectiveness(mv.type, dummy.types)
	var stab: = " · STAB x1.5" if mv.type in attacker.types else ""
	lines.append("\nvs dummy (%s): x%s%s" % ["/".join(dummy.types), eff, stab])
	_info.text = "\n".join(lines)


func _process(_delta: float) -> void :
	if _status == null:
		return
	if debug_duel:
		debug_duel = false
		_enter_duel()
	if debug_fight:
		debug_fight = false
		_start_duel()
	if debug_repeat != "":
		_cycle_t -= _delta
		if _cycle_t <= 0.0:
			_cycle_t = debug_cycle_secs
			if _casts >= debug_repeat_n:
				print("[lab] %s: %d misses / %d casts" % [debug_repeat, _misses, _casts])
				debug_repeat = ""
			else:
				_casts += 1
				attacker.restore_pp()
				attacker.root_t = 0.0
				attacker.global_position = dummy.global_position + Vector3(0, 0, 3.2)
				debug_cast = debug_repeat
	if debug_cycle:
		_cycle_t -= _delta
		if _cycle_t <= 0.0:
			_cycle_t = debug_cycle_secs
			if _cycle_i >= _moves.size():
				debug_cycle = false
				print("[lab] cycle done")
			else:
				print("[lab] casting ", _moves[_cycle_i])
				debug_cast = _moves[_cycle_i]
				_cycle_i += 1
				attacker.root_t = 0.0
				attacker.restore_pp()
				attacker.sprite.modulate = attacker.base_tint()
				attacker.global_position = dummy.global_position + Vector3(0, 0, 3.2)
	if debug_cast != "":
		var i: = _moves.find(debug_cast)
		debug_cast = ""
		if i >= 0:
			_select(i)
			attacker.clear_cooldowns()
			get_node("/root/Moves").use(attacker, attacker.selected_move)
	if _duel:
		_duel_process(_delta)
		return
	for c in _pp_rows.keys():
		var row: Array = _pp_rows[c]
		var tag: = ("   [color=#ffbb55]EXHAUSTED %.1fs[/color]" % c.stagger_t) if c.stagger_t > 0.0 else ""
		row[0].text = "%s  PP %.1f / %d   stamina %d%s" % ["ATTACKER" if c == attacker else "DUMMY", c.pp_max, int(c.pp_base), int(c.stamina), tag.replace("[color=#ffbb55]", "").replace("[/color]", "")]
		row[1].set_values(c.pp_base, c.pp_max, c.stamina)
	var cd: = float(attacker.move_cd.get(attacker.selected_move, 0.0))
	_status.text = "%s\n%s\n[color=#aaaaaa]cooldown: %s[/color]" % [_desc(attacker, "ATTACKER"), _desc(dummy, "DUMMY · " + BEHAVIOURS[dummy.dummy_style] + (" · FIGHTING" if _dummy_fights else "")), ("%.1fs" % cd) if cd > 0.0 else "ready"]


func _desc(c: Creature, title: String) -> String:
	var st: = ""
	for k in c.stages.keys():
		if c.stages[k] != 0:
			st += " %s%+d" % [k, c.stages[k]]
	return "[b]%s[/b]  %s Lv%d [%s]\nHP %d/%d  %s%s\natk %d def %d spa %d spd %d spe %d  (speed x%.2f)\n[color=#aaaaaa]%s · IV %s · EV %d/%d[/color]" % [title, c.species, c.level, "/".join(c.types), c.hp, c.max_hp, 
		("[color=#ffcc66]%s[/color]" % c.status.to_upper()) if c.status != "" else "", st, 
		c.stats.atk, c.stats.def, c.stats.spa, c.stats.spd, c.stats.spe, c.speed_factor(), 
		StatCalc.nature_label(c.mon.nature), _iv_str(c.mon), c.mon.ev_total(), StatCalc.EV_MAX_TOTAL]


func _iv_str(m) -> String:
	var parts: Array = []
	for s in StatCalc.STATS:
		parts.append(str(m.ivs.get(s, 0)))
	return "/".join(parts)






func _toggle_duel() -> void :
	if _duel:
		_exit_duel()
	else:
		_enter_duel()


func _enter_duel() -> void :
	if _duel or Battle.in_battle or _duel_busy:
		return
	_duel = true
	_build_duel_ui()
	_classic_ui(false)
	_setup_win.visible = true
	_readout_win.visible = false
	_setup_list.active = true
	for c in [attacker, dummy]:
		c.visible = false
		c.mode = Creature.Mode.IDLE
		c.remove_from_group("combatant")
	cam.focus_fixed(DUEL_CENTER, 18.0)
	_duel_look(true)
	_note("Duel mode — pick both sides, Enter starts the real battle (G back)")


func _exit_duel() -> void :
	if _duel_busy:
		return
	if Battle.in_battle:
		Battle.end_battle("fled")
	_duel = false
	_restart_wanted = false
	if _slow_i > 0:
		Engine.time_scale = 1.0
		_slow_i = 0
	if _setup_win != null:
		_setup_win.visible = false
	if _readout_win != null:
		_readout_win.visible = false
	if _duel_hud != null:
		_duel_hud.visible = false
	_classic_ui(true)
	_update_hints()
	_duel_look(false)
	for c in [attacker, dummy]:
		c.visible = true
		if not c.is_in_group("combatant"):
			c.add_to_group("combatant")
	_reset()
	cam.focus_follow(attacker)
	_note("Classic move list back")



func _duel_look(on: bool) -> void :
	var we: = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null:
		if _lab_env == null:
			_lab_env = we.environment
		we.environment = DUEL_ENV if on else _lab_env
	if _dirt != null:
		_dirt.visible = not on


func _classic_ui(on: bool) -> void :
	for p in [_left_panel, _right_panel, _bottom_panel]:
		if p != null:
			p.visible = on




func _duel_input(e: InputEvent) -> void :
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var k: int = e.physical_keycode
	if Battle.in_battle:
		match k:
			KEY_F1:
				_restart_duel()
			KEY_F2:
				_leave_fight()
			KEY_F3:
				_slow_i = (_slow_i + 1) % SLOWS.size()
				Engine.time_scale = SLOWS[_slow_i]
			KEY_F4:
				_refill(Battle.wild)
			KEY_F5:
				_refill(Battle.partner)
			KEY_F6:
				_swap_control()
			KEY_F7:
				_freeze_foe()
			KEY_F8:
				_readout_on = not _readout_on
			_:
				return
	elif k == KEY_G:
		_toggle_duel()
	else:
		return
	get_viewport().set_input_as_handled()




func _build_duel_ui() -> void :
	if _setup_win != null:
		return
	_duel_ui = CanvasLayer.new()
	_duel_ui.layer = 3
	add_child(_duel_ui)
	_setup_win = PkWindow.new()
	_setup_win.title = "DUEL"
	_setup_win.anchor_left = 0.5
	_setup_win.anchor_top = 0.5
	_setup_win.anchor_right = 0.5
	_setup_win.anchor_bottom = 0.5
	_setup_win.offset_left = -330
	_setup_win.offset_top = -300
	_setup_win.offset_right = 330
	_setup_win.offset_bottom = 300
	_duel_ui.add_child(_setup_win)
	_setup_scroll = ScrollContainer.new()
	_setup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_setup_win.add_child(_setup_scroll)
	_setup_list = PkOptionList.new()
	_setup_scroll.add_child(_setup_list)
	_build_setup_rows()
	_readout_win = _panel(_duel_ui, Vector2(0, 150), Vector2(330, 0))
	_readout_win.anchor_left = 1.0
	_readout_win.anchor_right = 1.0
	_readout_win.offset_left = -346
	_readout_win.offset_right = -16
	_readout = _rich(_readout_win)
	_readout.add_theme_font_size_override("normal_font_size", 12)
	_readout.add_theme_font_size_override("bold_font_size", 13)
	_readout_win.visible = false
	_hints_setup = _hint_bar(Vector2(0.5, 1.0), -44)
	_hints_setup.set_hints([["↑ ↓", "choose row"], ["← →", "change value"], ["Enter", "FIGHT"], ["G", "back to the move lab"]])


	_hints_game = _hint_bar(Vector2(0.0, 0.0), 16)
	_hints_game.offset_left = 112
	_hints_game.scale = Vector2(0.8, 0.8)
	_hints_game.set_hints([["↑↓←→", "move"], ["S D A W", "your moves"], ["Shift", "sprint"], ["Q", "jump"]])
	_hints_lab = _hint_bar(Vector2(0.0, 0.0), 56)
	_hints_lab.offset_left = 112
	_hints_lab.scale = Vector2(0.8, 0.8)



func _hint_bar(anchor: Vector2, dy: float) -> PkHintBar:
	var b: = PkHintBar.new()
	b.anchor_left = anchor.x
	b.anchor_right = anchor.x
	b.anchor_top = anchor.y
	b.anchor_bottom = anchor.y
	b.grow_horizontal = Control.GROW_DIRECTION_BOTH if anchor.x == 0.5 else Control.GROW_DIRECTION_END
	b.offset_top = dy
	b.offset_bottom = dy
	b.visible = false
	_duel_ui.add_child(b)
	return b



func _update_hints() -> void :
	if _hints_setup == null:
		return
	var fighting: = _duel and Battle.in_battle
	var state: = "off" if not _duel else ("fight%d" % _slow_i if fighting else "setup")
	if state == _hints_state:
		return
	_hints_state = state
	_hints_setup.visible = state == "setup"
	_hints_game.visible = fighting
	_hints_lab.visible = fighting
	if fighting:
		_hints_lab.set_hints([["F1", "restart"], ["F2", "setup"], ["F3", "slow %s×" % str(SLOWS[_slow_i])], 
			["F4", "foe HP"], ["F5", "my HP"], ["F6", "swap"], ["F7", "freeze"], ["F8", "stats"]])


func _build_setup_rows() -> void :
	for r in _setup_list.rows:
		r.queue_free()
	_setup_list.rows.clear()
	_setup_rows.clear()
	_setup_list.index = 0
	_add_row("fight", "FIGHT  (Enter)", PkOptionRow.Kind.ACTION, 0, [], func(): _start_duel())
	_add_row("you_species", "You: species", PkOptionRow.Kind.CHOICE, _species.find(_you_species), _species, 
		func(v): _pick_species("you", v))
	_add_row("you_level", "You: level", PkOptionRow.Kind.CHOICE, _you_level - 2, _levels, 
		func(v): _pick_level("you", v))
	for i in 4:
		_add_row("you_move_%d" % i, "You: move %d" % (i + 1), PkOptionRow.Kind.CHOICE, 
			_move_index(String(_you_moves[i])), _move_choices(), func(v): _pick_move("you", i, v))
	_add_row("foe_species", "Foe: species", PkOptionRow.Kind.CHOICE, _species.find(_foe_species), _species, 
		func(v): _pick_species("foe", v))
	_add_row("foe_level", "Foe: level", PkOptionRow.Kind.CHOICE, _foe_level - 2, _levels, 
		func(v): _pick_level("foe", v))
	for i in 4:
		_add_row("foe_move_%d" % i, "Foe: move %d" % (i + 1), PkOptionRow.Kind.CHOICE, 
			_move_index(String(_foe_moves[i])), _move_choices(), func(v): _pick_move("foe", i, v))
	_add_row("brain", "Foe brain", PkOptionRow.Kind.CHOICE, _brain_i, BRAINS, func(v): _brain_i = v)
	_add_row("tier", "AI tier", PkOptionRow.Kind.CHOICE, _tier_i, _tier_labels(), func(v): _tier_i = v)
	_add_row("sturdy", "Sturdy (you ≥30%)", PkOptionRow.Kind.TOGGLE, _sturdy, [], func(v): _sturdy = v)
	_add_row("immortal", "Foe immortal", PkOptionRow.Kind.TOGGLE, _foe_immortal, [], func(v): _foe_immortal = v)
	_add_row("ranges", "Show ranges", PkOptionRow.Kind.TOGGLE, _ranges, [], func(v): _ranges = v)


func _add_row(key: String, label: String, kind: int, value, choices: Array, cb: Callable) -> void :
	var r: = PkOptionRow.make(label, kind, value, choices)
	if kind == PkOptionRow.Kind.ACTION:
		r.activated.connect(cb)
	else:
		r.changed.connect(cb)
	_setup_list.add_row(r)
	_setup_rows[key] = r



func _default_kit(species: String, level: int) -> Array:
	var out: Array = Dex.moves_at(species, level).duplicate()
	while out.size() < 4:
		out.append("")
	return out.slice(0, 4)


func _move_choices() -> Array:
	return ["—"] + _moves


func _move_index(id: String) -> int:
	return 0 if id == "" else _moves.find(id) + 1


func _tier_labels() -> Array:
	var out: Array = []
	for t in TIERS:
		out.append("%s %.1f" % [t[0], t[1]])
	return out


func _pick_species(side: String, v: int) -> void :
	var sp: String = _species[v]
	if side == "you":
		_you_species = sp
		_you_moves = _default_kit(sp, _you_level)
	else:
		_foe_species = sp
		_foe_moves = _default_kit(sp, _foe_level)
	_sync_move_rows(side)


func _pick_level(side: String, v: int) -> void :
	if side == "you":
		_you_level = int(_levels[v])
		_you_moves = _default_kit(_you_species, _you_level)
	else:
		_foe_level = int(_levels[v])
		_foe_moves = _default_kit(_foe_species, _foe_level)
	_sync_move_rows(side)


func _pick_move(side: String, slot: int, v: int) -> void :
	var id: = "" if v <= 0 else String(_moves[v - 1])
	if side == "you":
		_you_moves[slot] = id
	else:
		_foe_moves[slot] = id


func _sync_move_rows(side: String) -> void :
	var moves: Array = _you_moves if side == "you" else _foe_moves
	for i in 4:
		var r = _setup_rows.get("%s_move_%d" % [side, i])
		if r != null:
			r.set_value_silent(_move_index(String(moves[i])))





func _start_duel() -> void :
	if not _duel or _duel_busy or Battle.in_battle or Game.cutscene:
		return
	_run_duel()


func _run_duel() -> void :
	_duel_busy = true
	while true:
		await _fight_once()
		if not _restart_wanted or not _duel:
			break
		_restart_wanted = false
	_duel_busy = false
	_end_fight_ui()


func _fight_once() -> void :
	if Battle.in_battle:
		Battle.end_battle("fled")
	while not Game._sending.is_empty():
		await get_tree().process_frame
	await get_tree().process_frame
	_ensure_duel_world()
	var you = MonScript.create(_you_species, _you_level)
	you.moves = _kit(_you_moves)
	Kit.reset_party([you])
	var foe = MonScript.create(_foe_species, _foe_level)
	foe.moves = _kit(_foe_moves)
	foe.owner = "Foe"
	_duel_hits.clear()
	_duel_rate.clear()
	_duel_result = ""
	_swapped = false
	_foe_frozen = false
	_foe_body = null
	_fight_t0 = Time.get_ticks_msec()
	_setup_win.visible = false
	_readout_win.visible = _readout_on
	_duel_hud.visible = true
	_setup_list.active = false
	_duel_started = true
	print("[duel] %s Lv%d vs %s Lv%d (%s)" % [_you_species, _you_level, _foe_species, _foe_level, _brain_label()])
	_duel_result = await Battle.start_trainer_battle(_duel_foe_npc, "FOE", [foe], {
		"ai_think_scale": float(TIERS[_tier_i][1]), "center": DUEL_CENTER, "arena": DUEL_ARENA, 
		"scripted": true, "intro_text": "Duel!"})
	_duel_started = false
	_foe_body = null
	print("[duel] result: %s" % _duel_result)



func _ensure_duel_world() -> void :
	if is_instance_valid(_duel_world):
		return
	_duel_world = Node3D.new()
	_duel_world.name = "DuelWorld"
	add_child(_duel_world)
	_duel_player = load("res://scenes/player.tscn").instantiate()
	_duel_player.position = Vector3(0, 0, 6)
	_duel_world.add_child(_duel_player)
	_duel_foe_npc = load("res://scenes/npc.tscn").instantiate()
	_duel_foe_npc.npc_name = "FOE"
	_duel_foe_npc.sprite_sheet = load("res://assets/sprites/npc_rival.png")
	_duel_foe_npc.wander_radius = 0.0
	_duel_foe_npc.scripted = true
	_duel_world.add_child(_duel_foe_npc)
	_duel_foe_npc.global_position = Vector3(0, 0, -6)
	_duel_hud = CanvasLayer.new()
	_duel_hud.set_script(load("res://scripts/hud.gd"))
	_duel_hud.visible = _duel
	add_child(_duel_hud)


func _kit(moves: Array) -> Array:
	var out: Array = []
	for m in moves:
		if m != "" and not out.has(m):
			out.append(m)
	return out


func _end_fight_ui() -> void :
	_duel_started = false
	_foe_body = null
	_clear_rings()
	if _readout_win != null:
		_readout_win.visible = false
	if _duel_hud != null:
		_duel_hud.visible = false
	if _setup_win != null and _duel:
		_setup_win.visible = true
		_setup_list.active = true


func _brain_label() -> String:
	if _brain_i >= BRAINS.size() - 1:
		return "AI %s %.1f" % [TIERS[_tier_i][0], TIERS[_tier_i][1]]
	return BRAINS[_brain_i]





func _restart_duel() -> void :
	_restart_wanted = true
	if Battle.in_battle:
		Battle.end_battle("fled")


func _leave_fight() -> void :
	_restart_wanted = false
	if Battle.in_battle:
		Battle.end_battle("fled")


func _refill(c) -> void :
	if not is_instance_valid(c):
		return
	c.hp = c.max_hp
	if c.mon:
		c.mon.hp = c.hp
	c.refresh_label()




func _swap_control() -> void :
	var p = Battle.partner
	var w = Battle.wild
	if not is_instance_valid(p) or not is_instance_valid(w):
		return
	_swapped = not _swapped
	if _swapped:
		w.mode = Creature.Mode.PLAYER
		p.mode = Creature.Mode.BATTLE_AI
	else:
		p.mode = Creature.Mode.PLAYER
		_apply_brain()
	_duel_hit_line("— swapped control: you drive %s" % w.species)



func _freeze_foe() -> void :
	if not is_instance_valid(_foe_body):
		return
	_foe_frozen = not _foe_frozen
	if _foe_frozen:
		_foe_body.mode = Creature.Mode.IDLE
	else:
		_apply_brain()
	_duel_hit_line("— foe AI %s" % ("frozen" if _foe_frozen else "live"))



func _apply_brain() -> void :
	if not is_instance_valid(_foe_body) or _foe_frozen:
		return
	if _brain_i >= BRAINS.size() - 1:
		_foe_body.mode = Creature.Mode.BATTLE_AI
		_foe_body.ai_think_scale = float(TIERS[_tier_i][1])
		_foe_body.ai_uses_moves = true
	else:
		_foe_body.mode = Creature.Mode.DUMMY
		_foe_body.dummy_style = _brain_i
		_foe_body.ai_uses_moves = false


func _on_duel_battle_started(_partner, foe) -> void :
	if not _duel_started:
		return
	_foe_body = foe
	_apply_brain()
	if _foe_immortal and is_instance_valid(foe):
		foe.immortal = true




func _on_duel_move_used(user, mv) -> void :
	if not _duel_started or user != _controlled():
		return
	var id: = String(mv.get("id", ""))
	var r: Array = _duel_rate.get(id, [0, 0])
	r[1] += 1
	_duel_rate[id] = r



func _controlled():
	return Battle.wild if _swapped else Battle.partner


func _duel_note_hit(user, target, info: Dictionary) -> void :
	var id: = String(info.get("move", ""))
	if user == _controlled():
		var r: Array = _duel_rate.get(id, [0, 0])
		if int(info.damage) > 0:
			r[0] += 1
		_duel_rate[id] = r
	var tag: = ""
	if info.eff == 0.0:
		tag = " (no effect)"
	elif info.eff > 1.0:
		tag = " (x%s super)" % info.eff
	elif info.eff < 1.0:
		tag = " (x%s)" % info.eff
	var st: = " +%s" % info.status if info.has("status") else ""
	_duel_hit_line("t=%.1f  %s → %s  %s  %d dmg%s%s" % [_duel_t(), user.species, target.species, id, info.damage, tag, st])


func _duel_note_miss(user, target, mv) -> void :
	_duel_hit_line("t=%.1f  %s → %s  %s  MISSED" % [_duel_t(), user.species, target.species, mv.id])


func _duel_hit_line(s: String) -> void :
	_duel_hits.push_front(s)
	_duel_hits = _duel_hits.slice(0, 8)


func _duel_t() -> float:
	return (Time.get_ticks_msec() - _fight_t0) / 1000.0


func _duel_text() -> String:
	var state: = _duel_result if _duel_result != "" else ("fighting" if _duel_started else "setup")
	var slow: = ("   [color=#ffbb55]SLOW %.2f×[/color]" % SLOWS[_slow_i]) if _slow_i > 0 else ""
	var lines: Array = [
		"[b]DUEL[/b]  %s Lv%d  vs  %s Lv%d" % [_you_species, _you_level, _foe_species, _foe_level], 
		"brain: [b]%s[/b]   %s%s" % [_brain_label(), state, slow], 
		"", 
		"[b]Last hits[/b]  (t = seconds into the fight)"]
	if _duel_hits.is_empty():
		lines.append("[color=#8899aa]—[/color]")
	for h in _duel_hits:
		lines.append(h)

	lines.append("")
	lines.append("[b]Hit rate[/b]  (yours, hits / casts)")
	if _duel_rate.is_empty():
		lines.append("[color=#8899aa]—[/color]")
	for id in _duel_rate.keys():
		var r: Array = _duel_rate[id]
		lines.append("%-16s %d / %d" % [id, r[0], r[1]])

	return "\n".join(lines)




func _duel_process(_delta: float) -> void :
	_update_hints()
	if _readout_win != null and _duel_started:
		_readout_win.visible = _readout_on
	if _setup_win != null and _setup_win.visible and not _setup_list.rows.is_empty():
		_setup_scroll.ensure_control_visible(_setup_list.rows[_setup_list.index])
	if _sturdy and Battle.in_battle and is_instance_valid(Battle.partner) and Battle.partner.hp > 0:
		var floor_hp: = int(ceil(0.3 * Battle.partner.max_hp))
		if Battle.partner.hp < floor_hp:
			Battle.partner.heal(floor_hp - Battle.partner.hp)
	if _foe_immortal and is_instance_valid(_foe_body):
		_foe_body.immortal = true
	_update_rings()
	if _readout != null:
		_readout.text = _duel_text()





func _update_rings() -> void :
	var want: Array = []
	if _ranges and Battle.in_battle:
		for c in [Battle.partner, Battle.wild]:
			if is_instance_valid(c):
				want.append(c)
	while _rings.size() > want.size():
		var old: MeshInstance3D = _rings.pop_back()
		if is_instance_valid(old):
			old.queue_free()
	while _rings.size() < want.size():
		var mi: = MeshInstance3D.new()
		var cm: = CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 0.04
		var m: = StandardMaterial3D.new()
		m.albedo_color = Color(0.35, 0.8, 1.0, 0.22)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cm.material = m
		mi.mesh = cm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_duel_world.add_child(mi)
		_rings.append(mi)
	for i in _rings.size():
		var c = want[i]
		var reach: = _reach_of(c)
		_rings[i].global_position = Vector3(c.global_position.x, 0.05, c.global_position.z)
		_rings[i].scale = Vector3(reach, 1.0, reach)


func _reach_of(c) -> float:
	var r: = 1.5
	for id in c.moves:
		var mv: Dictionary = Dex.move(id)
		r = maxf(r, float(mv.get("range", 0.0)))
		r = maxf(r, float(mv.get("radius", 0.0)))
	return r


func _clear_rings() -> void :
	for r in _rings:
		if is_instance_valid(r):
			r.queue_free()
	_rings.clear()


func _exit_tree() -> void :
	if Game.battle_started.is_connected(_on_duel_battle_started):
		Game.battle_started.disconnect(_on_duel_battle_started)
	var moves_node: = get_node_or_null("/root/Moves")
	if moves_node != null and moves_node.move_used.is_connected(_on_duel_move_used):
		moves_node.move_used.disconnect(_on_duel_move_used)
	if _duel:
		Engine.time_scale = 1.0
