extends RefCounted






const ItemsData: = preload("res://scripts/items.gd")

const COL_INK: = Color(0.07, 0.08, 0.11)
const COL_WHITE: = Color(0.97, 0.97, 0.95)






const TOUCH_FILL_A: = 0.4
const TOUCH_RING_A: = 0.7
const TOUCH_LABEL_A: = 0.85
const TOUCH_PRESSED_FILL_A: = 0.85
const TOUCH_PRESSED_A: = 1.0

const TOUCH_STICK_BASE_A: = 0.35
const TOUCH_STICK_KNOB_A: = 0.55




static func fill_a(base: float, touch: bool, pressed: bool) -> float:
	return base if not touch else (TOUCH_PRESSED_FILL_A if pressed else TOUCH_FILL_A)



static func ring_a(base: float, touch: bool, pressed: bool) -> float:
	return base if not touch else (TOUCH_PRESSED_A if pressed else TOUCH_RING_A)



static func label_a(base: float, touch: bool, pressed: bool) -> float:
	return base if not touch else (TOUCH_PRESSED_A if pressed else TOUCH_LABEL_A)




static func _kit() -> GDScript:
	return load("res://scripts/ui/kit/ui_kit.gd")


static func font() -> Font:
	return _kit().body_font()


static func title_font() -> Font:
	return _kit().title_font()



static func glass(ci: CanvasItem, r: Rect2, alpha: = 0.35, radius: = 14) -> void :
	ci.draw_style_box(_kit().glass(alpha, radius), r)


static func rounded(ci: CanvasItem, r: Rect2, col: Color, radius: = 6.0, border: = 0.0, border_col: = Color.TRANSPARENT) -> void :
	var sb: = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	if border > 0.0:
		sb.set_border_width_all(int(border))
		sb.border_color = border_col
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)



static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: = COL_WHITE, outline: = 4, align: = HORIZONTAL_ALIGNMENT_LEFT, width: = -1.0, f: Font = null) -> void :
	var fnt: = f if f != null else font()
	if outline > 0:
		ci.draw_string_outline(fnt, pos, s, align, width, size, outline, Color(0, 0, 0, 0.85 * col.a))
	ci.draw_string(fnt, pos, s, align, width, size, col)


static func text_width(s: String, size: int, f: Font = null) -> float:
	return (f if f != null else font()).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x





static func text_center(ci: CanvasItem, center: Vector2, s: String, size: int, col: = COL_WHITE, outline: = 4, f: Font = null) -> void :
	var fnt: = f if f != null else font()
	var w: = fnt.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(ci, Vector2(center.x - w * 0.5, center.y), s, size, col, outline, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fnt)



static func key_cap(ci: CanvasItem, center: Vector2, label: String, size: = 22.0, dim: = false) -> void :
	var r: = Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
	rounded(ci, Rect2(r.position + Vector2(0, 2), r.size), Color(0, 0, 0, 0.45), size * 0.22)
	rounded(ci, r, Color(0.92, 0.93, 0.96, 0.55 if dim else 0.95), size * 0.22, 1.0, Color(1, 1, 1, 0.9))
	var fs: = int(size * 0.62)
	var w: = text_width(label, fs)
	ci.draw_string(font(), Vector2(center.x - w * 0.5, center.y + fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_INK)



static func key_pill(ci: CanvasItem, center: Vector2, label: String, size: = 22.0, dim: = false) -> void :
	if label == "":
		return
	var fs: = int(size * 0.62)
	var w: = maxf(size, text_width(label, fs) + size * 0.5)
	var r: = Rect2(center - Vector2(w, size) * 0.5, Vector2(w, size))
	rounded(ci, Rect2(r.position + Vector2(0, 2), r.size), Color(0, 0, 0, 0.45), size * 0.22)
	rounded(ci, r, Color(0.92, 0.93, 0.96, 0.55 if dim else 0.95), size * 0.22, 1.0, Color(1, 1, 1, 0.9))
	var tw: = text_width(label, fs)
	ci.draw_string(font(), Vector2(center.x - tw * 0.5, center.y + fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_INK)






static func circle_btn(ci: CanvasItem, sz: Vector2, label: String, ring: Color, glyph: = "", hold: = false, touch: = false, pressed: = false, dim: = false) -> void :
	var c: = sz * 0.5
	var r: = minf(sz.x, sz.y) * 0.5
	var ring_m: = 0.5 if dim else 1.0
	var label_m: = 0.45 if dim else 1.0
	ci.draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.35))
	ci.draw_circle(c, r, Color(COL_INK, fill_a(0.86, touch, pressed)))
	ci.draw_arc(c, r - 1.5, 0.0, TAU, 48, Color(ring, ring_a(ring.a, touch, pressed) * ring_m), 3.0, true)
	text_center(ci, c + Vector2(0, 4), label, int(clampf(r * 0.34, 14.0, 26.0)), 
		Color(COL_WHITE, label_a(1.0, touch, pressed) * label_m), 3)
	if glyph != "":
		key_pill(ci, c + Vector2( - r + 6.0, - r + 6.0), ("Hold " if hold else "") + glyph, 20, dim)



