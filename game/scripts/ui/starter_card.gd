extends Control










const UI: = preload("res://scripts/ui/ui_draw.gd")
const Dex: = preload("res://scripts/dex.gd")
const PokemonSprites: = preload("res://scripts/pokemon_sprites.gd")

const BLURBS: = {
	"Bulbasaur": "A strange seed was planted on its back at birth. The plant sprouts and grows with this Pokémon.", 
	"Charmander": "Obviously prefers hot places. When it rains, steam is said to spout from the tip of its tail.", 
	"Squirtle": "After birth, its back swells and hardens into a shell. Powerfully sprays foam from its mouth.", 
}
const CATEGORY: = {"Bulbasaur": "Seed Pokémon", "Charmander": "Lizard Pokémon", "Squirtle": "Tiny Turtle Pokémon"}

const PANEL_W: = 560.0
const PANEL_H: = 230.0

var _species: = ""
var _closing: = false


func _ready() -> void :
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = - PANEL_W * 0.5
	offset_right = PANEL_W * 0.5
	offset_top = 50.0
	offset_bottom = 50.0 + PANEL_H
	pivot_offset = Vector2(PANEL_W * 0.5, PANEL_H * 0.5)
	visible = false



func show_species(species: String) -> void :
	_species = species
	visible = true
	modulate.a = 0.0
	scale = Vector2.ONE * 0.85
	queue_redraw()
	var tw: = create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)



func close() -> void :
	if _closing:
		return
	_closing = true
	var tw: = create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_property(self, "scale", Vector2.ONE * 0.85, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


func _draw() -> void :
	var r: = Rect2(Vector2.ZERO, size)
	UI.rounded(self, Rect2(r.position + Vector2(0, 5), r.size), Color(0, 0, 0, 0.35), 16)
	UI.rounded(self, r, Color(0.97, 0.96, 0.92, 0.97), 16, 3, Color(0.22, 0.28, 0.4))
	if _species == "":
		return
	var types: Array = Dex.species(_species).get("types", ["normal"])
	var accent: Color = Dex.type_color(String(types[0]) if not types.is_empty() else "normal")

	var c: = Vector2(112, size.y * 0.5)
	var rad: = 78.0
	draw_circle(c, rad, accent.darkened(0.2))
	draw_circle(c, rad * 0.84, accent.lightened(0.3))
	draw_arc(c, rad, 0, TAU, 48, accent.darkened(0.5), 3.0, true)
	var icon: = PokemonSprites.icon(_species)
	if icon:
		draw_texture_rect(icon, Rect2(c - Vector2(rad, rad) * 0.8, Vector2(rad, rad) * 1.6), false, PokemonSprites.tint(_species))

	var x0: = 220.0
	var w: = size.x - x0 - 26.0
	UI.text(self, Vector2(x0, 68), _species, 32, UI.COL_INK, 0)
	UI.text(self, Vector2(x0, 94), String(CATEGORY.get(_species, "Pokémon")), 15, Color(0.35, 0.36, 0.42), 0)
	var tx: = x0
	for t in types:
		tx += UI.type_pill(self, Vector2(tx, 104), String(t), Dex.type_color(String(t)), 12) + 6.0
	var y: = 148.0
	for ln in _wrap(String(BLURBS.get(_species, "")), 15, w):
		UI.text(self, Vector2(x0, y), ln, 15, Color(0.16, 0.16, 0.2), 0)
		y += 21.0



func _wrap(text: String, fs: int, width: float) -> PackedStringArray:
	var out: = PackedStringArray()
	var line: = ""
	for word in text.split(" ", false):
		var test: = word if line == "" else line + " " + word
		if line == "" or UI.text_width(test, fs) <= width:
			line = test
		else:
			out.append(line)
			line = word
	if line != "":
		out.append(line)
	return out
