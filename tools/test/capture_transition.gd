## 코믹 파편 전환 캡처: 로비 위에 전환을 띄워 progress 단계별로 찍고 docs/transition/ 에 저장한다. 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/TransitionCapture.tscn
## 사용자 인자 `-- --tag wide` 를 주면 파일 이름 뒤에 _wide 를 붙인다 (21:9 등 다른 비율로 한 번 더 찍을 때).
##   wipe_P_NN.png : 프리셋 P 의 progress 0.NN 전체 화면 · sheet_P.png : 9단계 모음(3x3) · live_NN.png : 실제 start()→reveal() 진행 중 몇 프레임
## 헤드리스로 돌리면 그림 없이 start → covered → reveal → finished 흐름과 progress 값만 PASS/FAIL 로 확인한다.
## 사용자 인자 `-- --flow` 를 주면 대신 실제 입장 흐름(로딩 → 전환 → 안개·HUD 등장)을 찍는다 (capture_transition_flow.gd).
extends Node

const OUT := "res://docs/transition/"
const ScreenTransition := preload("res://scripts/screen_transition.gd")
const STEPS := [0.08, 0.16, 0.24, 0.32, 0.42, 0.56, 0.64, 0.74, 0.86]
## 번개 닫힘: 들어오는 중 · K0 · K1 · K2 · K3 · 다 덮임 · 되감기 K2 · K1 · K0  (K 포즈의 progress = KEY_AT / 2, 되감기는 1 - 그 값)
const STEPS_LIGHTNING := [0.04, 0.07, 0.16, 0.28, 0.37, 0.5, 0.72, 0.84, 0.93]
## 번개 일섬·재단 (12장, 4x3): 번개 선타 · 다가옴 · 움찔 · 닫히는 중 · 충돌 · 여운 · 다 덮임 · 재점화 · 튕겨 열림 …
const STEPS_STRIKE := [0.05, 0.12, 0.2, 0.27, 0.3, 0.315, 0.35, 0.5, 0.56, 0.6, 0.68, 0.82]
## 워프 다이브 (12장): 늘어나기 시작 · 블록 깨짐 · 터널 · 다 덮임 · 도착 섬광 · 구멍 열림 · 또렷해짐
const STEPS_WARP := [0.06, 0.14, 0.22, 0.3, 0.38, 0.46, 0.5, 0.56, 0.6, 0.66, 0.74, 0.86]
## 워프 러시 (12장): 집중선 · 터널 닫힘 · 섬광 · 번쩍 · 구멍 터짐 · 자리 잡기
const STEPS_RUSH := [0.08, 0.16, 0.24, 0.32, 0.4, 0.47, 0.5, 0.54, 0.58, 0.64, 0.72, 0.86]
const ANIM_FPS := 30.0
var failures: Array[String] = []


func _check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
	print("[transition] %s %s" % ["PASS" if ok else "FAIL", description])


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if "--flow" in OS.get_cmdline_user_args():
		# current_scene 이 바뀌어도 살아남도록 루트에 붙은 별도 노드에서 진행
		var worker := Node.new()
		worker.name = "TransitionFlowWorker"
		worker.set_script(load("res://tools/test/capture_transition_flow.gd"))
		get_tree().root.add_child.call_deferred(worker)
		return
	call_deferred("_run")


