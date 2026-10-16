extends Area3D


@export_file("*.tscn") var target_scene: = ""
@export var target_spawn: = ""


func _ready() -> void :
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void :
	if body.is_in_group("player") and target_scene != "":
		Audio.play("sfx/world/door")
		Transitions.go_to(target_scene, target_spawn)
