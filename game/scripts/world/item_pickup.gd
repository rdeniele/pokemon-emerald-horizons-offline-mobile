extends Node3D








const CaptureFX: = preload("res://scripts/capture_fx.gd")
const Items: = preload("res://scripts/items.gd")

@export var uid: = ""
@export var item_id: = "potion"
@export var count: = 1

@export var hidden: = false

var npc_name: String:
	get:
		return ""

var _ball: Node3D
var _taken: = false
var _t: = 0.0


func _ready() -> void :
	if Game.flags.get("item_" + uid, false):
		queue_free()
		return
	add_to_group("npc")
	if hidden:
		return
	_ball = CaptureFX.make_ball("poke_ball")
	_ball.position = Vector3(0, CaptureFX.R, 0)
	_ball.rotation.y = randf() * TAU
	add_child(_ball)


func _process(delta: float) -> void :
	if _ball == null or _taken:
		return

	_t += delta
	var e: = maxf(0.0, sin(_t * 2.2) - 0.85) * 12.0
	CaptureFX.glow(_ball, Color(1, 1, 0.85), e)


func prompt_verb() -> String:
	return "Pick up"



func prompt_hidden() -> bool:
	return hidden or _taken



func prompt_anchor() -> Vector3:
	return global_position + Vector3(0, 0.9, 0)


func talk_to(_player: Node3D) -> PackedStringArray:
	var n: = Items.item_name(item_id)
	var what: = ("%d× %s" % [count, n]) if count > 1 else n
	return PackedStringArray(["You found %s!" % what, "You put the %s in the %s pocket." % [n, _pocket_name()]])


func _pocket_name() -> String:
	var pk: = Items.pocket_of(item_id)
	for p in Items.POCKETS:
		if p[0] == pk:
			return p[1]
	return "Items"


func finish_talk() -> void :
	if _taken:
		return
	_taken = true
	remove_from_group("npc")
	Game.add_item(item_id, count)
	Audio.play("sfx/world/item_pickup")
	Audio.jingle("music/key_item" if Items.pocket_of(item_id) == "key" else "music/item_get")
	Game.flags["item_" + uid] = true
	if _ball == null:
		queue_free()
		return
	var tw: = create_tween()
	tw.tween_property(_ball, "scale", Vector3.ONE * 0.01, 0.2)
	tw.tween_callback(queue_free)
