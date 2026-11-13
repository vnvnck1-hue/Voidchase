extends Node

const SAVE := "user://ftue_probe_save.cfg"
const SPEED := 6.0

var _fail := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fail += 1
	print("[ftue_probe] %s %s" % ["ok  " if ok else "FAIL", what])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _wait_until(cond: Callable, timeout: float, what: String) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await get_tree().process_frame
		if (Time.get_ticks_msec() - t0) / 1000.0 > timeout:
			_check(false, "timeout waiting for " + what)
			return false
	return true


func _scene() -> Node:
	return get_tree().current_scene


func _find(root: Node, script_class: String) -> Node:
	for c in root.get_children():
		var s: Script = c.get_script()
		if s != null and s.get_global_name() == script_class:
			return c
		var r := _find(c, script_class)
		if r:
			return r
	return null


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	GameSave.use_path(SAVE)
	_check(GameSave.is_first_run(), "fresh save = first run")
	await _wait(0.3)
	SceneSwitcher.go_lobby()
	await _wait(0.1)
	await _wait_until(func() -> bool: return not SceneSwitcher.is_loading(), 10.0, "lobby")
	await _wait(0.2)
	var hub := _scene()
	_check(SceneSwitcher.current_index() == 0, "hub is current scene")
	# 1) 타이틀
	_check(hub._title != null, "title shows on first boot")
	if hub._title:
		hub._title._t = 5.0
		hub._title.enter()
	await _wait_until(func() -> bool: return hub._title == null, 5.0, "title to close")
	# 2) 프롤로그
	_check(hub._dialog != null, "prologue starts on first run")
	if hub._dialog:
		var n: int = hub._dialog.lines.size()
		for i in 3:
			hub._dialog.step()
			await _wait(0.05)
		_check(n == 7 and not hub._dialog.is_done(), "prologue advances line by line (%d lines)" % n)
		hub._dialog.skip()
	# 3) 첫 다이브
	await _wait_until(func() -> bool: return SceneSwitcher.current_index() == 1 and not SceneSwitcher.is_loading(), 15.0, "first dive")
	_check(not GameSave.is_first_run(), "prologue marked seen")
	var b: VDBattle = _scene() as VDBattle
	_check(b != null and b.case_run != null and b.case_run.is_case(), "battle runs in case mode")
	if b == null or b.case_run == null:
		return _done()
	_check(b.case_run.room_total() == 5, "case has 5 rooms")
	# 분대를 크게 강화해 끝까지 간다 (흐름 점검이 목적)
	for a in b.allies:
		a.max_hp *= 30.0
		a.hp = a.max_hp
		a.atk *= 12.0
	b.auto_ult = true
	b.camera.set_game_speed(SPEED)
	var offers := 0
	var saw_place := false
	var t0 := Time.get_ticks_msec()
	while not b.case_run.finished and (Time.get_ticks_msec() - t0) / 1000.0 < 240.0:
		await get_tree().process_frame
		if b.case_run.bark._place_t >= 0.0:
			saw_place = true
		match b.state:
			VDBattle.State.PLACEMENT:
				if not b._spawning:
					b.start_battle()
			VDBattle.State.CHOOSE_PATH:
				if b.exits.size() > 0:
					b.choose_path(0)
		if b.relic_hud.has_offer() and not b.relic_hud.offer_ids().is_empty():
			offers += 1
			b.relic_hud.pick(String(b.relic_hud.offer_ids()[0]))
			await _wait(0.8)
	_check(b.case_run.finished, "run finishes (stage %d, rooms %d)" % [b.stage, int(b.case_run.stats["rooms"])])
	_check(int(b.case_run.stats["rooms"]) == 5, "5 rooms cleared")
	_check(saw_place, "place card shown")
	_check(offers >= 3, "relic offers every non-boss room (%d)" % offers)
	_check(b.case_run.bark.said.size() >= 6, "barks spoken (%d)" % b.case_run.bark.said.size())
	_check(b.case_run.coach.shown.has("place") and b.case_run.coach.shown.has("ult"), "coach hints shown %s" % str(b.case_run.coach.shown))
	_check(GameSave.is_cleared("harin") and GameSave.sessions("harin") == 1, "save records clear")
	_check(GameSave.postcards().has("harin"), "postcard earned")
	var c1 := GameSave.crystals()
	_check(c1 == 5 * 2 + 10 + 5, "crystals = rooms*2 + clear + first clear (%d)" % c1)
	# 4) 엔딩: 마지막 문 → 기억 로그 → 반장 한마디 → 결과
	var t1 := Time.get_ticks_msec()
	var saw_dialog := 0
	var saw_log := false
	while b.case_run.result == null and (Time.get_ticks_msec() - t1) / 1000.0 < 30.0:
		await get_tree().process_frame
		var dlg := _find(b.case_run, "StoryDialog") as StoryDialog
		if dlg and not dlg.is_done():
			saw_dialog += 1
			dlg.skip()
			await _wait(0.4)
		var lg := _find(b.case_run, "VDMemoryLog") as VDMemoryLog
		if lg:
			saw_log = true
			lg._advance()
			await _wait(0.1)
	_check(saw_dialog >= 2, "door dialog + ending line played (%d)" % saw_dialog)
	_check(saw_log, "memory log played")
	_check(b.case_run.result != null, "result screen shown")
	if b.case_run.result == null:
		return _done()
	var res: VDResultScreen = b.case_run.result
	_check(bool(res.data["cleared"]) and String(res.data["postcard"]) != "" and bool(res.data["first_unlock"]), "result: cleared + postcard + first unlock")
	_check(not SceneSwitcher.esc_guard.is_null() and SceneSwitcher.esc_guard.call(), "Esc is swallowed on result screen")
	res._t = 99.0
	await _wait(0.2)
	res._emit("hub")
	await _wait(0.1)
	await _wait_until(func() -> bool: return SceneSwitcher.current_index() == 0 and not SceneSwitcher.is_loading(), 10.0, "back to hub")
	await _wait(0.3)
	# 5) 허브: 해금 · 강화
	hub = _scene()
	_check(hub._title == null and hub._dialog == null, "no title / prologue on return")
	_check(not hub._locked("upgrade") and GameSave.take_new_tabs().size() == 3, "hub tabs unlocked with NEW marks")
	for id in ["squad", "upgrade", "postcards", "lab", "case"]:
		hub._show_tab(id, false)
		await get_tree().process_frame
	_check(GameSave.take_new_tabs().is_empty(), "NEW marks clear after visiting tabs")
	hub._buy("vital")
	_check(GameSave.upgrade_level("vital") == 1 and GameSave.crystals() == c1 - 3, "upgrade bought (crystals %d)" % GameSave.crystals())
	_check(GameSave.endless_unlocked(), "endless mode unlocked after clear")
	# 6) 두 번째 다이브: 일시정지 → 전멸
	hub.dive("case")
	await _wait(0.1)
	await _wait_until(func() -> bool: return SceneSwitcher.current_index() == 1 and not SceneSwitcher.is_loading(), 15.0, "second dive")
	b = _scene() as VDBattle
	_check(b != null and b.case_run != null, "second run in case mode")
	if b == null or b.case_run == null:
		return _done()
	var knight: VDUnit = null
	for a in b.allies:
		if a.id == "knight":
			knight = a
	_check(knight != null and is_equal_approx(knight.max_hp, floorf(200.0 * 1.06)), "vital upgrade applied (knight hp %.0f)" % (knight.max_hp if knight else 0.0))
	await _wait(0.5)
	SceneSwitcher.request_lobby()
	await get_tree().process_frame
	_check(get_tree().paused and is_instance_valid(b.case_run._pause), "Esc opens pause menu and pauses")
	SceneSwitcher.request_lobby()
	await get_tree().process_frame
	_check(not get_tree().paused and SceneSwitcher.current_index() == 1, "Esc again resumes")
	await _wait_until(func() -> bool: return b.state == VDBattle.State.PLACEMENT and not b._spawning, 15.0, "placement")
	b.camera.set_game_speed(SPEED)
	b.start_battle()
	await _wait_until(func() -> bool: return b.state == VDBattle.State.BATTLE, 10.0, "battle")
	for a in b.allies:
		a.take_damage(99999.0)
	await _wait_until(func() -> bool: return b.case_run.result != null, 20.0, "defeat result")
	_check(b.state == VDBattle.State.GAMEOVER and not b._over_panel.visible, "defeat goes to result screen, not the old panel")
	if b.case_run.result:
		_check(not bool(b.case_run.result.data["cleared"]) and int(b.case_run.result.data["crystals"]) >= 1, "defeat still pays crystals (+%d)" % int(b.case_run.result.data["crystals"]))
	_check(GameSave.sessions("harin") == 2 and GameSave.last_result() == "retreat", "second session recorded as retreat")
	_done()


func _done() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("[ftue_probe] DONE  failures=%d" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)
