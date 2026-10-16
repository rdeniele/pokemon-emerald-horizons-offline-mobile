extends CanvasLayer





























const UI: = preload("res://scripts/ui/ui_draw.gd")
const Controls: = preload("res://scripts/controls.gd")
enum Mode{AUTO, ON, OFF}

const STICK_R: = 95.0
const KNOB_R: = 38.0
const STICK_DEAD: = 0.15
const SMALL_R: = 28.0
const DPAD_BTN: = 64.0

const DPAD_MARGIN: = 24.0

const REPEAT_FIRST: = 0.35
const REPEAT_STEP: = 0.12



class Surface extends Control:
	var pad
	func _init(p) -> void :
		pad = p
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void :
		pad.draw_pad(self)


var mode: = Mode.AUTO


var forced: = false

var _seen: = false

var _roles: = {}
var stick_origin: = Vector2.ZERO
var stick_vec: = Vector2.ZERO

var _surface: Control
var _repeat_action: = ""
var _repeat_t: = 0.0
var _repeat_started: = false


func _init() -> void :
	layer = 70

	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_surface = Surface.new(self)
	add_child(_surface)
	set_process(true)



func ui_scale() -> float:
	return Controls.ui_scale()


func _ready() -> void :
	Controls.setup_menus()
	var settings = get_node_or_null("/root/Settings")
	if settings != null:
		settings.changed.connect( func(k): if k == "touch_controls": _read_settings())
	_read_settings()
	if OS.has_feature("mobile") or OS.has_feature("web"):
		forced = true
		if OS.has_feature("web"):
			_enable_mouse_touch()
		_refresh()
	get_viewport().size_changed.connect(Controls.reset_ui_scale)
	if OS.get_cmdline_user_args().has("--touch"):
		forced = true
		_enable_mouse_touch()
		_refresh()


func _read_settings() -> void :
	var settings = get_node_or_null("/root/Settings")
	if settings != null:
		mode = clampi(int(settings.touch_controls), 0, 2)

	if mode == Mode.ON:
		_enable_mouse_touch()
	elif not forced:
		_disable_mouse_touch()
	_refresh()



func _enable_mouse_touch() -> void :
	var desktop_preview := not OS.has_feature("mobile")
	Input.set_emulate_touch_from_mouse(false)
	Controls.emulate_touch = desktop_preview


func _disable_mouse_touch() -> void :
	Input.set_emulate_touch_from_mouse(false)
	Controls.emulate_touch = false


func _refresh() -> void :
	var want: bool = forced or mode == Mode.ON or (mode == Mode.AUTO and _seen)
	if want == visible:
		return
	visible = want
	if not visible:
		_release_all()
	elif _surface:
		_surface.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_release_all()


func _process(delta: float) -> void :
	if visible and _surface:
		_surface.queue_redraw()

	if _repeat_action != "":
		_repeat_t += delta
		if _repeat_t >= (REPEAT_STEP if _repeat_started else REPEAT_FIRST):
			_repeat_t = 0.0
			_repeat_started = true
			_fire(_repeat_action, true)




func _input(e: InputEvent) -> void :
	if e is InputEventScreenTouch:
		Controls.note_device(e)
		if mode == Mode.OFF:
			return
		_seen = true
		_refresh()
		if not visible:
			return
		if e.pressed:
			_begin(e.index, e.position)
		else:
			_end(e.index)
		get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag:
		Controls.note_device(e)
		if visible:
			_drag(e.index, e.position)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton or e is InputEventMouseMotion:
		if Controls.emulate_touch:
			_input_mouse(e)
	elif e is InputEventKey or e is InputEventJoypadButton or e is InputEventJoypadMotion:
		Controls.note_device(e)

		if mode == Mode.AUTO and not forced and _seen and _hides(e):
			_seen = false
			_refresh()




func _input_mouse(e: InputEvent) -> void :
	if e is InputEventMouseButton:
		if e.button_index != MOUSE_BUTTON_LEFT or mode == Mode.OFF:
			return
		_seen = true
		_refresh()
		if not visible:
			return
		if e.pressed:
			_begin(0, e.position)
		else:
			_end(0)
	elif e is InputEventMouseMotion:
		if visible and _roles.has(0) and String(_roles[0].kind) == "stick":
			_drag(0, e.position)



func _hides(e: InputEvent) -> bool:
	if e is InputEventJoypadMotion:
		return absf(e.axis_value) >= Controls.PAD_NOTICE
	return true


