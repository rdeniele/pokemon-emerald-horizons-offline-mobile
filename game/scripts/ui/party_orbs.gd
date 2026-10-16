class_name PartyOrbs
extends Control









const PokemonSprites: = preload("res://scripts/pokemon_sprites.gd")

const ControlsScript: = preload("res://scripts/controls.gd")


const PANEL_W: = 72.0
const SLOT_GAP: = 60.0
const CX: = 36.0
const CY0: = 36.0
const PANEL_H: = 6.0 * SLOT_GAP + 12.0

const TOP: = 64.0
const R_OUTER: = 28.0
const R_DISC: = 24.0
const R_ICON: = 23.0
const R_EMPTY: = 18.0


const PANEL_A_TOUCH: = 0.5
const ANIM: = 8.0
const FLASH: = 0.2
const NAME_HOLD: = 1.5
const ICON_PX: = 64




var top: = TOP



var _orbs: Array = []
var _t: = 0.0
var _name_t: = {}
var _prev_fighting: = {}
var _hover: = -1




func scale_factor() -> float:
	if not ControlsScript.is_touch():
		return 1.0
	var k: = ControlsScript.ui_scale()
	var max_k: = (get_viewport_rect().size.y - top - 8.0 - 12.0 * k) / (6.0 * SLOT_GAP)
	return minf(k, maxf(max_k, 1.0))



func set_top(t: float) -> void :
	top = t
	size = panel_size()
	custom_minimum_size = size
	queue_redraw()



func panel_size() -> Vector2:
	return Vector2(PANEL_W, PANEL_H) * scale_factor()




func panel_alpha() -> float:
	return PANEL_A_TOUCH if ControlsScript.is_touch() else 0.8


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = panel_size()
	custom_minimum_size = size
	mouse_exited.connect( func(): _hover = -1)
	Game.party_changed.connect(_rebuild)
	_rebuild()



func _rebuild() -> void :
	var n: = mini(Game.party.size(), 6)
	_orbs.resize(n)
	for i in n:
		if _orbs[i] == null:
			_orbs[i] = {"hp": 1.0, "hp_shown": 1.0, "flash": 0.0}
	size = panel_size()
	custom_minimum_size = size
	queue_redraw()






func ring_ratios(i: int) -> Vector2:
	if i < 0 or i >= Game.party.size():
		return Vector2.ZERO
	var mon = Game.party[i]
	return Vector2(clampf(float(mon.hp) / maxf(float(mon.max_hp), 1.0), 0.0, 1.0), _pp_ratio(i, mon))



func orb_state(i: int) -> String:
	if i < 0 or i >= Game.party.size():
		return ""
	if Game.party[i].hp <= 0:
		return "fainted"
	if Game.is_out(i):
		var c = Game.companions[i]
		if is_instance_valid(c):
			if c.evolving:
				return "evolving"
			if Battle.in_battle and Battle.allies.has(c):
				return "fighting"
			return "out"
	return ""



func is_controlled(i: int) -> bool:
	if not Battle.in_battle or Battle.allies.size() < 2 or not Game.is_out(i):
		return false
	return Battle.partner == Game.companions[i]



func flash_name(i: int) -> void :
	if i >= 0 and i < _orbs.size():
		_name_t[i] = NAME_HOLD



func slot_center(i: int) -> Vector2:
	var k: = scale_factor()
	return Vector2(CX, CY0 + float(i) * SLOT_GAP) * k



func slot_at(p: Vector2) -> int:
	var r: = R_DISC * scale_factor()
	for i in mini(Game.party.size(), 6):
		if p.distance_to(slot_center(i)) <= r:
			return i
	return -1



func press_slot(i: int) -> void :
	if i < 0 or i >= Game.party.size():
		return
	flash_name(i)
	Game._party_key(i, false)


