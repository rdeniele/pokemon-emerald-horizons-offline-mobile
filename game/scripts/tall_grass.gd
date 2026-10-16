@tool
extends Area3D

















@export var size: = Vector2(6, 4):
	set(v):
		size = v
		if is_inside_tree():
			_build()
@export_file("*.json") var encounter_table: = "res://data/encounters/route_1.json"

const SHADER: = preload("res://shaders/hgss_foliage.gdshader")
const TILE_TEX: = preload("res://assets/models/hgss/common/egrass.png")
const TUFT_TEX: = preload("res://assets/models/hgss/common/egrass_u.png")



const TILE: = 0.8
const TUFT_PER_TILE: = 2
const TUFT_H: = 0.65



const TINT: = Color(0.85, 0.95, 0.78)


const TUFT_UV: = Vector4(0.0, 0.25, 1.0, 0.875)

const GROUND_Y: = 0.02


const PUSH_RADIUS: = 1.15
const MAX_PUSHERS: = 16
const PUSH_SCALE: = 1.6



const STEP_SECS: = 0.3
const MAX_STEPS: = 8

const STEP_LEN: = 1.0





const COVER_H: = 0.42
const COVER_SINK: = 0.25


const COVER_BASE_H: = 0.36
const COVER_W: = TILE * 1.5


const COVER_UV: = Vector4(0.0, 0.25, 1.5, 0.875)
const COVER_BASE_UV: = Vector4(0.0, 0.8125, 1.5, 0.5)
const COVER_LEAD: = 0.22
const SHAKE_SECS: = 0.6

const RUSTLE_GAP: = 0.16


const HIDE_SECS: = 0.3
const HIDE_MARGIN: = 0.5

var _mat: ShaderMaterial
var _pushers: = PackedVector4Array()

var _steps: = PackedVector4Array()

var _walk: = {}

var _covers: = {}
var _cover_base_mesh: QuadMesh
var _cover_top_mesh: QuadMesh
var _cover_base_mat: ShaderMaterial
var _cover_top_mat: ShaderMaterial
var _shake: = 0.0
var _shake_rate: = 1.0 / SHAKE_SECS
var _shake_at: = Vector2.ZERO
var _rustle_cd: = 0.0

var _hide: = 0.0
var _hide_rect: = Rect2()
var _hide_rate: = 1.0 / HIDE_SECS


func _ready() -> void :
	_build()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _build() -> void :
	for c in get_children():
		if String(c.name).begins_with("_gen"):
			remove_child(c)
			c.free()
	_covers.clear()
	_walk.clear()
	_build_ground()
	_build_tufts()
	var cs: = CollisionShape3D.new()
	cs.name = "_gen_shape"
	var bs: = BoxShape3D.new()
	bs.size = Vector3(size.x, 1.5, size.y)
	cs.shape = bs
	cs.position.y = 0.75
	add_child(cs)



func _build_ground() -> void :
	var mat: = StandardMaterial3D.new()
	mat.albedo_texture = TILE_TEX
	mat.albedo_color = TINT
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(size.x / TILE, size.y / TILE, 1.0)
	mat.roughness = 1.0
	var pm: = PlaneMesh.new()
	pm.size = size
	var mi: = MeshInstance3D.new()
	mi.name = "_gen_ground"
	mi.mesh = pm
	mi.material_override = mat
	mi.position.y = GROUND_Y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)



func _build_tufts() -> void :
	var q: = QuadMesh.new()
	q.size = Vector2(TILE, TUFT_H)
	q.center_offset = Vector3(0, TUFT_H / 2.0, 0)
	var mm: = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	var rng: = RandomNumberGenerator.new()
	rng.seed = hash(String(name))



	var nx: = maxi(1, ceili(size.x / TILE))
	var nz: = maxi(1, ceili(size.y / TILE))
	mm.instance_count = (nx + 1) * (nz + 1) * TUFT_PER_TILE
	var n: = 0
	for iz in nz + 1:
		for ix in nx + 1:
			for row in TUFT_PER_TILE:
				var p: = Vector3(
					- size.x / 2.0 + (ix + rng.randf_range(-0.25, 0.25)) * TILE, 
					GROUND_Y, 
					- size.y / 2.0 + (iz + (0.5 if row == 1 else 0.0) + rng.randf_range(-0.25, 0.25)) * TILE)
				var s: = rng.randf_range(0.9, 1.15)
				mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3(s, s, s)), p))
				n += 1
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("albedo_tex", TUFT_TEX)
	_mat.set_shader_parameter("uv_rect", TUFT_UV)
	_mat.set_shader_parameter("tint", TINT)
	_mat.set_shader_parameter("sway", 0.05)
	_mat.set_shader_parameter("push_scale", PUSH_SCALE)
	_pushers.resize(MAX_PUSHERS)
	_mat.set_shader_parameter("pushers", _pushers)
	_steps.resize(MAX_STEPS)
	_mat.set_shader_parameter("steps", _steps)
	_mat.set_shader_parameter("shake", Vector4.ZERO)
	_mat.set_shader_parameter("hide_rect", Vector4.ZERO)
	_mat.set_shader_parameter("hide_amount", 0.0)
	var mmi: = MultiMeshInstance3D.new()
	mmi.name = "_gen_tufts"
	mmi.multimesh = mm
	mmi.material_override = _mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_build_cover()