func _begin(idx: int, p: Vector2) -> void :

	if _confirm_mode():
		if a_rect().has_point(p):
			_press_role(idx, "confirm")
		return

	if _title_mode():
		_press_role(idx, "pk_ok")
		return

	if _menu_mode():
		if _dpad_needed():
			var dp: = dpad_action_at(p)
			if dp != "":
				_press_dpad(idx, dp)
				return
		if _text_entry_open() and start_rect().has_point(p):
			_press_role(idx, "pk_start")
			return
		if a_rect().has_point(p):
			_press_role(idx, "pk_ok")
			return
		if b_rect().has_point(p):
			_press_role(idx, "pk_back")
			return

		if _choice_tap(p):
			return

		if not _dpad_needed() and not _choice_open() and _dialog_rect().has_point(p):
			_press_role(idx, "pk_ok")
			return
		return
	if _text_entry_open():
		return
	var h: = _hud()
	if h == null:
		return
	var ring = h.get("party_ring")
	if ring != null and ring.is_open:
		var slot: int = ring.slot_at(p)
		if slot >= 0:
			ring.press_slot(slot)
			_roles[idx] = {"kind": "ring", "ring": ring}
		else:
			_press_role(idx, "pk_back")
		return
	if Battle.in_battle and _battle_hit(idx, p):
		return
	if not Battle.in_battle:
		if menu_rect().has_point(p):
			_press_role(idx, "pk_pause")
			return
		if a_rect().has_point(p):
			_press_role(idx, "interact")
			return
		if b_rect().has_point(p):
			_press_role(idx, "run")
			return
		var pr: = _prompt_rect()
		if pr.has_area() and pr.has_point(p):
			_press_role(idx, "interact")
			return

		var orbs: Control = h.get("party_orbs")
		if orbs != null and orbs.visible and orbs.has_method("slot_at"):
			var slot: int = orbs.slot_at(p - orbs.global_position)
			if slot >= 0:
				orbs.press_slot(slot)
				return
	if p.x < _vp().x * 0.5:
		stick_origin = p
		stick_vec = Vector2.ZERO
		_roles[idx] = {"kind": "stick"}


func _drag(idx: int, p: Vector2) -> void :
	var role = _roles.get(idx)
	if role == null or String(role.kind) != "stick":
		return
	var v: = (p - stick_origin) / stick_radius()
	if v.length() > 1.0:
		v = v.normalized()
	stick_vec = v
	_apply_stick(v)


func _end(idx: int) -> void :
	var role = _roles.get(idx)
	if role == null:
		return
	_roles.erase(idx)
	match String(role.kind):
		"stick":
			_release_stick()
		"ring":
			role.ring.release_slot()
		"action":
			if String(role.action) == _repeat_action:
				_repeat_action = ""
				_repeat_started = false
			_fire(String(role.action), false)






func _fire(action: String, down: bool) -> void :
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var ev: = InputEventAction.new()
	ev.action = action
	ev.pressed = down
	Input.parse_input_event(ev)


func _press_role(idx: int, action: String) -> void :
	_roles[idx] = {"kind": "action", "action": action}
	_fire(action, true)


func _press_dpad(idx: int, action: String) -> void :
	_press_role(idx, action)
	_repeat_action = action
	_repeat_t = 0.0
	_repeat_started = false


func _set_axis(action: String, v: float) -> void :
	if v > 0.001:
		Input.action_press(action, v)
	else:
		Input.action_release(action)


func _apply_stick(v: Vector2) -> void :


	var d: = v.normalized() if v.length() > STICK_DEAD else Vector2.ZERO
	_set_axis("move_left", maxf(0.0, - d.x))
	_set_axis("move_right", maxf(0.0, d.x))
	_set_axis("move_up", maxf(0.0, - d.y))
	_set_axis("move_down", maxf(0.0, d.y))



func _release_stick() -> void :
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	stick_vec = Vector2.ZERO
	stick_origin = Vector2.ZERO


func _release_all() -> void :
	for idx in _roles.keys():
		var role: Dictionary = _roles[idx]
		match String(role.kind):
			"ring":
				role.ring.release_slot()
			"action":
				_fire(String(role.action), false)
	_roles.clear()
	_repeat_action = ""
	_release_stick()




