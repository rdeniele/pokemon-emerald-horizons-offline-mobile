extends Node



const FxPopups: = preload("res://scripts/ui/fx_popups.gd")
const Props: = preload("res://scripts/world/props.gd")
const Flipbook: = preload("res://scripts/vfx_flipbook.gd")
const PmdFx: = preload("res://scripts/vfx_pmd.gd")
var _fx: CanvasLayer


func root() -> Node:
	return get_tree().current_scene





func popup(pos: Vector3, text: String, col: = Color.WHITE, scale: = 1.0, style: = "", n: = 1) -> void :
	if style == "":
		style = _guess_style(text)
	if not is_instance_valid(_fx):
		_fx = FxPopups.new()
		add_child(_fx)
	_fx.spawn(pos, text, col, scale, style, n)


func _guess_style(text: String) -> String:
	if text.is_valid_int():
		return "damage"
	if text.begins_with("+") and text.substr(1).is_valid_int():
		return "heal"
	if text.begins_with("Miss"):
		return "miss"
	return "info"


func shake(amount: float) -> void :
	var cam: = get_tree().get_first_node_in_group("camera_rig")
	if cam and cam.has_method("shake"):
		cam.shake(amount)


func _quad_mat() -> StandardMaterial3D:
	var m: = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _process_mat(col: Color, dir: Vector3, spread: float, vel: float, gravity: Vector3, sphere_r: float) -> ParticleProcessMaterial:
	var pm: = ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = vel * 0.5
	pm.initial_velocity_max = vel
	pm.gravity = gravity
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.color = col
	var g: = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt: = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	if sphere_r > 0.0:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = sphere_r
	return pm



func burst(pos: Vector3, col: Color, amount: = 12, life: = 0.45, speed: = 3.0, size: = 0.12, 
		spread: = 180.0, dir: = Vector3.UP, gravity: = Vector3(0, -4, 0), sphere_r: = 0.0) -> void :
	var p: = GPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.process_material = _process_mat(col, dir, spread, speed, gravity, sphere_r)
	var q: = QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _quad_mat()
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


	p.speed_scale = Battle.fight_speed()
	root().add_child(p)
	p.global_position = pos
	p.emitting = true
	Battle.fight_timer(life + 0.4).timeout.connect(p.queue_free)



func emitter(col: Color, amount: int, life: float, speed: float, size: float, spread: float, 
		dir: Vector3, gravity: Vector3, sphere_r: = 0.0) -> GPUParticles3D:
	var p: = GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.process_material = _process_mat(col, dir, spread, speed, gravity, sphere_r)
	var q: = QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _quad_mat()
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.speed_scale = Battle.fight_speed()
	return p



func make_trail(col: Color) -> GPUParticles3D:
	var p: = emitter(col, 24, 0.3, 0.3, 0.1, 180.0, Vector3.UP, Vector3.ZERO)
	p.local_coords = false
	p.emitting = true
	return p


func glow_mat(col: Color) -> StandardMaterial3D:
	var m: = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	return m


func flat_box(size: Vector3, col: Color) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var bm: = BoxMesh.new()
	bm.size = size
	var m: = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	bm.material = m
	mi.mesh = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi



func disc(radius: float, col: Color) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var cm: = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	cm.radial_segments = 32
	var m: = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	cm.material = m
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func shockwave(center: Vector3, radius: float, col: Color, height: = 0.3) -> void :
	var mi: = MeshInstance3D.new()
	var tm: = TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 6
	var m: = glow_mat(col.lightened(0.3))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.material = m
	mi.mesh = tm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root().add_child(mi)
	mi.global_position = center + Vector3(0, height, 0)
	mi.scale = Vector3(0.2, 1, 0.2)
	var tw: = Battle.fight_tween(mi).set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1, radius), 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(mi.queue_free)


func bolt(p: Vector3, col: Color) -> void :
	var mi: = MeshInstance3D.new()
	var cm: = CylinderMesh.new()
	cm.top_radius = 0.25
	cm.bottom_radius = 0.12
	cm.height = 14.0
	cm.material = glow_mat(col.lightened(0.6))
	mi.mesh = cm
	root().add_child(mi)
	mi.global_position = p + Vector3(0, 7, 0)
	var light: = OmniLight3D.new()
	light.light_color = col
	light.light_energy = 8.0
	light.omni_range = 8.0
	root().add_child(light)
	light.global_position = p + Vector3(0, 1.5, 0)
	var tw: = Battle.fight_tween(mi).set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(0.05, 1, 0.05), 0.25).set_delay(0.08)
	tw.tween_property(light, "light_energy", 0.0, 0.3)
	tw.chain().tween_callback( func():
		mi.queue_free()
		light.queue_free())
	burst(p + Vector3(0, 0.2, 0), col, 30, 0.5, 6.0, 0.14)


