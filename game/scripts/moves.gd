extends Node




















const Dex: = preload("res://scripts/dex.gd")
const VfxBeam: = preload("res://scripts/vfx_beam.gd")
const ProjectileScript: = preload("res://scripts/projectile.gd")
const StatCalc: = preload("res://scripts/stats/stat_calc.gd")

signal move_used(user, move)


signal move_released(user, move)
signal hit_landed(user, target, info)
signal move_missed(user, target, move)

signal knocked_out(user, target)



var debug_force_miss: = false

var debug_force_crit: = false

var accuracy_scale: = 1.0

var _cast_gen: = {}
var _anim_played: = {}

static var _data: = {}


static func _json() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/move_fx.json"))
		_data = parsed if parsed is Dictionary else {}
	return _data



static func fx_roles(mv: Dictionary) -> Dictionary:
	return _json().get("moves", {}).get(String(mv.get("id", "")), {})




func _legacy_fx(mv: Dictionary) -> bool:
	var roles: = fx_roles(mv)
	return roles.is_empty() or bool(roles.get("legacy", false))



static func status_role(status: String) -> Dictionary:
	return _role(_json().get("status", {}), status)



static func stat_role(stat_k: String, up: bool) -> Dictionary:
	var pair = _json().get("stats", {}).get(stat_k)
	return _role(pair, "up" if up else "down") if pair is Dictionary else {}



static func _role(roles: Dictionary, name: String) -> Dictionary:
	var v = roles.get(name)
	if v is String:
		return {"fx": v}
	return v if v is Dictionary else {}

const MISSABLE: = ["dash", "arc", "multi_arc", "whip", "projectile", "beam", "aoe_target", "zone"]

const STATUS_IMMUNE: = {"burn": "fire", "poison": "poison", "paralysis": "electric", "leech": "grass"}
const STAT_NAMES: = {"atk": "Attack", "def": "Defense", "spa": "Sp. Atk", "spd": "Sp. Def", "spe": "Speed", "acc": "Accuracy"}


func root() -> Node:
	return get_tree().current_scene


func targets_of(user: Node) -> Array:
	var out: Array = []
	if not is_instance_valid(user):
		return out
	for n in get_tree().get_nodes_in_group("combatant"):
		if n != user and is_instance_valid(n) and n.side != user.side and n.alive():
			out.append(n)
	return out






func can_afford(user: Node, id: String, careful: = true) -> bool:
	var mv: = Dex.move(id)
	if mv.is_empty() or user.pp_max < Dex.pp_cost(mv):
		return false
	return not careful or user.stamina >= Dex.fatigue(mv) or randf() < 0.1




func use(user: Node, id: String, feedback: = false) -> bool:
	if Battle.online_guest:
		return false
	var mv: = Dex.move(id)
	if mv.is_empty() or not is_instance_valid(user) or not user.can_act():
		return false
	if float(user.move_cd.get(id, 0.0)) > 0.0 or user.gcd_t > 0.0 or user.root_t > 0.0 or user.dash_t > 0.0:
		if feedback:
			Audio.ui("sfx/ui/error")
		return false


	if not user.may_start(mv):
		if feedback:
			Audio.ui("sfx/ui/error")
		return false
	var head: Vector3 = user.global_position + Vector3(0, 0.8, 0)
	var cost: = Dex.pp_cost(mv)
	var tired: = Dex.fatigue(mv)
	if user.pp_max < cost:
		if feedback:
			Audio.ui("sfx/ui/error")
			Vfx.popup(head, "Not enough PP!", Color(1, 0.6, 0.4))
		return false

	user.pp_max -= cost
	user.stamina = minf(user.stamina - tired, user.pp_max)
	var exhausted: bool = user.stamina < 0.0
	if user.mon:
		user.mon.pp = user.pp_max

	user.move_cd[id] = Dex.cooldown(mv) / user.speed_factor()
	user.gcd_t = Dex.GLOBAL_COOLDOWN / user.speed_factor()
	if user.status == "paralysis" and randf() < 0.2:
		Vfx.popup(head, "Fully paralyzed!", Dex.type_color("electric"), 1.0, "status")
		play_status_fx(user, "paralysis")
		return true

	var _uk: = user.get_instance_id()
	_cast_gen[_uk] = int(_cast_gen.get(_uk, 0)) + 1
	if _anim_played.size() > 256:
		_anim_played.clear()
	if exhausted:
		_stagger_after(user, mv)
	var prepare: = Dex.prepare_time(mv)

	move_used.emit(user, mv)
	if prepare <= 0.0:
		_deliver(user, mv)
		return true
	var gen: int = user.combat.begin_prepare(id, mv, prepare)
	_release_after(user, mv, gen)
	return true





func replay(user: Node, id: String, dir: Vector3) -> void :
	if not is_instance_valid(user) or not user.alive():
		return
	var mv: = Dex.move(id)
	if mv.is_empty():
		return
	user.facing = dir
	_deliver(user, mv)




func _release_after(user: Node, mv: Dictionary, gen: int) -> void :
	if not await user.combat.wait_prepare(gen):
		return
	if not is_instance_valid(user) or not user.alive():
		return
	user.combat.end_prepare()
	_deliver(user, mv)





