## 서브웨이브 · 웨이브 진행도 테스트:
##   1) 첫 웨이브: 배치 → 전투. 스테이지 진행도가 보이고, 싸우면 줄어든다 (지금 웨이브 구획 안에서만).
##   2) 첫 웨이브 적을 모두 쓰러뜨리면 다음 웨이브: "N차 웨이브!" 띠가 뜨지 않고,
##      모두 내려앉을 때까지(_sub_pending) 영웅·적 모두 움직이거나 때리지 않는다. 그동안 새 웨이브 구획은 꽉 찬 채다.
##   3) 다 내려앉으면 전투 재개: 적이 피해를 입는다.
##   godot --headless --path . res://tools/test/VDWaveProbe.tscn
##   창이 있으면 --out=DIR 에 단계별 스크린샷
extends Node

var _b: VDBattle
var _fails: Array[String] = []
var out_dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(out_dir)
	_b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(_b)
	_run()


func _run() -> void:
	await _until(func() -> bool: return _b.state == VDBattle.State.PLACEMENT and not _b._spawning, 15.0)
	_check(_b._wave_bar.visible, "wave bar visible in placement")
	_b.start_battle()
	await _until(func() -> bool: return _b.state == VDBattle.State.BATTLE, 10.0)
	await _wait(2.5)
	await _shot("wave_01_fight")
	var r1: float = _b._wave_bar._target
	_check(r1 < 0.999, "wave bar drains while fighting (%.2f)" % r1)
	_check(_b._wave_bar._wave_text == "WAVE 1/%d" % VDData.waves_in_stage(_b.stage), "label %s" % _b._wave_bar._wave_text)
	var n_w := VDData.waves_in_stage(_b.stage)
	var st1: float = _b._wave_bar._stage_target
	_check(st1 >= float(n_w - 1) / n_w - 0.001 and st1 < 0.999, "stage progress stays in wave 1 section (%.2f)" % st1)

	# 첫 웨이브 정리: 남은 적을 모두 쓰러뜨린다
	var banner_text := ""
	for e in _b.enemies.duplicate():
		if e.alive:
			e.take_damage(e.hp + 99999.0)
	await _until(func() -> bool: return _b._sub_pending, 3.0)
	_check(_b._sub_pending, "next wave pending")
	# 다음 웨이브가 내려앉는 동안: 아무도 행동하지 않는다
	await _until(func() -> bool: return _b.wave_in_stage == 2 and _b.enemies.size() > _b._wave_from, 5.0)
	var cells := {}
	for a in _b.allies:
		cells[a] = a.cell
	var hp_sum := func() -> float:
		var s := 0.0
		for i in range(_b._wave_from, _b.enemies.size()):
			s += _b.enemies[i].hp
		return s
	var ally_hp := func() -> float:
		var s := 0.0
		for a in _b.allies:
			s += a.hp
		return s
	var a_hp0: float = ally_hp.call()
	await _wait(0.4)
	await _shot("wave_02_landing")
	var still := true
	var ehp_during: float = hp_sum.call()
	while _b._sub_pending:
		for a in _b.allies:
			if a.cell != cells[a]:
				still = false
		await get_tree().process_frame
	_check(still, "heroes held still while the wave landed")
	_check(is_equal_approx(hp_sum.call(), ehp_during) or hp_sum.call() >= ehp_during, "no damage to the landing wave")
	_check(is_equal_approx(ally_hp.call(), a_hp0), "no damage to heroes while landing")
	var n := _b.enemies.size() - _b._wave_from
	_check(n > 0, "wave 2 spawned (%d)" % n)
	banner_text = _b.banner._title.text if _b.banner.is_playing() else ""
	_check(not banner_text.contains("차 웨이브"), "no wave banner")
	_check(_b._wave_bar._target > 0.95, "wave bar refilled (%.2f)" % _b._wave_bar._target)
	var st2: float = _b._wave_bar._stage_target
	_check(absf(st2 - float(n_w - 1) / n_w) < 0.05, "stage progress = waves left (%.2f)" % st2)
	await _shot("wave_03_full")
	# 재개: 싸운다
	var h0: float = hp_sum.call()
	await _wait(3.0)
	_check(hp_sum.call() < h0, "battle resumed after landing (%.0f -> %.0f)" % [h0, hp_sum.call()])
	await _shot("wave_04_resume")
	print("[wave-test] DONE fails=%d %s" % [_fails.size(), str(_fails)])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while not cond.call() and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time() / maxf(Engine.time_scale, 0.05)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _check(ok: bool, what: String) -> void:
	print("[wave-test] %s: %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)
