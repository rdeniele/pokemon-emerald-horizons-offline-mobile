extends "res://scripts/story/cutscene.gd"



const MonScript: = preload("res://scripts/stats/mon.gd")
const Dex: = preload("res://scripts/dex.gd")
const CreatureDef: = preload("res://scripts/creature.gd")
const StarterCard: = preload("res://scripts/ui/starter_card.gd")
const BattleTutorial: = preload("res://scripts/ui/battle_tutorial.gd")
const DemoEndCard: = preload("res://scripts/ui/demo_end_card.gd")
const FrontEnd: = preload("res://scripts/front/front_end.gd")
const NpcScript: = preload("res://scripts/npc.gd")

const RIVAL: = "Blue"
const OAK: = "Prof. Oak"
const VIRIDIAN_INTERIORS: = "res://scenes/interiors/viridian_city_interiors.tscn"
const BOOT: = "res://scenes/front/boot.tscn"
const RIVAL_LEVEL: = 5




const RIVAL_ARENA: = Vector2(10, 6.4)

const COUNTER: = {"Bulbasaur": "Charmander", "Charmander": "Squirtle", "Squirtle": "Bulbasaur"}






const RIVAL_STARTER_REACH: = 1.4

const STARTER_QUESTIONS: = {
	"Bulbasaur": "I see! BULBASAUR is your choice.\nIt's very easy to raise.\nSo, {PLAYER}, you want to go with\nthe GRASS POKéMON BULBASAUR?", 
	"Charmander": "Ah! CHARMANDER is your choice.\nYou should raise it patiently.\nSo, {PLAYER}, you're claiming the\nFIRE POKéMON CHARMANDER?", 
	"Squirtle": "Hm! SQUIRTLE is your choice.\nIt's one worth raising.\nSo, {PLAYER}, you've decided on the\nWATER POKéMON SQUIRTLE?", 
}


var debug_autoplay: = false

var scenario_mode: = false
var debug_pick: = "Bulbasaur"

var rival_ai_scale: = 1.6

var _auto_busy: = false
var _auto_went_out: = false

var _starter_previews: = 0


func _process(_delta: float) -> void :
	if scenario_mode:
		return
	if not debug_autoplay or running or _auto_busy or Game.is_busy():
		return
	_auto_busy = true
	_auto_run()


func trigger(event: String, _source: Node) -> void :
	if running:
		return
	print("[story] trigger ", event)
	match event:
		"oak_stop":
			oak_stop()
		"lab_exit":
			lab_exit()
		"mart_parcel":
			mart_parcel()
		"parcel_deliver":
			parcel_deliver()
		"pewter_east_block":
			pewter_east_block()
		"demo_end":
			demo_end()




func rival_display_name() -> String:
	return Game.state.rival_name


func lines_for(npc_name: String) -> PackedStringArray:

	return Dialogue.fill_lines(_lines_for(npc_name))


func _lines_for(npc_name: String) -> PackedStringArray:
	var f: = Game.flags
	match npc_name:
		"Mom":
			if not f.get("starter_chosen", false):
				return PackedStringArray(["…Right.\nAll boys leave home someday.\nIt said so on TV.", 
					"Oh, yes. PROF. OAK, next door, was\nlooking for you."])
		"Daisy":
			if f.get("rival_battle_done", false):
				return PackedStringArray(["{PLAYER}, I heard you had\na battle against {RIVAL}.", "I wish I'd seen that!"])
			return PackedStringArray(["Hi, {PLAYER}!", "My brother, {RIVAL}, is out at\nGrandpa's LAB."])
		"Head Researcher":
			if f.get("starter_chosen", false):
				return PackedStringArray(["That Pokémon already trusts you. Take good care of it!"])
		OAK:
			if f.get("has_pokedex", false):
				return PackedStringArray(["Come see me sometime.", 
					"After all, I want to know how your\nPOKéDEX is coming along."])
			if f.get("rival_battle_done", false):
				return PackedStringArray(["{PLAYER}, raise your young\nPOKéMON by making it battle.", 
					"It has to battle for it to grow."])
			if f.get("starter_chosen", false):
				return PackedStringArray(["If a wild POKéMON appears,\nyour POKéMON can battle it.", 
					"With it at your side, you should be\nable to reach the next town."])
			return PackedStringArray(["Now, {PLAYER}.", "Inside those three POKé BALLS are\nPOKéMON.", 
				"Which one will you choose for\nyourself?"])
		RIVAL:
			if f.get("starter_chosen", false):
				return PackedStringArray(["My POKéMON looks a lot\ntougher than yours."])
			return PackedStringArray(["Heh, I don't need to be\ngreedy like you. I'm mature!", 
				"Go ahead and choose, {PLAYER}!"])
		"Clerk":
			if f.get("has_parcel", false) and not f.get("has_pokedex", false):
				return PackedStringArray(["Okay, thanks! Please say hi to\nPROF. OAK for me, too."])
			if f.get("has_pokedex", false):
				return PackedStringArray(["Hi there! May I help you?"])
		"Aide":


			if f.get("hm05_flash", false):
				return PackedStringArray(["How is your POKéDEX coming along?", "Keep up the good work!"])
	return PackedStringArray()




