extends Control




const FrontEnd: = preload("res://scripts/front/front_end.gd")
const CreatureDef: = preload("res://scripts/creature.gd")
const BOOT: = "res://scenes/front/boot.tscn"

var is_open: = false
var _win: PkWindow
var _list: PkMenuList
var _card: TrainerCard
var _dialog: PkDialogBox
var _options: OptionsScreen
var _watching: Control


func _init() -> void :
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.setup_input()
	_win = PkWindow.new()
	_win.custom_minimum_size = Vector2(260, 0)
	_win.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_win.offset_left = -290
	_win.offset_top = 24
	_win.offset_right = -24
	add_child(_win)
	_list = PkMenuList.new()
	_list.active = false
	_list.chosen.connect(_on_chosen)
	_list.cancelled.connect(close)
	_list.moved.connect( func(_i): _card.visible = false)
	_win.add_child(_list)
	_card = TrainerCard.new()
	_card.custom_minimum_size = Vector2(440, 0)
	_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_card.offset_left = -760
	_card.offset_top = 24
	_card.offset_right = -320
	_card.visible = false
	_card.closed.connect( func(): _list.active = true)
	add_child(_card)
	_dialog = PkDialogBox.new()
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_dialog.offset_left = 120
	_dialog.offset_right = -120
	_dialog.offset_top = -190
	_dialog.offset_bottom = -30
	add_child(_dialog)
	_options = OptionsScreen.new()
	_options.closed.connect( func(): _list.active = true)
	add_child(_options)
	visible = false


func can_open() -> bool:
	if is_open or Game.get_player() == null or not Game._evolving.is_empty():
		return false
	if Battle.in_battle:
		return not Battle._intro and not Battle._ending and not Progression._capturing and not Battle._switching
	return not Game.is_busy()


func _unhandled_input(e: InputEvent) -> void :
	if not is_open and e.is_action_pressed("pk_pause") and can_open():
		get_viewport().set_input_as_handled()
		open()


func open() -> void :
	is_open = true
	Game.menu_open = true
	var p: = Game.get_player()
	if p:
		p.controls_enabled = false
	var items: Array = []
	if Battle.in_battle:
		if Battle.online or Battle.online_guest:
			items = _online_items()
		else:
			Battle._battle_paused = true
			items = _battle_items()
	else:
		if Game.flags.get("has_pokedex", false):
			items.append({"id": "pokedex", "label": "POKéDEX"})
		items.append_array([
			{"id": "pokemon", "label": "POKéMON", "disabled": Game.party.is_empty()}, 
			{"id": "bag", "label": "BAG"}, 
			{"id": "trainer", "label": Game.state.player_name}, 
			{"id": "save", "label": "SAVE", "disabled": not SaveGame.enabled}, 
			{"id": "options", "label": "OPTIONS"}, 
			{"id": "title", "label": "TITLE"}, 
		])
	_list.set_items(items)
	_card.visible = false
	_place()
	visible = true
	UiKit.sfx("menu_open")
	UiKit.pop_in(_win)
	_list.active = true


func close(restore_controls: = true) -> void :
	if not is_open:
		return
	is_open = false
	Battle._battle_paused = false
	_watching = null
	_list.active = false
	_card.active = false
	_card.visible = false
	visible = false
	UiKit.sfx("menu_close")
	Game.menu_open = false
	var p: = Game.get_player()
	if restore_controls and p and not Game.cutscene:
		p.controls_enabled = true