func _deliver(user: Node, mv: Dictionary) -> void :
	var head: Vector3 = user.global_position + Vector3(0, 0.8, 0)
	move_released.emit(user, mv)
	var dir: Vector3 = user.aim_dir()

	var aimed: Node = user.opponent if is_instance_valid(user.opponent) and user.opponent.alive() else null
	var miss: Node = null


	if not Battle.online_guest:
		var acc: = float(mv.get("accuracy", 0.0))
		var eff_acc: = acc * accuracy_scale * _acc_mult(int(user.stages.get("acc", 0)))
		if aimed and acc > 0.0 and String(mv.kind) in MISSABLE and (debug_force_miss or (eff_acc < 100.0 and randf() * 100.0 >= eff_acc)):
			miss = aimed
			if String(mv.kind) != "multi_arc":
				dir = _miss_dir(user, aimed, mv, dir)
			_announce_miss(user, aimed, mv)

		if user.confusion_t > 0.0 and randf() < 0.33:
			Vfx.popup(head, "It's confused!", Dex.type_color("psychic"), 1.0, "status")
			dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			if dir.length() < 0.01:
				dir = Vector3.BACK
			dir = dir.normalized()
	user.facing = dir
	if user.has_method("play_move_anim"):
		user.play_move_anim(mv)
	Vfx.popup(head + Vector3(0, 1.6, 0), mv.name, Dex.type_color(mv.type), 1.0, "move")
	_play_cast_anim(user, mv)


	if String(mv.kind) == "arc" or String(mv.kind) == "multi_arc":
		user.combat.start_arc_step(dir)

	if mv.has("magnitude"):
		var roll: Array = _roll_magnitude(mv.magnitude)
		mv = mv.duplicate()
		mv.power = int(roll[1])
		mv["mag_level"] = int(roll[0])
		Vfx.popup(head + Vector3(0, 0.35, 0), "Magnitude %d" % int(roll[0]), Dex.type_color(mv.type), 1.0, "move")

	user.combat.cast_move = mv
	user.combat.cast_n += 1
	match String(mv.kind):
		"dash":
			if _legacy_fx(mv):
				Vfx.burst(user.global_position + Vector3(0, 0.2, 0), Color(0.85, 0.8, 0.7), 10, 0.35, 2.0, 0.12, 60.0, - dir + Vector3.UP * 0.3)
			user.combat.hop_to_reach(aimed)
			user.start_dash(mv, dir, miss)
		"arc":
			_arc(user, mv, dir, miss)
		"whip":
			_whip(user, mv, dir, miss)
		"multi_arc":
			_multi_arc(user, mv, miss)
		"projectile":
			_projectiles(user, mv, dir, false, miss)
		"homing":
			_projectiles(user, mv, dir, true)
		"stream":
			_stream(user, mv, dir)
		"beam":
			_beam(user, mv, dir, miss)
		"aoe_self":
			_aoe_self(user, mv)
		"aoe_target":
			_aoe_target(user, mv, dir, miss)
		"zone":
			_zone(user, mv, dir, miss)
		"self_buff":
			if String(mv.stat) == "crit":
				var before: int = user.crit_stage
				user.crit_stage = mini(user.crit_stage + int(mv.stages), 4)
				if user.crit_stage != before:
					play_stat_fx(user, "crit", true)
			else:
				_change_stage(user, String(mv.stat), int(mv.stages))
			if _legacy_fx(mv):
				Vfx.burst(user.global_position + Vector3(0, 0.3, 0), Dex.type_color(mv.type), 24, 0.8, 2.5, 0.12, 15.0, Vector3.UP, Vector3.ZERO, 0.6)
		"debuff_aoe":
			_debuff(user, mv)
		"clones":
			_clones(user, mv)



func _miss_dir(user: Node, target: Node, mv: Dictionary, dir: Vector3) -> Vector3:
	var to: Vector3 = target.global_position - user.global_position
	to.y = 0.0
	var dist: = maxf(to.length(), 0.5)
	var side: = 1.0 if randf() < 0.5 else -1.0
	var deg: = 0.0
	match String(mv.kind):
		"arc", "multi_arc", "whip":
			deg = float(mv.get("angle", 90)) / 2.0 + 25.0
		"projectile":
			deg = float(mv.get("spread", 0)) / 2.0 + rad_to_deg(atan2(1.4, dist)) + 6.0
		"beam":
			deg = rad_to_deg(atan2(float(mv.get("width", 0.8)) / 2.0 + 1.1, dist)) + 4.0
		_:
			deg = rad_to_deg(atan2(1.4, dist)) + 6.0
	return dir.rotated(Vector3.UP, side * deg_to_rad(minf(deg, 80.0)))





func dodge_tell(target: Node, id: = "") -> void :
	Vfx.popup(target.head_pos(0.5), "DODGED!", Color(0.75, 0.9, 1.0), 1.1, "dodge")
	if id != "":
		print("[dodge] %s jumped over %s" % [target.species, id])



func _announce_miss(user: Node, target: Node, mv: Dictionary) -> void :
	var delay: = 0.15
	var dist: float = user.global_position.distance_to(target.global_position)
	match String(mv.kind):
		"projectile":
			delay = dist / float(mv.get("speed", 12.0))
		"dash":
			delay = minf(dist, float(mv.get("range", 3.0))) / float(mv.get("speed", 12.0))
		"beam", "aoe_target":
			delay = float(mv.get("windup", 0.6)) + 0.1
	await Battle.fight_timer(delay).timeout
	if is_instance_valid(target) and target.alive():
		Vfx.popup(target.global_position + Vector3(0, 0.5, 0), "Miss!", Color(0.75, 0.85, 1.0), 1.0, "miss")
		move_missed.emit(user, target, mv)
		print("[acc] %s missed %s" % [mv.id, target.species])