func _pp_ratio(i: int, mon) -> float:
	if Battle.in_battle and Game.is_out(i):
		var c = Game.companions[i]
		if is_instance_valid(c) and Battle.allies.has(c):
			return clampf(float(c.pp_max) / maxf(float(c.pp_base), 1.0), 0.0, 1.0)
	return clampf(float(mon.pp) / maxf(float(mon.pp_base), 1.0), 0.0, 1.0)




func _process(delta: float) -> void :

	visible = not Battle.in_battle
	_t += delta
	_refresh(delta)
	for i in _orbs.size():
		if Input.is_action_just_pressed("party_%d" % (i + 1)):
			_name_t[i] = NAME_HOLD
	for i in _name_t.keys():
		_name_t[i] = float(_name_t[i]) - delta
		if float(_name_t[i]) <= 0.0:
			_name_t.erase(i)
	queue_redraw()


func _refresh(delta: float) -> void :
	for i in _orbs.size():
		var o: Dictionary = _orbs[i]
		var mon = Game.party[i]
		var hp: = clampf(float(mon.hp) / maxf(float(mon.max_hp), 1.0), 0.0, 1.0)
		if hp < float(o.hp_shown) - 0.001:
			o.flash = FLASH
		o.hp = hp
		o.hp_shown = move_toward(float(o.hp_shown), hp, delta * ANIM)
		o.flash = maxf(float(o.flash) - delta, 0.0)
		var st: = orb_state(i)
		if st == "fighting" and not _prev_fighting.get(i, false):
			_name_t[i] = NAME_HOLD
		_prev_fighting[i] = st == "fighting"




func _gui_input(e: InputEvent) -> void :
	if e is InputEventMouseMotion:
		_hover = slot_at(e.position)
	elif e is InputEventScreenTouch and e.pressed:
		var s: = slot_at(e.position)
		if s >= 0:
			_hover = s
			press_slot(s)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:



		if e.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var s: = slot_at(e.position)
		if s >= 0:
			press_slot(s)




func _draw() -> void :

	var k: = scale_factor()
	draw_style_box(UiKit.pill(Color(UiKit.INK, panel_alpha()), Color(UiKit.PAPER, 0.12), 16), 
		Rect2(Vector2.ZERO, panel_size()))
	for i in 6:
		_draw_slot(i, slot_center(i), k)
	if ControlsScript.is_pad():
		_keycap(Vector2(CX, PANEL_H + 16.0), ControlsScript.key_label("party_ring"), true, 1.0)


func _draw_slot(i: int, c: Vector2, k: float) -> void :
	var has_mon: = i < Game.party.size()
	if not has_mon:
		draw_arc(c, R_EMPTY * k, 0.0, TAU, 40, Color(UiKit.RIM, 0.35), 2.0, true)
		return
	var mon = Game.party[i]
	var o: Dictionary = _orbs[i]
	var st: = orb_state(i)
	var fainted: = st == "fainted"
	var scale: = (1.12 if st == "fighting" else 1.0) * k
	var r_disc: = R_DISC * scale
	var r_out: = R_OUTER * scale
	_draw_halo(c, r_out, st)

	draw_circle(c, r_disc, Color(UiKit.INK, 0.7))
	var icon: = PokemonSprites.icon(mon.species)
	if icon:
		var t: = PokemonSprites.tint(mon.species)
		if fainted:
			t = Color(0.4, 0.4, 0.4)
		draw_texture_rect(PokemonSprites.disc_icon(mon.species, ICON_PX), 
			Rect2(c - Vector2(R_ICON, R_ICON) * k, Vector2(R_ICON, R_ICON) * 2.0 * k), false, t)

	var hp_ratio: = 0.0 if fainted else float(o.hp_shown)
	var hp_col: = UiKit.DIM if fainted else UiKit.hp_color(float(o.hp))
	if float(o.flash) > 0.0:
		hp_col = UiKit.PAPER
	elif st == "fighting" and float(o.hp) < 0.2:
		hp_col = hp_col.lerp(UiKit.PAPER, 0.5 + 0.5 * sin(_t * TAU * 2.0))
	UiKit.draw_ring(self, c, r_disc, 4.0 * k, hp_ratio, hp_col, Color(UiKit.INK, 0.55))
	if fainted:
		draw_line(c + Vector2( - r_disc * 0.8, r_disc * 0.8), c + Vector2(r_disc * 0.8, - r_disc * 0.8), UiKit.RED, 3.0, true)
	if not ControlsScript.is_pad() and not ControlsScript.is_touch():
		_keycap(c + Vector2(-30, -16), ControlsScript.key_label("party_%d" % (i + 1)), false, 1.0)
	_draw_level_tag(mon.level, c + Vector2(18, 20) * k, fainted, k)
	if is_controlled(i):
		draw_colored_polygon(PackedVector2Array([c + Vector2( - r_out - 15 * k, -7 * k), c + Vector2( - r_out - 4 * k, 0), c + Vector2( - r_out - 15 * k, 7 * k)]), UiKit.PAPER)
	if _name_t.has(i) or _hover == i:
		_draw_name(mon.display_name, c, r_out, float(_name_t.get(i, NAME_HOLD)), k)


