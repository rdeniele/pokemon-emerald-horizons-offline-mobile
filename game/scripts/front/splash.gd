extends ColorRect



var _tw: Tween
var _box: VBoxContainer
var _label: Label
var _sub: Label


func _init() -> void :
	color = Color.BLACK
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_box)
	_label = Label.new()
	_label.theme_type_variation = "TitleLabel"
	_label.text = "Daigan Games"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_label)
	_sub = Label.new()
	_sub.theme_type_variation = "HeaderLabel"
	_sub.text = "presents"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_color", UiKit.DIM)
	_box.add_child(_sub)
	_box.modulate.a = 0.0


func play() -> void :
	_tw = create_tween()
	_tw.tween_property(_box, "modulate:a", 1.0, 0.5)
	_tw.tween_interval(1.0)
	_tw.tween_property(_box, "modulate:a", 0.0, 0.4)
	_tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await _tw.finished


func skip() -> void :
	if _tw and _tw.is_running():
		_tw.custom_step(99.0)
