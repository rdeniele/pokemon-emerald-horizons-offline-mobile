class_name Creature
extends CharacterBody3D



signal fainted(creature: Creature)

enum Behaviour{PASSIVE, FLEE, AGGRESSIVE}


enum Mode{WANDER, BATTLE_AI, PLAYER, FAINTED, IDLE, FOLLOW, DUMMY, REMOTE, PUPPET}


enum AllyMode{ATTACK, DEFEND, SUPPORT}
const ALLY_MODE_NAMES: = ["ATTACK", "DEFEND", "SUPPORT"]
const ALLY_MODE_COLORS: = [Color(1.0, 0.45, 0.35), Color(0.45, 0.7, 1.0), Color(0.5, 0.95, 0.6)]

const Dex: = preload("res://scripts/dex.gd")
const StatCalc: = preload("res://scripts/stats/stat_calc.gd")
const PokemonSprites: = preload("res://scripts/pokemon_sprites.gd")
const MonScript: = preload("res://scripts/stats/mon.gd")
const GRAVITY: = 20.0

const SQUASH_RECOVER: = 2.6




const BOB_HOVER: = 0.11
const BOB_FLY: = 0.16
const BOB_HOVER_SPEED: = 3.6
const BOB_FLY_SPEED: = 4.6


const PP_REGEN: = 0.2


const PMD_FAINT_TIME: = 0.3
const PMD_FAINT_SCALE: = Vector3(1.15, 0.55, 1.15)
const PMD_FAINT_TINT: = Color(0.55, 0.55, 0.55)
const HOP_TAKEOFF_HOLD: = 0.06
const HOP_LAND_HOLD: = 0.08

@export var species: = "Critter"

@export var sprite_texture: Texture2D
@export var level: = 3
@export var behaviour: Behaviour = Behaviour.PASSIVE
@export var move_speed: = 2.5

@export var trainer_owned: = false
@export var owner_name: = ""
@export var talk_lines: PackedStringArray = PackedStringArray()

var is_wild: = true

var static_uid: = ""



var mon: RefCounted
var max_hp: = 0
var hp: = 0
var mode: Mode = Mode.WANDER:
	set(value):
		if mode == Mode.FAINTED and value != Mode.FAINTED:
			_pmd_faint_reset()
		mode = value
var facing: = Vector3(0, 0, 1)
var peace_timer: = 0.0



var combat: Combatant

var immortal: = false

var evolving: = false


var opponent: Creature:
	get:
		return combat.opponent
	set(value):
		combat.opponent = value
var types: Array:
	get:
		return combat.types
	set(value):
		combat.types = value
var stats: Dictionary:
	get:
		return combat.stats
	set(value):
		combat.stats = value
var stages: Dictionary:
	get:
		return combat.stages
	set(value):
		combat.stages = value
var moves: Array:
	get:
		return combat.moves
	set(value):
		combat.moves = value
var move_cd: Dictionary:
	get:
		return combat.move_cd
	set(value):
		combat.move_cd = value
var gcd_t: float:
	get:
		return combat.gcd_t
	set(value):
		combat.gcd_t = value
var sprinting: bool:
	get:
		return combat.sprinting
	set(value):
		combat.sprinting = value
var selected_move: String:
	get:
		return combat.selected_move
	set(value):
		combat.selected_move = value
var ai_uses_moves: bool:
	get:
		return combat.ai_uses_moves
	set(value):
		combat.ai_uses_moves = value
var ai_think_scale: float:
	get:
		return combat.ai_think_scale
	set(value):
		combat.ai_think_scale = value
var side: int:
	get:
		return combat.side
	set(value):
		combat.side = value
var pp_base: float:
	get:
		return combat.pp_base
	set(value):
		combat.pp_base = value
var pp_max: float:
	get:
		return combat.pp_max
	set(value):
		combat.pp_max = value
var stamina: float:
	get:
		return combat.stamina
	set(value):
		combat.stamina = value
var crit_stage: int:
	get:
		return combat.crit_stage
	set(value):
		combat.crit_stage = value
var stagger_t: float:
	get:
		return combat.stagger_t
	set(value):
		combat.stagger_t = value
var status: String:
	get:
		return combat.status
	set(value):
		combat.status = value
var status_t: float:
	get:
		return combat.status_t
	set(value):
		combat.status_t = value
var confusion_t: float:
	get:
		return combat.confusion_t
	set(value):
		combat.confusion_t = value
var leech_source: Creature:
	get:
		return combat.leech_source
	set(value):
		combat.leech_source = value
