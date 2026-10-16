extends CanvasLayer













signal card_shown(id: String)
signal card_closed(id: String)

const Spotlight: = preload("res://scripts/ui/kit/pk_spotlight.gd")
const Dex: = preload("res://scripts/dex.gd")


const CARD_IDS: = ["start", "cooldown", "dodge", "stat", "stamina", "hp", 
	"catch_weaken", "catch_status", "catch_throw"]





const LESSON: = ["intro", "your_hp", "foe_hp", "moves", "stat", "attack"]
const LESSON_LIVE: = ["moves", "stat", "attack"]

const STAT_HOLD: = 3.5

const GRID_HOLD: = 1.6


const MIN_SHOW: = 0.35

const AUTO_DISMISS: = 1.0

const TITLES: = {
	"start": "Real-time battles", 
	"cooldown": "Stamina & cooldowns", 
	"dodge": "Dodge!", 
	"stat": "Stat changes", 
	"stamina": "Low stamina", 
	"hp": "Low HP", 
	"catch_weaken": "Weaken it first", 
	"catch_status": "Status helps", 
	"catch_throw": "Throw the ball", 
}
const BODIES: = {
	"start": "Battles happen in real time! Move your Pokémon with WASD and keep your distance.\nPress Q, E, R or F to use a move — Space repeats the last one.", 
	"cooldown": "Every move spends stamina (the bright part of the PP bar), then cools down: its button stays dark until it's ready. After any move, all your moves rest for a moment, so you can't fire two at once. Spend too much and your Pokémon staggers!", 
	"dodge": "Incoming! Hold Shift while moving to sprint out of the way. Sprinting burns stamina, so save it for dodging.", 
	"stat": "▼ chips under the HP bar show lowered stats, ▲ raised ones. They reset when the battle ends.", 
	"stamina": "Your stamina is almost gone. Hold off for a moment and it refills by itself. Sprinting drains it too.", 
	"hp": "Your Pokémon is hurt! Later you can heal mid-battle with Potions in the quick slots (Z X C V).", 
	"catch_weaken": "A Pokémon at full health breaks out of the ball. Knock its HP into the yellow or red — but don't make it faint!", 
	"catch_status": "A sleeping or paralysed Pokémon is much easier to catch. Moves like Sleep Powder or Thunder Wave are a trainer's best friends.", 
	"catch_throw": "Pick a ball in a quick slot and press its key (Z X C V) to throw it. Better balls, better odds!", 
}

const TOUCH_BODIES: = {
	"start": "Battles happen in real time! Drag the stick to move your Pokémon and keep your distance.\nTap a move button to use a move.", 
	"dodge": "Incoming! Hold the Sprint button while moving to sprint out of the way. Sprinting burns stamina, so save it for dodging.", 
	"hp": "Your Pokémon is hurt! Hold Items and tap the Potion slot to heal mid-battle.", 
	"catch_throw": "Pick a ball in a quick slot and tap it to throw. Better balls, better odds!", 
}


var shown: Array = []

var shown_at: Dictionary = {}

var _current: = ""
var _queue: Array = []
var _delays: = {}
var _elapsed: = 0.0
var _released: = false
var _active: = false
var _t0: = 0
var _open_ms: = 0
var _stat_name: = "a move"
var _moves: Node
var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _body: Label
var _hint: Label



var _lesson: = -1
var _lesson_t: = 0.0
var _status_slot: = -1
var _attack_slot: = -1
var _lesson_done: = false
var _spot: Control
var _bubble: Control
var _bubble_body: Label
var _bubble_hint: Label

var _arrow: Label
var _arrow_at: = Vector2.ZERO
var _arrow_on: = false


func _ready() -> void :
	add_to_group("battle_tutorial")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	_t0 = Time.get_ticks_msec()
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.35)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)
	_panel = PkWindow.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -400
	_panel.offset_right = 400
	_panel.offset_top = -190
	_panel.offset_bottom = -40
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)
	_title = Label.new()
	_title.theme_type_variation = "HeaderLabel"
	_title.add_theme_color_override("font_color", UiKit.BLUE)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(0, 62)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("font_color", UiKit.INK)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_body)
	var hint: = Label.new()
	hint.theme_type_variation = "SmallLabel"
	hint.text = _dismiss_hint()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_color", UiKit.DIM)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hint)
	_hint = hint
	_moves = get_node_or_null("/root/Moves")
	if _moves:
		_moves.move_used.connect(_on_move_used)
		_moves.hit_landed.connect(_on_hit_landed)
	Game.battle_started.connect(_on_battle_started)
	Game.battle_ended.connect(_on_battle_ended)
	_build_lesson_ui()




