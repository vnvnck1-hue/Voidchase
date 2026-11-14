## 연출 연구실 "패링" 모드 + VFX 쇼룸 패링 항목 확인
##   1) 연구실: 패링을 열면 감시자·기사가 서고 조절값 줄이 뜬다 → 성공·실패를 한 번씩 재생 (예고 별·카드 강조·폭발이 생겼다 치워진다)
##   2) 조절값이 실제로 먹는지: 별 크기를 바꾸면 예고 별 배율이 따라온다 (끝나면 되돌림, 저장하지 않음)
##   3) 쇼룸: 카탈로그에 parry_fail / parry_ok 가 있고 크게 보기로 오류 없이 돈다
##   godot --headless --path . res://tools/test/ParryLabProbe.tscn
## 창이 있으면 --out=DIR 에 단계별 스크린샷
extends Node

const ParryFx := preload("res://scripts/void_defense/vd_parry_fx.gd")

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
	ParryFx.reset()      # 저장된 사용자 값과 상관없이 코드 기본값으로 (메모리에서만)
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _check(ok: bool, what: String) -> void:
	print("[parry-lab] %s: %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _telegraph() -> VDParry.Telegraph:
	for n in lab.fx_root.get_children():
		if n is VDParry.Telegraph:
			return n
	return null


func _wait_telegraph(limit := 5.0) -> VDParry.Telegraph:
	var t := 0.0
	while _telegraph() == null and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()
	return _telegraph()


func _run() -> void:
	await _wait(0.3)
	var has_mode := false
	for m in lab.MODES:
		has_mode = has_mode or m["id"] == "parry"
	_check(has_mode, "lab lists the parry mode")
	lab._target = 0
	lab._open("parry")
	lab._chk_auto.button_pressed = false
	_check(lab._enemies.size() == 2 and lab._enemies[0].id == "watcher" and lab._enemies[1].id == "knight", "watcher + knight stood")
	_check(lab._rows.has("star_scale") and lab._rows.has("ok_hitstop") and lab._rows.has("card_up"), "tunable rows built (%d)" % lab._rows.size())
	await _shot("lab_00_stage")

	# 1) 성공 → 실패
	for pass_i in 2:
		lab._target = 1 + pass_i
		lab._replay_parry()
		var tele := await _wait_telegraph()
		_check(tele != null, "%s: telegraph star appears" % lab.PARRY_TARGETS[lab._target])
		_check(lab._flame_frame.is_parry_marked("knight"), "target card highlighted")
		await _wait(0.12)
		await _shot("lab_%d0_pop" % (pass_i + 1))
		await _wait(0.4)
		await _shot("lab_%d1_hold" % (pass_i + 1))
		var t := 0.0
		while lab._flame_frame.is_parry_marked("knight") and t < 4.0:
			await get_tree().process_frame
			t += get_process_delta_time()
		await _shot("lab_%d2_resolve" % (pass_i + 1))
		await _wait(0.2)
		await _shot("lab_%d3_after" % (pass_i + 1))
		await _wait(0.9)
		_check(not lab._flame_frame.is_parry_marked("knight") and _telegraph() == null, "cleaned up (%.2fs to resolve)" % t)

	# 2) 값이 먹는지
	ParryFx.set_value("star_scale", 0.9)
	lab._target = 2
	lab._replay_parry()
	var big := await _wait_telegraph()
	_check(big != null and is_equal_approx(big.k, 0.9), "star_scale 0.9 → telegraph scale %.2f" % (big.k if big else -1.0))
	await _wait(0.5)
	await _shot("lab_30_big_star")
	ParryFx.reset()
	await _wait(1.5)
	lab._show_picker()
	await _wait(0.2)
	lab.queue_free()
	await _wait(0.2)

	# 3) 쇼룸
	var room: Control = load("res://scenes/void_defense/VfxShowroom.tscn").instantiate()
	add_child(room)
	var list: Array = room._entries_of("적 스킬")
	var at := -1
	for i in list.size():
		if list[i]["id"] == "parry_fail":
			at = i
	_check(at >= 0 and at + 1 < list.size() and list[at + 1]["id"] == "parry_ok", "showroom catalog has parry_fail + parry_ok")
	if at >= 0:
		room._show_cat("적 스킬")
		await _wait(1.0)
		room._open_focus(list, at)
		for k in 2:
			await _wait(0.75)
			await _shot("room_%d0_pop" % k)
			await _wait(0.6)
			await _shot("room_%d1_hold" % k)
			await _wait(0.75)
			await _shot("room_%d2_resolve" % k)
			await _wait(0.5)
			await _shot("room_%d3_after" % k)
			room._focus_step(1)
		room._close_focus()
	await _wait(0.3)
	print("[parry-lab] DONE fails=%d %s time_scale=%.2f" % [_fails.size(), _fails, Engine.time_scale])
	get_tree().quit(1 if _fails.size() > 0 else 0)