var stun_t: float:
	get:
		return combat.stun_t
	set(value):
		combat.stun_t = value
var root_t: float:
	get:
		return combat.root_t
	set(value):
		combat.root_t = value
var evasion_t: float:
	get:
		return combat.evasion_t
	set(value):
		combat.evasion_t = value
var evasion: float:
	get:
		return combat.evasion
	set(value):
		combat.evasion = value
var dummy_style: int:
	get:
		return combat.dummy_style
	set(value):
		combat.dummy_style = value
var dash_t: float:
	get:
		return combat.dash_t
	set(value):
		combat.dash_t = value
var dash_dir: Vector3:
	get:
		return combat.dash_dir
	set(value):
		combat.dash_dir = value
var dash_speed: float:
	get:
		return combat.dash_speed
	set(value):
		combat.dash_speed = value
var dash_move: Dictionary:
	get:
		return combat.dash_move
	set(value):
		combat.dash_move = value
var dash_miss: Node:
	get:
		return combat.dash_miss
	set(value):
		combat.dash_miss = value
var last_hit_by: Creature:
	get:
		return combat.last_hit_by
	set(value):
		combat.last_hit_by = value
var _status_tick: float:
	get:
		return combat._status_tick
	set(value):
		combat._status_tick = value

var _home: = Vector3.ZERO
var _wander_to: = Vector3.ZERO
var _wander_t: = 0.0
var _anim_t: = 0.0
var _sprint_dust_t: = 0.0


var _pmd_anim: = ""
var _pmd_t: = 0.0
var _pmd_oneshot: = false
var _pmd_hold: = -1
var _pmd_hold_dash: = false
var _pmd_hold_t: = 0.0

var _pmd_collapse_t: = -1.0


var _pmd_anchor: = Vector2.ZERO
var _pmd_walking: = false



var _pmd_hop_t: = -1.0
var _pmd_hop_land: = false
var _pmd_hop_was_air: = false
var _pmd_hop_prev_y: = 0.0

var squash: = 0.0


var _ground_y: = 0.0


var _strafe: = 1.0
var _talking: = false

var follow_slot: = 0

var _bob_phase: = randf() * TAU
var _bob_t_vis: = 0.0

var hopping: = false

@onready var sprite: Sprite3D = $Sprite3D
@onready var label: Label3D = $Label3D


func _ready() -> void :
	combat = Combatant.new(self)
	if mon:
		species = mon.species
		level = mon.level
		apply_species(false)
	else:
		apply_species(true)
	collision_mask |= 2
	_home = Vector3(position.x, 0.0, position.z)
	_wander_to = _home
	_strafe = 1.0 if randf() < 0.5 else -1.0
	if trainer_owned:
		add_to_group("npc")
		label.modulate = Color(1.0, 0.9, 0.6)
	elif is_wild:
		add_to_group("wild")
	else:
		combat.side = 0
		collision_layer = 0
		label.modulate = Color(0.6, 0.85, 1.0)
	_ground_y = global_position.y
	refresh_label()




func apply_species(full_heal: = true) -> void :
	if mon == null or mon.species != species or mon.level != level:
		mon = MonScript.create(species, level)
	mon.recalc()
	if full_heal:
		mon.heal_full()
	sync_from_mon()
	var sp: = Dex.species(species)
	if not sp.is_empty():
		combat.types = sp.get("types", ["normal"]).duplicate()
		combat.swimmer = bool(sp.get("swimmer", false))
		combat.fish = bool(sp.get("fish", false))
		if combat.moves.is_empty():
			combat.moves = mon.moves.duplicate() if not mon.moves.is_empty() else sp.get("moves", []).duplicate()
	apply_look()


var _look: = {}



func apply_look() -> void :
	if sprite == null:
		return
	_pmd_faint_reset()
	_look = PokemonSprites.apply(sprite, species)
	_pmd_anim = ""
	_pmd_hop_t = -1.0
	_pmd_hop_was_air = false
	_pmd_anchor = Vector2(0.0, float(_look.get("offset_y", 0.0)))
	_fit_look()
	if combat != null:
		combat.jump_height = Dex.jump_height(species)
		combat.jump_time = Combatant.jump_time_for(combat.jump_height)
		combat.locomotion = Dex.locomotion(species)
		var fh: = Dex.fly_height(species)
		if fh > 0.0:
			combat.fly_height = fh




func _fit_look() -> void :
	var vis: float = _look.get("visible_m", 1.0)
	label.position.y = vis + 0.4



func base_tint() -> Color:
	return _look.get("tint", Color.WHITE)



