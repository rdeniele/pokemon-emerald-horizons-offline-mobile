@tool
extends Node3D





const SURFACE: = preload("res://shaders/interior_surface.gdshader")

@export var size: = Vector2(10, 8):
	set(v):
		size = v
		_rebuild()
@export var wall_height: = 2.8:
	set(v):
		wall_height = v
		_rebuild()
@export var floor_texture: Texture2D:
	set(v):
		floor_texture = v
		_rebuild()
@export var wall_texture: Texture2D:
	set(v):
		wall_texture = v
		_rebuild()
@export var wall_tint: = Color(1, 1, 1):
	set(v):
		wall_tint = v
		_rebuild()

@export var exit_x: = 0.0:
	set(v):
		exit_x = v
		_rebuild()

@export var exit_width: = 1.6:
	set(v):
		exit_width = v
		_rebuild()


@export var exit_north_x: = 0.0:
	set(v):
		exit_north_x = v
		_rebuild()
@export var exit_north_width: = 0.0:
	set(v):
		exit_north_width = v
		_rebuild()



@export var stairwell: = Rect2():
	set(v):
		stairwell = v
		_rebuild()
@export var stairwell_depth: = 2.2:
	set(v):
		stairwell_depth = v
		_rebuild()

@export var window_side: = 0:
	set(v):
		window_side = v
		_rebuild()
@export var window_offset: = 0.0:
	set(v):
		window_offset = v
		_rebuild()
@export var window_size: = Vector2(1.6, 1.4):
	set(v):
		window_size = v
		_rebuild()
@export var window_y: = 1.6:
	set(v):
		window_y = v
		_rebuild()
@export var window_mask: Texture2D:
	set(v):
		window_mask = v
		_rebuild()

@export var window_view: Texture2D:
	set(v):
		window_view = v
		_rebuild()
@export var window_trim: = Color(0.96, 0.95, 0.9):
	set(v):
		window_trim = v
		_rebuild()

@export var window_curtain: = Color(0, 0, 0, 0):
	set(v):
		window_curtain = v
		_rebuild()


@export var wainscot_height: = 0.0:
	set(v):
		wainscot_height = v
		_rebuild()
@export var wainscot_color: = Color(0.48, 0.61, 0.77):
	set(v):
		wainscot_color = v
		_rebuild()


func _ready() -> void :
	var _p1: = Time.get_ticks_usec()
	_build()
	P1Prof.acc("interior room shell build", Time.get_ticks_usec() - _p1)


func _rebuild() -> void :
	if is_inside_tree():
		_build()


func _mat(tex: Texture2D, tint: Color) -> ShaderMaterial:
	var m: = ShaderMaterial.new()
	m.shader = SURFACE
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("use_tex", tex != null)
	if tex:
		m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("tiles_per_meter", 0.5)
	return m


func _box(root: Node3D, center: Vector3, sz: Vector3, mat: Material, collide: bool, node_name: = "") -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var bm: = BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	root.add_child(mi)
	if node_name != "":
		mi.name = node_name
	if collide:
		_collider(root, center, sz)
	return mi


func _collider(root: Node3D, center: Vector3, sz: Vector3) -> void :
	var sb: = StaticBody3D.new()
	sb.position = center
	var cs: = CollisionShape3D.new()
	var sh: = BoxShape3D.new()
	sh.size = sz
	cs.shape = sh
	sb.add_child(cs)
	root.add_child(sb)


