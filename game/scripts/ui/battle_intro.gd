extends Control



const BAR_H: = 72.0
const COL_BAR: = Color(0.02, 0.02, 0.03, 0.92)

var _top: ColorRect
var _bottom: ColorRect
var _banner: Label
var _fight: Label
var _bars_tw: Tween


func _ready() -> void :
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top = _bar()
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bottom = _bar()
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_set_bars(0.0)
	_banner = _big_label(46, UiKit.PAPER)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -600
	_banner.offset_right = 600
	_banner.offset_top = BAR_H + 26
	_banner.offset_bottom = BAR_H + 96
	_fight = _big_label(110, Color(1.0, 0.82, 0.25))
	_fight.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_fight.offset_left = -400
	_fight.offset_right = 400
	_fight.offset_top = -90
	_fight.offset_bottom = 90
	_fight.text = "Fight!"


func _bar() -> ColorRect:
	var r: = ColorRect.new()
	r.color = COL_BAR
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _process(_delta: float) -> void :
	if _banner != null and _banner.modulate.a > 0.01:
		queue_redraw()


func _big_label(size: int, col: Color) -> Label:
	var l: = Label.new()
	var s: = LabelSettings.new()
	s.font = UiKit.title_font()
	s.font_size = size
	s.font_color = col
	s.outline_size = maxi(10, size / 6)
	s.outline_color = Color(0, 0, 0, 0.9)
	l.label_settings = s
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(400, 90)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	add_child(l)
	return l




func _draw() -> void :
	if _banner == null or _banner.text == "":
		return
	var a: = _banner.modulate.a
	if a <= 0.01:
		return
	var f: = UiKit.title_font()
	var w: = f.get_string_size(_banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x + 64.0
	var cy: = _banner.position.y + _banner.size.y * 0.5
	var r: = Rect2(Vector2(size.x * 0.5 - w * 0.5, cy - 32.0), Vector2(w, 64.0))
	draw_style_box(UiKit.pill(Color(UiKit.INK, 0.82 * a), Color.TRANSPARENT, 16), r)


func _set_bars(h: float) -> void :
	_top.offset_top = 0.0
	_top.offset_bottom = h
	_bottom.offset_top = - h
	_bottom.offset_bottom = 0.0
	_top.visible = h > 0.5
	_bottom.visible = h > 0.5


func bars(on: bool, secs: = 0.35) -> void :
	Audio.play("sfx/battle/bars_slide", -6.0)
	if _bars_tw:
		_bars_tw.kill()
	_bars_tw = create_tween()
	_bars_tw.tween_method(_set_bars, _top.offset_bottom, BAR_H if on else 0.0, secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func banner(text: String) -> void :
	_banner.text = text
	var tw: = create_tween().set_parallel(true)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tw.tween_property(_banner, "offset_top", BAR_H + 26.0, 0.25).from(BAR_H + 6.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_banner() -> void :
	create_tween().tween_property(_banner, "modulate:a", 0.0, 0.2)


func fight() -> void :
	Audio.play("sfx/battle/fight")
	_fight.scale = Vector2.ONE * 1.8
	var tw: = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_fight, "modulate:a", 1.0, 0.12)
	tw.tween_property(_fight, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.45)
	tw.chain().tween_property(_fight, "modulate:a", 0.0, 0.3)



func reset() -> void :
	if _bars_tw:
		_bars_tw.kill()
	_set_bars(0.0)
	_banner.modulate.a = 0.0
	_fight.modulate.a = 0.0
