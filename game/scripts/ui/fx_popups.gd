extends CanvasLayer














const UI: = preload("res://scripts/ui/ui_draw.gd")

const LIFE: = {"damage": 0.75, "crit": 0.8, "super": 0.8, "weak": 0.7, "stat_up": 0.85, "stat_down": 0.85, 
	"status": 0.85, "move": 0.6, "miss": 0.65, "dodge": 0.8, "heal": 0.75, "info": 0.8}

var _root: Control


func _ready() -> void :
	layer = 5
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)



func spawn(world: Vector3, text: String, col: Color, scale: = 1.0, style: = "info", n: = 1) -> void :
	var p: = Pop.new()
	p.world = world
	p.text = text
	p.col = col
	p.scale_k = scale
	p.style = style
	p.n = n
	p.life = LIFE.get(style, 0.8)
	if style == "damage":
		p.jitter = randf_range(-16.0, 16.0)

	var cam: = get_viewport().get_camera_3d()
	if cam and not cam.is_position_behind(world):
		var sp: = cam.unproject_position(world)
		var step: = 46.0 if style == "damage" else 30.0
		for o in _root.get_children():
			if o.age < 0.35 and (o.screen + Vector2(0, o.stack)).distance_to(sp + Vector2(0, p.stack)) < step - 4.0:
				p.stack -= step
	_root.add_child(p)