func look_height() -> float:
	return _look.get("visible_m", 1.0)






func ground_y() -> float:
	return _ground_y



func _float_ground() -> void :
	if not _battle().in_battle:
		_ground_y = _game().ground_y(Vector3(global_position.x, global_position.y + 3.0, global_position.z), _ground_y)



func head_pos(extra: = 0.0) -> Vector3:
	return global_position + Vector3(0, look_height() + extra, 0)



func may_start(mv: Dictionary) -> bool:
	return combat.may_start(mv)



func sync_from_mon() -> void :
	_pmd_faint_reset()
	for k in StatCalc.BATTLE_STATS:
		combat.stats[k] = int(mon.stats.get(k, 10))
	max_hp = mon.max_hp
	hp = clampi(mon.hp, 0, max_hp)
	combat.pp_base = mon.pp_base
	combat.pp_max = clampf(mon.pp, 0.0, combat.pp_base)
	combat.stamina = combat.pp_max
	combat.sync_status_from_mon()
	refresh_label()




func speed_factor() -> float:
	return combat.speed_factor()


func battle_move_speed() -> float:
	return combat.battle_move_speed()


func gain_evs_from(defeated: Node) -> Dictionary:
	return combat.gain_evs_from(defeated)


func min_move_cost() -> float:
	return combat.min_move_cost()


func out_of_pp() -> bool:
	return combat.out_of_pp()


func stagger() -> void :
	combat.stagger()


func restore_pp() -> void :
	combat.restore_pp()


func crit_stat(k: String, attacking: bool) -> float:
	return combat.crit_stat(k, attacking)


func stat(k: String) -> float:
	return combat.stat(k)


func alive() -> bool:
	return mode != Mode.FAINTED and is_inside_tree()


func can_act() -> bool:
	return combat.can_act()



func is_airborne() -> bool:
	return combat.is_airborne()




var npc_name: String:
	get:
		return "%s's %s" % [owner_name, species] if owner_name != "" else species


func prompt_verb() -> String:
	return "" if trainer_owned else "Battle!"




func prompt_anchor() -> Vector3:
	var h: = look_height() * (sprite.scale.y if sprite else 1.0)
	return global_position + Vector3(0, h + 0.85, 0)


func talk_to(player: Node3D) -> PackedStringArray:
	_talking = true
	var to: = player.global_position - global_position
	to.y = 0.0
	if to.length() > 0.01:
		facing = to.normalized()
	if not talk_lines.is_empty():
		return talk_lines
	var cry: = species.substr(0, 4)
	return PackedStringArray(["%s: %s! %s!" % [species, cry, cry.to_lower()], "It seems used to people. It belongs to %s." % (owner_name if owner_name != "" else "someone")])


func finish_talk() -> void :
	_talking = false



func _game():
	return get_node("/root/Game")


func _battle():
	return get_node("/root/Battle")


func _moves():
	return get_node("/root/Moves")


func _vfx():
	return get_node("/root/Vfx")


