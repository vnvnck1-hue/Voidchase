## 공허 망령(중보스) 확인: 전투 연습장에 망령만 세우고 스킬·순간이동·회피·위빙 이동을 차례로 시킨다.
##   1) [공허 촉수 난타] 명중 수   2) 순간이동 → 촉수 난타 연계   3) 강공격(궁극기) 회피 / 기절 중엔 못 피함
##   4) 위빙: 타일에 묶이지 않고 떠다니는지, 밟은 칸이 위치를 따라오는지, 다른 유닛과 겹칠 수 있는지
##   헤드리스: godot --headless --path . res://tools/test/WraithSkillCapture.tscn
##   창: --out=DIR 로 슬로모션(0.25배) 연속 프레임 저장 (컨셉 assets/컨셉 원화/몬스터 스킬.psd 와 비교용)
##     godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/WraithSkillCapture.tscn -- --out=D:/shots/wraith_skill
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
		if VDSandbox.ENEMY_SETS[i][1] == ["wraith"]:
			VDSandbox._set_i = i
	VDSandbox._auto = false
	VDSandbox._enemy_fight = false
	VDBattle.sandbox_request = ["knight", "mage"]
	_b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(_b)
	_run()


func _check(ok: bool, what: String) -> void:
	print("[wraith-skill] %s: %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _ally_hp() -> float:
	var s := 0.0
	for a in _b.allies:
		s += maxf(a.hp, 0.0)
	return s


## 아군 바로 옆(가장 가까운 자리)에 세운다.
func _put_near(u: VDUnit) -> void:
	var es := _b.enemy_skills
	var near := u.cell
	for local in _b.room["cells"]:
		var at: Vector2i = VDMap.to_world(_b.room, local.x, local.y)
		if _b._fits(u, at) and es._ally_gap(u, at) < es._ally_gap(u, near):
			near = at
	_b.float_move.warp(u, u.foot_at(near))


func _run() -> void:
	var t := 0.0
	while _b.state != VDBattle.State.BATTLE and t < 10.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(0.6)
	_check(_b.enemies.size() == 1 and _b.enemies[0].id == "wraith", "wraith spawned")
	if _b.enemies.is_empty():
		_done()
		return
	var u := _b.enemies[0]
	var es := _b.enemy_skills
	var sk: Dictionary = VDData.ENEMY_SKILLS["wraith"]
	_check(u.size == 2 and u.footprint().size() == 4, "mid-boss footprint = 4 cells")
	_check(u.attack_range >= 7 and u.floating, "long range (%d), floating" % u.attack_range)
	await _shot("00_idle")

	# 평소 몸의 흔들림 폭 (광란과 비교용): 1초 동안 후드 본의 회전 범위
	var hood: Bone2D = (u._parts as VDWraithAnim)._hood
	var lo := 9.0
	var hi := -9.0
	var tt := 0.0
	while tt < 1.0:
		await get_tree().process_frame
		tt += get_process_delta_time()
		lo = minf(lo, hood.rotation)
		hi = maxf(hi, hood.rotation)
	var idle_range := rad_to_deg(hi - lo)
	lo = 9.0
	hi = -9.0

	# 1) 촉수 난타
	var hp0 := _ally_hp()
	var total := int(sk["tentacles"]) * int(sk["jabs"])
	Engine.time_scale = 0.25
	_check(es._tentacle_barrage(u, sk), "tentacle barrage cast")
	for i in 34:
		await get_tree().create_timer(0.05, true, false, false).timeout   # 게임 시간 0.05초마다
		await _shot("t%02d" % i)
		lo = minf(lo, hood.rotation)
		hi = maxf(hi, hood.rotation)
	Engine.time_scale = 1.0
	await _wait(0.9)
	_check(rad_to_deg(hi - lo) > idle_range * 3.0 and rad_to_deg(hi - lo) > 12.0, "body thrashes while casting (hood swings %.1f deg vs %.1f deg idle)" % [rad_to_deg(hi - lo), idle_range])
	_check(es.tentacle_hits == total, "tentacle hits %d / %d" % [es.tentacle_hits, total])
	_check(_ally_hp() < hp0, "allies took damage (%.0f -> %.0f)" % [hp0, _ally_hp()])
	_check(not u.casting and u.get_node_or_null("Tentacles") == null and u.z_index == 0, "tentacles cleaned up, casting ended")

	# 2) 순간이동 → 촉수 난타 연계 (확률 대신 강제)
	_put_near(u)
	await _wait(0.3)
	var cell0 := u.cell
	es.force_followup = 1
	var hits0 := es.tentacle_hits
	Engine.time_scale = 0.3
	var moved: bool = es._blink_tick(u, sk, 99.0)
	for i in 8:
		await get_tree().create_timer(0.05, true, false, false).timeout
		await _shot("b%02d" % i)
	Engine.time_scale = 1.0
	await _wait(2.6)
	var lb: Dictionary = es.last_blink
	_check(moved and u.cell != cell0 and int(lb["after"]) > int(lb["before"]), "blink: %s -> %s, ally gap %d -> %d" % [cell0, u.cell, lb.get("before", -1), lb.get("after", -1)])
	_check(es.followups == 1 and es.tentacle_hits == hits0 + total, "blink followed by tentacle barrage (%d hits)" % (es.tentacle_hits - hits0))
	_check(not u.casting and is_equal_approx(u.modulate.a, 1.0), "blink ended (visible, not casting)")
	es.force_followup = 0

	# 3) 강공격 회피
	_put_near(u)
	await _wait(0.3)
	cell0 = u.cell
	var hp := u.hp
	es.force_dodge = 1
	_b.ults._hit(u, 80.0, "burst", Color.WHITE, 0.5)
	_b.ults._hit(u, 80.0, "burst", Color.WHITE, 0.5)   # 같은 공격의 연타도 함께 피한다
	await _shot("d00_dodge")
	await _wait(0.8)
	_check(es.dodges == 1 and is_equal_approx(u.hp, hp) and u.cell != cell0, "ult hit dodged by blinking (%s -> %s, hp %.0f)" % [cell0, u.cell, u.hp])
	await _wait(0.6)
	es.force_dodge = 0
	_b.ults._hit(u, 80.0, "burst", Color.WHITE, 0.5)
	_check(u.hp < hp, "failed roll: ult hit lands (hp %.0f -> %.0f)" % [hp, u.hp])
	es.force_dodge = 1
	await _wait(1.7)   # 못 피한 뒤의 잠금이 풀릴 때까지
	u.stun(1.0)
	hp = u.hp
	_b.ults._hit(u, 40.0, "burst", Color.WHITE, 0.5)
	_check(u.hp < hp, "stunned: cannot dodge")
	es.force_dodge = 0
	await _wait(1.2)

	# 3.5) 너무 가까우면 촉수 난타를 쓰지 않고, 물러난 뒤에 쓴다
	_put_near(u)
	await _wait(0.3)
	var min_range := int(sk["min_range"])
	var gap0 := es._ally_gap(u, u.cell)
	hits0 = es.tentacle_hits
	u.set_meta("blink_t", -999.0)
	u.set_meta("eskill_t", 999.0)         # 재사용 대기는 다 찼다
	VDSandbox._enemy_fight = true          # 스스로 움직이고 스킬을 쓰게
	await get_tree().process_frame
	await get_tree().process_frame
	_check(gap0 < min_range and es.too_close > 0 and not u.casting, "too close (gap %d < %d): skill held back" % [gap0, min_range])
	var cast_gap := -1
	var waited := 0.0
	while waited < 8.0 and cast_gap < 0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if u.casting and not u.has_meta("blinking"):
			cast_gap = es._ally_gap(u, u.cell)
	_check(_b.float_move.back_offs >= 1, "backed off before casting (%d order)" % _b.float_move.back_offs)
	_check(cast_gap >= min_range and cast_gap <= min_range + 3, "cast after reaching a moderate distance (gap %d, %.1fs later)" % [cast_gap, waited])
	await _shot("m00_backed_off_cast")
	VDSandbox._enemy_fight = false
	await _wait(2.4)
	_check(es.tentacle_hits > hits0, "the delayed barrage landed (%d hits)" % (es.tentacle_hits - hits0))

	# 4) 위빙: 적이 스스로 움직이게 켜고 지켜본다 (스킬·순간이동은 멀리 미뤄 둔다)
	u.set_meta("eskill_t", -999.0)
	u.set_meta("blink_t", -999.0)
	VDSandbox._enemy_fight = true
	var path := 0.0
	var last := u.position
	var cells := {}
	var cell_ok := true
	var off_frames := 0
	var fastest := 0.0
	var overlapped := false
	var elapsed := 0.0
	var shots := 0
	while elapsed < 9.0 or (elapsed < 25.0 and (_b.float_move.fast_moves < 1 or _b.float_move.slow_moves < 1)):
		await get_tree().process_frame
		var d := get_process_delta_time()
		elapsed += d
		var step := u.position.distance_to(last)
		path += step
		fastest = maxf(fastest, step / maxf(d, 0.001))
		last = u.position
		cells[u.cell] = true
		# 밟은 칸 = 지금 떠 있는 자리의 칸 (위빙 흔들림만큼은 봐준다: 한 칸 이내)
		var here := VDFloatMove.cell_at(u, u.position)
		# 트윈은 노드 처리 뒤에 돌아 칸이 한 프레임 늦을 수 있다 → 3프레임 넘게 어긋날 때만 문제
		off_frames = off_frames + 1 if here != u.cell else 0
		if off_frames > 3:
			cell_ok = false
		for a in _b.allies:
			if a.alive and u.dist_to(a) == 0:
				overlapped = true
		if elapsed > shots * 1.5 and shots < 6:
			await _shot("w%02d" % shots)
			shots += 1
	_check(path > 250.0, "weaving: moved %.0f px in %.0fs without snapping to tiles" % [path, elapsed])
	_check(cells.size() >= 3, "tile under it follows the position (%d different cells)" % cells.size())
	_check(cell_ok, "occupied cell always matches where it floats")
	_check(_b.float_move.fast_moves >= 1 and _b.float_move.slow_moves >= 1, "both paces: fast %d, slow %d (top speed %.0f px/s)" % [_b.float_move.fast_moves, _b.float_move.slow_moves, fastest])
	_check(not _b._occupied(u.cell) or _b._unit_at(u.cell, _b.allies) != null, "does not block tiles (others may stand under it)")
	_check(_b._unit_at(u.cell, _b.enemies) == u, "still hittable through its tile")
	print("[wraith-skill] note: overlapped an ally's tile during the run = %s" % overlapped)
	# 다른 유닛과 같은 칸에 놓아도 되는지 직접 확인
	var ally := _b.allies[0]
	_b.float_move.warp(u, ally.position)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(u.dist_to(ally) == 0, "can float over an ally's tile")
	await _shot("z_overlap")
	_done()


func _done() -> void:
	VDSandbox._enemy_fight = false
	print("[wraith-skill] DONE fails=%d %s" % [_fails.size(), _fails])
	get_tree().quit(1 if _fails.size() > 0 else 0)
