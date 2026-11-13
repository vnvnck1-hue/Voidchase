## 타일 글리치(VDTileGlitch) 검증·캡처: 프리셋 3종 × 테마 2종, 충격 물결, 바닥 기억 로그.
## 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/TileGlitchCapture.tscn -- --frames=<절대 경로>
##   docs/tile_glitch/<테마>_<프리셋>_dense.png : 지직거리는 타일을 일부러 늘린 정지 화면
##   --frames 폴더: 실제 빈도의 연속 프레임(12fps, GIF 용) · 물결 · 로그
## 헤드리스로 돌리면 그림 없이 전환·저장·물결·로그 상태만 확인한다.
extends Node

const OUT := "res://docs/tile_glitch/"
const CONFIG := OUT + "test_settings/"
const TAGS := ["off", "signal", "data", "holo"]
const SEQ_FRAMES := 30
var frames_dir := ""
var failures: Array[String] = []


func _check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
	print("[tile_glitch] %s %s" % ["PASS" if ok else "FAIL", description])


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONFIG))
	for file_name in ["world.cfg", "tile_glitch.cfg"]:
		ConfigFile.new().save(CONFIG + file_name)
	VDWorldTheme.config_path = CONFIG + "world.cfg"
	VDWorldTheme._loaded = false
	VDTileGlitch.config_path = CONFIG + "tile_glitch.cfg"
	VDTileGlitch._loaded = false
	VDTileGlitch.selected = 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			frames_dir = arg.substr(9).trim_suffix("/") + "/"
			DirAccess.make_dir_recursive_absolute(frames_dir)
	call_deferred("_run")


func _shot(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _run() -> void:
	var headless := DisplayServer.get_name() == "headless"
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	while b.enemies.is_empty():
		await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	var tg := b.tile_glitch
	_check(tg != null and tg.visible and VDTileGlitch.selected == 1, "tile glitch on by default (signal)")
	_check(tg.get_index() == b.board.get_index() + 1 and tg.get_index() < b.ground_fx.get_index(), "sits right above the board, below ground fx")
	for style in [1, 2, 3]:
		tg.set_style(style, false)
		_check(int(tg._mat.get_shader_parameter("style")) == style - 1 and tg.visible, "preset %s applies" % TAGS[style])
	tg.set_style(0, false)
	_check(not tg.visible, "off hides the layer")
	tg.set_style(2, true)
	VDTileGlitch._loaded = false
	VDTileGlitch.selected = 1
	VDTileGlitch.load_saved()
	_check(VDTileGlitch.selected == 2, "preset reloads from config")
	_check(tg.cycle() == "기억 홀로그램" and tg.cycle() == "끄기" and tg.cycle() == "신호 잡음", "F4 cycle order")
	var center := VDData.to_screen(VDMap.center_f(b.room))
	tg._pulses.clear()
	tg.on_struck(center, "light", 1.0)
	_check(tg._pulses.is_empty(), "light hits do not pulse")
	tg.on_struck(center, "kill", 1.0)
	_check(tg._pulses.size() == 1, "kill pulses tiles")
	var cell := VDData.to_cell(center)
	tg.show_log(cell, "기억 조각 #3F2")
	_check(not tg._log.is_empty(), "memory log shows")
	SceneSwitcher.set_menu_open(true)
	var found := false
	for it: Dictionary in SceneSwitcher._items:
		found = found or str(it["text"]).begins_with("타일 글리치")
	_check(found, "settings menu has tile glitch choice")
	SceneSwitcher.set_menu_open(false)
	if headless or frames_dir == "":
		print("[tile_glitch] DONE failures=%d" % failures.size())
		get_tree().quit(0 if failures.is_empty() else 1)
		return

	tg.manual_time = true
	tg.log_on = false
	tg._log.clear()
	tg._log_layer.queue_redraw()
	for theme in [VDWorldTheme.Kind.DESERT, VDWorldTheme.Kind.VOID]:
		b.set_background_theme(theme, false)
		var tag := VDWorldTheme.profile(theme)
		for style in [1, 2, 3]:
			tg._pulses.clear()
			tg.density_boost = 1.0
			tg.set_style(style, false)
			for f in SEQ_FRAMES:
				tg.time = 100.0 + f / 12.0
				await _shot("%s%s_%s_%02d.png" % [frames_dir, tag, TAGS[style], f])
			tg.density_boost = 7.0
			tg.set_style(style, false)
			tg.time = 200.3
			await _shot(ProjectSettings.globalize_path(OUT) + "%s_%s_dense.png" % [tag, TAGS[style]])
	# 충격 물결 (내려찍기) · 구역 로딩 물결
	b.set_background_theme(VDWorldTheme.Kind.DESERT, false)
	tg.density_boost = 1.0
	for style in [1, 2, 3]:
		tg.set_style(style, false)
		tg._pulses.clear()
		tg.time = 300.0
		tg.on_struck(center, "slam", 1.0)
		for f in 12:
			tg.time = 300.0 + f * 0.06
			await _shot("%spulse_%s_%02d.png" % [frames_dir, TAGS[style], f])
	# 바닥 기억 로그
	tg.set_style(1, false)
	tg._pulses.clear()
	tg.log_on = true
	tg.show_log(cell, "기억 조각 #3F2")
	for f in 10:
		tg._log["t"] = 0.1 + f * 0.16
		tg.time = 400.0 + f * 0.16
		tg._log_layer.queue_redraw()
		await _shot("%slog_%02d.png" % [frames_dir, f])
	print("[tile_glitch] board center on screen: %s" % str(b.camera.get_viewport_transform() * center))
	print("[tile_glitch] DONE failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
