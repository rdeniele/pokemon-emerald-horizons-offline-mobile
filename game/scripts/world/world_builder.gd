@tool
extends Node3D














signal built
signal decorated

const Props: = preload("res://scripts/world/props.gd")
const LEDGE_SCRIPT: = "res://scripts/world/ledge.gd"
const TEX_GRASS: = preload("res://assets/textures/ground_grass.png")
const GROUND_SHADER: = preload("res://shaders/ground.gdshader")
const CliffWall: = preload("res://scripts/world/terrain/cliff_wall.gd")
const GrassLip: = preload("res://scripts/world/terrain/grass_lip.gd")
const Steps: = preload("res://scripts/world/terrain/steps.gd")
const PathMask: = preload("res://scripts/world/terrain/path_mask.gd")
const WATER_MAT: = preload("res://resources/look/water.tres")
const SUN_SHAFT: = preload("res://scripts/world/sun_shaft.gd")
const ROOFS: = {
	"red": "res://assets/models/kenney/suburban/Textures/colormap_roof_red.png", 
	"slate": "res://assets/models/kenney/suburban/Textures/colormap_roof_slate.png", 
	"blue": "res://assets/models/kenney/suburban/Textures/colormap_roof_blue.png", 
	"green": "res://assets/models/kenney/suburban/Textures/colormap_roof_green.png", 
}
const RAMP_SLOPE: = 2.8
const EDGE_WALL: = 1.6
const RAMP_WALL_MIN_DROP: = 0.2
const GROUND_LAYERS: = 1 | 4

const WATER_LAYER: = 8

@export_file("*.json") var map_file: = ""
@export var rebuild: = false:
	set(v):
		rebuild = false
		if v and is_inside_tree():
			build()
@export var tree_view_range: = 70.0


@export var mask_dir: = "res://data/masks"


@export var frame_budget: = 120


@export var frame_ms: = 8.0

const GL_BUDGET: = 30

var data: = {}
var is_built: = false
var is_decorated: = false
var canopy: Node3D
var _root: Node3D
var _rng: = RandomNumberGenerator.new()
var _budget: = 0
var _work_usec: = 0
var _max_work: = 0
var _per_frame: = 0
var _limit_usec: = 0


func _ready() -> void :
	build()


func build() -> void :
	is_built = false
	is_decorated = false
	var old: = get_node_or_null("_Generated")
	if old:
		remove_child(old)
		old.free()
	_root = Node3D.new()
	_root.name = "_Generated"
	add_child(_root)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(map_file))
	if not parsed is Dictionary:
		push_error("world_builder: cannot read %s" % map_file)
		return
	data = parsed
	_rng.seed = hash(map_file)
	var gl: = _on_gl() and frame_budget > 0
	_per_frame = GL_BUDGET if gl else frame_budget
	_limit_usec = int(frame_ms * 1000.0 * (0.5 if gl else 1.0))
	_new_frame()

	var _p1_tag: String = map_file.get_file().get_basename()
	var _p1_all: = Time.get_ticks_usec()
	var _p1_f0: = Engine.get_frames_drawn()
	var _p1_t: = Time.get_ticks_usec()
	var _p1_f: = Engine.get_frames_drawn()

	await _plateaus()
	P1Prof.step(_p1_tag, "plateaus", _p1_t, _p1_f)
	_p1_t = Time.get_ticks_usec();_p1_f = Engine.get_frames_drawn()
	await _paths()
	P1Prof.step(_p1_tag, "paths", _p1_t, _p1_f)
	_p1_t = Time.get_ticks_usec();_p1_f = Engine.get_frames_drawn()
	await _water()
	P1Prof.step(_p1_tag, "water", _p1_t, _p1_f)
	_p1_t = Time.get_ticks_usec();_p1_f = Engine.get_frames_drawn()
	await _buildings()
	P1Prof.step(_p1_tag, "buildings", _p1_t, _p1_f)
	_p1_t = Time.get_ticks_usec();_p1_f = Engine.get_frames_drawn()
	await _fences()
	P1Prof.step(_p1_tag, "fences", _p1_t, _p1_f)
	_p1_t = Time.get_ticks_usec();_p1_f = Engine.get_frames_drawn()
	await _props()
	P1Prof.step(_p1_tag, "props", _p1_t, _p1_f)
	_p1_t = Time.get_ticks_usec();_p1_f = Engine.get_frames_drawn()
	_walls()
	P1Prof.step(_p1_tag, "walls", _p1_t, _p1_f)
	P1Prof.step(_p1_tag, "BUILD playable", _p1_all, _p1_f0)
	P1Prof.span("%s longest playable frame" % _p1_tag, _max_work)
	is_built = true
	built.emit()

	_max_work = 0
	_p1_t = Time.get_ticks_usec();_p1_f = Engine.get_frames_drawn()
	await _tree_lines()
	P1Prof.step(_p1_tag, "tree_lines", _p1_t, _p1_f)
	_p1_t = Time.get_ticks_usec();_p1_f = Engine.get_frames_drawn()
	await _trees()
	P1Prof.step(_p1_tag, "trees", _p1_t, _p1_f)
	_p1_t = Time.get_ticks_usec();_p1_f = Engine.get_frames_drawn()
	await _canopy()
	P1Prof.step(_p1_tag, "canopy", _p1_t, _p1_f)
	_p1_t = Time.get_ticks_usec();_p1_f = Engine.get_frames_drawn()
	await _flowers()
	P1Prof.step(_p1_tag, "flowers", _p1_t, _p1_f)
	_p1_t = Time.get_ticks_usec();_p1_f = Engine.get_frames_drawn()
	await _scatter()
	P1Prof.step(_p1_tag, "scatter", _p1_t, _p1_f)
	_p1_t = Time.get_ticks_usec();_p1_f = Engine.get_frames_drawn()
	await _sun_shafts()
	P1Prof.step(_p1_tag, "sun_shafts", _p1_t, _p1_f)
	P1Prof.step(_p1_tag, "BUILD decorated", _p1_all, _p1_f0)
	P1Prof.span("%s longest visual frame" % _p1_tag, _max_work)
	is_decorated = true
	decorated.emit()



