## 패배 연출 캡처: 전투를 시작하고 바로 게임 오버를 걸어 화면 글리치 → 흑백 → "거점 함락" 배너 → 패널까지 연속 프레임을
## 메모리에 담았다가 docs/defeat_glitch/ 에 저장한다 (PNG 저장이 느려서 찍는 동안은 저장하지 않는다). 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/DefeatCapture.tscn
##   defeat_<프레임>.png : 전체 화면 (실제 시간 약 0.15초 간격) · strip_defeat.png : 축소해 이어 붙인 것 · final.png : 패널까지 다 뜬 뒤
## 헤드리스로 돌리면 글리치 수명과 패널이 뜨는지만 확인한다.
extends Node

const OUT := "res://docs/defeat_glitch/"
const FRAMES := 24
const GAP := 0.15


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var headless := DisplayServer.get_name() == "headless"
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	while b.enemies.is_empty():
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	b.start_battle()
	await get_tree().create_timer(1.2).timeout
	var vp := get_viewport()
	var sg = b.screen_glitch
	if sg == null:
		print("[defeat] battle failed to build -> quit")
		get_tree().quit(1)
		return
	b._do_game_over()
	if headless:
		var t0 := Time.get_ticks_msec()
		while sg.is_active():
			await get_tree().process_frame
		print("[defeat] glitch lived %d ms" % [Time.get_ticks_msec() - t0])
		await get_tree().create_timer(3.0, true, false, true).timeout
		print("[defeat] panel visible=%s" % str(b._over_panel.visible))
		get_tree().quit(0)
		return
	var shots: Array[Image] = []
	var times: Array[float] = []
	var t0 := Time.get_ticks_msec()
	for f in FRAMES:
		await RenderingServer.frame_post_draw
		shots.append(vp.get_texture().get_image())
		times.append((Time.get_ticks_msec() - t0) / 1000.0)
		await get_tree().create_timer(GAP, true, false, true).timeout
	await get_tree().create_timer(1.5, true, false, true).timeout
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(OUT + "final.png")
	var w := 480
	var h := 270
	var cols := 8
	var rows := ceili(FRAMES / float(cols))
	var sheet := Image.create(w * cols, h * rows, false, shots[0].get_format())
	for f in FRAMES:
		shots[f].save_png(OUT + "defeat_%02d.png" % f)
		shots[f].resize(w, h, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(shots[f], Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i(w * (f % cols), h * (f / cols)))
	sheet.save_png(OUT + "sheet_defeat.png")
	print("[defeat] frames at %s" % str(times))
	get_tree().quit(0)
