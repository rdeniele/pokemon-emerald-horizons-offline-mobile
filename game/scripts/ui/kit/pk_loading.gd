class_name PkLoading
extends Control








const UiDraw: = preload("res://scripts/ui/ui_draw.gd")


const SHOW_AFTER: = 0.25

const MIN_VISIBLE: = 0.25
const SPIN_RATE: = 4.5
const W: = 214.0
const H: = 64.0
const PAD: = 18.0


var progress: = -1.0

var _active: = false
var _held: = 0.0
var _spin: = 0.0


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	custom_minimum_size = Vector2(W, H)
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = - (W + PAD)
	offset_top = - (H + PAD)
	offset_right = - PAD
	offset_bottom = - PAD



func begin() -> void :
	_active = true
	_held = 0.0
	_spin = 0.0
	progress = -1.0
	visible = false
	_redraw()



func end() -> void :
	_active = false
	visible = false
	_held = 0.0


func active() -> bool:
	return _active



func held() -> float:
	return _held




func stage(f: float) -> void :
	progress = clampf(f, 0.0, 1.0) if f < 1.0 else -1.0
	_redraw()



func _redraw() -> void :
	if is_inside_tree():
		queue_redraw()


func _process(delta: float) -> void :
	if not _active:
		return
	_held += delta
	_spin += delta * SPIN_RATE
	if _held >= SHOW_AFTER and not visible:
		visible = true
	if visible:
		_redraw()


func _draw() -> void :
	UiDraw.glass(self, Rect2(Vector2.ZERO, size), 0.72, 14)
	var determined: = progress >= 0.0
	var ball_y: = 24.0 if determined else size.y * 0.5
	var ball: = Vector2(27.0, ball_y)
	draw_set_transform(ball, _spin, Vector2.ONE)
	UiDraw.item_icon(self, "poke_ball", Rect2(-11.0, -11.0, 22.0, 22.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var label: = "Loading…"
	if determined:
		label = "Loading… %d%%" % int(round(progress * 100.0))
	UiDraw.text(self, Vector2(48.0, ball.y + 6.5), label, UiKit.SIZE_SMALL, UiKit.PAPER, 3)
	if determined:
		UiDraw.bar(self, Rect2(48.0, size.y - 15.0, size.x - 66.0, 5.0), progress, UiKit.RED)
