class_name PkWindow
extends PanelContainer



const RIM_INSET: = 6.0

@export var title: = "":
	set(v):
		title = v
		_apply_title_margin()
		queue_redraw()


func _init() -> void :
	theme = UiKit.theme()
	_apply_title_margin()



func _apply_title_margin() -> void :
	if title == "":
		remove_theme_stylebox_override("panel")
		return
	var sb: = UiKit.window_box()
	sb.content_margin_top += 12
	add_theme_stylebox_override("panel", sb)


func _draw() -> void :
	var rim: = StyleBoxFlat.new()
	rim.draw_center = false
	rim.border_color = UiKit.RIM
	rim.set_border_width_all(2)
	rim.set_corner_radius_all(6)
	rim.anti_aliasing = true
	draw_style_box(rim, Rect2(Vector2.ZERO, size).grow( - RIM_INSET))
	if title == "":
		return
	var f: = UiKit.title_font()
	var fs: = UiKit.SIZE_SMALL + 2
	var w: = f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28.0
	var tab: = Rect2(Vector2(20, - fs * 0.8), Vector2(w, fs + 12))
	draw_style_box(UiKit.pill(UiKit.BLUE, UiKit.INK, 8), tab)
	draw_string(f, tab.position + Vector2(14, fs + 3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.PAPER)
