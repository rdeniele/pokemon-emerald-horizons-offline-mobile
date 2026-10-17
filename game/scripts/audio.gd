extends Node


























const ROOT: = "res://assets/audio/"
const EXTS: = ["ogg", "mp3", "wav"]

const LOOP_SLOTS: = ["music/pallet_town", "music/route_1", "music/indoors", "music/lab", "music/battle_wild", "music/evolution", "music/oak", "music/rival", "music/battle_trainer", 
	"music/viridian", "music/viridian_forest", "music/pewter_gym", "music/battle_gym_leader", "music/title", "sfx/weather/rain"]

const CFG_PATH: = "user://audio.cfg"

const BUS_DEFAULTS: = {"Music": 0.8, "SFX": 1.0, "UI": 1.0, "Ambience": 0.6}

const AMB_DB: = -10.0

const SILENT_DB: = -80.0



const JINGLE_MAX_SECS: = 8.0
const JINGLE_CAPS: = {"music/encounter": 3.0, "music/victory": 5.0, "music/victory_trainer": 5.0}
const JINGLE_CUT_FADE: = 0.3


const JINGLE_LENGTHS_PATH: = "res://assets/audio/music/jingle_lengths.json"

const JINGLE_TAIL: = 0.15

const INTERRUPT_FADE: = 0.15

const SFX_VOICES: = 12
const SFX3D_VOICES: = 8
const SFX_UNIT_SIZE: = 18.0
const SFX_MAX_DISTANCE: = 80.0

const SFX_MIN_GAP_MS: = 40


var debug_log: = false

var current_music: = ""

var area_slot: = ""

var current_ambience: = ""

signal jingles_done

signal sfx_played(slot: String)

var _cfg: = ConfigFile.new()
var _streams: = {}
var _warned: = {}
var _tweens: = {}


var _mus_a: AudioStreamPlayer
var _mus_b: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _jingle: AudioStreamPlayer
var _stack: Array = []
var _resume: = {}
var _jingle_queue: Array = []
var _jingle_active: = false
var _jingle_slot: = ""
var _paused_player: AudioStreamPlayer
var _pending_fade: = 0.6
var _jingle_gen: = 0
var _jingle_audible: = {}


var _amb_a: AudioStreamPlayer
var _amb_b: AudioStreamPlayer
var _amb_player: AudioStreamPlayer


var _sfx: Array[AudioStreamPlayer] = []
var _sfx3d: Array[AudioStreamPlayer3D] = []
var _sfx_i: = 0
var _sfx3d_i: = 0
var _last_played: = {}
var _loops: = {}


func _ready() -> void :
	_ensure_buses()
	_load_volumes()
	_mus_a = _make_player("Music")
	_mus_b = _make_player("Music")
	_jingle = _make_player("Music")
	_jingle.finished.connect( func(): _jingle_ended(_jingle_gen))
	if FileAccess.file_exists(JINGLE_LENGTHS_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(JINGLE_LENGTHS_PATH))
		if data is Dictionary:
			_jingle_audible = data
	_amb_a = _make_player("Ambience")
	_amb_b = _make_player("Ambience")
	for i in SFX_VOICES:
		_sfx.append(_make_player("SFX"))
	for i in SFX3D_VOICES:
		var p: = AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = SFX_UNIT_SIZE
		p.max_distance = SFX_MAX_DISTANCE
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_sfx3d.append(p)
	var cues: Node = preload("res://scripts/audio_cues.gd").new()
	cues.name = "AudioCues"
	add_child(cues)



func _ensure_buses() -> void :
	for bus in BUS_DEFAULTS:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		var idx: = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus)
		AudioServer.set_bus_send(idx, "Master")


func _load_volumes() -> void :
	_cfg.load(CFG_PATH)
	for bus in BUS_DEFAULTS:
		var v: = clampf(float(_cfg.get_value("volume", bus, BUS_DEFAULTS[bus])), 0.0, 1.0)
		_apply_volume(bus, v)



func set_volume(bus: String, v: float) -> void :
	v = clampf(v, 0.0, 1.0)
	_apply_volume(bus, v)
	_cfg.set_value("volume", bus, v)
	_cfg.save(CFG_PATH)


