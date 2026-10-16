extends Control













const UI: = preload("res://scripts/ui/ui_draw.gd")
const HintBar: = preload("res://scripts/ui/kit/pk_hint_bar.gd")
const ExpBarMath: = preload("res://scripts/ui/exp_bar_math.gd")

const Controls: = preload("res://scripts/controls.gd")


const CARD_W: = 506.0
const CARD_H: = 92.0
const CARD_MARGIN: = 14.0
const CARD_TOP: = 12.0
const ALLY_H: = 40.0


const ALLY_W: = 340.0
const PORTRAIT_R: = 37.0
const HP_W: = 392.0
const HP_H: = 12.0
const PP_W: = 300.0
const PP_H: = 6.0
const EXP_W: = 86.0
const EXP_H: = 4.0
const PIP_R: = 8.0
const PIP_Y: = 118.0
const PIP_X0: = 30.0
const PIP_STEP: = 22.0
const PIPS: = 6
const MOVE_R: = 42.0

const MOVE_R_TOUCH: = 46.0
const MOVE_DX: = 92.0
const MOVE_DY: = 68.0

const DIAMOND_AT: = Vector2(-182.0, -134.0)
const ITEMS_AT: = Vector2(-368.0, -154.0)
const JUMP_AT: = Vector2(-368.0, -70.0)
const SWAP_AT: = Vector2(-368.0, -208.0)
const ITEMS_SIZE: = Vector2(80.0, 44.0)
const JUMP_R: = 32.0




const MOVE_TAP_PX: = MOVE_R_TOUCH * 2.0
const CIRCLE_R: = 32.0
const CIRCLE_TAP_PX: = CIRCLE_R * 2.0
const CIRCLE_GAP: = 6.0


const DIAMOND_AT_T: = Vector2(-150.0, -134.0)

const CLUSTER_W: = 0.4
const CLUSTER_H: = 0.6

const LOG_W: = 560.0
const LOG_TOP: = 116.0
const LOG_H: = 32.0

var _player_card: Control
var _foe_card: Control
var _ally_card: Control
var _moves: Array = []
var _items_btn: Control
var _jump_btn: Control
var _swap_btn: Control
var _sprint_btn: Control
var _pips: Control
var _overheads: Array = []
var _shown: = false

var _sized: = Vector3(-1.0, -1.0, -1.0)
var _tw: Tween
var _hint: Control
var _hint_tw: Tween



var _popups: Array = []
const POPUP_LIFE: = 1.8
const POPUP_H: = 27.0
const POPUP_GAP: = 12.0
const POPUP_RISE: = 6.0
const POPUP_MAX: = 4


func _ready() -> void :
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false

	_foe_card = FighterCard.new()
	_foe_card.foe = true
	_place_at(_foe_card, Vector2(1, 0), Vector2(CARD_W, CARD_H), 
		Vector2( - CARD_MARGIN - CARD_W * 0.5, CARD_TOP + CARD_H * 0.5))

	_player_card = FighterCard.new()
	_place_at(_player_card, Vector2(0, 0), Vector2(CARD_W, CARD_H), 
		Vector2(CARD_MARGIN + CARD_W * 0.5, CARD_TOP + CARD_H * 0.5))


	_ally_card = AllyCard.new()
	_place_at(_ally_card, Vector2(0, 0), Vector2(ALLY_W, ALLY_H), 
		Vector2(CARD_MARGIN + ALLY_W * 0.5, CARD_TOP + CARD_H + 6.0 + ALLY_H * 0.5))


	_place_moves(MOVE_R)

	_items_btn = ItemsButton.new()
	_place_at(_items_btn, Vector2(1, 1), ITEMS_SIZE, ITEMS_AT)

	_jump_btn = JumpButton.new()
	_place_at(_jump_btn, Vector2(1, 1), Vector2(JUMP_R * 2.0, JUMP_R * 2.0), JUMP_AT)


	_swap_btn = SwapButton.new()
	_place_at(_swap_btn, Vector2(1, 1), ITEMS_SIZE, SWAP_AT)
	_swap_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_swap_btn.visible = false


	_sprint_btn = SprintButton.new()
	_place_at(_sprint_btn, Vector2(1, 1), ITEMS_SIZE, ITEMS_AT)
	_sprint_btn.visible = false


	_pips = PipsRow.new()
	_place_at(_pips, Vector2(0, 0), Vector2((PIPS - 1) * PIP_STEP + PIP_R * 2.0, PIP_R * 2.0), 
		Vector2(PIP_X0 - PIP_R, PIP_Y - PIP_R))
	_pips.mouse_filter = Control.MOUSE_FILTER_STOP

	for role in ["foe", "you", "ally"]:
		var o: = Overhead.new()
		o.role = role
		o.foe = role == "foe"
		add_child(o)
		move_child(o, 0)
		_overheads.append(o)

	var mv_sig = get_node_or_null("/root/Moves")
	if mv_sig:
		mv_sig.move_used.connect(_on_move_used)
	Game.item_used.connect(_on_item_used)



func _log() -> Node:
	var p: = get_parent()
	if p == null or p.get("battle_log") == null:
		return null
	return p.battle_log



static func confirm_key() -> String:
	return Controls.key_label("confirm")




func show_hint(hints: Array, secs: = 3.5) -> void :
	if hints.is_empty():
		return
	if _hint == null:
		_hint = HintBar.new()
		add_child(_hint)
		_hint.visible = false
		_hint.modulate.a = 0.0
	_hint.set_hints(hints)
	_hint.position = Vector2(size.x * 0.5 - _hint.get_combined_minimum_size().x * 0.5, 152.0)
	if _hint_tw:
		_hint_tw.kill()
	_hint.visible = true
	_hint_tw = create_tween()
	_hint_tw.tween_property(_hint, "modulate:a", 1.0, 0.15)
	_hint_tw.tween_interval(secs)
	_hint_tw.tween_property(_hint, "modulate:a", 0.0, 0.3)
	_hint_tw.tween_callback( func(): _hint.visible = false)




func hint_hold(hints: Array) -> void :
	if hints.is_empty():
		return
	var lg: = _log()
	if lg != null and hints.size() == 1:
		lg.hint_glyph = String(hints[0][0])
		lg.hint_text = String(hints[0][1])
		return
	if _hint == null:
		_hint = HintBar.new()
		add_child(_hint)
		_hint.visible = false
		_hint.modulate.a = 0.0
	_hint.set_hints(hints)
	_hint.position = Vector2(size.x * 0.5 - _hint.get_combined_minimum_size().x * 0.5, 152.0)
	if _hint_tw:
		_hint_tw.kill()
	_hint.visible = true
	_hint.modulate.a = 1.0



func hint_clear() -> void :
	var lg: = _log()
	if lg != null:
		lg.hint_glyph = ""
		lg.hint_text = ""
	if _hint == null:
		return
	if _hint_tw:
		_hint_tw.kill()
	_hint_tw = create_tween()
	_hint_tw.tween_property(_hint, "modulate:a", 0.0, 0.2)
	_hint_tw.tween_callback( func(): _hint.visible = false)




func _place_at(c: Control, anchor: Vector2, size_px: Vector2, center: Vector2) -> void :
	if c.get_parent() != self:
		add_child(c)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = center.x - size_px.x * 0.5
	c.offset_right = center.x + size_px.x * 0.5
	c.offset_top = center.y - size_px.y * 0.5
	c.offset_bottom = center.y + size_px.y * 0.5



func _ui_scale() -> float:
	return Controls.ui_scale() if Controls.is_touch() else 1.0



func _diamond_scale() -> float:
	return Controls.touch_target_scale(MOVE_TAP_PX) if Controls.is_touch() else 1.0



func _circle_scale() -> float:
	return Controls.touch_target_scale(CIRCLE_TAP_PX) if Controls.is_touch() else 1.0




