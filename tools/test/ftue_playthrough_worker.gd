## FTUE 실제 속도 플레이스루 (창 필요, 약 13분): 치트·배속 없이 사람이 읽고 누르는 박자로 처음부터 의뢰 완료까지.
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/FtuePlaythrough.tscn
## 남기는 것: docs/ftue/playthrough/timeline.txt (언제 무엇이 떴는지) + 주요 순간·25초 간격 화면.
## 조작 박자: 대사는 1.9초에 한 줄, 배치는 안내를 읽고 5초 뒤 시작, 유물은 3초 보고 고른 뒤 2초 뒤 끼움, 갈림길 2.5초,
##   궁극기는 첫 안내를 3초 본 뒤부터 차는 대로(자동 조준). 임시 세이브.
extends Node

const SAVE := "user://ftue_playthrough_save.cfg"
const OUT := "res://docs/ftue/playthrough"

var _t0 := 0
var _lines: PackedStringArray = []
var _n := 0
var _last_shot := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run()


func _now() -> float:
	return (Time.get_ticks_msec() - _t0) / 1000.0


func _log(what: String) -> void:
	var s := "%02d:%04.1f  %s" % [int(_now()) / 60, fmod(_now(), 60.0), what]
	_lines.append(s)
	print("[playthrough] " + s)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	_last_shot = _now()
	var name := "%02d_%04ds_%s.png" % [_n, int(_now()), tag]
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT.path_join(name)))
	_log("  [shot] " + name)


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await get_tree().process_frame


