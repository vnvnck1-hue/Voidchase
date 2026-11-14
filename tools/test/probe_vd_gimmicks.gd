## 기믹 무리·웨이브·성장 자동 테스트 (2026-11-08 TrioChess 이식분).
## 기믹 6종을 차례로 강제(force_gimmick)해 새 판을 돌리고, 스테이지(웨이브 2개)를 치우는 동안
##   구성이 팩 그대로인지 · 적 HP 바가 교전 때 붙는지 · 서브웨이브가 이어지는지 · 각 기믹 행동 횟수(도약·질주·분열·부활·무적 명중)
##   · 처치 경험치로 레벨이 오르는지 · SP 로 스킬을 올리면 수치가 바뀌는지 를 확인한다.
##   godot --headless --path . res://tools/test/VDGimmickProbe.tscn -- --speed=6
##   godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/VDGimmickProbe.tscn -- --out=D:/shots --speed=2
## --gimmicks=a,b 로 일부만 돌릴 수 있다. 창이 있으면 기믹마다 배치(스킬창 열림)·전투 장면을 저장한다.
extends Node

var speed := 6.0
var timeout := 90.0            # 기믹 하나당 실제 초
var out_dir := ""
var gimmicks: Array = []

var _b: VDBattle
var _fails: Array[String] = []
var _subwaves := 0
var _quitting := false


func _ready() -> void:
	gimmicks = VDData.GIMMICK_ORDER.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--speed="):
			speed = float(a.substr(8))
		elif a.begins_with("--timeout="):
			timeout = float(a.substr(10))
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(out_dir)
		elif a.begins_with("--gimmicks="):
			gimmicks = Array(a.substr(11).split(","))
	_b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(_b)
	_b.subwave_cleared.connect(func(_w: int) -> void: _subwaves += 1)
	Engine.time_scale = speed
	print("[gimmick-test] ready  speed=%.1f gimmicks=%s headless=%s" % [speed, str(gimmicks), str(_is_headless())])
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(0.3).timeout
	_test_growth_api()
	for g in gimmicks:
		await _run_gimmick(String(g))
	print("[gimmick-test] subwaves=%d  growth=%s" % [_subwaves, str(_b.growth.count)])
	if _subwaves < 1:
		_fails.append("no subwave cleared")
	if int(_b.growth.count["levels"]) < 1:
		_fails.append("no level up")
	_finish()


## 성장 API: SP 를 쥐여 주고 스킬을 올리면 고유 스킬·유닛 수치가 바뀌어야 한다.
func _test_growth_api() -> void:
	var g = _b.growth
	var k: VDUnit = g.unit_of("knight")
	var base_dmg: float = VDData.SKILLS["knight"]["dmg"]
	var base_hp := k.max_hp
	g.data["knight"]["sp"] = 3
	_check(g.upgrade("knight", 0), "upgrade assault_mastery")
	_check(is_equal_approx(float(g.skill_def("knight")["dmg"]), base_dmg * 1.25), "skill_def dmg x1.25 (got %.3f)" % float(g.skill_def("knight")["dmg"]))
	_check(g.upgrade("knight", 2), "upgrade iron_wall")
	_check(is_equal_approx(k.dmg_reduce, 0.05), "knight dmg_reduce 0.05 (got %.3f)" % k.dmg_reduce)
	_check(g.upgrade("knight", 3), "upgrade vitality")
	_check(is_equal_approx(k.max_hp, base_hp + 30.0), "knight max_hp +30 (got %.0f -> %.0f)" % [base_hp, k.max_hp])
	_check(not g.upgrade("knight", 0), "no SP left -> upgrade refused")
	_check(g.sp_of("knight") == 0, "sp spent")
	g.data["gunner"]["sp"] = 1
	_check(g.upgrade("gunner", 2), "upgrade rapid_fire")
	var gu: VDUnit = g.unit_of("gunner")
	_check(is_equal_approx(gu.atk_cd_mult(), 1.0 / 1.06), "gunner atk_cd_mult 1/1.06 (got %.3f)" % gu.atk_cd_mult())
	# 궁극기 숙련: 마법사 번개 군주 2레벨 → 튕김 +1
	g.data["mage"]["sp"] = 2
	g.upgrade("mage", 1)
	g.upgrade("mage", 1)
	_check(int(g.ult_def("mage")["bounces"]) == int(VDData.ULTS["mage"]["bounces"]) + 1, "mage ult bounces +1 at Lv2 (got %d)" % int(g.ult_def("mage")["bounces"]))
	# 스킬창: 열고 닫기
	_b.skill_window.open("knight")
	_check(_b.skill_window.visible and _b.skill_window.hero == "knight", "skill window opens")
	_b.skill_window.close()
	_check(not _b.skill_window.is_open, "skill window closes")   # 닫힘 연출 동안은 visible 이 남는다
	print("[gimmick-test] growth api checked  knight=%s" % str(g.data["knight"]))


