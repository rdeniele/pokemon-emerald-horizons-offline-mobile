extends Control




const CHARIZARD: = "res://assets/pokemon/charizard/overworld.png"
const FRAME: = 32
const MON_SCALE: = 7.0
const SKY: = [Color("2a1b3d"), Color("b8453a"), Color("f2a65a")]

var _logo: VBoxContainer
var _press: Label
var _mon: TextureRect
var _shadow: Control
var _atlas: AtlasTexture
var _t: = 0.0
var _press_on: = false
var _mon_base: = Vector2(980, 210)


func _init() -> void :
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grad: = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	grad.colors = PackedColorArray(SKY)
	var gt: = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var sky: = TextureRect.new()
	sky.texture = gt
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	var embers: = CPUParticles2D.new()
	embers.position = Vector2(640, 760)
	embers.amount = 60
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(700, 10)
	embers.direction = Vector2(0.2, -1)
	embers.spread = 20.0
	embers.gravity = Vector2(0, -12)
	embers.initial_velocity_min = 30.0
	embers.initial_velocity_max = 70.0
	embers.scale_amount_min = 2.0
	embers.scale_amount_max = 5.0
	var ramp: = Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 0.75, 0.35, 0.9), Color(1, 0.4, 0.2, 0.0)])
	embers.color_ramp = ramp
	add_child(embers)

	_shadow = Control.new()
	_shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.draw.connect(_draw_shadow)
	add_child(_shadow)
	_atlas = AtlasTexture.new()
	_atlas.atlas = load(CHARIZARD)
	_atlas.region = Rect2(0, 0, FRAME, FRAME)
	_mon = TextureRect.new()
	_mon.texture = _atlas
	_mon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mon.size = Vector2(FRAME, FRAME) * MON_SCALE
	_mon.position = _mon_base
	add_child(_mon)
	_logo = VBoxContainer.new()
	_logo.position = Vector2(90, 120)
	_logo.add_theme_constant_override("separation", -6)
	var l1: = Label.new()
	l1.theme_type_variation = "TitleLabel"
	l1.text = "POKéMON"
	l1.add_theme_font_size_override("font_size", 96)
	l1.add_theme_color_override("font_color", Color("ffd84a"))
	l1.add_theme_color_override("font_outline_color", Color("2a3a8a"))
	_logo.add_child(l1)
	var l2: = Label.new()
	l2.theme_type_variation = "TitleLabel"
	l2.text = "BATTLE ADVANCED"
	l2.add_theme_font_size_override("font_size", 44)
	_logo.add_child(l2)
	_logo.modulate.a = 0.0
	add_child(_logo)
	_press = Label.new()
	_press.theme_type_variation = "HeaderLabel"
	_press.add_theme_color_override("font_color", UiKit.PAPER)
	_press.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	_press.position = Vector2(120, 520)
	_press.visible = false
	add_child(_press)
	var ver: = Label.new()
	ver.theme_type_variation = "HeaderLabel"
	ver.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "dev"))
	ver.add_theme_font_size_override("font_size", 16)
	ver.add_theme_color_override("font_color", Color(UiKit.PAPER, 0.65))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -260
	ver.offset_top = -42
	ver.offset_right = -18
	ver.offset_bottom = -16
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ver)


func _ready() -> void :
	_refresh_press()
	Controls.on_device_changed(_refresh_press)


func _exit_tree() -> void :
	Controls.off_device_changed(_refresh_press)




func _refresh_press(_device: String = "") -> void :
	_press.text = "TAP TO START" if Controls.device() == "touch"\
	else "PRESS %s" % Controls.key_label("pk_ok")



func play_intro() -> void :
	_logo.pivot_offset = Vector2(260, 80)
	_logo.scale = Vector2(1.3, 1.3)
	var tw: = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_logo, "modulate:a", 1.0, 0.25)
	tw.tween_property(_logo, "scale", Vector2.ONE, 0.35)
	await tw.finished
	UiKit.sfx("menu_open")
	var base: = position
	for i in 6:
		position = base + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		await get_tree().process_frame
	position = base
	show_press_start(true)


func show_instant() -> void :
	_logo.modulate.a = 1.0
	_logo.scale = Vector2.ONE
	show_press_start(false)


func show_press_start(on: bool) -> void :
	_press_on = on
	_press.visible = on


func _process(delta: float) -> void :
	_t += delta
	_atlas.region = Rect2((int(_t * 6.0) % 4) * FRAME, 0, FRAME, FRAME)
	_mon.position = _mon_base + Vector2(0, sin(_t * 2.0) * 8.0)
	if _press_on:
		_press.visible = fmod(_t, 1.0) < 0.65
	_shadow.queue_redraw()


func _draw_shadow() -> void :
	var c: = _mon_base + Vector2(FRAME * MON_SCALE * 0.5, FRAME * MON_SCALE + 26)
	var k: = 1.0 - sin(_t * 2.0) * 0.08
	_shadow.draw_set_transform(c, 0.0, Vector2(1.0, 0.22) * k)
	_shadow.draw_circle(Vector2.ZERO, 90.0, Color(0, 0, 0, 0.28))