func _build_lesson_ui() -> void :
	_spot = Spotlight.new()
	add_child(_spot)
	_bubble = PkWindow.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	add_child(_bubble)
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_bubble.add_child(v)
	var who: = Label.new()
	who.theme_type_variation = "HeaderLabel"
	who.text = "Prof. Oak"
	who.add_theme_color_override("font_color", UiKit.BLUE)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(who)
	_bubble_body = Label.new()
	_bubble_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_body.custom_minimum_size = Vector2(400, 0)
	_bubble_body.add_theme_color_override("font_color", UiKit.INK)
	_bubble_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_bubble_body)
	_bubble_hint = Label.new()
	_bubble_hint.theme_type_variation = "SmallLabel"
	_bubble_hint.text = _dismiss_hint()
	_bubble_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bubble_hint.add_theme_color_override("font_color", UiKit.DIM)
	_bubble_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_bubble_hint)

	_arrow = Label.new()
	_arrow.text = "▼"
	_arrow.add_theme_font_size_override("font_size", 44)
	_arrow.add_theme_color_override("font_color", UiKit.AMBER)
	_arrow.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.0, 0.9))
	_arrow.add_theme_constant_override("outline_size", 8)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.visible = false
	add_child(_arrow)


func _exit_tree() -> void :
	if _moves:
		if _moves.move_used.is_connected(_on_move_used):
			_moves.move_used.disconnect(_on_move_used)
		if _moves.hit_landed.is_connected(_on_hit_landed):
			_moves.hit_landed.disconnect(_on_hit_landed)
	if Game.battle_started.is_connected(_on_battle_started):
		Game.battle_started.disconnect(_on_battle_started)
	if Game.battle_ended.is_connected(_on_battle_ended):
		Game.battle_ended.disconnect(_on_battle_ended)
	var t: = get_tree()
	if t and t.paused:
		t.paused = false





func show_card(id: String, force: = false) -> void :
	if not BODIES.has(id):
		return
	if _current == id or _queue.has(id):
		return
	if not force and _seen(id):
		return
	_delays.erase(id)
	if _current == "":
		_show(id)
	else:
		_queue.append(id)


func is_showing() -> bool:
	return _current != ""




func waiting_for_dismiss() -> bool:
	if _current != "":
		return true
	if _lesson >= 0:
		return not (String(LESSON[_lesson]) in LESSON_LIVE)
	return false



func show_cards(ids: Array) -> void :
	for id in ids:
		show_card(id, true)
	while _current != "" or not _queue.is_empty() or not _delays.is_empty():
		await get_tree().process_frame




func _on_battle_started(_fighter: Node, _wild: Node) -> void :
	_active = true
	_t0 = Time.get_ticks_msec()
	shown.clear()
	shown_at.clear()
	_queue.clear()
	_delays.clear()
	if _should_teach():
		_start_lesson()
		return
	_trigger("start", 1.3)


func _on_battle_ended(_result: String) -> void :
	_active = false
	_current = ""
	_lesson = -1
	_queue.clear()
	_delays.clear()
	_dim.visible = false
	_panel.visible = false
	if _spot:
		_spot.clear()
	if _bubble:
		_bubble.visible = false
	if _arrow:
		_arrow.visible = false
		_arrow_on = false
	Battle.clear_tut_lock()
	if get_tree().paused:
		get_tree().paused = false
	queue_free()


func _on_move_used(user: Node, move: Dictionary) -> void :
	if _lesson >= 0:


		var step: = String(LESSON[_lesson])
		if step == "moves" and is_instance_valid(Battle.partner) and user == Battle.partner\
		and _is_move(move, _status_slot):
			_lesson_next()
		return
	if not _active:
		return
	if is_instance_valid(Battle.partner) and user == Battle.partner:
		_trigger("cooldown", 0.8)
	elif is_instance_valid(Battle.wild) and user == Battle.wild:
		if float(move.get("power", 0)) > 0.0:
			_trigger("dodge")
		elif String(move.get("category", "")) == "status" and not _seen("stat"):
			_stat_name = String(move.get("name", "a move"))
			_trigger("stat")


