extends Control






const PAD: = 8.0


const DIM: = Color(0, 0, 0, 0.62)
const LIFT: = 0.14

const FADE: = 0.18

var _hole: = Rect2()
var _alpha: = 0.0
var _want: = false


func _ready() -> void :
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	resized.connect(queue_redraw)



func target(rect: Rect2) -> void :
	_hole = rect.grow(PAD) if rect.size.x > 0.0 else Rect2()
	_want = true
	visible = true


	queue_redraw()


func clear() -> void :
	_want = false
	queue_redraw()


func _process(delta: float) -> void :
	var was: = _alpha
	_alpha = move_toward(_alpha, 1.0 if _want else 0.0, delta / FADE)
	if is_equal_approx(was, _alpha):
		if _alpha <= 0.0 and visible:
			visible = false
		return
	queue_redraw()


func _draw() -> void :
	var a: = DIM * _alpha
	if _hole.size.x <= 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), a)
		return
	var h: = _hole
	draw_rect(Rect2(0.0, 0.0, size.x, h.position.y), a)
	draw_rect(Rect2(0.0, h.end.y, size.x, size.y - h.end.y), a)
	draw_rect(Rect2(0.0, h.position.y, h.position.x, h.size.y), a)
	draw_rect(Rect2(h.end.x, h.position.y, size.x - h.end.x, h.size.y), a)

	draw_rect(h, Color(1.0, 0.97, 0.88, LIFT * _alpha))



	var rim: = Color(UiKit.AMBER.r, UiKit.AMBER.g, UiKit.AMBER.b, _alpha)
	draw_rect(h.grow(1.0), rim.darkened(0.55), false, 3.0)
	draw_rect(h.grow(4.0), rim, false, 5.0)
	draw_rect(h.grow(11.0), Color(rim.r, rim.g, rim.b, 0.22 * _alpha), false, 8.0)
