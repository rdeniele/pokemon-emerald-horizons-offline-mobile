extends Control







const OAK_SPRITE: = "res://assets/sprites/npc_oak.png"

const OAK_FRAME: = Rect2(8, 11, 16, 20)

const OAK_SIZE: = Vector2(160, 200)

const MON_SPRITE: = "res://assets/pokemon/nidorino/overworld.png"
const MON_SPECIES: = "Nidorino"
const MON_SIZE: = Vector2(128, 128)
const MON_POS: = Vector2(806, 150)

const BALL_FROM: = Vector2(700, 268)

const BALL_ARC: = 54.0
const LINES_INTRO: = [
	"Hello there! Welcome to the world of POKéMON!", 
	"My name is OAK. People call me the POKéMON PROF.", 
	"This world is inhabited far and wide by creatures called POKéMON.", 
]
const LINE_AFTER_NAME: = "%s! Your very own POKéMON legend is about to unfold!"
const LINES_RIVAL: = [
	"This is my grandson. He's been your rival\nsince you were a baby.", 
	"…Er, what is his name?", 
]
const LINE_FINALE: = "A world of dreams and adventures with POKéMON awaits! Let's go!"



class BallIcon extends Control:
	const UI: = preload("res://scripts/ui/ui_draw.gd")
	const D: = 54.0
	var alpha: = 0.0:
		set(v):
			alpha = v
			queue_redraw()

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void :
		if alpha <= 0.0:
			return
		var tint: = Color(1, 1, 1, alpha)
		UI._ball(self, Rect2( - Vector2(D, D) * 0.5, Vector2(D, D)), UiKit.RED * tint, Color(0, 0, 0, 0), tint)


var _oak: TextureRect
var _mon: TextureRect
var _ball: BallIcon
var _box: PkDialogBox
var _skip: = false


func _init() -> void :
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: = ColorRect.new()
	bg.color = Color("10162a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var rg: = Gradient.new()
	rg.colors = PackedColorArray([Color("33447a"), Color(0.06, 0.08, 0.16, 0)])
	var rgt: = GradientTexture2D.new()
	rgt.gradient = rg
	rgt.fill = GradientTexture2D.FILL_RADIAL
	rgt.fill_from = Vector2(0.5, 0.42)
	rgt.fill_to = Vector2(0.5, 1.05)
	var glow: = TextureRect.new()
	glow.texture = rgt
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(glow)
	_oak = _sprite_frame(OAK_SPRITE, OAK_SIZE, Vector2(640 - 80, 374 - 200), OAK_FRAME)
	add_child(_oak)


	_ball = BallIcon.new()
	_ball.position = BALL_FROM
	add_child(_ball)
	_mon = _sprite_frame(MON_SPRITE, MON_SIZE, MON_POS, Rect2(0, 0, 32, 32))
	_mon.modulate.a = 0.0
	add_child(_mon)
	_box = PkDialogBox.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_box.offset_left = 120
	_box.offset_right = -120
	_box.offset_top = -190
	_box.offset_bottom = -30
	add_child(_box)
	modulate.a = 0.0




func _sprite_frame(path: String, size: Vector2, pos: Vector2, region: Rect2, 
		stretch: = TextureRect.STRETCH_SCALE) -> TextureRect:
	var at: = AtlasTexture.new()
	at.atlas = load(path)
	at.region = region
	var t: = TextureRect.new()
	t.texture = at
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = stretch
	t.size = size
	t.position = pos
	t.pivot_offset = size * 0.5
	return t


func play_intro() -> void :
	var tw: = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.5)
	await tw.finished
	await _say(LINES_INTRO)
	if _skip:
		return
	await _send_out_mon()




func _send_out_mon() -> void :
	var to: = MON_POS + MON_SIZE * 0.5
	_ball.position = BALL_FROM
	_ball.alpha = 1.0
	Audio.play_exact("sfx/pokemon/ball_throw")
	var tw: = create_tween()
	tw.tween_method(_fly_ball.bind(to), 0.0, 1.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished

	Audio.play_exact("sfx/pokemon/ball_open")
	Audio.cry(MON_SPECIES)
	_ball.alpha = 0.0
	_mon.modulate.a = 1.0
	_mon.scale = Vector2(0.25, 0.25)
	var tw2: = create_tween()
	tw2.tween_property(_mon, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw2.finished



func _fly_ball(t: float, to: Vector2) -> void :
	_ball.position = BALL_FROM.lerp(to, t) - Vector2(0, sin(t * PI) * BALL_ARC)
	_ball.queue_redraw()


func play_after_player(player_name: String) -> void :
	if _skip:
		return
	await _say([LINE_AFTER_NAME % player_name])
	if _skip:
		return
	await _say(LINES_RIVAL)


func play_finale() -> void :
	if not _skip:
		await _say([LINE_FINALE])
	var tw: = create_tween().set_parallel()
	tw.tween_property(_oak, "scale", Vector2(0.2, 0.2), 0.6)
	tw.tween_property(_oak, "modulate:a", 0.0, 0.6)
	tw.tween_property(_mon, "modulate:a", 0.0, 0.6)
	tw.tween_property(_ball, "alpha", 0.0, 0.6)
	await tw.finished



func skip() -> void :
	_skip = true
	_box.skip()


func _say(lines: Array) -> void :
	if _skip:
		return
	await _box.say("PROF. OAK", lines)
