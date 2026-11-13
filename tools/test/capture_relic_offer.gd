## 유물 보상 카드 글리치 등장 캡처: 전투를 띄우고 3택1 카드를 제시한 뒤 연속 프레임을 메모리에 담았다가 docs/relic_offer/ 에 저장한다.
## (PNG 저장이 느려서 찍는 동안은 저장하지 않는다.) 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/RelicOfferCapture.tscn
##   offer_<프레임>.png : 전체 화면 · strip_offer.png : 축소해 이어 붙인 것 · settled.png : 다 나타난 뒤
## 헤드리스로 돌리면 카드가 만들어지는지만 확인한다.
extends Node

const OUT := "res://docs/relic_offer/"
const FRAMES := 16


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var headless := DisplayServer.get_name() == "headless"
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	while b.enemies.is_empty():
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var vp := get_viewport()
	b.relic_hud.offer(["ember", "star_feather", "thunder_shard"])
	if headless:
		await get_tree().create_timer(1.5).timeout
		print("[relic-offer] cards=%d open=%s" % [b.relic_hud._cards.size(), str(b.relic_hud.has_offer())])
		get_tree().quit(0)
		return
	var shots: Array[Image] = []
	var times: Array[float] = []
	var t0 := Time.get_ticks_msec()
	for f in FRAMES:
		await RenderingServer.frame_post_draw
		shots.append(vp.get_texture().get_image())
		times.append((Time.get_ticks_msec() - t0) / 1000.0)
		if f < 4:
			await get_tree().process_frame   # 처음 몇 장은 촘촘히
		else:
			await get_tree().create_timer(0.04).timeout
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(OUT + "settled.png")
	var w := 480
	var h := 270
	var strip := Image.create(w * FRAMES, h, false, shots[0].get_format())
	for f in FRAMES:
		shots[f].save_png(OUT + "offer_%02d.png" % f)
		shots[f].resize(w, h, Image.INTERPOLATE_LANCZOS)
		strip.blit_rect(shots[f], Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i(w * f, 0))
	strip.save_png(OUT + "strip_offer.png")
	print("[relic-offer] frames at %s" % str(times))
	get_tree().quit(0)
