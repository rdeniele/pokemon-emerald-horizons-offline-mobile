extends Node



const CreatureDef: = preload("res://scripts/creature.gd")
const MonScript: = preload("res://scripts/stats/mon.gd")
const Capture: = preload("res://scripts/stats/capture.gd")
const CaptureFX: = preload("res://scripts/capture_fx.gd")
const Evolution: = preload("res://scripts/evolution.gd")
const DexData: = preload("res://scripts/dex.gd")
const ItemsData: = preload("res://scripts/items.gd")


var item_cd: = 0.0
var _capturing: = false

var _evolving: = {}
var _evo_check_t: = 0.0


var pending_moves: Array = []

var _teaching: RefCounted = null


func _process(delta: float) -> void :

	item_cd = maxf(item_cd - delta * Battle.fight_speed(), 0.0)
	_evo_check_t -= delta
	if _evo_check_t <= 0.0:
		_evo_check_t = 0.4
		check_evolutions()
	_maybe_teach()




func usable_ball() -> String:
	var id: String = Game.state.selected_ball
	if Game.state.item_count(id) > 0:
		return id
	for b in Game.bag.keys():
		if ItemsData.pocket_of(b) == "balls" and Game.state.item_count(b) > 0:
			return b
	return ""





func throw_capture(ball_id: = "") -> void :
	if not Battle.trainer_battle.is_empty():
		Game._msg("The trainer blocked the ball! Don't be a thief!", 1.5, "trainer")
		return
	if not Battle.in_battle or Battle._intro or Battle._ending or _capturing or Battle._switching or not is_instance_valid(Battle.partner) or not is_instance_valid(Battle.wild) or Battle.wild.mode == CreatureDef.Mode.FAINTED:
		return
	if ball_id == "":
		ball_id = usable_ball()
		if ball_id == "":
			Game._msg("You have no Poké Balls!")
			return
		Game.state.selected_ball = ball_id
	if Game.state.item_count(ball_id) <= 0:
		Game._msg("You have no Poké Balls!", 1.2, "item")
		return
	var p: = Game.get_player()
	if p == null:
		return
	_capturing = true
	Game.state.remove_item(ball_id)
	var w: = Battle.wild
	var res: = Capture.throw_ball(w.max_hp, w.hp, w.mon.catch_rate(), ball_id, w.status, w.level)
	Debug.log("[capture] %s on %s HP %d/%d status '%s' -> a=%.1f shakes=%d caught=%s" % [ball_id, w.species, w.hp, w.max_hp, w.status, res.a, res.shakes, res.caught])
	Analytics.track("catch_attempt", {"species": w.species, "level": w.level, "ball": ball_id, 
		"foe_hp_pct": int(roundf(100.0 * float(w.hp) / float(w.max_hp))), "status": w.status, 
		"success": res.caught, "shakes": res.shakes})

	var frozen: = {}
	for a in Battle.allies:
		if is_instance_valid(a) and a.mode != CreatureDef.Mode.FAINTED:
			frozen[a] = a.mode
			a.mode = CreatureDef.Mode.IDLE
			a.velocity = Vector3.ZERO
	w.mode = CreatureDef.Mode.IDLE
	w.velocity = Vector3.ZERO
	Game._msg("You threw a %s!" % Game.state.ball_name(ball_id), 1.5, "item")
	var spr_pos: Vector3 = w.get_node("Sprite3D").position
	var ball = await CaptureFX.throw_and_wobble(Game, p.get_parent(), p.global_position + Vector3(0, 1.2, 0), w, ball_id, res.shakes)
	if ball == null or not Battle.in_battle:
		if is_instance_valid(ball):
			ball.queue_free()
		_capturing = false
		return
	if res.caught:
		var m = w.mon
		m.owner = "player"
		m.ball = ball_id
		m.met_level = m.level
		m.met_zone = SaveGame.location_name()
		Game.state.mark_caught(m.species)
		var where: = ""
		if Game.state.party.size() < Game.MAX_PARTY:
			Game.state.party.append(m)
		else:
			Game.state.box.append(m)
			where = "\n%s was sent to the PC box." % m.species
		Game._msg("Gotcha! %s was caught!%s" % [m.species, where], 3.0, "catch")
		Audio.clear_jingles()
		Audio.jingle("music/caught")
		Debug.log("[capture] caught %s Lv%d (%s) -> %s" % [m.species, m.level, m.nature, "party" if where == "" else "box"])
		Battle.wild = null
		w.queue_free()
		await CaptureFX.success(Game, ball)
		_capturing = false
		Game.party_changed.emit()
		Battle.end_battle("caught")
	else:
		Game._msg(Capture.fail_line(res.shakes), 2.0, "catch")
		await CaptureFX.release(Game, ball, w, spr_pos)
		_capturing = false
		if Battle.in_battle and is_instance_valid(w):
			w.mode = CreatureDef.Mode.BATTLE_AI
			for a in frozen:
				if is_instance_valid(a) and a.mode == CreatureDef.Mode.IDLE:
					a.mode = frozen[a]