func _hud() -> Node:
	var p: = get_parent()
	if p != null and p.get("battle_hud") != null:
		return p

	var g = get_node_or_null("/root/Game")
	if g != null and g.has_method("get_hud"):
		return g.get_hud()
	return null


func _text_entry_open() -> bool:
	return get_tree() != null and get_tree().get_first_node_in_group("text_entry") != null







func _confirm_mode() -> bool:
	var t: = _tutorial()
	return t != null and t.has_method("waiting_for_dismiss") and bool(t.waiting_for_dismiss())


func _tutorial() -> Node:
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group("battle_tutorial")



func _title_mode() -> bool:
	if get_tree() == null:
		return false
	var fe: = get_tree().get_first_node_in_group("front_end")
	return fe != null and fe.has_method("is_title") and bool(fe.is_title())


func _menu_mode() -> bool:
	if get_tree() != null and get_tree().get_first_node_in_group("front_end") != null:
		return true
	if _text_entry_open():
		return true
	if Game.menu_open:
		return true
	if Battle._awaiting_confirm:
		return true
	var h: = _hud()
	if h != null and h.has_method("is_dialog_open") and h.is_dialog_open():
		return true
	return false




func _dpad_needed() -> bool:
	var h: = _hud()
	return h == null or not h.has_method("is_dialog_open") or not h.is_dialog_open()


func _choice_open() -> bool:
	var h: = _hud()
	return h != null and h.has_method("is_choice_open") and bool(h.is_choice_open())



func _choice_tap(p: Vector2) -> bool:
	var h: = _hud()
	if h == null or not h.has_method("choice_tap"):
		return false
	return bool(h.choice_tap(p))



func _dialog_rect() -> Rect2:
	var h: = _hud()
	if h == null or not h.has_method("dialog_rect"):
		return Rect2()
	return h.dialog_rect()


func _ring_open() -> bool:
	var h: = _hud()
	if h == null:
		return false
	var ring = h.get("party_ring")
	return ring != null and ring.is_open



func _battle_hit(idx: int, p: Vector2) -> bool:
	var h: = _hud()
	if h == null:
		return false
	var bh = h.get("battle_hud")
	if bh == null:
		return false
	for i in 4:
		if bh.move_rect(i).has_point(p):
			_press_role(idx, "move_%d" % (i + 1))
			return true
	if bh.items_rect().has_point(p):
		_press_role(idx, "items_page")
		return true
	if bh.jump_rect().has_point(p):
		_press_role(idx, "jump")
		return true
	if bh._sprint_btn.visible and bh.sprint_rect().has_point(p):
		_press_role(idx, "sprint")
		return true
	if bh._swap_btn.visible and bh.swap_rect().has_point(p):
		_press_role(idx, "control_other")
		return true
	if bh.pips_rect().has_point(p):
		_press_role(idx, "party_ring")
		return true
	if pause_rect().has_point(p):
		_press_role(idx, "pk_pause")
		return true
	return false


func _prompt_rect() -> Rect2:
	var h: = _hud()
	if h == null or not h.has_method("interact_prompt_rect"):
		return Rect2()
	return h.interact_prompt_rect()




func _vp() -> Vector2:
	return _surface.size if _surface != null else Vector2.ZERO


func stick_radius() -> float:
	return STICK_R * ui_scale() * clampf(_vp().y / 720.0, 0.5, 2.0)


func a_rect() -> Rect2:


	var k: = ui_scale()
	var off: = 75.0 * k
	var sl: = _strip_left()
	if sl < INF:
		off = maxf(off, _vp().x - sl + 8.0 + 45.0 * k)
	var c: = Vector2(_vp().x - off, _vp().y - 85.0 * k)
	var r: = 45.0 * k
	return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)


func b_rect() -> Rect2:

	var k: = ui_scale()
	var r: = 38.0 * k
	var c: = Vector2(a_rect().get_center().x - 107.0 * k, _vp().y - 62.0 * k)
	return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)



func _strip_left() -> float:
	var h: = _hud()
	if h == null:
		return INF
	var orbs: Control = h.get("party_orbs")
	if orbs == null or not orbs.visible:
		return INF
	return orbs.global_position.x


func menu_rect() -> Rect2:

	var k: = ui_scale()
	var c: = Vector2(_vp().x - 54.0 * k, 46.0 * k)
	return Rect2(c - Vector2(SMALL_R, SMALL_R) * k, Vector2(SMALL_R, SMALL_R) * 2.0 * k)


