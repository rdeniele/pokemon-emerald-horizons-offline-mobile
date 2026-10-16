extends CanvasLayer

signal dialog_closed
signal choice_made(yes: bool)


const SummaryPanel: = preload("res://scripts/ui/summary_panel.gd")
const BagPanel: = preload("res://scripts/ui/bag_panel.gd")
const PokedexPanel: = preload("res://scripts/ui/pokedex_panel.gd")
const PartyPanel: = preload("res://scripts/ui/party_panel.gd")
const ShopPanel: = preload("res://scripts/ui/shop_panel.gd")
const PcPanel: = preload("res://scripts/ui/pc_panel.gd")
const CableClubPanel: = preload("res://scripts/ui/cable_club/cable_club_panel.gd")
const BattleIntro: = preload("res://scripts/ui/battle_intro.gd")
const BattleHud: = preload("res://scripts/ui/battle_hud.gd")
const BattleLog: = preload("res://scripts/ui/battle_log.gd")
const PartyOrbs: = preload("res://scripts/ui/party_orbs.gd")
const PartyRing: = preload("res://scripts/ui/kit/pk_party_ring.gd")
const PauseMenu: = preload("res://scripts/ui/pause_menu.gd")
const HintBar: = preload("res://scripts/ui/kit/pk_hint_bar.gd")

const Controls: = preload("res://scripts/controls.gd")

var _status: Label
var _ball: Label
var _msg: Label
var _msg_t: = 0.0
var _dlg: PkDialogBox
var _summary: PanelContainer
var intro: Control
var battle_hud: Control
var battle_log: Control
var party_orbs: Control
var party_ring: Control
var pause_menu: Control

var touch_controls: CanvasLayer
var _saving: Label

var _loc_panel: PanelContainer
var _loc_label: Label

var _clock: Label
var _loc_zone: = ""
var _streamer: Node
var _zone_ready: = false
var _in_battle: = false

var _loc_sb: StyleBoxFlat

var _hint: Control
const LOC_TOP: = 16.0
const LOC_RIGHT: = 14.0

const ORB_GAP: = 10.0

const LOC_RIGHT_TOUCH: = 78.0
const HINT_INSET: = 20.0


var _prompt: Control
var _prompt_target: Node3D
var _prompt_verb: = "�"
var _prompt_shown: = false
var _prompt_tw: Tween
const PROMPT_LIFT: = 14.0


func _ready() -> void :
	add_to_group("hud")
	battle_hud = BattleHud.new()
	add_child(battle_hud)
	battle_log = BattleLog.new()
	add_child(battle_log)
	intro = BattleIntro.new()
	add_child(intro)
	_status = _label(22)
	_status.position = Vector2(16, 36)
	_ball = _label(20)
	_ball.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_ball.offset_left = -360
	_ball.offset_top = -44
	_ball.offset_right = -16
	_ball.offset_bottom = -12
	_ball.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_msg = _label(28)
	_msg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_msg.offset_top = -90
	_msg.offset_bottom = -30
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_party_orbs()
	_build_location()
	_build_hint()
	party_ring = PartyRing.new()
	party_ring.name = "party_ring"
	add_child(party_ring)
	party_ring.picked.connect(_on_party_ring_picked)
	party_ring.held.connect(_on_party_ring_held)
	_build_dialog()
	pause_menu = PauseMenu.new()
	add_child(pause_menu)


	touch_controls = get_node_or_null("/root/Touch")


func _label(font_size: int) -> Label:
	var l: = Label.new()
	var s: = LabelSettings.new()
	s.font_size = font_size
	s.outline_size = 8
	s.outline_color = Color(0, 0, 0, 0.85)
	l.label_settings = s
	add_child(l)
	return l


func _build_party_orbs() -> void :

	party_orbs = PartyOrbs.new()
	party_orbs.anchor_left = 1.0
	party_orbs.anchor_right = 1.0
	add_child(party_orbs)
	_refresh_orbs()