func _place_controls(k: float, kd: float, ks: float) -> void :
	var touch: = Controls.is_touch()
	_place_moves((MOVE_R_TOUCH if touch else MOVE_R) * kd)
	for b: Control in [_items_btn, _jump_btn, _swap_btn, _sprint_btn]:
		b.set("circle", touch)
	if not touch:

		_place_at(_items_btn, Vector2(1, 1), ITEMS_SIZE, ITEMS_AT)
		_place_at(_jump_btn, Vector2(1, 1), Vector2(JUMP_R, JUMP_R) * 2.0, JUMP_AT)
		_place_at(_swap_btn, Vector2(1, 1), ITEMS_SIZE, SWAP_AT)
		_place_at(_sprint_btn, Vector2(1, 1), ITEMS_SIZE, ITEMS_AT)
	else:



		var s: = CIRCLE_R * ks
		kd = minf(kd, maxf((size.x * CLUSTER_W - CIRCLE_GAP - 2.0 * s)
			/ (absf(DIAMOND_AT_T.x) + MOVE_DX + MOVE_R_TOUCH), 1.0))
		_place_moves(MOVE_R_TOUCH * kd)
		var dx: = MOVE_DX * kd
		var dy: = MOVE_DY * kd
		var r: = MOVE_R_TOUCH * kd
		var cx: = size.x + DIAMOND_AT_T.x * kd
		var cy: = size.y + DIAMOND_AT_T.y * kd
		var col_x: = cx - dx - r - CIRCLE_GAP - s
		var row: = cy + dy
		var step: = 2.0 * s + CIRCLE_GAP
		var d: = Vector2(s, s) * 2.0
		for i in 4:
			var b: Control = [_jump_btn, _sprint_btn, _items_btn, _swap_btn][i]
			_place_at(b, Vector2(1, 1), d, Vector2(col_x - size.x, row - i * step - size.y))
	_place_at(_pips, Vector2(0, 0), Vector2((PIPS - 1) * PIP_STEP + PIP_R * 2.0, PIP_R * 2.0) * k, 
		Vector2(PIP_X0 - PIP_R, PIP_Y - PIP_R) * k)



func touch_held(action: String) -> bool:
	var t: = get_node_or_null("/root/Touch")
	return t != null and t.has_method("held") and bool(t.held(action))





func cluster_rect() -> Rect2:
	var rects: Array = []
	for i in _moves.size():
		var mr: = move_rect(i)
		if mr.has_area():
			rects.append(mr)
	for b: Control in [_items_btn, _jump_btn, _sprint_btn]:
		if b != null and b.visible:
			rects.append(Rect2(b.position, b.size))
	if rects.is_empty():
		return Rect2()
	var r: Rect2 = rects[0]
	for i in range(1, rects.size()):
		r = r.merge(rects[i])
	return r



func _place_moves(r: float) -> void :
	var touch: = Controls.is_touch()
	var k: = r / (MOVE_R_TOUCH if touch else MOVE_R)
	var offs: = [Vector2(0, MOVE_DY * k), Vector2(MOVE_DX * k, 0), Vector2( - MOVE_DX * k, 0), Vector2(0, - MOVE_DY * k)]
	for i in 4:
		var b: Control
		if i < _moves.size():
			b = _moves[i]
		else:
			b = MoveButton.new()
			b.index = i
			_moves.append(b)
		_place_at(b, Vector2(1, 1), Vector2(r * 2.0, r * 2.0), (DIAMOND_AT_T if touch else DIAMOND_AT) * k + offs[i])






func card_rect(which: String) -> Rect2:
	var c: Control = _player_card
	if which == "foe":
		c = _foe_card
	elif which == "ally":
		c = _ally_card
	return Rect2(c.position, c.size) if c else Rect2()




func log_rect() -> Rect2:
	var p: = get_parent()
	var log: Control = p.get("battle_log") if p != null else null
	var top: = float(log.offset_top) if log != null else LOG_TOP
	return Rect2(size.x * 0.5 - LOG_W * 0.5, top, LOG_W, LOG_H)



func pips_rect() -> Rect2:
	return Rect2(_pips.position, _pips.size) if _pips else Rect2()



func pip_state(i: int) -> String:
	return _pips.state(i) if _pips else "empty"


func items_rect() -> Rect2:
	return Rect2(_items_btn.position, _items_btn.size) if _items_btn else Rect2()


func jump_rect() -> Rect2:
	return Rect2(_jump_btn.position, _jump_btn.size) if _jump_btn else Rect2()


func swap_rect() -> Rect2:
	return Rect2(_swap_btn.position, _swap_btn.size) if _swap_btn else Rect2()


func sprint_rect() -> Rect2:
	return Rect2(_sprint_btn.position, _sprint_btn.size) if _sprint_btn else Rect2()


func moves_rect() -> Rect2:
	if _moves.is_empty():
		return Rect2()
	var r: = Rect2(_moves[0].position, _moves[0].size)
	for b in _moves:
		r = r.merge(Rect2(b.position, b.size))
	return r


func move_rect(i: int) -> Rect2:
	if i < 0 or i >= _moves.size():
		return Rect2()

	if Controls.is_touch() and not _moves[i].showing_item and _moves[i].move_id() == "":
		return Rect2()
	return Rect2(_moves[i].position, _moves[i].size)




func popup(text: String, col: = UiKit.AMBER) -> void :
	_popups.append({"text": text, "t": 0.0, "col": col})
	if _popups.size() > POPUP_MAX:

		_popups[0].t = maxf(float(_popups[0].t), POPUP_LIFE - 0.3)



func exp_animating() -> bool:
	for c in [_player_card, _ally_card]:
		if is_instance_valid(c) and c.exp_animating():
			return true
	return false



func card_for(mon: RefCounted) -> Control:
	for c in [_player_card, _ally_card]:
		if is_instance_valid(c) and is_instance_valid(c.body) and c.body.mon == mon:
			return c
	return null



func _popup_anchor_y() -> float:
	var top: = CARD_TOP + CARD_H + 4.0
	if is_instance_valid(_ally_card) and is_instance_valid(_ally_card.body):
		top = _ally_card.position.y + _ally_card.size.y + 8.0
	return top + POPUP_MAX * (POPUP_H + POPUP_GAP)


func _draw() -> void :
	_draw_vs()
	if _popups.is_empty():
		return
	var base: = _popup_anchor_y()
	var n: = _popups.size()
	for i in n:
		var p: Dictionary = _popups[i]

		var slot: = n - 1 - i
		var a: = clampf(1.0 - float(p.t) / POPUP_LIFE, 0.0, 1.0)
		var drift: = minf(float(p.t), 0.3) / 0.3 * POPUP_RISE
		var ty: = base - slot * (POPUP_H + POPUP_GAP) - drift
		var s: = String(p.text)
		var w: = UI.text_width(s, 20) + 22.0
		UI.rounded(self, Rect2(30, ty - 21, w, POPUP_H), Color(UiKit.INK, 0.72 * a), 13)
		UI.text(self, Vector2(41, ty), s, 20, Color(p.col, a), 3)



func _draw_vs() -> void :
	if not vs_drawn():
		return
	UI.text(self, Vector2(size.x * 0.5, 58.0), "VS", 30, Color(UiKit.PAPER, 0.86), 5, 
		HORIZONTAL_ALIGNMENT_CENTER, -1.0, UiKit.title_font())



func vs_drawn() -> bool:
	if not visible:
		return false
	var t: = get_node_or_null("/root/Touch")
	return not (t != null and t.has_method("pause_drawn") and bool(t.pause_drawn()))



func foe_chips_rect() -> Rect2:
	if _foe_card == null:
		return Rect2()
	var c: Rect2 = _foe_card.chips_rect()
	return Rect2(_foe_card.position + c.position, c.size) if c.size.x > 0.0 else Rect2()


