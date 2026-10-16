class_name Controls
extends RefCounted





const DebugScript: = preload("res://scripts/debug.gd")


const MOVE_KEYS: = [KEY_S, KEY_D, KEY_A, KEY_W]

const ITEM_KEYS: = [KEY_S, KEY_D, KEY_A, KEY_W]














const ACTIONS: = {

	"move_left": {"kb": [KEY_LEFT], "pad": [{"axis": JOY_AXIS_LEFT_X, "value": -1.0}], "touch": "stick", "mode": "any", "deadzone": 0.25}, 
	"move_right": {"kb": [KEY_RIGHT], "pad": [{"axis": JOY_AXIS_LEFT_X, "value": 1.0}], "touch": "stick", "mode": "any", "deadzone": 0.25}, 
	"move_up": {"kb": [KEY_UP], "pad": [{"axis": JOY_AXIS_LEFT_Y, "value": -1.0}], "touch": "stick", "mode": "any", "deadzone": 0.25}, 
	"move_down": {"kb": [KEY_DOWN], "pad": [{"axis": JOY_AXIS_LEFT_Y, "value": 1.0}], "touch": "stick", "mode": "any", "deadzone": 0.25}, 

	"run": {"kb": [KEY_SHIFT], "pad": [{"btn": JOY_BUTTON_B}], "touch": "b", "mode": "overworld", "deadzone": 0.25}, 
	"interact": {"kb": [KEY_E], "pad": [{"btn": JOY_BUTTON_A}], "touch": "a", "mode": "overworld", "deadzone": 0.25}, 
	"party_ring": {"kb": [], "pad": [{"btn": JOY_BUTTON_DPAD_DOWN}], "touch": "party", "mode": "any", "deadzone": 0.25}, 

	"move_1": {"kb": [KEY_S], "pad": [{"btn": JOY_BUTTON_A}], "touch": "diamond_1", "mode": "battle", "deadzone": 0.25}, 
	"move_2": {"kb": [KEY_D], "pad": [{"btn": JOY_BUTTON_B}], "touch": "diamond_2", "mode": "battle", "deadzone": 0.25}, 
	"move_3": {"kb": [KEY_A], "pad": [{"btn": JOY_BUTTON_X}], "touch": "diamond_3", "mode": "battle", "deadzone": 0.25}, 
	"move_4": {"kb": [KEY_W], "pad": [{"btn": JOY_BUTTON_Y}], "touch": "diamond_4", "mode": "battle", "deadzone": 0.25}, 


	"sprint": {"kb": [KEY_SHIFT], "pad": [{"axis": JOY_AXIS_TRIGGER_RIGHT, "value": 1.0}], "touch": "sprint", "mode": "battle", "deadzone": 0.5}, 
	"jump": {"kb": [KEY_Q], "pad": [{"btn": JOY_BUTTON_RIGHT_SHOULDER}], "touch": "jump", "mode": "battle", "deadzone": 0.25}, 
	"items_page": {"kb": [KEY_Z], "pad": [{"btn": JOY_BUTTON_LEFT_SHOULDER}], "touch": "items", "mode": "battle", "deadzone": 0.25}, 
	"pause": {"kb": [KEY_ESCAPE], "pad": [{"btn": JOY_BUTTON_START}], "touch": "pause", "mode": "battle", "deadzone": 0.25}, 
	"confirm": {"kb": [KEY_E], "pad": [{"btn": JOY_BUTTON_A}], "touch": "tap", "mode": "battle", "deadzone": 0.25}, 

	"control_other": {"kb": [KEY_R], "pad": [{"axis": JOY_AXIS_TRIGGER_LEFT, "value": 1.0}], "touch": "swap", "mode": "battle", "deadzone": 0.5}, 

	"pk_up": {"kb": [KEY_UP], "pad": [{"btn": JOY_BUTTON_DPAD_UP}, {"axis": JOY_AXIS_LEFT_Y, "value": -1.0}], "touch": "stick", "mode": "menu", "deadzone": 0.5}, 
	"pk_down": {"kb": [KEY_DOWN], "pad": [{"btn": JOY_BUTTON_DPAD_DOWN}, {"axis": JOY_AXIS_LEFT_Y, "value": 1.0}], "touch": "stick", "mode": "menu", "deadzone": 0.5}, 
	"pk_left": {"kb": [KEY_LEFT], "pad": [{"btn": JOY_BUTTON_DPAD_LEFT}, {"axis": JOY_AXIS_LEFT_X, "value": -1.0}], "touch": "stick", "mode": "menu", "deadzone": 0.5}, 
	"pk_right": {"kb": [KEY_RIGHT], "pad": [{"btn": JOY_BUTTON_DPAD_RIGHT}, {"axis": JOY_AXIS_LEFT_X, "value": 1.0}], "touch": "stick", "mode": "menu", "deadzone": 0.5}, 
	"pk_ok": {"kb": [KEY_E], "pad": [{"btn": JOY_BUTTON_A}], "touch": "tap", "mode": "menu", "deadzone": 0.25}, 
	"pk_back": {"kb": [KEY_ESCAPE], "pad": [{"btn": JOY_BUTTON_B}], "touch": "back", "mode": "menu", "deadzone": 0.25}, 
	"pk_pause": {"kb": [KEY_ESCAPE], "pad": [{"btn": JOY_BUTTON_START}], "touch": "menu", "mode": "menu", "deadzone": 0.25}, 
	"pk_start": {"kb": [KEY_TAB], "pad": [{"btn": JOY_BUTTON_START}], "touch": "end", "mode": "menu", "deadzone": 0.25}, 
	"pk_prev": {"kb": [KEY_Q], "pad": [], "touch": "", "mode": "menu", "deadzone": 0.25}, 
	"pk_next": {"kb": [KEY_W], "pad": [], "touch": "", "mode": "menu", "deadzone": 0.25}, 
	"pk_alt": {"kb": [KEY_Z], "pad": [], "touch": "", "mode": "menu", "deadzone": 0.25}, 
	"evo_cancel": {"kb": [KEY_ESCAPE], "pad": [{"btn": JOY_BUTTON_B}], "touch": "back", "mode": "menu", "deadzone": 0.25}, 
}




