extends Marker3D


@export_enum("Down", "Left", "Right", "Up") var facing: = 0


func _ready() -> void :
	add_to_group("spawn_point")