func _window(root: Node3D) -> void :
	var w: = size.x
	var d: = size.y
	var ws: = window_size

	var c: Vector3
	var u: Vector3
	var n: Vector3
	match window_side:
		1:
			c = Vector3(window_offset, window_y, - d / 2)
			u = Vector3(1, 0, 0)
			n = Vector3(0, 0, 1)
		2:
			c = Vector3( - w / 2, window_y, window_offset)
			u = Vector3(0, 0, -1)
			n = Vector3(1, 0, 0)
		_:
			c = Vector3(w / 2, window_y, window_offset)
			u = Vector3(0, 0, 1)
			n = Vector3(-1, 0, 0)
	var trim: = _mat(null, window_trim)
	var part: = func(cu: float, cv: float, cn: float, su: float, sv: float, sn: float, mat: Material) -> void :
		var pos: = c + u * cu + Vector3.UP * cv + n * cn
		var sz: = (u * su).abs() + Vector3.UP * sv + (n * sn).abs()
		_box(root, pos, sz, mat, false)

	var pane: = StandardMaterial3D.new()
	pane.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pane.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	pane.albedo_texture = window_view
	pane.albedo_color = Color(1.15, 1.15, 1.15) if window_view else Color(0.72, 0.86, 1.0)
	var pm: = MeshInstance3D.new()
	var bm: = BoxMesh.new()
	bm.size = (u * ws.x).abs() + Vector3.UP * ws.y + n.abs() * 0.02
	pm.mesh = bm
	pm.material_override = pane
	pm.position = c + n * 0.02
	pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pm)
	var f: = 0.09
	var depth: = 0.12
	part.call(0.0, ws.y / 2 + f / 2, depth / 2, ws.x + f * 2, f, depth, trim)
	part.call(0.0, - ws.y / 2 - f / 2, depth / 2, ws.x + f * 2, f, depth, trim)
	part.call( - ws.x / 2 - f / 2, 0.0, depth / 2, f, ws.y, depth, trim)
	part.call(ws.x / 2 + f / 2, 0.0, depth / 2, f, ws.y, depth, trim)

	part.call(0.0, 0.0, 0.05, 0.05, ws.y, 0.06, trim)
	part.call(0.0, 0.0, 0.05, ws.x, 0.05, 0.06, trim)

	part.call(0.0, - ws.y / 2 - f - 0.03, 0.12, ws.x + f * 2 + 0.16, 0.06, 0.24, trim)
	if window_curtain.a > 0.0:
		var cm: = _mat(null, window_curtain)
		var cw: = ws.x * 0.22
		part.call( - ws.x / 2 - f + cw / 2 - 0.04, 0.06, 0.16, cw, ws.y + 0.2, 0.05, cm)
		part.call(ws.x / 2 + f - cw / 2 + 0.04, 0.06, 0.16, cw, ws.y + 0.2, 0.05, cm)
		part.call(0.0, ws.y / 2 + f + 0.08, 0.17, ws.x + f * 2 + 0.2, 0.22, 0.07, cm)


func _wainscot(root: Node3D) -> void :
	var w: = size.x
	var d: = size.y
	var wh: = wainscot_height
	var t: = 0.05
	var band: = _mat(null, wainscot_color)
	var rail: = _mat(null, wainscot_color.darkened(0.3))
	var base: = _mat(null, wainscot_color.darkened(0.45))


	for seg in _back_spans(w):
		var sw: float = seg[1] - seg[0]
		if sw <= 0.01:
			continue
		var c: float = (seg[0] + seg[1]) / 2.0
		_box(root, Vector3(c, wh / 2, - d / 2 + t / 2), Vector3(sw, wh, t), band, false, "Wainscot")
		_box(root, Vector3(c, wh, - d / 2 + t), Vector3(sw, 0.08, t * 2), rail, false, "Wainscot")
		_box(root, Vector3(c, 0.07, - d / 2 + t), Vector3(sw, 0.14, t * 2.4), base, false, "Wainscot")
	_box(root, Vector3( - w / 2 + t / 2, wh / 2, 0), Vector3(t, wh, d), band, false)
	_box(root, Vector3(w / 2 - t / 2, wh / 2, 0), Vector3(t, wh, d), band, false)
	_box(root, Vector3( - w / 2 + t, wh, 0), Vector3(t * 2, 0.08, d), rail, false)
	_box(root, Vector3(w / 2 - t, wh, 0), Vector3(t * 2, 0.08, d), rail, false)
	_box(root, Vector3( - w / 2 + t, 0.07, 0), Vector3(t * 2.4, 0.14, d), base, false)
	_box(root, Vector3(w / 2 - t, 0.07, 0), Vector3(t * 2.4, 0.14, d), base, false)