func _process(delta: float) -> void :
	if not _popups.is_empty():
		for p in _popups:
			p.t = float(p.t) + delta
		_popups = _popups.filter( func(p): return float(p.t) < POPUP_LIFE)
		queue_redraw()
	var want: bool = Battle.in_battle and not Battle._intro
	if want != _shown:
		_shown = want
		if _tw:
			_tw.kill()
		_tw = create_tween().set_parallel(true)
		if want:
			visible = true
			_tw.tween_property(self, "modulate:a", 1.0, 0.25)
			_tw.tween_property(self, "position:y", 0.0, 0.3).from(24.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			_tw.tween_property(self, "modulate:a", 0.0, 0.3)
			_tw.chain().tween_callback( func(): visible = _shown)
	if not visible:
		return

	_player_card.body = Battle.partner if is_instance_valid(Battle.partner) else null
	_foe_card.body = Battle.wild if is_instance_valid(Battle.wild) else null
	_ally_card.body = Battle.ai_ally()
	for o in _overheads:
		match o.role:
			"foe":
				o.body = _foe_card.body
			"you":
				o.body = _player_card.body
			_:
				o.body = _ally_card.body
		o.place()
	_separate_overheads()
	_avoid_cards()

	var ally_out: bool = is_instance_valid(_ally_card.body)


	var k: = _ui_scale()
	var kd: = _diamond_scale()
	var ks: = _circle_scale()
	if not (is_equal_approx(k, _sized.x) and is_equal_approx(kd, _sized.y) and is_equal_approx(ks, _sized.z)):
		_sized = Vector3(k, kd, ks)
		_place_controls(k, kd, ks)
	var pr: = PIP_R * k
	_pips.position.y = (_ally_card.position.y + _ally_card.size.y + 6.0 + pr) if ally_out else PIP_Y + 14.0 * (k - 1.0) - pr
	_pips.position.x = PIP_X0 * k - pr
	_swap_btn.visible = ally_out


	var tut: Node = get_tree().get_first_node_in_group("battle_tutorial") if get_tree() != null else null
	var lesson_wait: bool = tut != null and tut.has_method("waiting_for_dismiss") and bool(tut.waiting_for_dismiss())
	var touch_layer: Node = get_node_or_null("/root/Touch")
	var touch_on: bool = touch_layer != null and touch_layer.visible
	var menu_hide: bool = touch_on and (Game.menu_open or Battle._awaiting_confirm or lesson_wait)
	var touch: = Controls.is_touch()
	for b in _moves:
		b.visible = not menu_hide and ( not touch or b.showing_item or b.move_id() != "")
	_items_btn.visible = not menu_hide
	_jump_btn.visible = not menu_hide
	_pips.visible = not menu_hide
	_swap_btn.visible = ally_out and not menu_hide
	_sprint_btn.visible = touch and not menu_hide
	queue_redraw()
	for c in get_children():
		c.queue_redraw()



func _separate_overheads() -> void :
	for i in _overheads.size():
		for j in range(i + 1, _overheads.size()):
			_separate_pair(_overheads[i], _overheads[j])


func _separate_pair(a: Control, b: Control) -> void :
	if not (a.visible and b.visible):
		return
	var top: Control = a if a.position.y <= b.position.y else b
	var low: Control = b if top == a else a
	if absf(a.position.x - b.position.x) > a.size.x - 30.0:
		return
	var limit: float = low.position.y + low.content_top() - top.content_bottom() - 2.0
	if top.position.y > limit:
		top.position.y = limit



func _avoid_cards() -> void :
	for o in _overheads:
		if not o.visible:
			continue
		for card in [_foe_card, _player_card, _ally_card]:
			if card == _ally_card and not is_instance_valid(_ally_card.body):
				continue
			var cr: Rect2 = card.get_global_rect().grow(6.0)
			var pad: float = (o.size.x - o.W) * 0.5
			var orr: = Rect2(o.position + Vector2(pad, 0), Vector2(o.W, o.content_bottom()))
			if cr.intersects(orr):
				o.position.x = (cr.position.x - o.W - pad) if card == _foe_card else (cr.end.x - pad)


func _on_move_used(user: Node, mv: Dictionary) -> void :
	if user != Battle.partner:
		return
	for b in _moves:
		if b.move_id() == String(mv.get("id", "")):
			b.flash = 1.0


func _on_item_used(slot: int) -> void :

	if slot >= 0 and slot < _moves.size():
		_moves[slot].flash = 1.0




class FighterCard extends Control:
	const UI: = preload("res://scripts/ui/ui_draw.gd")
	const PokemonSprites: = preload("res://scripts/pokemon_sprites.gd")
	const Dex: = preload("res://scripts/dex.gd")
	const Growth: = preload("res://scripts/stats/growth.gd")

	var foe: = false
	var body: Node
	var _species: = ""
	var _hp_ratio: = 1.0
	var _ghost: = 1.0
	var _ghost_hold: = 0.0
	var _chips: = Rect2()

	var drawn_name: = ""

	var lv_rect: = Rect2()
	var hp_text_rect: = Rect2()
	var tag_rect: = Rect2()
	var hp_bar_rect: = Rect2()
	var pp_bar_rect: = Rect2()
	var exp_bar_rect: = Rect2()

	var _exp_shown: = 0.0
	var _exp_mon: RefCounted

	var _exp_level: = 1

	var _exp_scripted: = false

	var _level_hold: = false
	var _level_flash: = 0.0


	const HP_ROW_Y: = 64.0
	const HP_ROW_H: = 12.0
	const PP_ROW_Y: = 79.0
	const PP_ROW_H: = 6.0
	const EXP_ROW_Y: = 79.0
	const EXP_ROW_H: = 6.0

	const EXP_GAP: = 6.0

	const NAME_Y: = 30.0
	const CHIP_Y: = 42.0



	func text_x0() -> float:
		return 16.0 if foe else 98.0

	func text_x1() -> float:
		return size.x - 98.0 if foe else size.x - 16.0


	func exp_track() -> Color:
		return UI.EXP_TRACK



	func _exp_ratio() -> float:
		if not is_instance_valid(body) or body.mon == null:
			return 0.0
		if _level_hold or _exp_level >= Growth.MAX_LEVEL:
			return 1.0
		var growth: = String(body.mon.growth)
		var lo: = float(Growth.exp_for_level(growth, _exp_level))
		var hi: = float(Growth.exp_for_level(growth, _exp_level + 1))
		return clampf((_exp_shown - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)


	func exp_animating() -> bool:
		return is_instance_valid(body) and body.mon != null and _exp_shown < float(body.mon.xp)


	func _say(text: String, col: Color) -> void :
		var p: = get_parent()
		if p and p.has_method("popup"):
			p.popup(text, col)


	func begin_scripted(m: RefCounted, gain: int) -> void :
		_exp_scripted = true
		if _exp_mon != m or _exp_shown > float(m.xp):
			_exp_shown = float(m.xp) - float(gain)
		_exp_mon = m
		_exp_level = ExpBarMath.level_at(String(m.growth), int(_exp_shown))
		_level_hold = false
		_level_flash = 0.0


	func fill_to(target: float, skip_on_press: = true) -> void :
		if not is_instance_valid(body) or body.mon == null:
			return
		var growth: = String(body.mon.growth)
		while _exp_shown < target:
			if skip_on_press and Input.is_action_just_pressed("pk_ok"):
				break
			var step: = ExpBarMath.rate(growth, int(_exp_shown))
			if step <= 0.0:
				break
			_exp_shown = minf(_exp_shown + step * get_process_delta_time(), target)
			await get_tree().process_frame
		_exp_shown = target


	func announce_level(lv: int) -> void :
		_exp_level = lv
		_level_hold = true
		_level_flash = 1.0


	func resume_after_level() -> void :
		_level_hold = false

	func end_scripted() -> void :
		_exp_scripted = false

	func _on_level_up(m: RefCounted, lv: int) -> void :
		_say("%s: Level Up!" % String(m.display_name), UiKit.AMBER)
		Audio.jingle("music/level_up", true)


	func chips_rect() -> Rect2:
		return _chips


	static func foe_tag(trainer_battle: Dictionary) -> String:
		if trainer_battle.is_empty():
			return "WILD"
		return str(trainer_battle.get("name", "TRAINER")).to_upper() + "'S"


	static func ball_states(trainer_battle: Dictionary) -> Array:
		if trainer_battle.is_empty():
			return []
		var total: int = mini(int(trainer_battle.get("total", 1)), 6)
		var fainted: int = clampi(int(trainer_battle.get("fainted", 0)), 0, total)
		var out: Array = []
		for i in total:
			out.append(i >= fainted)
		return out


	func _draw_party_balls(right: Vector2, states: Array) -> void :
		var total_w: = states.size() * 10.0 + (states.size() - 1) * 3.0
		var x: = right.x - total_w
		var y: = right.y - 9.0
		for i in states.size():
			var r: = Rect2(Vector2(x + i * 13.0, y), Vector2(10, 10))
			if states[i]:
				UI._ball(self, r, UiKit.RED, Color(0, 0, 0, 0), Color.WHITE)
			else:
				UI._ball(self, r, UiKit.DIM.darkened(0.3), Color(0, 0, 0, 0), Color(0.75, 0.75, 0.75))
				draw_line(r.position + Vector2(1.5, 8.5), r.position + Vector2(8.5, 1.5), Color(0.08, 0.08, 0.1), 2.0)

	func _ready() -> void :
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void :
		if not is_instance_valid(body):
			return
		if body.species != _species:
			_species = body.species
			_hp_ratio = float(body.hp) / maxf(body.max_hp, 1)
			_ghost = _hp_ratio
		var r: = float(body.hp) / maxf(body.max_hp, 1)
		if r < _hp_ratio:
			_ghost_hold = 0.45
		_hp_ratio = r
		if _ghost < _hp_ratio:
			_ghost = _hp_ratio
		elif _ghost_hold > 0.0:
			_ghost_hold -= delta
		else:
			_ghost = move_toward(_ghost, _hp_ratio, delta * 0.8)




		var m: RefCounted = body.mon if body.mon else null
		if _exp_scripted or Battle._ending:
			pass
		elif m != _exp_mon:
			_exp_mon = m
			_exp_shown = float(m.xp) if m else 0.0
			_exp_level = int(m.level) if m else 1
		elif m:
			if _exp_shown < float(m.xp):
				var growth: = String(m.growth)
				_exp_shown = minf(_exp_shown + ExpBarMath.rate(growth, int(_exp_shown)) * delta, float(m.xp))
				var lv: = ExpBarMath.level_at(growth, int(_exp_shown))
				while _exp_level < lv:
					_exp_level += 1
					_on_level_up(m, _exp_level)
		_level_flash = maxf(_level_flash - delta * 1.5, 0.0)

	func _draw() -> void :
		var r: = Rect2(Vector2.ZERO, size)
		if not is_instance_valid(body):
			UI.glass(self, r, 0.5, 14)
			return
		var types: Array = body.types
		var accent: Color = Dex.type_color(types[0] if not types.is_empty() else "normal")

		UI.rounded(self, Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.35), 14)
		UI.glass(self, r, 0.72, 14)
		var edge_x: = size.x - 6.0 if foe else 0.0
		UI.rounded(self, Rect2(edge_x, 10, 6, size.y - 20), accent, 3)

		var pc: = Vector2(size.x - 46.0, size.y * 0.5) if foe else Vector2(46.0, size.y * 0.5)
		draw_circle(pc, PORTRAIT_R, accent.darkened(0.55))
		draw_arc(pc, PORTRAIT_R, 0.0, TAU, 40, accent.lightened(0.2), 2.0, true)
		var icon: = PokemonSprites.disc_icon(_species, int(PORTRAIT_R * 2.0))
		if icon:
			var t: = PokemonSprites.tint(_species)
			if body.mode == 3:
				t = Color(0.35, 0.35, 0.35)
			draw_texture_rect(icon, Rect2(pc - Vector2(PORTRAIT_R, PORTRAIT_R), Vector2(PORTRAIT_R * 2.0, PORTRAIT_R * 2.0)), false, t)

		var x0: = text_x0()
		var x1: = text_x1()
		var name_s: String = body.mon.display_name if body.mon and "display_name" in body.mon else body.species
		drawn_name = name_s
		var lv: = "Lv %d" % (_exp_level if _exp_mon == body.mon else int(body.level))
		var lv_col: Color = Color.WHITE if _level_flash > 0.0 else UiKit.AMBER
		if foe:

			UI.text(self, Vector2(x0, NAME_Y), name_s, 24, UI.COL_WHITE, 4, HORIZONTAL_ALIGNMENT_RIGHT, x1 - x0, UiKit.title_font())
			lv_rect = Rect2(x0, NAME_Y - 18.0, UI.text_width(lv, 18, UiKit.title_font()), 18.0)
		else:
			UI.text(self, Vector2(x0, NAME_Y), name_s, 24, UI.COL_WHITE, 4, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.title_font())
			lv_rect = Rect2(x1 - UI.text_width(lv, 18, UiKit.title_font()), NAME_Y - 18.0, 
				UI.text_width(lv, 18, UiKit.title_font()), 18.0)
		UI.text(self, Vector2(lv_rect.position.x, NAME_Y), lv, 18, lv_col, 4, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.title_font())
		_draw_chips(x0, x1, types)

		hp_bar_rect = Rect2(x0, HP_ROW_Y, HP_W, HP_H)
		UI.bar(self, hp_bar_rect, _hp_ratio, UI.hp_color(_hp_ratio), _ghost, Color(1, 1, 1, 0.75), foe)
		if foe:
			return
		var hp_s: = "%d / %d" % [body.hp, body.max_hp]
		hp_text_rect = Rect2(x1 - UI.text_width(hp_s, 13), CHIP_Y + 1.0, UI.text_width(hp_s, 13), 13.0)
		UI.text(self, Vector2(hp_text_rect.position.x, CHIP_Y + 14.0), hp_s, 13, Color(1, 1, 1, 0.85), 3)

		var base: = maxf(body.pp_base, 1.0)
		pp_bar_rect = Rect2(x0, PP_ROW_Y, PP_W, PP_ROW_H)
		UI.bar(self, pp_bar_rect, maxf(body.stamina, 0.0) / base, UiKit.PP_BLUE, body.pp_max / base, Color(0.2, 0.3, 0.55))
		exp_bar_rect = Rect2(x0 + PP_W + EXP_GAP, EXP_ROW_Y, EXP_W, EXP_ROW_H)
		UI.bar(self, exp_bar_rect, _exp_ratio(), UiKit.AMBER, -1.0, Color(1, 1, 1, 0.75), false, UI.EXP_TRACK)
		_draw_level_sparkle(exp_bar_rect.end.x, EXP_ROW_Y + EXP_ROW_H * 0.5)



	func name_rect() -> Rect2:
		if drawn_name == "":
			return Rect2()
		var w: = UI.text_width(drawn_name, 24, UiKit.title_font())
		var x: = text_x0() if not foe else text_x1() - w
		return Rect2(x, NAME_Y - 24.0, w, 24.0)


	func _draw_chips(x0: float, x1: float, types: Array) -> void :
		var gap: = 5.0

		var tag_w: = UI.text_width(foe_tag(Battle.trainer_battle), 10) + 8.0 if foe else 0.0
		var tx: = x0
		if foe:



			var w: = 0.0
			for t in types:
				w += UI.text_width(String(t).to_upper(), 10) + 12.0 + gap
			if UI.STATUS_TAGS.has(body.status):
				w += UI.text_width(String(UI.STATUS_TAGS[body.status][0]), 10) + 12.0 + gap
			w += UI.mod_chips_width(body, 10)
			tx = maxf(x1 - w, x0 + tag_w)
		for t in types:
			tx += UI.type_pill(self, Vector2(tx, CHIP_Y), t, Dex.type_color(t), 10) + gap


		var sw: float = UI.status_pill(self, Vector2(tx, CHIP_Y), body.status, 10)
		if sw > 0.0:
			tx += sw + gap




		var chips: float = UI.mod_chips(self, Vector2(tx, CHIP_Y), body, 10, x1 if foe else x1 - 40.0)
		_chips = Rect2(tx, CHIP_Y - 2.0, chips, 20.0) if chips > 0.0 else Rect2()
		tx += chips
		if body.stagger_t > 0.0:
			UI.text(self, Vector2(tx + 2, CHIP_Y + 14.0), "STAGGERED", 11, Color(1, 0.55, 0.35), 3)
		elif body.evolving:
			UI.text(self, Vector2(tx + 2, CHIP_Y + 14.0), "EVOLVING", 11, Color(1, 0.95, 0.6), 3)
		if foe:
			var tag: = foe_tag(Battle.trainer_battle)
			tag_rect = Rect2(x0, CHIP_Y + 13.0 - 10.0, UI.text_width(tag, 10), 10.0)
			UI.text(self, Vector2(x0, CHIP_Y + 13.0), tag, 10, Color(1, 1, 1, 0.45), 0)
			var states: = ball_states(Battle.trainer_battle)
			if not states.is_empty():
				_draw_party_balls(Vector2(x0 + 90.0, CHIP_Y + 3.0), states)


	func _draw_level_sparkle(x: float, y: float) -> void :
		if _level_flash <= 0.0:
			return
		var c: = Color(1.0, 0.95, 0.6, _level_flash)
		var grow: = (1.0 - _level_flash) * 14.0
		for k in 6:
			var dir: = Vector2(cos(TAU * k / 6.0), sin(TAU * k / 6.0))
			draw_line(Vector2(x, y) + dir * (3.0 + grow), Vector2(x, y) + dir * (8.0 + grow), c, 2.0)



class AllyCard extends Control:
	const UI: = preload("res://scripts/ui/ui_draw.gd")
	const PokemonSprites: = preload("res://scripts/pokemon_sprites.gd")
	const Creature: = preload("res://scripts/creature.gd")
	const Growth: = preload("res://scripts/stats/growth.gd")

	var body: Node
	var _exp_shown: = 0.0
	var _exp_mon: RefCounted
	var _exp_level: = 1
	var _exp_scripted: = false
	var _level_hold: = false
	var _level_flash: = 0.0

	const HP_ROW_Y: = 18.0
	const HP_ROW_H: = 8.0
	const PP_ROW_Y: = 27.0
	const PP_ROW_H: = 5.0
	const EXP_ROW_Y: = 27.0
	const EXP_ROW_H: = 5.0
	const EXP_GAP: = 6.0

	var pp_bar_rect: = Rect2()
	var exp_bar_rect: = Rect2()


	func exp_track() -> Color:
		return UI.EXP_TRACK

	func _exp_ratio() -> float:
		if not is_instance_valid(body) or body.mon == null:
			return 0.0
		if _level_hold or _exp_level >= Growth.MAX_LEVEL:
			return 1.0
		var growth: = String(body.mon.growth)
		var lo: = float(Growth.exp_for_level(growth, _exp_level))
		var hi: = float(Growth.exp_for_level(growth, _exp_level + 1))
		return clampf((_exp_shown - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)

	func exp_animating() -> bool:
		return is_instance_valid(body) and body.mon != null and _exp_shown < float(body.mon.xp)

	func _say(text: String, col: Color) -> void :
		var p: = get_parent()
		if p and p.has_method("popup"):
			p.popup(text, col)


	func begin_scripted(m: RefCounted, gain: int) -> void :
		_exp_scripted = true
		if _exp_mon != m or _exp_shown > float(m.xp):
			_exp_shown = float(m.xp) - float(gain)
		_exp_mon = m
		_exp_level = ExpBarMath.level_at(String(m.growth), int(_exp_shown))
		_level_hold = false
		_level_flash = 0.0


	func fill_to(target: float, skip_on_press: = true) -> void :
		if not is_instance_valid(body) or body.mon == null:
			return
		var growth: = String(body.mon.growth)
		while _exp_shown < target:
			if skip_on_press and Input.is_action_just_pressed("pk_ok"):
				break
			var step: = ExpBarMath.rate(growth, int(_exp_shown))
			if step <= 0.0:
				break
			_exp_shown = minf(_exp_shown + step * get_process_delta_time(), target)
			await get_tree().process_frame
		_exp_shown = target

	func announce_level(lv: int) -> void :
		_exp_level = lv
		_level_hold = true
		_level_flash = 1.0

	func resume_after_level() -> void :
		_level_hold = false

	func end_scripted() -> void :
		_exp_scripted = false

	func _on_level_up(m: RefCounted, lv: int) -> void :
		_say("%s: Level Up!" % String(m.display_name), UiKit.AMBER)
		Audio.jingle("music/level_up", true)

	func _ready() -> void :
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void :

		var m: RefCounted = body.mon if is_instance_valid(body) and body.mon else null
		if _exp_scripted or Battle._ending:
			pass
		elif m != _exp_mon:
			_exp_mon = m
			_exp_shown = float(m.xp) if m else 0.0
			_exp_level = int(m.level) if m else 1
		elif m:
			if _exp_shown < float(m.xp):
				var growth: = String(m.growth)
				_exp_shown = minf(_exp_shown + ExpBarMath.rate(growth, int(_exp_shown)) * delta, float(m.xp))
				var lv: = ExpBarMath.level_at(growth, int(_exp_shown))
				while _exp_level < lv:
					_exp_level += 1
					_on_level_up(m, _exp_level)
		_level_flash = maxf(_level_flash - delta * 1.5, 0.0)
		queue_redraw()

	func _draw() -> void :
		if not is_instance_valid(body):
			return
		var r: = Rect2(Vector2.ZERO, size)
		UI.rounded(self, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.3), 12)
		UI.glass(self, r, 0.68, 12)
		var ps: = 24.0
		var pc: = Vector2(20.0, size.y * 0.5)
		draw_circle(pc, ps * 0.5, Color(0.15, 0.2, 0.25))
		var icon: = PokemonSprites.icon(body.species)
		if icon:
			draw_texture_rect(icon, Rect2(pc - Vector2(ps, ps) * 0.42, Vector2(ps, ps) * 0.84), false, PokemonSprites.tint(body.species))
		var x0: = 38.0
		var nm: String = body.mon.display_name if body.mon else body.species
		var lv_n: int = _exp_level if _exp_mon == body.mon else int(body.level)
		var nm_col: Color = Color(1.0, 0.95, 0.6) if _level_flash > 0.0 else UI.COL_WHITE
		UI.text(self, Vector2(x0, 14), "%s  Lv %d" % [nm, lv_n], 14, nm_col, 4, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.title_font())
		var m: int = Game.ally_mode
		var tag: String = Creature.ALLY_MODE_NAMES[m]
		var tw: = UI.text_width(tag, 11) + 14
		var tx: = size.x - 12.0 - tw
		UI.rounded(self, Rect2(tx, 11, tw, 18), Color(Creature.ALLY_MODE_COLORS[m], 0.9), 9)
		UI.text(self, Vector2(tx + 7, 24), tag, 11, Color(0.05, 0.05, 0.08), 0)
		var ratio: = float(body.hp) / maxf(body.max_hp, 1)
		UI.bar(self, Rect2(x0, HP_ROW_Y, 190.0, HP_ROW_H), ratio, UI.hp_color(ratio))
		var base: = maxf(body.pp_base, 1.0)
		pp_bar_rect = Rect2(x0, PP_ROW_Y, 160.0, PP_ROW_H)
		UI.bar(self, pp_bar_rect, maxf(body.stamina, 0.0) / base, UiKit.PP_BLUE, body.pp_max / base, Color(0.2, 0.3, 0.55))

		exp_bar_rect = Rect2(x0 + 160.0 + EXP_GAP, EXP_ROW_Y, 60.0, EXP_ROW_H)
		UI.bar(self, exp_bar_rect, _exp_ratio(), UiKit.AMBER, -1.0, Color(1, 1, 1, 0.75), false, UI.EXP_TRACK)
		_draw_level_sparkle(exp_bar_rect.end.x, EXP_ROW_Y + EXP_ROW_H * 0.5)
		UI.status_pill(self, Vector2(x0 + 236.0, 12.0), body.status, 9)

	func _draw_level_sparkle(x: float, y: float) -> void :
		if _level_flash <= 0.0:
			return
		var c: = Color(1.0, 0.95, 0.6, _level_flash)
		var grow: = (1.0 - _level_flash) * 14.0
		for k in 6:
			var dir: = Vector2(cos(TAU * k / 6.0), sin(TAU * k / 6.0))
			draw_line(Vector2(x, y) + dir * (3.0 + grow), Vector2(x, y) + dir * (8.0 + grow), c, 2.0)




class MoveButton extends Control:
	const UI: = preload("res://scripts/ui/ui_draw.gd")
	const Dex: = preload("res://scripts/dex.gd")
	const ItemsData: = preload("res://scripts/items.gd")


	const NAME_FS: = 16
	const NAME_MIN_FS: = 10
	const NAME_W: = 62.0
	const NAME_MAX_LINES: = 2


	const COOLDOWN_NAME_A: = 0.35
	const COOLDOWN_NAME_FS: = 11

	var index: = 0
	var flash: = 0.0

	var showing_item: = false

	func move_id() -> String:
		var p: Node = Battle.partner
		if is_instance_valid(p) and index < p.moves.size():
			return String(p.moves[index])
		return ""


	func item_id() -> String:
		return String(Game.quick_slots[index]) if index < Game.quick_slots.size() else ""


	static func items_held() -> bool:
		return Controls.items_page_held()

	func _process(delta: float) -> void :
		flash = maxf(flash - delta * 3.0, 0.0)
		showing_item = items_held()


	func glyph() -> String:
		return Controls.key_label("move_%d" % (index + 1))


	func _name_width() -> float:
		return size.x * 0.92 if Controls.is_touch() else NAME_W

	func _wrap(nm: String, fs: int) -> Array:
		var lines: Array = []
		var cur: = ""
		if Controls.is_touch():
			var line := ""
			for ch in nm:
				if line != "" and UI.text_width(line + ch, fs, UiKit.title_font()) > _name_width():
					lines.append(line.strip_edges())
					line = ""
				line += ch
			if line != "":
				lines.append(line.strip_edges())
			return lines
		for w in nm.split(" ", false):
			var cand: = String(w) if cur == "" else cur + " " + String(w)
			if cur != "" and UI.text_width(cand, fs, UiKit.title_font()) > _name_width():
				lines.append(cur)
				cur = String(w)
			else:
				cur = cand
		if cur != "":
			lines.append(cur)
		return lines


	func _name_fit(nm: String) -> Array:
		var fs: = maxi(NAME_FS, Controls.screen_font(12.0)) if Controls.is_touch() else NAME_FS
		while fs > NAME_MIN_FS:
			var lines: = _wrap(nm, fs)
			var ok: = lines.size() <= NAME_MAX_LINES
			for l in lines:
				if UI.text_width(String(l), fs, UiKit.title_font()) > _name_width():
					ok = false
			if ok:
				return [lines, fs]
			fs -= 1
		return [_wrap(nm, NAME_MIN_FS), NAME_MIN_FS]


	func text_fits() -> bool:
		var id: = move_id()
		if id == "":
			return true
		var nm: = String(Dex.move(id).get("name", id))
		var fit: = _name_fit(nm)
		var lines: Array = fit[0]
		if lines.size() > NAME_MAX_LINES:
			return false
		for l in lines:
			if UI.text_width(String(l), int(fit[1]), UiKit.title_font()) > _name_width():
				return false
		return true


	func _name() -> String:
		var id: = move_id()
		return String(Dex.move(id).get("name", id)) if id != "" else ""



	func _name_layout() -> Array:
		var nm: = _name()
		if nm == "":
			return []
		var c: = size * 0.5

		if float(cooldown_state()[0]) > 0.0:
			var s: = nm
			var maxw: = minf(size.x, size.y) * 0.66
			while s.length() > 1 and UI.text_width(s + "…", COOLDOWN_NAME_FS, UiKit.title_font()) > maxw:
				s = s.substr(0, s.length() - 1)
			if s != nm:
				s += "…"
			return [{"text": s, "x": c.x, "y": c.y - 18.0, "fs": COOLDOWN_NAME_FS}]
		var fit: = _name_fit(nm)
		var lines: Array = fit[0]
		var fs: int = fit[1]
		var lh: = float(fs) * 1.05
		var y: = c.y - 8.0 - (lines.size() - 1) * lh * 0.5 + fs * 0.35
		var out: Array = []
		for l in lines:
			out.append({"text": String(l), "x": c.x, "y": y, "fs": fs})
			y += lh
		return out




	func cooldown_state() -> Array:
		var p: Node = Battle.partner
		var id: = move_id()
		if not is_instance_valid(p) or id == "":
			return [0.0, -1.0]
		var cd: = float(p.move_cd.get(id, 0.0))
		var use_gcd: = float(p.gcd_t) > cd
		if use_gcd:
			cd = float(p.gcd_t)
		if cd <= 0.0:
			return [0.0, -1.0]
		var total: = (Dex.GLOBAL_COOLDOWN if use_gcd else Dex.cooldown(Dex.move(id))) / maxf(p.speed_factor(), 0.01)
		return [cd, clampf(cd / maxf(total, 0.01), 0.0, 1.0)]



	func _cooldown_layout() -> Dictionary:
		var st: = cooldown_state()
		if float(st[0]) <= 0.0:
			return {}
		return {"text": "%.1f" % float(st[0]), "x": size.x * 0.5, "y": size.y * 0.5 + 6.0, "fs": 20}



	func cooldown_rect() -> Rect2:
		var e: = _cooldown_layout()
		if e.is_empty():
			return Rect2()
		var w: = UI.text_width(String(e.text), int(e.fs))
		return Rect2(float(e.x) - w * 0.5, float(e.y) - int(e.fs), w, float(e.fs))


	func name_rect() -> Rect2:
		var r: = Rect2()
		for i in _name_layout().size():
			var e: Dictionary = _name_layout()[i]
			var w: = UI.text_width(String(e.text), int(e.fs), UiKit.title_font())
			var box: = Rect2(float(e.x) - w * 0.5, float(e.y) - int(e.fs), w, float(e.fs))
			r = box if i == 0 else r.merge(box)
		return r


	func pp_center() -> Vector2:
		var c: = size * 0.5
		return Vector2(c.x, c.y + minf(size.x, size.y) * 0.5 - 14.0)


	func _touch_held() -> bool:
		if not Controls.is_touch():
			return false
		var h: = get_parent()
		return h != null and h.has_method("touch_held") and bool(h.touch_held("move_%d" % (index + 1)))



	func alphas(fill_base: = 0.88, ring_base: = 0.95, label_base: = 1.0) -> Vector3:
		var touch: = Controls.is_touch()
		var p: = _touch_held()
		return Vector3(UI.fill_a(fill_base, touch, p), UI.ring_a(ring_base, touch, p), UI.label_a(label_base, touch, p))

	func _draw() -> void :
		var c: = size * 0.5
		var r: = minf(size.x, size.y) * 0.5
		var a: = alphas()
		draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.35))
		if showing_item:
			_draw_item(c, r)
			return
		var id: = move_id()
		if id == "":
			draw_circle(c, r, Color(UiKit.INK, 0.55))
			draw_arc(c, r - 2.0, 0.0, TAU, 48, Color(UiKit.PAPER, 0.25), 2.0, true)
			UI.key_pill(self, c + Vector2( - r + 6.0, - r + 6.0), glyph(), 22, true)
			UI.text_center(self, Vector2(c.x, c.y + 6.0), "—", 16, Color(1, 1, 1, 0.3), 0)
			return
		var p: Node = Battle.partner
		var mv: = Dex.move(id)
		var tcol: = Dex.type_color(String(mv.get("type", "normal")))
		var cost: = Dex.pp_cost(mv)
		var afford: bool = p.pp_max >= cost
		var tired: bool = p.stamina < Dex.fatigue(mv)
		var selected: bool = p.selected_move == id

		draw_circle(c, r, Color(UiKit.INK, a.x) if afford else Color(0.1, 0.1, 0.12, alphas(0.92).x))
		var ring_col: = Color(1, 1, 1) if selected else tcol
		draw_arc(c, r - 2.0, 0.0, TAU, 48, Color(ring_col, alphas(0.95 if selected else ring_col.a).y), 4.0 if selected else 3.5, true)


		var cooling: bool = float(cooldown_state()[0]) > 0.0
		var name_col: = Color(1, 1, 1, alphas(1.0).z * COOLDOWN_NAME_A) if cooling\
		else (Color(1, 1, 1, alphas(1.0).z) if afford else Color(1, 1, 1, alphas(0.4).z))
		for e: Dictionary in _name_layout():
			UI.text_center(self, Vector2(e.x, e.y), String(e.text), int(e.fs), name_col, 3, UiKit.title_font())

		var cost_s: = "%d PP" % int(round(cost))
		var cost_col: = UiKit.PP_BLUE
		if not afford:
			cost_col = Color(1, 0.4, 0.35)
		elif tired:
			cost_col = Color(1, 0.7, 0.3)
		UI.text_center(self, pp_center(), cost_s, 12, Color(cost_col, alphas(1.0).z), 3)

		UI.key_pill(self, c + Vector2( - r + 6.0, - r + 6.0), glyph(), 22, not afford)


		var cst: = cooldown_state()
		if float(cst[0]) > 0.0:
			draw_circle(c, r - 2.0, Color(0, 0, 0, 0.55 * float(cst[1])))
			var cl: = _cooldown_layout()
			UI.text_center(self, Vector2(cl.x, cl.y), String(cl.text), int(cl.fs), 
				Color(1, 1, 1, alphas(0.95).z), 4)

		if p.combat.prepare_id == id and float(p.combat.prepare_t) > 0.0:
			var pf: = 1.0 - clampf(float(p.combat.prepare_t) / maxf(Dex.prepare_time(mv), 0.01), 0.0, 1.0)
			draw_circle(c, r - 2.0, Color(1, 1, 1, 0.2 * pf))
		if flash > 0.0:
			draw_circle(c, r, Color(1, 1, 1, flash * 0.45))


	func _draw_item(c: Vector2, r: float) -> void :
		var a: = alphas()
		draw_circle(c, r, Color(UiKit.INK, a.x))
		draw_arc(c, r - 2.0, 0.0, TAU, 48, Color(UiKit.AMBER, alphas(0.85).y), 3.5, true)
		UI.key_pill(self, c + Vector2( - r + 6.0, - r + 6.0), glyph(), 22)
		var id: = item_id()
		if id == "":
			UI.text_center(self, Vector2(c.x, c.y + 6.0), "—", 16, Color(1, 1, 1, alphas(0.3).z), 0)
			return
		var n: int = Game.item_count(id)
		var dim: = n <= 0
		UI.item_icon(self, id, Rect2(c - Vector2(r * 0.42, r * 0.42), Vector2(r * 0.84, r * 0.84)), dim)
		var nm: = ItemsData.item_name(id)
		while nm.length() > 1 and UI.text_width(nm + "…", 11) > _name_width():
			nm = nm.substr(0, nm.length() - 1)
		if nm != ItemsData.item_name(id):
			nm += "…"
		UI.text_center(self, Vector2(c.x, c.y + r - 22.0), nm, 11, Color(1, 1, 1, alphas(0.85 if not dim else 0.4).z), 3)
		UI.text_center(self, Vector2(c.x, c.y + r - 8.0), "×%d" % n, 12, Color(1, 1, 1, alphas(1.0).z) if not dim else Color(1, 0.5, 0.5, alphas(1.0).z), 3)
		if flash > 0.0:
			draw_circle(c, r, Color(0.6, 1.0, 0.6, flash * 0.5))






