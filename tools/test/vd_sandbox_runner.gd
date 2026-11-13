## 전투 연습장(VDSandbox) 자동 테스트: 연습 모드로 전투를 열고
##   1) 기사 하나, 자동 전투 끔: 적이 서 있고 영웅이 스스로 움직이지 않는지 → 일반 공격·고유 스킬·궁극기 버튼 → 피해가 들어갔는지
##   2) 몬스터 끌어 옮기기(입력 주입) → 칸이 바뀌었는지, 클릭 → 대상 지정 + 공격
##   3) 4명 모두 + 자동 전투: 적이 다 쓰러지면 다시 세워지는지
##   godot --headless --path . res://tools/test/VDSandboxRunner.tscn
##   창이 있으면 --out=DIR 로 단계별 스크린샷
extends Node

var _b: VDBattle
var _fails: Array[String] = []
var out_dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(out_dir)
	VDBattle.sandbox_request = ["knight"]
	_b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(_b)
	_run()


func _check(ok: bool, what: String) -> void:
	print("[sandbox-test] %s: %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _wait_battle() -> void:
	var t := 0.0
	while _b.state != VDBattle.State.BATTLE and t < 10.0:
		await get_tree().process_frame
		t += get_process_delta_time()


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _hp_sum() -> float:
	var s := 0.0
	for e in _b.enemies:
		s += maxf(e.hp, 0.0)
	return s


func _run() -> void:
	var sb := _b.sandbox
	_check(sb != null, "sandbox created")
	_check(VDBattle.sandbox_request.is_empty(), "request consumed (normal battle next time)")
	if sb == null:
		_done()
		return
	await _wait_battle()
	_check(_b.state == VDBattle.State.BATTLE, "battle started without placement")
	_check(_b.allies.size() == 1 and _b.allies[0].id == "knight", "only the chosen hero (%d allies)" % _b.allies.size())
	_check(_b.enemies.size() == VDSandbox.ENEMY_SETS[VDSandbox._set_i][1].size(), "enemy set spawned (%d)" % _b.enemies.size())
	await _shot("sandbox_01_start")

	# 1) 자동 전투 끔 → 가만히
	sb._chk_auto.button_pressed = false
	var k := _b.allies[0]
	var cell0 := k.cell
	var hp0 := _hp_sum()
	await _wait(2.0)
	_check(k.cell == cell0 and is_equal_approx(_hp_sum(), hp0), "manual mode: hero idles, enemies untouched")
	sb.attack()
	await _wait(0.8)
	var hp1 := _hp_sum()
	_check(hp1 < hp0, "attack button dealt damage (%.0f -> %.0f)" % [hp0, hp1])
	await _shot("sandbox_02_attack")
	sb.skill()
	await _wait(0.1)
	await _shot("sandbox_03_skill")
	await _wait(1.6)
	var hp2 := _hp_sum()
	_check(hp2 < hp1 or _b.skills.cast_count.get("knight", 0) > 0, "skill button cast (count=%s)" % str(_b.skills.cast_count.get("knight", 0)))
	sb.ultimate()
	await _wait(0.5)
	await _shot("sandbox_04_ult")
	await _wait(2.5)
	_check(k.ult < VDData.MAX_ULT, "ult button cast (ult gauge spent)")

	# 2) 끌어 옮기기: 살아 있는 적 하나를 빈 칸으로
	var e: VDUnit = null
	for x in _b.enemies:
		if x.alive:
			e = x
			break
	# 마우스 이벤트 주입은 창이 있어야 위치가 맞는다 (헤드리스는 버튼 경로만 확인)
	var windowed := DisplayServer.get_name() != "headless"
	if e != null and windowed:
		# 가장 가까운 빈 칸으로 끌어 놓기 (Godot 안에서 이벤트 주입, OS 입력 없음)
		var free := Vector2i(-999, -999)
		for l in VDMap.local_cells(_b.room, "E"):
			var c := VDMap.to_world(_b.room, l.x, l.y)
			if c != e.cell and _b._fits(e, c) and (free.x == -999 or Vector2(c).distance_to(Vector2(e.cell)) < Vector2(free).distance_to(Vector2(e.cell))):
				free = c
		if free.x != -999:
			var xf: Transform2D = _b.board.get_global_transform_with_canvas()
			var start: Vector2 = xf * (e.position + Vector2(0, e._top * 0.4))
			var end: Vector2 = xf * VDData.to_screen(Vector2(free))
			_mouse_move(start)
			_mouse_button(start, true)
			for i in 6:
				_mouse_move(start.lerp(end, (i + 1) / 6.0))
				await get_tree().process_frame
			_mouse_button(end, false)
			await _wait(0.5)
			_check(e.cell == free, "dragged enemy to %s (now %s)" % [str(free), str(e.cell)])
		# 클릭 = 대상 지정 + 바로 일반 공격 (근접은 곁으로 붙어서)
		var before := e.hp
		var at: Vector2 = _b.board.get_global_transform_with_canvas() * (e.position + Vector2(0, e._top * 0.4))
		_mouse_move(at)
		_mouse_button(at, true)
		_mouse_button(at, false)
		await _wait(0.9)
		_check(sb.target == e, "click selected the target")
		_check(not is_instance_valid(e) or e.hp < before, "clicked target took the hit (%.0f -> %.0f)" % [before, e.hp])
		await _shot("sandbox_02b_click")
	elif e != null:
		sb.target = e
		var before := e.hp
		sb.attack()
		await _wait(0.9)
		_check(not is_instance_valid(e) or e.hp < before, "targeted attack hit")

	# 3) 4명 모두 + 자동 전투 → 적이 다 쓰러지면 다시 세워진다
	sb._chk_auto.button_pressed = true
	sb._set_heroes(VDData.HERO_ORDER.duplicate())
	await _wait_battle()
	_check(_b.allies.size() == 4, "4 heroes after switching (%d)" % _b.allies.size())
	Engine.time_scale = 3.0
	var t := 0.0
	var respawned := false
	var saw_clear := false
	while t < 60.0:
		await get_tree().process_frame
		t += get_process_delta_time() / Engine.time_scale
		if _b._alive_count(_b.enemies) == 0:
			saw_clear = true
		elif saw_clear and _b.state == VDBattle.State.BATTLE:
			respawned = true
			break
	Engine.time_scale = 1.0
	_check(respawned, "enemies respawned after being cleared (%.1fs)" % t)
	_check(_b.state != VDBattle.State.GAMEOVER and _b.state != VDBattle.State.CHOOSE_PATH, "no clear/game-over flow")
	await _shot("sandbox_05_auto")
	_done()


func _mouse_button(p: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = get_viewport().get_final_transform() * p   # 캔버스 좌표 → 창 좌표
	ev.global_position = ev.position
	get_viewport().push_input(ev)


func _mouse_move(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = get_viewport().get_final_transform() * p
	ev.global_position = ev.position
	get_viewport().push_input(ev)


func _done() -> void:
	print("[sandbox-test] DONE fails=%d %s" % [_fails.size(), str(_fails)])
	get_tree().quit(0 if _fails.is_empty() else 1)