func _find(root: Node, script_class: String) -> Node:
	for c in root.get_children():
		var s: Script = c.get_script()
		if s != null and s.get_global_name() == script_class and not c.is_queued_for_deletion():
			return c
		var r := _find(c, script_class)
		if r:
			return r
	return null


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	GameSave.use_path(SAVE)
	await _wait(0.3)
	SceneSwitcher.go_lobby()
	await _wait(0.1)
	while SceneSwitcher.is_loading():
		await get_tree().process_frame
	_t0 = Time.get_ticks_msec()
	_log("앱 시작: 타이틀")
	var hub := get_tree().current_scene
	await _wait(3.2)
	await _shot("title")
	await _key(KEY_SPACE)
	_log("입력: 아무 키 (접속)")
	while hub._dialog == null:
		await get_tree().process_frame
	_log("프롤로그 시작")
	while hub._dialog != null and not hub._dialog.is_done():
		await _wait(1.9)
		if hub._dialog and not hub._dialog.is_done():
			await _key(KEY_SPACE)
			await _key(KEY_SPACE)
	_log("프롤로그 끝 → 다이브")
	while not (SceneSwitcher.current_index() == 1 and not SceneSwitcher.is_loading()):
		await get_tree().process_frame
	_log("전투 화면 도착 (로딩·전환 끝)")
	var b := get_tree().current_scene as VDBattle
	var cr: VDCaseRun = b.case_run
	b.auto_ult = false
	var said := 0
	var hinted := 0
	var last_state := -1
	var state_since := 0.0
	var offer_since := -1.0
	var tray_since := -1.0
	var boss_seen := false
	var ult_hint_at := -1.0
	var first_input := true
	while not cr.finished and _now() < 1500.0:
		await get_tree().process_frame
		while said < cr.bark.said.size():
			_log("말풍선: " + cr.bark.said[said])
			said += 1
		while hinted < cr.coach.shown.size():
			_log("코치: " + cr.coach.shown[hinted])
			if cr.coach.shown[hinted] == "ult":
				ult_hint_at = _now()
			hinted += 1
			await _wait(0.9)
			await _shot("coach_" + cr.coach.shown[hinted - 1])
		if b.state != last_state:
			last_state = b.state
			state_since = _now()
			_log("상태: %s (방 %d, 웨이브 %d)" % [VDBattle.State.keys()[b.state], b.stage, b.wave_in_stage])
			if b.state == VDBattle.State.CHOOSE_PATH and b.exits.size() >= 2:
				await _wait(1.2)
				await _shot("choose_path")
		if ult_hint_at > 0.0 and _now() - ult_hint_at > 3.0:
			b.auto_ult = true
		match b.state:
			VDBattle.State.PLACEMENT:
				# 첫 방은 안내 두 줄을 읽을 시간, 그 뒤로는 5초
				var need := 12.0 if b.stage == 1 else 5.0
				if not b._spawning and _now() - state_since > need and not b.relic_hud.has_offer():
					if first_input:
						first_input = false
						await _shot("before_first_battle")
					await _key(KEY_SPACE)
					_log("입력: Space (배치 완료)")
					await _wait(0.3)
			VDBattle.State.CHOOSE_PATH:
				if b.exits.size() > 0 and _now() - state_since > 2.5 and not b.relic_hud.has_offer():
					b.choose_path(0)
					_log("입력: 길 선택")
		# 유물 3택1
		if b.relic_hud.has_offer() and not b.relic_hud.offer_ids().is_empty():
			if offer_since < 0.0:
				offer_since = _now()
				_log("유물 3택1 등장")
			elif _now() - offer_since > 3.0:
				await _shot("relic_offer")
				var id := String(b.relic_hud.offer_ids()[0])
				b.relic_hud.pick(id)
				_log("입력: 유물 선택 " + id)
				offer_since = -1.0
				await _wait(0.8)
		# 보관함 → 성좌판 (2초 뒤)
		if b.state != VDBattle.State.BATTLE and not b.relic_board.tray.is_empty() and not b.relic_hud.has_offer():
			if tray_since < 0.0:
				tray_since = _now()
			elif _now() - tray_since > 2.0:
				_place(b)
				tray_since = -1.0
		if not boss_seen:
			for e in b.enemies:
				if is_instance_valid(e) and e.is_boss and e.alive and e.visible:
					boss_seen = true
					_log("보스 등장: " + b._lbl_boss.text)
					await _wait(1.5)
					await _shot("boss")
		if _now() - _last_shot > 25.0:
			await _shot("room%d" % b.stage)
	var alive := 0
	for a in b.allies:
		if a.alive:
			alive += 1
	_log("런 끝: 정리한 방 %d · 생존 %d · 처치 %d" % [int(cr.stats["rooms"]), alive, int(cr.stats["kills"])])
	# 엔딩 → 결과
	var seen_log := 0
	while cr.result == null and _now() < 1700.0:
		await get_tree().process_frame
		var dlg := _find(cr, "StoryDialog") as StoryDialog
		if dlg and not dlg.is_done():
			await _wait(2.2)
			if _n < 90:
				await _shot("ending_dialog")
			if is_instance_valid(dlg) and not dlg.is_done():
				await _key(KEY_SPACE)
				await _key(KEY_SPACE)
			continue
		var lg := _find(cr, "VDMemoryLog") as VDMemoryLog
		if lg:
			await _wait(3.4)
			seen_log += 1
			await _shot("memory_log_%d" % seen_log)
			await _key(KEY_SPACE)
	if cr.result:
		_log("결과 화면")
		while not cr.result.ready_for_input():
			await get_tree().process_frame
		_log("결과: 버튼 열림")
		await _wait(1.5)
		await _shot("result")
		await _key(KEY_SPACE)
		_log("입력: Space (상담소로)")
		while not (SceneSwitcher.current_index() == 0 and not SceneSwitcher.is_loading()):
			await get_tree().process_frame
		await _wait(2.5)
		_log("허브 복귀")
		await _shot("hub_return")
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT.path_join("timeline.txt")), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("[playthrough] DONE")
	get_tree().quit()


func _place(b: VDBattle) -> void:
	var board := b.relic_board
	var i := 0
	var guard := 0
	while i < board.tray.size() and guard < 40:
		guard += 1
		var done := false
		for c: Vector2i in board.cells:
			if board.is_slot(i):
				if board.can_unlock(c) and board.unlock_from_tray(i, c):
					done = true
					break
			elif board.relic_at(c) == "" and board.can_place(c) and board.place_from_tray(i, c):
				done = true
				break
		if not done:
			i += 1
	_log("입력: 보관함 조각을 성좌판에 끼움")
