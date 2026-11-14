## 로비 → VOID DEFENSE 실제 입장 흐름(로딩 화면 → 코믹 파편 전환 → 안개 열림 → HUD 등장) 을 프레임 띄엄띄엄 찍어
## docs/transition/flow_sheet.png (6x4) 로 저장한다. current_scene 이 바뀌어도 살아남도록 루트 아래 별도 노드로 돈다.
## 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/TransitionCapture.tscn -- --flow
extends Node

const OUT := "res://docs/transition/"
const EVERY := 4           # 몇 프레임마다 한 장
const COLS := 6
const ROWS := 6
const CELL := Vector2i(480, 270)


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().create_timer(0.3).timeout
	SceneSwitcher.go_lobby()
	# 테스트 씬 → 로비도 코믹 파편 전환을 거친다: 끝나고 로비 등장 연출이 마칠 때까지 기다린다
	await get_tree().create_timer(0.1).timeout
	while SceneSwitcher.is_loading():
		await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	var vd := -1
	for i in SceneSwitcher.SCENES.size():
		if SceneSwitcher.SCENES[i]["name"] == "VoidDefense_greybox":
			vd = i
	SceneSwitcher.switch_to(vd)
	# 로딩 화면이 다 찰 때까지는 안 찍는다 (코믹 전환이 뜬 뒤부터)
	while SceneSwitcher.is_loading() and not is_instance_valid(SceneSwitcher._wipe):
		await get_tree().process_frame
	var shots: Array[Image] = []
	var n := 0
	var after_ms := -1
	var t_start := Time.get_ticks_msec()
	while shots.size() < COLS * ROWS:
		await RenderingServer.frame_post_draw
		if not SceneSwitcher.is_loading():
			if after_ms < 0:
				after_ms = Time.get_ticks_msec()
			elif Time.get_ticks_msec() - after_ms > 2600:
				break
		if n % EVERY == 0:
			shots.append(get_viewport().get_texture().get_image())
			var w: Node = SceneSwitcher._wipe
			var cs := get_tree().current_scene
			var fog := "-"
			if cs is VDBattle:
				var fr: Node = cs.fog_reveal
				fog = ("reveal %.2f" % float(fr._mat.get_shader_parameter("reveal"))) if is_instance_valid(fr) else "gone"
			print("[transition] shot %2d frame %3d t=%.2fs wipe=%s scene=%d fog=%s" % [shots.size() - 1, n, (Time.get_ticks_msec() - t_start) / 1000.0,
				("%.3f/ph%d" % [w.progress, w._phase]) if is_instance_valid(w) else "-", SceneSwitcher.current_index(), fog])
			if shots.size() - 1 in [16, 20, 30, 35]:
				shots[shots.size() - 1].save_png(OUT + "flow_%02d.png" % (shots.size() - 1))
		n += 1
	var sheet := Image.create(CELL.x * COLS, CELL.y * ROWS, false, shots[0].get_format())
	for i in shots.size():
		var f := shots[i]
		f.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(f, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (i % COLS), CELL.y * (i / COLS)))
	sheet.save_png(OUT + "flow_sheet.png")
	print("[transition] flow sheet %d frames" % shots.size())
	get_tree().quit(0)