static func type_pill(ci: CanvasItem, pos: Vector2, type_name: String, col: Color, fs: = 11) -> float:
	var label: = type_name.to_upper()
	var w: = text_width(label, fs) + 12.0
	var h: = fs + 6.0
	rounded(ci, Rect2(pos, Vector2(w, h)), col.darkened(0.15), h * 0.5, 1.0, col.lightened(0.35))
	ci.draw_string(font(), pos + Vector2(6, h - 4.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_WHITE)
	return w



static func category(ci: CanvasItem, cat: String, c: Vector2, r: float) -> void :
	match cat:
		"physical":
			var pts: = PackedVector2Array()
			for i in 16:
				var a: = TAU * i / 16.0 - PI * 0.5
				var rr: = r if i % 2 == 0 else r * 0.5
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, Color(1.0, 0.55, 0.2))
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.5, 0.15, 0.0), 1.0, true)
		"special":
			ci.draw_circle(c, r, Color(0.35, 0.5, 1.0))
			ci.draw_arc(c, r * 0.62, 0, TAU, 20, COL_WHITE, 1.6, true)
			ci.draw_circle(c, r * 0.25, COL_WHITE)
		_:
			ci.draw_circle(c, r, Color(0.75, 0.75, 0.8))
			ci.draw_arc(c, r * 0.55, PI * 0.5, PI * 1.5, 14, COL_INK, 2.0, true)




static func _hex(s: String, fallback: Color) -> Color:
	return Color.html(s) if s != "" and Color.html_is_valid(s) else fallback




static func item_icon(ci: CanvasItem, id: String, r: Rect2, dim: = false) -> void :
	var it: = ItemsData.item(id)
	var mod: = Color(1, 1, 1, 0.35) if dim else Color.WHITE
	if it.get("category", "") == "balls":
		_ball(ci, r, _hex(it.get("top", ""), Color(0.9, 0.2, 0.2)) * mod, _hex(it.get("accent", ""), Color.TRANSPARENT) * mod, mod)
		return
	var ic: Dictionary = it.get("icon", {})
	var col: = _hex(ic.get("color", ""), Color(0.6, 0.6, 0.65)) * mod
	match String(ic.get("shape", "")):
		"spray":
			_spray(ci, r, col, mod)
		"vial":
			_vial(ci, r, col, mod)
		"berry":
			_berry(ci, r, col, mod)
		"candy":
			_candy(ci, r, col, mod)
		"parcel":
			_parcel(ci, r, col, mod)
		"device":
			_device(ci, r, col, mod)
		_:
			rounded(ci, r.grow( - r.size.x * 0.2), col, 6)


static func _ball(ci: CanvasItem, r: Rect2, top: Color, accent: Color, mod: Color) -> void :
	var c: = r.get_center()
	var rad: = minf(r.size.x, r.size.y) * 0.42
	ci.draw_circle(c + Vector2(0, rad * 0.08), rad, Color(0, 0, 0, 0.35 * mod.a))
	ci.draw_circle(c, rad, COL_WHITE * mod)
	var top_pts: = PackedVector2Array()
	for i in 25:
		var a: = PI + PI * i / 24.0
		top_pts.append(c + Vector2(cos(a), sin(a)) * rad)
	ci.draw_colored_polygon(top_pts, top)
	if accent.a > 0.0:
		ci.draw_circle(c + Vector2( - rad * 0.45, - rad * 0.45), rad * 0.2, accent)
		ci.draw_circle(c + Vector2(rad * 0.45, - rad * 0.45), rad * 0.2, accent)
	ci.draw_line(c - Vector2(rad, 0), c + Vector2(rad, 0), COL_INK * mod, rad * 0.16)
	ci.draw_circle(c, rad * 0.3, COL_INK * mod)
	ci.draw_circle(c, rad * 0.19, COL_WHITE * mod)
	ci.draw_arc(c, rad, 0, TAU, 32, COL_INK * mod, maxf(1.5, rad * 0.08), true)
	ci.draw_circle(c + Vector2( - rad * 0.35, - rad * 0.55), rad * 0.12, Color(1, 1, 1, 0.7 * mod.a))



