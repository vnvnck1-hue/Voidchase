## 전투 배경 엠비언트 빛 티끌 캡처: 공허·사막·바이오 테마에서 전투 화면을 찍어 docs/ambient_motes/ 에 저장한다.
## 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/AmbientMotesCapture.tscn
## 헤드리스로 돌리면 그림 없이 개수·상승·테마 색·켜고 끄기만 확인한다.
extends Node

const OUT := "res://docs/ambient_motes/"
const CROP := Rect2i(0, 300, 420, 300)   # 1280x720 기준: 왼쪽 아래 보드 바깥 배경
var failures: Array[String] = []


func _check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
	print("[motes] %s %s" % ["PASS" if ok else "FAIL", description])


func _ready() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + name + ".png")
	var crop := img.get_region(CROP)
	crop.resize(CROP.size.x * 2, CROP.size.y * 2, Image.INTERPOLATE_LANCZOS)
	crop.save_png(OUT + "crop_" + name + ".png")


func _run() -> void:
	var headless := DisplayServer.get_name() == "headless"
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	while b.enemies.is_empty():
		await get_tree().process_frame
	var motes := b.ambient_motes
	_check(motes != null and motes.get_parent() == b.bg_rect.get_parent(), "motes live on background layer")
	_check(motes.get_index() == b.bg_rect.get_index() + 1, "motes drawn right above background")
	_check(motes._motes.size() >= 24, "mote count %d" % motes._motes.size())
	var m0: Dictionary = motes._motes[0]
	m0.pos = Vector2(400, 600); m0.age = 2.0; m0.top = -9999.0
	await get_tree().create_timer(0.5).timeout
	_check(m0.pos.y < 600.0 and m0.pos.x > 400.0, "motes rise diagonally up-right (%s)" % str(m0.pos))
	var front := b.ambient_motes_front
	_check(front != null and front.front, "front layer exists")
	var fl := front.get_parent() as CanvasLayer
	_check(fl != null and fl.layer > 0 and fl.layer < 10, "front layer above world, below HUD (layer %d)" % (fl.layer if fl else -1))
	_check(front._motes.size() >= 3 and front._motes.size() < motes._motes.size() / 4, "front is sparse (%d)" % front._motes.size())
	var waiting := 0
	for fm in front._motes:
		if fm.wait > 0.0:
			waiting += 1
	_check(waiting > 0 or front._motes.size() <= 3, "front motes appear only now and then")
	for theme in [VDWorldTheme.Kind.VOID, VDWorldTheme.Kind.DESERT, VDWorldTheme.Kind.BIO]:
		b.set_background_theme(theme, false)
		var tag := VDWorldTheme.profile(theme)
		_check(motes._palette == VDAmbientMotes.PALETTES[tag], "%s palette applied" % tag)
		await get_tree().create_timer(2.0).timeout
		# 캡처용: 앞 층 몇 개를 화면 가운데로 꺼내 둔다
		for i in front._motes.size():
			var fm: Dictionary = front._motes[i]
			fm.wait = 0.0; fm.age = 2.0
			fm.pos = Vector2(250.0 + 230.0 * i, 250.0 + 70.0 * (i % 3)) * (b.bg_rect.size.y / 720.0)
		await get_tree().create_timer(0.1).timeout
		if not headless:
			await _shot(tag)
	motes.toggle()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not motes.visible and not front.visible, "toggle off hides both layers")
	motes.toggle()
	_check(motes.visible, "toggle on shows motes")
	print("[motes] %s (%d failures)" % ["ALL PASS" if failures.is_empty() else "FAILED", failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
