import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve('game');
const baseline = path.resolve('reference/prototype/baseline');
// Always start from untouched recovered files so adaptations are reproducible.
for (const file of ['project.godot', 'scripts/analytics.gd', 'scripts/ui/touch_controls.gd', 'scripts/controls.gd', 'scripts/settings.gd', 'scripts/front/main_menu.gd', 'scripts/ui/battle_hud.gd', 'scripts/ui/ui_draw.gd']) {
  fs.copyFileSync(path.join(baseline, file), path.join(root, file));
}
function edit(file, from, to) {
  const target = path.join(root, file);
  const source = fs.readFileSync(target, 'utf8');
  if (!source.includes(from)) throw new Error(`Missing adaptation anchor: ${file}`);
  fs.writeFileSync(target, source.replace(from, to));
}

edit('project.godot', 'BeckettRuntime="*uid://do68dqybesb7r"\n', '');
edit('project.godot', 'enabled=PackedStringArray("res://addons/beckett/plugin.cfg")', 'enabled=PackedStringArray()');
edit('project.godot', 'config/name="Pokémon Prototype Demo"', 'config/name="Pokémon Prototype Mobile"');
edit('project.godot', 'config/version="0.1.0-demo"', 'config/version="0.2.0-national"');
edit('project.godot', 'window/stretch/aspect="expand"', 'window/stretch/aspect="expand"\nwindow/handheld/orientation=0\nwindow/size/window_width_override=1280\nwindow/size/window_height_override=720');
edit('project.godot', 'renderer/rendering_method.mobile="forward_plus"', 'renderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"');
edit('project.godot', '[physics]', '[input_devices]\n\npointing/emulate_mouse_from_touch=false\n\n[physics]');
edit('scripts/analytics.gd', 'enabled = DisplayServer.get_name() != "headless" and not checkpoint\\\n\tand not ("--no-analytics" in args) and (debug_force or dbg == null or not dbg.enabled)', 'enabled = false # Offline mobile port: no telemetry or consent interruption.');
edit('scripts/ui/touch_controls.gd', '\t_read_settings()\n\tif OS.get_cmdline_user_args().has("--touch"):', '\t_read_settings()\n\tif OS.has_feature("mobile") or OS.has_feature("web"):\n\t\tforced = true\n\t\t_refresh()\n\tget_viewport().size_changed.connect(Controls.reset_ui_scale)\n\tif OS.get_cmdline_user_args().has("--touch"):');
edit('scripts/ui/touch_controls.gd', 'Input.set_emulate_touch_from_mouse(true)\n\tControls.emulate_touch = true', 'var desktop_preview := not OS.has_feature("mobile")\n\tInput.set_emulate_touch_from_mouse(false)\n\tControls.emulate_touch = desktop_preview');
edit('scripts/ui/touch_controls.gd', '\t\tforced = true\n\t\t_refresh()', '\t\tforced = true\n\t\tif OS.has_feature("web"):\n\t\t\t_enable_mouse_touch()\n\t\t_refresh()');
// Native finger events must work even when the desktop preview uses mouse input.
edit('scripts/ui/touch_controls.gd', '\t\tif Controls.emulate_touch:\n\t\t\treturn\n\t\tif mode == Mode.OFF:', '\t\tif mode == Mode.OFF:');
edit('scripts/ui/touch_controls.gd', '\t\tif Controls.emulate_touch:\n\t\t\treturn\n\t\tif visible:', '\t\tif visible:');
edit('scripts/ui/touch_controls.gd', '\tif stick_origin != Vector2.ZERO and _has_stick():\n\t\t_draw_stick(s)', '\tif _has_stick():\n\t\t_draw_stick(s)\n\telse:\n\t\t_draw_idle_stick(s)');
edit('scripts/ui/touch_controls.gd', 'func _draw_stick(s: Control) -> void :', 'func _draw_idle_stick(s: Control) -> void:\n\tvar r := stick_radius()\n\tvar c := Vector2(42.0 + r, _vp().y - 48.0 - r)\n\ts.draw_circle(c, r, Color(0.04, 0.07, 0.08, 0.35))\n\ts.draw_arc(c, r, 0.0, TAU, 64, Color(1, 1, 1, 0.45), 2.0, true)\n\ts.draw_circle(c, KNOB_R * ui_scale(), Color(1, 1, 1, 0.2))\n\n\nfunc _draw_stick(s: Control) -> void :');
edit('scripts/ui/touch_controls.gd', 'func _process(delta: float) -> void :', 'func _notification(what: int) -> void:\n\tif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:\n\t\t_release_all()\n\n\nfunc _process(delta: float) -> void :');
edit('scripts/ui/touch_controls.gd', '["move_left", "move_right", "move_up", "move_down", "run"]', '["move_left", "move_right", "move_up", "move_down"]');
edit('scripts/ui/touch_controls.gd', '\tif _confirm_mode():\n\t\t_draw_a', '\tif _title_mode():\n\t\treturn\n\tif _confirm_mode():\n\t\t_draw_a');
// A 16:9 minimum canvas preserves the original menus; wider phones gain world space.
// Clamp DPI-driven controls to keep the right action cluster clear of the field.
edit('scripts/controls.gd', 'return clampf(demand_scale(), UI_SCALE_MIN, UI_SCALE_MAX)', 'return clampf(maxf(demand_scale(), screen_target_scale(48.0, 56.0)), UI_SCALE_MIN, UI_SCALE_MAX)');
edit('scripts/controls.gd', 'return clampf(TAP_REF_PX * demand_scale() / maxf(base_px, 0.001), UI_SCALE_MIN, UI_SCALE_MAX)', 'return clampf(maxf(TAP_REF_PX * demand_scale() / maxf(base_px, 0.001), screen_target_scale(60.0 if base_px >= 90.0 else 52.0, base_px)), UI_SCALE_MIN, UI_SCALE_MAX)');
edit('scripts/controls.gd', 'static func reset_ui_scale() -> void :', 'static func screen_target_scale(pixels: float, base: float) -> float:\n\tvar tree = Engine.get_main_loop()\n\tif tree is SceneTree and DisplayServer.get_name() != "headless":\n\t\tvar h := maxf(float(DisplayServer.window_get_size().y), 1.0)\n\t\treturn pixels * tree.root.get_visible_rect().size.y / (h * base)\n\treturn 1.0\n\nstatic func screen_font(pixels: float) -> int:\n\treturn int(ceil(screen_target_scale(pixels, 1.0)))\n\nstatic func reset_ui_scale() -> void :');
edit('scripts/settings.gd', 'const TOUCH_MODES: = ["Auto", "On", "Off"]', 'const TOUCH_MODES: = ["Auto", "On"]');
edit('scripts/settings.gd', 'touch_controls = clampi(int(v), 0, TOUCH_MODES.size() - 1)', 'touch_controls = clampi(int(v), 0, TOUCH_MODES.size() - 1)');
// Bound stored older Off values to On so a touch-only player can always recover.
edit('scripts/settings.gd', 'touch_controls = clampi(int(cfg.get_value("options", "touch_controls", 0)), 0, TOUCH_MODES.size() - 1)', 'touch_controls = clampi(int(cfg.get_value("options", "touch_controls", 0)), 0, TOUCH_MODES.size() - 1)');
edit('scripts/ui/battle_hud.gd', '\t\tvar fs: = NAME_FS', '\t\tvar fs: = maxi(NAME_FS, Controls.screen_font(12.0)) if Controls.is_touch() else NAME_FS');
edit('scripts/ui/battle_hud.gd', '\tfunc _wrap(nm: String, fs: int) -> Array:', '\tfunc _name_width() -> float:\n\t\treturn size.x * 0.92 if Controls.is_touch() else NAME_W\n\n\tfunc _wrap(nm: String, fs: int) -> Array:');
// Keep long move names readable by wrapping whole words, then long words by character.
edit('scripts/ui/battle_hud.gd', '\t\tfor w in nm.split(" ", false):', '\t\tif Controls.is_touch():\n\t\t\tvar line := ""\n\t\t\tfor ch in nm:\n\t\t\t\tif line != "" and UI.text_width(line + ch, fs, UiKit.title_font()) > _name_width():\n\t\t\t\t\tlines.append(line.strip_edges())\n\t\t\t\t\tline = ""\n\t\t\t\tline += ch\n\t\t\tif line != "":\n\t\t\t\tlines.append(line.strip_edges())\n\t\t\treturn lines\n\t\tfor w in nm.split(" ", false):');
const hudPath = path.join(root, 'scripts/ui/battle_hud.gd');
fs.writeFileSync(hudPath, fs.readFileSync(hudPath, 'utf8').replaceAll('> NAME_W', '> _name_width()'));
edit('scripts/ui/ui_draw.gd', 'int(clampf(r * 0.34, 14.0, 26.0))', 'maxi(int(clampf(r * 0.34, 14.0, 26.0)), Controls.screen_font(12.0)) if touch else int(clampf(r * 0.34, 14.0, 26.0))');
edit('scripts/settings.gd', '\tDisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if window_mode == 1 else DisplayServer.WINDOW_MODE_WINDOWED)', '\tif OS.has_feature("mobile") or OS.has_feature("web"):\n\t\treturn\n\tDisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if window_mode == 1 else DisplayServer.WINDOW_MODE_WINDOWED)');
edit('scripts/front/main_menu.gd', 'if not OS.has_feature("web"):', 'if not OS.has_feature("web") and not OS.has_feature("mobile"):');
// The desktop-only WebRTC native extension is absent on Android. Offline play
// retains the existing Net API without requiring that extension at startup.
fs.writeFileSync(path.join(root, '.godot/extension_list.cfg'), '');
fs.writeFileSync(path.join(root, 'addons/.gdignore'), '');
console.log('Applied landscape mobile adaptations to recovered Godot game.');
