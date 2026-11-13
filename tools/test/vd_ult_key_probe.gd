## 궁극기 단축키(Z X C V = 분대 카드 순서) 확인: 키 입력을 고도 안에서 넣어(Input.parse_input_event) 시전·조준·취소·전환을 본다.
##   godot --headless --path . res://tools/test/VDUltKeyProbe.tscn
##   창: godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/VDUltKeyProbe.tscn -- --out=D:/shots
extends Node

var out_dir := "user://vd_ult_key_probe"
var _b: VDBattle
var _fails: Array[String] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	_b.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_b)
	_run()


func _run() -> void:
	await _wait(1.0)
	# 배치 단계: 단축키는 아무 일도 하지 않는다
	await _key(KEY_C)
	_check(not _b.ult.active and _b.state != VDBattle.State.BATTLE, "placement: key ignored")
	_b.start_battle()
	while _b.state != VDBattle.State.BATTLE:
		await get_tree().process_frame
	for e in _b.enemies:
		e.max_hp *= 30.0
		e.hp = e.max_hp
	await _wait(1.6)
	_check(VDData.HERO_ORDER == ["gunner", "mage", "knight", "healer"], "hero order z=gunner x=mage c=knight v=healer")
	# 게이지가 안 찼으면 거절 (시전 없음)
	await _key(KEY_C)
	_check(not _b.ult.active and _casts("knight") == 0, "C with empty gauge: denied")
	# C: 기사 (조준 없음) → 바로 시전
	_fill("knight")
	await _key(KEY_C)
	await _wait_real(0.3)
	_check(_b.ult.active or _casts("knight") >= 1, "C casts knight ult")
	await _wait_ult_done()
	_check(_casts("knight") == 1, "knight cast once")
	# V: 힐러
	_fill("healer")
	await _key(KEY_V)
	await _wait_ult_done()
	_check(_casts("healer") == 1, "V casts healer ult")
	# Z: 건너 조준 열림 → Z 다시 = 취소 (게이지 유지)
	_fill("gunner")
	await _key(KEY_Z)
	_check(_b.ult_aim.active and _b.ult_aim.caster.id == "gunner" and get_tree().paused, "Z opens gunner aim")
	await _wait_real(0.3)
	await _shot("01_gunner_aim_hint")
	await _key(KEY_Z)
	_check(not _b.ult_aim.active and not get_tree().paused and _hero("gunner").ult_full(), "Z again cancels, gauge kept")
	# Z 조준 중 X(준비 안 됨) = 그대로 / X(준비됨) = 마법사 조준으로 전환
	await _key(KEY_Z)
	await _key(KEY_X)
	_check(_b.ult_aim.active and _b.ult_aim.caster.id == "gunner", "X not ready: stays on gunner aim")
	_fill("mage")
	await _key(KEY_X)
	_check(_b.ult_aim.active and _b.ult_aim.caster.id == "mage" and get_tree().paused, "X ready: switches to mage aim")
	# 조준 중 C(조준 없는 궁극기) = 조준을 닫고 바로 시전
	_fill("knight")
	await _key(KEY_C)
	await _wait_real(0.3)
	_check(not _b.ult_aim.active and (_b.ult.active or _casts("knight") == 2), "C during aim: casts knight")
	await _wait_ult_done()
	_check(_hero("mage").ult_full() and _hero("gunner").ult_full(), "mage/gunner gauge kept")
	# 조준 → 클릭 시전
	await _key(KEY_X)
	var e := _b._nearest(_hero("mage"), _b.enemies)
	_b.ult_aim.mouse_override = get_viewport().get_canvas_transform() * _b._chest(e)
	_b.ult_aim._update_target()
	_b.ult_aim.press(_b.ult_aim.mouse_override)
	_b.ult_aim.mouse_override = null
	await _wait_ult_done()
	_check(_casts("mage") == 1, "X + click casts mage ult")
	# Ctrl+Z 는 단축키가 아니다
	await _key(KEY_Z, true)
	_check(not _b.ult_aim.active, "Ctrl+Z ignored")
	await _wait_real(0.4)
	await _shot("02_cards_keycaps")
	print("[ult-key-probe] casts=%s" % str(_b.ults.cast_count))
	print("[ult-key-probe] %s  fails=%s" % ["OK" if _fails.is_empty() else "FAIL", str(_fails)])
	get_tree().paused = false
	get_tree().quit(0 if _fails.is_empty() else 1)


func _casts(id: String) -> int:
	return int(_b.ults.cast_count.get(id, 0))


func _hero(id: String) -> VDUnit:
	for a in _b.allies:
		if a.id == id:
			return a
	return null


func _fill(id: String) -> void:
	_hero(id).gain_ult(VDData.MAX_ULT)


func _key(code: Key, ctrl := false) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		ev.ctrl_pressed = ctrl
		Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame


func _check(ok: bool, what: String) -> void:
	print("[ult-key-probe] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout


func _wait_real(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _wait_ult_done() -> void:
	await _wait_real(0.2)
	while _b.ult.active or get_tree().paused:
		await get_tree().process_frame
	await _wait_real(1.6)


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("[ult-key-probe] shot " + name)