func slash(pos: Vector3, col: Color) -> void :
	for i in 3:
		var mi: = MeshInstance3D.new()
		var bm: = BoxMesh.new()
		bm.size = Vector3(0.07, 0.8, 0.07)
		bm.material = glow_mat(Color.WHITE.lerp(col, 0.3))
		mi.mesh = bm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root().add_child(mi)
		mi.global_position = pos + Vector3((i - 1) * 0.22, 0, 0)
		mi.rotation.z = deg_to_rad(-35)
		var tw: = Battle.fight_tween(mi)
		tw.tween_property(mi, "scale", Vector3(1, 0.05, 1), 0.18).set_delay(0.05)
		tw.tween_callback(mi.queue_free)






func flipbook(anim: String, at: Vector3, world_h: float, type_id: = "normal") -> Node3D:
	return Flipbook.spawn(root(), anim, at, world_h, type_id)



func anim_ready(anim: String) -> bool:
	return Flipbook.exists(anim)



func flipbook_travel(parent: Node3D, anim: String, world_h: float, type_id: = "normal") -> Node3D:
	return Flipbook.attach(parent, anim, world_h, type_id)








func pmd_fx(fx_id: String, at: Vector3, aim: Vector3, role: = {}) -> Node3D:
	return PmdFx.spawn(root(), fx_id, at, aim, role)



func pmd_fx_travel(parent: Node3D, fx_id: String, aim: Vector3, role: = {}) -> Node3D:
	return PmdFx.attach(parent, fx_id, aim, role)





const ROCK_PALETTE: = {"dirt": Color(0.62, 0.63, 0.66), "grass": Color(0.45, 0.46, 0.5)}


func _rock_id() -> String:
	return "rock_tall" + "ABCDEFGHIJ"[randi() % 10]





func rock_piece(parent: Node3D, target: float, grounded: bool, by_height: = true) -> Dictionary:
	var inst: Node3D = Props.place(parent, "nature/" + _rock_id(), Vector3.ZERO, {"shadow": false, "palette": ROCK_PALETTE})
	var bb: = Props.bounds(inst)
	var dim: = bb.size.y if by_height else maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
	inst.scale = Vector3.ONE * (target / maxf(dim, 0.001))
	inst.position = Vector3.ZERO
	bb = Props.bounds(inst)
	inst.position = Vector3(0, - bb.position.y, 0) if grounded else - bb.get_center()
	return {"inst": inst, "w": maxf(bb.size.x, bb.size.z), "h": bb.size.y}






func rock_drop(center: Vector3, avoid: Array, trap_secs: float) -> void :
	var count: = 6
	var pieces: Array = []
	var max_half: = 0.0
	for i in count:
		var p: = _make_rock(randf_range(1.0, 1.2))
		pieces.append(p)
		max_half = maxf(max_half, float(p.w) * 0.5)

	var body_r: = 0.35
	var best: = 1000000000.0
	for f in avoid:
		var d: float = (Vector3(f.pos.x, 0, f.pos.z) - Vector3(center.x, 0, center.z)).length()
		if d < best:
			best = d
			body_r = float(f.r)
	var ring: = body_r + max_half + 0.03
	for i in count:
		var r: Dictionary = pieces[i]
		var ang: = TAU * float(i) / float(count) + randf_range(-0.12, 0.12)
		var pos: = center + Vector3(cos(ang), 0.0, sin(ang)) * ring
		var blocked: = false
		for f in avoid:
			var fp: = Vector3(f.pos.x, 0, f.pos.z)
			if fp.distance_to(Vector3(center.x, 0, center.z)) < 0.15:
				continue
			if fp.distance_to(Vector3(pos.x, 0, pos.z)) < float(f.r) + float(r.w) * 0.5 + 0.05:
				blocked = true
				break
		if blocked:
			r.holder.queue_free()
			continue
		_launch_rock(r, pos, trap_secs)
		await Battle.fight_timer(0.07).timeout


