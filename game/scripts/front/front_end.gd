extends Control






const Splash: = preload("res://scripts/front/splash.gd")
const TitleScreen: = preload("res://scripts/front/title_screen.gd")
const MainMenu: = preload("res://scripts/front/main_menu.gd")
const OakWelcome: = preload("res://scripts/front/oak_welcome.gd")
const NameEntry: = preload("res://scripts/ui/kit/pk_name_entry.gd")
const GenderPick: = preload("res://scripts/ui/kit/pk_gender_pick.gd")

const CreditsPanelScript: = preload("res://scripts/ui/credits_panel.gd")

const NEW_GAME_SCENE: = "res://scenes/interiors/pallet_town_interiors.tscn"
const NEW_GAME_SPAWN: = "bedroom_start"
const IDLE_TO_SPLASH: = 60.0

enum S{SPLASH, TITLE, MENU, BUSY, INTRO}

static var boot_to_menu: = false

var state: = S.SPLASH
var _splash: ColorRect
var _title: Control
var _menu: Control
var _options: OptionsScreen
var _credits: Control
var _dialog: PkDialogBox
var _hints: PkHintBar
var _idle: = 0.0
var _oak: Control
var _name_entry: Control
var _gender_pick: Control
var _intro_skipped: = false


func _ready() -> void :
	add_to_group("front_end")
	theme = UiKit.theme()
	UiKit.setup_input()
	SaveGame.enabled = false
	if Debug.checkpoint != "":
		return
	_title = TitleScreen.new()
	add_child(_title)
	_menu = MainMenu.new()
	_menu.chosen.connect(_on_menu)
	add_child(_menu)
	_hints = PkHintBar.new()
	_hints.position = Vector2(860, 660)
	_hints.set_hints([["pk_ok", "Select"], [["pk_up", "pk_down"], "Move"]])
	_hints.visible = false
	add_child(_hints)
	_dialog = PkDialogBox.new()
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_dialog.offset_left = 120
	_dialog.offset_right = -120
	_dialog.offset_top = -190
	_dialog.offset_bottom = -30
	add_child(_dialog)

	if Analytics.needs_consent():
		_title.visible = false
		var yes: = await _dialog.ask_yes_no("", "Help improve the demo by sending anonymous play data?\nYou can change this later in OPTIONS.")
		Analytics.set_consent(yes, "prompt")
		_title.visible = true
	Analytics.app_opened()
	_options = OptionsScreen.new()
	_options.closed.connect( func():
		state = S.MENU
		_menu.list.active = true)
	add_child(_options)
	_credits = CreditsPanelScript.new()
	_credits.closed.connect( func():
		state = S.MENU
		_menu.list.active = true)
	add_child(_credits)
	Audio.set_area_music("music/title", 1.0)
	if boot_to_menu:
		boot_to_menu = false
		_title.show_instant()
		_open_menu()
		return
	_splash = Splash.new()
	add_child(_splash)
	state = S.SPLASH
	await _splash.play()
	_splash.queue_free()
	_splash = null
	state = S.TITLE
	_title.play_intro()


func _input(e: InputEvent) -> void :



	if state == S.INTRO and _name_entry == null and _gender_pick == null and e.is_action_pressed("pk_back"):
		_skip_intro()
		get_viewport().set_input_as_handled()


func _unhandled_input(e: InputEvent) -> void :
	if e is InputEventKey and e.pressed:
		_idle = 0.0
	match state:
		S.SPLASH:
			if _splash and (e is InputEventKey or e is InputEventAction) and e.is_pressed():
				_splash.skip()
				get_viewport().set_input_as_handled()
		S.TITLE:
			if e.is_action_pressed("pk_ok"):
				UiKit.sfx("confirm")
				_open_menu()
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void :
	if state == S.TITLE:
		_idle += delta
		if _idle > IDLE_TO_SPLASH:
			get_tree().reload_current_scene()



func is_title() -> bool:
	return state == S.TITLE


func _open_menu() -> void :
	state = S.MENU
	_title.show_press_start(false)
	_hints.visible = true
	_menu.open(SaveGame.peek())


func _open_options() -> void :
	state = S.BUSY
	_menu.list.active = false
	_options.open()


func _open_credits() -> void :
	state = S.BUSY
	_menu.list.active = false
	_credits.open()


func _on_menu(id: String) -> void :
	Analytics.track("title_choice", {"choice": id, "has_save": SaveGame.exists()})
	match id:
		"continue":
			continue_game()
		"new_game":
			new_game()
		"options":
			_open_options()
		"credits":
			_open_credits()
		"quit":
			Analytics.quit_game()


func new_game() -> void :
	state = S.BUSY
	_menu.list.active = false
	if SaveGame.exists():
		_hints.visible = false
		var yes: = await _dialog.ask_yes_no("", "There is already a saved game. Start a new game? The old save is replaced when you next save.")
		if not yes:
			state = S.MENU
			_menu.list.active = true
			_hints.visible = true
			return
	Game.state.reset_new_game()
	_menu.visible = false
	_hints.visible = false
	Audio.set_area_music("music/oak", 0.5)
	await _run_intro()
	SaveGame.enabled = true

	Transitions.go_to(NEW_GAME_SCENE, NEW_GAME_SPAWN, true)




func _run_intro() -> void :
	state = S.INTRO
	_intro_skipped = false
	_oak = OakWelcome.new()
	add_child(_oak)
	await _oak.play_intro()
	if not _intro_skipped:
		Game.state.player_gender = await _ask_gender()
	if not _intro_skipped:
		Game.state.player_name = await _ask_name("YOUR NAME?", Game.state.player_name)
	await _oak.play_after_player(Game.state.player_name)
	if not _intro_skipped:
		Game.state.rival_name = await _ask_name("RIVAL'S NAME?", Game.state.rival_name)
	await _oak.play_finale()
	_oak = null
	AnalyticsBeats.beat("intro_done")
	Analytics.track("intro_completed", {"skipped": _intro_skipped, 
		"default_names": Game.state.player_name == GameState.DEFAULT_PLAYER_NAME
			and Game.state.rival_name == GameState.DEFAULT_RIVAL_NAME})



func _ask_gender() -> String:
	var pick: = GenderPick.new()

	pick.position = Vector2(420, 380)
	add_child(pick)
	_gender_pick = pick
	var g: String = await pick.ask(Game.state.player_gender)
	_gender_pick = null
	pick.queue_free()
	return g


func _ask_name(title_text: String, default_name: String) -> String:
	var entry: = NameEntry.new()

	entry.position = Vector2(420, 380)
	add_child(entry)
	_name_entry = entry
	var n: String = await entry.ask(title_text, default_name)
	_name_entry = null
	entry.queue_free()
	return n


func _skip_intro() -> void :
	if _intro_skipped:
		return
	_intro_skipped = true
	if _oak:
		_oak.skip()


func continue_game() -> void :
	state = S.BUSY
	_menu.list.active = false
	if SaveGame.peek().is_empty():
		_hints.visible = false
		await _dialog.say("", ["The save file could not be loaded."])
		_hints.visible = true
		_open_menu()
		return
	SaveGame.restore()
