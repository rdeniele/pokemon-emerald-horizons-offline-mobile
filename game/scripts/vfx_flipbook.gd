extends RefCounted











const DIR: = "res://assets/vfx/moves/"

const CELL_WORLD: = 1.6

const ADDITIVE_TYPES: = {"fire": true, "electric": true, "psychic": true, "ice": true, 
	"dragon": true, "steel": true, "fairy": true}

static var _meta: = {}
static var _frames: = {}


static func exists(anim: String) -> bool:
	return anim != "" and ResourceLoader.exists(DIR + anim + ".png") and FileAccess.file_exists(DIR + anim + ".json")


static func meta(anim: String) -> Dictionary:
	if _meta.has(anim):
		return _meta[anim]
	var d: = {}
	if exists(anim):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DIR + anim + ".json"))
		if parsed is Dictionary:
			d = parsed
	_meta[anim] = d
	return d


static func sprite_frames(anim: String) -> SpriteFrames:
	if _frames.has(anim):
		return _frames[anim]
	var m: = meta(anim)
	if m.is_empty():
		return null
	var tex: Texture2D = load(DIR + anim + ".png")
	if tex == null:
		return null
	var cw: = int(m.cell[0])
	var ch: = int(m.cell[1])
	var cols: = int(m.cols)
	var sf: = SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("play")
	sf.set_animation_speed("play", float(m.fps))
	sf.set_animation_loop("play", false)
	for i in int(m.count):
		var at: = AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((i % cols) * cw, (i / cols) * ch, cw, ch)
		sf.add_frame("play", at)
	_frames[anim] = sf
	return sf


static func additive_for(type_id: String) -> bool:
	return ADDITIVE_TYPES.has(type_id)




static func spawn(parent: Node, anim: String, at: Vector3, world_h: float, type_id: = "normal") -> Node3D:
	var holder: = _build(parent, anim, world_h, type_id, false)
	if holder == null:
		return null
	holder.global_position = at
	return holder



static func attach(parent: Node3D, anim: String, world_h: float, type_id: = "normal") -> Node3D:
	return _build(parent, anim, world_h, type_id, true)


static func _build(parent: Node, anim: String, world_h: float, type_id: String, loop: bool) -> Node3D:
	var sf: = sprite_frames(anim)
	if sf == null:
		return null
	var m: = meta(anim)
	var holder: = Node3D.new()
	holder.name = "Flipbook"
	holder.set_meta("anim", anim)
	var spr: = AnimatedSprite3D.new()
	spr.name = "Sprite"
	spr.sprite_frames = sf
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spr.transparent = true
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

	var src_h: = float(m.src_cell[1])
	var wps: = world_h * CELL_WORLD / src_h
	spr.pixel_size = wps / float(m.scale)

	var win: Array = m.win
	var dx: = float(win[0]) + float(win[2]) * 0.5 - float(m.src_cell[0]) * 0.5
	var dy: = float(win[1]) + float(win[3]) * 0.5 - src_h * 0.5
	spr.position = Vector3(dx * wps, - dy * wps, 0)

	var mat: = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = sf.get_frame_texture("play", 0)
	if additive_for(type_id):
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spr.material_override = mat
	spr.frame_changed.connect( func(): mat.albedo_texture = sf.get_frame_texture("play", spr.frame))
	holder.add_child(spr)
	parent.add_child(holder)
	if loop:
		spr.animation_finished.connect( func(): spr.play("play"))
		spr.play("play")
	else:
		spr.animation_finished.connect(holder.queue_free)
		spr.play("play")

		var life: = float(m.count) / maxf(float(m.fps), 1.0) + 0.5
		var tree: = Engine.get_main_loop() as SceneTree
		if tree != null:
			var ref: WeakRef = weakref(holder)
			tree.create_timer(life).timeout.connect( func():
				var h: = ref.get_ref() as Node
				if h != null:
					h.queue_free())
	return holder
