## CRT 프리셋 캡처: 전투 화면(멈춘 프레임)과 로비를 프리셋마다 찍어 docs/crt/ 에 저장한다. 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/CrtCapture.tscn
##   <장면>_<번호>_<프리셋>.png : 전체 화면 · crop_<장면>_<프리셋>.png : 일부 3배 확대 · sheet_<장면>.png : 프리셋 6개 모음 · tuner_menu.png : 조정 패널+설정 메뉴
## 헤드리스로 돌리면 프리셋을 모두 적용해 보고 값 문자열만 출력한다.
extends Node

const OUT := "res://docs/crt/"
const CROP := Rect2i(720, 250, 400, 225)        # 1280x720 기준 확대할 자리 (전투: 영웅·적 근처)
const CROP_LOBBY := Rect2i(60, 180, 400, 225)   # 로비: 메뉴 글자


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var crt: CanvasLayer = SceneSwitcher.crt
	if DisplayServer.get_name() == "headless":
		for i in crt.PRESETS.size():
			crt.apply_preset(i)
			print("[crt] %s -> %s" % [crt.preset_id(), crt.values_text()])
		crt.apply_preset(0)
		get_tree().quit(0)
		return
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	while b.enemies.is_empty():
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	b.start_battle()
	await get_tree().create_timer(2.4).timeout
	get_tree().paused = true
	await _shoot("battle", CROP, crt)
	get_tree().paused = false
	b.queue_free()
	await get_tree().process_frame
	var lobby: Node = load("res://scenes/Lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(0.8).timeout
	await _shoot("lobby", CROP_LOBBY, crt)
	# 조정 패널(F7)·설정 메뉴가 CRT 위에 선명하게 뜨는지
	crt.apply_preset(2)
	SceneSwitcher._crt_tuner.toggle()
	SceneSwitcher.set_menu_open(true)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "tuner_menu.png")
	SceneSwitcher._crt_tuner.toggle()
	SceneSwitcher.set_menu_open(false)
	crt.apply_preset(0)
	print("[crt] done")
	get_tree().quit(0)


func _shoot(tag: String, crop: Rect2i, crt: CanvasLayer) -> void:
	var vp := get_viewport()
	var fulls: Array[Image] = []
	for i in crt.PRESETS.size():
		crt.apply_preset(i)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var id: String = crt.preset_id()
		img.save_png(OUT + "%s_%d_%s.png" % [tag, i, id])
		var k := float(img.get_width()) / vp.get_visible_rect().size.x
		var r := Rect2i(Vector2i(Vector2(crop.position) * k), Vector2i(Vector2(crop.size) * k))
		var z := img.get_region(r.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
		z.resize(z.get_width() * 3, z.get_height() * 3, Image.INTERPOLATE_NEAREST)
		z.save_png(OUT + "crop_%s_%s.png" % [tag, id])
		fulls.append(img)
		print("[crt] %s %s" % [tag, id])
	var cw := 640
	var ch := 360
	var cols := 3
	var rows := ceili(fulls.size() / float(cols))
	var sheet := Image.create(cw * cols, ch * rows, false, fulls[0].get_format())
	for i in fulls.size():
		var f := fulls[i]
		f.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(f, Rect2i(Vector2i.ZERO, Vector2i(cw, ch)), Vector2i(cw * (i % cols), ch * (i / cols)))
	sheet.save_png(OUT + "sheet_%s.png" % tag)