func _stagger_after(user: Node, mv: Dictionary) -> void :
	var prep: = Dex.prepare_time(mv)
	var delay: = prep + float(mv.get("windup", 0.0)) + float(mv.get("duration", 0.0)) + 0.25
	if mv.get("kind", "") == "dash":
		delay = prep + float(mv.get("range", 3.0)) / float(mv.get("speed", 12.0)) + 0.1
	await Battle.fight_timer(delay).timeout
	if is_instance_valid(user) and user.alive():
		user.stagger()







func expected_damage(user: Node, target: Node, mv: Dictionary) -> float:
	if not is_instance_valid(user) or not is_instance_valid(target) or not target.alive():
		return 0.0
	var power: = float(mv.get("power", 0.0))
	if power <= 0.0:
		return 0.0
	var eff: = Dex.effectiveness(String(mv.get("type", "")), target.types)
	if eff <= 0.0:
		return 0.0



	if is_instance_valid(target.combat):
		if String(mv.get("kind", "")) == "dash" and (target.combat.is_diving() or target.combat.is_airborne()):
			if target.combat.is_diving():
				return 0.0


			var lift: float = user.combat.jump_height if user.combat.can_jump() else user.combat.air_h
			if target.combat.air_h - lift >= user.combat.dash_reach():
				return 0.0
		if String(mv.get("kind", "")) == "aoe_self" and String(mv.get("type", "")) == "ground" and target.combat.is_airborne():
			return 0.0
	var physical: bool = mv.get("category", "") == "physical"
	var a: float = user.stat("atk" if physical else "spa")
	var d: float = target.stat("def" if physical else "spd")
	var hits: = float(mv.get("hits", mv.get("count", 1)))
	var base: float = ((2.0 * float(user.level) / 5.0 + 2.0) * power * a / maxf(d, 1.0)) / 50.0 + 2.0
	var stab: = 1.5 if mv.get("type") in user.types else 1.0
	return base * hits * stab * eff * 0.925 * hit_chance(user, mv)



func hit_chance(user: Node, mv: Dictionary) -> float:
	var acc: = float(mv.get("accuracy", 0.0))
	if acc <= 0.0 or not String(mv.get("kind", "")) in MISSABLE:
		return 1.0
	return clampf(acc * accuracy_scale * _acc_mult(int(user.stages.get("acc", 0))) / 100.0, 0.0, 1.0)


func hit(user: Node, target: Node, mv: Dictionary, dir: Vector3, power_scale: = 1.0) -> void :
	if Battle.online_guest:
		return
	if Battle.pause_for_evolution:
		return
	if not is_instance_valid(target) or not target.alive() or not is_instance_valid(user):
		return

	var head: Vector3 = target.global_position + Vector3(0, 0.5, 0)
	if target.evasion_t > 0.0 and randf() < target.evasion:
		Vfx.popup(head, "Miss!", Color(0.9, 0.9, 1.0), 1.0, "miss")
		return
	_play_hit_anim(user, target, mv)
	var eff: = Dex.effectiveness(mv.type, target.types)
	var power: = float(mv.get("power", 0)) * power_scale
	var info: = {"move": mv.id, "damage": 0, "eff": eff}
	if power > 0.0:
		if eff == 0.0:
			Vfx.popup(head, "No effect...", Color(0.7, 0.7, 0.7))
			hit_landed.emit(user, target, info)
			return
		var physical: bool = mv.category == "physical"
		var crit_stage: int = int(mv.get("crit", 0)) + int(user.crit_stage)
		var crit: bool = debug_force_crit or randf() < StatCalc.crit_chance(crit_stage)
		var ak: = "atk" if physical else "spa"
		var dk: = "def" if physical else "spd"
		var a: float = user.crit_stat(ak, true) if crit else user.stat(ak)
		var d: float = target.crit_stat(dk, false) if crit else target.stat(dk)
		var lv: = float(user.level)
		var base: float = ((2.0 * lv / 5.0 + 2.0) * power * a / maxf(d, 1.0)) / 50.0 + 2.0
		var stab: = 1.5 if mv.type in user.types else 1.0
		var dmg: = maxi(1, int(base * stab * eff * (StatCalc.CRIT_MULT if crit else 1.0) * randf_range(0.85, 1.0)))
		info.damage = dmg
		info["crit"] = crit
		var hp_before: int = target.hp
		target.last_hit_by = user
		target.take_damage(dmg, dir, float(mv.get("knockback", 4.0)))
		if dmg >= hp_before:
			knocked_out.emit(user, target)

		var col: = Color(1, 0.75, 0.15) if eff > 1.0 else (Color(0.55, 0.58, 0.66) if eff < 1.0 else Color(0.9, 0.25, 0.22))
		if crit:
			col = Color(1, 0.45, 0.25)
		Vfx.popup(head, str(dmg), col, 1.5 if crit else 1.0, "damage")
		if crit:
			Vfx.popup(head + Vector3(0, 0.35, 0), "CRITICAL!", Color(1, 0.55, 0.3), 1.0, "crit")
			Vfx.shake(0.25)
		if eff > 1.0:
			Vfx.popup(head + Vector3(0, -0.35, 0), "SUPER EFFECTIVE!", Color(1, 0.8, 0.2), 1.0, "super", 2)
		elif eff < 1.0:
			Vfx.popup(head + Vector3(0, -0.35, 0), "Not very effective", Color(0.7, 0.7, 0.8), 1.0, "weak")
		if _legacy_fx(mv):
			Vfx.burst(target.global_position + Vector3(0, 0.6, 0), Dex.type_color(mv.type), 12, 0.35, 3.5)
	var ef = mv.get("effect")
	if ef is Dictionary and target.alive() and randf() < float(ef.get("chance", 0.0)):
		if ef.has("stat"):
			_change_stage(user if ef.get("self", false) else target, String(ef.stat), int(ef.stages))
			if ef.get("self", false) and String(mv.get("fx", "")) == "steel_claw":
				Vfx.steel_flash(user)
		else:
			var st: String = ef.status
			if STATUS_IMMUNE.get(st, "") in target.types:
				Vfx.popup(head + Vector3(0, 0.35, 0), "Immune to %s" % st, Color(0.8, 0.8, 0.8))
			elif target.apply_status(st, user):
				Vfx.popup(head + Vector3(0, 0.35, 0), STATUS_WORDS.get(st, st.to_upper() + "!"), _status_color(st), 1.0, "status")
				info["status"] = st
				if st == "confusion" and _legacy_fx(mv):
					Vfx.confuse_orbit(target)
	hit_landed.emit(user, target, info)


