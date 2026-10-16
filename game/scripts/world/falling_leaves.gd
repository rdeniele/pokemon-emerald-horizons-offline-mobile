extends Node3D




const MAX_LEAVES: = 12
const RADIUS: = 15.0
const LEAF_SIZE: = 0.22

var _mesh: QuadMesh
var _base_mat: StandardMaterial3D
var _live: Array = []
var _rig: Node3D
var _wind_node: Node
var _timer: = 0.0
var _rng: = RandomNumberGenerator.new()


func _ready() -> void :
	_rng.randomize()
	_mesh = QuadMesh.new()
	_mesh.size = Vector2(LEAF_SIZE, LEAF_SIZE)
	_base_mat = StandardMaterial3D.new()
	_base_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_base_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_base_mat.billboard_keep_scale = true
	_base_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_base_mat.albedo_color = Color(0.5, 0.7, 0.28)


func _process(delta: float) -> void :
	if not is_instance_valid(_rig):
		_rig = get_tree().get_first_node_in_group("camera_rig") as Node3D
	if _rig == null:
		return
	var g: = _gust()
	_timer -= delta
	if _timer <= 0.0:
		_timer = _rng.randf_range(0.6, 1.6) * (1.0 - 0.7 * g)
		if _live.size() < MAX_LEAVES and _high():
			_spawn()
	_update(delta, g)


func _spawn() -> void :
	var focus: = _rig.global_position
	var near: Array = []
	for t in get_tree().get_nodes_in_group("leaf_source"):
		if not is_instance_valid(t):
			continue
		var d: = Vector2(t.global_position.x - focus.x, t.global_position.z - focus.z)
		if d.length() <= RADIUS:
			near.append(t)
	if near.is_empty():
		return
	var tree: Node3D = near[_rng.randi() % near.size()]
	var mi: = MeshInstance3D.new()
	mi.mesh = _mesh
	var mat: = _base_mat.duplicate()
	mat.albedo_color = Color(0.5, 0.7, 0.28).lerp(Color(0.75, 0.78, 0.35), _rng.randf())
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var px: = tree.global_position.x + _rng.randf_range(-1.5, 1.5)
	var pz: = tree.global_position.z + _rng.randf_range(-1.5, 1.5)
	var py: = tree.global_position.y + 2.0 * tree.scale.x + _rng.randf_range(-0.4, 0.4)
	mi.global_position = Vector3(px, py, pz)
	var ground: = py - 3.0
	var game: = get_node_or_null("/root/Game")
	if game and game.has_method("ground_y"):
		ground = game.ground_y(Vector3(px, py + 2.0, pz), py)
	_live.append({"node": mi, "mat": mat, "age": 0.0, "life": _rng.randf_range(4.0, 7.0), 
		"phase": _rng.randf() * TAU, "spin": _rng.randf_range(4.0, 9.0), "ground": ground})


func _update(delta: float, g: float) -> void :
	var wd: = _wind_dir()
	var speed: = 2.0 + 4.0 * g
	for i in range(_live.size() - 1, -1, -1):
		var leaf: Dictionary = _live[i]
		var node: MeshInstance3D = leaf.node
		if not is_instance_valid(node):
			_live.remove_at(i)
			continue
		leaf.age += delta
		var p: = node.global_position
		p.x += (wd.x * speed + sin(leaf.age * 3.0 + leaf.phase) * 0.7) * delta
		p.z += (wd.y * speed + cos(leaf.age * 2.4 + leaf.phase) * 0.7) * delta
		p.y -= (1.1 + 0.4 * sin(leaf.age * 4.0 + leaf.phase)) * delta
		node.global_position = p

		node.scale = Vector3(abs(sin(leaf.age * leaf.spin + leaf.phase)) * 0.85 + 0.15, 1.0, 1.0)
		var fade: = 1.0
		if p.y <= leaf.ground + 0.15:
			fade = clampf((p.y - leaf.ground) / 0.15, 0.0, 1.0)
		if leaf.age > leaf.life - 1.0:
			fade = minf(fade, clampf(leaf.life - leaf.age, 0.0, 1.0))
		var mat: StandardMaterial3D = leaf.mat
		var c: = mat.albedo_color
		c.a = fade
		mat.albedo_color = c
		if leaf.age >= leaf.life or p.y <= leaf.ground - 0.05:
			node.queue_free()
			_live.remove_at(i)


func _wind() -> Node:
	if not is_instance_valid(_wind_node):
		_wind_node = get_tree().get_first_node_in_group("wind")
	return _wind_node


func _wind_dir() -> Vector2:
	var w: = _wind()
	return w.dir if w != null else Vector2(1, 0)


func _gust() -> float:
	var w: = _wind()
	return w.gust() if w != null else 0.0



func _high() -> bool:
	var s: = get_node_or_null("/root/Settings")
	return s == null or s.is_high()