func get_volume(bus: String) -> float:
	var idx: = AudioServer.get_bus_index(bus)
	if idx == -1 or AudioServer.is_bus_mute(idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


func _apply_volume(bus: String, v: float) -> void :
	var idx: = AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, v <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))


func _make_player(bus: String) -> AudioStreamPlayer:
	var p: = AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p





func stream(slot: String) -> AudioStream:
	if _streams.has(slot):
		return _streams[slot] as AudioStream
	var st: AudioStream = null
	for ext in EXTS:
		var path: String = ROOT + slot + "." + ext
		if ResourceLoader.exists(path):
			st = load(path) as AudioStream
			break
	if st == null:
		_streams[slot] = null
		if not _warned.has(slot):
			_warned[slot] = true
			push_warning("[audio] missing slot: " + slot)
			_log("missing " + slot)
		return null
	if slot in LOOP_SLOTS or slot.begins_with("sfx/ambience/"):
		_force_loop(st)
	_streams[slot] = st
	return st





func resolve(slots: Array) -> String:
	for s in slots:
		if has_slot(String(s)):
			return String(s)
	return String(slots[-1]) if not slots.is_empty() else ""



func has_slot(slot: String) -> bool:
	for ext in EXTS:
		var path: String = ROOT + slot + "." + ext
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return true
	return false


func _force_loop(st: AudioStream) -> void :
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	elif st is AudioStreamWAV:
		var w: = st as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = _wav_frames(w)


func _wav_frames(w: AudioStreamWAV) -> int:

	var bytes_per_sample: = 1 if w.format == AudioStreamWAV.FORMAT_8_BITS else 2
	var channels: = 2 if w.stereo else 1
	return w.data.size() / (bytes_per_sample * channels)




func set_area_music(slot: String, fade: = 1.5) -> void :
	area_slot = slot
	_apply(fade)



func push_music(key: String, slot: String, fade: = 0.5) -> void :
	_pop_key(key)
	_stack.append([key, slot])
	_apply(fade)



func pop_music(key: String, fade: = 1.0) -> void :
	_pop_key(key)
	_apply(fade)



func stop_music(fade: = 1.0) -> void :
	area_slot = ""
	_stack.clear()
	_apply(fade)


func _pop_key(key: String) -> void :
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i][0] == key:
			_stack.remove_at(i)


func _target() -> String:
	return _stack[-1][1] if not _stack.is_empty() else area_slot


func _is_area_slot(slot: String) -> bool:
	if slot == "":
		return false
	for e in _stack:
		if e[1] == slot:
			return false
	return true



func _apply(fade: float) -> void :
	if _jingle_active:
		_pending_fade = fade
		return
	var target: = _target()
	if target == current_music:
		return
	var st: AudioStream = null
	if target != "":
		st = stream(target)
		if st == null:
			return
	var prev: = _music_player
	if prev:
		var old_slot: = current_music
		var area: = _is_area_slot(old_slot)
		if prev.stream_paused:
			prev.stream_paused = false
			_music_stop(prev, old_slot, area)
		else:
			_gain_tween(prev, false, fade, 0.0, _music_out_done.bind(prev, old_slot, area))
	if target == "":
		current_music = ""
		_music_player = null
		return
	_music_player = _mus_b if prev == _mus_a else _mus_a
	_music_player.stream = st
	_music_player.volume_db = SILENT_DB
	_music_player.stream_paused = false
	var at: = float(_resume.get(target, 0.0)) if _is_area_slot(target) else 0.0
	_music_player.play(at)
	_gain_tween(_music_player, true, fade, 0.0)
	current_music = target
	_log("music -> %s (fade %.1f)" % [target, fade])


func _music_out_done(p: AudioStreamPlayer, slot: String, area: bool) -> void :
	_music_stop(p, slot, area)


func _music_stop(p: AudioStreamPlayer, slot: String, area: bool) -> void :
	if area and p.playing:
		_resume[slot] = p.get_playback_position()
	p.stop()







func jingle(slot: String, interrupt: = false) -> void :
	if interrupt:
		_jingle_queue.push_front(slot)
		if _jingle_active:
			_jingle_cut(_jingle_gen, INTERRUPT_FADE)
		else:
			_start_jingles()
		return
	if _jingle_queue.size() >= 3:
		return
	_jingle_queue.append(slot)
	if not _jingle_active:
		_start_jingles()