func _north_doorway(root: Node3D, oh: float) -> void :
	var d: = size.y
	var x: = exit_north_x
	var ow: = exit_north_width
	var z: = - d / 2.0

	var bands: = 4
	for i in bands:
		var bh: = oh / bands
		var shade: = Color(0.15, 0.15, 0.18).lerp(Color(0.03, 0.03, 0.04), float(i) / float(bands - 1))
		_box(root, Vector3(x, bh * (i + 0.5), z - 0.02), Vector3(ow, bh, 0.04), _mat(null, shade), false, "DoorOpening")

	var fw: = 0.14
	var fd: = 0.16
	var wood: = _mat(null, Color(0.36, 0.24, 0.15))
	_box(root, Vector3(x - ow / 2 - fw / 2, (oh + fw) / 2, z + fd / 2), Vector3(fw, oh + fw, fd), wood, false, "DoorFrame")
	_box(root, Vector3(x + ow / 2 + fw / 2, (oh + fw) / 2, z + fd / 2), Vector3(fw, oh + fw, fd), wood, false, "DoorFrame")
	_box(root, Vector3(x, oh + fw / 2, z + fd / 2), Vector3(ow + fw * 2, fw, fd), wood, false, "DoorFrame")
	_box(root, Vector3(x, 0.02, z + fd / 2), Vector3(ow, 0.04, fd), wood, false, "DoorFrame")




func _floor_with_well(root: Node3D, fm: Material) -> void :
	var w: = size.x
	var d: = size.y
	var r: = stairwell
	var x0: = - w / 2
	var x1: = w / 2
	var z0: = - d / 2
	var z1: = d / 2
	var slabs: = [
		Rect2(x0, z0, w, r.position.y - z0), 
		Rect2(x0, r.end.y, w, z1 - r.end.y), 
		Rect2(x0, r.position.y, r.position.x - x0, r.size.y), 
		Rect2(r.end.x, r.position.y, x1 - r.end.x, r.size.y), 
	]
	for s: Rect2 in slabs:
		if s.size.x > 0.01 and s.size.y > 0.01:
			_box(root, Vector3(s.get_center().x, -0.1, s.get_center().y), Vector3(s.size.x, 0.2, s.size.y), fm, false)
	_collider(root, Vector3(0, -0.1, 0), Vector3(w, 0.2, d))
	var dd: = stairwell_depth
	var dark: = _mat(null, Color(0.5, 0.38, 0.26))
	var floor_dark: = _mat(null, Color(0.16, 0.12, 0.09))
	var c: = r.get_center()
	_box(root, Vector3(r.position.x - 0.05, - dd / 2, c.y), Vector3(0.1, dd, r.size.y), dark, false)
	_box(root, Vector3(r.end.x + 0.05, - dd / 2, c.y), Vector3(0.1, dd, r.size.y), dark, false)
	_box(root, Vector3(c.x, - dd / 2, r.position.y - 0.05), Vector3(r.size.x + 0.2, dd, 0.1), dark, false)
	_box(root, Vector3(c.x, - dd / 2, r.end.y + 0.05), Vector3(r.size.x + 0.2, dd, 0.1), dark, false)
	_box(root, Vector3(c.x, - dd - 0.05, c.y), Vector3(r.size.x + 0.2, 0.1, r.size.y + 0.2), floor_dark, false)




func _back_spans(w: float) -> Array:
	if exit_north_width <= 0.0:
		return [[ - w / 2, w / 2]]
	return [[ - w / 2, exit_north_x - exit_north_width / 2.0], [exit_north_x + exit_north_width / 2.0, w / 2]]


