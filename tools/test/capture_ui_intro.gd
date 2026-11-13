## UI 등장 애니메이션 점검·캡처 (2026-11-09): 로비 순차 등장(UIIntro)과 VOID DEFENSE 전투 입장(HUD 방향별 슬라이드 +
## 하프톤 안개 중앙 열림 VDFogReveal)을 시간차로 찍어 docs/ui_intro/ 에 저장한다. 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/UiIntroCapture.tscn
##   lobby_<ms>.png · battle_<ms>.png (입장 뒤 경과 ms) · sheet_lobby.png / sheet_battle.png (모음)
## 헤드리스로 돌리면 그림 없이: 시작 직후 조각이 밀려나 있고(투명), 끝난 뒤 원래 offset 으로 정확히 돌아오는지,
## 안개 덧판의 reveal 이 0 에서 올라가 끝나면 지워지는지 확인한다.
extends Node

const OUT := "res://docs/ui_intro/"
const LOBBY_TIMES := [50, 250, 450, 700, 950, 1300, 1800]
const BATTLE_TIMES := [50, 450, 650, 850, 1050, 1300, 1700, 2200, 3000]
const SETTLE_TIMEOUT := 8.0
var failures: Array[String] = []
var _headless := false


func _check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
	print("[ui-intro] %s %s" % ["PASS" if ok else "FAIL", description])


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	call_deferred("_run")


func _offsets(c: Control) -> PackedFloat32Array:
	return PackedFloat32Array([c.offset_left, c.offset_right, c.offset_top, c.offset_bottom])


func _same(a: PackedFloat32Array, b: PackedFloat32Array) -> bool:
	for i in 4:
		if absf(a[i] - b[i]) > 0.01:
			return false
	return true


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


## 러너(UIIntro)가 하나도 안 남을 때까지 (최대 SETTLE_TIMEOUT 초). 걸린 시간을 돌려준다.
func _settle(root: Node) -> float:
	var t0 := Time.get_ticks_msec()
	while _has_runner(root) and (Time.get_ticks_msec() - t0) / 1000.0 < SETTLE_TIMEOUT:
		await get_tree().process_frame
	return (Time.get_ticks_msec() - t0) / 1000.0


func _has_runner(n: Node) -> bool:
	if n is UIIntro or n is VDFogReveal:
		return true
	for c in n.get_children():
		if _has_runner(c):
			return true
	return false


var _mid := -1.0


func _watch_mid(b: VDBattle) -> void:
	var mid_t := b.INTRO_FOG_DELAY + VDFogReveal.DUR * 0.5
	while is_instance_valid(b.fog_reveal) and b.fog_reveal.elapsed() < mid_t:
		await get_tree().process_frame
	if is_instance_valid(b.fog_reveal):
		_mid = float((b.fog_reveal.material as ShaderMaterial).get_shader_parameter("reveal"))


func _shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + name + ".png")
	return img


## 연출 자체 시계 (러너·안개 덧판 중 가장 많이 흐른 것, 초). 화면 캡처로 프레임이 느려져도 연출은 프레임당 MAX_DT 씩만 가므로
## 실시간 대신 이 시계로 찍어야 같은 장면이 나온다. 러너가 다 끝났으면 INF.
func _intro_clock(n: Node) -> float:
	var t := -1.0
	if n is UIIntro:
		t = n._t
	elif n is VDFogReveal:
		t = n.elapsed()
	for c in n.get_children():
		t = maxf(t, _intro_clock(c))
	return t


