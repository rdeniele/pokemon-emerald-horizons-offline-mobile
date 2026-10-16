extends RefCounted













const DIR: = "res://assets/vfx/pmd/"

const FX_PIXEL_M: = 0.03



const FX_TOWARD_CAM_M: = 0.35



const DIR_ROWS: = ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]

const DIR_VEC: = [Vector2(0, -1), Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1), 
	Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(1, -1)]

static var _fx: = {}
static var _frames: = {}



static func table() -> Dictionary:
	if _fx.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/move_fx.json"))
		_fx = parsed.get("fx", {}) if parsed is Dictionary else {}
	return _fx


static func entry(fx_id: String) -> Dictionary:
	return table().get(fx_id, {})


static func exists(fx_id: String) -> bool:
	return not entry(fx_id).is_empty() and ResourceLoader.exists(DIR + fx_id + ".png")




static func spawn(parent: Node, fx_id: String, at: Vector3, aim: Vector3, role: Dictionary) -> Node3D:
	var holder: = _build(parent, fx_id, aim, role, bool(role.get("loop", false)))
	if holder != null:
		holder.global_position = at + _toward_camera(parent, at)
	return holder



static func attach(parent: Node3D, fx_id: String, aim: Vector3, role: Dictionary) -> Node3D:
	return _build(parent, fx_id, aim, role, bool(role.get("loop", true)))






static func content_offset(e: Dictionary, lo: int, hi: int) -> Vector2:
	var bbox: Array = e.get("bbox", [])
	if bbox.is_empty():
		return Vector2.ZERO
	var x0: = 1e+30
	var y0: = 1e+30
	var x1: = -1e+30
	var y1: = -1e+30
	for i in range(maxi(lo, 0), mini(hi, bbox.size() - 1) + 1):
		var b: Array = bbox[i]
		if b.size() != 4 or float(b[2]) <= float(b[0]) or float(b[3]) <= float(b[1]):
			continue
		x0 = minf(x0, float(b[0]))
		y0 = minf(y0, float(b[1]))
		x1 = maxf(x1, float(b[2]))
		y1 = maxf(y1, float(b[3]))
	if x1 < 0.0:
		return Vector2.ZERO
	return Vector2((x0 + x1) * 0.5 - float(e.frame[0]) * 0.5, 
		(y0 + y1) * 0.5 - float(e.frame[1]) * 0.5)



static func frames(fx_id: String, row: int, lo: int, hi: int, loop: bool) -> SpriteFrames:
	var key: = "%s:%d:%d:%d" % [fx_id, row, lo, hi]
	if _frames.has(key):
		return _frames[key]
	var e: = entry(fx_id)
	if e.is_empty():
		return null
	var tex: Texture2D = load(DIR + fx_id + ".png")
	if tex == null:
		return null
	var fw: = int(e.frame[0])
	var fh: = int(e.frame[1])
	var sf: = SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("play")
	sf.set_animation_speed("play", float(e.get("fps", 12)))
	sf.set_animation_loop("play", loop)
	for i in range(lo, hi + 1):
		var at: = AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, row * fh, fw, fh)
		sf.add_frame("play", at)
	_frames[key] = sf
	return sf


static func _build(parent: Node, fx_id: String, aim: Vector3, role: Dictionary, loop: bool) -> Node3D:
	if parent == null:
		return null
	var e: = entry(fx_id)
	if e.is_empty():
		return null
	var n: = int(e.get("frames", 0))
	var rng: Array = role.get("range", [0, n - 1])
	var lo: = clampi(int(rng[0]), 0, maxi(n - 1, 0))
	var hi: = clampi(int(rng[1]), lo, maxi(n - 1, 0))
	var sd: = _screen_dir(parent, aim)
	var row: = _row(e, sd)
	var sf: = frames(fx_id, row, lo, hi, loop)
	if sf == null:
		return null
	var holder: = Node3D.new()
	holder.name = "PmdFx"
	holder.set_meta("fx", fx_id)
	var spr: = AnimatedSprite3D.new()
	spr.name = "Sprite"
	spr.sprite_frames = sf
	spr.pixel_size = FX_PIXEL_M * float(role.get("scale", 1.0))


	var c: = content_offset(e, lo, hi)
	spr.offset = Vector2( - c.x, c.y)
	spr.transparent = true
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if String(e.get("blend", "alpha")) == "add":
		var mat: = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = sf.get_frame_texture("play", 0)
		spr.material_override = mat
		spr.frame_changed.connect( func(): mat.albedo_texture = sf.get_frame_texture("play", spr.frame))
	holder.add_child(spr)
	parent.add_child(holder)
	_orient(spr, sd, int(e.get("dirs", 1)) <= 1, _mirror(e, sd, role))
	spr.play("play")
	if loop:
		spr.animation_finished.connect( func(): spr.play("play"))
	else:
		spr.animation_finished.connect(holder.queue_free)

		var life: = float(hi - lo + 1) / maxf(float(e.get("fps", 12)), 1.0) + 0.5
		var tree: = Engine.get_main_loop() as SceneTree
		if tree != null:
			var ref: WeakRef = weakref(holder)
			tree.create_timer(life).timeout.connect( func():
				var h: = ref.get_ref() as Node
				if h != null:
					h.queue_free())
	return holder



static func _screen_dir(parent: Node, aim: Vector3) -> Vector2:
	var a: = Vector3(aim.x, 0.0, aim.z)
	if a.length_squared() < 1e-06:
		return Vector2(0, -1)
	a = a.normalized()
	var cam: = _camera(parent)
	if cam == null:
		return Vector2(a.x, - a.z)
	var b: = cam.global_basis
	var sd: = Vector2(a.dot(b.x), a.dot(b.y))
	return sd.normalized() if sd.length_squared() > 1e-06 else Vector2(0, -1)



static func _row(e: Dictionary, sd: Vector2) -> int:
	var dirs: = int(e.get("dirs", 1))
	if dirs <= 1:
		return 0
	if dirs < DIR_VEC.size():
		sd.x = - absf(sd.x)
	var best: = 0
	var best_dot: = -2.0
	for i in mini(dirs, DIR_VEC.size()):
		var d: float = sd.dot(DIR_VEC[i].normalized())
		if d > best_dot:
			best_dot = d
			best = i
	return best



static func _mirror(e: Dictionary, sd: Vector2, role: Dictionary) -> bool:
	if role.has("mirror"):
		return bool(role.mirror)
	var dirs: = int(e.get("dirs", 1))
	if dirs > 1 and dirs < DIR_VEC.size():
		return sd.x > 0.0
	return String(e.get("src", "")).contains(".Flip.") and sd.x < 0.0





static func _orient(spr: AnimatedSprite3D, sd: Vector2, roll: bool, mirror: bool) -> void :
	var cam: = _camera(spr)
	if not roll or cam == null:
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	else:
		spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		var b: = cam.global_basis.orthonormalized()
		spr.global_basis = b
		spr.rotate_object_local(Vector3.BACK, atan2(sd.y, sd.x))
	spr.flip_h = mirror


static func _camera(node: Node) -> Camera3D:
	var vp: = node.get_viewport()
	return vp.get_camera_3d() if vp != null else null





static func _toward_camera(node: Node, at: Vector3) -> Vector3:
	var cam: = _camera(node)
	if cam == null:
		return Vector3.ZERO
	var d: = cam.global_position - at
	return d.normalized() * FX_TOWARD_CAM_M if d.length_squared() > 1e-06 else Vector3.ZERO
