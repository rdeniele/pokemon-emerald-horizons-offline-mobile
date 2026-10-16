extends StaticBody3D






@export var until_flag: = ""
@export var size: = Vector3(6.0, 6.0, 1.0)

var _player: Node3D
var _hit: = false


func _ready() -> void :
	if until_flag != "" and Game.flags.get(until_flag, false):
		queue_free()
		return
	var cs: = CollisionShape3D.new()
	var sh: = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position.y = size.y * 0.5
	add_child(cs)


	var zone: = Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = 1
	zone.monitorable = false
	var zcs: = CollisionShape3D.new()
	var zsh: = BoxShape3D.new()
	zsh.size = size + Vector3(1.2, 0.0, 1.2)
	zcs.shape = zsh
	zcs.position.y = size.y * 0.5
	zone.add_child(zcs)
	add_child(zone)
	zone.body_entered.connect( func(body: Node):
		if body.is_in_group("player"):
			Analytics.track("blocked_exit_hit", {"wall": until_flag, "zone": SaveGame.location_name()}))