func _build_location() -> void :
	_loc_panel = PanelContainer.new()
	_loc_panel.name = "location_pill"
	_loc_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loc_panel.visible = false

	_loc_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_loc_panel.anchor_left = 1.0
	_loc_panel.anchor_right = 1.0
	var sb: = UiKit.pill(Color(UiKit.INK, 0.8), Color.TRANSPARENT, 18)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	_loc_sb = sb
	_loc_panel.add_theme_stylebox_override("panel", sb)
	add_child(_loc_panel)

	var box: = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loc_panel.add_child(box)
	_loc_label = Label.new()
	_loc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_loc_label.add_theme_font_override("font", UiKit.title_font())
	_loc_label.add_theme_font_size_override("font_size", 22)
	_loc_label.add_theme_color_override("font_color", UiKit.PAPER)
	box.add_child(_loc_label)
	_clock = Label.new()
	_clock.name = "clock_line"
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.add_theme_font_override("font", UiKit.title_font())
	_clock.add_theme_font_size_override("font_size", UiKit.SIZE_SMALL)
	_clock.add_theme_color_override("font_color", UiKit.RIM)
	box.add_child(_clock)
	var clock: = get_node_or_null("/root/Clock")
	if clock != null:
		clock.minute_changed.connect(_on_clock_changed)
		clock.period_changed.connect(_on_clock_changed)
	Controls.on_device_changed(_on_device_changed)



func _on_clock_changed(_name: = "") -> void :
	_refresh_location()



func _refresh_clock() -> void :
	if _clock == null:
		return
	var clock: = get_node_or_null("/root/Clock")
	if clock == null:
		return
	var k: = Controls.ui_scale() if Controls.is_touch() else 1.0
	_clock.add_theme_font_size_override("font_size", int(UiKit.SIZE_SMALL * k))
	_clock.text = Clock.format(Clock.minutes)



func _build_hint() -> void :
	_hint = HintBar.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.visible = false
	add_child(_hint)
	_refresh_hint()


func _exit_tree() -> void :
	Controls.off_device_changed(_on_device_changed)


func _on_device_changed(_device: String) -> void :
	_refresh_location()
	_refresh_hint()
	_refresh_orbs()
	_refresh_dialog()




func _refresh_orbs() -> void :
	if party_orbs == null:
		return
	var top: = PartyOrbs.TOP
	if Controls.is_touch():
		var t: = get_node_or_null("/root/Touch")
		if t != null and t.has_method("menu_rect"):
			top = maxf(top, t.menu_rect().end.y + 8.0)

	if _loc_panel != null and _loc_panel.visible:
		top = maxf(top, _loc_panel.offset_bottom + ORB_GAP)
	party_orbs.set_top(top)
	var sz: Vector2 = party_orbs.panel_size()
	party_orbs.offset_right = -14.0
	party_orbs.offset_left = -14.0 - sz.x
	party_orbs.offset_top = top
	party_orbs.offset_bottom = top + sz.y




func _hud_corners_process() -> void :
	if not _zone_ready:
		var s: = get_tree().get_first_node_in_group("zone_streamer")
		if s != null:
			_zone_ready = true
			_streamer = s
			s.zone_changed.connect(_on_zone_changed)
			var id: = String(s.active)
			if id != "":
				_on_zone_changed(id, s.active_name())
	if Battle.in_battle != _in_battle:
		_in_battle = Battle.in_battle
		_refresh_location()
		_refresh_hint()


func _on_zone_changed(_zone_id: String, zone_name: String) -> void :
	_loc_zone = zone_name
	_refresh_location()




func _refresh_location() -> void :
	if _loc_panel == null:
		return
	var show: = _loc_zone != "" and not Battle.in_battle
	_loc_panel.visible = show
	if not show:
		_refresh_orbs()
		return
	_loc_label.text = _loc_zone
	_refresh_clock()
	var k: = Controls.ui_scale() if Controls.is_touch() else 1.0
	_loc_label.add_theme_font_size_override("font_size", int(22.0 * k))
	_loc_sb.content_margin_left = 20.0 * k
	_loc_sb.content_margin_right = 20.0 * k
	_loc_sb.content_margin_top = 6.0 * k
	_loc_sb.content_margin_bottom = 6.0 * k
	var right: = LOC_RIGHT
	if Controls.is_touch():
		right = LOC_RIGHT_TOUCH
		var t: = get_node_or_null("/root/Touch")
		if t != null and t.has_method("menu_rect"):
			right = get_viewport().get_visible_rect().size.x - t.menu_rect().position.x + 8.0
	var m: = _loc_panel.get_combined_minimum_size()
	_loc_panel.offset_right = - right
	_loc_panel.offset_left = - right - m.x
	_loc_panel.offset_top = LOC_TOP
	_loc_panel.offset_bottom = LOC_TOP + m.y
	_refresh_orbs()



