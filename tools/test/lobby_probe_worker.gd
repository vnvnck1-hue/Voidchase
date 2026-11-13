extends Node

var out_dir := ""
var _fail := 0


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().create_timer(0.3).timeout
	SceneSwitcher.go_lobby()
	# 테스트 씬 → 로비도 코믹 파편 전환을 거친다: 끝날 때까지 기다린다
	await get_tree().create_timer(0.1).timeout
	while SceneSwitcher.is_loading():
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	_expect(0, "lobby")
	await _shot("lobby")
	for i in range(1, SceneSwitcher.SCENES.size()):
		var t0 := Time.get_ticks_msec()
		SceneSwitcher.switch_to(i)
		# 로비 → 모드는 페이크 로딩 화면(1~3초 랜덤) → 코믹 파편 전환(약 1.3초: 다 덮인 0.5 에서 씬 교체) 을 거친다
		if not SceneSwitcher.is_loading():
			_fail += 1
			print("[lobby_probe] FAIL no loading screen for mode %d" % i)
		var prev := SceneSwitcher.current_index()
		var saw_wipe := false
		var swap_p := -1.0          # 전환이 떠 있는 동안 씬이 바뀌었다면 그때의 progress
		var swap_under_loading := false   # 로딩 화면 아래에서(전환 전에) 씬이 바뀌었는가
		var wipe_after_swap := false
		var swapped := false
		while SceneSwitcher.is_loading():
			await get_tree().process_frame
			var w: Node = SceneSwitcher._wipe
			if not swapped and SceneSwitcher.current_index() != prev:
				swapped = true
				if is_instance_valid(w):
					swap_p = w.progress
				elif SceneSwitcher._loading != null:
					swap_under_loading = true
			if is_instance_valid(w):
				saw_wipe = true
				if swapped:
					wipe_after_swap = true
		var dt := (Time.get_ticks_msec() - t0) / 1000.0
		# 하한 = 고른 전환의 덮기 + 걷기 시간 (번개 닫힘은 0.66초로 색판 프리셋보다 짧다: 고정값 0.9 를 쓰지 않는다)
		var st := preload("res://scripts/screen_transition.gd")
		var dt_ok := dt >= st.in_dur() + st.out_dur() and dt <= 5.5
		if not dt_ok:
			_fail += 1
		print("[lobby_probe] %s loading+wipe %.2fs" % ["ok  " if dt_ok else "FAIL", dt])
		if SceneSwitcher.SCENES[i].get("loading", true):
			# 로딩 경로: 씬은 로딩 화면 아래에서 바뀌고, 그 뒤에 전환이 뜬다 (전환 중 멈춤 없음)
			var wipe_ok := swap_under_loading and wipe_after_swap
			if not wipe_ok:
				_fail += 1
			print("[lobby_probe] %s scene swapped under loading screen, then wipe (saw_wipe=%s)" % ["ok  " if wipe_ok else "FAIL", saw_wipe])
		else:
			# 직접 전환: 다 덮인 0.5 에서 교체
			var wipe_ok := saw_wipe and is_equal_approx(swap_p, 0.5)
			if not wipe_ok:
				_fail += 1
			print("[lobby_probe] %s wipe only, scene swapped at progress %.2f" % ["ok  " if wipe_ok else "FAIL", swap_p])
		await get_tree().create_timer(1.2).timeout
		_expect(i, SceneSwitcher.SCENES[i]["name"])
		await _shot("mode_%d" % i)
		# Esc 로 로비 복귀
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.pressed = true
		Input.parse_input_event(ev)
		# Esc → 로비도 코믹 파편 전환을 거친다 (덮인 0.5 에서 교체)
		await get_tree().create_timer(0.1).timeout
		while SceneSwitcher.is_loading():
			await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
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