static func setup(party_slots: int) -> void :
	for a in ACTIONS:
		_add_action(a, ACTIONS[a])
	if DebugScript.enabled:
		_add_action("heal", {"kb": [KEY_H], "pad": []})
	for i in party_slots:
		_add_action("party_%d" % (i + 1), {"kb": [KEY_1 + i], "pad": []})



static func setup_menus() -> void :
	for a in ACTIONS:
		if String(a).begins_with("pk_"):
			_add_action(a, ACTIONS[a])


static func _add_action(action: StringName, spec: Dictionary) -> void :
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in spec.get("kb", []):
		var ev: = InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	var has_axis: = false
	for d in spec.get("pad", []):
		if d.has("btn"):
			var b: = InputEventJoypadButton.new()
			b.button_index = d.btn
			InputMap.action_add_event(action, b)
		else:
			has_axis = true
			var m: = InputEventJoypadMotion.new()
			m.axis = d.axis
			m.axis_value = d.value
			InputMap.action_add_event(action, m)
	if has_axis:
		InputMap.action_set_deadzone(action, float(spec.get("deadzone", 0.5)))







static var _device: = "touch" if OS.has_feature("mobile") else "kb"

const PAD_NOTICE: = 0.25



static var _device_listeners: Array[Callable] = []



static func on_device_changed(cb: Callable) -> void :
	if not _device_listeners.has(cb):
		_device_listeners.append(cb)


static func off_device_changed(cb: Callable) -> void :
	_device_listeners.erase(cb)



static func device() -> String:
	return _device



static func is_pad() -> bool:
	return _device == "pad"





static func is_touch() -> bool:
	return _device == "touch" or emulate_touch




static var emulate_touch: = false












const UI_SCALE_MIN: = 1.0
const UI_SCALE_MAX: = 1.8
const DESKTOP_UI_SCALE: = 1.4
const TAP_MIN_MM: = 11.0

const TAP_REF_PX: = 44.0
const DESIGN_H: = 720.0


static var _demand: = -1.0





static func demand_scale() -> float:
	if _demand >= 0.0:
		return _demand
	var env: = OS.get_environment("TOUCH_SCALE")
	if env != "":
		_demand = maxf(env.to_float(), 0.0)
		return _demand
	if OS.has_feature("mobile"):
		var dpi: = float(DisplayServer.screen_get_dpi())
		var win: = DisplayServer.window_get_size()
		if dpi > 0.0 and win.y > 0:
			var mm_per_design: = 25.4 / dpi * (float(win.y) / DESIGN_H)
			_demand = TAP_MIN_MM / maxf(TAP_REF_PX * mm_per_design, 0.0001)
			return _demand
	_demand = DESKTOP_UI_SCALE
	return _demand