func _run() -> void:
	var headless := DisplayServer.get_name() == "headless"
	var lobby: Node = load("res://scenes/Lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(0.3 if headless else 1.2).timeout

	# 1) 흐름 확인 (헤드리스에서도): 번개 닫힘(기본 프리셋) → 색판 프리셋
	var tag := ""
	var args := OS.get_cmdline_user_args()
	if "--tag" in args and args.find("--tag") + 1 < args.size():
		tag = "_" + args[args.find("--tag") + 1]
	var only := -1      # `-- --only N`: 그 프리셋만 찍는다
	if "--only" in args and args.find("--only") + 1 < args.size():
		only = int(args[args.find("--only") + 1])
	if "--anim" in args:
		await _anim(args[args.find("--anim") + 1], only)
		_finish()
		return
	_check(ScreenTransition.DEFAULT_PRESET == ScreenTransition.PRESET_STRIKE, "default preset is the lightning strike")
	# 전투 진입 전환은 일반 화면 전환과 따로 고른다
	_check(ScreenTransition.general_names().size() == 5 and not ScreenTransition.general_names().has("워프 다이브"), "general list has no battle-entry warps")
	_check(ScreenTransition.enter_names() == ["워프 다이브", "워프 러시 (카툰)"], "battle-entry list = the two warps")
	var keep_p := ScreenTransition.get_preset()
	var keep_e := ScreenTransition.get_enter()
	ScreenTransition.set_enter(0)
	ScreenTransition.set_preset(1)
	ScreenTransition._preset = -1
	ScreenTransition._enter = -1
	_check(ScreenTransition.enter_preset() == ScreenTransition.PRESET_WARP and ScreenTransition.get_preset() == 1, "both choices survive a save and reload")
	ScreenTransition.set_preset(6)
	_check(ScreenTransition.get_preset() < 5, "general choice cannot become a warp")
	ScreenTransition.set_enter(keep_e)
	ScreenTransition.set_preset(keep_p)
	_check(SceneSwitcher.SCENES[1].get("enter_wipe", false) and not SceneSwitcher.SCENES[2].has("enter_wipe"), "only the main battle uses the battle-entry transition")
	for k in [ScreenTransition.PRESET_STRIKE, ScreenTransition.PRESET_STRIKE + 1]:
		var sk := ScreenTransition.new()
		sk.preset_override = k
		add_child(sk)
		_check(sk._view != null and not sk._view.is_opaque(), "preset %d: starts with nothing over the scene" % k)
		sk.start()
		var saw_gap := false       # 다 덮이기 전에 가려지지 않은 구간이 있고, 덮인 뒤에는 0.5 까지 계속 가려져 있는가
		var hole_after := false
		var closed := false
		while sk._phase == 1:
			await get_tree().process_frame
			if sk._view.is_opaque():
				closed = true
			elif closed:
				hole_after = true
			else:
				saw_gap = true
		_check(saw_gap and closed and not hole_after, "preset %d: closes once and stays closed until covered" % k)
		_check(is_equal_approx(sk.progress, 0.5) and sk._view.is_opaque(), "preset %d: covered at 0.5 and fully opaque" % k)
		_check(sk.time_to_open() > 0.0 and sk.time_to_open() < sk.out_dur(k) + 0.1, "preset %d: time_to_open inside the reveal (%.3fs)" % [k, sk.time_to_open()])
		sk.reveal()
		await sk.finished
		_check(is_equal_approx(sk.progress, 1.0) and not sk._view.is_opaque(), "preset %d: opened" % k)
	var lt := ScreenTransition.new()
	lt.preset_override = ScreenTransition.PRESET_LIGHTNING
	add_child(lt)
	_check(lt._view != null and not lt._view.is_opaque(), "lightning: starts with nothing drawn over the scene")
	lt.start()
	var lt0 := Time.get_ticks_usec()
	await lt.covered
	_check(is_equal_approx(lt.progress, 0.5) and lt._view.is_opaque(), "lightning: covered at 0.5 and fully opaque")
	_check((Time.get_ticks_usec() - lt0) / 1e6 >= lt.in_dur(lt._pid) * 0.9, "lightning: cover took >= lt_in_dur")
	_check(lt.time_to_open() > 0.0 and lt.time_to_open() < lt.out_dur(lt._pid) + 0.1, "lightning: time_to_open inside the rewind (%.3fs)" % lt.time_to_open())
	lt.reveal()
	await lt.finished
	_check(is_equal_approx(lt.progress, 1.0) and not lt._view.is_opaque(), "lightning: rewound to open")
	for q in [0.1, 0.25, 0.4]:   # 되감기 = 같은 그림: progress q 와 1-q 의 도형이 같다
		var a := ScreenTransition.new()
		a.preset_override = ScreenTransition.PRESET_LIGHTNING
		add_child(a)
		a.preview(q)
		var pa: PackedVector2Array = a._view._polys[0].polygon
		a.preview(1.0 - q)
		_check(pa == a._view._polys[0].polygon, "lightning: rewind mirrors the close at %.2f" % q)
		a.queue_free()
	await get_tree().process_frame
	var ru := ScreenTransition.new()
	ru.preset_override = ScreenTransition.PRESET_RUSH
	add_child(ru)
	_check(ru._view == null and ru._mat.shader == ScreenTransition.RUSH_SHADER and not ru._rect.visible, "rush: uses the rush shader, hidden at progress 0")
	ru.start()
	await ru.covered
	_check(is_equal_approx(ru.progress, 0.5) and ru._rect.visible, "rush: covered at 0.5")
	_check(ru.in_dur(ru._pid) + ru.out_dur(ru._pid) < ScreenTransition.in_dur(ScreenTransition.PRESET_WARP) + ScreenTransition.out_dur(ScreenTransition.PRESET_WARP), "rush: shorter than the warp dive")
	_check(ScreenTransition.rush_tick(0.9) > ScreenTransition.rush_tick(0.5) and ScreenTransition.rush_tick(0.5) > ScreenTransition.rush_tick(0.1), "rush: stop-motion tick advances")
	ru.reveal()
	await ru.finished
	_check(is_equal_approx(ru.progress, 1.0) and not ru._rect.visible, "rush: opened and hidden at 1.0")
	await get_tree().process_frame
	var wp := ScreenTransition.new()
	wp.preset_override = ScreenTransition.PRESET_WARP
	add_child(wp)
	_check(wp._view == null and wp._mat.shader == ScreenTransition.WARP_SHADER and not wp._rect.visible, "warp: uses the warp shader, hidden at progress 0")
	wp.start()
	await wp.covered
	_check(is_equal_approx(wp.progress, 0.5) and wp._rect.visible, "warp: covered at 0.5")
	_check(wp.time_to_open() > 0.0 and wp.time_to_open() < wp.out_dur(wp._pid) + 0.1, "warp: time_to_open inside the reveal (%.3fs)" % wp.time_to_open())
	var tv := [ScreenTransition.warp_travel(0.49), ScreenTransition.warp_travel(0.5), ScreenTransition.warp_travel(0.51), ScreenTransition.warp_travel(1.0)]
	_check(tv[0] < tv[1] and tv[1] < tv[2] and tv[2] < tv[3], "warp: travel keeps increasing through 0.5")
	wp.reveal()
	await wp.finished
	_check(is_equal_approx(wp.progress, 1.0) and not wp._rect.visible, "warp: opened and hidden at 1.0")
	await get_tree().process_frame
	var tr := ScreenTransition.new()
	tr.preset_override = 0
	add_child(tr)
	_check(tr.progress == 0.0, "starts at progress 0")
	tr.start()
	var t0 := Time.get_ticks_usec()
	var live: Array[Image] = []
	if not headless:
		_grab_live(tr, live)
	await tr.covered
	var in_s := (Time.get_ticks_usec() - t0) / 1e6
	_check(is_equal_approx(tr.progress, 0.5), "covered at progress 0.5 (got %.3f)" % tr.progress)
	_check(in_s >= tr.in_dur(0) * 0.9, "cover took >= in_dur (%.2fs)" % in_s)
	tr.reveal()
	await tr.finished
	_check(is_equal_approx(tr.progress, 1.0), "finished at progress 1.0 (got %.3f)" % tr.progress)
	await get_tree().process_frame
	_check(not is_instance_valid(tr), "transition frees itself")

	if headless:
		_finish()
		return

	# 2) 단계별 정지 화면
	for i in live.size():
		live[i].save_png(OUT + "live_%02d%s.png" % [i, tag])
	for k in ScreenTransition.PRESET_NAMES.size():
		if only >= 0 and k != only:
			continue
		tr = ScreenTransition.new()
		tr.preset_override = k
		add_child(tr)
		tr._mat.set_shader_parameter("seed", 7.0)
		var fulls: Array[Image] = []
		var steps: Array = STEPS_RUSH if k == ScreenTransition.PRESET_RUSH else STEPS_WARP if k == ScreenTransition.PRESET_WARP else STEPS_STRIKE if k >= ScreenTransition.PRESET_STRIKE else (STEPS_LIGHTNING if k == ScreenTransition.PRESET_LIGHTNING else STEPS)
		var cols := 4 if steps.size() > 9 else 3
		for p in steps:
			tr.preview(p)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png(OUT + "wipe_%d_%02d%s.png" % [k, int(round(p * 100)), tag])
			fulls.append(img)
		var cw := 640
		var ch := int(round(640.0 * fulls[0].get_height() / fulls[0].get_width()))
		var sheet := Image.create(cw * cols, ch * ((fulls.size() + cols - 1) / cols), false, fulls[0].get_format())
		for i in fulls.size():
			var f := fulls[i]
			f.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(f, Rect2i(Vector2i.ZERO, Vector2i(cw, ch)), Vector2i(cw * (i % cols), ch * (i / cols)))
		sheet.save_png(OUT + "sheet_%d%s.png" % [k, tag])
		print("[transition] preset %d sheet" % k)
		tr.queue_free()
	_finish()


## `-- --anim <폴더>`: 번개 일섬·재단을 실제 속도의 프레임(ANIM_FPS)으로 찍어 <폴더>/anim_P_NNN.png 로 저장한다 (gif 로 묶어 움직임 확인).
func _anim(dir: String, only := -1) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for k in [ScreenTransition.PRESET_STRIKE, ScreenTransition.PRESET_STRIKE + 1, ScreenTransition.PRESET_WARP, ScreenTransition.PRESET_RUSH]:
		if only >= 0 and k != only:
			continue
		var tr := ScreenTransition.new()
		tr.preset_override = k
		add_child(tr)
		var t_in: float = tr.in_dur(k)
		var t_out: float = tr.out_dur(k)
		var n := int(ceil((t_in + t_out) * ANIM_FPS)) + 1
		for i in range(-6, n + 8):
			var t := clampf(i / ANIM_FPS, 0.0, t_in + t_out)
			tr.preview(0.5 * t / t_in if t <= t_in else 0.5 + 0.5 * (t - t_in) / t_out)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dir.path_join("anim_%d_%03d.png" % [k, i + 6]))
		print("[transition] preset %d anim frames %d" % [k, n + 14])
		tr.queue_free()
		await get_tree().process_frame


## 실제 진행 중 몇 프레임을 받아 둔다 (속도감 확인용).
func _grab_live(tr: Node, into: Array[Image]) -> void:
	var marks := [0.12, 0.25, 0.42, 0.5, 0.6, 0.75]
	var next := 0
	while is_instance_valid(tr) and next < marks.size():
		await RenderingServer.frame_post_draw
		if not is_instance_valid(tr):
			break
		if tr.progress >= marks[next]:
			into.append(get_viewport().get_texture().get_image())
			next += 1


func _finish() -> void:
	print("[transition] %s (%d failures)" % ["ALL PASS" if failures.is_empty() else "FAILED", failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
