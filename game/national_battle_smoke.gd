extends SceneTree

const Mon = preload("res://scripts/stats/mon.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func _run() -> void:
	create_timer(120.0).timeout.connect(func(): quit(2))
	await process_frame
	var game = root.get_node("Game")
	root.get_node("Settings").battle_tips = false
	await game.start_checkpoint("route1")
	await create_timer(1.0).timeout
	game.party.clear()
	game.party.append(Mon.create("Sprigatito", 14))
	game.party.append(Mon.create("Sylveon", 16))
	game.party_changed.emit()
	var player = game.get_player()
	var foe = root.get_node("Encounters").spawn_creature({"species": "Fuecoco", "level": 12}, player.get_parent(), player.global_position + Vector3(2, 0, -2))
	var battle = root.get_node("Battle")
	await battle.start_battle(foe)
	check(battle.in_battle and battle.partner.species == "Sprigatito", "Gen9 starter participates in original battle")
	check(not battle.partner._pmd().is_empty() and not foe._pmd().is_empty(), "Gen9 opponents use directional animation sheets")
	var hud = game.get_hud().battle_hud
	var touch = root.get_node("Touch")
	var viewport := root.get_visible_rect()
	for i in battle.partner.moves.size():
		check(viewport.encloses(hud.move_rect(i)), "Expanded roster keeps move buttons inside landscape")
	var press := InputEventScreenTouch.new()
	press.index = 9
	press.pressed = true
	press.position = hud.move_rect(0).get_center()
	touch._input(press)
	check(Input.is_action_pressed("move_1"), "Gen9 battle move receives touch input")
	press.pressed = false
	touch._input(press)
	await create_timer(2.0).timeout
	var imported_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/national-moves.json"))
	var imported_ids: Array = imported_data.moves.map(func(move): return String(move.id))
	var imported_move := ""
	for move in battle.partner.moves:
		if imported_ids.has(String(move)):
			imported_move = String(move)
			break
	check(imported_move != "", "Gen9 starter learns a newly imported action")
	if imported_move != "":
		battle.partner.move_cd.clear()
		battle.partner.gcd_t = 0.0
		check(root.get_node("Moves").use(battle.partner, imported_move), "Newly imported action executes in the original combat engine")
		await create_timer(1.0).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../reference/empress/national-battle.png"))
	print("NATIONAL_BATTLE_RESULT failures=%d" % failures)
	quit(0 if failures == 0 else 1)