func _on_gl() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


func _new_frame() -> void :
	_budget = _per_frame
	_work_usec = Time.get_ticks_usec()





func boost_build() -> void :
	if Engine.is_editor_hint() or frame_budget <= 0:
		return
	_per_frame = maxi(_per_frame, 900)
	_limit_usec = maxi(_limit_usec, 40000)











func _tick() -> bool:
	if Engine.is_editor_hint() or frame_budget <= 0:
		return true
	if not is_inside_tree():
		return false
	_budget -= 1
	var work: = Time.get_ticks_usec() - _work_usec
	if work < _limit_usec and (_budget > 0 or work * 2 < _limit_usec):
		return true
	_max_work = maxi(_max_work, work)
	await get_tree().process_frame
	_new_frame()
	return is_inside_tree()


func _group(n: String) -> Node3D:
	var g: = Node3D.new()
	g.name = n
	_root.add_child(g)
	return g




func height_at(x: float, z: float) -> float:
	return PathMask.height_at(data, x, z)


func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), height_at(float(a[0]), float(a[1])), float(a[1]))




func _ground_mat() -> ShaderMaterial:
	var gm: = ShaderMaterial.new()
	gm.shader = GROUND_SHADER
	gm.set_shader_parameter("albedo_tex", TEX_GRASS)
	return gm