## 연출 시계가 times 의 각 시각(ms)에 닿을 때마다 찍고, 가로 3장씩 모은 시트를 저장한다. 헤드리스면 찍지 않고 기다리기만 한다.
func _sequence(prefix: String, root: Node, times: Array) -> void:
	var shots: Array[Image] = []
	for ms in times:
		while _has_runner(root) and _intro_clock(root) * 1000.0 < float(ms):
			await get_tree().process_frame
		if not _headless:
			shots.append(await _shot("%s_%04d" % [prefix, int(ms)]))
	if _headless:
		return
	var w := shots[0].get_width() / 2
	var h := shots[0].get_height() / 2
	var cols := 3
	var rows := ceili(shots.size() / float(cols))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGB8)
	for i in shots.size():
		var s := shots[i]
		s.resize(w, h, Image.INTERPOLATE_BILINEAR)
		s.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(s, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png(OUT + "sheet_%s.png" % prefix)


func _run() -> void:
	# ---- 로비(상담소 허브): 탭 패널·반장이 밀려난 채 투명으로 시작해 제자리로 (2026-11-13 허브 개편에 맞춤)
	var lobby: Control = load("res://scenes/Lobby.tscn").instantiate()
	add_child(lobby)
	var card: Control = lobby._cards[0]   # 탭 패널 (오른쪽에 붙는다: offset_left = 1010 - 1920)
	var home: float = lobby.PANEL_RECT.position.x - 1920.0
	var card_before := _offsets(card)
	_check(card.modulate.a < 0.01 and card_before[0] > home + 50.0, "hub panel starts offset right and transparent (x=%.0f)" % card_before[0])
	_check(lobby._chief.modulate.a < 0.01, "hub chief starts transparent")
	await _sequence("lobby", lobby, LOBBY_TIMES)
	var took := await _settle(lobby)
	_check(took < SETTLE_TIMEOUT, "lobby intro runners finish (+%.2fs)" % took)
	var card_after := _offsets(card)
	_check(absf(card_after[0] - home) < 0.01 and card.modulate.a > 0.99, "hub panel settles at its pinned x opaque (x=%.2f a=%.2f)" % [card_after[0], card.modulate.a])
	_check(lobby._chief.modulate.a > 0.99, "hub chief settles opaque")
	_check(lobby._dive != null and lobby._tab_bar.modulate.a > 0.99, "hub dive button and tabs are up")
	lobby.queue_free()
	await get_tree().process_frame

	# ---- 전투: 러너 자식이라 자동 입장은 돌지 않는다 → 제자리 offset 을 먼저 재고 play_intro() 로 돈다
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	while b.enemies.is_empty():
		await get_tree().process_frame
	_check(b.fog_reveal == null, "no auto intro when battle is not the current scene")
	var watched := {"main": b._btn_main, "turntable": b.turntable, "relic": b.relic_hud, "backdrop": b.relic_hud.backdrop,
		"essence": b._lbl_essence, "wave_lbl": b._lbl_wave, "top_bar": b.frame._top_bar, "panel": b.frame._panel, "shade": b.frame._shade}
	var before := {}
	var alpha_before := {}   # 뒷패널·하단 그늘은 원래 반투명이다: 1 이 아니라 원래 알파로 돌아왔는지 본다
	for k in watched:
		before[k] = _offsets(watched[k])
		alpha_before[k] = watched[k].modulate.a
	await _wait(0.4)
	b.play_intro()
	_check(is_instance_valid(b.fog_reveal) and b.fog_reveal.get_parent() == b._reveal_layer, "fog reveal overlay added to reveal layer (7)")
	var mat := b.fog_reveal.material as ShaderMaterial
	_check(float(mat.get_shader_parameter("reveal")) == 0.0 and float(mat.get_shader_parameter("edge_mask")) == 0.0, "fog reveal starts fully covered, edge mask off")
	var saved := b.nebula_tuner.halftone_params()
	_check(is_equal_approx(float(mat.get_shader_parameter("ht_size")), float(saved["ht_size"])), "fog reveal uses saved halftone dot size (%.1f)" % float(saved["ht_size"]))
	_check(_offsets(b._btn_main)[2] > before["main"][2] + 100.0, "main button starts below its place")
	_check(_offsets(b.turntable)[0] < before["turntable"][0] - 100.0, "turntable starts left of its place")
	_check(_offsets(b.relic_hud)[0] > before["relic"][0] + 100.0, "relic board starts right of its place")
	_check(_offsets(b.frame._top_bar)[2] < before["top_bar"][2] - 50.0, "top bar starts above its place")
	_check(b.frame._fx[b.frame._heroes[0]].get("in_t", 1.0) < 0.0, "squad cards wait for their turn")
	_watch_mid(b)   # 캡처와 나란히: 안개 자체 시계로 delay + dur/2 때 reveal 값을 적어 둔다
	await _sequence("battle", b, BATTLE_TIMES)
	took = await _settle(b)
	_check(_mid > 0.3 and _mid < 0.7, "fog reveal is opening mid-way (reveal=%.2f)" % _mid)
	_check(took < SETTLE_TIMEOUT, "battle intro runners finish (+%.2fs)" % took)
	for k in watched:
		_check(_same(_offsets(watched[k]), before[k]) and absf(watched[k].modulate.a - float(alpha_before[k])) < 0.01, "%s returns to its place" % k)
	_check(not is_instance_valid(b.fog_reveal), "fog reveal overlay removed itself")
	_check(not b.frame._fx[b.frame._heroes[0]].has("in_t"), "squad card intro finished")
	print("[ui-intro] DONE failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
