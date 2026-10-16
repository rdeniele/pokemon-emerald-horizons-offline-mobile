extends Control






var base: = 100.0
var pp_max: = 100.0
var stamina: = 100.0


func _init() -> void :
	custom_minimum_size = Vector2(200, 12)


func set_values(b: float, m: float, s: float) -> void :
	if is_equal_approx(b, base) and is_equal_approx(m, pp_max) and is_equal_approx(s, stamina):
		return
	base = maxf(b, 1.0)
	pp_max = m
	stamina = s
	queue_redraw()


func _draw() -> void :
	var w: = size.x
	var h: = size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.35, 0.08, 0.1, 0.9))
	draw_rect(Rect2(0, 0, w * pp_max / base, h), Color(0.12, 0.16, 0.24))
	var col: = Color(0.35, 0.75, 1.0) if stamina >= pp_max - 0.01 else Color(1.0, 0.72, 0.3)
	draw_rect(Rect2(0, 0, w * stamina / base, h), col)
	draw_rect(Rect2(w * pp_max / base - 1.0, -2, 2, h + 4), Color.WHITE)
