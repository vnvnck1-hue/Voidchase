## 공허 응시자의 패링 공격 [월식 돌진] 확인: 전투 연습장에 응시자만 세우고 실패 → 성공 → 예고 중 기절(취소)을 차례로 시킨다.
##   예고 2초: 날개를 격렬히 퍼덕이며 대상에게서 물러난다 (거리가 벌어지는지)
##   실패   : 뿔로 돌진해 대상에게 닿는다 (피해 + 기절), 그 뒤 그 자리에서 다시 떠다닌다
##   성공   : 돌진이 대상 앞에서 막히고 튕겨 나간다 (보스 무력화 + 반격, 영웅 무피해)
##   헤드리스: godot --headless --path . res://tools/test/GazerParryCapture.tscn
##   창     : godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/GazerParryCapture.tscn -- --out=D:/shots/gazer_parry
extends Node

var _b: VDBattle
var _fails: Array[String] = []
var out_dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(out_dir)
	for i in VDSandbox.ENEMY_SETS.size():
		if VDSandbox.ENEMY_SETS[i][1] == ["gazer"]:
			VDSandbox._set_i = i
	VDSandbox._hp_i = 2
	VDSandbox._auto = false
	VDSandbox._enemy_fight = false
	VDBattle.sandbox_request = ["gunner", "mage", "knight", "healer"]
	_b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(_b)
	_run()