func oak_stop() -> void :
	await begin()
	var p: = player()
	print("[story] oak_stop")
	p.show_alert(true)
	await wait(0.6)
	Audio.push_music("story", "music/oak", 0.3)
	await say(OAK, ["Hey! Wait!\nDon't go out!"])
	p.show_alert(false)
	await p.walk_to(Vector3(0.0, p.global_position.y, p.global_position.z + 0.6))
	var y: = Game.ground_y(p.global_position + Vector3(0, 0, 7), p.global_position.y)
	var oak: = spawn_npc(OAK, "res://assets/sprites/npc_oak.png", Vector3(0.0, y, p.global_position.z + 7.0))
	p.face_toward(oak.global_position)
	await oak.walk_to(p.global_position + Vector3(0, 0, 1.5))
	face_each_other(oak, p)
	await say(OAK, ["It's unsafe!\nWild POKéMON live in tall grass!", "You need your own POKéMON for\nyour protection.", "I know!\nHere, come with me!"])
	var dest: = oak.global_position + Vector3(0, 0, 4.0)
	oak.walk_to(dest)

	await p.walk_to(dest - Vector3(0, 0, 1.0), 8.0, NpcScript.SCRIPT_SPEED)
	Game.flags["oak_stopped"] = true
	AnalyticsBeats.beat("oak_stopped")
	_starter_previews = 0
	await goto(INTERIORS, "lab")
	await lab_intro()
	Audio.pop_music("story", 1.5)
	end()


func lab_intro() -> void :
	await wait(0.3)
	var p: = player()
	var oak: = find_npc(OAK)
	var rival: = find_npc(RIVAL)
	if oak == null or rival == null:
		push_error("[story] lab_intro: Oak or Blue missing in the lab")
		return


	await p.walk_to(Vector3(p.global_position.x, 0, 0.0))

	await p.walk_to(oak.global_position + Vector3(-2.1, 0, 3.0))
	p.face_toward(oak.global_position)
	await say(rival_display_name(), ["Gramps! I'm fed up with waiting!"])
	await say(OAK, ["{RIVAL}?\nLet me think…", "Oh, that's right, I told you to\ncome! Just wait!", 
		"Here, {PLAYER}.", "There are three POKéMON here.", "Haha!", 
		"The POKéMON are held inside\nthese POKé BALLS.", 
		"When I was young, I was a serious\nPOKéMON TRAINER.", 
		"But now, in my old age, I have\nonly these three left.", 
		"You can have one.\nGo on, choose!"])
	await say(rival_display_name(), ["Hey! Gramps! No fair!\nWhat about me?"])
	await say(OAK, ["Be patient, {RIVAL}.\nYou can have one, too!"])
	print("[story] lab_intro done")





func mart_parcel() -> void :
	if running:
		return
	await begin()
	var p: = player()
	var clerk: = find_npc("Clerk")
	if p == null or clerk == null:
		push_error("[story] mart_parcel: player or Clerk missing")
		end()
		return
	print("[story] mart_parcel")
	clerk.face(p.global_position - clerk.global_position)
	await say("Clerk", ["Hey!\nYou came from PALLET TOWN?"])

	await p.walk_to(Vector3(p.global_position.x, p.global_position.y, 0.9))
	await p.walk_to(clerk.global_position + Vector3(0, 0, 2.0))
	p.face_toward(clerk.global_position)
	await say("Clerk", ["You know PROF. OAK, right?", "His order came in.\nCan I get you to take it to him?"])
	await receive_item("oaks_parcel", 1, "OAK'S PARCEL")
	Game.flags["has_parcel"] = true
	AnalyticsBeats.beat("parcel_received")
	await say("Clerk", ["Okay, thanks! Please say hi to\nPROF. OAK for me, too."])
	end()



