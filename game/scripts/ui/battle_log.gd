class_name BattleLog
extends Control









const UI: = preload("res://scripts/ui/ui_draw.gd")

const MAX_ENTRIES: = 8
const TAIL: = 3.0
const MAX_W: = 560.0
const PAD: = 14.0
const CHIP: = 4.0
const CHIP_GAP: = 8.0
const H: = 32.0
const TOP: = 116.0
const FONT_SIZE: = 18
const APPEAR: = 0.25


var entries: Array = []

var hint_glyph: = ""
var hint_text: = ""

var _tail: = 0.0
var _visible: = false
var _tw: Tween

var _age: = APPEAR


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = - MAX_W * 0.5
	offset_right = MAX_W * 0.5
	offset_top = TOP
	offset_bottom = TOP + H
	_place_top()
	visible = false
	modulate.a = 0.0
	var mv: = get_node_or_null("/root/Moves")
	if mv:
		mv.move_used.connect(_on_move_used)



func active() -> bool:
	return Battle.in_battle or _tail > 0.0



func push(text: String, kind: = "info") -> void :
	entries.append({"text": text, "kind": kind, "t": 0.0})
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()
	_age = 0.0
	queue_redraw()


func clear() -> void :
	entries.clear()
	queue_redraw()


func kind_at(i: int) -> String:
	return String(entries[i].kind) if i >= 0 and i < entries.size() else ""



func line_text() -> String:
	return fit_text(String(entries[-1].text)) if not entries.is_empty() else ""



func line_count() -> int:
	return 1 if not entries.is_empty() else 0



func line_width() -> float:
	return UI.text_width(line_text(), FONT_SIZE) if not entries.is_empty() else 0.0



func fit_text(s: String) -> String:
	if UI.text_width(s, FONT_SIZE) <= MAX_W:
		return s
	while s.length() > 1 and UI.text_width(s + "…", FONT_SIZE) > MAX_W:
		s = s.substr(0, s.length() - 1)
	return s + "…"


func chip_color(kind: String) -> Color:
	match kind:
		"exp":
			return UiKit.PP_BLUE
		"level", "money":
			return UiKit.AMBER
		"faint":
			return UiKit.RED
		"catch", "item":
			return UiKit.GREEN
		"move":
			return UiKit.PAPER
		"trainer":
			return UiKit.RED_SOFT
		_:
			return UiKit.DIM



func _on_move_used(user: Node, mv: Dictionary) -> void :
	if not Battle.in_battle:
		return
	var is_foe: = user == Battle.wild
	var is_status: = String(mv.get("category", "")) == "status"
	if is_foe or is_status:
		push("%s used %s!" % [user.species, String(mv.get("name", mv.get("id", "")))], "move")




func _place_top() -> void :
	var t: = get_node_or_null("/root/Touch")
	var top: = TOP
	if t != null and t.visible and t.has_method("pause_rect"):
		top = maxf(top, t.pause_rect().end.y + 6.0)
	if not is_equal_approx(offset_top, top):
		offset_top = top
		offset_bottom = top + H


func _process(delta: float) -> void :
	_place_top()
	var show: = Battle.in_battle and not Battle._intro
	if Battle.in_battle:
		_tail = TAIL
	elif _tail > 0.0:
		_tail = maxf(_tail - delta, 0.0)
	if show and not _visible:
		_set_shown(true)
	elif not show and _tail <= 0.0 and _visible:
		_set_shown(false)
	_age += delta
	for e in entries:
		e.t = float(e.t) + delta
	queue_redraw()


func _set_shown(on: bool) -> void :
	_visible = on
	if _tw:
		_tw.kill()
	if on:
		visible = true
		_tw = create_tween()
		_tw.tween_property(self, "modulate:a", 1.0, 0.25)
	else:
		_tw = create_tween()
		_tw.tween_property(self, "modulate:a", 0.0, 0.3)
		_tw.tween_callback( func():
			visible = false
			entries.clear()
			hint_glyph = ""
			hint_text = "")


func _draw() -> void :
	if entries.is_empty():
		return
	var s: = line_text()

	var a: = 0.55 + 0.45 * clampf(_age / APPEAR, 0.0, 1.0)
	var hint_w: = 0.0
	if hint_text != "":
		hint_w = UI.text_width(hint_text, 14) + 40.0
	var w: = minf(UI.text_width(s, FONT_SIZE) + PAD * 2.0 + CHIP + CHIP_GAP, MAX_W) + hint_w
	var x: = size.x * 0.5 - w * 0.5
	var y: = size.y * 0.5 - H * 0.5
	UI.rounded(self, Rect2(x, y, w, H), Color(UiKit.INK, 0.88 * a), 16)
	draw_rect(Rect2(x + PAD, y + 8.0, CHIP, H - 16.0), Color(chip_color(String(entries[-1].kind)), a))
	UI.text(self, Vector2(x + PAD + CHIP + CHIP_GAP, y + H * 0.5 + 6.0), s, FONT_SIZE, Color(UiKit.PAPER, a), 3)
	if hint_text != "":
		UI.key_pill(self, Vector2(x + w - PAD - UI.text_width(hint_text, 14) - 16.0, y + H * 0.5), hint_glyph, 18)
		UI.text(self, Vector2(x + w - PAD - UI.text_width(hint_text, 14), y + H * 0.5 + 5.0), hint_text, 14, Color(UiKit.PAPER, a), 3)
