extends CharacterBody3D


const ROW_VEC: = [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)]
const WALK_CYCLE: = [0, 1, 0, 2]
const SpriteLook: = preload("res://scripts/sprite_look.gd")
const EncounterRate: = preload("res://scripts/encounter_rate.gd")





const SHEETS: = {
	"red": {"walk": "res://assets/sprites/trainer.png", "run": "res://assets/sprites/trainer_run.png"}, 
	"green": {"walk": "res://assets/sprites/trainer_green.png", "run": "res://assets/sprites/trainer_green_run.png"}, 
}

var _walk_tex: Texture2D
var _run_tex: Texture2D

@export var walk_speed: = 4.0
@export var run_speed: = 7.0


const WATER_LAYER: = 8

var controls_enabled: = true
var row: = 0
var _grass: Array = []

var _grace: = 0.0

var _steps_since: = 0

var _new_tile: = false
var _dist: = 0.0
var _anim_t: = 0.0
var _step_t: = 0.0
var _focus_npc: Node3D
var hopping: = false

var debug_move: = Vector2.ZERO

var debug_speed: = 0.0



const TRAIL_STEP: = 0.4
const TRAIL_MAX: = 64


const TRAIL_BREAK: = 4.0

var _trail: Array[Vector3] = []

var script_move: = Vector2.ZERO

var script_speed: = 0.0

@onready var sprite: Sprite3D = $Sprite3D
@onready var alert: Label3D = $Alert


func _ready() -> void :
	add_to_group("player")
	alert.visible = false
	collision_mask |= WATER_LAYER
	var key: = "green" if Game.state.is_green() else "red"
	_walk_tex = load(SHEETS[key]["walk"])
	_run_tex = load(SHEETS[key]["run"])
	sprite.texture = _walk_tex
	SpriteLook.setup(sprite)
	Game.battle_ended.connect(_on_battle_ended)



func _on_battle_ended(_result: String) -> void :
	_grace = EncounterRate.GRACE_M
	_steps_since = 0


func _physics_process(delta: float) -> void :
	if hopping:

		velocity = Vector3.ZERO
		return
	var input: = Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if debug_move != Vector2.ZERO:
			input = debug_move
	if script_move != Vector2.ZERO:
		input = script_move
	var speed: = run_speed if Input.is_action_pressed("run") else walk_speed
	if script_speed > 0.0 and script_move != Vector2.ZERO:
		speed = script_speed
	if debug_move != Vector2.ZERO and debug_speed > 0.0:
		speed = debug_speed
	velocity.x = input.x * speed
	velocity.z = input.y * speed
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 20.0 * delta
	move_and_slide()
	_record_trail()

	var moving: = input.length() > 0.1

	var want: = _run_tex if (moving and Input.is_action_pressed("run")) else _walk_tex
	if sprite.texture != want:
		sprite.texture = want
	if moving:
		if absf(input.x) > absf(input.y):
			row = 1 if input.x < 0.0 else 2
		else:
			row = 0 if input.y > 0.0 else 3
		_anim_t += delta * speed * 1.5
		if not _grass.is_empty():
			var d: = Vector2(velocity.x, velocity.z).length() * delta
			_dist += d
			if _grace > 0.0:
				_grace = maxf(_grace - d, 0.0)
			while _dist >= EncounterRate.STEP_M:
				_dist -= EncounterRate.STEP_M
				_grass_step()
	else:
		_anim_t = 0.0
	var step_gap: = 0.24 if Input.is_action_pressed("run") else 0.32
	if moving and controls_enabled and is_on_floor():
		_step_t += delta
		if _step_t >= step_gap:
			_step_t = 0.0
			var indoors: = get_tree().current_scene != null and get_tree().current_scene.scene_file_path.contains("interiors")
			Audio.play("sfx/world/step_wood" if indoors else "sfx/world/step_grass", -8.0)
			if Game.state.repel_steps > 0:
				Game.state.repel_steps -= 1
				if Game.state.repel_steps == 0:
					Game._msg("Repel's effect wore off...")
	else:
		_step_t = step_gap
	var col: int = WALK_CYCLE[int(_anim_t) % 4] if moving else 0
	sprite.frame = row * 3 + col
	_update_npc_focus()
	if controls_enabled and _focus_npc and Input.is_action_just_pressed("interact"):
		if _focus_npc.is_in_group("wild"):
			Battle.engage(_focus_npc)
		else:
			Game.start_dialogue(_focus_npc)




const ENGAGE_RANGE: = 3.5
const ENGAGE_RANGE_WATER: = 4.5



