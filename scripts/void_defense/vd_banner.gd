## 화면 가운데 가로 띠 배너 ("치료 성공" · "치료 시작").
##   띠가 가운데서 좌우로 펼쳐짐 → 제목이 크게 떨어져 박힘(섬광) → 부제가 아래서 올라옴 → 빛줄기가 띠를 훑음
##   → hold 동안 유지 → 제목·부제가 위로 빠지고 띠가 세로로 접힌다.
## 모든 트윈은 실제 시간(ignore_time_scale): 슬로모션·히트스탑·배속에 늘어지지 않는다.
class_name VDBanner
extends Control

const GameFonts := preload("res://scripts/game_fonts.gd")

var _band: Control
var _bg: ColorRect
var _flash: ColorRect
var _streak: ColorRect
var _line_top: ColorRect
var _line_bot: ColorRect
var _title: Label
var _sub: Label
var _tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band = Control.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.clip_contents = true
	add_child(_band)
	_bg = _rect(_band, Color(0.06, 0.02, 0.12, 0.82))
	_streak = _rect(_band, Color(1, 1, 1, 0.22))
	_streak.rotation = 0.38
	_flash = _rect(_band, Color(1, 1, 1, 0))
	_line_top = _rect(self, Color.WHITE)
	_line_bot = _rect(self, Color.WHITE)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub)
	visible = false


## 제목 글꼴: 숫자·타이틀 역할 (scripts/game_fonts.gd). 기본은 영문 ARCO + 한글 굵은 고딕.
func _title_font() -> Font:
	return GameFonts.display()


func _rect(parent: Control, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## 배너를 띄운다. 끝날 때까지 걸리는 실제 시간(초)을 돌려준다. big=false 면 얇고 짧은 배너("치료 시작" 등).
func play(title: String, sub: String, accent: Color, hold := 1.8, big := true) -> float:
	if _tween:
		_tween.kill()
	var view := get_viewport_rect().size
	# 플레이 영역(위 HUD 120 · 아래 분대 바 150 제외)의 가운데
	var cy := 120.0 + (view.y - 270.0) * 0.5
	var h := 190.0 if big else 104.0
	var title_size := 104 if big else 58
	_band.position = Vector2(0, cy - h * 0.5)
	_band.size = Vector2(view.x, h)
	_band.pivot_offset = Vector2(view.x * 0.5, h * 0.5)
	_bg.size = _band.size
	_flash.size = _band.size
	_streak.size = Vector2(70.0 if big else 44.0, h * 2.2)
	for ln in [_line_top, _line_bot]:
		ln.color = accent
		ln.size = Vector2(view.x, 3.0)
		ln.pivot_offset = Vector2(view.x * 0.5, 1.5)
		ln.scale = Vector2(0, 1)
	_line_top.position = Vector2(0, _band.position.y - 6.0)
	_line_bot.position = Vector2(0, _band.position.y + h + 3.0)

	var ls := LabelSettings.new()
	ls.font = _title_font()
	ls.font_size = title_size
	ls.font_color = accent.lightened(0.35)
	ls.outline_size = int(title_size * 0.16)
	ls.outline_color = Color(0.12, 0.03, 0.2)
	ls.shadow_size = 0
	ls.shadow_color = Color(accent, 0.55)
	ls.shadow_offset = Vector2(0, 6)
	_title.label_settings = ls
	_title.text = title
	_title.size = Vector2(view.x, title_size * 1.3)
	_title.position = Vector2(0, cy - title_size * 0.65 - (18.0 if big and sub != "" else 0.0))
	_title.pivot_offset = _title.size * 0.5
	var ss := LabelSettings.new()
	ss.font = VDData.font()
	ss.font_size = 26 if big else 20
	ss.font_color = Color(0.92, 0.88, 1.0)
	ss.outline_size = 6
	ss.outline_color = Color(0.1, 0.03, 0.18)
	_sub.label_settings = ss
	_sub.text = sub
	_sub.size = Vector2(view.x, 40)
	var sub_y := _title.position.y + _title.size.y - 8.0
	_sub.position = Vector2(0, sub_y + 18.0)

	visible = true
	modulate = Color.WHITE
	_band.scale = Vector2(0.0, 1.0)
	_band.modulate.a = 1.0
	_flash.color.a = 0.0
	_streak.position = Vector2(-200, -h * 0.6)
	_title.scale = Vector2(2.3, 2.3)
	_title.modulate.a = 0.0
	_sub.modulate.a = 0.0

	var t_open := 0.22 if big else 0.16
	var t_slam := 0.2 if big else 0.14
	_tween = create_tween().set_ignore_time_scale(true)
	# 1) 띠·선이 가운데서 펼쳐진다
	_tween.tween_property(_band, "scale:x", 1.0, t_open).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_line_top, "scale:x", 1.0, t_open + 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_line_bot, "scale:x", 1.0, t_open + 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 2) 제목이 떨어져 박히고 띠가 번쩍
	_tween.tween_property(_title, "modulate:a", 1.0, t_slam * 0.5)
	_tween.parallel().tween_property(_title, "scale", Vector2.ONE, t_slam).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void: _flash.color = Color(accent.lightened(0.6), 0.55))
	_tween.tween_property(_flash, "color:a", 0.0, 0.3)
	# 3) 부제가 올라오고, 빛줄기가 훑는다
	_tween.parallel().tween_property(_sub, "modulate:a", 1.0, 0.3).set_delay(0.08)
	_tween.parallel().tween_property(_sub, "position:y", sub_y, 0.35).set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_streak, "position:x", view.x + 200.0, 0.7 if big else 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 4) 유지
	_tween.tween_interval(hold)
	# 5) 빠진다
	var t_out := 0.32 if big else 0.22
	_tween.tween_property(_title, "position:y", _title.position.y - 30.0, t_out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_title, "modulate:a", 0.0, t_out)
	_tween.parallel().tween_property(_sub, "modulate:a", 0.0, t_out * 0.7)
	_tween.parallel().tween_property(_band, "scale:y", 0.0, t_out).set_delay(t_out * 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_line_top, "modulate:a", 0.0, t_out).set_delay(t_out * 0.4)
	_tween.parallel().tween_property(_line_bot, "modulate:a", 0.0, t_out).set_delay(t_out * 0.4)
	_tween.tween_callback(_reset)
	return t_open + t_slam + 0.3 + hold + t_out * 1.4


func is_playing() -> bool:
	return visible


func _reset() -> void:
	visible = false
	_band.scale = Vector2.ONE
	_line_top.modulate.a = 1.0
	_line_bot.modulate.a = 1.0
	_tween = null