class ItemsButton extends Control:
	const UI: = preload("res://scripts/ui/ui_draw.gd")


	var circle: = false


	static func glyph() -> String:
		return Controls.key_label("items_page")


	func label_center() -> Vector2:
		return Vector2(size.x * 0.5, size.y * 0.5 + 8.0)

	func _draw() -> void :
		if circle:
			var h: = get_parent()
			var p: bool = h != null and h.has_method("touch_held") and bool(h.touch_held("items_page"))
			UI.circle_btn(self, size, "Items", Color(UiKit.AMBER, 0.8), glyph(), true, true, p)
			return
		var r: = Rect2(Vector2.ZERO, size)
		UI.rounded(self, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.35), 12)
		UI.rounded(self, r, Color(UiKit.INK, 0.86), 12, 2.0, Color(UiKit.AMBER, 0.8))
		UI.text_center(self, label_center(), "Items", 14, UiKit.PAPER, 3)
		var g: = glyph()
		if g != "":
			UI.key_pill(self, Vector2(4.0, 4.0), "Hold " + g, 20)




class SwapButton extends Control:
	const UI: = preload("res://scripts/ui/ui_draw.gd")


	var circle: = false

	static func glyph() -> String:
		return Controls.key_label("control_other")


	func label_center() -> Vector2:
		return Vector2(size.x * 0.5, size.y * 0.5 + 8.0)

	func _gui_input(e: InputEvent) -> void :

		if Controls.is_touch():
			return
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			press()


	func press() -> void :
		Input.action_press("control_other")
		await get_tree().process_frame
		Input.action_release("control_other")

	func _draw() -> void :
		if circle:
			var h: = get_parent()
			var p: bool = h != null and h.has_method("touch_held") and bool(h.touch_held("control_other"))
			UI.circle_btn(self, size, "Swap", Color(UiKit.BLUE, 0.85), glyph(), false, true, p)
			return
		var r: = Rect2(Vector2.ZERO, size)
		UI.rounded(self, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.35), 12)
		UI.rounded(self, r, Color(UiKit.INK, 0.86), 12, 2.0, Color(UiKit.BLUE, 0.85))
		UI.text_center(self, label_center(), "Swap", 14, UiKit.PAPER, 3)
		var g: = glyph()
		if g != "":
			UI.key_pill(self, Vector2(4.0, 4.0), g, 20)