func pause_rect() -> Rect2:
	var k: = ui_scale()
	var c: = Vector2(_vp().x * 0.5, 50.0 * k)
	return Rect2(c - Vector2(SMALL_R, SMALL_R) * k, Vector2(SMALL_R, SMALL_R) * 2.0 * k)




func pause_drawn() -> bool:
	return visible and Battle.in_battle and not _confirm_mode() and not _menu_mode() and not _ring_open()



func start_rect() -> Rect2:
	var k: = ui_scale()
	var a: = a_rect()
	var w: = 96.0 * k
	var h: = 34.0 * k
	var bottom: = a.position.y - 12.0 * k
	return Rect2(a.get_center().x - w * 0.5, bottom - h, w, h)


func dpad_center() -> Vector2:
	var k: = ui_scale()
	var half: = DPAD_BTN * k * 1.5
	return Vector2(DPAD_MARGIN * k + half, _vp().y - DPAD_MARGIN * k - half)



func dpad_rect(i: int) -> Rect2:
	var k: = ui_scale()
	var b: = DPAD_BTN * k
	var offs: = [Vector2(0, - b), Vector2(0, b), Vector2( - b, 0), Vector2(b, 0)]
	return Rect2(dpad_center() + offs[i] - Vector2(b, b) * 0.5, Vector2(b, b))


const DPAD_ACTIONS: = ["pk_up", "pk_down", "pk_left", "pk_right"]



func dpad_action_at(p: Vector2) -> String:
	for i in 4:
		if dpad_rect(i).has_point(p):
			return String(DPAD_ACTIONS[i])
	return ""




func draw_pad(s: Control) -> void :
	if _vp().x <= 0.0:
		return
	if _title_mode():
		return
	if _confirm_mode():
		_draw_a(s, "Continue", "confirm")
		return
	if _menu_mode():
		if _dpad_needed():
			_draw_dpad(s)
		_draw_a(s, "OK", "pk_ok")
		_draw_b(s, "Back", "pk_back")
		if _text_entry_open():
			_draw_start(s)
		return
	if _ring_open():
		return
	if _has_stick():
		_draw_stick(s)
	else:
		_draw_idle_stick(s)
	var k: = ui_scale()
	var hint: = "drag to move" if not Battle.in_battle else "drag to move · hold Sprint"
	UI.text_center(s, Vector2(_vp().x * 0.22, _vp().y - 22.0 * k), hint, int(12 * k), Color(1, 1, 1, 0.8))
	if Battle.in_battle:
		_draw_pause(s)
	else:
		_draw_a(s, "Talk", "interact")
		_draw_b(s, "hold run", "run")
		_draw_menu(s)



func _held(action: String) -> bool:
	for idx in _roles:
		var role: Dictionary = _roles[idx]
		if String(role.kind) == "action" and String(role.action) == action:
			return true
	return false



func held(action: String) -> bool:
	return _held(action)




func btn_alphas(action: String) -> Vector3:
	var p: = _held(action)
	return Vector3(UI.fill_a(0.82, true, p), UI.ring_a(0.95, true, p), UI.label_a(1.0, true, p))


func _has_stick() -> bool:
	for idx in _roles:
		if String(_roles[idx].kind) == "stick":
			return true
	return false


func _draw_idle_stick(s: Control) -> void:
	var r := stick_radius()
	var c := Vector2(42.0 + r, _vp().y - 48.0 - r)
	s.draw_circle(c, r, Color(0.04, 0.07, 0.08, 0.35))
	s.draw_arc(c, r, 0.0, TAU, 64, Color(1, 1, 1, 0.45), 2.0, true)
	s.draw_circle(c, KNOB_R * ui_scale(), Color(1, 1, 1, 0.2))


func _draw_stick(s: Control) -> void :
	var k: = ui_scale()
	var r: = stick_radius()
	var a: = stick_alphas()
	s.draw_circle(stick_origin, r, Color(1, 1, 1, 0.1))
	s.draw_arc(stick_origin, r, 0.0, TAU, 64, Color(1, 1, 1, a.x), 3.0, true)
	var knob: = stick_origin + stick_vec * maxf(r - KNOB_R * k, 1.0)
	s.draw_circle(knob, KNOB_R * k, Color(1, 1, 1, a.y))
	s.draw_arc(knob, KNOB_R * k, 0.0, TAU, 48, Color(1, 1, 1, a.y), 2.0, true)