func _on_hit_landed(user: Node, target: Node, _info: Dictionary) -> void :
	if _lesson >= 0:
		if String(LESSON[_lesson]) == "attack" and is_instance_valid(Battle.partner) and user == Battle.partner:
			_lesson_next()
		return
	if _active and is_instance_valid(Battle.partner) and target == Battle.partner:
		_trigger("dodge")



func _trigger(id: String, delay: = 0.0) -> void :
	if not Settings.battle_tips:
		return
	if _lesson_done and not id.begins_with("catch"):
		return
	if not BODIES.has(id) or _seen(id):
		return
	if id != "start" and _delays.has("start"):
		delay = maxf(delay, float(_delays["start"]) + 0.01)
	if delay <= 0.0:
		show_card(id)
	else:
		_delays[id] = delay


func _seen(id: String) -> bool:
	return bool(Game.flags.get("tut_" + id, false)) or shown.has(id) or _current == id or _queue.has(id) or _delays.has(id)




func _show(id: String) -> void :
	_current = id
	_elapsed = 0.0
	_released = false
	_open_ms = Time.get_ticks_msec()
	shown.append(id)
	shown_at[id] = maxf(0.0, (Time.get_ticks_msec() - _t0) / 1000.0)
	Game.flags["tut_" + id] = true
	_title.text = String(TITLES.get(id, ""))
	_body.text = _body_for(id)
	if _hint:
		_hint.text = _dismiss_hint()
	_dim.visible = true
	_panel.visible = true
	get_tree().paused = true
	print("[tutorial] ", id)
	card_shown.emit(id)


func _close() -> void :
	var id: = _current
	_current = ""
	_elapsed = 0.0
	_released = false
	_dim.visible = false
	_panel.visible = false
	Analytics.track("tutorial_card", {"id": id, "seconds_open": (Time.get_ticks_msec() - _open_ms) / 1000.0})
	card_closed.emit(id)
	if not _queue.is_empty():
		_show(_queue.pop_front())
	else:
		get_tree().paused = false


func _body_for(id: String) -> String:
	match id:
		"stat":
			var sp: = "The foe"
			if is_instance_valid(Battle.wild):
				sp = Battle.wild.species
			return "%s used %s!" % [sp, _stat_name] + "\n" + String(BODIES.get(id, ""))
		"hp":
			var q: Array = Game.quick_slots
			if Game.item_count("potion") > 0 and not q.is_empty() and String(q[0]) == "potion":
				if Controls.is_touch():
					return "Your Pokémon is hurt! Hold Items and tap the Potion slot to heal."
				return "Your Pokémon is hurt! Press Z to use a Potion from your quick slots. Items share a short cooldown."
	if Controls.is_touch() and TOUCH_BODIES.has(id):
		return String(TOUCH_BODIES[id])
	return String(BODIES.get(id, ""))




func _process(delta: float) -> void :
	if _lesson >= 0:
		_process_lesson(delta)
		return
	for id in _delays.keys():
		_delays[id] = float(_delays[id]) - delta
		if float(_delays[id]) <= 0.0:
			_delays.erase(id)
			show_card(id)
	if _current != "":
		_elapsed += delta
		if _released:
			if not _dismiss_held():
				_close()
		elif _elapsed >= MIN_SHOW and (_dismiss_pressed() or (Debug.auto_dialog and _elapsed >= AUTO_DISMISS)):
			_released = true
		return

	if get_tree().paused or not _active or not Battle.in_battle or not is_instance_valid(Battle.partner):
		return
	var p = Battle.partner
	if p.pp_max > 0.0 and float(p.stamina) < 0.3 * float(p.pp_max):
		_trigger("stamina")
	if p.max_hp > 0 and int(p.hp) < 0.5 * float(p.max_hp):
		_trigger("hp")


func _dismiss_pressed() -> bool:
	return Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("ui_accept")



func _dismiss_hint() -> String:
	if Controls.is_touch():
		return "Tap A to continue"
	return "[%s] OK" % Controls.key_label("confirm")