static func _spray(ci: CanvasItem, r: Rect2, col: Color, mod: Color) -> void :
	var s: = minf(r.size.x, r.size.y)
	var o: = r.get_center() - Vector2(s, s) * 0.5
	var body: = Rect2(o + Vector2(s * 0.24, s * 0.36), Vector2(s * 0.52, s * 0.56))
	rounded(ci, Rect2(body.position + Vector2(0, s * 0.03), body.size), Color(0, 0, 0, 0.35 * mod.a), s * 0.12)
	rounded(ci, body, col, s * 0.12, maxf(1.0, s * 0.03), col.darkened(0.45))
	rounded(ci, Rect2(body.position + Vector2(s * 0.06, s * 0.17), Vector2(s * 0.4, s * 0.2)), COL_WHITE * mod, s * 0.04)
	ci.draw_line(body.position + Vector2(s * 0.12, s * 0.27), body.position + Vector2(s * 0.4, s * 0.27), col.darkened(0.2), maxf(1.0, s * 0.04))
	var neck: = Rect2(o + Vector2(s * 0.38, s * 0.24), Vector2(s * 0.24, s * 0.13))
	rounded(ci, neck, Color(0.55, 0.57, 0.62) * mod, s * 0.03)
	var head: = Rect2(o + Vector2(s * 0.3, s * 0.1), Vector2(s * 0.42, s * 0.15))
	rounded(ci, head, Color(0.72, 0.74, 0.78) * mod, s * 0.05, 1.0, Color(0.3, 0.32, 0.36) * mod)
	ci.draw_line(o + Vector2(s * 0.3, s * 0.17), o + Vector2(s * 0.18, s * 0.2), Color(0.55, 0.57, 0.62) * mod, maxf(1.5, s * 0.05))
	rounded(ci, Rect2(body.position + Vector2(s * 0.05, s * 0.05), Vector2(s * 0.07, s * 0.36)), Color(1, 1, 1, 0.35 * mod.a), s * 0.03)



static func _vial(ci: CanvasItem, r: Rect2, col: Color, mod: Color) -> void :
	var s: = minf(r.size.x, r.size.y)
	var o: = r.get_center() - Vector2(s, s) * 0.5
	var body: = Rect2(o + Vector2(s * 0.27, s * 0.3), Vector2(s * 0.46, s * 0.6))
	rounded(ci, Rect2(body.position + Vector2(0, s * 0.03), body.size), Color(0, 0, 0, 0.35 * mod.a), s * 0.14)
	rounded(ci, body, Color(0.85, 0.92, 0.96, 0.9) * mod, s * 0.14, maxf(1.0, s * 0.03), Color(0.3, 0.35, 0.4) * mod)
	rounded(ci, Rect2(body.position + Vector2(s * 0.04, s * 0.2), body.size - Vector2(s * 0.08, s * 0.24)), col, s * 0.11)
	rounded(ci, Rect2(o + Vector2(s * 0.33, s * 0.12), Vector2(s * 0.34, s * 0.2)), col.darkened(0.35), s * 0.05, 1.0, col.darkened(0.6))
	rounded(ci, Rect2(body.position + Vector2(s * 0.07, s * 0.06), Vector2(s * 0.06, s * 0.4)), Color(1, 1, 1, 0.5 * mod.a), s * 0.03)


static func _berry(ci: CanvasItem, r: Rect2, col: Color, mod: Color) -> void :
	var s: = minf(r.size.x, r.size.y)
	var c: = r.get_center() + Vector2(0, s * 0.06)
	ci.draw_circle(c + Vector2(0, s * 0.04), s * 0.33, Color(0, 0, 0, 0.35 * mod.a))
	ci.draw_circle(c + Vector2( - s * 0.1, 0), s * 0.26, col)
	ci.draw_circle(c + Vector2(s * 0.1, 0), s * 0.26, col)
	ci.draw_circle(c + Vector2(0, s * 0.06), s * 0.26, col.darkened(0.08))
	ci.draw_circle(c + Vector2( - s * 0.14, - s * 0.08), s * 0.07, Color(1, 1, 1, 0.55 * mod.a))
	var leaf: = PackedVector2Array([c + Vector2(0, - s * 0.22), c + Vector2(s * 0.2, - s * 0.42), c + Vector2(s * 0.3, - s * 0.3), c + Vector2(s * 0.06, - s * 0.18)])
	ci.draw_colored_polygon(leaf, Color(0.3, 0.7, 0.3) * mod)
	ci.draw_line(c + Vector2(0, - s * 0.2), c + Vector2( - s * 0.04, - s * 0.38), Color(0.35, 0.25, 0.15) * mod, maxf(1.5, s * 0.04))