class SprintButton extends Control:
	const UI: = preload("res://scripts/ui/ui_draw.gd")


	var circle: = false

	static func glyph() -> String:
		return Controls.key_label("sprint")


	func label_center() -> Vector2:
		return Vector2(size.x * 0.5, size.y * 0.5 + 8.0)

	func _gui_input(e: InputEvent) -> void :

		if Controls.is_touch():
			return
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			press()


	func press() -> void :
		Input.action_press("sprint")
		await get_tree().process_frame
		Input.action_release("sprint")

	func _draw() -> void :
		if circle:
			var h: = get_parent()
			var p: bool = h != null and h.has_method("touch_held") and bool(h.touch_held("sprint"))
			UI.circle_btn(self, size, "Sprint", Color(0.35, 0.85, 0.45, 0.95), glyph(), true, true, p)
			return
		var r: = Rect2(Vector2.ZERO, size)
		UI.rounded(self, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.35), 12)
		UI.rounded(self, r, Color(UiKit.INK, 0.86), 12, 2.0, Color(0.35, 0.85, 0.45, 0.9))
		UI.text_center(self, label_center(), "Sprint", 14, UiKit.PAPER, 3)
		var g: = glyph()
		if g != "":
			UI.key_pill(self, Vector2(4.0, 4.0), "Hold " + g, 20)





