extends Node3D











@export var length: = 10.0
@export var drop: = 0.7

const Boulders: = preload("res://scripts/world/terrain/boulders.gd")
const LIP: = 0.1
const CREATURE_LAYER: = 2

var _zone: Area3D
var _player: Node3D


func _ready() -> void :
	_build()
	_zone.body_entered.connect( func(b): if b.is_in_group("player"): _player = b)
	_zone.body_exited.connect( func(b): if b == _player: _player = null)


func _build() -> void :

	Boulders.row(self, length, drop, hash(global_position))

	var sb: = StaticBody3D.new()
	sb.collision_layer = CREATURE_LAYER
	sb.collision_mask = 0
	var cs: = CollisionShape3D.new()
	var sh: = BoxShape3D.new()
	sh.size = Vector3(length, 1.6, 0.2)
	cs.shape = sh
	sb.add_child(cs)
	sb.position = Vector3(0, 0.8, -0.1)
	add_child(sb)

	_zone = Area3D.new()
	var zs: = CollisionShape3D.new()
	var zb: = BoxShape3D.new()
	zb.size = Vector3(length, 2.0, 0.9)
	zs.shape = zb
	_zone.add_child(zs)
	_zone.position = Vector3(0, 1.0, -0.45)
	add_child(_zone)


func _physics_process(_d: float) -> void :
	if _player == null:
		return
	if _player.get("hopping") or not _player.get("controls_enabled"):
		return


	if _player.global_position.y < global_position.y - drop * 0.5:
		return
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dbg = _player.get("debug_move")
	if dbg is Vector2 and dbg != Vector2.ZERO:
		input = dbg
	var out: = global_transform.basis.z.normalized()
	if Vector2(out.x, out.z).dot(input) > 0.6:
		var to: Vector3 = _player.global_position + out * (LIP + 1.3)
		to.y = Game.ground_y(to, global_position.y - drop)
		_player.hop(to)