func stick_alphas() -> Vector2:
	return Vector2(UI.TOUCH_STICK_BASE_A, UI.TOUCH_STICK_KNOB_A)


func _draw_a(s: Control, label: String, action: String) -> void :
	var k: = ui_scale()
	var c: = a_rect().get_center()
	var r: = 45.0 * k
	var a: = btn_alphas(action)
	s.draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.35))
	s.draw_circle(c, r, Color(UiKit.INK, a.x))
	s.draw_arc(c, r - 2.0, 0.0, TAU, 44, Color(0.35, 0.85, 0.45, a.y), 3.5, true)
	UI.text_center(s, c + Vector2(0, 11 * k), "A", int(32 * k), Color(UiKit.PAPER, a.z), 4, UiKit.title_font())
	UI.text_center(s, c + Vector2(0, r + 16 * k), label, int(13 * k), Color(UiKit.PAPER, a.z), 3)


func _draw_b(s: Control, label: String, action: String) -> void :
	var k: = ui_scale()
	var c: = b_rect().get_center()
	var r: = 38.0 * k
	var a: = btn_alphas(action)
	s.draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.35))
	s.draw_circle(c, r, Color(UiKit.INK, a.x))
	s.draw_arc(c, r - 2.0, 0.0, TAU, 40, Color(0.9, 0.3, 0.3, a.y), 3.5, true)
	UI.text_center(s, c + Vector2(0, 9 * k), "B", int(26 * k), Color(UiKit.PAPER, a.z), 4, UiKit.title_font())
	UI.text_center(s, c + Vector2(0, r + 14 * k), label, int(12 * k), Color(UiKit.PAPER, a.z), 3)


func _draw_start(s: Control) -> void :
	var k: = ui_scale()
	var r: = start_rect()
	var a: = btn_alphas("pk_start")
	UI.rounded(s, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.35), int(14 * k))
	UI.rounded(s, r, Color(UiKit.INK, a.x), int(14 * k), 2.0, Color(UiKit.AMBER, a.y))
	UI.text_center(s, r.get_center() + Vector2(0, 5 * k), "START", int(15 * k), Color(UiKit.PAPER, a.z), 3)


func _draw_menu(s: Control) -> void :
	var k: = ui_scale()
	var c: = menu_rect().get_center()
	var r: = SMALL_R * k
	var a: = btn_alphas("pk_pause")
	UI.rounded(s, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), Color(UiKit.INK, a.x), int(14 * k), 2.0, Color(UiKit.PAPER, a.y))
	for i in 3:
		var y: = c.y - 9.0 * k + i * 9.0 * k
		s.draw_line(Vector2(c.x - 12.0 * k, y), Vector2(c.x + 12.0 * k, y), Color(UiKit.PAPER, a.z), 3.0, true)


func _draw_pause(s: Control) -> void :
	var k: = ui_scale()
	var c: = pause_rect().get_center()
	var r: = SMALL_R * k
	var a: = btn_alphas("pk_pause")
	UI.rounded(s, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), Color(UiKit.INK, a.x), int(14 * k), 2.0, Color(UiKit.PAPER, a.y))
	s.draw_rect(Rect2(c.x - 11.0 * k, c.y - 14.0 * k, 7.0 * k, 28.0 * k), Color(UiKit.PAPER, a.z))
	s.draw_rect(Rect2(c.x + 4.0 * k, c.y - 14.0 * k, 7.0 * k, 28.0 * k), Color(UiKit.PAPER, a.z))


func _draw_dpad(s: Control) -> void :
	var k: = ui_scale()
	for i in 4:
		var r: = dpad_rect(i)
		var a: = btn_alphas(String(DPAD_ACTIONS[i]))
		UI.rounded(s, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.35), int(14 * k))
		UI.rounded(s, r, Color(UiKit.INK, a.x), int(14 * k), 2.0, Color(UiKit.PAPER, a.y))
		var dirs: = [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]
		_arrow(s, r.get_center(), dirs[i], k, a.z)


func _arrow(s: Control, c: Vector2, d: Vector2, k: float, alpha: = 1.0) -> void :
	var side: = Vector2( - d.y, d.x)
	var tip: = c + d * 12.0 * k
	var base: = c - d * 6.0 * k
	s.draw_colored_polygon(PackedVector2Array([
		tip, base + side * 10.0 * k, base - side * 10.0 * k]), Color(UiKit.PAPER, alpha))