func _physics_process(delta: float) -> void :
	if mode != Mode.PLAYER and mode != Mode.BATTLE_AI and mode != Mode.REMOTE:
		combat.sprinting = false
	_float_bob(delta * combat.battle_speed())
	if mode == Mode.FAINTED:
		if not _pmd().is_empty():
			_pmd_tick(delta * combat.battle_speed())

		if combat.locomotion != "ground" and global_position.y > _ground_y + 0.01:
			global_position.y = maxf(global_position.y - Combatant.FAINT_FALL_SPEED * delta, _ground_y)
		return
	if mode == Mode.IDLE:
		velocity.x = 0.0
		velocity.z = 0.0
		if not _pmd().is_empty():
			_pmd_tick(delta * combat.battle_speed())

		if combat.floats():
			_float_ground()
			combat.hold_altitude(delta)
			move_and_slide()
		return
	if mode == Mode.PUPPET:



		var pcd: = delta * combat.battle_speed()
		if squash != 0.0:
			squash = move_toward(squash, 0.0, SQUASH_RECOVER * pcd)
			sprite.scale = Vector3(1.0 - squash * 0.5, 1.0 + squash, 1.0 - squash * 0.5)
		_animate(pcd, Vector2(velocity.x, velocity.z).length() > 0.1)
		return
	if evolving:
		velocity = Vector3.ZERO
		combat.dash_t = 0.0
		combat._lunge_t = 0.0
		return
	if _battle().pause_for_evolution and (mode == Mode.PLAYER or mode == Mode.BATTLE_AI or mode == Mode.REMOTE or mode == Mode.DUMMY):


		velocity = Vector3.ZERO
		return
	if hopping:

		velocity = Vector3.ZERO
		if not _pmd().is_empty():
			_pmd_tick(delta * combat.battle_speed())
		return
	combat.tick(delta)
	var bsp: = combat.battle_speed()
	var want: = Vector3.ZERO
	var speed: = move_speed
	match mode:
		Mode.WANDER:
			want = _wander_logic(delta)
		Mode.BATTLE_AI:

			want = combat.battle_ai(delta * bsp) + combat.arena_push()
			if want.length() > 1.0:
				want = want.normalized()
			speed = move_speed * 1.4 * (Combatant.SPRINT_MULT if combat.sprinting else 1.0)
		Mode.PLAYER:
			want = combat.player_input()
			speed = Combatant.BATTLE_MOVE_SPEED * (Combatant.SPRINT_MULT if combat.sprinting else 1.0)
		Mode.REMOTE:


			want = combat.apply_intent(combat.remote_intent)
			speed = Combatant.BATTLE_MOVE_SPEED * (Combatant.SPRINT_MULT if combat.sprinting else 1.0)
			combat.remote_intent.jump = false
			combat.remote_intent.slot = -1
		Mode.FOLLOW:
			want = _follow_logic(delta)

			speed = 1.0
		Mode.DUMMY:
			want = combat.dummy_logic()
			speed = 2.5
	combat.drive_velocity(delta, want, speed, mode == Mode.BATTLE_AI or mode == Mode.PLAYER or mode == Mode.REMOTE or mode == Mode.DUMMY)

	if combat.air_t <= 0.0 and not combat.floats():
		if is_on_floor():
			velocity.y = -0.5
		else:
			velocity.y -= GRAVITY * delta
	var prev: = global_position
	move_and_slide()
	global_position = combat.water_clamp(prev)
	combat.clamp_arena()
	if combat.floats():
		_float_ground()
	elif is_on_floor():
		_ground_y = global_position.y
	if combat.sprinting:
		_sprint_dust_t -= delta * bsp
		if _sprint_dust_t <= 0.0:
			_sprint_dust_t = 0.08
			var back: = Vector3.UP
			var horiz: = Vector3(velocity.x, 0.0, velocity.z)
			if horiz.length() > 0.01:
				back = - horiz.normalized()
			_vfx().burst(global_position + Vector3(0, 0.1, 0), Color(0.55, 0.48, 0.38), 7, 0.4, 1.2, 0.16, 50.0, back + Vector3.UP * 0.3)
	else:
		_sprint_dust_t = 0.0
	if squash != 0.0:
		squash = move_toward(squash, 0.0, SQUASH_RECOVER * delta * bsp)
		sprite.scale = Vector3(1.0 - squash * 0.5, 1.0 + squash, 1.0 - squash * 0.5)
	var cd: = delta * bsp
	_animate(cd, want.length() > 0.1 or combat._lunge_t > 0.0 or combat.dash_t > 0.0)
	_water_visual(cd, want.length() > 0.1)




func apply_status(s: String, source: Creature = null) -> bool:
	return combat.apply_status(s, source)


func clear_status() -> void :
	combat.clear_status()


func heal(amount: int) -> void :
	if mode == Mode.FAINTED:
		return
	hp = mini(hp + amount, max_hp)
	if mon:
		mon.hp = hp
	_vfx().popup(head_pos(0.9), "+%d" % amount, Color(0.5, 1.0, 0.5))
	refresh_label()




func _wander_logic(delta: float) -> Vector3:
	if _talking:
		return Vector3.ZERO
	var player: = get_tree().get_first_node_in_group("player") as Node3D
	if player and not trainer_owned and not _game().is_busy() and peace_timer <= 0.0:
		var to_p: = player.global_position - global_position
		to_p.y = 0.0
		var d: = to_p.length()

		if d < 1.1 and behaviour == Behaviour.AGGRESSIVE:
			_battle().start_battle(self)
			return Vector3.ZERO
		if behaviour == Behaviour.AGGRESSIVE and d < 6.0:
			return to_p.normalized()
		if behaviour == Behaviour.FLEE and d < 5.0:
			return - to_p.normalized() * 1.3
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.5, 3.5)
		_wander_to = _home + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))

		if is_wild and combat != null and combat.swimmer:
			_wander_to = combat.clamp_to_water(_wander_to)
		if randf() < 0.35:
			_wander_to = global_position
	var v: = _wander_to - global_position
	v.y = 0.0
	if v.length() < 0.2:
		return Vector3.ZERO
	return v.normalized() * 0.6