class Pop extends Control:
	const UI: = preload("res://scripts/ui/ui_draw.gd")

	var world: = Vector3.ZERO
	var text: = ""
	var col: = Color.WHITE
	var scale_k: = 1.0
	var style: = "info"
	var n: = 1
	var life: = 0.8
	var age: = 0.0
	var jitter: = 0.0
	var stack: = 0.0
	var screen: = Vector2.ZERO

	func _ready() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place()

	func _place() -> void :
		var cam: = get_viewport().get_camera_3d()
		if cam == null or cam.is_position_behind(world):
			visible = false
			return
		visible = true
		screen = cam.unproject_position(world)
		var rise: = (30.0 if style == "damage" else 18.0) * ease(clampf(age / life, 0.0, 1.0), 0.4)
		position = screen + Vector2(jitter, stack - rise)

	func _process(delta: float) -> void :
		age += delta
		if age >= life:
			queue_free()
			return
		_place()
		modulate.a = _alpha()
		queue_redraw()

	func _scale() -> float:

		if age < 0.07:
			return lerpf(0.3, 1.25, age / 0.07)
		if age < 0.14:
			return lerpf(1.25, 1.0, (age - 0.07) / 0.07)
		return 1.0

	func _alpha() -> float:
		var out: = 0.16
		return clampf((life - age) / out, 0.0, 1.0)

	func _draw() -> void :
		var s: = _scale() * scale_k
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		match style:
			"damage":
				_damage()
			"crit":
				_ribbon(text, Color(1.0, 0.42, 0.18), Color.WHITE, 17, -0.18)
			"super":
				_ribbon(text, Color(1.0, 0.8, 0.18), Color(0.25, 0.12, 0.0), 15, -0.12, 2)
			"weak":
				_pill(text, Color(0.2, 0.22, 0.27, 0.9), Color(0.78, 0.8, 0.86), 12)
			"stat_up":
				_stat(UI.COL_BUFF, true)
			"stat_down":
				_stat(UI.COL_DEBUFF, false)
			"status":
				_pill(text, col.darkened(0.15), Color.WHITE, 15, col.lightened(0.4))
			"move":
				_pill(text, Color(col.darkened(0.45), 0.92), Color.WHITE, 14, col.lightened(0.2))
			"miss":
				_speed_badge("MISS")
			"dodge":
				_speed_badge("DODGED!")
			"heal":
				_pill(text, Color(0.18, 0.62, 0.3), Color.WHITE, 17, Color(0.6, 1.0, 0.65))
			_:
				_pill(text, Color(0.06, 0.07, 0.1, 0.85), col, 14, Color(col, 0.5))



	func _pill(t: String, bg: Color, fg: Color, fs: int, border: = Color.TRANSPARENT) -> void :
		var w: = UI.text_width(t, fs) + 18.0
		var h: = fs + 12.0
		var r: = Rect2( - w * 0.5, - h * 0.5, w, h)
		UI.rounded(self, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.4), h * 0.5)
		UI.rounded(self, r, bg, h * 0.5, 2.0 if border.a > 0.0 else 0.0, border)
		UI.text(self, Vector2( - w * 0.5 + 9, fs * 0.36), t, fs, fg, 3)


	func _ribbon(t: String, bg: Color, fg: Color, fs: int, slant: float, arrows: = 0) -> void :
		var tw: = UI.text_width(t, fs)
		var aw: = arrows * (fs * 0.7 + 2.0)
		var w: = tw + 28.0 + aw
		var h: = fs + 14.0
		var k: = h * slant * -1.0
		var pts: = PackedVector2Array([Vector2( - w * 0.5 + k, - h * 0.5), Vector2(w * 0.5 + k, - h * 0.5), 
			Vector2(w * 0.5 - k, h * 0.5), Vector2( - w * 0.5 - k, h * 0.5)])
		var sh: = PackedVector2Array()
		for p in pts:
			sh.append(p + Vector2(2, 4))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.45))
		draw_colored_polygon(pts, bg)
		draw_polyline(pts + PackedVector2Array([pts[0]]), bg.darkened(0.45), 2.0, true)
		draw_colored_polygon(PackedVector2Array([pts[0], pts[1], (pts[1] + pts[2]) * 0.5, (pts[0] + pts[3]) * 0.5]), Color(1, 1, 1, 0.18))
		var x: = - w * 0.5 + 14.0
		UI.text(self, Vector2(x, fs * 0.36), t, fs, fg, 3 if fg.v > 0.5 else 0)
		for i in arrows:
			_tri(Vector2(x + tw + 8.0 + i * (fs * 0.7 + 2.0), 0), fs * 0.62, true, fg)

	func _stat(c: Color, up: bool) -> void :
		var fs: = 15
		var tw: = UI.text_width(text, fs)
		var aw: = n * (fs * 0.7 + 2.0)
		var w: = tw + 26.0 + aw
		var h: = fs + 12.0
		var r: = Rect2( - w * 0.5, - h * 0.5, w, h)
		UI.rounded(self, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.45), 7)
		UI.rounded(self, r, c.darkened(0.2), 7, 2.0, c.lightened(0.45))
		UI.rounded(self, Rect2(r.position + Vector2(3, 3), Vector2(w - 6, h * 0.4)), Color(1, 1, 1, 0.15), 5)
		UI.text(self, Vector2( - w * 0.5 + 10, fs * 0.36), text, fs, Color.WHITE, 3)
		for i in n:
			_tri(Vector2( - w * 0.5 + 16.0 + tw + i * (fs * 0.7 + 2.0), 0), fs * 0.66, up, Color.WHITE)

	func _tri(p: Vector2, sz: float, up: bool, c: Color) -> void :
		var pts: = PackedVector2Array([p + Vector2(0, sz * 0.45), p + Vector2(sz, sz * 0.45), p + Vector2(sz * 0.5, - sz * 0.45)]) if up\
		else PackedVector2Array([p + Vector2(0, - sz * 0.45), p + Vector2(sz, - sz * 0.45), p + Vector2(sz * 0.5, sz * 0.45)])
		draw_colored_polygon(pts, c)

	func _damage() -> void :
		var crit: = scale_k > 1.45
		var fs: = 30 if crit else 24

		var star_col: = Color(1.0, 0.45, 0.15, 0.95) if crit else Color(col.darkened(0.1), 0.92)
		var ro: = 34.0 if crit else 24.0
		var ri: = 20.0 if crit else 15.0
		var burst: = PackedVector2Array()
		for i in 20:
			var ang: = TAU * i / 20.0 + (age * 2.0 if crit else 0.3)
			burst.append(Vector2(cos(ang), sin(ang)) * (ro if i % 2 == 0 else ri))
		var shadow: = PackedVector2Array()
		for p in burst:
			shadow.append(p + Vector2(2, 3))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.4))
		draw_colored_polygon(burst, star_col)
		draw_polyline(burst + PackedVector2Array([burst[0]]), star_col.darkened(0.6), 2.0, true)
		var w: = UI.text_width(text, fs)
		var f: = UI.font()
		var pos: = Vector2( - w * 0.5, fs * 0.36)
		draw_string_outline(f, pos + Vector2(0, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, 0.55))
		draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 9, Color(0.08, 0.05, 0.05))
		draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	func _speed_badge(t: String) -> void :
		var fs: = 20
		var w: = UI.text_width(t, fs)

		for i in 3:
			var y: = -6.0 + i * 6.0
			draw_line(Vector2( - w * 0.5 - 22, y), Vector2( - w * 0.5 - 6 - i * 3, y), Color(0.8, 0.88, 1.0, 0.8), 2.0)
		UI.text(self, Vector2( - w * 0.5, fs * 0.36), t, fs, Color(0.82, 0.9, 1.0), 6)
