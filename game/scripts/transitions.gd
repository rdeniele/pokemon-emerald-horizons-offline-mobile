extends Node



const CreatureDef: = preload("res://scripts/creature.gd")
const PkLoadingScript: = preload("res://scripts/ui/kit/pk_loading.gd")


const GROUND_LAYER: = 4


var pending_spawn: = ""

var pending_point: = Vector3.INF
var pending_facing: = 0

var _transitioning: = false

var _fader: ColorRect
var _loading: Control


func _ready() -> void :
	P1Prof.boot()
	P1Prof.maybe_autodrive(self)
	_build_fader()



func busy() -> bool:
	return _transitioning


func _build_fader() -> void :
	var layer: = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fader = ColorRect.new()
	_fader.color = Color.BLACK
	_fader.modulate.a = 0.0
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fader)

	_loading = PkLoadingScript.new()
	_loading.name = "Loading"
	_fader.add_child(_loading)



func fade(to: float, secs: float) -> void :
	var tw: = create_tween()
	tw.tween_property(_fader, "modulate:a", to, secs)
	await tw.finished



func go_to(scene_path: String, spawn: String, force: = false, fade_time: = 0.3) -> void :
	if (Game.is_busy() and not force) or not ResourceLoader.exists(scene_path):
		return

	var _p1_tag: String = scene_path.get_file().get_basename()
	var _p1_all: = Time.get_ticks_usec()
	P1Prof.note("go_to %s spawn=%s BEGIN" % [_p1_tag, spawn])
	_transitioning = true
	var p: = Game.get_player()
	if p:
		p.controls_enabled = false
	while not Game._sending.is_empty():
		await get_tree().process_frame
	var out_idx: Array = []
	var out_nodes: Array = []
	for i in Game.companions.keys():
		if Game.is_out(i):
			out_idx.append(i)
			out_nodes.append(Game.companions[i])
	if fade_time > 0.0:
		var _p1_fade: = Time.get_ticks_usec()
		await fade(1.0, fade_time)
		P1Prof.span("go_to %s fade-out" % _p1_tag, Time.get_ticks_usec() - _p1_fade)
		_loading.begin()
	Game.companions.clear()
	Game._sending.clear()
	pending_spawn = spawn





	if not pending_point.is_finite() and _same_scene(scene_path):
		P1Prof.note("go_to %s same scene: keep instance" % _p1_tag)
		for c in out_nodes:
			if is_instance_valid(c):
				c.queue_free()
	else:
		var _p1_load: = Time.get_ticks_usec()
		await _change_scene(scene_path)
		P1Prof.span("go_to %s change_scene" % _p1_tag, Time.get_ticks_usec() - _p1_load)
		var _p1_prev: = Time.get_ticks_usec()
		await get_tree().process_frame
		P1Prof.span("go_to %s frame1 after change (scene swap + _ready)" % _p1_tag, Time.get_ticks_usec() - _p1_prev)
		for _i in 30:
			if get_tree().current_scene and get_tree().current_scene.scene_file_path == scene_path:
				break
			_p1_prev = Time.get_ticks_usec()
			await get_tree().process_frame
			var _p1_dt: = Time.get_ticks_usec() - _p1_prev
			if _p1_dt > 4000:
				P1Prof.span("go_to %s frame after change" % _p1_tag, _p1_dt)
		P1Prof.span("go_to %s scene-in-tree" % _p1_tag, Time.get_ticks_usec() - _p1_load)
	P1Prof.flush_acc(_p1_tag)
	await get_tree().process_frame

	var _p1_prep: = Time.get_ticks_usec()
	var streamer: = get_tree().get_first_node_in_group("zone_streamer")
	if streamer and not pending_point.is_finite():
		_loading.stage(0.5)
		pending_spawn = await streamer.prepare(pending_spawn)
	P1Prof.span("go_to %s streamer.prepare" % _p1_tag, Time.get_ticks_usec() - _p1_prep)
	_loading.stage(1.0)


	var cs: = get_tree().current_scene
	if cs and cs.has_method("prepare_arrival"):
		cs.prepare_arrival(pending_spawn, pending_point)
	var _p1_place: = Time.get_ticks_usec()
	p = Game.get_player()
	if p:
		p.controls_enabled = false
		place_player(p)
		snap_arrival_hooks()
		for i in out_idx:
			respawn_companion(i, p)
	P1Prof.span("go_to %s place_player+companions" % _p1_tag, Time.get_ticks_usec() - _p1_place)


	await _warm_black(fade_time > 0.0)
	await _loading_hold()
	if fade_time > 0.0:
		var _p1_fin: = Time.get_ticks_usec()
		await fade(0.0, fade_time)
		P1Prof.span("go_to %s fade-in" % _p1_tag, Time.get_ticks_usec() - _p1_fin)
	_loading.end()
	if p and not Game.cutscene:
		p.controls_enabled = true
	_transitioning = false
	P1Prof.span("go_to %s TOTAL (fades included)" % _p1_tag, Time.get_ticks_usec() - _p1_all)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		P1Prof.span("go_to %s first frame DRAWN" % _p1_tag, Time.get_ticks_usec() - _p1_all)
	P1Prof.snapshot("go_to %s end" % _p1_tag)
	SaveGame.autosave()