const FOLLOW_LEAD: = 1.0
const FOLLOW_SPACING: = 0.9

const FOLLOW_STOP: = 0.35

const FOLLOW_SPEED: = 4.6
const FOLLOW_RUN: = 7.6

const FOLLOW_LOST: = 18.0


func _follow_logic(delta: float) -> Vector3:

	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return Vector3.ZERO
	if global_position.distance_to(player.global_position) > FOLLOW_LOST:
		_to_trail(player)
		return Vector3.ZERO



	var target: Vector3 = player.trail_point(FOLLOW_LEAD + follow_slot * FOLLOW_SPACING)



	if is_on_wall() and target.y < _ground_y - LEDGE_HOP_DROP:
		hop(target)
		return Vector3.ZERO
	var v: Vector3 = target - global_position
	v.y = 0.0
	var d: = v.length()
	if d < FOLLOW_STOP:
		return Vector3.ZERO
	return v / d * clampf(d * 2.0, FOLLOW_SPEED, FOLLOW_RUN) * clampf(d / 0.8, 0.3, 1.0)



const LEDGE_HOP_DROP: = 0.4




func hop(to: Vector3) -> void :
	if hopping:
		return
	hopping = true
	velocity = Vector3.ZERO
	Audio.play_at("sfx/world/ledge_hop", global_position, -6.0)
	var mask: = collision_mask
	collision_mask = 0
	var from: = global_position
	var tw: = create_tween()
	tw.tween_method( func(t): global_position = from.lerp(to, t) + Vector3(0, sin(t * PI) * 0.6, 0), 0.0, 1.0, 0.4)
	await tw.finished
	collision_mask = mask
	velocity = Vector3.ZERO
	hopping = false



func _to_trail(player) -> void :
	global_position = player.trail_point(FOLLOW_LEAD + follow_slot * FOLLOW_SPACING)




func reset_battle_mods() -> void :
	combat.reset_battle_mods()


func hold_attacks(secs: float) -> void :
	combat.hold_attacks(secs)


func aim_dir() -> Vector3:
	return combat.aim_dir()



func start_dash(mv: Dictionary, dir: Vector3, miss: Node = null) -> void :
	combat.start_dash(mv, dir, miss)



func struggle() -> void :
	combat.struggle()



func clear_cooldowns() -> void :
	combat.clear_cooldowns()


func take_damage(amount: int, dir: Vector3, knock: = 8.0) -> void :
	if mode == Mode.FAINTED:
		return
	if evolving:
		if amount > 0:
			_vfx().popup(head_pos(1.0), "No effect!", Color(0.8, 0.9, 1.0), 0.9)
		return


	if amount > 0 and dir.length_squared() > 0.0:
		combat.interrupt_prepare()
		_pmd_hurt()
	hp = maxi(hp - amount, 0)
	if mon:
		mon.hp = hp
	combat._knock = dir * knock * Combatant.KNOCKBACK_SCALE
	if combat.status == "sleep" and knock > 0.0:
		clear_status()
	if amount > 0:
		sprite.modulate = Color(1.0, 0.35, 0.35)
		Battle.fight_tween(self).tween_property(sprite, "modulate", base_tint(), 0.25)
	refresh_label()
	if hp == 0:
		if immortal:
			hp = max_hp
			if mon:
				mon.hp = hp
			_vfx().popup(head_pos(1.1), "KO! (refilled)", Color(1, 0.4, 0.4))
			refresh_label()
			return
		_faint()


func _faint() -> void :
	Audio.play_at("sfx/pokemon/faint", global_position)
	Audio.cry(species, global_position, 0.7)
	mode = Mode.FAINTED
	_pmd_faint()
	$CollisionShape3D.set_deferred("disabled", true)
	label.visible = false
	fainted.emit(self)
	if is_wild:
		var tw: = create_tween()
		tw.tween_property(sprite, "modulate:a", 0.0, 0.8)
		tw.tween_callback(queue_free)


func refresh_label() -> void :
	if label == null:
		return
	if trainer_owned:
		label.text = npc_name
		label.visible = true
		return
	var in_fight: = mode == Mode.BATTLE_AI or mode == Mode.PLAYER or mode == Mode.REMOTE or mode == Mode.DUMMY

	label.visible = mode != Mode.FAINTED and (is_wild or in_fight)

	var g: Node = _battle()
	if g and g.in_battle and (g.allies.has(self) or self == g.wild):
		label.visible = false
	var st: = ("  [%s]" % combat.status.to_upper()) if combat.status != "" else ""
	if combat.stagger_t > 0.0:
		st += "  [EXHAUSTED]"
	if in_fight:
		label.text = "%s Lv%d  %d/%d%s" % [species, level, hp, max_hp, st]
	else:
		label.text = "%s Lv%d" % [species, level]