const STATUS_WORDS: = {"burn": "BURNED!", "poison": "POISONED!", "paralysis": "PARALYZED!", "sleep": "ASLEEP!", 
	"leech": "SEEDED!", "flinch": "FLINCHED!", "confusion": "CONFUSED!"}


func _status_color(st: String) -> Color:
	return {"burn": Dex.type_color("fire"), "poison": Dex.type_color("poison"), "paralysis": Dex.type_color("electric"), 
		"sleep": Color(0.7, 0.75, 1.0), "leech": Dex.type_color("grass"), "flinch": Color(1, 1, 1), 
		"confusion": Dex.type_color("psychic")}.get(st, Color.WHITE)



func _acc_mult(stage: int) -> float:
	return (3.0 + stage) / 3.0 if stage >= 0 else 3.0 / (3.0 - stage)



func _roll_magnitude(table: Array) -> Array:
	var total: = 0.0
	for row in table:
		total += float(row[2])
	var r: = randf() * total
	for row in table:
		r -= float(row[2])
		if r <= 0.0:
			return row
	return table[-1]


func _change_stage(c: Node, stat_k: String, delta_s: int) -> void :
	if delta_s == 0:
		return
	var cur: int = c.stages.get(stat_k, 0)
	var nv: = clampi(cur + delta_s, -6, 6)
	var name: String = STAT_NAMES.get(stat_k, stat_k)
	var head: Vector3 = c.global_position + Vector3(0, 0.15, 0)
	if nv == cur:
		Vfx.popup(head, "%s won't go any %s!" % [name, "higher" if delta_s > 0 else "lower"], Color(0.8, 0.8, 0.8))
		return
	c.stages[stat_k] = nv
	Audio.play_at("sfx/battle/stat_up" if delta_s > 0 else "sfx/battle/stat_down", c.global_position)
	Vfx.popup(head, name.to_upper(), Color.WHITE, 1.0, "stat_up" if delta_s > 0 else "stat_down", absi(nv - cur))
	play_stat_fx(c, stat_k, delta_s > 0)






func _play_cast_anim(user: Node, mv: Dictionary) -> void :
	var roles: = fx_roles(mv)
	if not roles.is_empty():
		var role: = _role(roles, "user")
		if not role.is_empty():
			var h: float = user.look_height() if user.has_method("look_height") else 1.0
			Vfx.pmd_fx(String(role.fx), user.global_position + Vector3(0, h * 0.4, 0), user.aim_dir(), role)
		return
	var anim: = String(mv.get("anim", ""))
	if anim == "" or String(mv.get("anim_at", "target")) != "user":
		return
	var h: float = user.look_height() if user.has_method("look_height") else 1.0
	Vfx.flipbook(anim, user.global_position + Vector3(0, h * 0.4, 0), h, String(mv.get("type", "normal")))



func _play_hit_anim(user: Node, target: Node, mv: Dictionary) -> void :
	var roles: = fx_roles(mv)
	var role: = _role(roles, "hit")

	var anim: = String(mv.get("anim", ""))
	var pack: = _legacy_fx(mv) and anim != "" and String(mv.get("anim_at", "target")) == "target"
	if role.is_empty() and not pack:
		return
	var uk: = user.get_instance_id()
	var key: = "%d:%d" % [uk, target.get_instance_id()]
	var gen: = int(_cast_gen.get(uk, 0))
	if int(_anim_played.get(key, -1)) == gen:
		return
	_anim_played[key] = gen
	var h: float = target.look_height() if target.has_method("look_height") else 1.0
	var at: Vector3 = target.global_position + Vector3(0, h * 0.4, 0)
	if not role.is_empty():
		Vfx.pmd_fx(String(role.fx), at, target.global_position - user.global_position, role)
	else:
		Vfx.flipbook(anim, at, h, String(mv.get("type", "normal")))




func play_status_fx(target: Node3D, status: String, at_head: = false) -> void :
	var role: = status_role(status)
	if role.is_empty():
		return
	var h: float = target.look_height() if target.has_method("look_height") else 1.0
	var at: Vector3 = target.global_position + Vector3(0, (h + 0.2) if at_head else h * 0.4, 0)
	Vfx.pmd_fx(String(role.fx), at, _aim(target), role)



func play_stat_fx(target: Node3D, stat_k: String, up: bool) -> void :
	var role: = stat_role(stat_k, up)
	if role.is_empty():
		return
	var h: float = target.look_height() if target.has_method("look_height") else 1.0
	Vfx.pmd_fx(String(role.fx), target.global_position + Vector3(0, h * 0.4, 0), _aim(target), role)



func _aim(target: Node3D) -> Vector3:
	return target.aim_dir() if target.has_method("aim_dir") else Vector3.FORWARD


