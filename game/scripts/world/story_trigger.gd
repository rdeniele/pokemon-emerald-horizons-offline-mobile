extends Area3D



@export var event: = ""

@export var requires_flags: PackedStringArray = PackedStringArray()

@export var blocks_flags: PackedStringArray = PackedStringArray()
@export var size: = Vector3(4, 3, 1)


func _ready() -> void :
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	var cs: = CollisionShape3D.new()
	var sh: = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position.y = size.y * 0.5
	add_child(cs)
	body_entered.connect(_on_body_entered)


func ready_to_fire() -> bool:
	for f in requires_flags:
		if not Game.flags.get(f, false):
			return false
	for f in blocks_flags:
		if Game.flags.get(f, false):
			return false
	return true


func _on_body_entered(body: Node) -> void :
	if not body.is_in_group("player") or not ready_to_fire():
		return
	if event == "pewter_east_block":
		Analytics.track("blocked_exit_hit", {"wall": "pewter_east", "zone": SaveGame.location_name()})
	var story: = get_node_or_null("/root/Story")
	if story:
		story.trigger(event, self)
