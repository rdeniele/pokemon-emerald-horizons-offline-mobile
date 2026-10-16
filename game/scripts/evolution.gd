extends Node













const PokemonSprites: = preload("res://scripts/pokemon_sprites.gd")
const DexData: = preload("res://scripts/dex.gd")

signal finished(evolved: bool)

const DURATION: = 5.0

var creature: Node3D
var into: = ""
var from: = ""
var _t: = 0.0
var _done: = false
var _layer: CanvasLayer
var _label: RichTextLabel
var _old_look: = {}
var _new_look: = {}
var _showing_new: = false


var _learned: Array = []

var debug_cancel_at: = -1.0


static func begin(host: Node, c: Node3D, target: String) -> Node:
	var e: Node = load("res://scripts/evolution.gd").new()
	e.creature = c
	e.into = target
	host.add_child(e)
	return e


func _ready() -> void :
	from = creature.species
	creature.evolving = true
	Audio.push_music("evolution", "music/evolution", 0.6)
	Audio.start_loop("evo_charge", "sfx/evolution/evo_charge")
	_old_look = PokemonSprites.spec(from)
	_new_look = PokemonSprites.spec(into)
	_build_ui()
	_say("What? [b]%s[/b] is evolving!" % creature.mon.display_name, _stop_keys())
	var mv: = get_node_or_null("/root/Vfx")
	if mv:
		mv.popup(creature.global_position + Vector3(0, 2.2, 0), "Evolving!", Color(1, 1, 0.75), 1.1)


func _build_ui() -> void :
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	var panel: = PanelContainer.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.88)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(1, 0.95, 0.7, 0.8)
	sb.set_border_width_all(2)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_top = -150
	panel.offset_bottom = -96
	panel.offset_left = -330
	panel.offset_right = 330
	_layer.add_child(panel)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.add_theme_font_size_override("normal_font_size", 22)
	_label.add_theme_font_size_override("bold_font_size", 22)
	panel.add_child(_label)


func _say(text: String, keys: = "") -> void :
	_label.text = "[center]%s%s[/center]" % [text, keys]



func _stop_keys() -> String:
	var caps: PackedStringArray = ControlsScreen.display_keys(["evo_cancel"])
	var key: = caps[0] if caps.size() > 0 else "B"
	return "\n[color=#ffd970][%s][/color] [color=#c9d3e0]Stop evolution[/color]" % key



func _continue_keys() -> String:
	var key: = Controls.key_label("confirm")
	if key == "":
		return "\n[color=#ffd970]continue[/color]"
	return "\n[color=#ffd970][%s][/color] [color=#c9d3e0]continue[/color]" % key


func _process(delta: float) -> void :
	if _done:
		return
	if not is_instance_valid(creature):
		_finish(false, "")
		return
	_t += delta
	var spr: Sprite3D = creature.sprite

	var glow: = clampf(_t / 0.8, 0.0, 1.0)
	spr.modulate = Color(1, 1, 1).lerp(Color(3.2, 3.2, 3.0), glow)
	if _t > 1.0:
		var k: = (_t - 1.0) / (DURATION - 1.0)
		var freq: = lerpf(1.5, 12.0, k * k)
		var show_new: = fmod(_t * freq, 1.0) > 0.5
		if show_new != _showing_new:
			_showing_new = show_new
			PokemonSprites.apply(spr, into if show_new else from)
			spr.modulate = Color(3.2, 3.2, 3.0)
	if (debug_cancel_at >= 0.0 and _t >= debug_cancel_at) or Input.is_action_pressed("evo_cancel"):
		_cancel()
	elif _t >= DURATION:
		_complete()


func _cancel() -> void :
	Audio.stop_loop("evo_charge")
	Audio.play("sfx/evolution/evo_cancel")
	PokemonSprites.apply(creature.sprite, from)
	creature.mon.evo_cancelled_level = creature.mon.level
	_finish(false, "Huh? [b]%s[/b] stopped evolving!" % creature.mon.display_name)


func _complete() -> void :
	Audio.stop_loop("evo_charge")
	Audio.play("sfx/evolution/evo_flash")
	Audio.jingle("music/evolution_done")
	var old_name: String = creature.mon.display_name
	var before: Array = creature.mon.moves.duplicate()
	var missed: Array = creature.mon.evolve(into)
	_learned = creature.mon.moves.filter( func(id): return not before.has(id))
	for id in missed:
		Progression.queue_move(creature.mon, id)
	creature.species = into
	creature.moves = []
	creature.apply_species(false)
	var mv: = get_node_or_null("/root/Vfx")
	if mv:
		mv.burst(creature.global_position + Vector3(0, 0.8, 0), Color(1, 1, 0.8), 40, 0.6, 5.0)
		mv.popup(creature.global_position + Vector3(0, 2.4, 0), into + "!", Color(1, 0.95, 0.5), 1.4)
	_finish(true, "Congratulations! Your [b]%s[/b] evolved into [b]%s[/b]!" % [old_name, into])


func _finish(evolved: bool, text: String) -> void :
	_done = true
	Audio.stop_loop("evo_charge")
	Audio.pop_music("evolution", 0.8)
	if is_instance_valid(creature):
		creature.evolving = false
		var spr: Sprite3D = creature.sprite
		creature.create_tween().tween_property(spr, "modulate", creature.base_tint(), 0.6)
		creature.refresh_label()



	if text != "":
		await _line(text)
	for id in _learned:
		var who: String = creature.mon.display_name if is_instance_valid(creature) else into
		await _line("%s learned %s!" % [who, String(DexData.move(id).get("name", id))])
	finished.emit(evolved)
	queue_free()




func _line(text: String) -> void :
	_say(text, _continue_keys())
	await Battle.wait_confirm()