func _same_scene(scene_path: String) -> bool:
	var cs: = get_tree().current_scene
	return cs != null and cs.scene_file_path == scene_path





func _change_scene(scene_path: String) -> void :
	if ResourceLoader.load_threaded_request(scene_path) != OK:
		get_tree().change_scene_to_file(scene_path)
		return
	var prog: Array = []
	while true:
		var st: = ResourceLoader.load_threaded_get_status(scene_path, prog)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			get_tree().change_scene_to_file(scene_path)
			return
		if not prog.is_empty():
			_loading.stage(float(prog[0]) * 0.5)
		await get_tree().process_frame
	var packed: PackedScene = ResourceLoader.load_threaded_get(scene_path)
	if packed == null:
		get_tree().change_scene_to_file(scene_path)
		return
	get_tree().change_scene_to_packed(packed)









func _warm_black(hold: bool) -> void :
	if not hold or DisplayServer.get_name() == "headless":
		return
	var _p1: = Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	P1Prof.span("go_to warm 1 frame", Time.get_ticks_usec() - _p1)




func _loading_hold() -> float:
	if not _loading.active():
		return 0.0
	var need: float = PkLoadingScript.SHOW_AFTER + PkLoadingScript.MIN_VISIBLE
	while _loading.active() and _loading.visible and _loading.held() < need:
		await get_tree().process_frame
	return _loading.held()








func snap_arrival_hooks() -> void :
	var scene: = get_tree().current_scene
	if scene:


		if scene.has_method("sync_rooms"):
			scene.sync_rooms()
		for n in scene.find_children("*", "WorldEnvironment", true, false):
			if n.has_method("snap"):
				n.snap()
	var cues: = get_node_or_null("/root/Audio/AudioCues")
	if cues and cues.has_method("snap_interior"):
		cues.snap_interior()






func go_to_at(scene_path: String, pos: Vector3, facing: = 0) -> void :
	if not ResourceLoader.exists(scene_path):
		return
	pending_point = pos
	pending_facing = facing
	await go_to(scene_path, "", true, 0.0)




func ground_y(pos: Vector3, fallback: = 0.0) -> float:
	var vp: = get_viewport()
	if vp == null or vp.world_3d == null:
		return fallback
	var q: = PhysicsRayQueryParameters3D.create(Vector3(pos.x, pos.y + 30.0, pos.z), Vector3(pos.x, pos.y - 30.0, pos.z), GROUND_LAYER)
	q.collide_with_areas = false
	var hit: = vp.world_3d.direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else fallback



func ground_xz(x: float, z: float) -> float:
	return ground_y(Vector3(x, 0.0, z), 0.0)





var _water_cache: Array = []
var _water_frame: = -1

func water_rects() -> Array:
	var frame: = Engine.get_physics_frames()
	if frame == _water_frame:
		return _water_cache
	_water_frame = frame
	var out: Array = []
	var streamer: = get_tree().get_first_node_in_group("zone_streamer")
	if streamer == null:
		_water_cache = out
		return out
	for id in streamer.loaded:
		var zn: Node = streamer.loaded[id]
		var w: Node = zn.get_node_or_null("World") if is_instance_valid(zn) else null
		if w == null or not w.data:
			continue
		for wt in w.data.get("water", []):
			var r: Array = wt.rect
			out.append(Rect2(r[0], r[1], r[2], r[3]))
	_water_cache = out
	return out



func surface_at(x: float, z: float) -> int:
	return Water.surface(water_rects(), x, z)


func place_player(p: Node3D) -> void :
	if pending_point.is_finite():
		p.global_position = pending_point
		p.row = pending_facing
		p.sprite.frame = p.row * 3
		pending_point = Vector3.INF
		pending_spawn = ""
		var cam0: = Game.get_camera_rig()
		if cam0:
			cam0.snap()
		return
	for sp in get_tree().get_nodes_in_group("spawn_point"):
		if sp.name == pending_spawn:
			p.global_position = sp.global_position
			p.row = sp.facing
			p.sprite.frame = p.row * 3
			break
	pending_spawn = ""
	var cam: = Game.get_camera_rig()
	if cam:
		cam.snap()


func respawn_companion(i: int, p: Node3D) -> void :
	if Game.party[i].hp <= 0:
		return
	var a: = randf() * TAU
	var c: = Encounters.spawn_mon(Game.party[i], p.get_parent(), p.global_position + Vector3(cos(a), 0, sin(a)) * 1.2, false)
	c.mode = CreatureDef.Mode.FOLLOW
	c.follow_slot = i
	Game.companions[i] = c
	Game.party_changed.emit()