func award_exp(defeated: RefCounted, trainer: = false, quiet: = false) -> Array:
	var got: Array = Battle._participants.filter( func(m): return m.hp > 0 and Game.state.party.has(m))
	var results: Array = []
	for m in got:
		var gain: int = maxi(1, int(defeated.exp_yield(m.level, trainer) / float(got.size())))
		var events: Array = m.add_exp(gain)
		if quiet:
			_apply_exp(m, events, gain)
		else:
			_report_exp(m, events, gain)
		results.append({"mon": m, "gain": gain, "events": events})
	return results



func _body_of(m: RefCounted) -> CreatureDef:
	for k in Game.state.companions:
		if Game.state.is_out(k) and Game.state.companions[k].mon == m:
			return Game.state.companions[k]
	return null



func _report_exp(m: RefCounted, events: Array, gain: int) -> void :
	var body: = _body_of(m)
	var mv: = get_node_or_null("/root/Vfx")
	var leveled: = false
	var new_level: int = int(m.level)
	Game._msg("%s gained %d EXP." % [m.display_name, gain], 2.8, "exp")
	for e in events:
		if e.type == "level":
			leveled = true
			new_level = e.level
			Game._msg("%s grew to Lv %d!" % [m.display_name, e.level], 2.8, "level")
		elif e.type == "move":
			if e.learned:
				Game._msg("%s learned %s!" % [m.display_name, DexData.move(e.move).get("name", e.move)], 2.8, "level")

	if leveled and body and mv:
		mv.popup(body.global_position + Vector3(0, 2.4, 0), "Lv %d!" % new_level, Color(0.55, 0.85, 1.0), 1.2)
		mv.burst(body.global_position + Vector3(0, 0.6, 0), Color(0.6, 0.85, 1.0), 16, 0.4, 3.0)
	if leveled:
		Audio.jingle("music/level_up", true)
	_apply_exp(m, events, gain)




func _apply_exp(m: RefCounted, events: Array, gain: int) -> void :
	var body: = _body_of(m)
	for e in events:
		if e.type == "level":
			Analytics.track("level_up", {"species": m.species, "new_level": e.level})
		elif e.type == "move" and e.learned:
			Analytics.track("move_learned", {"species": m.species, "move": e.move, "replaced": ""})
		elif e.type == "move":
			queue_move(m, e.move)
	Debug.log("[exp] %s +%d -> Lv%d (%d xp)" % [m.species, gain, m.level, m.xp])
	if body:
		body.level = m.level
		body.sync_from_mon()
		body.moves = m.moves.duplicate()
		body.refresh_label()
	Game.party_changed.emit()





func queue_move(m: RefCounted, id: String) -> void :
	pending_moves.append({"mon": m, "move": id})




func _maybe_teach() -> void :
	if _teaching != null or pending_moves.is_empty():
		return
	if Battle.in_battle or Game.is_busy() or not _evolving.is_empty() or _capturing or Transitions.busy():
		return
	var entry: Dictionary = pending_moves.pop_front()
	var m = entry.mon
	var id: String = entry.move
	if not Game.state.party.has(m) or m.moves.has(id):
		return
	if m.moves.size() < 4:
		m.moves.append(id)
		_sync_body(m)
		Analytics.track("move_learned", {"species": m.species, "move": id, "replaced": ""})
		Game._msg("%s learned %s!" % [m.display_name, _move_name(id)], 2.0, "level")
		return
	_teach(m, id)