func _plane(parent: Node3D, center: Vector3, size: Vector2, mat: Material) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var pm: = PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = mat
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _box_mesh(parent: Node3D, center: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var bm: = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	parent.add_child(mi)
	return mi






func _plateaus() -> void :
	var plist: Array = data.get("plateaus", [])
	if plist.is_empty():
		return
	var g: = _group("Terraces")
	var top: = _ground_mat()
	for p in plist:
		var r: Array = p.rect
		var h: = float(p.h)
		var c: = Vector3(r[0] + r[2] / 2.0, 0, r[1] + r[3] / 2.0)
		var block: = Node3D.new()
		block.name = String(p.id).to_pascal_case()
		g.add_child(block)
		_plane(block, c + Vector3(0, h + 0.002, 0), Vector2(r[2], r[3]), top)
		await _earth_walls(block, p, h)
		Props.wall(block, c + Vector3(0, h / 2.0, 0), Vector3(r[2], h, r[3])).collision_layer = GROUND_LAYERS

		block.set_meta("geoms", block.find_children("*", "GeometryInstance3D", true, false))
		block.set_meta("rect", Rect2(r[0], r[1], r[2], r[3]))
		block.set_meta("height", h + 1.5)
		block.set_meta("back_z", float(r[1]))
		block.add_to_group("fade_building")
		Props.register_fader(block, Rect2(r[0], r[1], r[2], r[3]))
		_edge_walls(block, p, h)
		for s in p.get("ramps", []):
			_ramp(block, p, s)
		for l in p.get("ledges", []):
			_ledge(block, p, l)
		if not await _tick():
			return



func _cuts(p: Dictionary) -> Dictionary:
	var cuts: = {}
	for s in p.get("ramps", []):
		cuts[s.side] = cuts.get(s.side, []) + [[float(s.at) - float(s.width) / 2.0, float(s.at) + float(s.width) / 2.0]]
	for l in p.get("ledges", []):
		cuts[l.side] = cuts.get(l.side, []) + [[float(l.from), float(l.to)]]
	var r: Array = p.rect
	for side in p.get("open", []):
		var horizontal: bool = side == "n" or side == "s"
		var a: float = r[0] if horizontal else r[1]
		var b: float = r[0] + r[2] if horizontal else r[1] + r[3]
		cuts[side] = cuts.get(side, []) + [[a, b]]
	return cuts



func _earth_walls(block: Node3D, p: Dictionary, h: float) -> void :
	var r: Array = p.rect
	var top_at: = func(_x: float, _z: float) -> float: return h
	var base_at: = func(x: float, z: float) -> float: return _height_excluding(x, z, p)
	var i: = 0
	for line in CliffWall.outline(Rect2(r[0], r[1], r[2], r[3]), _cuts(p)):
		var wall_seed: = hash(String(p.id)) + i
		var mi: = MeshInstance3D.new()
		mi.name = "Wall%d" % i
		mi.mesh = CliffWall.build(line.points, line.normals, line.closed, top_at, base_at, wall_seed)
		mi.material_override = CliffWall.material()
		block.add_child(mi)
		block.add_child(GrassLip.build(line.points, line.normals, top_at, wall_seed + 100))
		i += 1
		if not await _tick():
			return



func _edge_walls(parent: Node3D, p: Dictionary, h: float) -> void :
	var r: Array = p.rect
	for side in ["n", "s", "w", "e"]:
		var horizontal: bool = side == "n" or side == "s"
		var a: float = r[0] if horizontal else r[1]
		var b: float = r[0] + r[2] if horizontal else r[1] + r[3]
		var fixed: float = (r[1] if side == "n" else r[1] + r[3]) if horizontal else (r[0] if side == "w" else r[0] + r[2])
		var cuts: Array = _cuts(p).get(side, [])
		cuts.sort_custom( func(u, v): return u[0] < v[0])
		var segs: Array = []
		var cur: = a
		for cut in cuts:
			if cut[0] > cur:
				segs.append([cur, cut[0]])
			cur = maxf(cur, cut[1])
		if cur < b:
			segs.append([cur, b])
		for sg in segs:
			var mid: float = (sg[0] + sg[1]) / 2.0
			var len: float = sg[1] - sg[0]
			var center: = Vector3(mid, h + EDGE_WALL / 2.0, fixed) if horizontal else Vector3(fixed, h + EDGE_WALL / 2.0, mid)
			var size: = Vector3(len, EDGE_WALL, 0.2) if horizontal else Vector3(0.2, EDGE_WALL, len)
			Props.wall(parent, center, size)




func _ramp(parent: Node3D, p: Dictionary, s: Dictionary) -> void :
	var r: Array = p.rect
	var h: = float(p.h)
	var side: String = s.side
	var w: = float(s.width)
	var at: = float(s.at)
	var out: = {"n": Vector3(0, 0, -1), "s": Vector3(0, 0, 1), "w": Vector3(-1, 0, 0), "e": Vector3(1, 0, 0)}[side] as Vector3
	var edge: Vector3
	match side:
		"n": edge = Vector3(at, 0, r[1])
		"s": edge = Vector3(at, 0, r[1] + r[3])
		"w": edge = Vector3(r[0], 0, at)
		_: edge = Vector3(r[0] + r[2], 0, at)
	var probe: = edge + out * 0.5
	var base: = _height_excluding(probe.x, probe.z, p)
	var rise: = h - base
	var run: = rise * RAMP_SLOPE
	var lateral: = Vector3(absf(out.z), 0, absf(out.x))
	var top_a: = edge + lateral * (w / 2.0) + Vector3(0, h, 0)
	var top_b: = edge - lateral * (w / 2.0) + Vector3(0, h, 0)
	var foot_a: = top_a + out * run + Vector3(0, - rise, 0)
	var foot_b: = top_b + out * run + Vector3(0, - rise, 0)
	var under_a: = top_a + Vector3(0, - rise, 0)
	var under_b: = top_b + Vector3(0, - rise, 0)
	var surf: = MeshInstance3D.new()
	surf.name = "RampSurface"
	surf.mesh = Steps.build(top_a, top_b, foot_a, foot_b)
	surf.material_override = Steps.material()
	parent.add_child(surf)

	for cheek_side in [[top_a, foot_a, lateral], [top_b, foot_b, - lateral]]:
		var t0: Vector3 = cheek_side[0]
		var t1: Vector3 = cheek_side[1]
		var nrm: = Vector2(cheek_side[2].x, cheek_side[2].z)
		var pts: = PackedVector2Array()
		var nrms: = PackedVector2Array()
		var steps: = maxi(int(ceil(run / 0.25)), 1)
		for k in steps + 1:
			var q: = t0.lerp(t1, float(k) / steps)
			pts.append(Vector2(q.x, q.z))
			nrms.append(nrm)
		var cheek_top: = func(x: float, z: float) -> float:
			return Steps.height_at(rise, run, base, Vector2(x - t0.x, z - t0.z).length())
		var cheek: = MeshInstance3D.new()
		cheek.name = "RampCheek"
		cheek.mesh = CliffWall.build(pts, nrms, false, cheek_top, func(_x: float, _z: float) -> float: return base, hash(String(p.id)) + 7)
		cheek.material_override = CliffWall.material()
		parent.add_child(cheek)

	var sb: = StaticBody3D.new()
	sb.collision_layer = GROUND_LAYERS
	var cs: = CollisionShape3D.new()
	var shape: = ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([top_a, top_b, foot_a, foot_b, under_a, under_b])
	cs.shape = shape
	sb.add_child(cs)
	parent.add_child(sb)






	var wall_len: = run * clampf(1.0 - RAMP_WALL_MIN_DROP / maxf(rise, 0.001), 0.0, 1.0)
	if wall_len > 0.01:
		var wall_h: = rise + EDGE_WALL
		for cheek_off: Vector3 in [lateral * (w / 2.0), lateral * ( - w / 2.0)]:
			var center: Vector3 = edge + cheek_off + out * (wall_len / 2.0)
			center.y = base + wall_h / 2.0
			var size: = Vector3(wall_len, wall_h, 0.2) if absf(out.x) > 0.5 else Vector3(0.2, wall_h, wall_len)
			Props.wall(parent, center, size)



func _ledge(parent: Node3D, p: Dictionary, l: Dictionary) -> void :
	var r: Array = p.rect
	var h: = float(p.h)
	var a: = float(l.from)
	var b: = float(l.to)
	var n: = Node3D.new()
	n.set_script(load(LEDGE_SCRIPT))
	n.set("length", b - a)
	var pos: Vector3
	var yaw: = 0.0
	match String(l.side):
		"s":
			pos = Vector3((a + b) / 2.0, h, r[1] + r[3])
		"n":
			pos = Vector3((a + b) / 2.0, h, r[1])
			yaw = PI
		"e":
			pos = Vector3(r[0] + r[2], h, (a + b) / 2.0)
			yaw = PI / 2.0
		_:
			pos = Vector3(r[0], h, (a + b) / 2.0)
			yaw = - PI / 2.0
	var probe: = pos + Basis(Vector3.UP, yaw).z * 0.6
	n.set("drop", h - _height_excluding(probe.x, probe.z, p))
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)



