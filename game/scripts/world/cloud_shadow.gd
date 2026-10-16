extends MeshInstance3D





const SIZE: = 280.0
const HEIGHT: = 1.0

var _rig: Node3D


func _ready() -> void :
	var pm: = PlaneMesh.new()
	pm.size = Vector2(SIZE, SIZE)
	mesh = pm
	var m: = ShaderMaterial.new()
	m.shader = load("res://shaders/cloud_shadow.gdshader")
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	global_position.y = HEIGHT


func _process(_delta: float) -> void :
	if not is_instance_valid(_rig):
		_rig = get_tree().get_first_node_in_group("camera_rig") as Node3D
	if _rig:
		global_position.x = _rig.global_position.x
		global_position.z = _rig.global_position.z
