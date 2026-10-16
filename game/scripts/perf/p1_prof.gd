extends RefCounted
class_name P1Prof









static var auto_drive: = false

static var _enabled: = -1
static var _boot_usec: = 0
static var _steps: = 0
static var _driving: = false


static func on() -> bool:
	if auto_drive:
		return true
	if _enabled == -1:
		_enabled = 0
		if OS.get_environment("P1_PERF") == "1":
			_enabled = 1
		else:
			for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
				if a == "--p1" or a.begins_with("--p1="):
					_enabled = 1
					break
	return _enabled == 1



static func boot() -> void :
	if _boot_usec == 0:
		_boot_usec = Time.get_ticks_usec()
		platform()


static func note(msg: String) -> void :
	if on():
		print("[P1] ", msg)



static func span(label: String, usec: int) -> void :
	if on():
		print("[P1] %s: %.1f ms" % [label, usec / 1000.0])


static func mark(label: String) -> void :
	if on():
		print("[P1] %s: %.1f ms since first frame of game code" % [label, (Time.get_ticks_usec() - _boot_usec) / 1000.0])



static func step(tag: String, name: String, t0: int, f0: int) -> void :
	if not on():
		return
	_steps += 1
	print("[P1] step %s/%s: %.1f ms over %d frame(s)" % [tag, name, 
		(Time.get_ticks_usec() - t0) / 1000.0, Engine.get_frames_drawn() - f0])



static var _acc: = {}


static func acc(label: String, usec: int) -> void :
	if not on():
		return
	var e: Array = _acc.get(label, [0, 0])
	e[0] += usec
	e[1] += 1
	_acc[label] = e


static func flush_acc(tag: String) -> void :
	if not on():
		return
	for label in _acc:
		var e: Array = _acc[label]
		print("[P1] acc (%s) %s: %.1f ms over %d call(s)" % [tag, label, e[0] / 1000.0, e[1]])
	_acc.clear()



static func snapshot(tag: String) -> void :
	if not on():
		return
	print("[P1] snapshot %s: nodes=%d objects=%d resources=%d tex_mem=%.1fMB buf_mem=%.1fMB draws=%d prims=%d" % [
		tag, 
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), 
		int(Performance.get_monitor(Performance.OBJECT_COUNT)), 
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), 
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, 
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), 
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])


static func platform() -> void :
	if not on():
		return
	var threads: = true
	if ClassDB.class_has_method("OS", "can_use_threads"):
		threads = OS.call("can_use_threads")
	print("[P1] platform os=%s mode=%s driver=%s gpu=%s cpus=%d threads=%s feature_threads=%s frames_drawn=%d" % [
		OS.get_name(), 
		RenderingServer.get_current_rendering_method(), 
		RenderingServer.get_current_rendering_driver_name(), 
		RenderingServer.get_video_adapter_name(), 
		OS.get_processor_count(), threads, OS.has_feature("threads"), Engine.get_frames_drawn()])
	print("[P1] settings method=%s mobile=%s etc2_astc=%s" % [
		ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"), 
		ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "?"), 
		ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc", "?")])






static func maybe_autodrive(host: Node) -> void :
	if not on():
		return
	var args: = OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if auto_drive or "--p1-drive" in args:
		var d: = Node.new()
		d.set_script(load("res://scripts/perf/p1_drive_logic.gd"))
		d.name = "P1Drive"
		host.add_child(d)



const STEPS: = [
	["new_game->bedroom", "res://scenes/interiors/pallet_town_interiors.tscn", "bedroom_start"], 
	["bedroom->downstairs", "res://scenes/interiors/pallet_town_interiors.tscn", "player_house_stairs"], 
	["downstairs->pallet", "res://scenes/world/overworld.tscn", "player_house_door"], 
]


const PALLET: = "res://scenes/interiors/pallet_town_interiors.tscn"
const PALLET_ROOMS: = [["bedroom", "bedroom"], ["player_house_stairs", "stairs"], 
	["rival_house", "rival"], ["lab", "lab"]]






static func room_steps(first: String, town: = PALLET, rooms: = PALLET_ROOMS) -> Array:
	var steps: Array = [["cold->%s" % first, town, first]]
	for r in rooms:
		if String(r[0]) != first:
			steps.append(["room->%s" % r[1], town, String(r[0])])
	return steps



static func drive_rooms() -> Array:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--p1-rooms="):
			var out: Array = []
			for s in a.trim_prefix("--p1-rooms=").split(","):
				out.append([s, s])
			return out
	return PALLET_ROOMS



static func drive_scene() -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--p1-scene="):
			return a.trim_prefix("--p1-scene=")
	return PALLET




static func first_spawn() -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--p1-spawn="):
			return a.trim_prefix("--p1-spawn=")
	return "bedroom"



static func drive(tree: SceneTree, steps: Array) -> void :
	if _driving:
		return
	_driving = true
	await tree.process_frame
	var t: = tree.root.get_node_or_null("Transitions")
	if t == null:
		P1Prof.note("drive: no Transitions autoload")
		return
	for _i in 5:
		await tree.process_frame
	P1Prof.snapshot("boot")
	P1Prof.mark("boot -> first scene drawable")
	for s in steps:
		var spec: Array = s
		P1Prof.note("DRIVE -> %s (%s / %s)" % [spec[0], spec[1], spec[2]])
		var t0: = Time.get_ticks_usec()
		await t.go_to(String(spec[1]), String(spec[2]), true)
		P1Prof.span("DRIVE %s total" % spec[0], Time.get_ticks_usec() - t0)
		await tree.process_frame
		await RenderingServer.frame_post_draw
		P1Prof.snapshot("after %s" % spec[0])
	P1Prof.note("DRIVE done")
