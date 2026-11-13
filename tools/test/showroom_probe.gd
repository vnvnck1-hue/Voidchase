## VFX 쇼룸 헤드리스 점검: 쇼룸을 띄워 전체 칸을 몇 초 돌리고, 크게 보기로 항목을 하나씩 넘기며 재생 함수가 오류 없이 도는지 본다.
##   Godot --headless --path . res://tools/test/ShowroomProbe.tscn
## 창으로 돌리면(서브 모니터) docs/vfx_showroom/ 에 전체 화면 · 분류별 · 크게 보기 캡처를 남긴다.
extends Node

const OUT := "res://docs/vfx_showroom/"


func _ready() -> void:
	var headless := DisplayServer.get_name() == "headless"
	if not headless:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var room: Control = load("res://scenes/void_defense/VfxShowroom.tscn").instantiate()
	add_child(room)
	var entries: Array = room._catalog.entries
	print("[showroom] entries=%d tiles=%d" % [entries.size(), room._tiles.size()])
	await _wait(3.0)
	await _shot(headless, "00_all_top")
	room._scroll.scroll_vertical = 100000
	await _wait(2.5)
	await _shot(headless, "01_all_bottom")
	var cats: Array = room.Catalog.CATS
	for i in cats.size():
		room._show_cat(cats[i])
		await _wait(2.2)
		await _shot(headless, "c%02d_%s" % [i, cats[i]])
	room._show_cat("전체")
	room._open_focus(room._entries_of("전체"), 0)
	for i in entries.size():
		await _wait(0.45)
		await _shot(headless, "f%02d_%s_a" % [i, entries[i]["id"]])
		await _wait(0.85)
		await _shot(headless, "f%02d_%s_b" % [i, entries[i]["id"]])
		print("[showroom] focus ok %s" % entries[i]["id"])
		room._focus_step(1)
	room._close_focus()
	await _wait(0.5)
	print("[showroom] done time_scale=%.2f" % Engine.time_scale)
	get_tree().quit()


func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await get_tree().process_frame


func _shot(headless: bool, name: String) -> void:
	if headless:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