func _make_rock(target_h: float) -> Dictionary:
	var holder: = Node3D.new()
	root().add_child(holder)
	var piece: = rock_piece(holder, target_h, true)
	var inst: Node3D = piece.inst
	inst.rotation = Vector3(deg_to_rad(randf_range(-9, 9)), randf() * TAU, deg_to_rad(randf_range(-9, 9)))
	var bb: = Props.bounds(inst)
	inst.position.y -= bb.position.y
	var w: = maxf(bb.size.x, bb.size.z)
	var h: = bb.size.y

	var body: = StaticBody3D.new()
	var cs: = CollisionShape3D.new()
	var cyl: = CylinderShape3D.new()
	cyl.radius = w * 0.42
	cyl.height = h
	cs.shape = cyl
	cs.position.y = h * 0.5
	body.add_child(cs)
	holder.add_child(body)
	return {"holder": holder, "w": w, "h": h, "cs": cs}


func _launch_rock(r: Dictionary, pos: Vector3, trap_secs: float) -> void :
	var holder: Node3D = r.holder
	var cs: CollisionShape3D = r.cs
	holder.global_position = pos + Vector3(0, 6, 0)
	var ground: = pos.y
	var tw: = Battle.fight_tween(holder)
	tw.tween_property(holder, "global_position:y", ground, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback( func():
		if not is_instance_valid(holder):
			return
		Audio.play_at("sfx/moves/rumble", holder.global_position, 0.0, 1.6)
		burst(holder.global_position + Vector3(0, 0.1, 0), Color(0.45, 0.4, 0.34), 16, 0.5, 2.5, 0.14, 180.0, Vector3.UP, Vector3(0, -4, 0), 0.5)
		shake(0.18))
	tw.tween_interval(trap_secs)
	tw.tween_callback( func():
		if is_instance_valid(cs):
			cs.set_deferred("disabled", true))
	tw.tween_property(holder, "global_position:y", ground - 0.6, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(holder, "scale", Vector3(0.02, 0.02, 0.02), 0.6)
	tw.tween_callback(holder.queue_free)




func magnitude_telegraph(center: Vector3, radius: float, level: int, windup: float) -> MeshInstance3D:
	var t: = clampf((float(level) - 4.0) / 6.0, 0.0, 1.0)
	var col: = Color(0.85, 0.4, 0.05).lerp(Color(1.0, 0.08, 0.04), t)
	var mi: = disc(radius, Color(col.r, col.g, col.b, 0.3))
	root().add_child(mi)
	mi.global_position = center + Vector3(0, 0.03, 0)
	mi.scale = Vector3(0.05, 1, 0.05)
	var tw: = Battle.fight_tween(mi)
	tw.tween_property(mi, "scale", Vector3.ONE, maxf(windup * 0.6, 0.05))
	tw.tween_interval(maxf(windup * 0.4, 0.05))
	tw.tween_callback(mi.queue_free)
	return mi





func prepare_ring(center: Vector3, col: Color, prepare: float, radius: = 0.7) -> MeshInstance3D:
	var mi: = disc(radius, Color(col.r, col.g, col.b, 0.32))
	root().add_child(mi)
	mi.global_position = center + Vector3(0, 0.03, 0)
	mi.scale = Vector3(0.05, 1, 0.05)
	var tw: = Battle.fight_tween(mi)
	tw.tween_property(mi, "scale", Vector3.ONE, maxf(prepare, 0.05))
	tw.tween_callback(mi.queue_free)
	return mi



func psy_rings(target: Node3D) -> void :
	var pos: Vector3 = target.global_position + Vector3(0, 0.45, 0)
	for i in 3:
		Battle.fight_timer(0.1 * i).timeout.connect(_psy_ring.bind(pos))


func _psy_ring(pos: Vector3) -> void :
	var mi: = MeshInstance3D.new()
	var tm: = TorusMesh.new()
	tm.inner_radius = 0.86
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 8
	var m: = glow_mat(Color(1.0, 0.48, 0.72))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.material = m
	mi.mesh = tm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root().add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(0.2, 1, 0.2)
	var tw: = Battle.fight_tween(mi).set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.4, 1, 1.4), 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(mi.queue_free)



func sprite_wobble(sprite: Sprite3D) -> void :
	if not is_instance_valid(sprite):
		return
	var tw: = Battle.fight_tween(sprite)
	tw.tween_property(sprite, "rotation:z", 0.22, 0.1)
	tw.tween_property(sprite, "rotation:z", -0.22, 0.1)
	tw.tween_property(sprite, "rotation:z", 0.0, 0.2)



func confuse_orbit(target: Node3D) -> void :
	if not is_instance_valid(target):
		return
	var orbit: = Node3D.new()
	target.add_child(orbit)
	orbit.position = Vector3(0, target.look_height() + 0.2, 0)
	for i in 3:
		var s: = MeshInstance3D.new()
		var sm: = SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		sm.radial_segments = 6
		sm.rings = 3
		sm.material = glow_mat(Color(1.0, 0.48, 0.72))
		s.mesh = sm
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.position = Vector3(0.35, 0, 0).rotated(Vector3.UP, TAU * float(i) / 3.0)
		orbit.add_child(s)
	var tw: = Battle.fight_tween(orbit).set_loops()
	tw.tween_property(orbit, "rotation:y", TAU, 0.9).from(0.0)
	Battle.fight_timer(4.0).timeout.connect( func():
		if is_instance_valid(orbit):
			orbit.queue_free())




func steel_claw(pos: Vector3, dir: Vector3) -> void :
	var side: = Vector3( - dir.z, 0.0, dir.x)
	for i in 3:
		var mi: = MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root().add_child(mi)
		mi.global_position = pos + side * ((i - 1) * 0.22)
		mi.rotation.y = atan2(dir.x, dir.z)
		mi.rotation.z = deg_to_rad(-35)
		mi.visible = false
		var edge: = MeshInstance3D.new()
		var em: = BoxMesh.new()
		em.size = Vector3(0.1, 1.08, 0.02)
		em.material = glow_mat(Color(0.56, 0.7, 0.85))
		edge.mesh = em
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(edge)
		var core: = MeshInstance3D.new()
		var cm: = BoxMesh.new()
		cm.size = Vector3(0.045, 1.0, 0.045)
		cm.material = glow_mat(Color(1, 1, 1))
		core.mesh = cm
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(core)
		var tw: = Battle.fight_tween(mi)
		tw.tween_interval(0.04 * i)
		tw.tween_callback( func(): mi.visible = true)
		tw.tween_property(mi, "scale", Vector3.ONE, 0.04)
		tw.tween_property(mi, "scale", Vector3(1, 0.04, 1), 0.12)
		tw.tween_callback(mi.queue_free)



func steel_glint(pos: Vector3) -> void :
	var light: = OmniLight3D.new()
	light.light_color = Color(0.9, 0.96, 1.0)
	light.light_energy = 7.0
	light.omni_range = 4.0
	light.shadow_enabled = false
	root().add_child(light)
	light.global_position = pos
	var lt: = Battle.fight_tween(light)
	lt.tween_property(light, "light_energy", 0.0, 0.12)
	lt.tween_callback(light.queue_free)
	for i in 2:
		var mi: = MeshInstance3D.new()
		var bm: = BoxMesh.new()
		bm.size = Vector3(0.12, 1.1, 0.12)
		bm.material = glow_mat(Color(1, 1, 1))
		mi.mesh = bm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root().add_child(mi)
		mi.global_position = pos
		mi.rotation = Vector3(0, 0, PI / 2.0 * float(i))
		mi.scale = Vector3(0.01, 0.01, 0.01)
		var tw: = Battle.fight_tween(mi)
		tw.tween_property(mi, "scale", Vector3.ONE, 0.05)
		tw.tween_property(mi, "scale", Vector3(0.01, 0.01, 0.01), 0.18)
		tw.tween_callback(mi.queue_free)
	burst(pos, Color(1.0, 0.95, 0.8), 10, 0.3, 6.0, 0.05, 120.0, Vector3.UP, Vector3(0, -12, 0))



func steel_flash(body: Creature) -> void :
	if not is_instance_valid(body) or body.sprite == null:
		return
	var spr: Sprite3D = body.sprite
	var base: Color = body.base_tint()
	spr.modulate = Color(0.85, 0.92, 1.0)
	var tw: = Battle.fight_tween(spr)
	tw.tween_property(spr, "modulate", base, 0.15)



func silk_wrap(target: Node3D) -> void :
	if not is_instance_valid(target):
		return
	for h in [0.2, 0.45, 0.7]:
		var mi: = MeshInstance3D.new()
		var tm: = TorusMesh.new()
		tm.inner_radius = 0.4
		tm.outer_radius = 0.45
		tm.rings = 24
		tm.ring_segments = 6
		var m: = glow_mat(Color(0.96, 0.95, 0.9))
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tm.material = m
		mi.mesh = tm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root().add_child(mi)
		mi.global_position = target.global_position + Vector3(0, h, 0)
		var tw: = Battle.fight_tween(mi).set_parallel(true)
		tw.tween_property(mi, "scale", Vector3(1.1, 1.1, 1.1), 0.8).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.8)
		tw.chain().tween_callback(mi.queue_free)



func bubble_pop(pos: Vector3) -> void :
	burst(pos, Color(0.72, 0.88, 1.0), 10, 0.4, 4.0, 0.08, 180.0, Vector3.UP, Vector3(0, -9, 0), 0.15)
	shockwave(pos, 0.9, Color(0.8, 0.92, 1.0), 0.25)