static func _candy(ci: CanvasItem, r: Rect2, col: Color, mod: Color) -> void :
	var s: = minf(r.size.x, r.size.y)
	var c: = r.get_center()
	var wrap: = col.lightened(0.25)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2( - s * 0.2, 0), c + Vector2( - s * 0.46, - s * 0.18), c + Vector2( - s * 0.46, s * 0.18)]), wrap)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.2, 0), c + Vector2(s * 0.46, - s * 0.18), c + Vector2(s * 0.46, s * 0.18)]), wrap)
	ci.draw_circle(c + Vector2(0, s * 0.03), s * 0.25, Color(0, 0, 0, 0.35 * mod.a))
	ci.draw_circle(c, s * 0.24, col)
	ci.draw_arc(c, s * 0.24, 0, TAU, 24, col.darkened(0.45), maxf(1.0, s * 0.03), true)
	ci.draw_circle(c + Vector2( - s * 0.08, - s * 0.08), s * 0.06, Color(1, 1, 1, 0.6 * mod.a))



static func _parcel(ci: CanvasItem, r: Rect2, col: Color, mod: Color) -> void :
	var s: = minf(r.size.x, r.size.y)
	var o: = r.get_center() - Vector2(s, s) * 0.5
	var box: = Rect2(o + Vector2(s * 0.16, s * 0.22), Vector2(s * 0.68, s * 0.6))
	rounded(ci, Rect2(box.position + Vector2(0, s * 0.04), box.size), Color(0, 0, 0, 0.35 * mod.a), s * 0.06)
	rounded(ci, box, col, s * 0.06, maxf(1.0, s * 0.03), col.darkened(0.45))
	rounded(ci, Rect2(o + Vector2(s * 0.47, s * 0.22), Vector2(s * 0.06, s * 0.6)), col.lightened(0.25), s * 0.02)
	rounded(ci, Rect2(o + Vector2(s * 0.16, s * 0.47), Vector2(s * 0.68, s * 0.06)), col.lightened(0.25), s * 0.02)



static func _device(ci: CanvasItem, r: Rect2, col: Color, mod: Color) -> void :
	var s: = minf(r.size.x, r.size.y)
	var o: = r.get_center() - Vector2(s, s) * 0.5
	var body: = Rect2(o + Vector2(s * 0.22, s * 0.12), Vector2(s * 0.56, s * 0.76))
	rounded(ci, Rect2(body.position + Vector2(0, s * 0.04), body.size), Color(0, 0, 0, 0.35 * mod.a), s * 0.08)
	rounded(ci, body, col, s * 0.08, maxf(1.0, s * 0.03), col.darkened(0.4))
	rounded(ci, Rect2(o + Vector2(s * 0.29, s * 0.2), Vector2(s * 0.42, s * 0.3)), Color(0.55, 0.9, 0.75) * mod, s * 0.03, 1.0, col.darkened(0.5))
	ci.draw_circle(o + Vector2(s * 0.5, s * 0.66), s * 0.09, Color(0.3, 0.5, 0.9) * mod)
	ci.draw_circle(o + Vector2(s * 0.5, s * 0.66), s * 0.05, COL_WHITE * mod)
	ci.draw_circle(o + Vector2(s * 0.33, s * 0.66), s * 0.05, Color(0.95, 0.8, 0.3) * mod)





const TRACK: = Color(0.16, 0.18, 0.22)
const EXP_TRACK: = Color(0.46, 0.49, 0.56)



static func bar(ci: CanvasItem, r: Rect2, fill: float, col: Color, ghost: = -1.0, ghost_col: = Color(1, 1, 1, 0.75), rtl: = false, track: = TRACK) -> void :
	var rad: = r.size.y * 0.5
	rounded(ci, r.grow(1.5), Color(0, 0, 0, 0.6), rad + 1.5)
	rounded(ci, r, track, rad)
	if ghost > fill:
		_fill(ci, r, ghost, ghost_col, rad, rtl)
	if fill > 0.0:
		_fill(ci, r, fill, col, rad, rtl)
		_fill(ci, Rect2(r.position, Vector2(r.size.x, r.size.y * 0.42)), fill, Color(1, 1, 1, 0.22), rad * 0.5, rtl)


