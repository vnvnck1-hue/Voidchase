## 엔딩 컷 자리: 기억 로그 카드 (의뢰 완료 뒤 3장). 새 원화가 올 때까지 모니터 프레임 + 도형 + 글로 보여 준다.
## 카드가 한 장씩 켜지고(스캔선이 내려오며 글이 찍힘), 클릭/Space 로 다음 장. 마지막 장 뒤 finished.
## cards: [{tag, icon ("crown" | "plan" | "phone"), text}] (CaseData 의 "ending")
class_name VDMemoryLog
extends Control

signal finished

const GameFonts := preload("res://scripts/game_fonts.gd")
const CARD := Rect2(460, 190, 1000, 640)
const CPS := 30.0

var cards: Array = []
var _i := 0
var _t := 0.0
var _clock_us := 0
var _done := false
var _view: Control
var _text: Label
var _tag: Label
var _next: Label
var _dim: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var th := Theme.new()
	th.default_font = VDData.font()
	theme = th
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.03, 0.02, 0.08, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_view = Control.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneSwitcher.pin(_view, Vector2(0.5, 0.5), CARD)
	_view.draw.connect(_draw_card)
	add_child(_view)
	_tag = UiKit.tag("", UiKit.CYAN, 22)
	_tag.position = Vector2(44, 30)
	_view.add_child(_tag)
	_text = UiKit.label("", 38, UiKit.CREAM)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_constant_override("line_spacing", 14)
	_text.position = Vector2(60, 370)
	_text.size = Vector2(880, 220)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_view.add_child(_text)
	_next = UiKit.label("클릭 / Space", 18, UiKit.MUTED)
	_next.position = Vector2(820, 590)
	_view.add_child(_next)
	add_child(UiKit.screen_fx(0.07, 0.6))
	_clock_us = Time.get_ticks_usec()
	_show()


func _show() -> void:
	_t = 0.0
	var c: Dictionary = cards[_i]
	_tag.text = "%s  ·  %d / %d" % [String(c["tag"]), _i + 1, cards.size()]
	_text.text = String(c["text"])
	_text.visible_characters = 0


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf((now - _clock_us) / 1e6, 0.0, 0.1)
	_clock_us = now
	_t += dt
	_dim.color.a = minf(_dim.color.a + dt * 3.0, 0.88)
	if _done:
		return
	_text.visible_characters = int(maxf(_t - 0.5, 0.0) * CPS)
	_next.modulate.a = 0.5 + 0.5 * sin(_t * 5.0) if _typed() else 0.0
	_view.queue_redraw()


func _typed() -> bool:
	return _text.visible_characters >= _text.get_total_character_count()


func _draw_card() -> void:
	if _i >= cards.size():
		return
	var sz := CARD.size
	var on := clampf(_t / 0.35, 0.0, 1.0)
	# 모니터가 켜지듯 가운데 줄에서 위아래로 펼쳐진다
	var h := sz.y * UIIntro.back_out(on)
	var r := Rect2(0, (sz.y - h) * 0.5, sz.x, h)
	_view.draw_style_box(UiKit.comic_box(Color(0.07, 0.09, 0.2, 0.98), 20, 0), r)
	_view.draw_style_box(UiKit.box(Color(0, 0, 0, 0), Color(UiKit.CYAN, 0.8), 3, 16, 0), r.grow(-10))
	if on < 1.0:
		return
	var y := 20.0
	while y < sz.y - 16.0:
		_view.draw_line(Vector2(16, y), Vector2(sz.x - 16, y), Color(UiKit.CYAN, 0.035), 1.0)
		y += 6.0
	# 그림 자리 (도형)
	var c := Vector2(sz.x * 0.5, 210.0)
	var a := clampf((_t - 0.3) / 0.4, 0.0, 1.0)
	var bob := sin(_t * 1.8) * 6.0
	match String(cards[_i].get("icon", "")):
		"crown":
			var p := c + Vector2(0, bob)
			var pts := PackedVector2Array([p + Vector2(-110, 56), p + Vector2(-122, -44), p + Vector2(-58, 4), p + Vector2(0, -70), p + Vector2(58, 4), p + Vector2(122, -44), p + Vector2(110, 56)])
			_view.draw_colored_polygon(pts, Color(1.0, 0.82, 0.38, a))
			pts.append(pts[0])
			_view.draw_polyline(pts, Color(0.03, 0.02, 0.07, a), 6.0, true)
			for dx: float in [-58.0, 0.0, 58.0]:
				_view.draw_circle(p + Vector2(dx, 26), 10.0, Color(1.0, 0.36, 0.62, a))
			# 소파: 아래 둥근 띠
			_view.draw_style_box(UiKit.box(Color(0.42, 0.3, 0.7, a), Color(0.03, 0.02, 0.07, a), 5, 30, 0), Rect2(c.x - 230, c.y + 78, 460, 60))
		"plan":
			var sheet := Rect2(c.x - 170, c.y - 110 + bob * 0.4, 340, 230)
			_view.draw_style_box(UiKit.box(Color(0.97, 0.94, 0.86, a), Color(0.03, 0.02, 0.07, a), 5, 8, 0), sheet)
			for i in 5:
				var ly := sheet.position.y + 36 + i * 36.0
				_view.draw_line(Vector2(sheet.position.x + 26, ly), Vector2(sheet.end.x - 26 - (i % 2) * 60.0, ly), Color(0.4, 0.34, 0.6, 0.5 * a), 5.0)
			# 마지막 줄: 연필로 덧쓴 한 줄 (핑크)
			var k := clampf((_t - 0.9) / 0.8, 0.0, 1.0)
			var ly2 := sheet.end.y - 26.0
			_view.draw_line(Vector2(sheet.position.x + 26, ly2), Vector2(sheet.position.x + 26 + 200.0 * k, ly2), Color(1.0, 0.36, 0.62, a), 7.0)
		"phone":
			var ph := Rect2(c.x - 250, c.y - 96, 500, 220)
			_view.draw_style_box(UiKit.box(Color(0.12, 0.1, 0.25, a), Color(0.03, 0.02, 0.07, a), 5, 26, 0), ph)
			var k1 := UIIntro.back_out(clampf((_t - 0.5) / 0.3, 0.0, 1.0))
			var k2 := UIIntro.back_out(clampf((_t - 1.4) / 0.3, 0.0, 1.0))
			_view.draw_style_box(UiKit.box(Color(UiKit.CYAN, a * minf(k1, 1.0)), Color(0.03, 0.02, 0.07, a), 4, 20, 0), Rect2(ph.end.x - 30 - 300 * k1, ph.position.y + 28, 300 * k1, 60))
			_view.draw_style_box(UiKit.box(Color(UiKit.PINK, a * minf(k2, 1.0)), Color(0.03, 0.02, 0.07, a), 4, 20, 0), Rect2(ph.position.x + 30, ph.position.y + 124, 200 * k2, 60))


func _advance() -> void:
	if _done:
		return
	if not _typed():
		_t = 99.0   # 다 보여 준다
		_text.visible_characters = -1
		return
	_i += 1
	if _i >= cards.size():
		_done = true
		var tw := create_tween().set_ignore_time_scale()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func() -> void:
			finished.emit()
			queue_free())
		return
	_show()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		_advance()
