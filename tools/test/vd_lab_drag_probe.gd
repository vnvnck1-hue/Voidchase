## 연출 연구실 '유물 투사체' 끌어 옮기기·클릭 발사 테스트 (Godot 안에서 마우스 이벤트를 주입, OS 입력 없음)
##   godot --headless --path . res://tools/test/VDLabDragProbe.tscn
## 창이 있으면 --out=DIR 에 클릭 발사 직후 스크린샷
extends Node

var _fails: Array[String] = []
var out_dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(out_dir)
	var lab: Node = load("res://scenes/void_defense/FxLab.tscn").instantiate()
	add_child(lab)
	await get_tree().process_frame
	lab._open("relic")
	lab._chk_auto.button_pressed = false
	await get_tree().create_timer(0.6).timeout
	var e: VDUnit = lab._enemies[0]
	var from_cell := e.cell
	# 빈 칸 하나 찾기 (방 안, 다른 유닛 없음)
	var dest := Vector2i(-999, -999)
	for l in VDMap.local_cells(lab.room, "E") + VDMap.local_cells(lab.room, "A"):
		var c := VDMap.to_world(lab.room, l.x, l.y)
		if c != from_cell and lab._cell_free(c, e) and (dest.x == -999 or Vector2(c).distance_to(Vector2(from_cell)) < Vector2(dest).distance_to(Vector2(from_cell))):
			dest = c
	_check(dest.x != -999, "found a free cell")
	# 끌기: 몬스터 몸통 → 빈 칸 (화면 좌표로 바꿔 주입)
	var xf: Transform2D = lab.board.get_global_transform_with_canvas()
	var start: Vector2 = xf * (e.position + Vector2(0, e._top * 0.4))
	var end: Vector2 = xf * VDData.to_screen(Vector2(dest))
	_mouse_move(start)
	_mouse_button(start, true)
	for i in 6:
		_mouse_move(start.lerp(end, (i + 1) / 6.0))
		await get_tree().process_frame
	_mouse_button(end, false)
	await get_tree().create_timer(0.5).timeout
	_check(e.cell == dest, "dragged enemy %s -> %s (now %s)" % [str(from_cell), str(dest), str(e.cell)])
	# 클릭: 움직이지 않고 눌렀다 떼면 그 몬스터에게 발사
	var fx_before: int = lab.fx_root.get_child_count()
	var at: Vector2 = xf * (e.position + Vector2(0, e._top * 0.4))
	_mouse_move(at)
	_mouse_button(at, true)
	_mouse_button(at, false)
	await get_tree().process_frame
	_check(lab.fx_root.get_child_count() > fx_before, "click fired a projectile (%d -> %d fx nodes)" % [fx_before, lab.fx_root.get_child_count()])
	if out_dir != "" and DisplayServer.get_name() != "headless":
		await get_tree().create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("lab_click_fire.png"))
	print("[lab-drag] DONE fails=%d %s" % [_fails.size(), str(_fails)])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print("[lab-drag] %s: %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _mouse_button(p: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = get_viewport().get_final_transform() * p   # 캔버스 좌표 → 창 좌표 (push_input 이 늘이기 변환을 되돌린다)
	ev.global_position = ev.position
	get_viewport().push_input(ev)


func _mouse_move(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = get_viewport().get_final_transform() * p   # 캔버스 좌표 → 창 좌표 (push_input 이 늘이기 변환을 되돌린다)
	ev.global_position = ev.position
	get_viewport().push_input(ev)
