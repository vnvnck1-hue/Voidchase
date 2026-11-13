## 튜토리얼 코치: 상황이 처음 올 때 한 번만 뜨는 안내 카드 + 대상 강조 고리. 전투는 멈추지 않는다.
##   show("ult", "…", target, done)  target: () -> Rect2 (캔버스 좌표, 매 프레임 다시 읽는다) · done: () -> bool (true 면 닫힘)
## 한 번에 하나만 보이고 나머지는 차례를 기다린다. 뜬 안내는 GameSave 에 기록되어 다시 뜨지 않는다 (허브 연구실에서 되돌릴 수 있다).
## 카드는 화면 아래쪽 가운데(큰 버튼 위), 클릭하면 바로 닫힌다. 실제 시간으로 진행.
class_name VDCoach
extends Control

const GameFonts := preload("res://scripts/game_fonts.gd")
const CARD_RECT := Rect2(560, 668, 800, 92)
const MIN_SHOW := 1.2            # done 이 바로 참이어도 이만큼은 보여 준다

var enabled := true
var _queue: Array = []
var _cur := {}
var _t := 0.0
var _clock_us := 0
var _card: PanelContainer
var _text: Label
var _badge: Label
var shown: Array[String] = []     # 테스트용: 이번 전투에서 띄운 안내 id


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = VDData.font()
	theme = th
	_card = PanelContainer.new()
	var sb := UiKit.comic_box(Color(0.98, 0.96, 0.9, 0.97), 14, 16)
	sb.border_color = Color(0.05, 0.03, 0.1)
	_card.add_theme_stylebox_override("panel", sb)
	SceneSwitcher.pin(_card, Vector2(0.5, 1), CARD_RECT)
	_card.pivot_offset = CARD_RECT.size * 0.5
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			dismiss())
	_card.visible = false
	add_child(_card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(h)
	_badge = UiKit.label("TIP", 22, Color.WHITE, GameFonts.display())
	_badge.add_theme_stylebox_override("normal", UiKit.box(UiKit.PINK, Color(0.05, 0.03, 0.1), 3, 10, 10))
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_badge)
	_text = UiKit.label("", 24, Color(0.12, 0.09, 0.22))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_text)
	_clock_us = Time.get_ticks_usec()


## 안내를 예약한다. 이미 본 안내·꺼 둔 상태면 false.
func show_hint(id: String, text: String, target := Callable(), done := Callable(), max_sec := 9.0) -> bool:
	if not enabled or not GameSave.hints_enabled() or GameSave.hint_seen(id):
		return false
	for q in _queue:
		if q["id"] == id:
			return false
	if not _cur.is_empty() and _cur["id"] == id:
		return false
	_queue.append({"id": id, "text": text, "target": target, "done": done, "max": max_sec})
	return true


func dismiss() -> void:
	if not _cur.is_empty():
		_t = maxf(_t, float(_cur["max"]))


## 대기 중인 안내까지 모두 치운다 (런이 끝날 때). 아직 안 뜬 안내는 기록하지 않아 다음에 다시 뜬다.
func clear() -> void:
	_queue.clear()
	_cur = {}
	_card.visible = false
	queue_redraw()


func is_showing() -> bool:
	return not _cur.is_empty()


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf((now - _clock_us) / 1e6, 0.0, 0.1)
	_clock_us = now
	if _cur.is_empty():
		if _queue.is_empty():
			return
		_cur = _queue.pop_front()
		_t = 0.0
		GameSave.mark_hint(String(_cur["id"]))
		shown.append(String(_cur["id"]))
		print("[coach] %s: %s" % [_cur["id"], _cur["text"]])
		_text.text = String(_cur["text"])
		_card.visible = true
	_t += dt
	var done_cb: Callable = _cur["done"]
	var finished := _t >= float(_cur["max"]) or (_t >= MIN_SHOW and done_cb.is_valid() and bool(done_cb.call()))
	var k := UIIntro.back_out(clampf(_t / 0.3, 0.0, 1.0))
	_card.scale = Vector2(0.8 + 0.2 * k, 0.8 + 0.2 * k)
	_card.modulate.a = clampf(_t / 0.15, 0.0, 1.0)
	_badge.rotation = 0.06 * sin(_t * 5.0)
	queue_redraw()
	if finished:
		_cur = {}
		_card.visible = false


## 대상 강조: 대상 둘레에 숨 쉬는 고리 + 위에서 톡톡 내려찍는 화살표.
func _draw() -> void:
	if _cur.is_empty():
		return
	var target: Callable = _cur["target"]
	if not target.is_valid():
		return
	var r: Rect2 = target.call()
	if r.size.x <= 0.0:
		return
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	var grow := 6.0 + 8.0 * pulse
	var rr := r.grow(grow)
	draw_style_box(UiKit.box(Color(1, 1, 1, 0.0), Color(1.0, 0.9, 0.35, 0.95), 5, 16, 0), rr)
	draw_style_box(UiKit.box(Color(1, 1, 1, 0.0), Color(1.0, 0.36, 0.62, 0.5 * (1.0 - pulse)), 4, 22, 0), r.grow(grow + 14.0 * (1.0 - pulse)))
	var tip := Vector2(r.get_center().x, rr.position.y - 12.0 - 14.0 * absf(sin(_t * 5.0)))
	var tri := PackedVector2Array([tip, tip + Vector2(-20, -30), tip + Vector2(20, -30)])
	draw_colored_polygon(tri, Color(1.0, 0.9, 0.35))
	tri.append(tri[0])
	draw_polyline(tri, Color(0.05, 0.03, 0.1), 4.0, true)