func _start_jingles() -> void :
	_jingle_active = true
	_paused_player = _music_player

	if _paused_player:
		_gain_tween(_paused_player, false, 0.15, 0.0, _jingle_pause_done)
	_play_next_jingle()


func _jingle_pause_done() -> void :
	if _jingle_active and _paused_player and _paused_player.playing:
		_paused_player.stream_paused = true


func _play_next_jingle() -> void :
	_jingle_gen += 1
	if _jingle_queue.is_empty():
		_finish_jingles()
		return
	var slot: String = _jingle_queue.pop_front()
	var st: = stream(slot)
	if st == null:
		_play_next_jingle()
		return
	_jingle_slot = slot
	_kill_tween(_jingle)
	_jingle.stream = _one_shot(st)
	_jingle.volume_db = 0.0
	_jingle.play()

	var secs: = minf(float(JINGLE_CAPS.get(slot, JINGLE_MAX_SECS)), JINGLE_MAX_SECS)
	var len_s: = st.get_length()
	if _jingle_audible.has(slot):
		len_s = minf(float(_jingle_audible[slot]) + JINGLE_TAIL, len_s if len_s > 0.0 else INF)
	if len_s > 0.0 and len_s < secs:
		secs = len_s
	var gen: = _jingle_gen
	get_tree().create_timer(secs, true, false, true).timeout.connect(_jingle_cut.bind(gen))
	_log("jingle %s (max %.1f s)" % [slot, secs])



func _jingle_ended(gen: int) -> void :
	if gen == _jingle_gen and _jingle_active:
		_play_next_jingle()



func _jingle_cut(gen: int, fade: = JINGLE_CUT_FADE) -> void :
	if gen != _jingle_gen or not _jingle_active:
		return
	_jingle_gen += 1
	var next_gen: = _jingle_gen
	_gain_tween(_jingle, false, fade, 0.0, func():
		if next_gen == _jingle_gen and _jingle_active:
			_jingle.stop()
			_play_next_jingle())



func clear_jingles() -> void :
	_jingle_queue.clear()
	if _jingle_active:
		_jingle_cut(_jingle_gen)