func _in_cone(user: Node, t: Node, dir: Vector3, r: float, half_angle: float) -> bool:
	var to: Vector3 = t.global_position - user.global_position
	to.y = 0.0
	var d: = to.length()
	if d > r + 0.4:
		return false
	return d < 0.6 or dir.angle_to(to / d) <= half_angle


func _arc(user: Node, mv: Dictionary, dir: Vector3, miss: Node = null) -> void :
	var r: = float(mv.get("range", 1.8))
	var half: = deg_to_rad(float(mv.get("angle", 90))) / 2.0
	var steel: = String(mv.get("fx", "")) == "steel_claw"
	var legacy: = _legacy_fx(mv)


	var reach: float = minf(r * 0.7, 1.2)
	var at: Vector3 = user.global_position + dir * reach + Vector3(0, 0.7, 0)
	if not steel and legacy:
		Vfx.slash(at, Dex.type_color(mv.type))
	var drew: = false
	var hit_count: = 0
	for t in targets_of(user):
		if t != miss and _in_cone(user, t, dir, r, half):
			var to: Vector3 = t.global_position - user.global_position
			to.y = 0.0
			var d: Vector3 = to.normalized() if to.length() > 0.01 else dir
			if steel and legacy:

				Vfx.steel_claw(t.global_position + Vector3(0, 0.45, 0), d)
				Vfx.steel_glint(t.global_position + Vector3(0, 0.45, 0))
				drew = true
			hit(user, t, mv, d)
			hit_count += 1
	if steel and legacy and not drew:
		Vfx.steel_claw(user.global_position + dir * reach + Vector3(0, 0.45, 0), dir)
	elif not _role(fx_roles(mv), "tip").is_empty() or hit_count == 0:


		var h: float = user.look_height() if user.has_method("look_height") else 1.0
		play_reach_fx(user, mv, user.global_position + dir * reach + Vector3(0, h * 0.4, 0), dir)





func play_reach_fx(user: Node, mv: Dictionary, at: Vector3, aim: Vector3) -> void :
	var roles: = fx_roles(mv)
	var role: = _role(roles, "tip")
	if role.is_empty():
		role = _role(roles, "hit")
	if role.is_empty():
		return
	Vfx.pmd_fx(String(role.fx), at, aim, role)



func play_dash_reach_fx(user: Node, mv: Dictionary, dir: Vector3) -> void :
	if not is_instance_valid(user):
		return
	var h: float = user.look_height() if user.has_method("look_height") else 1.0
	play_reach_fx(user, mv, user.global_position + dir * 0.6 + Vector3(0, h * 0.4, 0), dir)






func _whip(user: Node, mv: Dictionary, dir: Vector3, miss: Node = null) -> void :
	var reach: = Dex.whip_reach(user.species, mv)
	var tips: = Dex.whip_tips(user.species, mv)
	var tip_r: = float(mv.get("tip_radius", 0.6))
	var spread: = float(mv.get("spread", 0.0))
	var col: = Dex.type_color(mv.type)
	var h: float = user.look_height() if user.has_method("look_height") else 1.0


	var origin: Vector3 = user.global_position + Vector3(0, h * 0.4, 0)
	var already: = {}
	for i in tips:
		var tipdir: Vector3 = dir.rotated(Vector3.UP, deg_to_rad(spread * (i - (tips - 1) / 2.0)))
		var tip: Vector3 = user.global_position + tipdir * reach + Vector3(0, h * 0.4, 0)
		_vine(origin, tip)

		play_reach_fx(user, mv, tip, tipdir)
		if _legacy_fx(mv):
			Vfx.burst(tip, col, 6, 0.3, 2.0, 0.1)
		for t in targets_of(user):
			if t == miss or already.has(t.get_instance_id()):
				continue
			var to_tip: Vector3 = t.global_position - tip
			to_tip.y = 0.0
			if to_tip.length() > tip_r:
				continue
			already[t.get_instance_id()] = true
			var to: Vector3 = t.global_position - user.global_position
			to.y = 0.0
			hit(user, t, mv, to.normalized() if to.length() > 0.01 else dir)





func _vine(from: Vector3, to: Vector3) -> Node3D:
	var d: = to - from
	var len: = d.length()
	if len < 0.01:
		return null
	var holder: = Node3D.new()
	root().add_child(holder)
	holder.global_position = from
	holder.look_at(to, Vector3.UP)


	for part in [{"w": 0.06, "y": 0.0, "col": Color(0.08, 0.32, 0.08)}, 
			{"w": 0.025, "y": 0.04, "col": Color(0.5, 0.8, 0.32)}]:
		var mi: = Vfx.flat_box(Vector3(part.w, part.w, len), part.col)
		holder.add_child(mi)
		mi.position = Vector3(0.0, part.y, - len * 0.5)
	holder.scale = Vector3(1, 1, 0.04)
	var tw: = Battle.fight_tween(holder)
	tw.tween_property(holder, "scale:z", 1.0, 0.1)
	tw.tween_property(holder, "scale:z", 0.03, 0.15)
	tw.tween_callback(holder.queue_free)
	return holder


func _multi_arc(user: Node, mv: Dictionary, miss: Node = null) -> void :
	for i in int(mv.get("hits", 3)):
		if not is_instance_valid(user) or not user.can_act():
			return
		var d: Vector3 = user.aim_dir()
		if is_instance_valid(miss):
			d = _miss_dir(user, miss, mv, d)
		_arc(user, mv, d, miss)
		await Battle.fight_timer(float(mv.get("interval", 0.2))).timeout