func parcel_deliver() -> void :
	if running:
		return
	await begin()
	var p: = player()
	var oak: = find_npc(OAK)
	if p == null or oak == null:
		push_error("[story] parcel_deliver: player or Oak missing in the lab")
		end()
		return
	print("[story] parcel_deliver")

	await p.walk_to(Vector3(p.global_position.x, 0, 0.0))
	await p.walk_to(oak.global_position + Vector3(0, 0, 1.5))
	p.face_toward(oak.global_position)
	await say(OAK, ["Oh, {PLAYER}!\nHow is my old POKéMON?", 
		"Well, it seems to be growing more\nattached to you.", 
		"You must be talented as a POKéMON\nTRAINER.", 
		"What's that?\nYou have something for me?"])
	Audio.play("sfx/world/item_pickup")
	Game.remove_item("oaks_parcel", 1)
	await say("", ["{PLAYER} delivered OAK'S PARCEL."])
	await say(OAK, ["Ah! \nIt's the custom POKé BALL!", "I had it on order.\nThank you!"])

	Audio.push_music("story", "music/rival", 0.3)
	var rival: = spawn_npc(RIVAL, "res://assets/sprites/npc_rival.png", _lab_door_pos())
	await rival.walk_path(_rival_enter_path(rival, p))
	rival.face(p.global_position - rival.global_position)
	await say(rival_display_name(), ["I almost forgot!\nWhat did you call me for?"])
	await say(OAK, ["Oh, right!\nI have a request for you two.", 
		"On the desk there is my invention,\nthe POKéDEX!", 
		"It automatically records data on\nPOKéMON you've seen or caught.", 
		"It's a high-tech encyclopedia!", 
		"{PLAYER} and {RIVAL}.\nTake these with you."])
	await receive_item("pokedex", 1, "the POKéDEX", "PROF. OAK")
	Game.flags["has_pokedex"] = true
	AnalyticsBeats.beat("pokedex_received")


	var sc: = get_tree().current_scene
	var lab: Node = sc.find_child("Lab", true, false) if sc else null
	if lab:
		for d in lab.find_children("Pokedex*", "Node3D", true, false):
			d.queue_free()
	await say(OAK, ["You can't get detailed data\non POKéMON by just seeing them.", 
		"You must catch them to obtain\ncomplete data.", 
		"So, here are some tools for\ncatching wild POKéMON."])
	await receive_item("poke_ball", 5, "5 POKé BALLS")
	await say(OAK, ["To make a complete guide on all\nthe POKéMON in the world…", "That was my dream!", 
		"But, I'm too old.\nI can't get the job done.", 
		"So, I want you two to fulfill my\ndream for me.", "Get moving, you two.", 
		"This is a great undertaking in\nPOKéMON history!"])
	Audio.push_music("story", "music/rival", 0.3)
	await say(rival_display_name(), ["All right, Gramps!\nLeave it all to me!", 
		"{PLAYER}, I hate to say it, but you\nwon't be necessary for this.", 
		"I know! I'll borrow a TOWN MAP\nfrom my sis!", 
		"I'll tell her not to lend you one,\n{PLAYER}! Hahaha!", 
		"Don't bother coming around to\nmy place after this!"])


	await rival.walk_to(_lab_door_pos())
	rival.queue_free()
	Audio.pop_music("story", 1.5)
	Game.flags["parcel_delivered"] = true
	AnalyticsBeats.beat("parcel_delivered")
	end()







func old_man_lesson(speaker: = "Old Man") -> void :
	if running:
		return
	await begin(false)
	if Game.flags.get("old_man_lesson", false):
		await say(speaker, ["Well, now, I've had my coffee, and\nthat's what I need to get going!", 
			"But I made it too strong.\nIt gave me a headache…", 
			"Incidentally, are you filling your\nPOKéDEX?", 
			"At first, focus on weakening the\nPOKéMON before trying to catch it."])
		end()
		return
	print("[story] old_man_lesson")

	if not await ask(speaker, "Shall I show you how to catch Pokémon?"):
		await say(speaker, ["Oh... Well, if you need to know, come back any time."])
		end()
		return
	var tut = BattleTutorial.new()
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	host.add_child(tut)
	await tut.show_cards(["catch_weaken", "catch_status", "catch_throw"])
	tut.queue_free()
	await say(speaker, ["There! Now tell me, that was\neducational, was it not?", "And here, take this, too."])
	await receive_item("teachy_tv", 1, "the TEACHY TV")
	AnalyticsBeats.beat("catch_lesson")
	await say(speaker, ["If there's something you don't\nunderstand, watch that.", 
		"It will teach you about the basics\nof being a POKéMON TRAINER."])
	Game.flags["old_man_lesson"] = true
	end()





func aide_reward() -> void :
	if running or Game.flags.get("hm05_flash", false):
		return
	if Game.state.dex_caught_count() < 10:
		return
	await begin(false)
	print("[story] aide_reward")
	await receive_item("hm_flash", 1, "HM05 Flash")
	Game.flags["hm05_flash"] = true
	end()








func pewter_east_block() -> void :
	await begin()
	var p: = player()
	p.show_alert(true)


	if Game.flags.get("boulder_badge", false):
		await say("Youngster", ["The road to Route 3 and Mt. Moon is closed… for now!", 
			"That's the end of the demo. Thanks for playing!"])
	else:
		await say("Youngster", ["You can't go east to Route 3 without the Boulder Badge.", 
			"Beat Leader Brock at the Pewter Gym and come back!"])
	p.show_alert(false)
	var back: = p.global_position + Vector3(-2.5, 0, 0)
	await p.walk_to(Vector3(back.x, p.global_position.y, back.z))
	end()








func demo_end() -> void :
	await begin()
	await Transitions.fade(1.0, 0.35)
	await Transitions.fade(0.0, 0.35)
	await say("", ["Congratulations! You've reached the end of the demo."])
	if SaveGame.enabled:
		if await ask("", "Would you like to save the game?"):
			var ok: bool = SaveGame.save_now()
			if ok:
				SaveGame.enabled = true
				hud().show_saving()
			var msg: = "%s saved the game." % Game.state.player_name if ok else "The game could not be saved."
			await say("", [msg])
	Game.flags["demo_end_seen"] = true
	AnalyticsBeats.beat("demo_completed")
	Analytics.track("demo_completed", {"play_time_min": int(Game.state.play_time / 60.0), 
		"whiteouts": Game.whiteout_count, 
		"party": Game.party.map( func(m): return "%s:%d" % [m.species, m.level])})
	var card: = DemoEndCard.new()
	hud().add_child(card)
	card.open()
	if debug_autoplay:
		await wait(3.0)
		card.press("continue")
		card.queue_free()
		end()
		return
	while true:
		var action: String = await card.choice
		if action == "continue":
			card.queue_free()
			break

		if await ask("", "Return to the title screen? Progress since your last save will be lost."):
			card.queue_free()
			Game.cutscene = false
			running = false
			var pl: = player()
			if pl:
				pl.controls_enabled = true
			SaveGame.enabled = false
			FrontEnd.boot_to_menu = true
			await Transitions.go_to(BOOT, "", true)
			return
		card.active = true
	end()