func _height_excluding(x: float, z: float, skip: Dictionary) -> float:
	var h: = 0.0
	for p in data.get("plateaus", []):
		if p == skip:
			continue
		var r: Array = p.rect
		if x >= r[0] and x <= r[0] + r[2] and z >= r[1] and z <= r[1] + r[3]:
			h = maxf(h, float(p.h))
	return h






func _paths() -> void :
	var g: = _group("Paths")
	var lv: = PathMask.levels(data.paths, height_at)


	var look: Dictionary = data.get("look", {})
	var tint: = Color(String(look.get("path_tint", "#ffffff")))
	var mix: = float(look.get("path_mix", 0.0))
	var zid: = map_file.get_file().get_basename()
	var i: = 0
	for level in lv:
		var path: = PathMask.mask_file(zid, i, mask_dir)
		var img: = PathMask.load_mask(path)
		if img == null:
			push_error("world_builder: missing path mask %s — run tools/gen_masks.gd" % path)
		else:
			g.add_child(PathMask.overlay(lv[level], float(level), img, tint, mix))
		i += 1
		if not await _tick():
			return







func _water() -> void :
	var g: = _group("Water")
	var mat: = WATER_MAT as ShaderMaterial
	mat.set_shader_parameter("shallow_width", Water.SHALLOW_WIDTH)
	var margin: = float(mat.get_shader_parameter("margin"))
	for w in data.water:
		var r: Array = w.rect
		var c: = Vector3(r[0] + r[2] / 2.0, 0.0, r[1] + r[3] / 2.0)
		var mi: = _plane(g, c + Vector3(0, 0.04, 0), Vector2(r[2] + margin * 2.0, r[3] + margin * 2.0), mat)
		mi.set_instance_shader_parameter("centre", Vector2(c.x, c.z))
		mi.set_instance_shader_parameter("half_size", Vector2(r[2] / 2.0, r[3] / 2.0))
		for k in 10:
			var p: = c + Vector3(_rng.randf_range( - r[2], r[2]) * 0.5, 0, _rng.randf_range( - r[3], r[3]) * 0.5)
			Props.place(g, "nature/lily_large" if k % 2 == 0 else "nature/lily_small", p + Vector3(0, 0.08, 0), 
				{"scale": 2.0, "rot": _rng.randi_range(0, 359), "shadow": false})
			if not await _tick():
				return




func _buildings() -> void :
	var g: = _group("Buildings")
	for b in data.buildings:


		var tex: Texture2D = null
		if b.has("tex"):
			tex = load(String(b["tex"]))
		elif b.has("roof") and ROOFS.has(b.roof):
			tex = load(ROOFS[b.roof])
		var inst: = Props.place(g, b.model, _v(b.pos), {"scale": b.get("scale", 5.0), "texture": tex, 
			"collide": "box", "fade": "building", "windows": true})
		inst.name = String(b.id).to_pascal_case()
		if b.has("board"):
			_board(g, inst, b)
		if not await _tick():
			return











const BOARD_SCALE_HGSS: = 0.6

