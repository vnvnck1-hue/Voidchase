## 아군 피격 글리치(VDHurtGlitch) 캡처: 영웅마다 피격을 걸고, 맞은 카드 둘레를 연속 프레임으로 docs/hurt_glitch/ 에 저장한다.
## 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1920x1080 res://tools/test/HurtGlitchCapture.tscn
##   hit_<영웅>_<프레임>.png : 맞은 카드 둘레 (흔들림 · 흰 섬광 → 붉은 기 · 가시)
##   strip_<영웅>.png         : 위 프레임들을 가로로 이어 붙인 것
##   real_XX.png              : 실제 전투에서 아군이 맞아 글리치가 켜진 화면
## -- --panel 이면 글리치 조정 패널을 연 화면(panel.png)도 남긴다.
extends Node

const OUT := "res://docs/hurt_glitch/"
const FRAMES := 8


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	while b.enemies.is_empty():
		await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	var g = b.hurt_glitch
	var vp := get_viewport()
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(OUT + "off.png")
	var k0: float = vp.get_texture().get_image().get_width() / vp.get_visible_rect().size.x

	for hid in VDData.HERO_ORDER:
		# 맞은 카드의 화면 위치 (흔들림 전)
		var card_rect := Rect2()
		for t in b.frame.glitch_targets():
			if t["id"] == hid:
				var xf: Transform2D = t["xf"]
				card_rect = Rect2(xf.origin, xf.basis_xform(t["tex"].get_size()))
		var crop := Rect2i(Vector2i((card_rect.position - Vector2(70, 50)) * k0), Vector2i((card_rect.size + Vector2(140, 100)) * k0))
		crop = crop.intersection(Rect2i(Vector2i.ZERO, Vector2i(vp.get_visible_rect().size * k0)))
		g.reset_timer()
		g.kick(1.0, hid)
		var shots: Array[Image] = []
		for f in FRAMES:
			await RenderingServer.frame_post_draw
			var z := vp.get_texture().get_image().get_region(crop)
			z.save_png(OUT + "hit_%s_%d.png" % [hid, f])
			shots.append(z)
			await get_tree().create_timer(0.035).timeout
		var strip := Image.create(crop.size.x * FRAMES, crop.size.y, false, shots[0].get_format())
		for f in FRAMES:
			strip.blit_rect(shots[f], Rect2i(Vector2i.ZERO, crop.size), Vector2i(crop.size.x * f, 0))
		strip.save_png(OUT + "strip_%s.png" % hid)
		print("[glitch] %s: spikes on %s" % [hid, str(g._spikes.map(func(s): return s["tid"]))])
		await get_tree().create_timer(0.6).timeout

	if "--panel" in OS.get_cmdline_user_args():
		b.glitch_tuner.toggle()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(OUT + "panel.png")
		b.glitch_tuner.toggle()
	# 실제 전투: 아군 피격으로 켜진 프레임을 남긴다
	b.start_battle()
	var saved := 0
	var kicks := 0
	var was_on := false
	for i in 3000:
		await RenderingServer.frame_post_draw
		var on: bool = g.is_active()
		if on and not was_on:
			kicks += 1
			if saved < 6:
				vp.get_texture().get_image().save_png(OUT + "real_%02d.png" % saved)
				saved += 1
		was_on = on
		if saved >= 6:
			break
	print("[glitch] real-battle kicks=%d saved=%d" % [kicks, saved])
	get_tree().quit(0)