class JumpButton extends Control:
	const UI: = preload("res://scripts/ui/ui_draw.gd")


	var circle: = false

	static func glyph() -> String:
		return Controls.key_label("jump")


	func label_center() -> Vector2:
		return size * 0.5 + Vector2(0, 4.0)




	func label_state() -> Array:
		var p = Battle.partner
		var c = p.combat if p != null and is_instance_valid(p) else null
		if c == null:
			return ["Jump", false]
		var verb: String = c.jump_verb()
		if verb == "":
			return ["Jump", false]
		return [verb, c.jump_ready()]

	func _draw() -> void :
		var st: = label_state()
		var verb: String = st[0]
		var ready: bool = st[1]
		if circle:
			var h: = get_parent()
			var p: bool = h != null and h.has_method("touch_held") and bool(h.touch_held("jump"))
			UI.circle_btn(self, size, verb, Color(UiKit.PAPER, 0.35), glyph(), false, true, p, not ready)
			return
		var c: = size * 0.5
		var r: = minf(size.x, size.y) * 0.5
		draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.35))
		draw_circle(c, r, Color(UiKit.INK, 0.82 if ready else 0.6))
		draw_arc(c, r - 1.5, 0.0, TAU, 40, Color(UiKit.PAPER, 0.35 if ready else 0.18), 2.0, true)
		UI.text_center(self, label_center(), verb, 13, UiKit.PAPER if ready else Color(UiKit.PAPER, 0.4), 3)
		var g: = glyph()
		if g != "":
			UI.key_pill(self, c + Vector2( - r + 6.0, - r + 6.0), g, 20, not ready)









