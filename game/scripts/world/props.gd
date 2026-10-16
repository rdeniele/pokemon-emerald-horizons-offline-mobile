extends RefCounted




















const ROOT: = "res://assets/models/kenney/"


const HGSS_ROOT: = "res://assets/models/"
const STYLIZE_SHADER: = preload("res://shaders/prop_stylize.gdshader")

const FOLIAGE_SHADER: = preload("res://shaders/hgss_foliage.gdshader")

const NightLights: = preload("res://scripts/world/night_lights.gd")

const WINDOW_COLOR: = Color(1.0, 0.5, 0.15)




const WINDOW_MIN_COVER: = 0.6


const NATURE_PALETTE: = {
	"leafsGreen": Color(0.33, 0.62, 0.27), 
	"leafsDark": Color(0.2, 0.45, 0.2), 
	"leafsFall": Color(0.85, 0.55, 0.25), 
	"grass": Color(0.45, 0.72, 0.3), 
	"woodBark": Color(0.45, 0.31, 0.22), 
	"woodBarkDark": Color(0.35, 0.24, 0.17), 
	"wood": Color(0.82, 0.62, 0.42), 
	"woodDark": Color(0.62, 0.45, 0.31), 
	"dirt": Color(0.6, 0.47, 0.33), 
	"stone": Color(0.62, 0.63, 0.66), 
	"stoneDark": Color(0.45, 0.46, 0.5), 
}

static var _scenes: = {}
static var _mats: = {}


const CELL: = 8.0
static var _cells: = {}


static func register_fader(n: Node3D, rect: Rect2) -> void :
	var a: = Vector2i(floori(rect.position.x / CELL), floori(rect.position.y / CELL))
	var b: = Vector2i(floori(rect.end.x / CELL), floori(rect.end.y / CELL))
	for cx in range(a.x, b.x + 1):
		for cz in range(a.y, b.y + 1):
			var k: = Vector2i(cx, cz)
			if not _cells.has(k):
				_cells[k] = []
			_cells[k].append(n)



static func faders_near(p: Vector3, radius: float) -> Array:
	var out: = {}
	var a: = Vector2i(floori((p.x - radius) / CELL), floori((p.z - radius) / CELL))
	var b: = Vector2i(floori((p.x + radius) / CELL), floori((p.z + radius) / CELL))
	for cx in range(a.x, b.x + 1):
		for cz in range(a.y, b.y + 1):
			var k: = Vector2i(cx, cz)
			if not _cells.has(k):
				continue
			var arr: Array = _cells[k]
			for i in range(arr.size() - 1, -1, -1):
				if not is_instance_valid(arr[i]):
					arr.remove_at(i)
				else:
					out[arr[i]] = true
	return out.keys()


static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]





static func _remap(m: Material, tex: Texture2D, palette: = {}, stylize: = false) -> Material:
	var sm: = m as StandardMaterial3D
	if sm == null:
		return m
	var key: = "%s|%s|%s|%s" % [sm.get_instance_id(), tex.resource_path if tex else "", str(palette), stylize]
	if _mats.has(key):
		return _mats[key]
	if palette.get(sm.resource_name) is Material:
		_mats[key] = palette[sm.resource_name]
		return _mats[key]
	var out: = sm
	if tex and sm.albedo_texture:
		out = sm.duplicate()
		out.albedo_texture = tex
	elif palette.has(sm.resource_name) or NATURE_PALETTE.has(sm.resource_name):
		out = sm.duplicate()
		out.albedo_color = palette.get(sm.resource_name, NATURE_PALETTE.get(sm.resource_name))
	if out != sm:
		out.roughness = 0.9
	var res: Material = _stylized(out) if stylize else out
	_mats[key] = res
	return res




static func stylizes(id: String) -> bool:
	return not id.begins_with("suburban/building") and not id.begins_with("hgss/")








static func _hgss_material(m: Material, billboard: = false, tint: = Color.WHITE, windows: = false) -> Material:
	var sm: = m as StandardMaterial3D
	if sm == null:
		return m
	var key: = "hgss|%s|%s|%s|%s" % [sm.get_instance_id(), billboard, tint, windows]
	if _mats.has(key):
		return _mats[key]
	if billboard and not String(sm.resource_name).contains("_un"):
		var fm: = ShaderMaterial.new()
		fm.shader = FOLIAGE_SHADER
		fm.set_shader_parameter("albedo_tex", sm.albedo_texture)
		fm.set_shader_parameter("tint", tint)
		_mats[key] = fm
		return fm
	var out: = sm.duplicate()
	out.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	out.albedo_color = tint
	if billboard:
		out.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		out.billboard_keep_scale = true
	if windows:


		var mask: = _window_mask(sm.albedo_texture)
		if mask:
			out.emission_enabled = true
			out.emission_texture = mask
			out.emission = WINDOW_COLOR


			out.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			out.emission_energy_multiplier = 0.0
			out.set_meta("window_glow", true)


			out.set_meta("window_base", out.albedo_color)
	_mats[key] = out
	return out






