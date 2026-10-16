extends RefCounted
















const Capture: = preload("res://scripts/stats/capture.gd")
const R: = 0.17
const LID_OPEN: = -1.1


static func _mat(col: Color, rough: = 0.35, emissive: = false) -> StandardMaterial3D:
	var m: = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic_specular = 0.7
	if emissive:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 0.0
	return m


static func _hemi(col: Color) -> MeshInstance3D:
	var sm: = SphereMesh.new()
	sm.radius = R
	sm.height = R
	sm.is_hemisphere = true
	sm.radial_segments = 32
	sm.rings = 12
	sm.material = _mat(col)
	var mi: = MeshInstance3D.new()
	mi.mesh = sm
	return mi


static func _cyl(radius: float, height: float, col: Color, emissive: = false) -> MeshInstance3D:
	var cm: = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 32
	cm.material = _mat(col, 0.5, emissive)
	var mi: = MeshInstance3D.new()
	mi.mesh = cm
	return mi


static func make_ball(ball_id: String) -> Node3D:
	var bd: = Capture.ball(ball_id)
	var ball: = Node3D.new()
	ball.name = "Ball"
	var pivot: = Node3D.new()
	pivot.name = "Pivot"
	pivot.position = Vector3(0, - R, 0)
	ball.add_child(pivot)
	var body: = Node3D.new()
	body.name = "Body"
	body.position = Vector3(0, R, 0)
	pivot.add_child(body)

	var bottom: = _hemi(Color(0.96, 0.96, 0.94))
	bottom.name = "Bottom"
	bottom.rotation.x = PI
	body.add_child(bottom)

	var lid: = Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0, - R)
	body.add_child(lid)
	var top: = _hemi(Color(bd.get("top", "#e3352b")))
	top.name = "Top"
	top.position = Vector3(0, 0, R)
	lid.add_child(top)
	if bd.has("accent"):
		var tm: = TorusMesh.new()
		tm.inner_radius = R * 0.74
		tm.outer_radius = R * 0.86
		tm.rings = 32
		tm.material = _mat(Color(bd.accent))
		var ring: = MeshInstance3D.new()
		ring.mesh = tm
		ring.position = Vector3(0, R * 0.52, R)
		lid.add_child(ring)

	var band: = _cyl(R * 1.015, R * 0.16, Color(0.08, 0.08, 0.09))
	band.name = "Band"
	body.add_child(band)

	var ring_b: = _cyl(R * 0.34, R * 0.2, Color(0.08, 0.08, 0.09))
	ring_b.rotation.x = PI / 2.0
	ring_b.position = Vector3(0, 0, R * 0.93)
	body.add_child(ring_b)
	var button: = _cyl(R * 0.22, R * 0.2, Color(0.97, 0.97, 0.97), true)
	button.name = "Button"
	button.rotation.x = PI / 2.0
	button.position = Vector3(0, 0, R * 1.0)
	body.add_child(button)
	return ball


static func _part(ball: Node3D, path: String) -> Node3D:
	return ball.get_node("Pivot/Body/" + path)




static func _tw(host: Node) -> Tween:
	var b: = host.get_node_or_null("/root/Battle")
	return host.create_tween().set_speed_scale(b.fight_speed() if b else 1.0)


static func _button_mat(ball: Node3D) -> StandardMaterial3D:
	return (_part(ball, "Button") as MeshInstance3D).mesh.material



static func glow(ball: Node3D, col: Color, energy: float) -> void :
	var m: = _button_mat(ball)
	m.emission = col
	m.emission_energy_multiplier = energy


static func set_lid(host: Node, ball: Node3D, open: bool, secs: = 0.12) -> void :
	var tw: = _tw(host)
	tw.tween_property(_part(ball, "Lid"), "rotation:x", LID_OPEN if open else 0.0, secs).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished



