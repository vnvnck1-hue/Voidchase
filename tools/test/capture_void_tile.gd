## 공허 오염 타일 · 발밑 경고 마름모가 캐릭터 아래에 깔리는지 확인하는 캡처 (2026-11-09 소팅 버그 수정 검증).
##   전투를 시작한 뒤 첫 영웅의 칸을 강제로 오염시키고 경고 마름모도 띄운 다음 그 영웅 주변을 잘라 docs/void_tile/ 에 저장한다.
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/VoidTileCapture.tscn
## 헤드리스로 돌리면 타일 레이어의 z_index 와 부모만 찍고 끝낸다.
extends Node

const OUT := "res://docs/void_tile/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var headless := DisplayServer.get_name() == "headless"
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	while b.enemies.is_empty():
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	b.start_battle()
	await get_tree().create_timer(0.6).timeout
	if b.flow == null or b.allies.is_empty():
		print("[void_tile] battle failed to build -> quit")
		get_tree().quit(1)
		return
	var a: VDUnit = b.allies[0]
	for h in b.allies:
		if h.alive and h.position.y > a.position.y:
			a = h
	b.flow._tiles[a.cell] = {"t": 1.0, "warn": false}
	b.flow._ensure_layer()
	b.ground_fx.move_child(b.flow._layer, b.ground_fx.get_child_count() - 1)
	b.flow._layer.queue_redraw()
	b.juice.telegraph(a, 3.0)
	await get_tree().create_timer(0.4).timeout
	print("[void_tile] layer z=%d parent=%s  is_void=%s" % [b.flow._layer.z_index, b.flow._layer.get_parent().name, str(b.flow.is_void(a.cell))])
	if headless:
		get_tree().quit(0)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "after_full.png")
	var p := b.camera.get_viewport_transform() * a.position if b.camera else a.position
	var r := Rect2i(Vector2i(p) - Vector2i(260, 300), Vector2i(520, 400)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png(OUT + "after_crop.png")
	print("[void_tile] saved, hero screen pos %s" % str(p))
	get_tree().quit(0)