func _float_bob(cd: float) -> void :
	if sprite == null or combat == null or not combat.floats() or combat.is_diving():
		if sprite != null and sprite.position.y != 0.0:
			sprite.position.y = 0.0
		return
	var flying: = combat.can_fly()
	_bob_t_vis += cd * (BOB_FLY_SPEED if flying else BOB_HOVER_SPEED)
	sprite.position.y = sin(_bob_t_vis + _bob_phase) * (BOB_FLY if flying else BOB_HOVER)


func _animate(delta: float, moving: bool) -> void :
	if _look.is_empty():
		apply_look()
	if not _pmd().is_empty():
		_pmd_tick(delta)
		if Engine.get_physics_frames() % 15 == 0:
			refresh_label()
		return
	_anim_t += delta * ((11.0 if combat.sprinting else 7.0) if moving else 2.0)
	var step: = int(_anim_t) if combat.status != "sleep" else 0
	PokemonSprites.animate(sprite, _look, facing, step)
	if Engine.get_physics_frames() % 15 == 0:
		refresh_label()





func _pmd() -> Dictionary:
	return _look.get("pmd", {})




func play_move_anim(mv: Dictionary) -> void :
	if _pmd().is_empty():
		return
	var chains: = PokemonSprites.pmd_anims()
	var chain: Array = chains.moves.get(String(mv.get("id", "")), chains.kinds.get(String(mv.get("kind", "")), []))
	var name: = PokemonSprites.resolve_chain(species, chain)
	if name == "":
		return
	if _pmd_oneshot and _pmd_anim == PokemonSprites.resolve_chain(species, chains.states.hurt):
		return
	var a: Dictionary = _pmd()[name]
	var kind: = String(mv.get("kind", ""))
	if kind == "dash":
		_pmd_play(name, true, int(a.rush), true, 0.0)
	elif kind == "stream" or kind == "beam":
		_pmd_play(name, true, int(a.hit), false, float(mv.get("duration", 0.0)))
	else:
		_pmd_play(name, true)



func _pmd_hurt() -> void :
	if _pmd().is_empty():
		return
	_pmd_play(PokemonSprites.resolve_chain(species, PokemonSprites.pmd_anims().states.hurt), true)





func _pmd_faint() -> void :
	if _pmd().is_empty() or _pmd().has("Faint"):
		return
	_pmd_collapse_t = 0.0
	_pmd_play("Hurt", true)




func _pmd_collapse(delta: float) -> void :
	if _pmd_collapse_t < 0.0 or _pmd_oneshot or _pmd_collapse_t >= PMD_FAINT_TIME:
		return
	_pmd_collapse_t = minf(_pmd_collapse_t + delta, PMD_FAINT_TIME)
	var k: = _pmd_collapse_t / PMD_FAINT_TIME
	sprite.scale = Vector3.ONE.lerp(PMD_FAINT_SCALE, k)
	var c: = base_tint().lerp(PMD_FAINT_TINT, k)
	sprite.modulate = Color(c.r, c.g, c.b, sprite.modulate.a)



func _pmd_faint_reset() -> void :
	if _pmd_collapse_t < 0.0:
		return
	_pmd_collapse_t = -1.0
	if sprite != null:
		sprite.scale = Vector3.ONE
		sprite.modulate = base_tint()



func _pmd_tick(delta: float) -> void :
	var pmd: = _pmd()
	if pmd.is_empty():
		return
	_pmd_update_walking()
	if _pmd_hop_tick(delta):
		return
	if _pmd_anim == "" or not pmd.has(_pmd_anim):
		_pmd_play(_pmd_state_anim(), false)
	if not pmd.has(_pmd_anim):
		return
	var a: Dictionary = pmd[_pmd_anim]
	if sprite.texture != a.texture:
		_pmd_bind(_pmd_anim)
	if _pmd_oneshot:
		if _pmd_hold >= 0:
			if _pmd_hold_dash:
				if combat.dash_t <= 0.0 and combat._lunge_t <= 0.0:
					_pmd_end()
					return
			else:
				_pmd_hold_t -= delta
				if _pmd_hold_t <= 0.0:
					_pmd_end()
					return
			_pmd_frame(_pmd_hold)
			return
		if _pmd_t >= _pmd_total(a):
			_pmd_end()
			return
	else:
		var want: = _pmd_state_anim()
		if want != "" and want != _pmd_anim:
			_pmd_play(want, false)
			a = pmd[_pmd_anim]
	_pmd_t += delta * _pmd_rate()
	var total: = _pmd_total(a)
	var t: = _pmd_t
	if mode == Mode.FAINTED:
		t = minf(t, total)
		_pmd_collapse(delta)
	elif t >= total:
		t = fmod(t, total)
	_pmd_frame(_pmd_frame_at(a.durations, t))