func _projectiles(user: Node, mv: Dictionary, dir: Vector3, homing: bool, miss: Node = null) -> void :
	var n: = int(mv.get("count", 1))
	var spread: = deg_to_rad(float(mv.get("spread", 0.0)))
	var roles: = fx_roles(mv)
	var legacy: = _legacy_fx(mv)
	var travel: = _role(roles, "travel") if not roles.is_empty() else {}
	for i in n:
		if not is_instance_valid(user):
			return
		var d: = dir
		if homing:
			d = dir.rotated(Vector3.UP, randf_range(-1.3, 1.3))
		elif n > 1:
			d = dir.rotated(Vector3.UP, lerpf( - spread / 2.0, spread / 2.0, float(i) / (n - 1)))
		var p: = Node3D.new()
		p.set_script(ProjectileScript)
		p.setup(user, mv, d, homing)
		p.miss_target = miss
		p.hide_body = not travel.is_empty()
		p.legacy_fx = legacy
		root().add_child(p)
		var hh: float = user.look_height() if user.has_method("look_height") else 1.0
		p.global_position = user.global_position + Vector3(0, hh * 0.4, 0) + d * 0.5
		if not travel.is_empty():
			Vfx.pmd_fx_travel(p, String(travel.fx), d, travel)
		elif String(mv.get("anim", "")) != "" and String(mv.get("anim_at", "")) == "travel":
			var h: float = user.look_height() if user.has_method("look_height") else 1.0
			Vfx.flipbook_travel(p, String(mv.get("anim", "")), h, String(mv.get("type", "normal")))
		if homing:
			await Battle.fight_timer(0.08).timeout


func _stream(user: Node, mv: Dictionary, dir: Vector3) -> void :
	var dur: = float(mv.get("duration", 1.0))
	var tick: = float(mv.get("tick", 0.15))
	var r: = float(mv.get("range", 5.0))
	var half: = deg_to_rad(float(mv.get("angle", 35))) / 2.0
	var col: = Dex.type_color(mv.type)
	user.root_t = maxf(user.root_t, dur)
	var once: = bool(mv.get("once", false))
	var already: = {}
	var em: GPUParticles3D = null
	if _legacy_fx(mv):
		em = Vfx.emitter(col, 70, 0.4, r / 0.4, 0.18, rad_to_deg(half), Vector3(0, 0, -1), Vector3.ZERO)
		root().add_child(em)
		em.global_position = user.global_position + Vector3(0, 0.7, 0)
		em.look_at(em.global_position + dir, Vector3.UP)
		em.emitting = true
	var stream: Dictionary = fx_roles(mv).get("stream", {})
	if not stream.is_empty():
		_stream_puffs(user, mv, dir, r, half, stream)
	var t: = 0.0
	while t < dur:
		if not is_instance_valid(user) or not user.can_act():
			break
		if em != null:
			em.global_position = user.global_position + Vector3(0, 0.7, 0) + dir * 0.4
		for tg in targets_of(user):
			if _in_cone(user, tg, dir, r, half):
				if once:
					if already.has(tg):
						continue
					already[tg] = true
				hit(user, tg, mv, dir)
		await Battle.fight_timer(tick).timeout
		t += tick


	if is_instance_valid(em):
		em.emitting = false
		Battle.fight_timer(0.6).timeout.connect(em.queue_free)






func _stream_puffs(user: Node, mv: Dictionary, dir: Vector3, r: float, half: float, cfg: Dictionary) -> void :
	var fx: = String(cfg.get("fx", ""))
	if fx == "":
		return
	var every: = maxf(float(cfg.get("every", 0.03)), 0.02)
	var travel: = maxf(float(cfg.get("travel", 0.25)), 0.05)
	var spread: = clampf(float(cfg.get("spread", 1.0)), 0.0, 1.0)
	var dur: = float(mv.get("duration", 1.0))
	var t: = 0.0
	while t < dur and is_instance_valid(user) and user.can_act():
		var mouth: Vector3 = user.global_position + Vector3(0, 0.7, 0) + dir * 0.35
		var d: Vector3 = dir.rotated(Vector3.UP, randf_range( - half * spread, half * spread))
		var puff: Node3D = Vfx.pmd_fx(fx, mouth, d, cfg)
		if puff != null:
			var tw: = Battle.fight_tween(puff)
			tw.tween_property(puff, "global_position", mouth + d * r * randf_range(0.8, 1.0), travel)
			var spr: = puff.get_node_or_null("Sprite")
			if spr != null:
				tw.parallel().tween_property(spr, "modulate:a", 0.0, travel * 0.4).set_delay(travel * 0.6)
		await Battle.fight_timer(every).timeout
		t += every


