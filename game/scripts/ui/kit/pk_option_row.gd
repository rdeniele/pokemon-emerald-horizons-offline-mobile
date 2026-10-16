class_name PkOptionRow
extends HBoxContainer




enum Kind{CHOICE, TOGGLE, VOLUME, ACTION}

signal changed(value)
signal activated

var kind: = Kind.CHOICE
var choices: Array = []
var value = 0
var selected: = false:
	set(v):
		selected = v
		queue_redraw()
		if _view:
			_view.queue_redraw()

var _label: Label
var _view: Control


class ValueView extends Control:
	var row: PkOptionRow

	func _init(r: PkOptionRow) -> void :
		row = r
		custom_minimum_size = Vector2(240, 34)

	func _draw() -> void :
		var f: = UiKit.body_font()
		var fs: = UiKit.SIZE_BODY
		var cy: = size.y * 0.5
		match row.kind:
			PkOptionRow.Kind.CHOICE:
				var text: = String(row.choices[int(row.value)]) if not row.choices.is_empty() else ""
				draw_string(f, Vector2(0, cy + fs * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, UiKit.INK)
				var col: = UiKit.RED if row.selected else UiKit.DIM
				draw_colored_polygon(PackedVector2Array([Vector2(8, cy), Vector2(18, cy - 8), Vector2(18, cy + 8)]), col)
				draw_colored_polygon(PackedVector2Array([Vector2(size.x - 8, cy), Vector2(size.x - 18, cy - 8), Vector2(size.x - 18, cy + 8)]), col)
			PkOptionRow.Kind.TOGGLE:
				var on: = bool(row.value)
				var r: = Rect2(Vector2(size.x * 0.5 - 40, cy - 14), Vector2(80, 28))
				draw_style_box(UiKit.pill(UiKit.GREEN if on else UiKit.DIM, UiKit.INK, 14), r)
				draw_string(f, Vector2(r.position.x, cy + 7), "ON" if on else "OFF", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, UiKit.PAPER)
			PkOptionRow.Kind.VOLUME:
				var w: = (size.x - 9 * 4.0) / 10.0
				for i in 10:
					var seg: = Rect2(Vector2(i * (w + 4.0), cy - 10), Vector2(w, 20))
					var filled: = i < int(row.value)
					draw_style_box(UiKit.pill(UiKit.RED if filled else UiKit.RED_SOFT, UiKit.INK if filled else UiKit.RIM, 4), seg)
			PkOptionRow.Kind.ACTION:
				var acol: = UiKit.RED if row.selected else UiKit.DIM
				draw_colored_polygon(PackedVector2Array([Vector2(size.x - 8, cy), Vector2(size.x - 18, cy - 8), Vector2(size.x - 18, cy + 8)]), acol)


static func make(label: String, k: Kind, v, ch: = []) -> PkOptionRow:
	var r: = PkOptionRow.new()
	r.kind = k
	r.choices = ch
	r.value = v
	r._label.text = label
	return r


func _init() -> void :
	theme = UiKit.theme()
	custom_minimum_size = Vector2(0, 44)
	var lm: = MarginContainer.new()
	lm.add_theme_constant_override("margin_left", 14)
	lm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lm.add_child(_label)
	add_child(lm)
	var vm: = MarginContainer.new()
	vm.add_theme_constant_override("margin_right", 10)
	_view = ValueView.new(self)
	vm.add_child(_view)
	add_child(vm)


func step(d: int) -> void :
	match kind:
		Kind.CHOICE:
			if choices.is_empty():
				return
			value = wrapi(int(value) + d, 0, choices.size())
		Kind.TOGGLE:
			value = not bool(value)
		Kind.VOLUME:
			var nv: = clampi(int(value) + d, 0, 10)
			if nv == int(value):
				UiKit.sfx("error")
				return
			value = nv
		Kind.ACTION:
			return
	UiKit.sfx("cursor")
	_view.queue_redraw()
	changed.emit(value)



func set_value_silent(v) -> void :
	value = v
	_view.queue_redraw()


func _draw() -> void :
	if selected:
		draw_style_box(UiKit.pill(UiKit.RED_SOFT, UiKit.RED, size.y * 0.5), Rect2(Vector2.ZERO, size))
