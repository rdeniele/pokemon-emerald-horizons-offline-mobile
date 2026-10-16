@tool
extends Node3D







const Props: = preload("res://scripts/world/props.gd")




const PALETTE: = {

	"wood": Color(0.74, 0.54, 0.32), 
	"woodDark": Color(0.52, 0.36, 0.22), 
	"carpet": Color(0.34, 0.6, 0.45), 
	"carpetBlue": Color(0.34, 0.44, 0.68), 
	"carpetDarker": Color(0.26, 0.44, 0.36), 
	"plant": Color(0.3, 0.58, 0.3), 
	"lamp": Color(0.95, 0.88, 0.68), 


	"dirt": Color(0.561, 0.573, 0.58), 
	"grass": Color(0.463, 0.49, 0.471), 

	"M_Week2": Color(0.72, 0.73, 0.76), 
	"M_FloorGrey": Color(0.6, 0.63, 0.66), 
	"M_SolidGrey": Color(0.66, 0.68, 0.71), 
	"M_SolidDarkGrey": Color(0.33, 0.36, 0.4), 
	"M_SolidDarkGrey_4": Color(0.3, 0.33, 0.37), 
	"M_SolidDarkerGrey": Color(0.21, 0.23, 0.26), 
	"M_SolidBlack": Color(0.11, 0.12, 0.14), 
	"M_SolidBlack_3": Color(0.13, 0.14, 0.16), 
	"M_Glass": Color(0.72, 0.88, 0.94), 
	"M_BookRed": Color(0.72, 0.26, 0.24), 
	"M_BookBlue": Color(0.28, 0.42, 0.72), 
	"M_BookGreen": Color(0.3, 0.6, 0.38), 
	"M_DeskTeal": Color(0.3, 0.62, 0.6), 
	"M_DeskTeal_1": Color(0.26, 0.56, 0.55), 
	"M_DeskDrawerBlue": Color(0.34, 0.46, 0.7), 
	"M_DeskKnobGold": Color(0.85, 0.7, 0.3), 
	"M_CupCream": Color(0.94, 0.92, 0.84), 
	"M_PencilYellow": Color(0.92, 0.78, 0.28), 
	"M_EraserPink": Color(0.9, 0.6, 0.65), 
	"M_PicturePinRed": Color(0.8, 0.28, 0.24), 
	"M_PictureFrameBrown": Color(0.52, 0.36, 0.22), 
	"M_PictureStringGrey": Color(0.55, 0.55, 0.58), 
	"M_CardboardBrown": Color(0.72, 0.56, 0.36), 
	"M_PokemonTableGreen": Color(0.34, 0.66, 0.44), 
}

@export var base: = "res://assets/models/kenney/":
	set(v):
		base = v
		_rebuild()
@export var model: = "furniture/bedSingle":
	set(v):
		model = v
		_rebuild()
@export var rot: = 0.0:
	set(v):
		rot = v
		_rebuild()
@export var model_scale: = 1.0:
	set(v):
		model_scale = v
		_rebuild()
@export var collide: = true:
	set(v):
		collide = v
		_rebuild()

@export var emission: = 0.0:
	set(v):
		emission = v
		_rebuild()


@export var carpet_color: = Color(0, 0, 0, 0):
	set(v):
		carpet_color = v
		_rebuild()


func _ready() -> void :
	var _p1: = Time.get_ticks_usec()
	_build()
	P1Prof.acc("interior furniture build (.glb -> props)", Time.get_ticks_usec() - _p1)


func _rebuild() -> void :
	if is_inside_tree():
		_build()


func _build() -> void :
	for c in get_children():
		remove_child(c)
		c.free()
	if model.is_empty():
		return
	var off: = _footprint_offset(base + model + ".glb")
	var pal: = PALETTE.duplicate()
	if carpet_color.a > 0.0:
		pal["carpet"] = carpet_color
	var inst: = Props.place(self, model, global_position - off, {
		"root": base, 
		"rot": rot, 
		"scale": model_scale, 
		"palette": pal, 
		"collide": "box" if collide else "", 
	})
	inst.name = "_gen_model"
	if emission > 0.0:
		_glow(inst)





func _footprint_offset(path: String) -> Vector3:
	var scene: = load(path) as PackedScene
	if scene == null:
		return Vector3.ZERO
	var probe: Node3D = scene.instantiate()
	add_child(probe)
	probe.transform = Transform3D.IDENTITY
	probe.scale = Vector3.ONE * model_scale
	probe.rotation_degrees.y = rot
	var box: = Props.bounds(probe)
	remove_child(probe)
	probe.free()
	return Vector3(box.get_center().x, box.position.y, box.get_center().z) - global_position


func _glow(inst: Node3D) -> void :
	for mi: MeshInstance3D in Props.meshes(inst):
		for i in mi.mesh.get_surface_count():
			var m: = mi.get_active_material(i)
			if not m is ShaderMaterial:
				continue
			var n: = String(m.resource_name).to_lower()
			if not (n.contains("screen") or n.contains("glass") or n.contains("lamp") or n.contains("neon")):
				continue
			var dup: ShaderMaterial = m.duplicate()
			dup.set_shader_parameter("emission_color", Color(0.75, 0.9, 1.0, 1.0))
			dup.set_shader_parameter("emission_energy", emission)
			mi.set_surface_override_material(i, dup)