func pick_starter(ball: Node3D) -> void :
	var sp: String = ball.species
	if not Game.flags.get("oak_stopped", false):
		await say("Poké Ball", ["Those are POKé BALLS.\nThey contain POKéMON!"])
		return
	if Game.flags.get("starter_chosen", false):
		await say("Poké Ball", ["It's a Poké Ball with %s inside." % sp, "It's waiting for another trainer."])
		return
	await begin(false)
	var p: = player()
	var mon = MonScript.create(sp, ball.level)
	mon.owner = "player"
	ball.hide_ball(true)

	var body = Encounters.spawn_mon(mon, p.get_parent(), ball.global_position + Vector3(0, 0.15, 0), false)
	body.mode = CreatureDef.Mode.IDLE
	body.facing = (p.global_position - body.global_position).normalized()
	Audio.cry(sp, body.global_position)
	var card = StarterCard.new()
	hud().add_child(card)
	_starter_previews += 1
	card.show_species(sp)
	Game.state.mark_seen(sp)
	var t: String = String(Dex.species(sp).get("types", ["normal"])[0]).capitalize()

	var yes: bool = await ask(OAK, STARTER_QUESTIONS.get(sp, "So! You want the %s-type Pokémon, %s?" % [t, sp]))
	card.close()
	if is_instance_valid(body):
		body.queue_free()
	if not yes:
		ball.hide_ball(false)
		end()
		return
	print("[story] starter: ", sp)
	AnalyticsBeats.beat("starter_chosen", {"species": sp, "previews_before_yes": _starter_previews})
	ball.take()
	Game.receive_starter(sp, ball.level, mon)
	await say(OAK, ["This POKéMON is really quite\nenergetic!"])
	var rsp: String = COUNTER.get(sp, "Bulbasaur")
	var rival: = find_npc(RIVAL)
	var scene: = get_tree().current_scene
	var rball: Node = scene.find_child("Starter_" + rsp, true, false) if scene else null
	await say(rival_display_name(), ["I'll take this one, then!"])
	if rival and rball:


		var tgt: Vector3 = rball.global_position + Vector3(0, 0, RIVAL_STARTER_REACH)
		if Vector2(tgt.x - p.global_position.x, tgt.z - p.global_position.z).length() < 0.9:
			tgt.x += 0.9 if tgt.x >= p.global_position.x else -0.9
		await rival.walk_to(tgt)
		rival.face(Vector3(0, 0, -1))
		rball.take()
	Game.flags["rival_starter"] = rsp
	Game.flags["starter_" + rsp.to_lower()] = true
	await say("", ["%s received the %s\nfrom PROF. OAK!" % [rival_display_name(), rsp]])
	end()




func lab_exit() -> void :
	if Game.flags.get("rival_battle_done", false):
		return
	if not Game.flags.get("starter_chosen", false):
		await begin()
		await say(OAK, ["Hey!\nDon't go away yet!"])
		var p: = player()
		await p.walk_to(p.global_position + Vector3(0, 0, -1.5))
		end()
		return
	await rival_battle()