static func _fill(ci: CanvasItem, r: Rect2, f: float, col: Color, rad: float, rtl: = false) -> void :
	var w: = maxf(r.size.x * clampf(f, 0.0, 1.0), rad * 2.0 if f > 0.0 else 0.0)
	var x: = r.position.x + (r.size.x - w if rtl else 0.0)
	rounded(ci, Rect2(Vector2(x, r.position.y), Vector2(w, r.size.y)), col, rad)


static func hp_color(ratio: float) -> Color:
	return _kit().hp_color(ratio)


const STATUS_TAGS: = {"burn": ["BRN", Color(0.93, 0.45, 0.2)], "poison": ["PSN", Color(0.65, 0.3, 0.75)], 
	"paralysis": ["PAR", Color(0.95, 0.8, 0.2)], "sleep": ["SLP", Color(0.55, 0.6, 0.7)], 
	"freeze": ["FRZ", Color(0.55, 0.85, 0.9)], "faint": ["FNT", Color(0.45, 0.45, 0.5)], 
	"leech": ["SEED", Color(0.4, 0.75, 0.3)]}



static func status_pill(ci: CanvasItem, pos: Vector2, status: String, fs: = 12) -> float:
	if not STATUS_TAGS.has(status):
		return 0.0
	var t: Array = STATUS_TAGS[status]
	var w: = text_width(t[0], fs) + 12.0
	var h: = fs + 6.0
	rounded(ci, Rect2(pos, Vector2(w, h)), t[1], 4)
	ci.draw_string(font(), pos + Vector2(6, h - 4.5), t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_WHITE)
	return w




const STAGE_ORDER: = ["atk", "def", "spa", "spd", "spe"]
const STAGE_SHORT: = {"atk": "ATK", "def": "DEF", "spa": "SP.A", "spd": "SP.D", "spe": "SPE"}
const COL_BUFF: = Color(0.3, 0.62, 1.0)
const COL_DEBUFF: = Color(0.93, 0.33, 0.3)



static func mod_chips_width(body: Object, fs: = 10) -> float:
	var w: = 0.0
	var tri: = fs * 0.62
	for k in STAGE_ORDER:
		var s: int = int(body.stages.get(k, 0))
		if s != 0:
			w += text_width(STAGE_SHORT[k], fs) + 10.0 + absi(s) * (tri + 1.5) + 2.0 + 4.0
	if body.evasion_t > 0.0:
		w += text_width("EVA", fs) + 10.0 + (tri + 1.5) + 2.0 + 4.0
	return w




static func mod_chips(ci: CanvasItem, pos: Vector2, body: Object, fs: = 10, max_x: = INF) -> float:
	var x: = pos.x
	var chips: Array = []
	for k in STAGE_ORDER:
		var s: int = int(body.stages.get(k, 0))
		if s != 0:
			chips.append([STAGE_SHORT[k], s])
	if body.evasion_t > 0.0:
		chips.append(["EVA", 1])
	var h: = fs + 6.0
	for c in chips:
		var label: String = c[0]
		var s: int = c[1]
		var n: = absi(s)
		var tri: = fs * 0.62
		var w: = text_width(label, fs) + 10.0 + n * (tri + 1.5) + 2.0
		if x + w > max_x:
			break
		var col: = COL_BUFF if s > 0 else COL_DEBUFF
		rounded(ci, Rect2(Vector2(x, pos.y), Vector2(w, h)), col.darkened(0.25), 4, 1.0, col.lightened(0.3))
		ci.draw_string(font(), Vector2(x + 5, pos.y + h - 4.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_WHITE)
		var tx: = x + 7.0 + text_width(label, fs)
		var cy: = pos.y + h * 0.5
		for i in n:
			var p: = Vector2(tx + i * (tri + 1.5), cy)
			var pts: = PackedVector2Array([p + Vector2(0, tri * 0.45), p + Vector2(tri, tri * 0.45), p + Vector2(tri * 0.5, - tri * 0.45)]) if s > 0\
			else PackedVector2Array([p + Vector2(0, - tri * 0.45), p + Vector2(tri, - tri * 0.45), p + Vector2(tri * 0.5, tri * 0.45)])
			ci.draw_colored_polygon(pts, COL_WHITE)
		x += w + 4.0
	return x - pos.x
