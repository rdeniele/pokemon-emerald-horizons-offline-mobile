extends Node3D


const Props: = preload("res://scripts/world/props.gd")

@export var title: = "Sign"
@export var lines: PackedStringArray = PackedStringArray(["..."])
@export var model: = "nature/sign"
@export var model_scale: = 2.2


@export var model_billboard: = false
@export var model_tint: = Color.WHITE

var npc_name: String:
	get:
		return title


func _ready() -> void :
	add_to_group("npc")
	if model != "":

		var opts: = {"scale": model_scale, "collide": "box", "rot": 180, "tint": model_tint}
		if model_billboard:
			opts["billboard"] = true
		Props.place(self, model, global_position, opts)


func prompt_verb() -> String:
	return "Read"



func prompt_anchor() -> Vector3:
	return global_position + Vector3(0, 2.2, 0)


func talk_to(_player: Node3D) -> PackedStringArray:
	return lines


func finish_talk() -> void :
	pass