static var _masks: = {}
static func _window_mask(tex: Texture2D) -> ImageTexture:
	if tex == null:
		return null
	if _masks.has(tex):
		return _masks[tex]

	if String(tex.resource_path).to_lower().contains("door"):
		_masks[tex] = null
		return null
	var img: = tex.get_image()
	if img == null or img.is_empty():
		_masks[tex] = null
		return null
	img = img.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	var w: = img.get_width()
	var h: = img.get_height()
	var seed: = false
	for y in h:
		for x in w:
			var c: = img.get_pixel(x, y)
			if c.a >= 0.5 and c.b - c.r >= 0.078 and c.b - c.g >= 0.059 and maxf(c.r, maxf(c.g, c.b)) >= 0.55:
				seed = true
				break
		if seed:
			break
	var out: = Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color.BLACK)
	var lit: = 0
	var tot: = 0
	for y in h:
		for x in w:
			var c: = img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			tot += 1
			var mx: = maxf(c.r, maxf(c.g, c.b))
			var mn: = minf(c.r, minf(c.g, c.b))
			var blue: = c.b - c.r >= 0.078 and c.b - c.g >= 0.059 and mx >= 0.55
			var white: = seed and mx >= 0.9 and mx - mn <= 0.078
			if blue or white:
				out.set_pixel(x, y, Color.WHITE)
				lit += 1
	if tot == 0 or float(lit) / float(tot) < WINDOW_MIN_COVER:
		_masks[tex] = null
		return null
	var it: = ImageTexture.create_from_image(out)
	_masks[tex] = it
	return it


static func _stylized(sm: StandardMaterial3D) -> ShaderMaterial:
	var m: = ShaderMaterial.new()
	m.shader = STYLIZE_SHADER
	m.resource_name = sm.resource_name
	m.set_shader_parameter("albedo", sm.albedo_color)
	if sm.albedo_texture:
		m.set_shader_parameter("use_tex", true)
		m.set_shader_parameter("albedo_tex", sm.albedo_texture)
	m.set_shader_parameter("is_foliage", String(sm.resource_name).begins_with("leafs"))
	return m




static func _hedge_material() -> ShaderMaterial:
	var sm: = StandardMaterial3D.new()
	sm.resource_name = "colormap"
	sm.albedo_color = Color(0.28, 0.52, 0.24)
	return _stylized(sm)


static func meshes(n: Node) -> Array:
	var out: Array = []
	var stack: Array = [n]
	while not stack.is_empty():
		var c = stack.pop_back()
		if c is MeshInstance3D:
			out.append(c)
		stack.append_array(c.get_children())
	return out



static func bounds(n: Node) -> AABB:
	var box: = AABB()
	var first: = true
	for mi in meshes(n):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func place(parent: Node, id: String, pos: Vector3, opts: = {}) -> Node3D:
	var hgss: = id.begins_with("hgss/")
	var root: String = opts.get("root", HGSS_ROOT if hgss else ROOT)
	var inst: Node3D = _scene(root + id + ".glb").instantiate()
	inst.name = id.get_file().validate_node_name()
	parent.add_child(inst)
	var s: = float(opts.get("scale", 1.0))
	inst.scale = Vector3.ONE * s
	inst.rotation_degrees.y = float(opts.get("rot", 0.0))
	inst.global_position = pos
	var tex: Texture2D = opts.get("texture", null)
	var palette: Dictionary = opts.get("palette", {})
	if id == "town/hedge":
		palette = palette.duplicate()
		palette["colormap"] = _hedge_material()
	var geoms: Array = []
	var window_mats: Array = []
	for mi: MeshInstance3D in meshes(inst):
		for i in mi.mesh.get_surface_count():
			var m: = mi.get_active_material(i)

			var r: = _hgss_material(m, bool(opts.get("billboard", false)), opts.get("tint", Color.WHITE), bool(opts.get("windows", false)))\
			if hgss else _remap(m, tex, palette, stylizes(id))
			if r != m:
				mi.set_surface_override_material(i, r)
			if r.has_meta("window_glow"):
				window_mats.append(r)
		if not opts.get("shadow", true):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var vr: = float(opts.get("vis_range", 0.0))
		if vr > 0.0:
			mi.visibility_range_end = vr
			mi.visibility_range_end_margin = 4.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		geoms.append(mi)
	inst.set_meta("geoms", geoms)
	match String(opts.get("collide", "")):
		"box":
			_box_collider(parent, bounds(inst))
		"trunk":
			var bb: = bounds(inst)
			_trunk_collider(parent, pos, maxf(bb.size.x * 0.18, 0.3), bb.size.y)
		"round":


			var rb: = bounds(inst)
			var r: = float(opts.get("collide_radius", maxf(rb.size.x, rb.size.z) * 0.5))
			_trunk_collider(parent, pos, maxf(r, 0.2), rb.size.y)
	match String(opts.get("fade", "")):
		"occluder":
			inst.add_to_group("fade_occluder")
			var bb: = bounds(inst)
			var r: = Rect2(bb.position.x, bb.position.z, bb.size.x, bb.size.z)
			inst.set_meta("rect", r)
			register_fader(inst, r)
		"building":
			var bb2: = bounds(inst)
			inst.add_to_group("fade_building")
			inst.set_meta("rect", Rect2(bb2.position.x, bb2.position.z, bb2.size.x, bb2.size.z))
			inst.set_meta("height", bb2.size.y)
			inst.set_meta("back_z", bb2.position.z)
			register_fader(inst, Rect2(bb2.position.x, bb2.position.z, bb2.size.x, bb2.size.z))
	if id == "town/lantern" or bool(opts.get("light", false)):
		_lantern_light(parent, inst)
	if not window_mats.is_empty():
		var nw: = NightLights.new()
		nw.window_mats = window_mats
		inst.add_child(nw)
	return inst




