## 화면 쇼크웨이브(VDShockwave) 캡처: 전장 가운데 적 위치에 종류별 웨이브를 띄우고 연속 프레임을 docs/shockwave/ 에 저장한다.
## 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/ShockwaveCapture.tscn
##   <종류>_<프레임>.png : 웨이브 둘레 확대 · strip_<종류>.png : 이어 붙인 것 · real_XX.png : 실제 전투 중 웨이브가 켜진 화면
## 헤드리스로 돌리면 그림 없이 웨이브 수명·개수만 확인한다.
extends Node

const OUT := "res://docs/shockwave/"
const FRAMES := 6


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var headless := DisplayServer.get_name() == "headless"
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	while b.enemies.is_empty():
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	var sw = b.shockwave
	var vp := get_viewport()
	var at: Vector2 = b._chest(b.enemies[0])
	for kind in sw.KINDS:
		sw.clear()
		sw.add(at, kind)
		if headless:
			var t0 := Time.get_ticks_msec()
			while not sw._list.is_empty():
				await get_tree().process_frame
			print("[shock] %s lived %d ms" % [kind, Time.get_ticks_msec() - t0])
			continue
		await RenderingServer.frame_post_draw
		var k0: float = vp.get_texture().get_image().get_width() / vp.get_visible_rect().size.x
		var c: Vector2 = vp.get_canvas_transform() * at
		var crop := Rect2i(Vector2i((c - Vector2(320, 200)) * k0), Vector2i(Vector2(640, 400) * k0))
		crop = crop.intersection(Rect2i(Vector2i.ZERO, Vector2i(vp.get_visible_rect().size * k0)))
		var shots: Array[Image] = []
		for f in FRAMES:
			var z := vp.get_texture().get_image().get_region(crop)
			z.save_png(OUT + "%s_%d.png" % [kind, f])
			shots.append(z)
			await get_tree().create_timer(float(sw.KINDS[kind]["life"]) / (FRAMES + 1)).timeout
			await RenderingServer.frame_post_draw
		var strip := Image.create(crop.size.x * FRAMES, crop.size.y, false, shots[0].get_format())
		for f in FRAMES:
			strip.blit_rect(shots[f], Rect2i(Vector2i.ZERO, crop.size), Vector2i(crop.size.x * f, 0))
		strip.save_png(OUT + "strip_%s.png" % kind)
		print("[shock] %s captured" % kind)
		await get_tree().create_timer(0.4).timeout
	# 실제 전투: 웨이브가 켜진 프레임 몇 장
	b.start_battle()
	var saved := 0
	var seen := 0
	for i in 2400:
		if headless:
			await get_tree().process_frame
		else:
			await RenderingServer.frame_post_draw
		if not sw._list.is_empty():
			seen += 1
			if not headless and saved < 4 and seen % 25 == 1:
				vp.get_texture().get_image().save_png(OUT + "real_%02d.png" % saved)
				saved += 1
		if seen > 120 and (headless or saved >= 4):
			break
	print("[shock] battle frames with waves=%d saved=%d" % [seen, saved])
	get_tree().quit(0)