func _pmd_update_walking() -> void :
	var speed: = Vector2(velocity.x, velocity.z).length()
	_pmd_walking = speed > (0.15 if _pmd_walking else 0.35)




func _pmd_rate() -> float:
	if _pmd_anim == "Walk":
		return clampf(Vector2(velocity.x, velocity.z).length() / maxf(move_speed, 0.1), 0.6, 2.0)
	return float(PokemonSprites.pmd_anims().get("rates", {}).get(_pmd_anim, 1.0))



func _pmd_state_anim() -> String:
	var st: Dictionary = PokemonSprites.pmd_anims().states
	if mode == Mode.FAINTED:
		return _pmd_pick(st.faint)
	if combat.stagger_t > 0.0:
		return _pmd_pick(st.stagger)
	if combat.status == "sleep":
		return _pmd_pick(st.sleep)
	if combat.prepare_t > 0.0:
		return _pmd_pick(st.prepare)
	if combat.floats():

		return _pmd_pick(st.fly)
	if combat.is_diving():
		return _pmd_pick(st.move)
	if _pmd_in_jump():
		return _pmd_pick(st.airborne)
	if _pmd_walking:
		return _pmd_pick(st.move)
	return _pmd_pick(st.idle)




func _pmd_in_jump() -> bool:
	return is_airborne() or hopping or (combat != null and combat.air_t > 0.0)









func _pmd_hop_tick(delta: float) -> bool:
	var hop: Dictionary = _pmd().get("Hop", {})
	if hop.is_empty() or combat == null or combat.floats() or combat.is_diving():
		return false
	if _pmd_oneshot and _pmd_anim != "Hop":
		return false
	var frames: = int(hop.get("frames", 0))
	if frames <= 0:
		return false
	var hf: Dictionary = PokemonSprites.pmd_anims().get("hop_frames", {})
	var rise: = clampi(int(hf.get("rise", 1)), 0, frames - 1)
	var fall: = clampi(int(hf.get("fall", 5)), 0, frames - 1)
	var airborne: = _pmd_in_jump()
	if airborne and not _pmd_hop_was_air:
		_pmd_hop_t = HOP_TAKEOFF_HOLD
		_pmd_hop_land = false
		_pmd_hop_prev_y = global_position.y
	elif not airborne and _pmd_hop_was_air:
		_pmd_hop_t = HOP_LAND_HOLD
		_pmd_hop_land = true
	_pmd_hop_was_air = airborne
	if _pmd_hop_t >= 0.0:
		_pmd_hop_t -= delta
		_pmd_play("Hop", false)
		_pmd_frame(0)
		if _pmd_hop_t <= 0.0:
			_pmd_hop_t = -1.0
			if _pmd_hop_land:
				_pmd_hop_land = false
				_pmd_play(_pmd_state_anim(), false)
		return true
	if not airborne:
		return false
	var dy: = global_position.y - _pmd_hop_prev_y
	_pmd_hop_prev_y = global_position.y
	_pmd_play("Hop", false)
	_pmd_frame(rise if dy > 0.0 else fall)
	return true



func _pmd_pick(chain: Array) -> String:
	var name: = PokemonSprites.resolve_chain(species, chain)
	return name if name != "" else _pmd_anim




func _pmd_play(name: String, oneshot: bool, hold: = -1, hold_dash: = false, hold_t: = 0.0) -> void :
	if name == _pmd_anim and not oneshot and not _pmd_oneshot:
		return
	var a: Dictionary = _pmd().get(name, {})
	if a.is_empty():
		return
	_pmd_anim = name
	_pmd_t = 0.0
	_pmd_oneshot = oneshot
	_pmd_hold = hold
	_pmd_hold_dash = hold_dash
	_pmd_hold_t = hold_t
	_pmd_bind(name)
	_pmd_frame(0)


func _pmd_bind(name: String) -> void :
	var a: Dictionary = _pmd()[name]
	sprite.texture = a.texture
	sprite.hframes = int(a.frames)
	sprite.vframes = int(a.dirs)