static func ui_scale() -> float:
	return clampf(demand_scale(), UI_SCALE_MIN, UI_SCALE_MAX)




static func touch_target_scale(base_px: float) -> float:
	return clampf(TAP_REF_PX * demand_scale() / maxf(base_px, 0.001), UI_SCALE_MIN, UI_SCALE_MAX)



static func reset_ui_scale() -> void :
	_demand = -1.0






static func note_device(e: InputEvent) -> void :
	var was: = _device
	if e is InputEventScreenTouch or e is InputEventScreenDrag:
		_device = "touch"
	elif e is InputEventJoypadButton:
		_device = "pad"
	elif e is InputEventJoypadMotion:
		if absf(e.axis_value) >= PAD_NOTICE:
			_device = "pad"
	elif e is InputEventKey:
		_device = "kb"
	elif e is InputEventMouse:
		if not emulate_touch and _device != "touch":
			_device = "kb"
	if _device != was:
		for cb in _device_listeners:
			if cb.is_valid():
				cb.call(_device)




const BUTTON_GLYPHS: = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", 
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", 
	JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Select", 
	JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓", 
	JOY_BUTTON_DPAD_LEFT: "D-pad ←", JOY_BUTTON_DPAD_RIGHT: "D-pad →", 
}
const AXIS_GLYPHS: = {
	JOY_AXIS_LEFT_X: "L-stick", JOY_AXIS_LEFT_Y: "L-stick", 
	JOY_AXIS_RIGHT_X: "R-stick", JOY_AXIS_RIGHT_Y: "R-stick", 
	JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT", 
}



const KEY_GLYPHS: = {KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→"}



static func event_label(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var code: Key = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		if KEY_GLYPHS.has(code):
			return String(KEY_GLYPHS[code])
		return OS.get_keycode_string(code).replace("Escape", "Esc")
	if ev is InputEventJoypadButton:
		return String(BUTTON_GLYPHS.get(ev.button_index, ev.as_text()))
	if ev is InputEventJoypadMotion:
		return String(AXIS_GLYPHS.get(ev.axis, ev.as_text()))
	return ev.as_text()



static func pad_glyph(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	var fallback: = ""
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			return event_label(ev)
		if ev is InputEventJoypadMotion and fallback == "":
			fallback = event_label(ev)
	return fallback




static func key_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""


	if is_touch():
		return ""
	var keys: Array = []
	var pads: Array = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			keys.append(ev)
		elif ev is InputEventJoypadButton:
			pads.append(ev)
		elif ev is InputEventJoypadMotion:
			pads.append(ev)
	var ev: InputEvent = null
	if is_pad() and not pads.is_empty():
		ev = pads[0]
	elif not keys.is_empty():
		ev = keys[0]
	elif not pads.is_empty():
		ev = pads[0]
	return event_label(ev) if ev != null else ""



static func items_page_held() -> bool:
	return Input.is_action_pressed("items_page")



const PARTY_HOLD_MS: = 400
static var _party_down: = {}
static var _party_held: = {}




static func handle_input(game) -> void :
	for i in game.MAX_PARTY:
		var a: = "party_%d" % (i + 1)
		if Input.is_action_just_pressed(a):
			_party_down[i] = Time.get_ticks_msec()
			_party_held[i] = false
		if Input.is_action_pressed(a) and not _party_held.get(i, false)\
		and Time.get_ticks_msec() - int(_party_down.get(i, 0)) >= PARTY_HOLD_MS:
			_party_held[i] = true
			game._party_key(i, true)
		if Input.is_action_just_released(a):
			if not _party_held.get(i, false):
				game._party_key(i, false)
			_party_down.erase(i)
			_party_held.erase(i)
	if DebugScript.enabled and Input.is_action_just_pressed("heal") and not Battle.in_battle and not game.talking:
		game.heal_party()
	if Battle._intro and Input.is_action_just_pressed("confirm"):
		Battle._intro_skip = true


	if Battle.in_battle and not Battle.tut_locked and Input.is_action_just_pressed("control_other"):
		Battle.swap_control()
