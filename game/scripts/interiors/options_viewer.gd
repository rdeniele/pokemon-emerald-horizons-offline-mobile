extends Camera3D



func _ready() -> void :
	_set_view(0)


func _unhandled_input(event: InputEvent) -> void :
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_0:
			_set_view(0)
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			_set_view(event.keycode - KEY_0)


func _options() -> Array:
	var out: Array = []
	for c in get_parent().get_children():
		if c is Node3D and String(c.name).begins_with("Option"):
			out.append(c)
	return out


func _set_view(i: int) -> void :
	var opts: = _options()
	if opts.is_empty():
		return
	var center: = Vector3.ZERO
	for o in opts:
		center += o.global_position
	center /= opts.size()
	if i <= 0:
		var span: = 0.0
		for o in opts:
			span = maxf(span, absf(o.global_position.x - center.x))
		var dist: = span * 2.2 + 18.0
		global_position = center + Vector3(0, dist * 0.55, dist * 0.85)
		look_at(center + Vector3(0, 1.0, 0), Vector3.UP)
	else:
		var o: Node3D = opts[mini(i - 1, opts.size() - 1)]
		global_position = o.global_position + Vector3(0, 7.5, 14.0)
		look_at(o.global_position + Vector3(0, 1.1, -0.5), Vector3.UP)
