extends Control





const PokemonSprites: = preload("res://scripts/pokemon_sprites.gd")
const UiDraw: = preload("res://scripts/ui/ui_draw.gd")

var mon: RefCounted

var status: = ""

var out: = false
var selected: = false:
	set(v):
		selected = v
		queue_redraw()

var source: = false:
	set(v):
		source = v
		queue_redraw()


func _init(m: RefCounted = null) -> void :
	mon = m
	custom_minimum_size = Vector2(0, 100)


func _draw() -> void :
	if mon == null:
		return
	var m = mon
	var r: = Rect2(Vector2.ZERO, size).grow_individual(-6, 0, -6, 0)
	if source:
		draw_style_box(UiKit.pill(Color(UiKit.RED, 0.1), UiKit.RED, 12), r)
	elif selected:
		draw_style_box(UiKit.pill(UiKit.RED_SOFT, UiKit.RED, 12), r)
	var f: = UiKit.body_font()
	var icon: = PokemonSprites.icon_fitted(m.species, 60)
	if icon:
		var t: = PokemonSprites.tint(m.species)
		if m.hp <= 0:
			t = Color(0.4, 0.4, 0.4)
		draw_texture_rect(icon, Rect2(Vector2(12, (size.y - 60) * 0.5), Vector2(60, 60)), false, t)
	var name_s: String = m.display_name.to_upper()
	var ink: Color = UiKit.INK if m.hp > 0 else UiKit.DIM
	draw_string(f, Vector2(84, 40), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_BODY, ink)
	var x: = 84.0 + f.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_BODY).x
	if m.gender == "male" or m.gender == "female":
		var male: bool = m.gender == "male"
		var sym: = "♂" if male else "♀"
		x += 8.0
		draw_string(f, Vector2(x, 40), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_BODY, 
			UiKit.BLUE if male else UiKit.RED)
		x += f.get_string_size(sym, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_BODY).x
	if out:
		x += 12.0
		var ow: = f.get_string_size("OUT", HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_SMALL).x + 16.0
		var orc: = Rect2(Vector2(x, 19), Vector2(ow, 22))
		draw_style_box(UiKit.pill(UiKit.BLUE, Color.TRANSPARENT, 11), orc)
		draw_string(f, Vector2(orc.position.x, orc.get_center().y + 5), "OUT", HORIZONTAL_ALIGNMENT_CENTER, 
			ow, UiKit.SIZE_SMALL, UiKit.PAPER)
	draw_string(f, Vector2(size.x - 116, 40), "Lv %d" % m.level, HORIZONTAL_ALIGNMENT_RIGHT, 104, 
		UiKit.SIZE_BODY, ink)

	var bar_x: = 84.0
	if status != "":
		bar_x += UiDraw.status_pill(self, Vector2(84, 52), status, 13) + 10.0
	var bar: = Rect2(Vector2(bar_x, 56), Vector2(size.x - 144 - bar_x, 12))
	draw_rect(bar, Color(UiKit.DIM, 0.5))
	var ratio: = clampf(float(m.hp) / maxf(float(m.max_hp), 1.0), 0.0, 1.0)
	if ratio > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), UiKit.hp_color(ratio))
	draw_string(f, Vector2(size.x - 126, 67), "HP %d/%d" % [maxi(m.hp, 0), m.max_hp], 
		HORIZONTAL_ALIGNMENT_LEFT, 110, UiKit.SIZE_SMALL, ink)
