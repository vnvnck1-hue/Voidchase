## 연출 연구실 '몬스터 사망' · '몬스터 피격' 테스트
##   1) 사망: 적 넷이 차례로 쓰러진다 → (폭발 시트는 쓰지 않음) · 체액 · 녹아내림(투명) → 다 쓰러지면 다시 세워진다
##   2) 조절값이 실제로 먹는지: 체액 끔이면 안 나온다 (끝나면 저장값으로 되돌림)
##   3) 보스 하나 · 클릭(입력 주입) 처치
##   4) 피격: 몸 반응 세기 0 이면 찌그러지지 않는다
##   godot --headless --path . res://tools/test/VDLabKillProbe.tscn
## 창이 있으면 --out=DIR 에 단계별 스크린샷
extends Node

const KillFx := preload("res://scripts/void_defense/vd_kill_fx.gd")
const HitFx := preload("res://scripts/void_defense/vd_hit_fx.gd")

var _fails: Array[String] = []
var out_dir := ""
var lab: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(out_dir)
	lab = load("res://scenes/void_defense/FxLab.tscn").instantiate()
	add_child(lab)
	await get_tree().process_frame
	# 저장된 사용자 값(user://kill_fx.json 등)과 상관없이 코드 기본값으로 확인한다. 메모리에서만 바꾸고 저장하지 않는다
	KillFx.reset()
	HitFx.reset()
	_run()


func _run() -> void:
	await _wait(0.3)
	await _shot("kill_00_picker")
	# 1) 차례로 쓰러뜨리기
	lab._open("kill")
	var vfx: VDVfx = lab.vfx
	_check(lab._enemies.size() == 4, "4 enemies stood (%d)" % lab._enemies.size())
	# 첫 프레임들이 느려 게임 시간 타이머가 늦게 돌 수 있다: 첫 처치까지 기다린다
	var t := 0.0
	while (lab._enemies[0] as VDUnit).alive and t < 6.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(0.1)
	await _shot("kill_01_first")
	_check(int(vfx.play_count.get("kill_burst", 0)) == 0, "kill_burst never played (removed)")
	var first: VDUnit = lab._enemies[0]
	_check(not first.alive, "first enemy down")
	await _wait(0.5)
	_check(first.modulate.a < 0.05, "body faded out (a=%.2f)" % first.modulate.a)
	_check(lab.goo.puddles.size() > 0, "goo puddles (%d)" % lab.goo.puddles.size())
	t = 0.0
	while (lab._enemies[3] as VDUnit).alive and t < 6.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(0.1)
	await _shot("kill_02_all")
	var all_down := true
	for e in lab._enemies:
		all_down = all_down and not e.alive
	_check(all_down, "all four down")
	await _wait(1.8)
	var stood: bool = lab._enemies.size() == 4 and (lab._enemies[0] as VDUnit).alive
	_check(stood, "restood after all down")

	# 2) 값이 먹는지: 체액 끔
	KillFx.set_value("goo_on", 0.0)
	lab._chk_auto.button_pressed = false
	lab._replay_kill(false)
	lab._kill_unit(lab._enemies[0])
	await _wait(0.4)
	_check(lab.goo.puddles.is_empty(), "goo_on=0 → no puddles (%d)" % lab.goo.puddles.size())
	KillFx.reset()

	# 3) 보스 + 클릭 처치
	lab._target = 1
	lab._replay_kill(false)
	await _wait(0.3)
	var boss: VDUnit = lab._enemies[0]
	_check(lab._enemies.size() == 1 and boss.is_boss, "boss stood")
	var xf: Transform2D = lab.board.get_global_transform_with_canvas()
	var at: Vector2 = xf * (boss.position + Vector2(0, boss._top * 0.4))
	_mouse_move(at)
	_mouse_button(at, true)
	_mouse_button(at, false)
	await _wait(0.15)
	_check(not boss.alive, "click killed the boss")
	await _shot("kill_03_boss")
	await _wait(0.6)
	await _shot("kill_04_boss_goo")

	# 4) 피격: 몸 반응 끔
	lab._open("hit")
	lab._chk_auto.button_pressed = false
	await _wait(0.3)
	var u: VDUnit = lab._enemies[0]
	HitFx.set_value("punch_k", 0.0)
	lab._hit_unit(u, true)
	await get_tree().process_frame
	_check(u._hit_sq.distance_to(Vector2.ONE) < 0.01, "punch_k=0 → no squash (%s)" % str(u._hit_sq))
	HitFx.reset()
	await _wait(0.5)
	lab._hit_unit(u, true)
	await get_tree().process_frame
	_check(u._hit_sq.distance_to(Vector2.ONE) > 0.05, "default punch squashes (%s)" % str(u._hit_sq))
	await _shot("hit_01_punch")
	print("[lab-kill] DONE fails=%d %s" % [_fails.size(), str(_fails)])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _check(ok: bool, what: String) -> void:
	print("[lab-kill] %s: %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _mouse_button(p: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = get_viewport().get_final_transform() * p
	ev.global_position = ev.position
	get_viewport().push_input(ev)


func _mouse_move(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = get_viewport().get_final_transform() * p
	ev.global_position = ev.position
	get_viewport().push_input(ev)
