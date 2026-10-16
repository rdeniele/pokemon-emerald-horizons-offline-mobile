extends RefCounted












const SHADER: = preload("res://shaders/path_organic.gdshader")

const MASK_DIR: = "res://data/masks"
const PX_PER_M: = 4.0
const MARGIN: = 1.5
const WARP: = 0.35
const SOFT: = 0.5
const LIFT: = 0.012




static func height_at(data: Dictionary, x: float, z: float) -> float:
	var h: = 0.0
	for p in data.get("plateaus", []):
		var r: Array = p.rect
		if x >= r[0] and x <= r[0] + r[2] and z >= r[1] and z <= r[1] + r[3]:
			h = maxf(h, float(p.h))
	return h



static func mask_file(zone_id: String, i: int, dir: = MASK_DIR) -> String:
	return "%s/%s_path_%d.png" % [dir, zone_id, i]




static func load_mask(path: String) -> Image:
	var bytes: = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var img: = Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return null
	return img


static func levels(paths: Array, height_at: Callable) -> Dictionary:
	var out: = {}
	for r in paths:
		var h: = snappedf(float(height_at.call(float(r[0]) + float(r[2]) / 2.0, float(r[1]) + float(r[3]) / 2.0)), 0.01)
		if not out.has(h):
			out[h] = []
		out[h].append(r)
	return out


static func bounds(rects: Array) -> Rect2:
	var b: = Rect2(rects[0][0], rects[0][1], rects[0][2], rects[0][3])
	for r in rects:
		b = b.merge(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	return b.grow(MARGIN)




const MASK_MS: = 4.0


static var _cache: = {}


static func mask(rects: Array, area: Rect2, seed: = 0) -> Image:
	var key: = hash([rects, area, seed])
	if _cache.has(key):
		return _cache[key]
	var w: = maxi(int(ceil(area.size.x * PX_PER_M)), 1)
	var h: = maxi(int(ceil(area.size.y * PX_PER_M)), 1)
	var img: = Image.create(w, h, false, Image.FORMAT_L8)
	var coarse: = FastNoiseLite.new()
	coarse.seed = seed
	coarse.frequency = 0.35
	var fine: = FastNoiseLite.new()
	fine.seed = seed + 7
	fine.frequency = 1.4


	var reach: = SOFT + WARP * 1.35 + 0.05
	var grown: Array[Rect2] = []
	for r in rects:
		grown.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).grow(reach))
	var mark: = Time.get_ticks_usec()
	for j in h:
		if Time.get_ticks_usec() - mark >= MASK_MS * 1000.0:
			mark = Time.get_ticks_usec()
			await (Engine.get_main_loop() as SceneTree).process_frame
		var z: = area.position.y + (j + 0.5) / PX_PER_M
		for i in w:
			var x: = area.position.x + (i + 0.5) / PX_PER_M
			var p: = Vector2(x, z)
			var near: = false
			for g in grown:
				if g.has_point(p):
					near = true
					break
			if not near:
				continue
			var d: = INF
			for r in rects:
				d = minf(d, _sd_rect(x, z, r))
			d += coarse.get_noise_2d(x, z) * WARP + fine.get_noise_2d(x, z) * WARP * 0.35
			var v: = 1.0 - smoothstep( - SOFT * 0.5, SOFT * 0.5, d)
			img.set_pixel(i, j, Color(v, v, v))
	_cache[key] = img
	return img



static func _sd_rect(x: float, z: float, r: Array) -> float:
	var qx: float = absf(x - (float(r[0]) + float(r[2]) / 2.0)) - float(r[2]) / 2.0
	var qz: float = absf(z - (float(r[1]) + float(r[3]) / 2.0)) - float(r[3]) / 2.0
	return Vector2(maxf(qx, 0.0), maxf(qz, 0.0)).length() + minf(maxf(qx, qz), 0.0)



static func overlay(rects: Array, level: float, image: Image, tint: = Color.WHITE, mix: = 0.0) -> MeshInstance3D:
	var area: = bounds(rects)
	var mat: = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("mask_tex", ImageTexture.create_from_image(image))
	mat.set_shader_parameter("mask_origin", area.position)
	mat.set_shader_parameter("mask_size", area.size)
	mat.set_shader_parameter("path_tint", tint)
	mat.set_shader_parameter("path_mix", mix)
	var pm: = PlaneMesh.new()
	pm.size = area.size
	var mi: = MeshInstance3D.new()
	mi.name = "PathLevel_%s" % str(level).replace(".", "_")
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3(area.get_center().x, level + LIFT, area.get_center().y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