func rival_battle() -> void :
	await begin()
	var p: = player()
	var rival: = find_npc(RIVAL)
	if rival == null:



		rival = _spawn_rival(p)
	if rival == null:
		push_error("[story] rival_battle: no %s to fight and no RivalBattleSpot to spawn one in %s" % [RIVAL, s_scene()])
		end()
		return
	print("[story] rival battle")
	face_each_other(rival, p)
	await say(rival_display_name(), ["Wait, {PLAYER}!\nLet's check out our POKéMON!", "Come on, I'll take you on!"])


	var spot: = get_tree().current_scene.find_child("RivalBattleSpot", true, false) as Node3D
	var centre: Vector3 = spot.global_position if spot else p.global_position
	var teaches: bool = Settings.battle_tips and not debug_autoplay and not Game.flags.has("tut_battle_lesson")\
	and not Game.flags.get("rival_battle_done", false)
	var oak: = find_npc(OAK)
	if teaches and oak:
		await _oak_take_lesson_spot(oak, centre)
		await say(OAK, ["Blue's always in such a rush.", 
			"{PLAYER}, this is your first battle.\nLet me show you how it's done."])
	var rmon = MonScript.create(String(Game.flags.get("rival_starter", "Charmander")), RIVAL_LEVEL)
	rmon.owner = rival_display_name()
	var tut = BattleTutorial.new()
	get_tree().current_scene.add_child(tut)
	Game.cutscene = false
	if debug_autoplay:
		Battle.autopilot = true


	var opts: = {"ai_think_scale": rival_ai_scale, "arena": RIVAL_ARENA, 
		"trainer_class": "rival", "scripted": true}
	if spot:
		opts["center"] = centre
	var result: String = await Battle.start_trainer_battle(rival, rival_display_name(), [rmon], opts)
	if not debug_autoplay:
		Battle.autopilot = false
	Game.cutscene = true
	p.controls_enabled = false


	var cam: = Game.get_camera_rig()
	if cam:
		cam.focus_fixed(opts.get("center", (p.global_position + rival.global_position) * 0.5), Battle._battle_cam_dist())
	print("[story] rival battle: ", result)
	Game.flags["rival_battle_won"] = result == "won"
	if result == "aborted":
		push_warning("[story] rival battle aborted (no battle ran)")
		if is_instance_valid(tut):
			tut.queue_free()
	elif result == "won":
		await say(rival_display_name(), ["WHAT?\nUnbelievable!\nI picked the wrong POKéMON!"])
	else:
		await say(rival_display_name(), ["Yeah!\nAm I great or what?"])
	await say(OAK, ["If a wild POKéMON appears,\nyour POKéMON can battle it.", 
		"With it at your side, you should be\nable to reach the next town."])
	await Game.heal_with_fade()
	Audio.push_music("story", "music/rival", 0.3)
	await say(rival_display_name(), ["Okay! I'll make my\nPOKéMON battle to toughen it up!", "{PLAYER}! Gramps!\nSmell you later!"])
	if cam:
		cam.focus_follow(rival)
	await rival.walk_to(_lab_door_pos())
	rival.queue_free()
	Audio.pop_music("story", 1.5)
	Game.flags["rival_battle_done"] = true
	AnalyticsBeats.beat("rival_battle_done", {"won": bool(Game.flags.get("rival_battle_won", false))})
	end()




func _spawn_rival(p: Node3D) -> Node3D:
	var scene: = get_tree().current_scene
	if p == null or scene == null or scene.find_child("RivalBattleSpot", true, false) == null:
		return null
	return spawn_npc(RIVAL, "res://assets/sprites/npc_rival.png", _lab_door_pos())



func _lab_door_pos() -> Vector3:
	var exit_pos: Vector3 = player().global_position + Vector3(0, 0, 4.0)
	for sp in get_tree().get_nodes_in_group("spawn_point"):
		if sp.name == "lab":
			exit_pos = sp.global_position + Vector3(0, 0, 1.2)
	return exit_pos










func _oak_lesson_spot(centre: Vector3) -> Vector3:
	return centre + Vector3(RIVAL_ARENA.x * 0.5 + 0.7, 0, - (RIVAL_ARENA.y * 0.5 + 1.0))





func _oak_lesson_route(oak: Node3D, centre: Vector3) -> Array:
	var top: = _oak_lesson_spot(centre)
	return [Vector3(top.x, oak.global_position.y, oak.global_position.z), top]




func _oak_take_lesson_spot(oak: Node3D, centre: Vector3) -> void :
	await oak.walk_path(_oak_lesson_route(oak, centre))
	oak.face(centre - oak.global_position)



func _rival_enter_path(rival: Node3D, p: Node3D) -> Array:
	var door: = _lab_door_pos()
	return [Vector3(door.x, rival.global_position.y, p.global_position.z), p.global_position + Vector3(-1.2, 0, 0)]








const E2E_WORLD: = "res://scenes/world/overworld.tscn"
const E2E_PALLET: = "res://scenes/interiors/pallet_town_interiors.tscn"
const E2E_MART: = "res://scenes/interiors/viridian_city_interiors.tscn"
const E2E_FOREST: = "res://scenes/interiors/viridian_forest_interiors.tscn"
const E2E_PEWTER: = "res://scenes/interiors/pewter_city_interiors.tscn"



const W_SPINE_TO_VIRIDIAN: = [
	Vector2(7.2, 6.5), Vector2(0.0, 6.5), Vector2(0.0, -18.0), Vector2(0.0, -30.0), 
	Vector2(-8.5, -31.5), Vector2(-8.5, -44.0), Vector2(-8.5, -56.0), Vector2(6.5, -57.5), 
	Vector2(6.5, -68.0), Vector2(6.5, -82.0), Vector2(0.0, -83.5), Vector2(0.0, -90.0), 
	Vector2(0.0, -105.0), Vector2(0.0, -113.0), Vector2(0.0, -120.0)]
const W_MART_SPUR: = [Vector2(0.0, -141.5), Vector2(18.9, -141.5), Vector2(18.9, -145.3)]
const W_VIRIDIAN_GATE: = [
	Vector2(0.0, -141.5), Vector2(0.0, -188.0), Vector2(0.0, -195.0), Vector2(0.0, -203.0), 
	Vector2(-6.0, -204.0), Vector2(-6.0, -213.0), Vector2(-6.0, -221.0), Vector2(-4.0, -221.0), 
	Vector2(-4.0, -228.0), Vector2(1.5, -228.0), Vector2(2.5, -233.0), Vector2(2.5, -236.0), 
	Vector2(0.0, -236.0), Vector2(-1.0, -240.0), Vector2(-1.0, -246.0), Vector2(-6.0, -246.0), 
	Vector2(-6.0, -247.4)]