func _refresh_hint() -> void :
	if _hint == null:
		return
	var show: = not Controls.is_touch() and not Battle.in_battle and not Debug.recording
	_hint.visible = show
	if not show:
		return
	var run: = Controls.key_label("run")
	if Controls.is_pad():
		run = "Hold " + run
	_hint.set_hints([[run, "Run"], ["pk_pause", "Menu"]])
	var m: Vector2 = _hint.get_combined_minimum_size()
	_hint.offset_right = - HINT_INSET
	_hint.offset_bottom = - HINT_INSET
	_hint.offset_left = - HINT_INSET - m.x
	_hint.offset_top = - HINT_INSET - m.y


func _build_dialog() -> void :


	_dlg = PkDialogBox.new()
	_dlg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_dlg.offset_left = -400
	_dlg.offset_right = 400
	_dlg.offset_top = -175
	_dlg.offset_bottom = -24
	add_child(_dlg)
	_dlg.finished.connect( func(): dialog_closed.emit())
	_refresh_dialog()







func _refresh_dialog() -> void :
	if _dlg == null:
		return
	var left: = -400.0
	var right: = 400.0
	if Controls.is_touch():
		var t: = get_node_or_null("/root/Touch")
		if t != null and t.has_method("b_rect"):
			const GAP: = 16.0
			const MARGIN: = 24.0
			var vw: = get_viewport().get_visible_rect().size.x
			var max_right: float = t.b_rect().position.x - GAP
			if vw * 0.5 + right > max_right:
				var w: = minf(800.0, maxf(200.0, max_right - MARGIN))
				right = max_right - vw * 0.5
				left = maxf(MARGIN - vw * 0.5, right - w)
				right = left + w
	_dlg.offset_left = left
	_dlg.offset_right = right
	_dlg.offset_top = -175.0
	_dlg.offset_bottom = -24.0


func open_dialog(speaker: String, lines: PackedStringArray) -> void :
	_dlg.say(speaker, Array(Dialogue.fill_lines(lines)))


func is_dialog_open() -> bool:
	return _dlg.visible



func is_choice_open() -> bool:
	return _dlg != null and _dlg.is_choice_open()



func choice_tap(gp: Vector2) -> bool:
	return _dlg != null and _dlg.choice_tap(gp)



func dialog_rect() -> Rect2:
	if _dlg == null or not _dlg.visible:
		return Rect2()
	return _dlg.get_global_rect()



func ask_yes_no(speaker: String, question: String) -> bool:
	return await _dlg.ask_yes_no(speaker, Dialogue.fill_text(question))




func _summary_process() -> void :
	if _summary == null:
		_summary = SummaryPanel.new()
		add_child(_summary)
	var p = Game.get_player()
	if _summary.visible:
		if _act("pk_back"):
			_summary.visible = false
			Audio.ui("sfx/ui/menu_close")
			Game.menu_open = false
			if p:
				p.controls_enabled = true
		else:
			if _act("pk_prev"):
				_summary.step(-1)
			elif _act("pk_next"):
				_summary.step(1)

			if _act("pk_left"):
				_summary.set_page(_summary.page - 1)
			if _act("pk_right"):
				_summary.set_page(_summary.page + 1)
			if _summary.page == 1 and _act("pk_alt"):
				_summary.toggle_iv_ev()
			if _summary.page == 2 and not _summary.read_only:
				if _act("pk_up"):
					_summary.move_selected(-1)
				if _act("pk_down"):
					_summary.move_selected(1)
				if _act("pk_ok"):
					_summary.confirm_move()
	elif Debug.summary and not Game.is_busy() and not Game.party.is_empty():
		Debug.summary = false
		open_summary()




func open_summary(start: = 0, read_only: = false) -> bool:
	if Game.party.is_empty() or (Game.is_busy() and not read_only):
		return false
	if _summary == null:
		_summary = SummaryPanel.new()
		add_child(_summary)
	_summary.open(start, read_only)
	Audio.ui("sfx/ui/menu_open")
	Game.menu_open = true
	var p = Game.get_player()
	if p:
		p.controls_enabled = false
	return true




