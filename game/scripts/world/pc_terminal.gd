extends Node3D








@export var npc_name: = "PC"


@export var action: = 0

func _ready() -> void :
	add_to_group("npc")


func prompt_verb() -> String:
	return "Use"



func prompt_anchor() -> Vector3:
	return global_position + Vector3(0, 1.6, 0)


func talk_to(_player: Node3D) -> PackedStringArray:
	return PackedStringArray(["Booted up the PC."])


func finish_talk() -> void :
	var hud: = Game.get_hud()
	if hud and hud.has_method("open_pc"):
		hud.open_pc()