const W_FOREST_GATE: = [
	Vector2(-6.0, -286.0), Vector2(12.0, -289.0), Vector2(12.0, -326.0), Vector2(-18.0, -329.0), 
	Vector2(-18.0, -347.0), Vector2(-14.0, -346.0), Vector2(-14.0, -344.0), 
	Vector2(-6.0, -344.0), Vector2(-6.0, -350.5), Vector2(-6.0, -352.9)]
const W_R2N_PEWTER: = [
	Vector2(-6.0, -359.5), Vector2(0.0, -370.0), Vector2(0.0, -378.0), Vector2(0.0, -386.0)]

var _auto_failed: = ""


var _auto_boost_level: = 0



func _auto_run() -> void :
	var f: = Game.flags
	if not f.get("oak_stopped", false):
		if not _auto_went_out:
			_auto_went_out = true
			print("[story] autoplay step 0")
			print("[e2e] teleport to pallet start (opening skip)")
			await wait(1.5)
			await goto(OVERWORLD, "start")
			_auto_busy = false
			return
		print("[story] autoplay step 1")
		var p: = player()
		if p == null:
			_auto_busy = false
			return
		print("[e2e] teleport onto the Pallet road (opening skip)")
		var y: = Game.ground_y(Vector3(0, p.global_position.y, -13.5), p.global_position.y)
		p.global_position = Vector3(0, y, -13.5)
		await p.walk_to(Vector3(0, y, -17.5))
		_auto_busy = false
		return
	if not f.get("starter_chosen", false):
		print("[story] autoplay step 2")
		var scene: = get_tree().current_scene
		var ball: Node = scene.find_child("Starter_" + debug_pick, true, false) if scene else null
		var p: = player()
		if p == null or ball == null:
			_auto_busy = false
			return
		p.global_position = ball.global_position + Vector3(0, 0, 1.0)
		Game.start_dialogue(ball)
		_auto_busy = false
		return
	if not f.get("rival_battle_done", false):
		print("[story] autoplay step 3")
		trigger("lab_exit", null)
		_auto_busy = false
		return
	if not f.get("has_parcel", false):
		print("[story] autoplay step 4 -> Viridian Mart")
		await _auto_to_mart()
		_auto_busy = false
		return
	if not f.get("has_pokedex", false):
		print("[story] autoplay step 5 -> Oak's lab")
		await _auto_to_oak()
		_auto_busy = false
		return
	if not f.get("auto_pewter_reached", false):
		print("[story] autoplay step 6 -> Pewter")
		await _auto_to_pewter()
		if _zone() == "pewter_city":
			Game.flags["auto_pewter_reached"] = true
		_auto_busy = false
		return
	if not f.get("auto_gym_entered", false):
		print("[story] autoplay step 6b -> Pewter Gym")
		await _auto_to_gym()
		if _scene_path() == E2E_PEWTER:
			Game.flags["auto_gym_entered"] = true
		_auto_busy = false
		return
	if not f.get("trainer_camper_liam", false):
		print("[story] autoplay step 7 -> Camper Liam")
		await _auto_gym_liam()
		_auto_busy = false
		return
	if not f.get("boulder_badge", false):
		print("[story] autoplay step 8 -> Brock")
		await _auto_gym_brock()
		_auto_busy = false
		return
	if not f.get("demo_end_seen", false):
		print("[story] autoplay step 9 -> ending")
		await _auto_gym_exit()
		_auto_busy = false
		return
	print("[story] autoplay done")
	debug_autoplay = false
	_auto_busy = false





func _auto_to_mart() -> void :
	var guard: = 0
	while debug_autoplay and not Game.flags.get("has_parcel", false) and guard < 30:
		guard += 1
		var sc: = _scene_path()
		if sc == "":
			await wait(0.2)
			continue
		if sc == E2E_WORLD and _zone() == "":
			await wait(0.2)
			continue
		if sc == E2E_MART:
			break
		if sc == E2E_PALLET:
			await _leave_room("Lab")
			continue
		if sc == E2E_WORLD:
			match _zone():
				"pallet_town", "route_1":
					await _walk_chain(W_SPINE_TO_VIRIDIAN)
					await _walk_chain(W_MART_SPUR)
				"viridian_city":

					var p: = player()
					var z0: float = p.global_position.z if p else -141.5
					await _walk_chain([Vector2(0.0, z0), Vector2(0.0, -141.5), 
						Vector2(18.9, -141.5), Vector2(18.9, -145.3)])
				_:
					_auto_failed = "to_mart: unexpected zone %s" % _zone()
					await wait(0.5)
			continue
		_auto_failed = "to_mart: unexpected scene %s" % sc
		await wait(0.5)
	await _wait_flag("has_parcel", 180.0)