func summary_panel() -> PanelContainer:
	if _summary == null:
		_summary = SummaryPanel.new()
		add_child(_summary)
	return _summary



func summary_visible() -> bool:
	return _summary != null and _summary.visible


var _bag: Control
var _bag_armed: = -1
var _pokedex: Control
var _party: Control
var _party_picking: = false
var _shop: Control
var _pc: Control
var _club: Control



func _act(action: StringName) -> bool:
	return Input.is_action_just_pressed(action)


func _bag_process() -> void :
	if _bag == null:
		_bag = BagPanel.new()
		add_child(_bag)
	var p = Game.get_player()
	if _party_picking:
		return

	if _bag.visible and not _bag.modal() and Engine.get_process_frames() != _bag_armed:
		var close: = false
		if _act("pk_back"):
			close = not _bag.back()
		if Debug.bag_use != "":
			var id: String = Debug.bag_use
			Debug.bag_use = ""
			var r: Dictionary = Progression.use_item(id, 0)
			print("[bag] use %s -> %s" % [id, r.text])
			_bag.refresh()
		if _act("pk_ok"):
			_bag.confirm()
		for k in 4:
			if _act("move_%d" % (k + 1)):
				_bag.assign_slot(k)
		if _act("pk_alt"):
			_bag.toss()
		if close:
			_bag.visible = false
			Audio.ui("sfx/ui/menu_close")
			Game.menu_open = false
			if p:
				p.controls_enabled = true
		if _act("pk_left"):
			_bag.step_pocket(-1)
		if _act("pk_right"):
			_bag.step_pocket(1)
		if _act("pk_up"):
			_bag.step_item(-1)
		if _act("pk_down"):
			_bag.step_item(1)
	elif Debug.bag and not Game.is_busy() and Game._evolving.is_empty():
		Debug.bag = false
		open_bag()



func open_shop(shop_id: String) -> void :
	if _shop == null:
		_shop = ShopPanel.new()
		add_child(_shop)


	if _dlg.visible:
		_dlg.close()
	_shop.open(shop_id)



func open_party() -> bool:
	if Game.is_busy() or Game.party.is_empty() or not Game._evolving.is_empty():
		return false
	_ensure_party().open()
	return true



func open_party_pick(item_id: String) -> bool:
	if not _ensure_party().open_pick(item_id):
		return false
	_party_picking = true
	if _bag:
		_bag.visible = false
	return true



func _on_party_pick_done(result: Dictionary) -> void :
	_party_picking = false
	if _bag:
		_bag.visible = true
		_bag.on_use_result(result)
	Game.menu_open = true
	var p: = Game.get_player()
	if p:
		p.controls_enabled = false



func _ensure_party() -> Control:
	if _party == null:
		_party = PartyPanel.new()
		add_child(_party)
		_party.pick_done.connect(_on_party_pick_done)
	return _party



func open_pc() -> bool:
	if _pc == null:
		_pc = PcPanel.new()
		add_child(_pc)
	_pc.open()
	return true



func open_cable_club() -> void :
	if _club == null:
		_club = CableClubPanel.new()
		add_child(_club)
	await _club.open()



func open_bag() -> bool:
	if Game.is_busy() or not Game._evolving.is_empty():
		return false
	if _bag == null:
		_bag = BagPanel.new()
		add_child(_bag)
	_bag.open()
	_bag_armed = Engine.get_process_frames()
	Audio.ui("sfx/ui/menu_open")
	Game.menu_open = true
	var p = Game.get_player()
	if p:
		p.controls_enabled = false
	return true



func open_pokedex() -> bool:
	if Game.is_busy() or not Game._evolving.is_empty():
		return false
	if _pokedex == null:
		_pokedex = PokedexPanel.new()
		add_child(_pokedex)
	_pokedex.open()
	return true



func sub_panel(id: String) -> Control:
	match id:
		"pokedex": return _pokedex
		"pokemon": return _party
		"bag": return _bag
	return null



