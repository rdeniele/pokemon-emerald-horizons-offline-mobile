extends Node3D





const CaptureFX: = preload("res://scripts/capture_fx.gd")
const MonScript: = preload("res://scripts/stats/mon.gd")

@export var species: = "Bulbasaur"
@export var level: = 5

var npc_name: String:
	get:
		return "Poké Ball"

var _ball: Node3D
var _taking: = false


func _ready() -> void :
	var g = get_node_or_null("/root/Game")
	if g and g.flags.get("starter_" + species.to_lower(), false):
		queue_free()
		return
	add_to_group("npc")
	_ball = CaptureFX.make_ball("poke_ball")
	_ball.scale = Vector3.ONE * 1.1
	_ball.position = Vector3(0, CaptureFX.R * 1.1, 0)
	add_child(_ball)


func _process(delta: float) -> void :
	if _ball and not _taking:
		_ball.rotation.y += delta * 0.6


func prompt_verb() -> String:
	return "Check"



func prompt_anchor() -> Vector3:
	return global_position + Vector3(0, 0.75, 0)



func interact(_player: Node3D) -> void :
	var s: = get_node_or_null("/root/Story")
	if s:
		await s.pick_starter(self)



func hide_ball(on: bool) -> void :
	if _ball:
		_ball.visible = not on




func take() -> void :
	if _taking:
		return
	_taking = true
	var g = get_node_or_null("/root/Game")
	if g:
		g.flags["starter_" + species.to_lower()] = true
	remove_from_group("npc")
	_ball.visible = true
	var tw: = create_tween()
	tw.tween_property(_ball, "position:y", 0.9, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_ball, "scale", Vector3.ONE * 0.01, 0.2)
	tw.tween_callback(hide)
