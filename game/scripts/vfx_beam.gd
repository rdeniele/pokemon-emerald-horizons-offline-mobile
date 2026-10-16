extends RefCounted



















const DATA: = "res://data/move_fx.json"
const DIR: = "res://assets/vfx/pmd/beams/"


const FX_PIXEL_M: = 0.03

const SKY_H: = 6.0

static var _data: = {}




static func _load() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func beams() -> Dictionary:
	return _load().get("beams", {})



static func beam_for(move_id: String) -> String:
	var mv = _load().get("moves", {}).get(move_id, {})
	return String(mv.get("beam", "")) if mv is Dictionary else ""






static func sky(move_id: String, at: Vector3, height: = SKY_H, dur: = 0.6) -> Node3D:
	return _mapped(move_id, "sky", at, Vector3.UP, height, dur)




static func aim(move_id: String, from: Vector3, dir: Vector3, length: float, dur: = 0.6) -> Node3D:
	return _mapped(move_id, "aim", from, dir, length, dur)


static func _mapped(move_id: String, axis: String, at: Vector3, dir: Vector3, length: float, dur: float) -> Node3D:
	var id: = beam_for(move_id)
	if id == "" or String(beams().get(id, {}).get("axis", "aim")) != axis:
		return null
	return spawn(id, at, dir, length, dur)





static func spawn(beam_id: String, at: Vector3, dir: = Vector3.FORWARD, length: = 12.0, dur: = 0.0) -> Node3D:
	var def: Dictionary = beams().get(beam_id, {})
	var tree: = Engine.get_main_loop() as SceneTree
	if def.is_empty() or tree == null or tree.current_scene == null:
		return null
	var n: = int(def.get("frames", 1))
	var fps: = maxf(float(def.get("fps", 16)), 1.0)
	var head: = _part(beam_id, "head", n)
	var body: = _part(beam_id, "body", n)
	if head.is_empty() or body.is_empty():
		return null
	var holder: = Node3D.new()
	holder.name = "BeamFx"
	holder.set_meta("beam", beam_id)
	tree.current_scene.add_child(holder)
	holder.global_position = at
	var tint: = _tint(def.get("tint", []))
	var add: = String(def.get("blend", "add")) == "add"



	var dia_px: = minf(float(head["fw"]), float(head["fh"]))
	var thick: = float(def.get("thickness", 0.0))
	var k: = thick / (dia_px * FX_PIXEL_M) if thick > 0.0 else 1.0
	var end_k: = k * float(def.get("head_scale", 1.0))
	if String(def.get("axis", "aim")) == "sky":
		_quad(holder, head, n, fps, Vector3(0, float(head["fh"]) * FX_PIXEL_M * end_k * 0.5, 0), 
			Vector3.ONE * end_k, tint, add)
		var tile: = float(body["fh"]) * FX_PIXEL_M
		for i in int(ceil(length / tile)):

			var t: = minf(tile, length - float(i) * tile)
			_quad(holder, body, n, fps, Vector3(0, float(i) * tile + t * 0.5, 0), 
				Vector3(dia_px / float(body["fw"]) * k, t / tile, 1), tint, add)
	else:
		var cam_node: = tree.root.get_camera_3d()
		var cam: Vector3 = cam_node.global_position if cam_node != null else at + Vector3(0, 4.0, 0)
		var aim: = dir.normalized()
		_aim(holder, head, n, fps, at, Vector3.ZERO, Vector3.AXIS_Y, aim, cam, Vector3.ONE * end_k, tint, add)
		var tile: = float(body["fw"]) * FX_PIXEL_M
		var stretch: = dia_px / float(body["fh"]) * k
		for i in int(ceil(length / tile)):

			var t: = minf(tile, length - float(i) * tile)
			_aim(holder, body, n, fps, at, aim * (float(i) * tile + t * 0.5), Vector3.AXIS_X, aim, cam, 
				Vector3(t / tile, stretch, 1), tint, add)
		var tail: = _part(beam_id, "tail", n)
		if not tail.is_empty():
			_aim(holder, tail, n, fps, at, aim * length, Vector3.AXIS_Y, aim, cam, Vector3.ONE * end_k, tint, add)
	var life: = dur if dur > 0.0 else float(n) / fps
	_fade(holder, life)
	Battle.fight_timer(maxf(life, 0.1)).timeout.connect(holder.queue_free)
	return holder