func _board(parent: Node3D, inst: Node3D, b: Dictionary) -> void :
	var bd: Dictionary = b.board
	var bs: = float(bd.get("scale", BOARD_SCALE_HGSS if String(b.model).begins_with("hgss/") else 1.0))
	var r: Rect2 = inst.get_meta("rect")
	var col: = Color(String(bd.get("color", "#d84a3a")))
	var ground: = _v(b.pos).y
	var door_x: = float(b.pos[0]) + float(b.get("door_dx", 0.0))
	var front: = r.end.y
	var parts: Array = []

	parts.append(_slab(parent, Vector3(door_x, ground + 0.03 * bs, front + 0.6 * bs), Vector3(2.8, 0.06, 1.2) * bs, col.lightened(0.55)))
	parts.append(_slab(parent, Vector3(door_x, ground + 0.05 * bs, front + 0.6 * bs), Vector3(2.4, 0.06, 0.9) * bs, col))

	var text: = String(bd.text)
	var ball: = bool(bd.get("ball", false))
	var lines: = text.split("\n")
	var longest: = 0
	for l in lines:
		longest = maxi(longest, l.length())
	var letter: = float(bd.get("letter", 0.42)) * bs
	var w: = longest * letter * 0.68 + ((0.95 if ball else 0.0) + 0.6) * bs
	var hgt: = lines.size() * letter * 1.25 + 0.35 * bs
	var side: = float(bd.get("side", 1.0))
	var at: = Vector3(door_x + side * (1.9 * bs + w / 2.0), ground + 0.55 * bs + hgt / 2.0, front + 0.7 * bs)
	parts.append(_slab(parent, at, Vector3(w, hgt, 0.14 * bs), col))
	parts.append(_slab(parent, at + Vector3(0, hgt / 2.0 + 0.04 * bs, 0), Vector3(w + 0.12 * bs, 0.08 * bs, 0.2 * bs), col.lightened(0.55)))
	for px in [ - w / 2.0 + 0.25 * bs, w / 2.0 - 0.25 * bs]:
		parts.append(_slab(parent, Vector3(at.x + px, ground + 0.3 * bs, at.z), Vector3(0.12, 0.6, 0.12) * bs, Color(0.35, 0.33, 0.32)))
	Props.wall(parent, Vector3(at.x, ground + 0.6 * bs, at.z), Vector3(w, 1.2 * bs, 0.3 * bs))
	var label: = Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = letter / 64.0 * 1.35
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 0.5)
	label.modulate = Color.WHITE
	label.shaded = false
	parent.add_child(label)
	label.global_position = at + Vector3(0.45 * bs if ball else 0.0, 0.0, 0.08 * bs)
	parts.append(label)
	if ball:
		var spr: = Sprite3D.new()
		spr.texture = _ball_texture()
		spr.pixel_size = 0.7 * bs / 64.0
		spr.shaded = false
		parent.add_child(spr)
		spr.global_position = at + Vector3( - w / 2.0 + 0.6 * bs, 0.0, 0.09 * bs)
		parts.append(spr)
	var geoms: Array = inst.get_meta("geoms", [])
	geoms.append_array(parts)
	inst.set_meta("geoms", geoms)