func _build_cover() -> void :
	_cover_base_mesh = QuadMesh.new()
	_cover_base_mesh.size = Vector2(COVER_W, COVER_BASE_H + COVER_SINK)
	_cover_base_mesh.center_offset = Vector3(0, (COVER_BASE_H + COVER_SINK) / 2.0 - COVER_SINK, 0)
	_cover_base_mat = ShaderMaterial.new()
	_cover_base_mat.shader = SHADER
	_cover_base_mat.set_shader_parameter("albedo_tex", TUFT_TEX)
	_cover_base_mat.set_shader_parameter("uv_rect", COVER_BASE_UV)
	_cover_base_mat.set_shader_parameter("tint", TINT)
	_cover_base_mat.set_shader_parameter("sway", 0.05)
	_cover_top_mesh = QuadMesh.new()
	_cover_top_mesh.size = Vector2(COVER_W, COVER_H + COVER_SINK)
	_cover_top_mesh.center_offset = Vector3(0, (COVER_H + COVER_SINK) / 2.0 - COVER_SINK, 0)
	_cover_top_mat = ShaderMaterial.new()
	_cover_top_mat.shader = SHADER
	_cover_top_mat.set_shader_parameter("albedo_tex", TUFT_TEX)
	_cover_top_mat.set_shader_parameter("uv_rect", COVER_UV)
	_cover_top_mat.set_shader_parameter("tint", TINT)
	_cover_top_mat.set_shader_parameter("sway", 0.05)




func _process(delta: float) -> void :
	if Engine.is_editor_hint():
		return
	_rustle_cd = maxf(0.0, _rustle_cd - delta)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - _shake_rate * delta)
	if _mat == null:
		return
	_decay_steps(delta)

	var battle: = get_node_or_null("/root/Battle")
	_hide_step(delta, battle != null and battle.in_battle, battle.arena_rect if battle else Rect2())
	var reach: = maxf(size.x, size.y) / 2.0 + PUSH_RADIUS
	var walkers: = _walkers_near(reach)
	var n: = 0
	for w in walkers:
		if n >= MAX_PUSHERS:
			break
		_pushers[n] = _pusher(w.global_position)
		n += 1
	for i in range(n, MAX_PUSHERS):
		_pushers[i] = Vector4.ZERO
	_mat.set_shader_parameter("pushers", _pushers)
	_mat.set_shader_parameter("shake", Vector4(_shake_at.x, _shake_at.y, 0.0, _shake))
	_mat.set_shader_parameter("steps", _steps)
	_step_walkers(walkers)
	_update_covers(walkers)




func _walkers_near(reach: float) -> Array:
	var here: = global_position
	var out: Array = []
	var p: = get_tree().get_first_node_in_group("player")
	if p is Node3D and _near(p.global_position, here, reach):
		out.append(p)
	var game: = get_node_or_null("/root/Game")
	if game:
		for c in game.companions.values():
			if is_instance_valid(c) and c is Node3D and _near(c.global_position, here, reach):
				out.append(c)
	for grp in ["wild", "npc"]:
		for w in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(w) and w is Node3D and _near(w.global_position, here, reach):
				out.append(w)
	return out





func _step_walkers(walkers: Array) -> void :
	var game: = get_node_or_null("/root/Game")
	var foot: = _footprint()
	var seen: = {}
	for w in walkers:
		if w.is_in_group("player"):
			continue
		var id: int = w.get_instance_id()
		var at: Vector3 = w.global_position
		var prev: Array = _walk.get(id, [at.x, at.z, 0.0])
		var d: = Vector2(at.x - prev[0], at.z - prev[1]).length()
		var acc: float = prev[2]

		if d > 1.0 or not foot.has_point(Vector2(at.x, at.z)):
			acc = 0.0
		else:
			acc += d
			while acc >= STEP_LEN:
				acc -= STEP_LEN
				_do_step(at, Vector3(at.x - prev[0], 0.0, at.z - prev[1]), 
					game != null and game.companions.values().has(w))
		_walk[id] = [at.x, at.z, acc]
		seen[id] = true
	for id in _walk.keys():
		if not seen.has(id):
			_walk.erase(id)