func _teach(m: RefCounted, id: String) -> void :
	_teaching = m
	Game.menu_open = true
	var p: = Game.get_player()
	if p:
		p.controls_enabled = false
	var mon: String = m.display_name.to_upper()
	var move: = _move_name(id).to_upper()
	var hud: = Game.get_hud()
	var slot: = -1
	if hud == null:
		slot = 0
	else:
		await _say(hud, PackedStringArray(["%s is trying to learn %s." % [mon, move], 
			"But %s can't learn more than four moves." % mon]))
		while slot < 0:
			if await hud.ask_yes_no("", "Delete a move to make room for %s?" % move):
				var panel = load("res://scripts/ui/forget_move_panel.gd").new()
				hud.add_child(panel)
				slot = await panel.choose(m, id)
				if slot >= 0:
					break
			if await hud.ask_yes_no("", "Stop learning %s?" % move):
				await _say(hud, PackedStringArray(["%s did not learn %s." % [mon, move]]))
				slot = -1
				break
	if slot >= 0:
		var replaced: String = m.moves[slot]
		var old: String = _move_name(m.moves[slot]).to_upper()
		m.replace_move(slot, id)
		Analytics.track("move_learned", {"species": m.species, "move": id, "replaced": replaced})
		_sync_body(m)
		if hud:
			hud.open_dialog("", PackedStringArray(["1, 2, and… … … Poof!", "%s forgot %s." % [mon, old], 
				"And…", "%s learned %s!" % [mon, move]]))
			Audio.jingle("music/level_up", true)
			await hud.dialog_closed
		else:
			Audio.jingle("music/level_up", true)
		Debug.log("[learn] %s forgot %s and learned %s" % [m.species, old, id])
	else:
		Analytics.track("move_skipped", {"species": m.species, "move": id, "replaced": ""})
	_teaching = null
	Game.menu_open = false
	if p and not Game.cutscene:
		p.controls_enabled = true



func _say(hud: Node, lines: PackedStringArray) -> void :
	hud.open_dialog("", lines)
	await hud.dialog_closed



func _sync_body(m: RefCounted) -> void :
	for k in Game.state.companions:
		if Game.state.is_out(k) and Game.state.companions[k].mon == m:
			Game.state.companions[k].moves = m.moves.duplicate()
	Game.party_changed.emit()


func _move_name(id: String) -> String:
	return String(DexData.move(id).get("name", id))






func check_evolutions() -> void :
	if Battle.online or Battle.online_guest:
		return
	if Game.state.talking or Game.state.menu_open or Transitions._transitioning or _capturing or Battle._ending:
		return
	if not _evolving.is_empty():
		return
	for i in Game.state.party.size():
		var m = Game.state.party[i]
		if not m.evo_pending or not Game.state.is_out(i):
			continue
		var target: String = m.evolution_target()
		if target == "":
			m.evo_pending = false
			continue
		var c: CreatureDef = Game.state.companions[i]
		if c.mode == CreatureDef.Mode.FAINTED or c.evolving or Game._sending.has(i):
			continue
		if Battle.in_battle and c != Battle.partner:
			continue
		_run_evolution(i, c, target)
		return


func _run_evolution(i: int, c: CreatureDef, target: String) -> void :
	var m = c.mon
	var from: String = m.species
	m.evo_pending = false
	var in_battle: = Battle.in_battle
	if in_battle:
		Battle.pause_for_evolution = true
	var evo = Evolution.begin(Game, c, target)
	_evolving[m] = evo
	Game.party_changed.emit()
	Debug.log("[evo] %s -> %s (Lv%d, %s)" % [m.species, target, m.level, "in battle" if in_battle else "overworld"])
	var evolved: bool = await evo.finished
	_evolving.erase(m)
	Analytics.track("evolution", {"from": from, "to": target, "cancelled": not evolved})
	if in_battle:
		Battle.pause_for_evolution = false
	if evolved:
		Game.state.mark_caught(m.species)
	Debug.log("[evo] %s" % ("evolved into " + m.species if evolved else "cancelled at Lv%d" % m.level))
	Game.party_changed.emit()