func _auto_to_oak() -> void :
	Debug.autoplay_boost(14)
	_auto_boost_level = 14
	var guard: = 0
	while debug_autoplay and not Game.flags.get("parcel_delivered", false) and guard < 30:
		guard += 1
		var sc: = _scene_path()
		if sc == "":
			await wait(0.2)
			continue
		if sc == E2E_WORLD and _zone() == "":
			await wait(0.2)
			continue
		if sc == E2E_MART:
			await _leave_room("PokeMart")
			continue
		if sc == E2E_PALLET:
			break
		if sc == E2E_WORLD:
			var chain: Array = _concat([Vector2(18.9, -141.5), Vector2(0.0, -141.5)], _reversed(W_SPINE_TO_VIRIDIAN))



			chain.append(Vector2(7.2, 3.7))
			await _walk_chain(chain)
			continue
		_auto_failed = "to_oak: unexpected scene %s" % sc
		await wait(0.5)
	await _wait_flag("parcel_delivered", 240.0)



func _auto_to_pewter(stop_zone: = "pewter_city") -> void :
	Debug.autoplay_boost(18)
	_auto_boost_level = 18
	var guard: = 0
	while debug_autoplay and _zone() != stop_zone and not _in_pewter_interior() and guard < 40:
		guard += 1
		var sc: = _scene_path()
		if sc == "":
			await wait(0.2)
			continue
		if sc == E2E_WORLD and _zone() == "":
			await wait(0.2)
			continue
		if sc == E2E_PALLET:
			await _leave_room("Lab")
			continue
		if sc == E2E_FOREST:
			var p: = player()
			var room: = "ForestNorthGate" if (p and p.global_position.x > 20.0) else "ForestSouthGate"
			var nd: = _room_child(room, "NorthDoor")
			var sp: = _room_child(room, "vf_gate_n_in" if room == "ForestNorthGate" else "vf_gate_s_in")
			if nd == null:
				_auto_failed = "to_pewter: no NorthDoor in %s" % room
				return

			var pts: Array = []
			if sp != null:
				pts.append(Vector2(sp.global_position.x, sp.global_position.z))
			pts.append(Vector2(nd.global_position.x, nd.global_position.z))
			await _walk_chain(pts)
			continue
		if sc == E2E_MART:
			await _leave_room("PokeMart")
			continue
		if sc == E2E_WORLD:
			match _zone():
				"pallet_town", "route_1":
					await _walk_chain(_concat(W_SPINE_TO_VIRIDIAN, W_VIRIDIAN_GATE))
				"viridian_city":
					await _walk_chain(W_VIRIDIAN_GATE)
				"route_2":
					await _walk_chain(W_VIRIDIAN_GATE.slice(3))
				"viridian_forest":
					await _walk_chain(W_FOREST_GATE)
				"route_2_north":
					await _walk_chain(W_R2N_PEWTER)
				"pewter_city":
					return
				_:
					_auto_failed = "to_pewter: unexpected zone %s" % _zone()
					await wait(0.5)
			continue
		_auto_failed = "to_pewter: unexpected scene %s" % sc
		await wait(0.5)



func _auto_to_gym() -> void :
	if _scene_path() == E2E_PEWTER:
		return
	if _zone() != "pewter_city":
		await _auto_to_pewter()
		if _zone() != "pewter_city":
			return
	var p: = player()



	var chain: Array = []
	if p and p.global_position.z < -427.0:
		chain = [Vector2(-18.0, -431.0), Vector2(-18.0, -433.0)]
	else:
		chain = [Vector2(0.0, -415.0), Vector2(0.0, -429.0), Vector2(-18.0, -429.0), Vector2(-18.0, -433.0)]
	await _walk_chain(chain)


func _in_pewter_interior() -> bool:
	return _scene_path() == E2E_PEWTER



func _auto_gym_liam() -> void :
	Debug.autoplay_boost(20)
	_auto_boost_level = 20
	var spot: = _marker("LiamSpot")
	if spot == null:
		_auto_failed = "gym: no LiamSpot"
		return


	var sx: float = spot.global_position.x
	var sz: float = spot.global_position.z
	await _walk_chain([Vector2(sx + 7.5, 9.0), Vector2(sx - 2.5, 9.0), Vector2(sx - 2.5, sz - 1.0), 
		Vector2(sx, sz - 1.0)])
	if not await _wait_flag("trainer_camper_liam", 240.0):
		_auto_failed = "Liam battle never finished (trainer_camper_liam)"



func _auto_gym_brock() -> void :
	Debug.autoplay_boost(22)
	_auto_boost_level = 22
	var center: = _marker("GymArenaCenter")
	var spot: = _marker("BrockSpot")
	if center == null or spot == null:
		_auto_failed = "gym: no arena markers"
		return
	await _walk_chain([Vector2(center.global_position.x, center.global_position.z), 
		Vector2(spot.global_position.x, spot.global_position.z)])
	var brock: = _room_child("PewterGym", "NPC_Brock")
	if brock == null:
		_auto_failed = "gym: Brock missing"
		return
	await Game.start_dialogue(brock)
	if not await _wait_flag("boulder_badge", 300.0):
		_auto_failed = "Brock battle never finished (boulder_badge)"



