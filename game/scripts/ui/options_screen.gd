class_name OptionsScreen
extends Control




signal closed


const ControlsScreenScript: = preload("res://scripts/ui/controls_screen.gd")

var _win: PkWindow
var _list: PkOptionList
var _speed: PkOptionRow
var _battle_speed: PkOptionRow
var _music: PkOptionRow
var _sound: PkOptionRow
var _window: PkOptionRow
var _quality: PkOptionRow
var _tips: PkOptionRow
var _touch: PkOptionRow
var _analytics: PkOptionRow
var _controls_row: PkOptionRow
var _controls: Control


func _init() -> void :
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim: = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_win = PkWindow.new()
	_win.title = "OPTIONS"
	_win.custom_minimum_size = Vector2(620, 0)
	center.add_child(_win)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_win.add_child(col)
	_list = PkOptionList.new()
	col.add_child(_list)
	_speed = PkOptionRow.make("TEXT SPEED", PkOptionRow.Kind.CHOICE, Settings.text_speed, Settings.TEXT_SPEEDS)
	_speed.changed.connect( func(v): Settings.set_value("text_speed", v))
	_battle_speed = PkOptionRow.make("BATTLE SPEED", PkOptionRow.Kind.CHOICE, Settings.battle_speed, Settings.BATTLE_SPEED_NAMES)
	_battle_speed.changed.connect( func(v): Settings.set_value("battle_speed", v))
	_music = PkOptionRow.make("MUSIC", PkOptionRow.Kind.VOLUME, 8)
	_music.changed.connect( func(v): Audio.set_volume("Music", v / 10.0))
	_sound = PkOptionRow.make("SOUND", PkOptionRow.Kind.VOLUME, 10)
	_sound.changed.connect( func(v):
		Audio.set_volume("SFX", v / 10.0)
		Audio.set_volume("UI", v / 10.0))
	_window = PkOptionRow.make("WINDOW", PkOptionRow.Kind.CHOICE, Settings.window_mode, Settings.WINDOW_MODES)
	_window.changed.connect( func(v): Settings.set_value("window_mode", v))
	_quality = PkOptionRow.make("GRAPHICS", PkOptionRow.Kind.CHOICE, Settings.quality, Settings.QUALITY_NAMES)
	_quality.changed.connect( func(v): Settings.set_value("quality", v))
	_tips = PkOptionRow.make("BATTLE TIPS", PkOptionRow.Kind.TOGGLE, Settings.battle_tips)
	_tips.changed.connect( func(v): Settings.set_value("battle_tips", v))
	_touch = PkOptionRow.make("TOUCH CONTROLS", PkOptionRow.Kind.CHOICE, Settings.touch_controls, Settings.TOUCH_MODES)
	_touch.changed.connect( func(v): Settings.set_value("touch_controls", v))

	_analytics = PkOptionRow.make("SEND PLAY DATA", PkOptionRow.Kind.TOGGLE, Settings.analytics == 1)
	_analytics.changed.connect( func(v): Analytics.set_consent(v, "options"))
	_controls_row = PkOptionRow.make("CONTROLS", PkOptionRow.Kind.ACTION, 0)
	_controls_row.activated.connect(_open_controls)
	for r in [_speed, _battle_speed, _music, _sound, _window, _quality, _tips, _touch, _analytics, _controls_row]:
		_list.add_row(r)
	var hints: = PkHintBar.new()
	hints.set_hints([[["pk_up", "pk_down"], "Choose"], [["pk_left", "pk_right"], "Change"], ["pk_ok", "Open"], ["pk_back", "Back"]])
	hints.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(hints)
	_controls = ControlsScreenScript.new()
	_controls.closed.connect( func():
		_win.visible = true
		_list.active = true)
	add_child(_controls)
	_list.active = false
	_list.cancelled.connect(_close)


func open() -> void :
	_speed.set_value_silent(Settings.text_speed)
	_battle_speed.set_value_silent(Settings.battle_speed)
	_music.set_value_silent(roundi(Audio.get_volume("Music") * 10.0))
	_sound.set_value_silent(roundi(Audio.get_volume("SFX") * 10.0))
	_window.set_value_silent(Settings.window_mode)
	_quality.set_value_silent(Settings.quality)
	_tips.set_value_silent(Settings.battle_tips)
	_touch.set_value_silent(Settings.touch_controls)
	_analytics.set_value_silent(Settings.analytics == 1)
	visible = true
	UiKit.sfx("menu_open")
	UiKit.pop_in(_win)
	_list.active = true


func _open_controls() -> void :
	_list.active = false
	_win.visible = false
	_controls.open()


func _close() -> void :
	_list.active = false
	UiKit.sfx("menu_close")
	await UiKit.pop_out(_win)
	visible = false
	_win.visible = true
	closed.emit()
