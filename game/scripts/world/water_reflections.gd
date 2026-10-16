extends Node














const WATER_MAT: = preload("res://resources/look/water.tres")
const REFLECT_SHADER: = preload("res://shaders/water_reflection.gdshader")

const REFLECT_DIST: = 3.0


const SSR_ON_DIST: = 25.0
const SSR_OFF_DIST: = 32.0

const WATER_Y: = 0.04
const GROUPS: = ["player", "npc", "wild"]

var _sky_top: = Color(-1, -1, -1)
var _sun_color: = Color(-1, -1, -1)
var _ssr_on: = false
var _ssr_t: = 0.0

var _refs: = {}



func apply_sky(env: Environment, sun: DirectionalLight3D = null) -> void :
	if env != null and env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		_sky_top = (env.sky.sky_material as ProceduralSkyMaterial).sky_top_color
		WATER_MAT.set_shader_parameter("sky_top", _sky_top)
	if sun != null:
		_sun_color = sun.light_color
		WATER_MAT.set_shader_parameter("sun_color", _sun_color)


func _process(delta: float) -> void :
	var env: = _active_env()
	var sun: = get_tree().get_first_node_in_group("sun") as DirectionalLight3D
	var top: = _sky_top
	if env != null and env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		top = (env.sky.sky_material as ProceduralSkyMaterial).sky_top_color
	if top != _sky_top or (sun != null and sun.light_color != _sun_color):
		apply_sky(env, sun)
	var rects: = _active_rects()
	_refresh(rects)
	_ssr_proximity(delta, rects)




func _ssr_proximity(delta: float, rects: Array) -> void :
	if not Settings.is_high() or RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return
	_ssr_t += delta
	if _ssr_t < 0.2:
		return
	_ssr_t = 0.0
	var cam: = get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null:
		return
	var eye: = cam.global_position
	var radius: = SSR_OFF_DIST if _ssr_on else SSR_ON_DIST
	var want: = false
	for r in rects:
		var c: = Vector3(r.get_center().x, WATER_Y, r.get_center().y)
		var near: = Vector3(clampf(eye.x, r.position.x, r.end.x), WATER_Y, clampf(eye.z, r.position.y, r.end.y))
		if eye.distance_to(c) <= radius or eye.distance_to(near) <= radius:
			if cam.is_position_in_frustum(c) or cam.is_position_in_frustum(near):
				want = true
				break
	if want != _ssr_on:
		_ssr_on = want
		var env: = _active_env()
		if env != null:
			env.ssr_enabled = want



func _active_env() -> Environment:
	var vp: = get_viewport()
	if vp == null:
		return null
	var w: = vp.find_world_3d()
	return w.environment if w != null else null


func _active_rects() -> Array:
	if not is_inside_tree():
		return []
	return Game.water_rects()



func _refresh(rects: Array) -> void :
	var live: = {}
	if not rects.is_empty():
		for body in _bodies():
			if not is_instance_valid(body) or not body.is_inside_tree():
				continue
			var spr: = _sprite_of(body)
			if spr == null or spr.texture == null:
				continue
			var pos: Vector3 = body.global_position
			if Water.distance_to_water(rects, pos.x, pos.z) > REFLECT_DIST:
				continue
			var r: = _nearest_rect(rects, pos.x, pos.z)
			_update(body, spr, r, Vector2(pos.x, pos.z))
			live[body] = true
	for body in _refs.keys():
		if not live.has(body) or not is_instance_valid(body):
			var n = _refs[body].get("node")
			if is_instance_valid(n):
				n.queue_free()
			_refs.erase(body)


func _bodies() -> Array:
	var out: Array = []
	for g in GROUPS:
		out.append_array(get_tree().get_nodes_in_group(g))
	return out


func _sprite_of(body: Node) -> Sprite3D:
	for c in body.get_children():
		if c is Sprite3D:
			return c
	return null


func _nearest_rect(rects: Array, x: float, z: float) -> Rect2:
	var best: Rect2 = rects[0]
	var bd: = INF
	for r in rects:
		var p: = Vector2(clampf(x, r.position.x, r.end.x), clampf(z, r.position.y, r.end.y))
		var d: = p.distance_squared_to(Vector2(x, z))
		if d < bd:
			bd = d
			best = r
	return best





func _update(body: Node3D, spr: Sprite3D, r: Rect2, at: Vector2) -> void :
	var entry = _refs.get(body)
	var node: MeshInstance3D
	var mat: ShaderMaterial
	var mesh: PlaneMesh
	if entry == null or not is_instance_valid(entry.get("node")):
		node = MeshInstance3D.new()
		node.name = "WaterReflection"
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mat = ShaderMaterial.new()
		mat.shader = REFLECT_SHADER
		mesh = PlaneMesh.new()
		mesh.orientation = PlaneMesh.FACE_Z
		node.mesh = mesh
		node.material_override = mat
		body.add_child(node)
		_refs[body] = {"node": node, "mat": mat, "mesh": mesh}
	else:
		node = entry["node"]
		mat = entry["mat"]
		mesh = entry["mesh"]


	var pos: Vector3 = body.global_position
	node.global_position = Vector3(at.x, 2.0 * WATER_Y - pos.y - spr.position.y, at.y)
	mesh.center_offset = Vector3(0.0, - spr.offset.y * spr.pixel_size * spr.scale.y, 0.0)
	var hf: = maxi(1, spr.hframes)
	var vf: = maxi(1, spr.vframes)
	var tex: = spr.texture
	var size: = Vector2(float(tex.get_width()) / hf, float(tex.get_height()) / vf) * spr.pixel_size
	size *= Vector2(spr.scale.x, spr.scale.y)
	if mesh.size != size:
		mesh.size = size

	var col: = spr.frame % hf
	var row: = spr.frame / hf
	mat.set_shader_parameter("albedo_tex", spr.texture)
	mat.set_shader_parameter("uv_rect", Vector4(float(col) / hf, float(row) / vf, 1.0 / hf, 1.0 / vf))
	mat.set_shader_parameter("tint", spr.modulate)
	mat.set_shader_parameter("flip_h", spr.flip_h)
	mat.set_shader_parameter("water_y", WATER_Y)
	mat.set_shader_parameter("water_centre", r.get_center())
	mat.set_shader_parameter("water_half", r.size * 0.5)
	mat.set_shader_parameter("water_warp", WATER_MAT.get_shader_parameter("warp"))
	var cam: = get_viewport().get_camera_3d() if get_viewport() else null
	if cam != null:
		mat.set_shader_parameter("cam_vp", cam.get_camera_projection() * Projection(cam.global_transform.affine_inverse()))
