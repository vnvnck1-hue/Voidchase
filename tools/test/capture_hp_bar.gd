## 유닛 HP 바 점검 (2026-11-09): ① 만피에서 회복을 받아도 회복빛(연두)이 빠진 뒤 바가 원래 색으로 다시 그려지는지,
## ② 채움·잔상·광택이 둥근 테두리 안쪽 모서리에 맞는지 여러 체력 비율로 확대해 찍는다.
##   헤드리스: Godot --headless --path . res://tools/test/HpBarCapture.tscn   (①만 PASS/FAIL)
##   캡처:     Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/HpBarCapture.tscn
##             → docs/fx_lab/bars/hp_bar_zoom.png (영웅 넷: 100% · 97% · 55% · 8%, 카메라 2.6배 줌 + 3배 확대, CRT 잠깐 숨김)
extends Node

const OUT := "res://docs/fx_lab/bars/"
const RATIOS := [1.0, 0.97, 0.55, 0.08]
const ZOOM := 3
const CW := 260          # 잘라낼 크기 (창 px, 카메라 줌 2.6 기준 바 하나 + 배지)
const CH := 70
var failures: Array[String] = []


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
	print("[hp-bar] %s %s" % ["PASS" if ok else "FAIL", what])


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	call_deferred("_run")


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _run() -> void:
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	while b.enemies.is_empty() or b.allies.size() < 4:
		await get_tree().process_frame
	await _wait(0.8)
	# ① 만피 회복 → 회복빛이 빠지고 바가 다시 그려져야 한다
	var u: VDUnit = b.allies[0]
	u.hp = u.max_hp
	await _wait(0.3)
	u.heal(5.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(u.drawn_heal > 0.5, "heal at full hp tints the bar (drawn_heal=%.2f)" % u.drawn_heal)
	await _wait(0.8)
	_check(is_zero_approx(u.drawn_heal), "bar is redrawn back to normal color after the heal glow (drawn_heal=%.2f)" % u.drawn_heal)
	# ② 비율별 모양 (창이 있을 때만 그림)
	for i in RATIOS.size():
		var a: VDUnit = b.allies[i]
		a.hp = a.max_hp * RATIOS[i]
	if DisplayServer.get_name() != "headless":
		# 바가 작아 확대해서 본다: 배치 단계 카메라는 _cam_target 을 따라가므로 분대 쪽으로 옮기고 줌인.
		# CRT 줄무늬가 모서리를 가리므로 레이어만 잠깐 숨긴다 (프리셋을 바꾸면 사용자 설정에 저장돼서)
		var sum := Vector2.ZERO
		for a in b.allies:
			sum += a.position
		b._cam_target = sum / b.allies.size() + Vector2(0, -110)
		b.camera.base_zoom = Vector2(2.6, 2.6)
		SceneSwitcher.crt.visible = false
	await _wait(1.2)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		SceneSwitcher.crt.visible = true
		img.save_png(OUT + "hp_bar_full.png")
		var xf := get_viewport().get_final_transform() * get_viewport().get_canvas_transform()
		var crops: Array[Image] = []
		for i in RATIOS.size():
			var a: VDUnit = b.allies[i]
			var p := xf * (a.bar_top() + Vector2(-12.0, 14.0))     # 바 가운데 근처 (왼쪽 레벨 배지까지)
			var r := Rect2i(Vector2i(p) - Vector2i(CW / 2, CH / 2), Vector2i(CW, CH)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			var c := img.get_region(r)
			c.resize(r.size.x * ZOOM, r.size.y * ZOOM, Image.INTERPOLATE_NEAREST)
			crops.append(c)
		var w := CW * ZOOM
		var h := CH * ZOOM
		var sheet := Image.create(w * 2, h * 2, false, img.get_format())
		for i in crops.size():
			sheet.blit_rect(crops[i], Rect2i(Vector2i.ZERO, crops[i].get_size()), Vector2i((i % 2) * w, (i / 2) * h))
		sheet.save_png(OUT + "hp_bar_zoom.png")
	print("[hp-bar] DONE failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
