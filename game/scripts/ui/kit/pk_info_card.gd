class_name PkInfoCard
extends PkWindow



var _grid: GridContainer


func _init() -> void :
	super ()
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 40)
	_grid.add_theme_constant_override("v_separation", 6)
	add_child(_grid)


func set_rows(rows: Array) -> void :
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	for r in rows:
		var k: = Label.new()
		k.text = String(r[0])
		k.add_theme_color_override("font_color", UiKit.BLUE)
		_grid.add_child(k)
		var v: = Label.new()
		v.text = String(r[1])
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(v)