class PipsRow extends Control:
	const UI: = preload("res://scripts/ui/ui_draw.gd")

	const PIPS: = 6
	const PIP_R: = 8.0
	const STEP: = 22.0


	func _k() -> float:
		return Controls.ui_scale() if Controls.is_touch() else 1.0

	func _ready() -> void :
		mouse_filter = Control.MOUSE_FILTER_STOP
		size = Vector2((PIPS - 1) * STEP + PIP_R * 2.0, PIP_R * 2.0) * _k()

	func _gui_input(e: InputEvent) -> void :

		if Controls.is_touch():
			return
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			press()


	func press() -> void :
		Input.action_press("party_ring")
		await get_tree().process_frame
		Input.action_release("party_ring")


	func state(i: int) -> String:
		if i < 0 or i >= Game.party.size():
			return "empty"
		if float(Game.party[i].hp) <= 0.0:
			return "fainted"
		if Battle.in_battle and Game.is_out(i):
			var c = Game.companions[i]
			if c == Battle.partner or c == Battle.ai_ally():
				return "active"
		return "available"

	func _draw() -> void :
		var k: = _k()
		var pr: = PIP_R * k
		var step: = STEP * k
		UI.rounded(self, Rect2(Vector2(-4, -4), size + Vector2(8, 8)), Color(UiKit.INK, 0.45), 10)
		for i in PIPS:
			var c: = Vector2(pr + i * step, pr)
			match state(i):
				"empty":
					draw_arc(c, pr, 0.0, TAU, 24, Color(UiKit.RIM, 0.45), 1.5, true)
				"fainted":
					UI._ball(self, Rect2(c - Vector2(7, 7) * k, Vector2(14, 14) * k), Color(0.34, 0.34, 0.38), Color(0, 0, 0, 0), Color(0.6, 0.6, 0.66))
					draw_line(c + Vector2(-4, -4) * k, c + Vector2(4, 4) * k, UiKit.RED, 2.0, true)
					draw_line(c + Vector2(4, -4) * k, c + Vector2(-4, 4) * k, UiKit.RED, 2.0, true)
				"active":
					draw_arc(c, pr + 2.5 * k, 0.0, TAU, 28, Color(UiKit.AMBER, 0.95), 2.5, true)
					UI._ball(self, Rect2(c - Vector2(8, 8) * k, Vector2(16, 16) * k), UiKit.RED.lightened(0.12), Color(0, 0, 0, 0), Color.WHITE)
				_:
					UI._ball(self, Rect2(c - Vector2(7, 7) * k, Vector2(14, 14) * k), UiKit.RED, Color(0, 0, 0, 0), Color.WHITE)