func _slab(parent: Node3D, center: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var bm: = BoxMesh.new()
	bm.size = size
	var mat: = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.7
	bm.material = mat
	mi.mesh = bm
	parent.add_child(mi)
	mi.global_position = center
	return mi


static var _ball_tex: Texture2D

static func _ball_texture() -> Texture2D:
	if _ball_tex:
		return _ball_tex
	var img: = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var c: = Vector2(31.5, 31.5)
	for y in 64:
		for x in 64:
			var d: = Vector2(x, y).distance_to(c)
			var col: = Color(0, 0, 0, 0)
			if d <= 30.0:
				col = Color(0.88, 0.16, 0.16) if y < 29 else Color(0.97, 0.97, 0.95)
				if d > 27.5 or absf(y - 31.5) < 3.0:
					col = Color(0.08, 0.08, 0.1)
				if d < 9.0:
					col = Color(0.08, 0.08, 0.1)
				if d < 6.0:
					col = Color(0.97, 0.97, 0.95)
			img.set_pixel(x, y, col)
	_ball_tex = ImageTexture.create_from_image(img)
	return _ball_tex




const HGSS_TREE_TINT: = Color(0.74, 0.86, 0.72)



const HGSS_SCALE: = 0.8
const KENNEY_TREE_SCALE: = 3.2

const HGSS_TREE: = "hgss/common/tree"
const HGSS_BUSH: = "hgss/common/bush"


func _tree(parent: Node3D, p: Vector3, models: Array, scale: = 0.0, collide: = true) -> void :
	var id: String = models[_rng.randi() % models.size()]



	var hgss: = id.begins_with("hgss/")
	if scale == 0.0:
		scale = HGSS_SCALE if hgss else KENNEY_TREE_SCALE
	var opts: = {"scale": scale * _rng.randf_range(0.9, 1.15), "rot": _rng.randi_range(0, 359), 
		"collide": "trunk" if collide else "", "fade": "occluder", "vis_range": tree_view_range}
	if hgss:


		opts["billboard"] = true
		opts["tint"] = HGSS_TREE_TINT
		var hinst: = Props.place(parent, id, p, opts)
		hinst.add_to_group("leaf_source")
		return
	var pal: = _palette(data.get("look", {}).get("tree_palette", {}))
	if not pal.is_empty():
		opts["palette"] = pal
	var inst: = Props.place(parent, id, p, opts)
	inst.add_to_group("leaf_source")

	var w: = _rng.randf_range(1.2, 1.4)
	inst.scale *= Vector3(w, 1.0, w)



func _model_width(id: String, scale: float) -> float:
	var probe: = Props.place(self, id, Vector3.ZERO, {"scale": scale})
	var w: = Props.bounds(probe).size.x
	probe.free()
	return w


func _tree_lines() -> void :
	var g: = _group("TreeLines")
	for t in data.tree_lines:
		var a: = Vector3(t.from[0], 0, t.from[1])
		var b: = Vector3(t.to[0], 0, t.to[1])
		var out: = Vector3(t.get("out", [0, 0])[0], 0, t.get("out", [0, 0])[1])



		var step: = 2.3
		var row_off: = 2.1
		var stagger: = 1.15
		if String(t.models[0]).begins_with("hgss/"):
			var w: = _model_width(String(t.models[0]), HGSS_SCALE)
			step = w * 0.85
			row_off = w * 0.85
			stagger = w * 0.5
		var n: = maxi(int(a.distance_to(b) / step), 1)
		for row in int(t.get("rows", 2)):
			var off: = out * (row * row_off) + (Vector3.ZERO if row % 2 == 0 else (b - a).normalized() * stagger)
			for i in n + 1:
				var p: = a.lerp(b, float(i) / n) + off
				p += Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
				p.y = height_at(p.x, p.z)
				_tree(g, p, t.models)
				if not await _tick():
					return


func _trees() -> void :
	var g: = _group("Trees")
	for t in data.trees:
		_tree(g, _v(t.pos), [t.model], 0.0, not bool(t.get("cover", false)))
		if not await _tick():
			return








func _canopy() -> void :
	var cfg: Variant = data.get("look", {}).get("canopy", null)
	if not (cfg is Dictionary):
		return
	var r: Array = data.rect
	var step: = maxf(float(cfg.get("step", 1.6)), 0.5)
	var base_scale: = float(cfg.get("scale", HGSS_SCALE))
	var ids: Array = cfg.get("models", [HGSS_TREE])
	var g: = _group("Canopy")
	canopy = g


	var rng: = RandomNumberGenerator.new()
	rng.seed = hash(map_file + ":canopy")
	var lists: = {}
	for id in ids:
		lists[id] = []
	var nx: = int(float(r[2]) / step) + 1
	var nz: = int(float(r[3]) / step) + 1
	for j in nz:
		for i in nx:
			var x: = float(r[0]) + (i + 0.5 + rng.randf_range(-0.28, 0.28)) * step
			var z: = float(r[1]) + (j + 0.5 + rng.randf_range(-0.28, 0.28)) * step
			lists[ids[rng.randi() % ids.size()]].append([x, z])
	for id in lists:
		await _canopy_mesh(g, id, lists[id], base_scale)


func _canopy_mesh(parent: Node3D, id: String, xs: Array, base_scale: float) -> void :
	if xs.is_empty():
		return
	var rng: = RandomNumberGenerator.new()
	rng.seed = hash(map_file + ":canopy:" + id)
	var src: Node3D = load(Props.HGSS_ROOT + id + ".glb").instantiate()
	var mi: MeshInstance3D = Props.meshes(src)[0]
	var mesh: Mesh = mi.mesh.duplicate()
	for s in mesh.get_surface_count():
		mesh.surface_set_material(s, Props._hgss_material(mi.get_active_material(s), true, HGSS_TREE_TINT))
	var mm: = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xs.size()
	for i in xs.size():
		var x: float = xs[i][0]
		var z: float = xs[i][1]
		var p: = Vector3(x, height_at(x, z), z)
		var s: = base_scale * rng.randf_range(0.9, 1.15)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), p))
		if not await _tick():
			return
	var mmi: = MultiMeshInstance3D.new()
	mmi.name = "Canopy_" + id.get_file()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	src.free()




func _fences() -> void :
	var g: = _group("Fences")
	for f in data.fences:
		var a: = _v(f.from)
		var b: = _v(f.to)
		var dir: = b - a
		dir.y = 0.0
		var model: = String(f.get("model", "nature/fence_simple"))
		var s: = float(f.get("scale", 2.0))



		var native: = maxf(_model_width(model, s), 0.01)
		var n: = maxi(int(round(dir.length() / native)), 1)
		var yaw: = rad_to_deg(atan2( - dir.z, dir.x))
		for i in n:


			var at: = a.lerp(b, (i + 0.5) / n)
			var piece: = Props.place(g, model, at, {"scale": s})
			piece.scale.x *= dir.length() / n / native
			piece.rotation_degrees.y = yaw


			var c: = Props.bounds(piece).get_center()
			piece.global_position += Vector3(at.x - c.x, 0.0, at.z - c.z)
			if not await _tick():
				return
		Props.wall(g, (a + b) / 2.0 + Vector3(0, 0.6, 0), Vector3(absf(dir.x) + 0.3, 1.2, absf(dir.z) + 0.3))


func _flowers() -> void :
	var g: = _group("Flowers")
	var kinds: = ["nature/flower_redA", "nature/flower_redB", "nature/flower_yellowA", "nature/flower_yellowB", 
		"nature/flower_purpleA", "nature/flower_purpleB"]
	for bed in data.flower_beds:
		var c: = _v(bed.center)
		if bed.get("tile", false):
			await _flower_tiles(g, c, float(bed.radius))
			continue
		for i in int(bed.count):
			var r: = sqrt(_rng.randf()) * float(bed.radius)
			var a: = _rng.randf() * TAU
			Props.place(g, kinds[_rng.randi() % kinds.size()], c + Vector3(cos(a), 0, sin(a)) * r, 
				{"scale": 2.0, "rot": _rng.randi_range(0, 359), "shadow": false, "vis_range": 50.0})
			if not await _tick():
				return





