## 전투 화면 컨셉 작업용 캡처 (2026-11-10): VOID DEFENSE 전투에서 전투 필드(배경·바닥·프랍·유닛·이펙트·앞 안개·
## 유닛 이름/HP 바)만 빼고 UI(HUD 레이어 10 + 설정 톱니)는 그대로 둔 채, 필드 자리가 완전히 투명한 PNG 를 찍는다.
## CRT 덧판(레이어 99)은 화면 전체를 덮는 효과라 끈다. 루트 뷰포트를 VIEWPORT 스케일로 바꿔 창 크기와 무관하게 1920x1080.
## 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/UiOnlyCapture.tscn
##   → docs/ui_only/battle_ui_only.png (투명 필드) · battle_full.png (비교용 원본)
extends Node

const OUT := "res://docs/ui_only/"
const SETTLE := 2.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	call_deferred("_run")


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + name + ".png")
	return img


func _run() -> void:
	var root := get_tree().root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = Vector2i(1920, 1080)
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	while b.enemies.is_empty():
		await get_tree().process_frame
	await _wait(SETTLE)
	await _shot("battle_full")

	# 필드 숨기기: HUD(10)·조정 패널(20) 아래의 CanvasLayer 와 월드(Node2D) 자식 전부
	for c in b.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer < 10:
			c.visible = false
		elif c is CanvasItem and not (c is Control):
			c.visible = false
	SceneSwitcher.crt.visible = false
	root.transparent_bg = true
	for i in 3:
		await get_tree().process_frame
	var img := await _shot("battle_ui_only")
	var clear := 0
	var total := img.get_width() * img.get_height()
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			if img.get_pixel(x, y).a < 0.01:
				clear += 1
	print("[ui-only] size=%s transparent=%.1f%%" % [img.get_size(), 100.0 * clear / (total / 16.0)])
	get_tree().quit(0)