func _run_gimmick(g: String) -> void:
	print("[gimmick-test] ===== %s" % g)
	_b.force_gimmick = g
	_b.restart()
	var t0 := Time.get_ticks_msec()
	# 배치 단계: 적 선등장이 끝날 때까지
	while _b.state != VDBattle.State.PLACEMENT or _b._spawning:
		await get_tree().process_frame
		if _elapsed(t0) > timeout:
			_fails.append("%s: placement timeout" % g)
			return
	var pack: Array = VDData.GIMMICKS[g]["pack"]
	var ids := _b.enemies.map(func(e: VDUnit) -> String: return e.id)
	ids.sort()
	var want := pack.duplicate()
	want.sort()
	_check(ids == want, "%s: pack spawned %s" % [g, str(ids)])
	_check(_b.is_gimmick_wave(), "%s: is_gimmick_wave" % g)
	var bars_hidden := _b.enemies.all(func(e: VDUnit) -> bool: return not e.show_bar)
	_check(bars_hidden, "%s: enemy bars hidden during placement" % g)
	if g == "illusionist":
		_check(_b.enemies.filter(func(e: VDUnit) -> bool: return e.id == "illusion").all(func(e: VDUnit) -> bool: return e.ghostly), "illusions ghostly")
	_b.skill_window.open("gunner")
	if out_dir != "":
		await get_tree().create_timer(0.5).timeout   # 스킬창 열림 트윈(실제 0.3초)이 끝난 뒤
	await _shot("%s_01_placement" % g)
	_b.skill_window.close()
	var before: Dictionary = _b.gimmicks.count.duplicate()
	var levels_before: int = _b.growth.count["levels"]
	_b.start_battle()
	var shot_battle := false
	var shot_sub := false
	var first_wave := _b.wave_in_stage
	while _b.state != VDBattle.State.TRANSITION and _b.state != VDBattle.State.GAMEOVER:
		await get_tree().process_frame
		if _b.state == VDBattle.State.BATTLE:
			if not shot_battle and _b.enemies.size() > 0:
				var bars_on := _b.enemies.all(func(e: VDUnit) -> bool: return e.show_bar or not e.alive)
				_check(bars_on, "%s: enemy bars on in battle" % g)
				shot_battle = true
				await get_tree().create_timer(1.2).timeout
				await _shot("%s_02_battle" % g)
			if not shot_sub and _b.wave_in_stage > first_wave:
				shot_sub = true
				await get_tree().create_timer(1.0).timeout
				await _shot("%s_03_subwave" % g)
		if _elapsed(t0) > timeout:
			_fails.append("%s: battle timeout (state=%s wave %d/%d alive=%d)" % [g, VDBattle.State.keys()[_b.state], _b.wave_in_stage, VDData.waves_in_stage(_b.stage), _b._alive_count(_b.enemies)])
			return
	if _b.state == VDBattle.State.GAMEOVER:
		_fails.append("%s: game over" % g)
		return
	var c: Dictionary = _b.gimmicks.count
	var d := {}
	for k in c:
		d[k] = int(c[k]) - int(before.get(k, 0))
	print("[gimmick-test] %s cleared in %.1fs  counts=%s  levels+%d" % [g, _elapsed(t0), str(d), int(_b.growth.count["levels"]) - levels_before])
	match g:
		"assassin_raid":
			_check(d["blink"] >= 1, "assassin blinked (%d)" % d["blink"])
		"sprinter_raid":
			_check(d["dash"] >= 1, "sprinter dashed (%d)" % d["dash"])
		"splitter_raid":
			_check(d["split"] >= 4, "splitters split (%d)" % d["split"])
		"hydra":
			_check(d["revive"] >= 1, "hydra revived (%d)" % d["revive"])
			_check(d["hydra_clear"] >= 1, "hydra cleared together (%d)" % d["hydra_clear"])
		"illusionist":
			_check(d["immune_hits"] >= 1, "illusion immune hits (%d)" % d["immune_hits"])
	await _shot("%s_04_clear" % g)
	_b.force_gimmick = ""


func _check(ok: bool, what: String) -> void:
	if ok:
		print("[gimmick-test] ok   " + what)
	else:
		print("[gimmick-test] FAIL " + what)
		_fails.append(what)


func _elapsed(t0: int) -> float:
	return (Time.get_ticks_msec() - t0) / 1000.0


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _shot(name: String) -> void:
	if _is_headless() or out_dir == "":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("[gimmick-test] shot " + path)


func _finish() -> void:
	if _quitting:
		return
	_quitting = true
	if _fails.is_empty():
		print("[gimmick-test] PASS")
	else:
		print("[gimmick-test] FAIL x%d:\n  %s" % [_fails.size(), "\n  ".join(_fails)])
	get_tree().quit(0 if _fails.is_empty() else 1)
