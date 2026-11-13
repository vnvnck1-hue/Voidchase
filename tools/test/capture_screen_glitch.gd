## 화면 글리치(VDScreenGlitch) 캡처: 전투 화면을 멈춘 채 피격·침식 글리치를 걸고 연속 프레임을 docs/screen_glitch/ 에 저장한다.
## 프레임 저장(get_image + PNG)에 200ms 넘게 걸려 실시간 간격으로는 못 찍으므로, 연속 프레임은 지속 시간을 SLOW 배 늘린
## 슬로모션으로 찍는다 (포락선 모양은 같다). real_XX 는 실제 속도의 전투에서 켜진 프레임.
## 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/ScreenGlitchCapture.tscn
##   hit_<프레임>.png / corrupt_<프레임>.png : 전체 화면 연속 프레임 · strip_hit.png / strip_corrupt.png : 축소해 이어 붙인 것
##   peak_hit.png / peak_corrupt.png : 가장 센 순간 전체 해상도 · real_XX.png : 실제 전투에서 켜진 화면
## 헤드리스로 돌리면 수명·포락선만 출력한다.
extends Node

const OUT := "res://docs/screen_glitch/"
const FRAMES := {"hit": [8, 0.03], "corrupt": [10, 0.08]}   # 종류 -> [장 수, 실제 간격(초)] (캡처는 SLOW 배 느리게)
const SLOW := 8.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var headless := DisplayServer.get_name() == "headless"
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	while b.enemies.is_empty():
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	b.start_battle()
	await get_tree().create_timer(2.0).timeout
	var sg = b.screen_glitch
	if sg == null:
		print("[screen-glitch] battle failed to build (screen_glitch null) -> quit")
		get_tree().quit(1)
		return
	var vp := get_viewport()
	sg.process_mode = Node.PROCESS_MODE_ALWAYS   # 전투를 멈춰도 글리치는 돈다
	get_tree().paused = true
	var life0: float = sg.P["life"]
	var clife0: float = sg.P["corrupt_life"]
	var fps0: float = sg.P["step_fps"]
	for kind in FRAMES:
		sg.P["life"] = life0 * (1.0 if headless else SLOW)
		sg.P["corrupt_life"] = clife0 * (1.0 if headless else SLOW)
		sg.P["step_fps"] = fps0 / (1.0 if headless else SLOW)
		sg.reset_timer()
		sg.kick(1.0, kind)
		if headless:
			var t0 := Time.get_ticks_msec()
			while sg.is_active():
				await get_tree().process_frame
			print("[screen-glitch] %s lived %d ms" % [kind, Time.get_ticks_msec() - t0])
			continue
		var n: int = FRAMES[kind][0]
		var gap: float = FRAMES[kind][1] * SLOW
		var shots: Array[Image] = []
		for f in n:
			await RenderingServer.frame_post_draw
			print("[screen-glitch] %s f%d  t=%.2fs  amount=%.2f" % [kind, f, sg._elapsed() / SLOW, float(sg._mat.get_shader_parameter("amount"))])
			var img := vp.get_texture().get_image()
			img.save_png(OUT + "%s_%d.png" % [kind, f])
			if f == 0:
				img.save_png(OUT + "peak_%s.png" % kind)
			img.resize(480, 270, Image.INTERPOLATE_LANCZOS)
			shots.append(img)
			await get_tree().create_timer(gap).timeout
		var strip := Image.create(480 * n, 270, false, shots[0].get_format())
		for f in n:
			strip.blit_rect(shots[f], Rect2i(Vector2i.ZERO, Vector2i(480, 270)), Vector2i(480 * f, 0))
		strip.save_png(OUT + "strip_%s.png" % kind)
		print("[screen-glitch] %s captured" % kind)
		while sg.is_active():
			await get_tree().process_frame
	sg.P["life"] = life0
	sg.P["corrupt_life"] = clife0
	sg.P["step_fps"] = fps0
	get_tree().paused = false
	if headless:
		get_tree().quit(0)
		return
	# 실제 전투: 아군 피격으로 켜진 프레임
	var saved := 0
	var seen := 0
	for i in 3000:
		await RenderingServer.frame_post_draw
		if sg.is_active():
			seen += 1
			if saved < 4 and seen % 6 == 2:   # 발동 다음 프레임 (세기가 가장 클 때)
				vp.get_texture().get_image().save_png(OUT + "real_%02d.png" % saved)
				saved += 1
		if saved >= 4:
			break
	print("[screen-glitch] battle frames active=%d saved=%d" % [seen, saved])
	get_tree().quit(0)