static func _part(beam_id: String, part: String, frames: int) -> Dictionary:
	var path: = DIR + beam_id + "/" + part + ".png"
	if not ResourceLoader.exists(path) or frames < 1:
		return {}
	var tex: Texture2D = load(path)
	if tex == null:
		return {}
	var fw: = tex.get_width() / frames
	var fh: = tex.get_height()
	return {} if fw < 1 or fh < 1 or (fw <= 1 and fh <= 1) else {"tex": tex, "fw": fw, "fh": fh}


static func _tint(v: Variant) -> Color:
	return Color(float(v[0]), float(v[1]), float(v[2])) if v is Array and (v as Array).size() >= 3 else Color.WHITE


static func _frames(part: Dictionary, n: int, fps: float) -> SpriteFrames:
	var sf: = SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("play")
	sf.set_animation_speed("play", fps)
	sf.set_animation_loop("play", true)
	for i in n:
		var at: = AtlasTexture.new()
		at.atlas = part["tex"]
		at.region = Rect2(i * int(part["fw"]), 0, int(part["fw"]), int(part["fh"]))
		sf.add_frame("play", at)
	return sf


static func _sprite(part: Dictionary, n: int, fps: float, tint: Color, add: bool) -> AnimatedSprite3D:
	var sf: = _frames(part, n, fps)
	var spr: = AnimatedSprite3D.new()
	spr.sprite_frames = sf
	spr.pixel_size = FX_PIXEL_M
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.transparent = true
	spr.speed_scale = Battle.fight_speed()
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	mat.albedo_color = tint
	mat.albedo_texture = sf.get_frame_texture("play", 0)
	spr.material_override = mat
	spr.frame_changed.connect( func(): mat.albedo_texture = sf.get_frame_texture("play", spr.frame))
	spr.play("play")
	return spr




static func _fade(holder: Node3D, life: float) -> void :
	var fade: = minf(0.06, life * 0.3)
	var fade_in: = Battle.fight_tween(holder).set_parallel(true)
	var fade_out: = Battle.fight_tween(holder).set_parallel(true)
	for s in holder.get_children():
		var mat: StandardMaterial3D = s.material_override
		var c: = mat.albedo_color
		c.a = 0.0
		mat.albedo_color = c
		fade_in.tween_property(mat, "albedo_color:a", 1.0, fade)
		fade_out.tween_property(mat, "albedo_color:a", 0.0, fade).set_delay(maxf(life - fade, 0.0))





static func _quad(holder: Node3D, part: Dictionary, n: int, fps: float, off: Vector3, scale: Vector3, 
		tint: Color, add: bool) -> void :
	var spr: = _sprite(part, n, fps, tint, add)
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.scale = scale
	spr.position = off
	holder.add_child(spr)



static func _aim(holder: Node3D, part: Dictionary, n: int, fps: float, at: Vector3, off: Vector3, 
		axis: int, dir: Vector3, cam: Vector3, scale: Vector3, tint: Color, add: bool) -> void :
	var spr: = _sprite(part, n, fps, tint, add)
	var pos: = at + off
	holder.add_child(spr)
	spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	spr.global_transform = Transform3D(_basis(dir, axis, pos, cam), pos)

	spr.scale = scale




static func _basis(dir: Vector3, axis: int, pos: Vector3, cam: Vector3) -> Basis:
	var d: = dir.normalized()
	var to_cam: = cam - pos
	var n: = to_cam - d * to_cam.dot(d)
	if n.length_squared() < 0.0001:
		n = Vector3.UP.cross(d)
		if n.length_squared() < 0.0001:
			n = Vector3.RIGHT
	n = n.normalized()
	return Basis(d.cross(n), d, n) if axis == Vector3.AXIS_Y else Basis(d, n.cross(d), n)
