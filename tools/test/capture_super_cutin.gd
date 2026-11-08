## 초궁극기 컷인(vd_super_cutin.gd) 타임라인 캡처. 창이 필요하다 (서브 모니터 + override.cfg no_focus).
##   Godot --path . -s tools/test/capture_super_cutin.gd --screen 1 --position 4380,80 --resolution 1280x720 -- <out_dir> [t] [bg.png] [hero]
## 전투 스크린샷을 배경으로 깔고 play() 를 돌려 t 초(실제 시간) 순간의 뷰포트를 PNG 로 남긴다.
## bg 자리에 battle 을 주면 실제 VOID DEFENSE 씬을 띄우고 preview_super_cutin()(설정 메뉴 · F8 과 같은 길)으로 재생한다.
## t 를 빼면 TIMES 를 한 번에 찍는다 — get_image() 가 프레임마다 ~0.15초 멈춰 뒤쪽 시각이 밀리므로 정확히 보려면 t 를 하나씩.
extends SceneTree

const Cutin := preload("res://scripts/void_defense/vd_super_cutin.gd")
const TIMES := [0.06, 0.12, 0.155, 0.19, 0.25, 0.36, 0.6, 1.0, 1.17, 1.24, 1.32]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://cutin"
	var times: Array = [float(args[1])] if args.size() > 1 else TIMES
	var bg_path: String = args[2] if args.size() > 2 and args[2] != "-" else "res://docs/relic_shots/full/02_battle_room0.png"
	var hero: String = args[3] if args.size() > 3 else "mage"   # gunner · mage · knight · healer
	DirAccess.make_dir_recursive_absolute(out)
	if bg_path == "battle":
		var scene: PackedScene = load("res://scenes/void_defense/VoidDefense.tscn")
		var b := scene.instantiate()
		root.add_child(b)
		await create_timer(1.5).timeout
		var t_b := Time.get_ticks_usec() / 1000000.0
		b.preview_super_cutin()
		await _shoot(out, times, t_b)
		quit()
		return
	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(bg_path)))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = root.get_visible_rect().size
	root.add_child(bg)
	await create_timer(0.3).timeout
	Cutin.prewarm()
	await create_timer(0.2).timeout
	var c := Cutin.new()
	root.add_child(c)
	var t0 := Time.get_ticks_usec() / 1000000.0
	var h: Dictionary = VDData.HEROES[hero]
	c.play(VDData.ULTS[hero]["name"], h["name"], h["color"], null, "", hero)
	await _shoot(out, times, t0, hero)
	quit()


func _shoot(out: String, times: Array, t0: float, hero := "mage") -> void:
	for t: float in times:
		while Time.get_ticks_usec() / 1000000.0 - t0 < t:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var fn := "%s/cutin_%s_%04d.png" % [out, hero, int(t * 1000)]
		img.save_png(fn)
		print("[cutin] ", fn, "  at ", snappedf(Time.get_ticks_usec() / 1000000.0 - t0, 0.001))