func _beam(user: Node, mv: Dictionary, dir: Vector3, miss: Node = null) -> void :
	var windup: = float(mv.get("windup", 0.6))
	var r: = float(mv.get("range", 14.0))
	var w: = float(mv.get("width", 0.8))
	var col: = Dex.type_color(mv.type)
	user.root_t = windup + 0.25 + float(mv.get("root", 1.0))
	var start: Vector3 = user.global_position + Vector3(0, 0.7, 0)

	var tele: = Vfx.flat_box(Vector3(w * 0.5, 0.02, r), Color(1, 0.3, 0.3, 0.35))
	root().add_child(tele)
	tele.global_position = Vector3(start.x, 0.03, start.z) + dir * r / 2.0
	tele.look_at(tele.global_position + dir, Vector3.UP)
	for i in 3:
		Vfx.burst(start, col, 10, 0.3, -2.5, 0.1, 180.0, Vector3.UP, Vector3.ZERO, 0.9)
		await Battle.fight_timer(windup / 3.0).timeout
	tele.queue_free()
	if not is_instance_valid(user) or not user.alive():
		return
	start = user.global_position + Vector3(0, 0.7, 0)
	Audio.play_at("sfx/moves/beam_fire", user.global_position)


	var reach: = r
	for t in targets_of(user):
		if t == miss:
			continue
		var p: Vector3 = t.global_position + Vector3(0, 0.6, 0)
		var along: = (p - start).dot(dir)
		if along > -0.5 and along < r and (start + dir * along).distance_to(p) < w / 2.0 + 0.5:
			reach = minf(reach, along)
			hit(user, t, mv, dir)

	if VfxBeam.aim(mv.id, start, dir, reach) == null:
		var beam: = MeshInstance3D.new()
		var cm: = CylinderMesh.new()
		cm.top_radius = w / 2.0
		cm.bottom_radius = w / 2.0
		cm.height = r
		cm.radial_segments = 12
		cm.material = Vfx.glow_mat(col.lightened(0.5))
		beam.mesh = cm
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root().add_child(beam)
		beam.global_position = start + dir * r / 2.0
		beam.look_at(beam.global_position + dir, Vector3.UP)
		beam.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		var tw: = Battle.fight_tween(beam)
		tw.tween_property(beam, "scale", Vector3(0.05, 1.0, 0.05), 0.35).set_delay(0.12)
		tw.tween_callback(beam.queue_free)
	Vfx.shake(0.25)



func magnitude_windup(level: int) -> float:
	return 0.9 + (clampf(float(level), 4.0, 10.0) - 4.0) / 6.0 * 0.5


func _aoe_self(user: Node, mv: Dictionary) -> void :
	var quake: = String(mv.get("fx", "")) == "quake"
	var rad: = float(mv.get("radius", 4.0))
	var col: = Dex.type_color(mv.type)
	var windup: = float(mv.get("windup", 0.4))
	var mag: = int(mv.get("mag_level", 7))
	if quake:
		windup = magnitude_windup(mag)
	user.root_t = maxf(user.root_t, windup + 0.2)
	if quake:

		var tele: = Vfx.magnitude_telegraph(user.global_position, rad, mag, windup)
		var tau_t: = 0.0
		while tau_t < windup:
			if not is_instance_valid(user) or not user.alive():
				if is_instance_valid(tele):
					tele.queue_free()
				return
			var f: = tau_t / maxf(windup, 0.01)
			Vfx.shake(0.06 + 0.3 * f)
			var a: = randf() * TAU
			Vfx.burst(user.global_position + Vector3(cos(a), 0, sin(a)) * rad * 0.9 + Vector3(0, 0.1, 0), 
				Color(0.5, 0.42, 0.32), 5, 0.4, 1.8, 0.12, 90.0, Vector3.UP, Vector3(0, -4, 0), 0.2)
			await Battle.fight_timer(0.15).timeout
			tau_t += 0.15
		if is_instance_valid(tele):
			tele.queue_free()
	else:
		var tele: = Vfx.disc(rad, Color(1, 0.3, 0.3, 0.25))
		root().add_child(tele)
		tele.global_position = user.global_position + Vector3(0, 0.03, 0)
		await Battle.fight_timer(windup).timeout
		tele.queue_free()
	if not is_instance_valid(user) or not user.alive():
		return
	var c: Vector3 = user.global_position
	Vfx.shockwave(c, rad, col)
	Vfx.shake(0.45)
	if _legacy_fx(mv):
		Vfx.burst(c + Vector3(0, 0.1, 0), col, 40, 0.6, 5.0, 0.16, 80.0, Vector3.UP, Vector3(0, -9, 0), rad * 0.6)
	var ground: = String(mv.get("type", "")) == "ground"
	for t in targets_of(user):


		if ground and t.is_airborne():
			dodge_tell(t, mv.id)
			continue
		var to: Vector3 = t.global_position - c
		to.y = 0.0
		if to.length() <= rad:
			hit(user, t, mv, to.normalized() if to.length() > 0.01 else Vector3.BACK)



func _aim_point(user: Node, dir: Vector3, r: float, miss: Node = null, miss_offset: = 3.0) -> Vector3:
	if is_instance_valid(user.opponent) and user.opponent.alive():
		var p: Vector3 = user.opponent.global_position
		if user.global_position.distance_to(p) <= r:
			if is_instance_valid(miss):
				var side: = Vector3( - dir.z, 0.0, dir.x) * (1.0 if randf() < 0.5 else -1.0)
				p += side * miss_offset + dir * randf_range(-0.8, 0.8)
			return Vector3(p.x, 0.0, p.z)
	var q: Vector3 = user.global_position + dir * r * 0.6
	return Vector3(q.x, 0.0, q.z)


func _aoe_target(user: Node, mv: Dictionary, dir: Vector3, miss: Node = null) -> void :
	var windup: = float(mv.get("windup", 1.0))
	var rad: = float(mv.get("radius", 2.0))
	var col: = Dex.type_color(mv.type)
	var p: = _aim_point(user, dir, float(mv.get("range", 10.0)), miss, rad + randf_range(0.9, 1.5))
	var tele: = Vfx.disc(rad, Color(col.r, col.g, col.b, 0.3))
	root().add_child(tele)
	tele.global_position = p + Vector3(0, 0.03, 0)
	var pulse: = Battle.fight_tween(tele).set_loops()
	pulse.tween_property(tele, "scale", Vector3(0.85, 1, 0.85), 0.15)
	pulse.tween_property(tele, "scale", Vector3.ONE, 0.15)
	await Battle.fight_timer(windup).timeout
	tele.queue_free()
	if not is_instance_valid(user):
		return
	var fx: = String(mv.get("fx", ""))
	if fx == "rock_drop":
		_rock_tomb(user, mv, p, rad)
		return
	if fx == "psy_rings":
		_psy_strike(user, mv, p, rad)
		return
	if float(mv.get("power", 0)) > 0.0:
		if VfxBeam.sky(mv.id, p) == null:
			Vfx.bolt(p, col)
		Vfx.shake(0.3)
	elif _legacy_fx(mv):
		Vfx.burst(p + Vector3(0, 0.4, 0), col, 50, 1.2, 1.5, 0.14, 180.0, Vector3.UP, Vector3(0, -0.5, 0), rad * 0.8)
	for t in targets_of(user):
		var to: Vector3 = t.global_position - p
		to.y = 0.0
		if to.length() <= rad:
			hit(user, t, mv, to.normalized() if to.length() > 0.01 else dir)



