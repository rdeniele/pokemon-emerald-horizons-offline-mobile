@tool
extends Node3D



enum Shape{BOX, CYLINDER, SPHERE}

@export var shape: Shape = Shape.BOX:
	set(v):
		shape = v
		_rebuild()
@export var size: = Vector3(1, 1, 1):
	set(v):
		size = v
		_rebuild()
@export var color: = Color(0.6, 0.45, 0.3):
	set(v):
		color = v
		_rebuild()
@export var texture: Texture2D:
	set(v):
		texture = v
		_rebuild()

@export var emission: = 0.0:
	set(v):
		emission = v
		_rebuild()
@export var collide: = true:
	set(v):
		collide = v
		_rebuild()


@export var hidden_by_flag: = ""


func _ready() -> void :
	if not Engine.is_editor_hint() and hidden_by_flag != "":
		var g: = get_node_or_null("/root/Game")
		if g and g.flags.get(hidden_by_flag, false):
			queue_free()
			return
	_build()


func _rebuild() -> void :
	if is_inside_tree():
		_build()


func _build() -> void :
	for c in get_children():
		if String(c.name).begins_with("_gen"):
			remove_child(c)
			c.free()
	var m: = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if texture:
		m.albedo_texture = texture
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	var mesh: Mesh
	match shape:
		Shape.BOX:
			var b: = BoxMesh.new()
			b.size = size
			mesh = b
		Shape.CYLINDER:
			var cy: = CylinderMesh.new()
			cy.top_radius = size.x / 2
			cy.bottom_radius = size.x / 2
			cy.height = size.y
			mesh = cy
		Shape.SPHERE:
			var sp: = SphereMesh.new()
			sp.radius = size.x / 2
			sp.height = size.y
			mesh = sp
	var mi: = MeshInstance3D.new()
	mi.name = "_gen_mesh"
	mi.mesh = mesh
	mi.material_override = m
	mi.position.y = size.y / 2
	add_child(mi)
	if collide:
		var sb: = StaticBody3D.new()
		sb.name = "_gen_body"
		var cs: = CollisionShape3D.new()
		var bs: = BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position.y = size.y / 2
		sb.add_child(cs)
		add_child(sb)