const HGSS_FLOWER_Y: = 0.03
const HGSS_FLOWER_FRAMES: = "res://assets/models/hgss/common/flower%02d_%d.png"
const HGSS_FLOWER_SECONDS: = 0.25

var _flower_mats: = {}


func _flower_material(kind: int) -> StandardMaterial3D:
	if _flower_mats.has(kind):
		return _flower_mats[kind]


	var frames: = AnimatedTexture.new()
	frames.frames = 3
	for f in 3:
		frames.set_frame_texture(f, load(HGSS_FLOWER_FRAMES % [kind, f + 1]))
		frames.set_frame_duration(f, HGSS_FLOWER_SECONDS)
	var m: = StandardMaterial3D.new()
	m.albedo_texture = frames
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 1.0
	_flower_mats[kind] = m
	return m


func _flower_tiles(g: Node3D, c: Vector3, radius: float) -> void :
	var quad: = PlaneMesh.new()
	quad.size = Vector2.ONE
	var mats: = [_flower_material(1), _flower_material(2)]
	var reach: = int(ceil(radius))
	for i in range( - reach, reach + 1):
		for j in range( - reach, reach + 1):
			if Vector2(i, j).length() > radius:
				continue
			var mi: = MeshInstance3D.new()
			mi.mesh = quad
			mi.material_override = mats[_rng.randi() % 2]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(mi)
			mi.global_position = Vector3(c.x + i, c.y + HGSS_FLOWER_Y, c.z + j)
			if not await _tick():
				return




func _palette(d: Dictionary) -> Dictionary:
	var out: = {}
	for k in d:
		out[k] = Color(String(d[k]))
	return out

func _rock_model(id: String) -> bool:
	return id.begins_with("nature/rock") or id.begins_with("nature/cliff")






func _cave_mouth(parent: Node3D, p: Dictionary) -> void :
	var size: Array = p.get("size", [2.4, 1.9])
	var grad: = Gradient.new()
	grad.set_color(0, Color(String(p.get("base", "#242428"))))
	grad.set_color(1, Color(String(p.get("top", "#060608"))))
	var gt: = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 1)
	gt.fill_to = Vector2(0, 0)
	var mat: = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = gt
	mat.disable_receive_shadows = true
	var qm: = QuadMesh.new()
	qm.size = Vector2(float(size[0]), float(size[1]))
	var mi: = MeshInstance3D.new()
	mi.name = "CaveMouth"
	mi.mesh = qm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = _v(p.pos) + Vector3(0, float(size[1]) / 2.0, 0)


func _props() -> void :
	var g: = _group("Props")
	var rock_pal: = _palette(data.get("look", {}).get("rock_palette", {}))
	var tree_pal: = _palette(data.get("look", {}).get("tree_palette", {}))
	for p in data.props:
		if p.get("cave", false):
			_cave_mouth(g, p)
			continue
		var opts: = {"scale": p.get("scale", 2.0), "rot": p.get("rot", 0), "collide": p.get("collide", ""), 
			"light": p.get("light", false)}
		if p.get("small", false):
			opts["shadow"] = false
			opts["vis_range"] = 50.0
		var mid: = String(p.model)
		if mid == HGSS_TREE or mid == HGSS_BUSH:


			opts["billboard"] = true
			opts["tint"] = HGSS_TREE_TINT
		if not rock_pal.is_empty() and _rock_model(mid):
			opts["palette"] = rock_pal
		elif not tree_pal.is_empty() and mid.begins_with("nature/"):
			opts["palette"] = tree_pal
		Props.place(g, p.model, _v(p.pos), opts)
		if not await _tick():
			return






func _scatter() -> void :
	for layer in data.get("scatter", []):
		var per_model: Dictionary = await _layer_transforms(layer)
		for id in per_model:
			await _scatter_mesh(layer, id, per_model[id])


func _layer_transforms(layer: Dictionary) -> Dictionary:
	var out: = {}
	for id in layer.models:
		out[id] = []
	var noise: = FastNoiseLite.new()
	noise.seed = hash(String(layer.get("name", "")) + map_file)
	noise.frequency = 0.15
	var clump: = float(layer.get("clump", 0.0))
	var sc: Array = layer.get("scale", [1.4, 2.4])
	for a in layer.areas:
		for i in int(float(a[2]) * float(a[3]) * float(layer.density)):
			if not await _tick():
				return out
			var p: = Vector3(_rng.randf_range(a[0], a[0] + a[2]), 0, _rng.randf_range(a[1], a[1] + a[3]))
			if clump > 0.0 and noise.get_noise_2d(p.x, p.z) * 0.5 + 0.5 < clump:
				continue
			if _blocked(p):
				continue
			p.y = height_at(p.x, p.z)
			var b: = Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(float(sc[0]), float(sc[1])))
			out[layer.models[_rng.randi() % layer.models.size()]].append(Transform3D(b, p))
	return out