class ItemSlot extends Control:
	const UI: = preload("res://scripts/ui/ui_draw.gd")
	const ItemsData: = preload("res://scripts/items.gd")

	var index: = 0
	var flash: = 0.0

	func _process(delta: float) -> void :
		flash = maxf(flash - delta * 3.0, 0.0)

	func _draw() -> void :
		var s: = size.x
		var box: = Rect2(0, 0, s, s)
		var key: = OS.get_keycode_string(Controls.ITEM_KEYS[index])
		var id: String = Game.quick_slots[index] if index < Game.quick_slots.size() else ""
		UI.rounded(self, Rect2(box.position + Vector2(0, 3), box.size), Color(0, 0, 0, 0.35), 12)
		if id == "":
			UI.glass(self, box, 0.5, 12)
			UI.key_cap(self, Vector2(10, 10), key, 22, true)
			UI.text(self, Vector2(0, s + 16), "empty", 13, Color(1, 1, 1, 0.35), 2, HORIZONTAL_ALIGNMENT_CENTER, s)
			return
		var n: int = Game.item_count(id)
		var is_ball: bool = ItemsData.pocket_of(id) == "balls"
		var dim: = n <= 0
		UI.glass(self, box, 0.72, 12)
		UI.rounded(self, Rect2(3, 3, s - 6, s * 0.45), Color(1, 1, 1, 0.05), 10)
		UI.item_icon(self, id, box.grow( - s * 0.14), dim)

		var f: = 0.0
		if is_ball:
			f = 1.0 if Game._capturing else 0.0
		elif Game.item_cd > 0.0:
			f = Game.item_cd / Game.ITEM_CD
		if f > 0.0:
			var c: = box.get_center()
			var pts: = PackedVector2Array([c])
			var steps: = 28
			for i in steps + 1:
				var a: = - PI * 0.5 + TAU * f * i / steps
				pts.append(c + Vector2(cos(a), sin(a)) * s * 0.75)

			draw_set_transform(Vector2.ZERO)
			var poly: = Geometry2D.intersect_polygons(pts, PackedVector2Array([Vector2(2, 2), Vector2(s - 2, 2), Vector2(s - 2, s - 2), Vector2(2, s - 2)]))
			for pl in poly:
				draw_colored_polygon(pl, Color(0, 0, 0, 0.6))
		UI.key_cap(self, Vector2(10, 10), key, 22, dim)
		var cnt: = "×%d" % n
		var cw: = UI.text_width(cnt, 13) + 10
		UI.rounded(self, Rect2(s - cw - 3, s - 20, cw, 17), Color(0, 0, 0, 0.7) if not dim else Color(0.5, 0.1, 0.1, 0.8), 8)
		UI.text(self, Vector2(s - cw + 2, s - 7), cnt, 13, Color.WHITE, 0)
		var nm: = ItemsData.item_name(id)
		var fs: = 13
		if UI.text_width(nm, fs) > s + 10:
			while nm.length() > 1 and UI.text_width(nm + "…", fs) > s + 10:
				nm = nm.substr(0, nm.length() - 1)
			nm += "…"
		UI.text(self, Vector2(s * 0.5 - UI.text_width(nm, fs) * 0.5, s + 16), nm, fs, Color(1, 1, 1, 0.8 if not dim else 0.4), 3)
		if flash > 0.0:
			UI.rounded(self, box, Color(0.6, 1.0, 0.6, flash * 0.5), 12)







class Overhead extends Control:
	const UI: = preload("res://scripts/ui/ui_draw.gd")


	const shows_bars: = false
	const W: = 150.0
	const TAG_H: = 20.0
	var role: = "you"
	var foe: = false
	var body: Node

	func _ready() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(W + 40, TAG_H)

	func content_top() -> float:
		return 0.0

	func content_bottom() -> float:
		return TAG_H


	func place() -> void :
		var cam: = get_viewport().get_camera_3d()
		if not is_instance_valid(body) or cam == null or body.mode == 3:
			visible = false
			return
		var lbl: Node3D = body.get_node_or_null("Label3D")
		var top: Vector3 = body.global_position + Vector3(0, (lbl.position.y if lbl else 1.8) + 0.1, 0)
		if cam.is_position_behind(top):
			visible = false
			return
		visible = true

		position = cam.unproject_position(top) - Vector2(size.x * 0.5, content_bottom())

	func _process(_delta: float) -> void :
		if is_instance_valid(body):
			queue_redraw()

	func _draw() -> void :
		if not is_instance_valid(body):
			return
		var name_col: = Color(1, 1, 1) if foe else Color(0.72, 0.88, 1.0)
		if role == "ally":
			name_col = Color(0.75, 1.0, 0.8)
		var f: = UiKit.title_font()
		var label: = String(body.species)
		var w: = UI.text_width(label, 14, f) + 20.0
		var r: = Rect2((size.x - w) * 0.5, 0.0, w, TAG_H)
		UI.rounded(self, r, Color(UiKit.INK, 0.68), TAG_H * 0.5)
		UI.text(self, Vector2(r.position.x + 10.0, TAG_H - 5.0), label, 14, name_col, 4, HORIZONTAL_ALIGNMENT_LEFT, -1.0, f)
		if role == "you" and Battle.allies.size() > 1:
			UI.text(self, Vector2(r.position.x - 14.0, TAG_H - 5.0), "▼", 12, Color(0.72, 0.88, 1.0))