func _on_chosen(id: String) -> void :
	var menu_of: = {"pokedex": "dex", "pokemon": "party", "bag": "bag", 
		"trainer": "trainer_card", "save": "save", "options": "options"}
	if menu_of.has(id):
		Analytics.track("menu_opened", {"menu": menu_of[id]})
	match id:
		"ally_mode":
			Battle.cycle_ally_mode()
			_list.set_items(_battle_items())
		"control_other":
			Battle.swap_control()
			close()
		"run":
			await _run()
		"forfeit":
			await _forfeit()
		"resume":
			close()
		"pokedex":
			_open_sub("pokedex", Game.get_hud().open_pokedex)
		"pokemon":
			_open_sub("pokemon", Game.get_hud().open_party)
		"bag":
			_open_sub("bag", Game.get_hud().open_bag)
		"trainer":
			_list.active = false
			_card.open_card()
		"save":
			await _save()
		"options":
			_list.active = false
			_options.open()
		"title":
			_list.active = false
			if await _dialog.ask_yes_no("", "Return to the title screen? Progress since your last save will be lost."):
				close(false)
				SaveGame.enabled = false
				FrontEnd.boot_to_menu = true
				Transitions.go_to(BOOT, "", true)
			else:
				_list.active = true



func _battle_items() -> Array:
	var items: Array = [{"id": "ally_mode", 
		"label": "ALLY MODE: %s" % CreatureDef.ALLY_MODE_NAMES[Game.state.ally_mode]}]
	if Battle.allies.size() >= 2:
		items.append({"id": "control_other", "label": "CONTROL OTHER FIGHTER"})
	items.append({"id": "run", "label": "RUN"})
	items.append({"id": "resume", "label": "RESUME"})
	return items



func _run() -> void :
	if not Battle.trainer_battle.is_empty():
		Game._msg("No! There's no running from a trainer battle!", 1.5)
		return
	close(false)
	Battle.end_battle("fled")



func _online_items() -> Array:
	return [{"id": "forfeit", "label": "FORFEIT"}, {"id": "resume", "label": "BACK"}]



func _forfeit() -> void :
	_list.active = false
	if await _dialog.ask_yes_no("", "Forfeit the battle?"):
		var ob: = get_tree().get_first_node_in_group("online_battle")
		if ob != null and ob.has_method("forfeit"):
			ob.forfeit()
		close(false)
	else:
		_list.active = true


func _save() -> void :
	if not SaveGame.enabled:
		return
	_list.active = false
	if await _dialog.ask_yes_no("", "Would you like to save the game?"):
		var ok: = SaveGame.save_now()
		if ok:
			SaveGame.enabled = true
			Game.get_hud().show_saving()
		await _dialog.say("", ["%s saved the game." % Game.state.player_name if ok else "The game could not be saved."])
	_list.active = true




func _open_sub(id: String, open_fn: Callable) -> void :
	_list.active = false
	Game.menu_open = false
	var opened: bool = open_fn.call()
	Game.menu_open = true
	if not opened:
		_list.active = true
		return
	_watching = Game.get_hud().sub_panel(id)
	if _watching == null:
		_list.active = true


func _process(_delta: float) -> void :
	if _watching != null and not _watching.visible:
		_rearm()






func _place() -> void :
	if Battle.in_battle:
		var top: = 24.0
		var t: = get_node_or_null("/root/Touch")
		if t != null and t.visible and t.has_method("pause_rect"):
			top = t.pause_rect().end.y + 12.0
		var p: = get_parent()
		var log: Control = p.get("battle_log") if p != null else null
		if log != null and log.visible:
			top = maxf(top, log.position.y + log.size.y + 10.0)
		_win.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_win.anchor_left = 0.5
		_win.anchor_right = 0.5
		_win.anchor_top = 0.0
		_win.anchor_bottom = 0.0
		_win.offset_left = - _win.custom_minimum_size.x * 0.5
		_win.offset_right = _win.custom_minimum_size.x * 0.5
		_win.offset_top = top
		_win.offset_bottom = top
		return
	_win.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_win.anchor_left = 1.0
	_win.anchor_right = 1.0
	_win.anchor_top = 0.0
	_win.anchor_bottom = 0.0
	_win.offset_left = -290.0
	_win.offset_right = -24.0
	_win.offset_top = 24.0
	_win.offset_bottom = 24.0




func _rearm() -> void :
	var panel: = _watching
	if panel == null or panel.visible or not is_open:
		return
	_watching = null
	if Game.menu_open:
		is_open = false
		visible = false
		return
	Game.menu_open = true
	var p: = Game.get_player()
	if p:
		p.controls_enabled = false
	_list.active = true