func trade_evolve(i: int, into: String) -> void :
	if into == "" or i < 0 or i >= Game.state.party.size():
		return
	if not Game.state.is_out(i):
		await Game.send_out(i)
	var c = Game.state.companions[i] if Game.state.is_out(i) else null
	if c == null:
		var m = Game.state.party[i]
		m.evolve(into)
		Game.state.mark_caught(m.species)
		Game.party_changed.emit()
	else:
		await _run_evolution(i, c, into)
	if SaveGame.enabled:
		SaveGame.save_now()








func use_item(id: String, i: int, quick_slot: = -1) -> Dictionary:
	var r: = _use_item(id, i)
	if r.ok:
		Analytics.track("item_used", {"item": id, "in_battle": Battle.in_battle, "quick_slot": quick_slot})
	return r


func _use_item(id: String, i: int) -> Dictionary:
	if Game.state.item_count(id) <= 0 or i < 0 or i >= Game.state.party.size():
		return {"ok": false, "text": ""}
	var m = Game.state.party[i]
	var e: Dictionary = ItemsData.item(id).get("effect", {})
	var body: CreatureDef = Game.state.companions[i] if Game.state.is_out(i) else null
	var name: String = m.display_name
	var no_effect: = {"ok": false, "text": "It won't have any effect."}
	if e.has("hp"):
		var cur: int = body.hp if body else m.hp
		if cur <= 0 or cur >= m.max_hp:
			return no_effect
		var amount: int = m.max_hp if str(e.hp) == "full" else int(e.hp)
		var healed: = mini(amount, m.max_hp - cur)
		if body:
			body.heal(healed)
		else:
			m.hp += healed

		Audio.play("sfx/battle/berry" if id.contains("berry") else "sfx/battle/potion")
		Game.state.remove_item(id)
		Game.party_changed.emit()
		return {"ok": true, "text": "%s's HP was restored by %d points." % [name, healed]}
	if e.has("cure"):
		var want: = String(e.cure)
		var cur: String = String(body.status) if body else String(m.status)
		if m.hp <= 0 or cur == "" or (want != "all" and cur != want):
			return no_effect
		var was: String = cur
		if body:
			body.clear_status()
		else:
			m.status = ""
		Audio.play("sfx/battle/cure")
		Game.state.remove_item(id)
		var words: = {"poison": "was cured of its poisoning", "paralysis": "was cured of paralysis", 
			"burn": "'s burn was healed", "sleep": "woke up"}
		var w: String = words.get(was, "was cured")
		return {"ok": true, "text": ("%s%s." % [name, w]) if w.begins_with("'") else ("%s %s." % [name, w])}
	if e.has("level"):
		if m.level >= MonScript.Growth.MAX_LEVEL:
			return no_effect
		var gain: int = m.exp_next_level - m.xp
		Game.state.remove_item(id)
		var events: Array = m.add_exp(gain)
		_report_exp(m, events, gain)
		return {"ok": true, "text": "%s grew to Lv %d!" % [name, m.level]}
	return {"ok": false, "text": "You can't use that here."}






func use_quick_item(k: int) -> void :
	if Battle.online or Battle.online_guest:
		return
	if k < 0 or k >= Game.state.quick_slots.size() or not Battle.in_battle or Battle._intro or Battle._ending or _capturing or Battle._switching:
		return
	var id: String = Game.state.quick_slots[k]
	if id == "":
		return
	if Game.state.item_count(id) <= 0:
		if ItemsData.pocket_of(id) == "balls":
			Game._msg("You have no Poké Balls!", 1.2, "item")
		else:
			Game._msg("You don't have any %ss left!" % ItemsData.item_name(id), 1.2, "item")
		return
	if ItemsData.pocket_of(id) == "balls":
		Game.item_used.emit(k)
		throw_capture(id)
		return
	if item_cd > 0.0 or not is_instance_valid(Battle.partner) or Battle.partner.evolving:
		return
	var i: = Game.state.party.find(Battle.partner.mon)
	var r: = use_item(id, i, k)
	if r.ok:
		item_cd = Game.ITEM_CD
		Game.item_used.emit(k)
		get_node("/root/Vfx").burst(Battle.partner.global_position + Vector3(0, 0.6, 0), Color(0.6, 1.0, 0.65), 20, 0.7, 2.0, 0.1)
		Debug.log("[item] battle: %s on %s" % [id, Battle.partner.species])
	Game._msg(r.text if r.text != "" else "You can't use that now.", 1.8, "item")