func _auto_gym_exit() -> void :
	var door: = _room_door("PewterGym")
	if door == null:
		_auto_failed = "gym: no ExitDoor"
		return
	var p: = player()
	await _walk_chain([Vector2(door.global_position.x, p.global_position.z if p else door.global_position.z), 
		Vector2(door.global_position.x, door.global_position.z)])
	if not await _wait_flag("demo_end_seen", 120.0):
		_auto_failed = "ending never played (demo_end_seen)"





func _walk_chain(points: Array) -> bool:
	for pt in points:
		if not is_instance_valid(player()):
			return true
		var r: String = await _step_to(pt)
		if r == "changed":
			return true
		if r == "timeout":
			_auto_failed = "walk stuck heading to %s (at %s)" % [pt, player().global_position]
			print("[e2e] STUCK -> %s from %s" % [pt, player().global_position])
			return false
	return true




func _step_to(pos: Vector2, secs: = 60.0, tol: = 0.6, stop_on_battle: = false) -> String:
	var p: = player()
	if p == null:
		return "changed"
	var scene0: = _scene_path()
	var t0: = Time.get_ticks_msec()
	var last: = Vector2(p.global_position.x, p.global_position.z)
	var stalled: = 0
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		if not is_instance_valid(p) or not p.is_inside_tree():
			await _await_transition()
			return "changed"
		if Game.is_busy():
			p.debug_move = Vector2.ZERO
			if stop_on_battle and (Battle.in_battle or Battle._ambush or (Game.cutscene and not Transitions.busy())):
				return "battle_started"
			var w0: = Time.get_ticks_msec()
			while Game.is_busy() and Time.get_ticks_msec() - w0 < 200000:
				await get_tree().physics_frame
				if not is_instance_valid(p) or not p.is_inside_tree():
					await _await_transition()
					return "changed"

			if _scene_path() != scene0:
				return "changed"
			last = Vector2(p.global_position.x, p.global_position.z)
			if _auto_boost_level > 0:
				Debug.autoplay_boost(_auto_boost_level)
			continue
		if _scene_path() != scene0:
			return "changed"
		var cur: = Vector2(p.global_position.x, p.global_position.z)
		var d: = pos - cur
		if d.length() < tol:
			p.debug_move = Vector2.ZERO
			for i in 4:
				await get_tree().physics_frame
			return "arrived"
		p.debug_move = d.normalized()
		await get_tree().physics_frame
		if cur.distance_to(last) < 0.0015:
			stalled += 1
			if stalled > 90:
				p.debug_move = Vector2.ZERO
				return "timeout"
		else:
			stalled = 0
		last = cur
	p.debug_move = Vector2.ZERO
	return "timeout"



func _leave_room(room: String) -> void :
	var door: = _room_door(room)
	if door == null:
		_auto_failed = "no ExitDoor in %s" % room
		return
	var p: = player()
	var pz: float = p.global_position.z if p else door.global_position.z
	await _walk_chain([Vector2(door.global_position.x, pz), 
		Vector2(door.global_position.x, door.global_position.z)])



func _await_transition() -> void :
	var t0: = Time.get_ticks_msec()
	while Transitions.busy() and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().physics_frame


func _room_child(room: String, child: String) -> Node3D:
	var sc: = get_tree().current_scene
	var r: Node = sc.find_child(room, true, false) if sc else null
	return r.find_child(child, true, false) as Node3D if r else null


func _room_door(room: String) -> Node3D:
	return _room_child(room, "ExitDoor")


func _marker(n: String) -> Node3D:
	var sc: = get_tree().current_scene
	return sc.find_child(n, true, false) as Node3D if sc else null


func _scene_path() -> String:
	var sc: = get_tree().current_scene
	return sc.scene_file_path if sc else ""


func _zone() -> String:
	var s: = get_tree().get_first_node_in_group("zone_streamer")
	return String(s.active) if s else ""


func _wait_flag(name: String, secs: float) -> bool:
	var t0: = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await get_tree().process_frame
		if Game.flags.get(name, false):
			return true
	return false


func _reversed(a: Array) -> Array:
	var out: = a.duplicate()
	out.reverse()
	return out


func _concat(a: Array, b: Array) -> Array:
	var out: = a.duplicate()
	out.append_array(b)
	return out





func s_walk(points: Array) -> bool:
	return await _walk_chain(points)


func s_step(xz: Vector2, secs: = 60.0, tol: = 0.6, stop_on_battle: = false) -> String:
	return await _step_to(xz, secs, tol, stop_on_battle)


func s_leave_room(room: String) -> void :
	await _leave_room(room)


func s_wait_flag(name: String, secs: float) -> bool:
	return await _wait_flag(name, secs)


func s_zone() -> String:
	return _zone()


func s_scene() -> String:
	return _scene_path()


func s_to_mart() -> void :
	await _auto_to_mart()


func s_to_oak() -> void :
	await _auto_to_oak()


func s_to_pewter(stop: = "pewter_city") -> void :
	await _auto_to_pewter(stop)


func s_to_gym() -> void :
	await _auto_to_gym()


func s_gym_liam() -> void :
	await _auto_gym_liam()


func s_gym_brock() -> void :
	await _auto_gym_brock()


func s_gym_exit() -> void :
	await _auto_gym_exit()