func show_saving() -> void :
	if _saving == null:
		_saving = Label.new()
		_saving.theme = UiKit.theme()
		_saving.theme_type_variation = "SmallLabel"
		_saving.text = "● Saving…"
		_saving.add_theme_color_override("font_color", UiKit.PAPER)
		_saving.add_theme_color_override("font_outline_color", UiKit.INK)
		_saving.add_theme_constant_override("outline_size", 6)
		_saving.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		_saving.offset_left = -170
		_saving.offset_top = -48
		add_child(_saving)
	_saving.modulate.a = 1.0
	var tw: = _saving.create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(_saving, "modulate:a", 0.0, 0.4)




func show_interact_prompt(target: Node3D) -> void :
	if target == null or not is_instance_valid(target):
		return
	_prompt_target = target
	if _prompt == null:
		_prompt = HintBar.new()
		_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_prompt)
		_prompt.visible = false
	var verb: = String(target.prompt_verb()) if target.has_method("prompt_verb") else ""
	if verb != _prompt_verb:
		_prompt_verb = verb
		_prompt.set_hints([["interact", verb]])
		_prompt.size = _prompt.get_combined_minimum_size()
		_prompt.pivot_offset = _prompt.size * 0.5
	if not _prompt_shown:
		_prompt_shown = true
		_prompt.visible = true
		_prompt.scale = Vector2(0.9, 0.9)
		_prompt.modulate.a = 0.0
		if _prompt_tw:
			_prompt_tw.kill()
		_prompt_tw = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_prompt_tw.tween_property(_prompt, "scale", Vector2.ONE, 0.14)
		_prompt_tw.tween_property(_prompt, "modulate:a", 1.0, 0.14)
	_update_interact_prompt()



func hide_interact_prompt() -> void :
	_prompt_target = null
	if _prompt == null or not _prompt_shown:
		return
	_prompt_shown = false
	if _prompt_tw:
		_prompt_tw.kill()
	_prompt_tw = create_tween()
	_prompt_tw.tween_property(_prompt, "modulate:a", 0.0, 0.1)
	_prompt_tw.tween_callback( func():
		if not _prompt_shown and _prompt:
			_prompt.visible = false)



func interact_prompt_rect() -> Rect2:
	if _prompt == null or not _prompt_shown or not _prompt.visible:
		return Rect2()
	return Rect2(_prompt.position, _prompt.size).grow(8.0)




func _update_interact_prompt() -> void :
	if _prompt == null or not _prompt_shown:
		return
	if not is_instance_valid(_prompt_target):
		hide_interact_prompt()
		return
	var cam: = get_viewport().get_camera_3d()
	if cam == null:
		return
	var anchor: Vector3 = _prompt_target.global_position + Vector3(0, 2.0, 0)
	if _prompt_target.has_method("prompt_anchor"):
		anchor = _prompt_target.prompt_anchor()
	if cam.is_position_behind(anchor):
		_prompt.visible = false
		return
	_prompt.visible = true
	var screen: = cam.unproject_position(anchor)
	var sz: = _prompt.size
	var vp: = get_viewport().get_visible_rect().size
	var pos: = Vector2(screen.x - sz.x * 0.5, screen.y - sz.y - PROMPT_LIFT)
	pos.x = clampf(pos.x, 8.0, maxf(8.0, vp.x - sz.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, vp.y - sz.y - 8.0))
	_prompt.position = pos


func show_message(text: String, secs: = 2.5, kind: = "info") -> void :
	if battle_log.active():
		battle_log.push(text, kind)
		return
	_msg.text = text
	_msg_t = secs


func _party_ring_process() -> void :


	var can_open: = not Game.is_busy()\
	or (Battle.in_battle and not Battle._intro and not Battle._ending and not Battle._switching)
	if not party_ring.is_open and Input.is_action_just_pressed("party_ring") and can_open:
		party_ring.open("battle" if Battle.in_battle else "overworld")


func _on_party_ring_picked(slot: int) -> void :
	Game._party_key(slot, false)
	party_ring.close()


func _on_party_ring_held(slot: int) -> void :
	Game._party_key(slot, true)
	party_ring.close()


func _process(delta: float) -> void :
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg.text = ""
	_summary_process()
	_bag_process()
	_party_ring_process()
	_hud_corners_process()
	_update_interact_prompt()

	_status.text = ""
	_ball.text = ""
	var lift: = Battle.in_battle
	_msg.offset_top = -232.0 if lift else -90.0
	_msg.offset_bottom = -172.0 if lift else -30.0
