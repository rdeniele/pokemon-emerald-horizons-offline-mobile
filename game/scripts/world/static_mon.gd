extends Node3D
















const ROW_VEC: = [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)]

const SCALE: = 1.25

const BURST_DIST: = 2.2




const Combatant: = preload("res://scripts/combat/combatant.gd")
const FLY_CRUISE: = 1.3
const BREATH: = 0.02
const TURN_MIN: = 3.0
const TURN_MAX: = 6.0
const HOP_MIN: = 5.0
const HOP_MAX: = 8.0

@export var uid: = ""
@export var species: = ""
@export var level: = 5
@export var hidden: = false

@export var facing: = 0

var _fired: = false

var _pet: Creature
var _flier: = false
var _idle_t: = 0.0
var _turn_t: = 0.0
var _hop_t: = 0.0


func _ready() -> void :
	if Game.flags.get("static_" + uid, false):
		queue_free()
		return
	if hidden:
		_make_trigger()
	else:


		_spawn_creature.call_deferred(global_position)


func _make_trigger() -> void :
	var area: = Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitorable = false
	var cs: = CollisionShape3D.new()
	var sh: = BoxShape3D.new()
	sh.size = Vector3(2.0, 3.0, 2.0)
	cs.shape = sh
	cs.position.y = 1.5
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void :
	if _fired or not body.is_in_group("player") or Game.is_busy() or Game.party.is_empty():
		return
	_fired = true
	_burst_out(body)




func _burst_out(p: Node3D) -> void :
	Battle._ambush = true
	p.controls_enabled = false
	p.show_alert(true)
	await get_tree().create_timer(0.6).timeout
	p.show_alert(false)
	var target: Vector3 = p.global_position + p.facing_vector() * BURST_DIST
	target.y = Transitions.ground_y(target, p.global_position.y)
	var c: = _spawn_creature(target + Vector3(0, -0.8, 0))
	var tw: = create_tween()
	tw.tween_property(c, "position", target + Vector3(0, 1.3, 0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position", target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	Battle._ambush = false
	Battle.start_battle(c)


func _spawn_creature(at: Vector3) -> Creature:
	var c: Creature = Encounters.spawn_creature(
		{"species": species, "level": level, "behaviour": "passive"}, get_parent(), at)
	c.static_uid = uid
	c.mode = Creature.Mode.IDLE
	c.peace_timer = 0.0
	c.facing = ROW_VEC[clampi(facing, 0, 3)]
	c._animate(0.0, false)
	c.sprite.scale = Vector3.ONE * SCALE


	_pet = c
	_flier = c.combat.locomotion != "ground"
	if _flier:
		c.combat.flight = Combatant.Flight.AIRBORNE
		c.combat.fly_height = minf(c.combat.fly_height, FLY_CRUISE)
	_turn_t = randf_range(TURN_MIN, TURN_MAX)
	_hop_t = randf_range(HOP_MIN, HOP_MAX)
	var vis: = c.look_height()
	c.label.position.y = vis * SCALE + 0.4

	var sparkle: = Vfx.emitter(Color(1.0, 0.95, 0.6), 10, 1.4, 0.3, 0.09, 25.0, Vector3.UP, Vector3(0, -0.15, 0), 0.6)
	sparkle.position = Vector3(0, vis * 0.7, 0)
	sparkle.emitting = true
	c.add_child(sparkle)
	return c






func _process(delta: float) -> void :
	if _pet == null or not is_instance_valid(_pet) or _pet.mode != Creature.Mode.IDLE:
		return
	_idle_t += delta
	if _flier:
		_pet._animate(delta, false)
		return
	_pet.sprite.scale = Vector3.ONE * SCALE * Vector3(1.0, 1.0 + sin(_idle_t * 1.6) * BREATH, 1.0)
	_turn_t -= delta
	if _turn_t <= 0.0:
		_turn_t = randf_range(TURN_MIN, TURN_MAX)
		_pet.facing = ROW_VEC[randi() % 4]
		_pet._animate(0.0, false)
	_hop_t -= delta
	if _hop_t <= 0.0:
		_hop_t = randf_range(HOP_MIN, HOP_MAX)
		_hop()



func _hop() -> void :
	var spr: = _pet.sprite
	var tw: = spr.create_tween()
	tw.tween_property(spr, "position:y", 0.18, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