func _build() -> void :
	var old: = get_node_or_null("_Generated")
	if old:
		remove_child(old)
		old.free()
	var root: = Node3D.new()
	root.name = "_Generated"
	add_child(root)
	var fm: = _mat(floor_texture, Color.WHITE)
	var wm: = _mat(wall_texture, wall_tint)
	var trim: = _mat(null, wall_tint.darkened(0.45))
	var w: = size.x
	var d: = size.y
	var h: = wall_height

	if stairwell.has_area():
		_floor_with_well(root, fm)
	else:
		_box(root, Vector3(0, -0.1, 0), Vector3(w, 0.2, d), fm, true)


	if exit_north_width > 0.0:
		var oh: = minf(2.2, h)
		for seg in _back_spans(w):
			var nsw: float = seg[1] - seg[0]
			if nsw <= 0.01:
				continue
			var ncx: float = (seg[0] + seg[1]) / 2.0
			_box(root, Vector3(ncx, h / 2, - d / 2 - 0.15), Vector3(nsw, h, 0.3), wm, true)

		_box(root, Vector3(exit_north_x, (h + oh) / 2, - d / 2 - 0.15), Vector3(exit_north_width, h - oh, 0.3), wm, false)
		_north_doorway(root, oh)
	else:
		_box(root, Vector3(0, h / 2, - d / 2 - 0.15), Vector3(w + 0.6, h, 0.3), wm, true)
	_box(root, Vector3( - w / 2 - 0.15, h / 2, 0), Vector3(0.3, h, d), wm, true)
	_box(root, Vector3(w / 2 + 0.15, h / 2, 0), Vector3(0.3, h, d), wm, true)
	if wainscot_height > 0.0:
		_wainscot(root)
	else:
		for seg in _back_spans(w):
			var sw: float = seg[1] - seg[0]
			if sw <= 0.01:
				continue
			_box(root, Vector3((seg[0] + seg[1]) / 2.0, 0.12, - d / 2 + 0.03), Vector3(sw, 0.24, 0.06), trim, false)
	if window_side > 0:
		_window(root)

	var segs: = [[ - w / 2, exit_x - exit_width / 2], [exit_x + exit_width / 2, w / 2]]
	if exit_width <= 0.0:
		segs = [[ - w / 2, w / 2]]
	for seg in segs:
		var sw: float = seg[1] - seg[0]
		if sw <= 0.01:
			continue
		var cx: float = (seg[0] + seg[1]) / 2.0
		_box(root, Vector3(cx, 0.3, d / 2 + 0.15), Vector3(sw, 0.6, 0.3), wm, false)
		_collider(root, Vector3(cx, 1.5, d / 2 + 0.15), Vector3(sw, 3, 0.3))

	if exit_width > 0.0:
		var mat_m: = _mat(null, Color(0.55, 0.22, 0.2))
		_box(root, Vector3(exit_x, 0.01, d / 2 - 0.45), Vector3(exit_width, 0.02, 0.8), mat_m, false)
		_box(root, Vector3(exit_x, -0.1, d / 2 + 1.0), Vector3(exit_width, 0.2, 2.0), fm, true)
		_collider(root, Vector3(exit_x - exit_width / 2 - 0.15, 1.5, d / 2 + 1.0), Vector3(0.3, 3, 2))
		_collider(root, Vector3(exit_x + exit_width / 2 + 0.15, 1.5, d / 2 + 1.0), Vector3(0.3, 3, 2))
		_collider(root, Vector3(exit_x, 1.5, d / 2 + 2.15), Vector3(exit_width, 3, 0.3))

	if exit_north_width > 0.0:
		var nmat: = _mat(null, Color(0.55, 0.22, 0.2))
		_box(root, Vector3(exit_north_x, 0.01, - d / 2 + 0.45), Vector3(exit_north_width, 0.02, 0.8), nmat, false)
		_box(root, Vector3(exit_north_x, -0.1, - d / 2 - 1.0), Vector3(exit_north_width, 0.2, 2.0), fm, true)
		_collider(root, Vector3(exit_north_x - exit_north_width / 2 - 0.15, 1.5, - d / 2 - 1.0), Vector3(0.3, 3, 2))
		_collider(root, Vector3(exit_north_x + exit_north_width / 2 + 0.15, 1.5, - d / 2 - 1.0), Vector3(0.3, 3, 2))
		_collider(root, Vector3(exit_north_x, 1.5, - d / 2 - 2.15), Vector3(exit_north_width, 3, 0.3))