func _update_npc_focus() -> void :
	var best: Node3D = null
	var best_d: = INF
	for n in get_tree().get_nodes_in_group("npc"):
		var to: Vector3 = n.global_position - global_position
		to.y = 0.0
		var d: = to.length()
		if d < 2.0 and d < best_d and (d < 1.3 or facing_vector().dot(to / maxf(d, 0.001)) > 0.4):
			best = n
			best_d = d
	if not Game.party.is_empty():
		for w in get_tree().get_nodes_in_group("wild"):
			if not w.visible or not w.alive() or w.peace_timer > 0.0:
				continue
			var to: Vector3 = w.global_position - global_position
			to.y = 0.0
			var d: = to.length()
			var reach: = ENGAGE_RANGE_WATER if (w.combat and w.combat.swimmer) else ENGAGE_RANGE
			if d < reach and d < best_d and (d < 1.3 or facing_vector().dot(to / maxf(d, 0.001)) > 0.5):
				best = w
				best_d = d
	if best != _focus_npc:
		_focus_npc = best

	var hud: = Game.get_hud()
	var hidden: bool = _focus_npc != null and _focus_npc.has_method("prompt_hidden") and _focus_npc.prompt_hidden()
	if _focus_npc and controls_enabled and not hidden:
		if hud and hud.has_method("show_interact_prompt"):
			hud.show_interact_prompt(_focus_npc)
	elif hud and hud.has_method("hide_interact_prompt"):
		hud.hide_interact_prompt()


func face_toward(pos: Vector3) -> void :
	var v: = pos - global_position
	if absf(v.x) > absf(v.z):
		row = 1 if v.x < 0.0 else 2
	else:
		row = 0 if v.z > 0.0 else 3
	sprite.frame = row * 3


func _grass_step() -> void :
	if not controls_enabled or Game.is_busy() or Game.state.repel_steps > 0:
		return
	var patch: Node = _grass[-1]
	if patch.has_method("rustle_step"):
		patch.rustle_step(global_position, facing_vector())
	if Debug.no_encounters:
		return
	if EncounterRate.grace_blocks(_grace):
		return
	var rate: = Encounters.table_rate(patch.encounter_table)

	var first: = _new_tile
	_new_tile = false
	if _steps_since < EncounterRate.cooldown_steps(rate):
		_steps_since += 1
		if randf() >= EncounterRate.COOLDOWN_BYPASS:
			return

	if first and randf() >= EncounterRate.NEW_TILE_GATE:
		return
	if randf() < EncounterRate.per_step_chance(rate):
		_steps_since = 0
		Encounters.grass_encounter(self, patch.encounter_table)


func enter_grass(area: Node) -> void :
	if not _grass.has(area):
		if _grass.is_empty():
			_new_tile = true
		_grass.append(area)
		Audio.play("sfx/world/grass_rustle", -4.0)


func exit_grass(area: Node) -> void :
	_grass.erase(area)


func facing_vector() -> Vector3:
	return ROW_VEC[row]




func trail_point(metres: float) -> Vector3:
	if _trail.is_empty():
		return global_position
	var acc: = 0.0
	for i in range(1, _trail.size()):
		acc += Vector2(_trail[i - 1].x - _trail[i].x, _trail[i - 1].z - _trail[i].z).length()
		if acc >= metres:
			return _trail[i]
	return _trail[-1]




func _record_trail() -> void :
	var here: = global_position
	if not _trail.is_empty():
		var moved: = Vector2(here.x - _trail[0].x, here.z - _trail[0].z).length()
		if moved < TRAIL_STEP:
			return
		if moved > TRAIL_BREAK:
			_trail.clear()
	_trail.push_front(here)
	if _trail.size() > TRAIL_MAX:
		_trail.resize(TRAIL_MAX)



func walk_to(pos: Vector3, timeout: = 8.0, speed: = 0.0) -> void :
	script_speed = speed
	var t: = 0.0
	while is_inside_tree() and t < timeout:
		var d: = Vector2(pos.x - global_position.x, pos.z - global_position.z)
		if d.length() < 0.15:
			break
		script_move = d.normalized() * clampf(d.length() * 2.0, 0.35, 1.0)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	script_move = Vector2.ZERO
	script_speed = 0.0





func hop(to: Vector3) -> void :
	if hopping:
		return
	hopping = true
	Audio.play("sfx/world/ledge_hop")
	controls_enabled = false
	velocity = Vector3.ZERO
	var mask: = collision_mask
	collision_mask = 0
	var from: = global_position
	var arc: = func(t: float) -> void :
		global_position = from.lerp(to, t) + Vector3(0, sin(t * PI) * 0.6, 0)
	var tw: = create_tween()
	tw.tween_method(arc, 0.0, 1.0, 0.4)
	await tw.finished
	velocity = Vector3.ZERO
	Audio.play("sfx/world/ledge_land")
	collision_mask = mask
	hopping = false
	if not Game.is_busy():
		controls_enabled = true


func show_alert(on: bool) -> void :
	alert.visible = on
