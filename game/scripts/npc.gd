extends CharacterBody3D



enum Action{NONE, HEAL, SHOP, TUTOR, GIFT, CLUB}

const WALK_CYCLE: = [0, 1, 0, 2]
const SpriteLook: = preload("res://scripts/sprite_look.gd")

@export var npc_name: = "Villager"
@export var sprite_sheet: Texture2D
@export var lines: PackedStringArray = PackedStringArray(["Hello there!"])

@export var wander_radius: = 0.0

@export var action: Action = Action.NONE

@export var after_heal_lines: PackedStringArray = PackedStringArray(["There! You and your Pokémon are looking great. Take care now!"])
@export_enum("Down", "Left", "Right", "Up") var start_facing: = 0


@export var lying: = false

@export var requires_flag: = ""

@export var hidden_by_flag: = ""


var scripted: = false
var _walk_target = null
const SCRIPT_SPEED: = 2.4

var talking: = false
var row: = 0
var _home: = Vector3.ZERO
var _target: = Vector3.ZERO
var _t: = 0.0
var _anim: = 0.0

@onready var sprite: Sprite3D = $Sprite3D


func _ready() -> void :
	if (requires_flag != "" and not Game.flags.get(requires_flag, false)) or (hidden_by_flag != "" and Game.flags.get(hidden_by_flag, false)):
		queue_free()
		return
	add_to_group("npc")
	if sprite_sheet:
		sprite.texture = sprite_sheet
	SpriteLook.setup(sprite)
	row = start_facing
	_home = global_position
	_target = _home
	sprite.frame = row * 3
	if lying:
		_lie_down()




func _lie_down() -> void :
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.rotation = Vector3(0.0, 0.0, - PI * 0.5)
	sprite.offset = Vector2.ZERO
	sprite.position = Vector3(0, 0.35, 0)
	sprite.modulate = Color(0.72, 0.72, 0.8)
	var cs: = $CollisionShape3D as CollisionShape3D
	if cs:
		var box: = BoxShape3D.new()
		box.size = Vector3(1.7, 0.6, 0.7)
		cs.shape = box
		cs.position = Vector3(0, 0.3, 0)


func prompt_verb() -> String:
	return "Talk"



func prompt_anchor() -> Vector3:
	return global_position + Vector3(0, 0.9 if lying else 1.25, 0)


func _physics_process(delta: float) -> void :
	var v: = Vector3.ZERO
	var spd: = 1.4
	if _walk_target != null:
		var dw: Vector3 = _walk_target - global_position
		dw.y = 0.0
		if dw.length() < 0.12:
			_walk_target = null
		else:
			v = dw.normalized()
			spd = SCRIPT_SPEED
	elif not talking and not scripted and wander_radius > 0.0:
		_t -= delta
		if _t <= 0.0:
			_t = randf_range(2.0, 5.0)
			_target = _home + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * wander_radius
			if randf() < 0.4:
				_target = global_position
		var d: = _target - global_position
		d.y = 0.0
		if d.length() > 0.15:
			v = d.normalized()
	velocity.x = v.x * spd
	velocity.z = v.z * spd
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 20.0 * delta
	move_and_slide()
	var moving: = v.length() > 0.1
	if moving:
		row = row_for(v)
		_anim += delta * 6.0
	else:
		_anim = 0.0
	var col: int = WALK_CYCLE[int(_anim) % 4] if moving else 0
	sprite.frame = row * 3 + col


func face(dir: Vector3) -> void :
	dir.y = 0.0
	if dir.length() > 0.01:
		row = row_for(dir)
		sprite.frame = row * 3


static func row_for(v: Vector3) -> int:
	if absf(v.x) > absf(v.z):
		return 1 if v.x < 0.0 else 2
	return 0 if v.z > 0.0 else 3



func walk_to(pos: Vector3, timeout: = 8.0, through_player: = true) -> void :
	scripted = true
	_walk_target = Vector3(pos.x, global_position.y, pos.z)

	var pl: = get_tree().get_first_node_in_group("player") as PhysicsBody3D
	if through_player and pl:
		add_collision_exception_with(pl)
	var t: = 0.0
	while is_inside_tree() and _walk_target != null:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if t > timeout:
			global_position = Vector3(pos.x, global_position.y, pos.z)
			_walk_target = null
	if through_player and is_instance_valid(pl) and is_inside_tree():
		remove_collision_exception_with(pl)



func walk_path(points: Array, timeout_each: = 8.0, through_player: = true) -> void :
	for pos in points:
		await walk_to(pos, timeout_each, through_player)



func talk_to(player: Node3D) -> PackedStringArray:
	talking = true
	face(player.global_position - global_position)
	var story: = get_node_or_null("/root/Story")
	if story:
		var l: PackedStringArray = story.lines_for(npc_name)
		if not l.is_empty():
			return l
	return lines



func finish_talk() -> void :
	talking = false
	match action:
		Action.HEAL:
			if Game.party.is_empty():
				return
			Game.remember_heal_point(npc_name == "Mom")
			await Game.heal_with_fade()
			if npc_name != "Mom":
				Analytics.track("healed_at_center", {"zone": SaveGame.location_name()})
			if not after_heal_lines.is_empty():
				var hud: = Game.get_hud()
				if hud:
					hud.open_dialog(npc_name, after_heal_lines)
					await hud.dialog_closed
		Action.SHOP:

			if not Game.flags.get("has_pokedex", false):
				return
			var hud2: = Game.get_hud()
			if hud2 and hud2.has_method("open_shop"):
				hud2.open_shop(String(get_meta("shop", "viridian")))
		Action.TUTOR:

			var story: = get_node_or_null("/root/Story")
			if story:
				await story.old_man_lesson(npc_name)
		Action.GIFT:

			var gift_story: = get_node_or_null("/root/Story")
			if gift_story:
				await gift_story.aide_reward()
		Action.CLUB:

			var hud3: = Game.get_hud()
			if hud3 and hud3.has_method("open_cable_club"):
				await hud3.open_cable_club()