func _body_radius(c: Node) -> float:
	if is_instance_valid(c):
		var cs: = c.get_node_or_null("CollisionShape3D")
		if cs != null and cs.shape is CapsuleShape3D:
			return (cs.shape as CapsuleShape3D).radius
	return 0.35




func _rock_tomb(user: Node, mv: Dictionary, p: Vector3, rad: float) -> void :
	var trap: = float(mv.get("trap", 2.0))
	var avoid: Array = []
	for f in [user, user.opponent]:
		if is_instance_valid(f):
			avoid.append({"pos": f.global_position, "r": _body_radius(f)})
	Vfx.rock_drop(p, avoid, trap)
	await Battle.fight_timer(0.35).timeout
	if not is_instance_valid(user):
		return
	for t in targets_of(user):
		var to: Vector3 = t.global_position - p
		to.y = 0.0
		if to.length() <= rad:
			hit(user, t, mv, to.normalized() if to.length() > 0.01 else Vector3.BACK)
			if is_instance_valid(t) and t.alive():
				t.combat.entomb(trap)
				Vfx.popup(t.head_pos(0.4), "Trapped!", Dex.type_color("rock"), 1.0, "status")



func _psy_strike(user: Node, mv: Dictionary, p: Vector3, rad: float) -> void :
	Vfx.shake(0.15)
	for t in targets_of(user):
		var to: Vector3 = t.global_position - p
		to.y = 0.0
		if to.length() <= rad:
			if _legacy_fx(mv):
				Vfx.psy_rings(t)
			Vfx.sprite_wobble(t.sprite)
			hit(user, t, mv, to.normalized() if to.length() > 0.01 else Vector3.BACK)


func _zone(user: Node, mv: Dictionary, dir: Vector3, miss: Node = null) -> void :
	var rad: = float(mv.get("radius", 2.0))
	var dur: = float(mv.get("duration", 4.0))
	var tick: = float(mv.get("tick", 0.5))
	var col: = Dex.type_color(mv.type)
	var p: = _aim_point(user, dir, float(mv.get("range", 7.0)), miss, rad + randf_range(0.9, 1.5))
	var disc: = Vfx.disc(rad, Color(col.r, col.g, col.b, 0.18))
	root().add_child(disc)
	disc.global_position = p + Vector3(0, 0.03, 0)
	var cloud: GPUParticles3D = null
	if _legacy_fx(mv):
		cloud = Vfx.emitter(col, 60, 1.6, 0.4, 0.2, 180.0, Vector3.UP, Vector3(0, 0.3, 0), rad * 0.9)
		root().add_child(cloud)
		cloud.global_position = p + Vector3(0, 0.6, 0)
		cloud.emitting = true
	var t: = 0.0
	while t < dur and is_instance_valid(user):
		for tg in targets_of(user):
			var to: Vector3 = tg.global_position - p
			to.y = 0.0
			if to.length() <= rad:
				hit(user, tg, mv, Vector3.ZERO)
		await Battle.fight_timer(tick).timeout
		t += tick

	if is_instance_valid(cloud):
		cloud.emitting = false
	if is_instance_valid(disc):
		Battle.fight_tween(disc).tween_property(disc, "scale", Vector3(0.01, 1, 0.01), 0.4)
	Battle.fight_timer(1.8).timeout.connect( func():
		if is_instance_valid(cloud):
			cloud.queue_free()
		if is_instance_valid(disc):
			disc.queue_free())


func _debuff(user: Node, mv: Dictionary) -> void :
	var rad: = float(mv.get("radius", 6.0))
	Vfx.shockwave(user.global_position, rad, Dex.type_color(mv.type), 0.15)
	for t in targets_of(user):
		if t.global_position.distance_to(user.global_position) <= rad:
			_change_stage(t, String(mv.stat), int(mv.stages))


func _clones(user: Node, mv: Dictionary) -> void :
	var dur: = float(mv.get("duration", 5.0))
	user.evasion_t = dur
	user.evasion = float(mv.get("evasion", 0.4))
	var spr: Sprite3D = user.sprite
	for i in int(mv.get("count", 2)):
		var c: Sprite3D = spr.duplicate()
		c.modulate = Color(spr.modulate, 0.55)
		c.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		user.add_child(c)
		var side: = -1.0 if i % 2 == 0 else 1.0
		var a: = Vector3(side * 1.1, 0, 0.2)
		var b: = Vector3(side * 0.7, 0, -0.5)
		c.position = a
		var tw: = Battle.fight_tween(c).set_loops()
		tw.tween_property(c, "position", b, 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_property(c, "position", a, 0.35).set_trans(Tween.TRANS_SINE)
		Battle.fight_timer(dur).timeout.connect(c.queue_free)
