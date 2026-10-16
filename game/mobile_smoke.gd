extends SceneTree

# Bounded integration probe. Not an autoload; only run explicitly with --script.
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures.append(label)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var file := ProjectSettings.globalize_path("res://../reference/prototype/" + label + ".png")
	root.get_texture().get_image().save_png(file)

func _run() -> void:
	create_timer(150.0).timeout.connect(func(): quit(2))
	change_scene_to_file("res://scenes/front/boot.tscn")
	await create_timer(4.5).timeout
	var touch = root.get_node("Touch")
	var game = root.get_node("Game")
	var analytics = root.get_node("Analytics")
	root.get_node("Settings").path = "user://mobile-smoke-settings.cfg"
	check(current_scene != null, "original boot scene loads")
	check(not analytics.enabled, "telemetry disabled")
	check(touch.visible, "touch controls visible before first input")
	await capture("mobile-title")
	await game.start_checkpoint("pallet")
	await create_timer(2.0).timeout
	check(game.get_player() != null, "Pallet Town loads with player")
	check(game.party.size() == 1, "original checkpoint creates party")
	var vp := root.get_visible_rect()
	for rect in [touch.a_rect(), touch.b_rect(), touch.menu_rect()]:
		check(vp.encloses(rect), "touch button inside landscape viewport")
	var physical_scale := float(DisplayServer.window_get_size().y) / vp.size.y
	if DisplayServer.get_name() != "headless":
		check(touch.menu_rect().size.y * physical_scale >= 47.5, "menu target at least 48 screen pixels")
	root.get_node("Settings").set_value("touch_controls", 2)
	check(root.get_node("Settings").touch_controls == 1, "old Off value resolves to usable On setting")
	var down := InputEventScreenTouch.new()
	down.index = 3
	down.pressed = true
	down.position = Vector2(160, 540)
	touch._input(down)
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = down.position + Vector2(80, 0)
	touch._input(drag)
	check(Input.is_action_pressed("move_right"), "finger drag moves right")
	var action := InputEventScreenTouch.new()
	action.index = 4
	action.pressed = true
	action.position = touch.b_rect().get_center()
	touch._input(action)
	check(Input.is_action_pressed("run"), "second finger holds run while moving")
	touch._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("run"), "backgrounding releases both fingers")
	await capture("mobile-pallet")
	await game.start_checkpoint("forest_north")
	await create_timer(2.0).timeout
	check(game.get_player() != null, "Viridian Forest streams")
	await capture("mobile-forest")
	var save = load("res://scripts/state/save_game.gd")
	save.path = "user://mobile-smoke-save.json"
	check(save.save_now(), "local save writes")
	check(not save.peek().is_empty(), "local save reads with scene and party")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.path = save.DEFAULT_PATH
	root.get_node("Settings").battle_tips = false
	var player = game.get_player()
	var wild = root.get_node("Encounters").spawn_creature({"species": "Rattata", "level": 2}, player.get_parent(), player.global_position + Vector3(2, 0, -2))
	var battle = root.get_node("Battle")
	await battle.start_battle(wild)
	await create_timer(1.0).timeout
	check(battle.in_battle and is_instance_valid(battle.partner), "original real-time battle starts")
	var hud = game.get_hud().battle_hud
	check(hud._moves[0]._name_fit("Scratch")[0].size() == 1, "Scratch label stays on one line")
	for i in 4:
		check(vp.encloses(hud.move_rect(i)), "battle move target inside landscape viewport")
	if DisplayServer.get_name() != "headless":
		check(hud.items_rect().size.y * physical_scale >= 51.5, "Items target at least 52 screen pixels")
		check(hud.jump_rect().size.y * physical_scale >= 51.5, "Jump target at least 52 screen pixels")
	var attack := InputEventScreenTouch.new()
	attack.index = 5
	attack.pressed = true
	attack.position = hud.move_rect(0).get_center()
	touch._input(attack)
	check(Input.is_action_pressed("move_1"), "finger press reaches battle move")
	attack.pressed = false
	touch._input(attack)
	check(not Input.is_action_pressed("move_1"), "battle move releases")
	await capture("mobile-battle")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root.get_node("Settings").path))
	print("MOBILE_SMOKE: " + str(failures.size()) + " failures")
	quit(0 if failures.is_empty() else 1)
