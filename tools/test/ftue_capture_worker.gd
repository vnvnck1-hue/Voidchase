## FTUE 화면 캡처 (창 필요): 타이틀 → 프롤로그 → 로딩 → 첫 방(장소 카드·말풍선·코치) → 일시정지 → 엔딩 → 결과 → 허브 탭들 → 패배 결과.
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/FtueCapture.tscn [-- --out=<dir>]
## 기본 저장 위치 docs/ftue/. 세이브는 임시 파일을 쓴다.
extends Node

const SAVE := "user://ftue_capture_save.cfg"

var out_dir := "res://docs/ftue"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _until(cond: Callable, timeout := 20.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and (Time.get_ticks_msec() - t0) / 1000.0 < timeout:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_dir.path_join(name + ".png"))
	img.save_png(path)
	print("[ftue_capture] %s" % path)


func _find(root: Node, script_class: String) -> Node:
	for c in root.get_children():
		var s: Script = c.get_script()
		if s != null and s.get_global_name() == script_class:
			return c
		var r := _find(c, script_class)
		if r:
			return r
	return null


## 그 클래스의 노드가 생길 때까지 기다렸다 돌려준다 (없으면 null).
func _node(root: Node, script_class: String, timeout := 8.0) -> Node:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < timeout:
		var n := _find(root, script_class)
		if n and not n.is_queued_for_deletion():
			return n
		await get_tree().process_frame
	return null


func _battle() -> VDBattle:
	return get_tree().current_scene as VDBattle


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	GameSave.use_path(SAVE)
	await _wait(0.3)
	SceneSwitcher.go_lobby()
	await _wait(0.1)
	await _until(func() -> bool: return not SceneSwitcher.is_loading())
	var hub := get_tree().current_scene
	await _wait(1.0)
	await _shot("01_title_boot")
	await _wait(2.4)
	await _shot("02_title")
	hub._title.enter()
	await _until(func() -> bool: return hub._dialog != null)
	await _wait(1.6)
	await _shot("03_prologue_note")
	hub._dialog.step()
	hub._dialog.step()
	await _wait(1.4)
	await _shot("04_prologue_chief")
	for who in ["knight", "gunner", "mage", "healer"]:
		hub._dialog.step()
		hub._dialog.step()
		await _wait(1.2)
		await _shot("05_prologue_%s" % who)
	hub._dialog.skip()
	await _until(func() -> bool: return SceneSwitcher._loading != null, 5.0)
	await _wait(0.7)
	await _shot("06_loading")
	await _until(func() -> bool: return SceneSwitcher.current_index() == 1 and not SceneSwitcher.is_loading())
	var b := _battle()
	await _until(func() -> bool: return b.case_run.bark._place_t >= 0.9, 12.0)
	await _shot("07_room_place_card")
	await _until(func() -> bool: return b.case_run.coach.is_showing(), 8.0)
	await _wait(0.6)
	await _shot("08_coach_place")
	b.case_run.coach.dismiss()
	await _wait(0.3)
	b.case_run.coach.dismiss()
	await _wait(0.3)
	await _until(func() -> bool: return b.case_run.coach.is_showing() and b.case_run.coach._cur.get("id", "") == "start", 6.0)
	await _wait(0.6)
	await _shot("09_coach_start")
	b.start_battle()
	await _until(func() -> bool: return b.state == VDBattle.State.BATTLE)
	# 궁극기 안내: 마법사 게이지를 채운다
	await _wait(1.5)
	for a in b.allies:
		if a.id == "mage":
			a.gain_ult(VDData.MAX_ULT)
	b.case_run.coach.dismiss()
	await _until(func() -> bool: return b.case_run.coach._cur.get("id", "") == "ult", 6.0)
	await _wait(0.7)
	await _shot("10_coach_ult")
	b.case_run.bark.shout("아직 부족해!")
	await _wait(0.5)
	await _shot("11_boss_shout")
	SceneSwitcher.request_lobby()
	await _wait(0.5)
	await _shot("12_pause")
	SceneSwitcher.request_lobby()
	await _wait(0.3)
	# 엔딩: 마지막 방까지 정리한 것으로 치고 끝낸다
	b.stage = 5
	b.case_run.stats = {"rooms": 5, "kills": 63}
	b.essence = 148
	b.case_run.finish(true)
	var dlg := await _node(b.case_run, "StoryDialog") as StoryDialog
	await _wait(1.3)
	await _shot("13_door_client")
	dlg.step()
	dlg.step()
	await _wait(1.3)
	await _shot("14_door_healer")
	dlg.skip()
	var lg := await _node(b.case_run, "VDMemoryLog") as VDMemoryLog
	for i in 3:
		await _wait(2.6)
		await _shot("15_memory_log_%d" % (i + 1))
		lg._advance()
		lg._advance()
	await _wait(0.6)
	dlg = await _node(b.case_run, "StoryDialog") as StoryDialog
	await _wait(1.6)
	await _shot("16_ending_line")
	dlg.skip()
	await _until(func() -> bool: return b.case_run.result != null, 8.0)
	await _wait(1.5)
	await _shot("17_result_clear_counting")
	await _wait(4.0)
	await _shot("18_result_clear")
	b.case_run.result._emit("hub")
	await _wait(0.2)
	await _until(func() -> bool: return SceneSwitcher.current_index() == 0 and not SceneSwitcher.is_loading())
	hub = get_tree().current_scene
	await _wait(2.4)
	await _shot("19_hub_after_clear")
	for id in ["squad", "upgrade", "postcards", "lab"]:
		hub._show_tab(id)
		await _wait(0.5)
		await _shot("20_hub_%s" % id)
	hub._show_tab("upgrade")
	hub._buy("vital")
	hub._buy("pocket")
	await _wait(0.6)
	await _shot("21_hub_upgrade_bought")
	hub._show_tab("case")
	await _wait(0.4)
	# 패배 결과
	hub.dive("case")
	await _wait(0.2)
	await _until(func() -> bool: return SceneSwitcher.current_index() == 1 and not SceneSwitcher.is_loading())
	b = _battle()
	await _until(func() -> bool: return b.state == VDBattle.State.PLACEMENT and not b._spawning)
	b.start_battle()
	await _until(func() -> bool: return b.state == VDBattle.State.BATTLE)
	b.case_run.stats = {"rooms": 2, "kills": 21}
	b.essence = 57
	for a in b.allies:
		a.take_damage(99999.0)
	await _wait(2.2)
	await _shot("22_defeat_banner")
	await _until(func() -> bool: return b.case_run.result != null, 12.0)
	await _wait(4.5)
	await _shot("23_result_retreat")
	# 첫 방문 허브 (메뉴 잠김)
	GameSave.wipe()
	GameSave.mark_prologue_seen()
	b.case_run.result._emit("hub")
	await _wait(0.2)
	await _until(func() -> bool: return SceneSwitcher.current_index() == 0 and not SceneSwitcher.is_loading())
	await _wait(2.6)
	await _shot("24_hub_first_visit")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("[ftue_capture] DONE")
	get_tree().quit()
