extends Node

var out_dir := ""
var _fail := 0


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().create_timer(0.3).timeout
	SceneSwitcher.go_lobby()
	await get_tree().create_timer(0.6).timeout
	_expect(0, "lobby")
	await _shot("lobby")
	for i in range(1, SceneSwitcher.SCENES.size()):
		var t0 := Time.get_ticks_msec()
		SceneSwitcher.switch_to(i)
		# 로비 → 모드는 페이크 로딩 화면(1~3초 랜덤 + 걷히는 시간)을 거친다
		if not SceneSwitcher.is_loading():
			_fail += 1
			print("[lobby_probe] FAIL no loading screen for mode %d" % i)
		while SceneSwitcher.is_loading():
			await get_tree().process_frame
		var dt := (Time.get_ticks_msec() - t0) / 1000.0
		if dt < 0.9 or dt > 4.5:
			_fail += 1
		print("[lobby_probe] %s loading %.2fs" % ["ok  " if dt >= 0.9 and dt <= 4.5 else "FAIL", dt])
		await get_tree().create_timer(1.2).timeout
		_expect(i, SceneSwitcher.SCENES[i]["name"])
		await _shot("mode_%d" % i)
		# Esc 로 로비 복귀
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().create_timer(0.6).timeout
		_expect(0, "lobby after esc from %d" % i)
	print("[lobby_probe] %s  (fail=%d)" % ["DONE" if _fail == 0 else "FAILED", _fail])
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(0 if _fail == 0 else 1)


func _expect(idx: int, label: String) -> void:
	var cur := SceneSwitcher.current_index()
	var cs := get_tree().current_scene
	var path := cs.scene_file_path if cs else "<none>"
	if cur == idx:
		print("[lobby_probe] ok   %-28s -> %s" % [label, path])
	else:
		_fail += 1
		print("[lobby_probe] FAIL %-28s expected %d got %d (%s)" % [label, idx, cur, path])


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out_dir)
	img.save_png(out_dir.path_join(name + ".png"))
