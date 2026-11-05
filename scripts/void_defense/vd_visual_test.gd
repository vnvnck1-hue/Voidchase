## VOID DEFENSE 원화 분리본 비주얼 테스트: docs/void_defense_original/assembly.json 대로 조립한
## 1672x941 캔버스(`Canvas`)를 뷰포트(화면 비율에 따라 넓어지거나 높아짐)에 비율을 유지하며 맞춘다.
## 씬은 tools/void_defense_original/build_visual_test.py 가 생성한다(손으로 고치지 말 것).
## 아래 토글은 오른쪽 위 설정 메뉴에도 있다(SceneSwitcher.add_setting). 단축키도 그대로 쓴다.
##   [R] reference_only 보조 레이어(가장자리 매트·타일 틴트·캐스트 라이트) 켜고 끄기
##   [H] HUD 켜고 끄기   [O] 1:1 원본 크기 / 화면 맞춤 전환   [G] 영웅 리그 피벗 표시
##   [A] 절차 애니메이션(영웅 아이들·몬스터·이펙트·프랍 위빙, scripts/void_defense/vd_visual_idle.gd) 켜고 끄기
##   몬스터 클릭 = 피격 연출 + 데미지 로그 (scripts/void_defense/vd_visual_hit.gd)
extends Node2D

const CANVAS_PX := Vector2(1672, 941)
const REF_GROUP := "vd_reference_only"
const VDVisualIdle := preload("res://scripts/void_defense/vd_visual_idle.gd")
const VDVisualHit := preload("res://scripts/void_defense/vd_visual_hit.gd")

@onready var canvas: Node2D = $Canvas
@onready var heroes: Node2D = $Canvas/Heroes
@onready var ui: Node2D = $Canvas/UI

var fit := true
var show_reference := true
var show_pivots := false
var _idle: Node


func _ready() -> void:
	_layout()
	_idle = VDVisualIdle.new()
	_idle.name = "Idle"
	add_child(_idle)
	_idle.setup(canvas)
	get_viewport().size_changed.connect(_layout)
	var hud := CanvasLayer.new()
	hud.layer = 50
	add_child(hud)
	SceneSwitcher.add_setting(self, "보조 레이어  (R)", _toggle_reference, func() -> bool: return show_reference)
	SceneSwitcher.add_setting(self, "HUD  (H)", func() -> void: ui.visible = not ui.visible, func() -> bool: return ui.visible)
	SceneSwitcher.add_setting(self, "1:1 원본 크기  (O)", _toggle_fit, func() -> bool: return not fit)
	SceneSwitcher.add_setting(self, "리그 피벗  (G)", _toggle_pivots, func() -> bool: return show_pivots)
	SceneSwitcher.add_setting(self, "애니메이션  (A)", func() -> void: _idle.enabled = not _idle.enabled, func() -> bool: return _idle.enabled)
	# 몬스터 클릭 피격 (타격 파티클·펀치·화이트 플래시·히트스톱·흔들림·데미지 로그). 흔들림은 이 노드를 움직인다.
	var hit: Node = VDVisualHit.new()
	hit.name = "Hit"
	add_child(hit)
	hit.setup(canvas, self, hud)
	var n := 0
	for s in canvas.find_children("*", "Sprite2D", true, false):
		n += 1
	print("[vd_visual_test] sprites=%d reference_only=%d heroes=%d" % [n, get_tree().get_nodes_in_group(REF_GROUP).size(), heroes.get_child_count() - 1])


## 캔버스를 뷰포트 안에 비율 유지로 맞추거나(fit) 1:1 로 가운데 둔다.
func _layout() -> void:
	var vp := get_viewport_rect().size
	var s := minf(vp.x / CANVAS_PX.x, vp.y / CANVAS_PX.y) if fit else 1.0
	canvas.scale = Vector2(s, s)
	canvas.position = ((vp - CANVAS_PX * s) * 0.5).floor()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_toggle_reference()
			KEY_H:
				ui.visible = not ui.visible
			KEY_O:
				_toggle_fit()
			KEY_G:
				_toggle_pivots()
			KEY_A:
				_idle.enabled = not _idle.enabled


func _toggle_reference() -> void:
	show_reference = not show_reference
	for n in get_tree().get_nodes_in_group(REF_GROUP):
		(n as CanvasItem).visible = show_reference


func _toggle_fit() -> void:
	fit = not fit
	_layout()


func _toggle_pivots() -> void:
	show_pivots = not show_pivots
	queue_redraw()


func _process(_delta: float) -> void:
	if show_pivots and _idle.enabled:
		queue_redraw()


## 영웅 루트(발밑)와 각 파츠 피벗을 표시한다. 리그 조립 확인용.
func _draw() -> void:
	if not show_pivots:
		return
	for h in heroes.get_children():
		if h.name == "Effects":
			continue
		var root: Vector2 = canvas.to_global((h as Node2D).position) - global_position
		draw_circle(root, 6, Color(1, 0.3, 0.3, 0.9))
		draw_string(ThemeDB.fallback_font, root + Vector2(8, -6), h.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.9, 0.9))
		for p in h.get_children():
			var sp := p as Sprite2D
			if sp == null:
				continue
			var pv: Vector2 = canvas.to_global(h.position + sp.position) - global_position
			draw_circle(pv, 3, Color(0.3, 1, 0.5, 0.9))
			draw_line(root, pv, Color(0.3, 1, 0.5, 0.5), 1.0)
