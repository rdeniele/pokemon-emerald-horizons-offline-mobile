class_name PkHintBar
extends HBoxContainer







class KeyCap extends Control:
	var label: = ""

	func _init(text: String) -> void :
		label = text
		var w: = UiKit.body_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		custom_minimum_size = Vector2(maxf(28.0, w + 16.0), 28)

	func _draw() -> void :
		var r: = Rect2(Vector2(0, 2), size - Vector2(0, 4))
		draw_style_box(UiKit.pill(Color(0, 0, 0, 0.45), Color.TRANSPARENT, 6), Rect2(r.position + Vector2(0, 2), r.size))
		draw_style_box(UiKit.pill(UiKit.PAPER, UiKit.RIM, 6), r)
		draw_string(UiKit.body_font(), Vector2(0, r.get_center().y + 5), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, UiKit.INK)


var _spec: Array = []


func _init() -> void :
	theme = UiKit.theme()
	add_theme_constant_override("separation", 8)


	Controls.on_device_changed(_on_device_changed)


func _exit_tree() -> void :
	Controls.off_device_changed(_on_device_changed)


func _on_device_changed(_device: String) -> void :
	_rebuild()


func set_hints(list: Array) -> void :
	_spec = list.duplicate(true)
	_rebuild()




static func _cap(v) -> String:
	if v is Array:
		var parts: = PackedStringArray()
		for a in v:
			parts.append(Controls.key_label(String(a)))
		return "".join(parts)
	var s: = String(v)
	return Controls.key_label(s) if Controls.ACTIONS.has(s) else s


func _rebuild() -> void :
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for h in _spec:
		add_child(KeyCap.new(_cap(h[0])))
		var l: = Label.new()
		l.theme_type_variation = "SmallLabel"
		l.text = String(h[1]) + "   "
		l.add_theme_color_override("font_color", UiKit.PAPER)
		add_child(l)


func _draw() -> void :
	if get_child_count() > 0:
		draw_style_box(UiKit.pill(Color(UiKit.INK, 0.72), Color.TRANSPARENT, size.y * 0.5), Rect2(Vector2.ZERO, size).grow(8))
