class_name UiKit
extends RefCounted







const PAPER: = Color("f8f8f0")
const INK: = Color("283040")
const RIM: = Color("c8ccd4")
const SHADOW_TXT: = Color("d0d0c8")
const RED: = Color("e0403a")
const RED_SOFT: = Color("fbe3e1")
const GREEN: = Color("48a860")
const BLUE: = Color("3870c8")
const AMBER: = Color("e8b030")
const PP_BLUE: = Color("58a0e8")
const DIM: = Color("9098a0")

const SIZE_TITLE: = 64
const SIZE_HEADER: = 28
const SIZE_BODY: = 24
const SIZE_SMALL: = 18

const TITLE_FONT_PATH: = "res://assets/fonts/PixelifySans.ttf"
const BODY_FONT_PATH: = "res://assets/fonts/Nunito.ttf"


static func setup_input() -> void :
	Controls.setup_menus()

static var _theme: Theme
static var _fonts: = {}


static func title_font() -> Font:
	return _font(TITLE_FONT_PATH, 600)


static func body_font() -> Font:
	return _font(BODY_FONT_PATH, 600)


static func _font(p: String, weight: int) -> Font:
	if _fonts.has(p):
		return _fonts[p]
	var f: Font = ThemeDB.fallback_font
	var base: = load(p) as FontFile if ResourceLoader.exists(p) else null
	if base:
		var fv: = FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		f = fv
	else:
		push_warning("[ui] font missing: %s (using the fallback font)" % p)
	_fonts[p] = f
	return f



static func window_box() -> StyleBoxFlat:
	var sb: = StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	sb.set_content_margin_all(18)
	sb.anti_aliasing = true
	return sb




static func glass(alpha: = 0.35, radius: = 14) -> StyleBoxFlat:
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(INK, alpha)
	sb.border_color = Color(PAPER, 0.08)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb



static func hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return GREEN
	if ratio > 0.2:
		return AMBER
	return RED



static func draw_ring(ci: CanvasItem, center: Vector2, r: float, width: float, ratio: float, col: Color, bg: Color) -> void :
	ci.draw_arc(center, r, 0.0, TAU, 64, bg, width, true)
	var f: = clampf(ratio, 0.0, 1.0)
	if f <= 0.0:
		return
	var a0: = - PI * 0.5
	var a1: = a0 + TAU * f
	ci.draw_arc(center, r, a0, a1, maxi(8, int(64 * f)), col, width, true)

	ci.draw_circle(center + Vector2(cos(a0), sin(a0)) * r, width * 0.5, col)
	ci.draw_circle(center + Vector2(cos(a1), sin(a1)) * r, width * 0.5, col)



static func pill(bg: Color, border: Color, radius: float) -> StyleBoxFlat:
	var sb: = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1 if border.a > 0.0 else 0)
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	return sb


static func theme() -> Theme:
	if _theme:
		return _theme
	var t: = Theme.new()
	t.default_font = body_font()
	t.default_font_size = SIZE_BODY
	t.set_color("font_color", "Label", INK)
	t.set_color("font_shadow_color", "Label", SHADOW_TXT)
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_stylebox("panel", "PanelContainer", window_box())
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font("font", "HeaderLabel", title_font())
	t.set_font_size("font_size", "HeaderLabel", SIZE_HEADER)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", title_font())
	t.set_font_size("font_size", "TitleLabel", SIZE_TITLE)
	t.set_color("font_color", "TitleLabel", PAPER)
	t.set_color("font_outline_color", "TitleLabel", INK)
	t.set_constant("outline_size", "TitleLabel", 12)
	t.set_color("font_shadow_color", "TitleLabel", Color(0, 0, 0, 0.35))
	t.set_type_variation("SmallLabel", "Label")
	t.set_font_size("font_size", "SmallLabel", SIZE_SMALL)
	t.set_color("font_shadow_color", "SmallLabel", Color.TRANSPARENT)
	_theme = t
	return t



static func pop_in(c: Control, secs: = 0.12) -> void :
	c.visible = true
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.96, 0.96)
	c.modulate.a = 0.0
	var tw: = c.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, secs)
	tw.tween_property(c, "modulate:a", 1.0, secs)



static func pop_out(c: Control, secs: = 0.1) -> void :
	c.pivot_offset = c.size * 0.5
	var tw: = c.create_tween().set_parallel()
	tw.tween_property(c, "scale", Vector2(0.96, 0.96), secs)
	tw.tween_property(c, "modulate:a", 0.0, secs)
	await tw.finished
	c.visible = false
	c.scale = Vector2.ONE
	c.modulate.a = 1.0



static func sfx(name: String) -> void :
	Audio.ui("sfx/ui/" + name)