func _scatter_mesh(layer: Dictionary, id: String, xs: Array) -> void :
	if xs.is_empty():
		return
	var src: Node3D = load(Props.ROOT + id + ".glb").instantiate()
	var mi: MeshInstance3D = Props.meshes(src)[0]
	var mesh: Mesh = mi.mesh.duplicate()
	var glow: = float(layer.get("glow", 0.0))
	var pal: = _palette(layer.get("palette", {}))
	for s in mesh.get_surface_count():
		var m: Material = Props._remap(mi.get_active_material(s), null, pal)
		if m is StandardMaterial3D:
			var sm: StandardMaterial3D = m.duplicate()
			sm.vertex_color_use_as_albedo = true
			if glow > 0.0 and String(sm.resource_name).begins_with("color"):
				sm.emission_enabled = true
				sm.emission = sm.albedo_color
				sm.emission_energy_multiplier = glow
			m = sm
		mesh.surface_set_material(s, m)
	var mm: = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		var v: = _rng.randf_range(0.88, 1.08)
		mm.set_instance_color(i, Color(v, v, v * 0.97))
		if not await _tick():
			return
	var mmi: = MultiMeshInstance3D.new()
	mmi.name = "%s_%s" % [String(layer.get("name", "Scatter")), id.get_file()]
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mmi)
	src.free()




func _sun_shafts() -> void :
	var list: Array = data.get("sun_shafts", [])
	if list.is_empty():
		return
	var g: = _group("SunShafts")
	for s in list:
		var n: = Node3D.new()
		n.set_script(SUN_SHAFT)
		n.position = _v(s.pos)
		n.set("radius", float(s.get("radius", 2.2)))
		n.set("height", float(s.get("height", 9.0)))
		n.set("tilt_deg", float(s.get("tilt", 10.0)))
		n.set("opacity", float(s.get("opacity", 0.2)))
		n.set("mote_count", int(s.get("motes", 14)))
		n.set("shaft_seed", int(s.get("seed", 0)))
		g.add_child(n)
		if not await _tick():
			return


func _blocked(p: Vector3) -> bool:
	for r in data.paths:
		if p.x > r[0] - 0.4 and p.x < r[0] + r[2] + 0.4 and p.z > r[1] - 0.4 and p.z < r[1] + r[3] + 0.4:
			return true
	for w in data.water:
		var r: Array = w.rect
		if p.x > r[0] - 1.0 and p.x < r[0] + r[2] + 1.0 and p.z > r[1] - 1.0 and p.z < r[1] + r[3] + 1.0:
			return true
	for b in data.buildings:
		if absf(p.x - b.pos[0]) < 6.0 and absf(p.z - b.pos[1]) < 5.5:
			return true
	for g in data.get("tall_grass", []):
		var gp: Array = g.pos
		var gs: Array = g.size
		if absf(p.x - gp[0]) < gs[0] / 2.0 + 0.5 and absf(p.z - gp[1]) < gs[1] / 2.0 + 0.5:
			return true
	for pl in data.get("plateaus", []):
		var r: Array = pl.rect
		var near_x: = absf(p.x - r[0]) < 0.6 or absf(p.x - (r[0] + r[2])) < 0.6
		var near_z: = absf(p.z - r[1]) < 0.6 or absf(p.z - (r[1] + r[3])) < 0.6
		var in_x: bool = p.x > r[0] - 0.6 and p.x < r[0] + r[2] + 0.6
		var in_z: bool = p.z > r[1] - 0.6 and p.z < r[1] + r[3] + 0.6
		if (near_x and in_z) or (near_z and in_x):
			return true
		for s in pl.get("ramps", []):
			var run: = float(pl.h) * RAMP_SLOPE + 0.5
			var half: = float(s.width) / 2.0 + 0.6
			match String(s.side):
				"e":
					if p.x > r[0] + r[2] - 0.5 and p.x < r[0] + r[2] + run and absf(p.z - s.at) < half:
						return true
				"w":
					if p.x < r[0] + 0.5 and p.x > r[0] - run and absf(p.z - s.at) < half:
						return true
				"n":
					if p.z < r[1] + 0.5 and p.z > r[1] - run and absf(p.x - s.at) < half:
						return true
				"s":
					if p.z > r[1] + r[3] - 0.5 and p.z < r[1] + r[3] + run and absf(p.x - s.at) < half:
						return true
	return false


func _walls() -> void :
	var g: = _group("Walls")



	var water: Array = []
	for wt in data.water:
		water.append(wt.rect)
	for r in data.walls:
		var sb: = Props.wall(g, Vector3(r[0] + r[2] / 2.0, 3.0, r[1] + r[3] / 2.0), Vector3(r[2], 6.0, r[3]))
		for wr in water:
			if absf(float(wr[0]) - r[0]) < 0.01 and absf(float(wr[1]) - r[1]) < 0.01\
			and absf(float(wr[2]) - r[2]) < 0.01 and absf(float(wr[3]) - r[3]) < 0.01:
				sb.collision_layer = WATER_LAYER
				break