func _check(ok: bool, what: String) -> void:
	print("[gazer-parry] %s: %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _hero(id: String) -> VDUnit:
	for a in _b.allies:
		if a.id == id:
			return a
	return null


func _until_idle(limit := 8.0) -> void:
	var t := 0.0
	while _b.parry.active and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()


func _run() -> void:
	var t := 0.0
	while _b.state != VDBattle.State.BATTLE and t < 10.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(1.0)
	_check(_b.enemies.size() == 1 and _b.enemies[0].id == "gazer", "gazer spawned")
	if _b.enemies.is_empty():
		_done()
		return
	var u := _b.enemies[0]
	var p := _b.parry
	var d: Dictionary = VDData.PARRY["gazer"]
	_check(u.is_boss and u.size == 2 and u.floating and u._parts is VDGazerAnim, "boss: 4 cells, floating, gazer rig (top %.0f)" % u._top)
	_check(VDData.wave_enemies(5, 3).has("gazer") and float(d["window"]) == 2.0, "stage 5 boss = gazer, 2s telegraph")
	_check(absf(u.visual.scale.x) > 0.44 and _b._giant_zoom() < 0.8, "1.5x size (scale %.2f), camera pulls back (x%.2f)" % [absf(u.visual.scale.x), _b._giant_zoom()])
	await _shot("00_idle")

	# 1) 실패: 물러났다가 돌진해 들이받는다
	var h := _hero("gunner")
	var hp0 := h.hp
	_b.float_move.warp(u, h.position + Vector2(190, -20))     # 바짝 붙여 놓고 시작: 물러나는지 본다
	await _wait(0.2)
	var gap0 := u.position.distance_to(h.position)
	_check(p.begin(u, h, d), "telegraph begins")
	var gap_max := gap0
	var n := 0
	while p.active and not p._resolved:
		await get_tree().process_frame
		gap_max = maxf(gap_max, u.position.distance_to(h.position))
		n += 1
		if n % 12 == 0:
			await _shot("a_tele_%02d" % (n / 12))
	_check(gap_max > gap0 + 80.0 and _b.float_move.retreats == 1, "backs away during the telegraph (%.0f -> %.0f px)" % [gap0, gap_max])
	# 돌진: 뿔 끝이 대상 가슴에 얼마나 가까이 가는지 (창 캡처 때는 슬로모션으로 촘촘히 찍는다)
	var near := INF
	if out_dir != "":
		_b.camera.set_game_speed(0.12)
	for i in 400:            # 프레임 수가 아니라 닿을 때까지 본다 (헤드리스는 프레임이 아주 짧다)
		if i >= 30 and (near < 30.0 or not p.active):
			break
		await get_tree().process_frame
		if is_instance_valid(u) and u._parts:
			var horn: Vector2 = (u._parts as VDGazerAnim).horn_offset()
			horn.x *= -u._facing
			near = minf(near, (u.position + horn).distance_to(VDParry.chest(h)))
		if i < 14:
			await _shot("a_ram_%02d" % i)
	_b.camera.set_game_speed(1.0)
	await _until_idle()
	_check(near < 30.0, "horn reaches the target (closest %.0f px)" % near)
	_check(p.failed == 1 and h.hp < hp0, "no input: ram lands (hp %.0f -> %.0f)" % [hp0, h.hp])
	_check(not u.casting and not p.active, "cleaned up after the ram")
	await _wait(1.6)
	_check(u.position.distance_to(u.float_pos) < 80.0, "floats again from where it landed")
	await _shot("a_after")

	# 2) 성공: 창 안에서 누른다 → 돌진이 막히고 보스가 무력화된다
	h = _hero("knight")
	hp0 = h.hp
	var boss_hp := u.hp
	p.begin(u, h, d)
	await _wait(0.5)
	var ult0 := h.ult
	_b.try_ult("knight")
	_check(p.early == 1 and p.parried == 0 and p.active and h.ult == ult0, "too early (%.2fs < %.2fs): swallowed, no parry, ult not spent" % [p.t, p.press_from()])
	while p.active and p.t < p.press_from() + 0.15:
		await get_tree().process_frame
	await _shot("b_before_press")
	if out_dir != "":
		_b.camera.set_game_speed(0.12)
	_b.try_ult("knight")
	_check(p.parried == 1 and p.t >= p.press_from(), "press inside the last %.2fs = parry (at %.2fs of %.2fs)" % [float(d["press"]), p.t, p.window])
	for i in 16:
		await get_tree().process_frame
		await _shot("b_clash_%02d" % i)
	_b.camera.set_game_speed(1.0)
	await _until_idle()
	_check(h.hp == hp0, "parried: hero unhurt")
	_check(u.hp < boss_hp and u.stun_timer > 0.0, "boss countered (%.0f) and staggered" % p.last_counter)
	await _shot("b_stunned")
	await _wait(3.2)

	# 3) 예고 중 기절 → 취소
	h = _hero("mage")
	hp0 = h.hp
	p.begin(u, h, d)
	await _wait(1.3)
	_b.try_ult("mage")
	await _wait(0.3)
	_b.try_ult("mage")          # 창은 열렸지만(1.55초~) 방금 일찍 눌러 아직 잠겨 있다
	_check(p.early == 2 and p.parried == 1 and p.active, "early press locks input for a moment (mashing does not parry)")
	u.stun(0.5)
	await _wait(0.2)
	_check(p.cancelled == 1 and not p.active and h.hp == hp0, "stunned mid-telegraph: cancelled")
	await _wait(1.0)

	# 4) 별은 예비 동작이 끝나고 일격 직전에만 뜬다
	h = _hero("gunner")
	var cues0 := p.cues
	p.begin(u, h, d)
	await _wait(0.8)
	_check(p.cues == cues0 and not is_instance_valid(p._tele), "no star during the wind-up (0.8s of %.2fs)" % p.window)
	while p.active and p.t < p.press_from() + 0.05:
		await get_tree().process_frame
	_check(p.cues == cues0 + 1 and is_instance_valid(p._tele), "star pops when the strike is cast (%.2fs)" % p.t)
	_b.try_ult("gunner")
	await _until_idle()
	_check(p.parried == 2, "press on the star = parry")
	await _wait(3.0)

	# 5) 두 번째 패링 공격: 만안 섬광 (제자리에서 광선)
	var gz: VDGazerSkills = _b.enemy_skills.gazer
	h = _hero("knight")
	hp0 = h.hp
	var pos0 := u.position
	_check(p.begin(u, h, VDData.GAZER["beam"]) and p._beam and not p._ram, "second parry attack (beam) begins")
	await _wait(0.6)
	await _shot("c_beam_charge")
	await _until_idle()
	_check(p.failed == 2 and h.hp < hp0 and u.position.distance_to(pos0) < 120.0, "beam: no input = hit, boss stays put")
	await _shot("c_beam_fail")
	await _wait(1.6)
	h = _hero("mage")
	boss_hp = u.hp
	p.begin(u, h, VDData.GAZER["beam"])
	p.auto_parry = 0.92
	if out_dir != "":
		while p.active and p.t < p.press_from() + 0.2:
			await get_tree().process_frame
		await _shot("c_beam_star")
	await _until_idle()
	p.auto_parry = -1.0
	_check(p.parried == 3 and u.hp < boss_hp and u.stun_timer > 0.0, "beam parried: reflected, boss staggered")
	await _shot("c_beam_ok")
	await _wait(3.0)

	# 6) 나머지 세 패턴
	for name in ["barrage", "gale", "sweep"]:
		for a in _b.allies:
			if not a.alive:
				a.revive(1.0)
			a.hp = a.max_hp
		_check(gz.cast(u, name), "%s casts" % name)
		var shots := 0
		var tt := 0.0
		while is_instance_valid(u) and u.casting and tt < 6.0:
			await get_tree().process_frame
			tt += get_process_delta_time()
			shots += 1
			if out_dir != "" and shots % 14 == 0 and shots <= 14 * 6:
				await _shot("d_%s_%02d" % [name, shots / 14])
		_check(not u.casting and tt < 6.0, "%s finishes (%.1fs)" % [name, tt])
		await _wait(1.2)
	_check(gz.gale_hits >= 1, "gale lifted heroes (%d)" % gz.gale_hits)
	_check(gz.feather_hits + gz.sweep_hits >= 1, "feathers %d · sweep %d hits" % [gz.feather_hits, gz.sweep_hits])

	# 7) 스스로 다섯 패턴을 돌려 쓰는지
	for a in _b.allies:
		a.hp = a.max_hp
	VDSandbox._enemy_fight = true
	p.auto_parry = 0.95
	u.set_meta("gz_t", 999.0)
	var seen := {}
	t = 0.0
	while seen.size() < 5 and t < 60.0 and is_instance_valid(u) and u.alive:
		await get_tree().process_frame
		t += get_process_delta_time()
		if gz.last != "":
			seen[gz.last] = true
		if not u.casting and not p.active:
			u.set_meta("gz_t", 999.0)        # 기다리지 않고 바로 다음 패턴
		for a in _b.allies:
			a.hp = a.max_hp
	_check(seen.size() == 5, "rotates through all five patterns on its own (%s in %.0fs)" % [seen.keys(), t])
	VDSandbox._enemy_fight = false
	_done()


func _done() -> void:
	VDSandbox._enemy_fight = false
	print("[gazer-parry] %s" % ("ALL OK" if _fails.is_empty() else "FAILED: " + ", ".join(_fails)))
	get_tree().quit(0 if _fails.is_empty() else 1)