func _update_covers(walkers: Array) -> void :
	var foot: = _footprint()
	var cam: = get_viewport().get_camera_3d() if is_inside_tree() else null
	var live: = {}
	var ground: = global_position.y + GROUND_Y
	for w in walkers:
		var at: Vector3 = w.global_position
		if _hide > 0.0 or at.y - ground > 0.3 or not foot.has_point(Vector2(at.x, at.z)):
			continue
		live[w] = true
		var c: Node3D = _covers.get(w)
		if c == null:
			c = Node3D.new()
			c.name = "_gen_cover"
			var base: = MeshInstance3D.new()
			base.mesh = _cover_base_mesh
			base.material_override = _cover_base_mat
			base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			base.name = "base"
			c.add_child(base)
			var top: = MeshInstance3D.new()
			top.mesh = _cover_top_mesh
			top.material_override = _cover_top_mat
			top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			top.name = "top"
			c.add_child(top)
			add_child(c)
			_covers[w] = c
		var dir: = Vector3(0, 0, 1)
		if cam:
			var to: = cam.global_position - at
			to.y = 0.0
			if to.length() > 0.01:
				dir = to.normalized()
		c.global_position = Vector3(at.x, ground, at.z) + dir * COVER_LEAD

		(c.get_node("base") as Node3D).position = - dir * 0.04
	for w in _covers.keys():
		if live.has(w):
			continue
		var c: Node3D = _covers[w]
		if is_instance_valid(c):
			c.queue_free()
		_covers.erase(w)



func _add_step(at: Vector3) -> void :
	var slot: = 0
	var oldest: = -1.0
	for i in MAX_STEPS:
		if _steps[i].w <= 0.0:
			slot = i
			break
		if _steps[i].z > oldest:
			oldest = _steps[i].z
			slot = i
	_steps[slot] = Vector4(at.x, at.z, 0.0, 1.0)



func _decay_steps(delta: float) -> void :
	for i in MAX_STEPS:
		if _steps[i].w <= 0.0:
			continue
		var age: float = _steps[i].z + delta
		if age >= STEP_SECS:
			_steps[i] = Vector4.ZERO
		else:
			_steps[i] = Vector4(_steps[i].x, _steps[i].y, age, _steps[i].w)




func _hide_step(delta: float, active: bool, rect: Rect2) -> void :
	var target: = Rect2()
	if active and rect.has_area():
		target = rect.grow(HIDE_MARGIN)
	if target.has_area() and _footprint().intersects(target):
		_hide_rect = target
		_hide = minf(1.0, _hide + _hide_rate * delta)
	else:
		_hide = maxf(0.0, _hide - _hide_rate * delta)
	if _hide > 0.0:
		_mat.set_shader_parameter("hide_rect", Vector4(
			_hide_rect.position.x, _hide_rect.position.y, _hide_rect.end.x, _hide_rect.end.y))
		_mat.set_shader_parameter("hide_amount", _hide)
	elif _hide_rect.has_area():

		_mat.set_shader_parameter("hide_amount", 0.0)
		_hide_rect = Rect2()




func _footprint() -> Rect2:
	var g: = global_position if is_inside_tree() else position
	return Rect2(g.x - size.x / 2.0, g.z - size.y / 2.0, size.x, size.y)


func _pusher(at: Vector3) -> Vector4:
	return Vector4(at.x, at.z, 0.0, PUSH_RADIUS)


func _near(at: Vector3, here: Vector3, reach: float) -> bool:
	return absf(at.x - here.x) < reach and absf(at.z - here.z) < reach






func rustle_step(at: Vector3, dir: Vector3) -> void :
	_add_step(at)
	if _rustle_cd > 0.0:
		return
	_rustle_cd = RUSTLE_GAP
	_rustle(at, dir, -9.0)



func _do_step(at: Vector3, dir: Vector3, loud: bool) -> void :
	_add_step(at)
	if not loud or _rustle_cd > 0.0:
		return
	_rustle_cd = RUSTLE_GAP
	_rustle(at, dir, -13.0)



func _rustle(at: Vector3, dir: Vector3, db: float) -> void :
	var audio: = get_node_or_null("/root/Audio")
	if audio:
		audio.play_at("sfx/world/grass_rustle", at, db, randf_range(0.92, 1.08))
	var vfx: = get_node_or_null("/root/Vfx")
	if vfx and get_tree() and get_tree().current_scene:
		var back: = Vector3( - dir.x, 0.9, - dir.z).normalized()
		vfx.burst(at + Vector3(0, 0.25, 0) - dir.normalized() * 0.2, Color(0.42, 0.62, 0.26), 
			12, 0.6, 3.0, 0.11, 80.0, back, Vector3(0, -5, 0))



func shake(at: Vector3, secs: = SHAKE_SECS) -> void :
	_shake = 1.0
	_shake_rate = 1.0 / maxf(secs, 0.05)
	_shake_at = Vector2(at.x, at.z)


func _on_body_entered(body: Node) -> void :
	if body.has_method("enter_grass"):
		body.enter_grass(self)


func _on_body_exited(body: Node) -> void :
	if body.has_method("exit_grass"):
		body.exit_grass(self)
