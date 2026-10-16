extends "res://scripts/world/sign_post.gd"







@export var uid: = ""


func prompt_verb() -> String:
	return "Check"


func _ready() -> void :
	model = "hgss/common/cut_tree"
	model_scale = 0.8


	model_billboard = true
	model_tint = Color(0.74, 0.86, 0.72)
	title = "Tree"
	lines = PackedStringArray([
		"A small tree blocks the way.", 
		"It looks like a Pokémon could cut it down..."])
	super ()
	add_to_group("cut_tree")
	set_meta("cut_uid", uid)



	for c in get_children():
		if c is StaticBody3D:
			var cs: CollisionShape3D = c.get_child(0)
			(cs.shape as BoxShape3D).size = Vector3(1.4, 1.8, 1.4)
			c.global_position = global_position + Vector3(0, 0.9, 0)