func _draw_halo(c: Vector2, r: float, st: String) -> void :
	match st:
		"out":
			draw_arc(c, r, 0.0, TAU, 48, UiKit.AMBER, 2.0, true)
		"fighting":
			var a: = 0.6 + 0.4 * (0.5 + 0.5 * sin(_t * TAU / 1.2))
			draw_arc(c, r, 0.0, TAU, 48, Color(UiKit.RED, a), 2.5, true)
		"evolving":
			var a2: = 0.5 + 0.5 * (0.5 + 0.5 * sin(_t * TAU / 1.2))
			draw_arc(c, r, 0.0, TAU, 48, Color(1.0, 0.85, 0.35, a2), 2.5, true)



func _keycap(center: Vector2, label: String, dark: bool, k: float) -> void :
	if label == "":
		return
	var f: = UiKit.body_font()
	var fs: = int(11.0 * k)
	var h: = 18.0 * k
	var w: = maxf(h, f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0 * k)
	var r: = Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
	draw_style_box(UiKit.pill(UiKit.INK if dark else UiKit.PAPER, UiKit.RIM if not dark else Color.TRANSPARENT, 6), r)
	draw_string(f, Vector2(r.position.x, r.get_center().y + 4), label, HORIZONTAL_ALIGNMENT_CENTER, w, fs, UiKit.PAPER if dark else UiKit.INK)


func _draw_level_tag(level: int, at: Vector2, fainted: bool, k: float) -> void :
	var f: = UiKit.body_font()
	var s: = "L%d" % level
	var r: = Rect2(at - Vector2(12.0, 8.0) * k, Vector2(24.0, 16.0) * k)
	draw_style_box(UiKit.pill(Color(UiKit.INK, 0.9), Color.TRANSPARENT, 7), r)
	draw_string(f, Vector2(r.position.x, r.get_center().y + 4), s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(11.0 * k), 
		UiKit.DIM if fainted else UiKit.PAPER)



func _draw_name(name_s: String, c: Vector2, r_out: float, t_left: float, k: float) -> void :
	var f: = UiKit.body_font()
	var s: = name_s.to_upper()
	var w: = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16.0 * k)).x + 22.0 * k
	var h: = 26.0 * k
	var slide: = 12.0 * k * clampf(1.0 - (NAME_HOLD - t_left) / 0.18, 0.0, 1.0)
	var r: = Rect2(Vector2(c.x - r_out - 6.0 * k - w + slide, c.y - h * 0.5), Vector2(w, h))
	draw_style_box(UiKit.glass(0.62, 12), r)
	draw_string(f, Vector2(r.position.x + 11.0 * k, r.get_center().y + 5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16.0 * k), UiKit.PAPER)