static func _lantern_light(parent: Node, inst: Node3D) -> void :
	var bb: = bounds(inst)


	var head: = Vector3(bb.get_center().x, bb.position.y + bb.size.y, bb.get_center().z)
	var r: = clampf(maxf(bb.size.x, bb.size.z) * 0.14, 0.1, 0.24)
	var gm: = StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(1.0, 0.8, 0.5)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.72, 0.35)
	gm.emission_energy_multiplier = 4.0
	var sphere: = SphereMesh.new()
	sphere.radius = r
	sphere.height = r * 2.0
	sphere.material = gm
	var glow: = MeshInstance3D.new()
	glow.mesh = sphere
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var host: Node3D = inst
	for mi: MeshInstance3D in meshes(inst):
		host = mi
		break
	host.add_child(glow)
	glow.global_position = head


	(inst.get_meta("geoms") as Array).append(glow)
	var light: = OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.5)
	light.light_energy = 6.0
	light.omni_range = 6.0
	light.omni_attenuation = 0.8
	light.shadow_enabled = false
	parent.add_child(light)

	light.global_position = head - Vector3(0, bb.size.y * 0.12, 0)

	var nl: = NightLights.new()
	nl.light = light
	nl.glow = glow
	parent.add_child(nl)




static func _box_collider(parent: Node, bb: AABB, min_h: = 1.0) -> StaticBody3D:
	var sb: = StaticBody3D.new()
	var cs: = CollisionShape3D.new()
	var sh: = BoxShape3D.new()
	var h: = maxf(bb.size.y, min_h)
	sh.size = Vector3(bb.size.x, h, bb.size.z)
	cs.shape = sh
	sb.add_child(cs)
	parent.add_child(sb)
	sb.global_position = Vector3(bb.get_center().x, bb.position.y + h / 2.0, bb.get_center().z)
	return sb


static func _trunk_collider(parent: Node, base: Vector3, radius: float, height: float) -> void :
	var sb: = StaticBody3D.new()
	var cs: = CollisionShape3D.new()
	var sh: = CylinderShape3D.new()
	sh.radius = radius
	sh.height = maxf(height, 1.5)
	cs.shape = sh
	sb.add_child(cs)
	parent.add_child(sb)
	sb.global_position = base + Vector3(0, sh.height / 2.0, 0)




static func wall(parent: Node, center: Vector3, size: Vector3) -> StaticBody3D:
	return _box_collider(parent, AABB(center - size / 2.0, size), 0.0)




static func place_fit(parent: Node, id: String, target: AABB, rot_deg: = 0.0, opts: = {}) -> Node3D:
	var o: = opts.duplicate()
	o["rot"] = rot_deg
	o["scale"] = 1.0
	o.erase("collide")
	o.erase("fade")
	var inst: = place(parent, id, target.get_center(), o)
	var bb: = bounds(inst)
	var swap: = absf(fmod(absf(rot_deg), 180.0) - 90.0) < 1.0
	var sx: = target.size.x / maxf(bb.size.x, 0.001)
	var sy: = target.size.y / maxf(bb.size.y, 0.001)
	var sz: = target.size.z / maxf(bb.size.z, 0.001)
	inst.scale = Vector3(sz, sy, sx) if swap else Vector3(sx, sy, sz)
	var bb2: = bounds(inst)
	inst.global_position += target.position - bb2.position
	return inst
