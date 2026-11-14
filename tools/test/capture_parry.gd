## 패링 시스템 확인: 전투 연습장에 공허 감시자(보스)만 세우고 패링 공격을 차례로 시킨다.
##   1) 실패: 입력 없이 일격을 맞는다 (피해 + 기절)
##   2) 성공: 창 안에 try_ult(대상) → 받아침 (보스 무력화 + 반격 피해, 영웅 무피해, 궁극기 게이지 획득)
##   3) 단축키: 대상 영웅의 궁극기 키(Z X C V) 입력으로 받아침
##   4) 다른 영웅의 키는 패링이 아니다 → 일격이 들어간다
##   5) 예고 중 보스가 기절하면 취소
##   6) 스스로 쓰는지: 재사용 대기가 차면 VDEnemySkills 가 예고를 시작한다
##   헤드리스: godot --headless --path . res://tools/test/ParryCapture.tscn
##   창: --out=DIR 로 연속 프레임 저장 (컨셉 docs/parry/psd_reference.png 와 비교용)
##     godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/ParryCapture.tscn -- --out=D:/shots/parry
extends Node

var _b: VDBattle
var _fails: Array[String] = []
var out_dir := ""
var slow := 1.0                  # --slow=0.12: 연속 프레임을 찍는 동안의 게임 배속 (팟칭 구간을 촘촘히)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--slow="):
			slow = float(a.substr(7))
		if a.begins_with("--out="):
			out_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(out_dir)
	for i in VDSandbox.ENEMY_SETS.size():
		if VDSandbox.ENEMY_SETS[i][1] == ["watcher"]:
			VDSandbox._set_i = i
	VDSandbox._hp_i = 2
	VDSandbox._auto = false
	VDSandbox._enemy_fight = false
	VDBattle.sandbox_request = ["gunner", "mage", "knight", "healer"]
	_b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(_b)
	_run()


func _check(ok: bool, what: String) -> void:
	print("[parry] %s: %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## 연속 프레임: n 장을 every 프레임마다 (실제 프레임 기준 — 히트스탑·슬로모션도 그대로 찍힌다).
func _burst(tag: String, n: int, every := 1) -> void:
	for i in n:
		for k in every:
			await get_tree().process_frame
		await _shot("%s_%02d" % [tag, i])


func _hero(id: String) -> VDUnit:
	for a in _b.allies:
		if a.id == id:
			return a
	return null


func _until_idle(limit := 6.0) -> void:
	var t := 0.0
	while _b.parry.active and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(0.5)


func _run() -> void:
	var t := 0.0
	while _b.state != VDBattle.State.BATTLE and t < 10.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(0.8)
	_check(_b.enemies.size() == 1 and _b.enemies[0].id == "watcher", "watcher spawned")
	if _b.enemies.is_empty():
		_done()
		return
	var u := _b.enemies[0]
	var p := _b.parry
	var d: Dictionary = VDData.PARRY["watcher"]
	_check(u.is_boss and u.size == 2 and u.visual != null, "boss: 4 cells, art loaded (top %.0f)" % u._top)
	_check(VDData.wave_enemies(5, 3).has("gazer") and VDData.wave_enemies(10, 3).has("boss") and VDData.wave_enemies(15, 3).has("watcher"), "stage 5 = gazer, stage 10 = lord, stage 15 = watcher")
	await _shot("00_idle")

	# 1) 실패
	var h := _hero("gunner")
	var hp0 := h.hp
	_b.camera.set_game_speed(slow)
	_check(p.begin(u, h, d), "telegraph begins")
	_check(_b.frame.is_parry_marked("gunner") and u.casting, "target card highlighted, boss winding up")
	await _burst("a_tele", 40, 1)
	_b.camera.set_game_speed(1.0)
	await _burst("a_hold", 6, 4)
	await _until_idle()
	_check(p.failed == 1 and h.hp < hp0, "no input: strike lands (hp %.0f -> %.0f)" % [hp0, h.hp])
	_check(not _b.frame.is_parry_marked("gunner") and not u.casting and not p.active, "cleaned up after the strike")
	await _wait(1.2)

	# 2) 성공 (try_ult = 카드 탭과 같은 경로)
	h = _hero("mage")
	hp0 = h.hp
	h.ult = 0.0
	var boss_hp := u.hp
	p.begin(u, h, d)
	while p.active and p.t < 0.62:
		await get_tree().process_frame
	await _shot("b_before_press")
	_b.camera.set_game_speed(slow)
	_b.try_ult("mage")
	_check(p.parried == 1, "press inside the window = parry (at %.2fs of %.2fs)" % [p.t, p.window])
	await _burst("b_parry", 30, 1)
	_b.camera.set_game_speed(1.0)
	await _until_idle()
	_check(is_equal_approx(h.hp, hp0), "parried: no damage to the hero")
	_check(u.hp < boss_hp and p.last_counter > 0.0, "counter hit the boss (%.0f -> %.0f)" % [boss_hp, u.hp])
	_check(u.stun_timer > 0.0, "boss staggered (%.1fs left)" % u.stun_timer)
	_check(h.ult >= float(d["ult_gain"]) - 0.01, "hero gained ult gauge (%.0f)" % h.ult)
	await _wait(2.6)

	# 3) 단축키 (카드 순서 Z X C V: gunner mage knight healer → knight = C)
	h = _hero("knight")
	p.begin(u, h, d)
	await _wait(0.3)
	var ev := InputEventKey.new()
	ev.keycode = KEY_C
	ev.physical_keycode = KEY_C
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(p.parried == 2, "ult hotkey of the highlighted hero parries")
	await _until_idle()
	await _wait(2.6)

	# 4) 다른 영웅의 키
	h = _hero("healer")
	hp0 = h.hp
	for a in _b.allies:
		a.ult = 0.0
	p.begin(u, h, d)
	await _wait(0.3)
	_b.try_ult("knight")
	_check(p.parried == 2 and p.active, "another hero's key does not parry")
	await _until_idle()
	_check(p.failed == 2 and h.hp < hp0, "so the strike lands on the target")
	await _wait(1.2)

	# 5) 예고 중 보스 기절 → 취소
	h = _hero("gunner")
	hp0 = h.hp
	p.begin(u, h, d)
	await _wait(0.3)
	u.stun(0.6)
	await _wait(0.3)
	_check(p.cancelled == 1 and not p.active and is_equal_approx(h.hp, hp0) and not u.casting, "boss stunned mid-telegraph: cancelled")
	await _wait(1.0)

	# 6) 스스로 쓴다
	u.set_meta("parry_t", 999.0)
	var begun := p.begun
	VDSandbox._enemy_fight = true
	p.auto_parry = 0.7
	t = 0.0
	while p.begun == begun and t < 4.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	_check(p.begun == begun + 1 and int(_b.enemy_skills.cast_count.get("parry", 0)) == 1, "boss starts the parry attack on its own (%.1fs)" % t)
	await _burst("c_auto", 12, 3)
	await _until_idle()
	_check(p.parried == 3, "auto parry at 70% of the window")
	VDSandbox._enemy_fight = false
	_done()


func _done() -> void:
	VDSandbox._enemy_fight = false
	print("[parry] DONE fails=%d %s" % [_fails.size(), _fails])
	get_tree().quit(1 if _fails.size() > 0 else 0)