func _should_teach() -> bool:
	if not Settings.battle_tips or Debug.auto_dialog:
		return false
	var story: = get_node_or_null("/root/Story")
	if story != null and bool(story.debug_autoplay):
		return false
	if bool(Game.flags.get("tut_battle_lesson", false)) or bool(Game.flags.get("rival_battle_done", false)):
		return false
	return String(Battle.trainer_battle.get("class", "")) == "rival"


func _start_lesson() -> void :
	Game.flags["tut_battle_lesson"] = true
	Game.flags["tut_start"] = true
	_pick_lesson_moves()
	print("[tutorial] lesson start (status slot %d, attack slot %d)" % [_status_slot, _attack_slot])
	_lesson = 0
	_enter_lesson()




func _pick_lesson_moves() -> void :
	_status_slot = -1
	_attack_slot = -1
	if not is_instance_valid(Battle.partner):
		return
	var ids: Array = Battle.partner.moves
	for k in mini(ids.size(), 4):
		var mv: = Dex.move(String(ids[k]))
		if _status_slot < 0 and String(mv.get("category", "")) == "status" and int(mv.get("stages", 0)) < 0:
			_status_slot = k
		elif _attack_slot < 0 and float(mv.get("power", 0.0)) > 0.0:
			_attack_slot = k
	if _status_slot < 0:
		_status_slot = _attack_slot
	if _attack_slot < 0:
		_attack_slot = _status_slot








func _enter_lesson() -> void :
	var step: = String(LESSON[_lesson])
	var live: = step in LESSON_LIVE
	_lesson_t = 0.0
	_elapsed = 0.0
	_released = false
	get_tree().paused = false
	Battle.clear_tut_lock()
	Battle.tut_locked = true
	Battle.tut_hold_foe = true
	if step == "moves":
		Battle.tut_move = _status_slot
	elif step == "attack":
		Battle.tut_move = _attack_slot
		Battle.tut_walk = true
	_dim.visible = false
	_panel.visible = false
	var target: = _lesson_target(step)
	if step == "attack":
		_spot.clear()
	else:
		_spot.target(target)
	_set_arrow(step)
	_bubble_body.text = _lesson_line(step)
	_bubble_hint.text = _dismiss_hint()
	_bubble_hint.visible = not live
	_bubble.visible = true
	_place_bubble(target)
	print("[tutorial] lesson ", step)
	card_shown.emit("lesson_" + step)


func _lesson_next() -> void :
	_lesson += 1
	if _lesson >= LESSON.size():
		_end_lesson()
	else:
		_enter_lesson()



func _end_lesson() -> void :
	_lesson = -1
	_lesson_done = true
	_spot.clear()
	_bubble.visible = false
	_arrow.visible = false
	_arrow_on = false
	if get_tree().paused:
		get_tree().paused = false
	Battle.clear_tut_lock()
	print("[tutorial] lesson done")
	card_closed.emit("lesson")


func _process_lesson(delta: float) -> void :
	_lesson_t += delta
	_elapsed += delta
	_process_arrow()
	var step: = String(LESSON[_lesson])
	if step == "attack":
		return
	if step == "moves":


		if _lesson_t >= GRID_HOLD:
			var one: = _lesson_target("moves_one")
			if one.size.x > 0.0:
				_spot.target(one)
		return
	if step == "stat":


		var chips: = _lesson_target("stat")
		if chips.size.x > 0.0:
			_spot.target(chips)
	var done: = _lesson_t >= STAT_HOLD if step == "stat" else (_elapsed >= MIN_SHOW and _dismiss_pressed())
	if done or (Debug.auto_dialog and _lesson_t >= AUTO_DISMISS):
		_lesson_next()




func _lesson_target(step: String) -> Rect2:
	var hud: = Dialogue.hud()
	if hud == null or hud.battle_hud == null:
		return Rect2()
	var bh = hud.battle_hud
	match step:
		"your_hp":
			return bh.card_rect("you")
		"foe_hp":
			return bh.card_rect("foe")
		"moves":
			return bh.moves_rect()
		"moves_one":
			return bh.move_rect(_status_slot)
		"stat":
			return bh.foe_chips_rect()
		"attack":
			return bh.move_rect(_attack_slot)
	return Rect2()