func _pmd_end() -> void :
	_pmd_oneshot = false
	_pmd_hold = -1
	_pmd_hold_dash = false
	_pmd_hold_t = 0.0
	_pmd_play(_pmd_state_anim(), false)




func _pmd_frame(frame: int) -> void :
	var a: Dictionary = _pmd()[_pmd_anim]
	var frames: = int(a.frames)
	var row: = 0
	if int(a.dirs) > 1:
		row = posmod(int(round(atan2(facing.x, facing.z) / (PI / 4.0))), 8) % int(a.dirs)
	var f: = clampi(frame, 0, frames - 1)
	sprite.frame = row * frames + f
	_pmd_place(a, row, f)




func _pmd_place(a: Dictionary, row: int, frame: int) -> void :
	var rows: Array = a.get("anchor", [])
	if rows.is_empty():
		_pmd_anchor = Vector2(0.0, float(_look.get("offset_y", 0.0)))
	else:
		var pts: Array = rows[clampi(row, 0, rows.size() - 1)]
		var p: Array = pts[clampi(frame, 0, pts.size() - 1)]
		_pmd_anchor = Vector2(float(a.w) / 2.0 - float(p[0]), float(p[1]) - float(a.h) / 2.0)
	sprite.offset = _pmd_anchor


static func _pmd_total(a: Dictionary) -> float:
	var total: = 0.0
	for d in a.durations:
		total += float(d)
	return maxf(total, 1.0 / 60.0)


static func _pmd_frame_at(durs: Array, t: float) -> int:
	var acc: = 0.0
	for i in durs.size():
		acc += float(durs[i])
		if t < acc:
			return i
	return maxi(0, durs.size() - 1)








var _water_t: = 0.0
var _ripple: MeshInstance3D
var _dive_shadow: MeshInstance3D


func _water_visual(delta: float, moving: bool) -> void :
	if sprite == null or combat == null or _look.is_empty():
		return
	_water_t += delta
	var s: = combat.surface()
	var px: float = maxf(float(_look.get("pixel_size", 0.045)), 0.001)

	var base_y: float = _pmd_anchor.y if not _pmd().is_empty() else float(_look.get("offset_y", 0.0))
	var sink: = 0.0
	var flop: = 0.0
	var h: float = look_height()
	if s == Water.Surface.SHALLOW:
		sink = Water.WADE_SINK * h
	elif s == Water.Surface.DEEP:
		sink = (Water.SWIM_SINK if combat.swimmer else Water.WADE_SINK) * h
	if combat.is_diving():
		sink = Water.DIVE_SINK * h
	elif combat.fish and s == Water.Surface.GROUND and moving:
		flop = absf(sin(_water_t * 9.0)) * h * 0.28
	sprite.offset.y = base_y - (sink - flop) / px
	_water_ripple(s)
	_water_shadow(s)



func _water_ripple(s: int) -> void :
	var on: = s != Water.Surface.GROUND and combat.locomotion == "ground" and not combat.is_diving()
	if on and _ripple == null:
		_ripple = MeshInstance3D.new()
		var tm: = TorusMesh.new()
		tm.inner_radius = 0.3
		tm.outer_radius = 0.42
		tm.rings = 24
		tm.ring_segments = 5
		var m: = StandardMaterial3D.new()
		m.albedo_color = Color(0.88, 0.97, 1.0, 0.55)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tm.material = m
		_ripple.mesh = tm
		_ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ripple)
	if _ripple:
		_ripple.visible = on
		if on:
			_ripple.global_position = Vector3(global_position.x, ground_y() + 0.06, global_position.z)
			var pulse: = 1.0 + sin(_water_t * 3.0) * 0.12
			_ripple.scale = Vector3(pulse, 1.0, pulse)



func _water_shadow(s: int) -> void :
	var on: = combat.is_diving() and s == Water.Surface.DEEP
	if on and _dive_shadow == null:
		_dive_shadow = MeshInstance3D.new()
		var cm: = CylinderMesh.new()
		cm.top_radius = 0.55
		cm.bottom_radius = 0.55
		cm.height = 0.02
		var m: = StandardMaterial3D.new()
		m.albedo_color = Color(0.0, 0.03, 0.08, 0.8)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cm.material = m
		_dive_shadow.mesh = cm
		_dive_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_dive_shadow)
	if _dive_shadow:
		_dive_shadow.visible = on
		if on:
			_dive_shadow.global_position = Vector3(global_position.x, ground_y() + 0.06, global_position.z)
