class_name PkPartyRing
extends Control




signal picked(slot: int)
signal held(slot: int)
signal closed

const PokemonSprites: = preload("res://scripts/pokemon_sprites.gd")
const HOLD_SECS: = 0.4
const RADIUS: = 165.0
const SLOT_R: = 44.0
const ICON_PX: = 72

var is_open: = false
var mode: = "overworld"
var highlight: = 0

var _hold_slot: = -1
var _hold_t: = 0.0
var _t: = 0.0


func _init() -> void :
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func open(m: String) -> void :
	mode = m
	is_open = true
	visible = true
	highlight = 0
	_hold_slot = -1
	queue_redraw()


func close() -> void :
	if not is_open:
		return
	is_open = false
	visible = false
	_hold_slot = -1
	closed.emit()


func _process(delta: float) -> void :
	if not is_open:
		return
	_t += delta
	if Input.is_action_just_pressed("pk_back"):
		close()
		return
	if Controls.is_pad():


		var stick: = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if stick.length() > 0.5:
			highlight = _slot_from_dir(stick)
		if Input.is_action_just_released("party_ring"):
			_press(highlight)
			_release()
			return
	else:
		if Input.is_action_just_pressed("pk_left") or Input.is_action_just_pressed("pk_up"):
			highlight = (highlight + 5) % 6
		if Input.is_action_just_pressed("pk_right") or Input.is_action_just_pressed("pk_down"):
			highlight = (highlight + 1) % 6
	if Input.is_action_just_pressed("pk_ok"):
		_press(highlight)
	if Input.is_action_just_released("pk_ok"):
		_release()
	if _hold_slot >= 0:
		_hold_t += delta
		if _hold_t >= HOLD_SECS:
			var s: = _hold_slot
			_hold_slot = -1
			held.emit(s)
	queue_redraw()



func _slot_from_dir(v: Vector2) -> int:
	var ang: = atan2(v.y, v.x)
	var best: = 0
	var best_d: = 999.0
	for i in 6:
		var a: = - PI * 0.5 + TAU * float(i) / 6.0
		var d: = absf(angle_difference(a, ang))
		if d < best_d - 1e-06:
			best_d = d
			best = i
	return best


func _press(slot: int) -> void :
	_hold_slot = slot
	_hold_t = 0.0


func _release() -> void :
	if _hold_slot >= 0:
		var s: = _hold_slot
		_hold_slot = -1
		picked.emit(s)






func slot_at(gp: Vector2) -> int:
	return _slot_at(gp)



func press_slot(i: int) -> void :
	if i < 0:
		return
	highlight = i
	_press(i)



func release_slot() -> void :
	_release()




func _gui_input(e: InputEvent) -> void :
	if not is_open:
		return

	if Controls.is_touch():
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			var slot: = _slot_at(e.position)
			if slot >= 0:
				highlight = slot
				_press(slot)
		else:
			_release()
	elif e is InputEventMouseMotion and _hold_slot < 0:
		var slot: = _slot_at(e.position)
		if slot >= 0:
			highlight = slot


func _slot_at(p: Vector2) -> int:
	for i in 6:
		if p.distance_to(_slot_center(i)) <= SLOT_R:
			return i
	return -1


func _slot_center(i: int) -> Vector2:
	var a: = - PI * 0.5 + TAU * float(i) / 6.0
	return size * 0.5 + Vector2(cos(a), sin(a)) * RADIUS




func _draw() -> void :
	if not is_open:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	draw_arc(size * 0.5, RADIUS, 0.0, TAU, 64, Color(UiKit.INK, 0.45), 6.0, true)
	for i in 6:
		_draw_slot(i, _slot_center(i))


func _draw_slot(i: int, c: Vector2) -> void :
	var has_mon: = i < Game.party.size()
	var mon = Game.party[i] if has_mon else null
	var fainted: bool = has_mon and mon.hp <= 0
	if i == highlight:
		draw_arc(c, SLOT_R + 8.0, 0.0, TAU, 48, UiKit.PAPER, 3.0, true)
	draw_circle(c, SLOT_R, Color(UiKit.INK, 0.72))
	if not has_mon:
		return
	var ratio: = clampf(float(mon.hp) / maxf(float(mon.max_hp), 1.0), 0.0, 1.0)
	UiKit.draw_ring(self, c, SLOT_R, 5.0, ratio, UiKit.hp_color(ratio), Color(UiKit.INK, 0.55))
	var tint: = PokemonSprites.tint(mon.species)
	if fainted:
		tint = Color(0.4, 0.4, 0.4)
	var d: = SLOT_R * 0.72
	draw_texture_rect(PokemonSprites.disc_icon(mon.species, ICON_PX), 
		Rect2(c - Vector2(d, d), Vector2(d, d) * 2.0), false, tint)
	var f: = UiKit.body_font()
	draw_string(f, c + Vector2( - SLOT_R, SLOT_R + 20), "%d %s" % [i + 1, mon.display_name], 
		HORIZONTAL_ALIGNMENT_CENTER, SLOT_R * 2.0, 14, UiKit.PAPER)