func _set_arrow(step: String) -> void :
	var slot: = -1
	if step == "moves":
		slot = _status_slot
	elif step == "attack":
		slot = _attack_slot
	var r: = _move_button_rect(slot)
	if r.size.x <= 0.0:
		_arrow_on = false
		_arrow.visible = false
		return
	_arrow_on = true
	_arrow.visible = true
	_arrow_at = Vector2(r.get_center().x, r.position.y - 4.0)


func _move_button_rect(slot: int) -> Rect2:
	var hud: = Dialogue.hud()
	if hud == null or hud.battle_hud == null or slot < 0:
		return Rect2()
	return hud.battle_hud.move_rect(slot)



func _process_arrow() -> void :
	if not _arrow_on:
		return
	_arrow.reset_size()
	var m: = _arrow.get_combined_minimum_size()
	var bob: = sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.1) * 4.0
	_arrow.position = Vector2(_arrow_at.x - m.x * 0.5, _arrow_at.y - m.y + bob)




func _lesson_line(step: String) -> String:
	match step:
		"intro":
			return "Battles here don't wait their turn — they happen in real time. You move, and so does your Pokémon."
		"your_hp":
			return "Down here is your Pokémon's health. If that bar empties, it's out of the fight."
		"foe_hp":
			return "Up here is your opponent's health — that's what you're trying to empty."
		"moves":
			if _status_slot < 0:
				return "These are your four moves — %s." % ("tap one" if Controls.is_touch() else "one key each")
			return "These are your four moves — %s. Start with %s: %s" % [
				"tap one" if Controls.is_touch() else "one key each", _move_name(_status_slot), _stat_line(_status_slot)]
		"stat":
			return "See the ▼? The foe's %s is down — and that lasts for the rest of the battle." % _stat_word(_status_slot)
		"attack":
			if _attack_slot < 0:
				return "Now hit it!"
			if Controls.is_touch():
				return "Now hit it. Walk in close, then tap %s." % _move_name(_attack_slot)
			return "Now hit it. Walk in close, then press %s to use %s." % [_move_key(_attack_slot), _move_name(_attack_slot)]
	return ""


func _move_def(slot: int) -> Dictionary:
	if not is_instance_valid(Battle.partner) or slot < 0 or slot >= Battle.partner.moves.size():
		return {}
	return Dex.move(String(Battle.partner.moves[slot]))


func _move_name(slot: int) -> String:
	var mv: = _move_def(slot)
	return String(mv.get("name", "your move"))



func _stat_line(slot: int) -> String:
	var w: = _stat_word(slot)
	return "it lowers the foe's %s." % w if w != "" else "it weakens the foe."


func _stat_word(slot: int) -> String:
	match String(_move_def(slot).get("stat", "")):
		"atk":
			return "Attack"
		"def":
			return "Defense"
		"spa":
			return "Sp. Atk"
		"spd":
			return "Sp. Def"
		"spe":
			return "Speed"
	return ""


func _move_key(slot: int) -> String:
	if slot < 0 or slot >= 4:
		return "?"
	return Controls.key_label("move_%d" % (slot + 1))



func _is_move(move: Dictionary, slot: int) -> bool:
	var want: = _move_def(slot)
	if want.is_empty():
		return false
	var a: = String(move.get("id", move.get("name", "")))
	var b: = String(want.get("id", want.get("name", "")))
	return a != "" and a == b




func _place_bubble(rect: Rect2) -> void :
	_bubble.reset_size()
	var min: = _bubble.get_combined_minimum_size()
	_bubble.size = Vector2(maxf(min.x, 440.0), min.y)
	var vp: = get_viewport().get_visible_rect().size
	var at: = Vector2(vp.x * 0.5 - _bubble.size.x * 0.5, 150.0)
	if rect.size.x > 0.0:
		at.x = clampf(rect.get_center().x - _bubble.size.x * 0.5, 16.0, maxf(16.0, vp.x - _bubble.size.x - 16.0))
		at.y = rect.end.y + 14.0 if rect.position.y < 340.0 else rect.position.y - _bubble.size.y - 14.0
		if _arrow_on and rect.position.y >= 340.0:

			at.y -= _arrow.get_combined_minimum_size().y
	_bubble.position = at


func _dismiss_held() -> bool:
	return Input.is_action_pressed("interact") or Input.is_action_pressed("confirm") or Input.is_action_pressed("ui_accept")