func _one_shot(st: AudioStream) -> AudioStream:
	if (st is AudioStreamOggVorbis or st is AudioStreamMP3) and st.get("loop"):
		var s: = st.duplicate() as AudioStream
		s.set("loop", false)
		return s
	if st is AudioStreamWAV and (st as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED:
		var w: = st.duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_DISABLED
		return w
	return st


func _finish_jingles() -> void :
	_jingle_active = false
	_jingle_slot = ""
	var p: = _paused_player
	_paused_player = null
	if _target() != current_music:
		_apply(_pending_fade)
	elif p and is_instance_valid(p):
		p.stream_paused = false
		_gain_tween(p, true, 0.4, 0.0)
	jingles_done.emit()




func set_ambience(slot: String, fade: = 2.0) -> void :
	if slot == current_ambience:
		return
	var st: AudioStream = null
	if slot != "":
		st = stream(slot)
		if st == null:
			return
	var prev: = _amb_player
	if prev:
		_gain_tween(prev, false, fade, AMB_DB, _amb_out_done.bind(prev))
	_amb_player = _amb_b if prev == _amb_a else _amb_a
	current_ambience = slot
	if slot == "":
		return
	_amb_player.stream = st
	_amb_player.volume_db = SILENT_DB
	_amb_player.play()
	_gain_tween(_amb_player, true, fade, AMB_DB)
	_log("ambience -> " + slot)


func _amb_out_done(p: AudioStreamPlayer) -> void :
	p.stop()




func play(slot: String, vol_db: = 0.0, pitch: = 1.0, bus: = "SFX") -> void :
	play_exact(slot, vol_db, pitch * randf_range(0.96, 1.04), bus)



func play_exact(slot: String, vol_db: = 0.0, pitch: = 1.0, bus: = "SFX") -> void :
	var st: = stream(slot)
	if st == null or not _spam_ok(slot):
		return
	var p: = _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = st
	p.bus = bus
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()
	sfx_played.emit(slot)
	_log("sfx " + slot)



func play_at(slot: String, pos: Vector3, vol_db: = 0.0, pitch: = 1.0) -> void :
	var st: = stream(slot)
	if st == null or not _spam_ok(slot):
		return
	var p: = _sfx3d[_sfx3d_i]
	_sfx3d_i = (_sfx3d_i + 1) % _sfx3d.size()
	p.stream = st
	p.bus = "SFX"
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.global_position = pos
	p.play()
	sfx_played.emit(slot)
	_log("sfx " + slot)



func ui(slot: String) -> void :
	play_exact(slot, 0.0, 1.0, "UI")



func cry(species: String, at = null, pitch: = 1.0) -> void :
	var slot: = "cries/" + species.to_lower()
	if not has_slot(slot):
		var dex_data = preload("res://scripts/dex.gd")
		slot = "cries/national/" + String(dex_data.species(species).get("national_id", ""))
	if at is Vector3:
		play_at(slot, at, 0.0, pitch)
	else:
		play_exact(slot, 0.0, pitch)




func start_loop(key: String, slot: String, at = null, vol_db: = 0.0) -> void :
	if _loops.has(key):
		return
	var st: = stream(slot)
	if st == null:
		return
	var s: = st.duplicate() as AudioStream
	_force_loop(s)
	if at is Vector3:
		var p: = AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = SFX_UNIT_SIZE
		p.max_distance = SFX_MAX_DISTANCE
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		p.global_position = at
		p.stream = s
		p.volume_db = vol_db
		p.play()
		_loops[key] = p
	else:
		var p2: = AudioStreamPlayer.new()
		p2.bus = "SFX"
		p2.stream = s
		p2.volume_db = vol_db
		add_child(p2)
		p2.play()
		_loops[key] = p2
	_log("sfx " + slot)



func stop_loop(key: String, fade: = 0.15) -> void :
	if not _loops.has(key):
		return
	var p: Node = _loops[key]
	_loops.erase(key)
	_gain_tween(p, false, fade, 0.0, _loop_stop_done.bind(p))


func _loop_stop_done(p: Node) -> void :
	if is_instance_valid(p):
		p.queue_free()


func _spam_ok(slot: String) -> bool:
	var now: = Time.get_ticks_msec()
	if _last_played.has(slot) and now - int(_last_played[slot]) < SFX_MIN_GAP_MS:
		return false
	_last_played[slot] = now
	return true





func _gain_tween(p: Node, fade_in: bool, fade: float, base_db: float, done: Callable = Callable()) -> void :
	_kill_tween(p)
	if fade <= 0.0:
		_set_gain(p, 1.0 if fade_in else 0.0, base_db)
		if done.is_valid():
			done.call()
		return
	var cur: = clampf(db_to_linear(float(p.get("volume_db")) - base_db), 0.0, 1.0)
	var t0: = (asin(cur) if fade_in else acos(cur)) / (PI * 0.5)
	var t: = create_tween()
	_tweens[p] = t
	t.tween_method(_gain_step.bind(p, fade_in, base_db), t0, 1.0, fade)
	if done.is_valid():
		t.finished.connect(done)


func _gain_step(t: float, p: Node, fade_in: bool, base_db: float) -> void :
	_set_gain(p, sin(t * PI * 0.5) if fade_in else cos(t * PI * 0.5), base_db)


func _set_gain(p: Node, factor: float, base_db: float) -> void :
	if factor <= 0.0001:
		p.set("volume_db", SILENT_DB)
	else:
		p.set("volume_db", maxf(base_db + linear_to_db(factor), SILENT_DB))


func _kill_tween(p: Node) -> void :
	var t: = _tweens.get(p) as Tween
	if t and t.is_valid():
		t.kill()
	_tweens.erase(p)




func state() -> Dictionary:
	var keys: = []
	for e in _stack:
		keys.append(e[0])
	return {
		"music": current_music, 
		"area": area_slot, 
		"stack": keys, 
		"jingle": _jingle_slot, 
		"jingles": _jingle_queue.duplicate(), 
		"jingle_active": _jingle_active, 
		"ambience": current_ambience, 
		"loops": _loops.keys(), 
	}


func _log(msg: String) -> void :
	if debug_log:
		print("[audio] %.2f %s" % [Time.get_ticks_msec() / 1000.0, msg])