static func fly(host: Node, ball: Node3D, from: Vector3, get_to: Callable, secs: = 0.45, height: = 1.6) -> void :
	var body: = ball.get_node("Pivot/Body") as Node3D
	var step: = func(t: float) -> void :
		if is_instance_valid(ball):
			ball.global_position = from.lerp(get_to.call(), t) + Vector3(0, sin(t * PI) * height, 0)
			body.rotation.x = - t * TAU * 2.0
	var tw: = _tw(host)
	tw.tween_method(step, 0.0, 1.0, secs)
	await tw.finished
	if is_instance_valid(ball):
		body.rotation.x = 0.0




static func wobble(host: Node, ball: Node3D) -> void :
	var pivot: = ball.get_node("Pivot")
	Audio.play_at("sfx/capture/wobble", ball.global_position)
	glow(ball, Color(1, 0.2, 0.15), 2.5)
	var tw: = _tw(host)
	tw.tween_property(pivot, "rotation:z", 0.42, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(pivot, "rotation:z", -0.42, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(pivot, "rotation:z", 0.12, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(pivot, "rotation:z", 0.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback( func(): if is_instance_valid(ball): glow(ball, Color.WHITE, 0.0))
	tw.tween_interval(0.6)
	await tw.finished





static func throw_and_wobble(host: Node, parent: Node3D, from: Vector3, w: Node3D, ball_id: String, shakes: int) -> Node3D:
	var ball: = make_ball(ball_id)
	parent.add_child(ball)
	ball.global_position = from
	Audio.play_at("sfx/pokemon/ball_throw", from)
	var target: = func() -> Vector3:
		if is_instance_valid(w):
			var h: float = w.look_height() if w.has_method("look_height") else 0.9
			return w.global_position + Vector3(0, h * 0.9, 0)
		return from + Vector3(0, 0.9, 0)
	await fly(host, ball, from, target)
	if not _ok(ball, w):
		return null
	Audio.play_at("sfx/capture/ball_hit", ball.global_position)

	var hover: Vector3 = target.call() + Vector3(0, 0.35, 0)
	var tw0: = _tw(host)
	tw0.tween_property(ball, "global_position", hover, 0.12).set_ease(Tween.EASE_OUT)
	await tw0.finished
	if not _ok(ball, w):
		return null
	await set_lid(host, ball, true)
	var spr: Node3D = w.get_node("Sprite3D")
	glow(ball, Color(1, 0.3, 0.3), 3.0)
	var tw2: = _tw(host).set_parallel(true)
	tw2.tween_property(spr, "scale", Vector3.ONE * 0.05, 0.28)
	tw2.tween_property(spr, "modulate", Color(3, 0.5, 0.5), 0.2)
	tw2.tween_property(spr, "global_position", hover, 0.28)
	await tw2.finished
	if not _ok(ball, w):
		return null
	w.visible = false
	Audio.play_at("sfx/capture/absorb", ball.global_position)
	glow(ball, Color.WHITE, 0.0)
	await set_lid(host, ball, false, 0.1)
	if not _ok(ball, w):
		return null


	var gy: float = w.ground_y() if w.has_method("ground_y") else w.global_position.y
	var on_water: bool = is_instance_valid(w.combat) and w.combat.surface() != Water.Surface.GROUND
	var rest: = gy + R * (0.7 if on_water else 1.0)
	var ground: = Vector3(w.global_position.x, rest, w.global_position.z)
	var tw3: = _tw(host)
	tw3.tween_property(ball, "global_position", ground, 0.45).set_trans(Tween.TRANS_SINE if on_water else Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw3.tween_callback( func() -> void : Audio.play_at("sfx/capture/ball_land", ground))
	tw3.tween_interval(0.45)
	await tw3.finished
	if on_water:
		var bob: = _tw(host).set_loops(2)
		bob.tween_method( func(y: float) -> void :
			if is_instance_valid(ball):
				ball.global_position.y = y, rest - 0.02, rest + 0.07, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_method( func(y: float) -> void :
			if is_instance_valid(ball):
				ball.global_position.y = y, rest + 0.07, rest - 0.02, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in mini(shakes, 3):
		if not _ok(ball, w):
			return null
		await wobble(host, ball)
	return ball if _ok(ball, w) else null



static func success(host: Node, ball: Node3D, linger: = 1.2) -> void :
	var pivot: = ball.get_node("Pivot")
	var tw: = _tw(host)
	tw.tween_property(pivot, "rotation:z", 0.08, 0.05)
	tw.tween_property(pivot, "rotation:z", 0.0, 0.08)
	await tw.finished
	if not is_instance_valid(ball):
		return
	Audio.play_at("sfx/capture/caught_click", ball.global_position)
	glow(ball, Color(1, 1, 0.8), 4.0)
	var mv: = host.get_node_or_null("/root/Vfx")
	if mv:
		mv.burst(ball.global_position + Vector3(0, 0.25, 0), Color(1, 0.95, 0.5), 22, 0.45, 3.5)
	var fade: = func(e: float) -> void :
		if is_instance_valid(ball):
			glow(ball, Color(1, 1, 0.8), e)
	var tw2: = _tw(host)
	tw2.tween_method(fade, 4.0, 0.0, 0.6)
	tw2.tween_interval(maxf(linger - 0.6, 0.0))
	await tw2.finished
	if is_instance_valid(ball):
		var tw3: = _tw(host)
		tw3.tween_property(ball, "scale", Vector3.ONE * 0.01, 0.25)
		tw3.tween_callback(ball.queue_free)
		await tw3.finished




static func release(host: Node, ball: Node3D, w: Node3D, spr_pos: Vector3) -> void :
	if is_instance_valid(ball):
		glow(ball, Color(1, 0.25, 0.2), 3.0)
		await set_lid(host, ball, true, 0.08)
		Audio.play_at("sfx/capture/breakout", ball.global_position)
	if not is_instance_valid(w):
		if is_instance_valid(ball):
			ball.queue_free()
		return
	var mv: = host.get_node_or_null("/root/Vfx")
	if mv:
		mv.burst(w.global_position + Vector3(0, 0.5, 0), Color(1, 1, 1), 16, 0.3, 4.0)
	var spr: Node3D = w.get_node("Sprite3D")
	w.visible = true
	spr.position = spr_pos
	var tw: = _tw(host).set_parallel(true)
	tw.tween_property(spr, "scale", Vector3.ONE, 0.2)
	tw.tween_property(spr, "modulate", w.base_tint() if w.has_method("base_tint") else Color.WHITE, 0.3)
	if is_instance_valid(ball):
		tw.tween_property(ball, "scale", Vector3.ONE * 0.01, 0.2)
	await tw.finished
	if is_instance_valid(ball):
		ball.queue_free()



static func send_out(host: Node, parent: Node3D, from: Vector3, to: Vector3, ball_id: String) -> void :
	var ball: = make_ball(ball_id)
	parent.add_child(ball)
	ball.global_position = from
	Audio.play_at("sfx/pokemon/ball_throw", from)
	var land: = to + Vector3(0, R + 0.25, 0)
	await fly(host, ball, from, func() -> Vector3: return land, 0.35, 1.4)
	if not is_instance_valid(ball):
		return
	await set_lid(host, ball, true, 0.08)
	Audio.play_at("sfx/pokemon/ball_open", to)
	if not is_instance_valid(ball):
		return
	var mv: = host.get_node_or_null("/root/Vfx")
	if mv:
		mv.burst(land, Color(1, 1, 1), 12, 0.25, 3.0)
	var tw: = _tw(host)
	tw.tween_property(ball, "scale", Vector3.ONE * 0.01, 0.12)
	await tw.finished
	if is_instance_valid(ball):
		ball.queue_free()


static func _ok(ball: Node3D, w: Node3D) -> bool:
	if is_instance_valid(ball) and is_instance_valid(w):
		return true
	if is_instance_valid(ball):
		ball.queue_free()
	return false
