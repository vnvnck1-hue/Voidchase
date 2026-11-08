## 전투 HUD 아래 가운데 큰 버튼: 배치 단계에선 "배치 완료"(Space), 그 밖엔 진행 상태("치료 중" 등)를 보여 주는 잠긴 버튼.
## 시안 톤(보라·마젠타, 툴팁과 같은 진한 외곽선)에 분대 카드처럼 살짝 기울인 모양. 누를 수 있을 땐 빛이 숨쉬듯 번지고
## 버튼이 작게 맥동해 눈에 띈다. 아래에 SPACE 키캡.
## class_name 없음: vd_battle.gd 가 preload 해서 쓴다.
extends Button

const SKEW := Vector2(-0.16, 0.0)
const BG := Color(0.66, 0.27, 0.98)            # 시안 게이지 보라(#AA57FF)보다 조금 진하게
const BG_HOVER := Color(0.78, 0.38, 1.0)
const BG_PRESSED := Color(0.5, 0.18, 0.82)
const BG_OFF := Color(0.17, 0.13, 0.27)
const BORDER := Color(0.07, 0.07, 0.1)        # 시안 툴팁 외곽선
const GLOW := Color(1.0, 0.45, 0.95)
const TEXT_OUTLINE := Color(0.14, 0.03, 0.26)

var _normal: StyleBoxFlat
var _hover: StyleBoxFlat
var _shine: StyleBoxFlat
var _keycap: StyleBoxFlat
var _key_font: Font
var show_key := true            # 아래 SPACE 키캡 (길 선택 버튼 등에선 끈다)
var _bump := 0.0                # bump(): 톡 튀는 정도 (1 → 0, 실제 시간)
var _bump_k := 1.0
var _clock_us := 0


## 글자가 바뀌거나 열릴 때 톡 튄다 (가로로 넓어졌다 탄성으로 제자리).
func bump(k := 1.0) -> void:
	_bump = 1.0
	_bump_k = k


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	_normal = _box(BG, 4)
	_hover = _box(BG_HOVER, 4)
	var pressed_sb := _box(BG_PRESSED, 4)
	pressed_sb.content_margin_top = 6.0         # 눌리면 글자가 살짝 내려간다
	var off := _box(BG_OFF, 3)
	off.border_color = Color(0.32, 0.26, 0.46)
	off.shadow_size = 0
	add_theme_stylebox_override("normal", _normal)
	add_theme_stylebox_override("hover", _hover)
	add_theme_stylebox_override("pressed", pressed_sb)
	add_theme_stylebox_override("hover_pressed", pressed_sb)
	add_theme_stylebox_override("disabled", off)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans KR", "Apple SD Gothic Neo", "sans-serif"])
	f.font_weight = 900
	add_theme_font_override("font", f)
	add_theme_font_size_override("font_size", 34)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(k, Color.WHITE)
	add_theme_color_override("font_disabled_color", Color(0.62, 0.57, 0.74))
	add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	add_theme_constant_override("outline_size", 10)

	# 위쪽 반사광 (같은 기울기)
	_shine = StyleBoxFlat.new()
	_shine.bg_color = Color(1, 1, 1, 0.16)
	_shine.skew = SKEW
	_shine.set_corner_radius_all(10)
	_keycap = StyleBoxFlat.new()
	_keycap.bg_color = Color(0.09, 0.06, 0.16, 0.95)
	_keycap.border_color = Color(0.85, 0.72, 1.0)
	_keycap.set_border_width_all(2)
	_keycap.border_width_bottom = 4
	_keycap.set_corner_radius_all(6)
	_key_font = load("res://assets/fonts/ARCO.otf")
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5


func _box(col: Color, border: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = BORDER
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(14)
	sb.skew = SKEW
	sb.shadow_color = Color(GLOW, 0.5)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_bottom = 4
	sb.anti_aliasing = true
	return sb


func _process(_dt: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var now_us := Time.get_ticks_usec()
	var real := clampf((now_us - _clock_us) / 1000000.0, 0.0, 0.1) if _clock_us > 0 else 0.0
	_clock_us = now_us
	_bump = maxf(0.0, _bump - real * 3.2)
	# 튐: 감쇠 진동 (처음 가로로 넓게 → 세로로 → 가라앉음)
	var osc := sin((1.0 - _bump) * PI * 3.0) * _bump * _bump * 0.18 * _bump_k
	var bump_s := Vector2(1.0 + osc, 1.0 - osc * 0.7)
	if disabled:
		scale = bump_s
	else:
		var k := 0.5 + 0.5 * sin(t * 4.2)
		var hovered := is_hovered()
		scale = Vector2.ONE * (1.04 if hovered else 1.0 + 0.03 * k) * bump_s
		for sb in [_normal, _hover]:
			sb.shadow_size = int(8.0 + 14.0 * k)
			sb.shadow_color = Color(GLOW, 0.35 + 0.35 * k)
	queue_redraw()


func _draw() -> void:
	if _bump > 0.6:
		# 튀는 순간 흰 테두리 번쩍
		var fl := StyleBoxFlat.new()
		fl.bg_color = Color(1, 1, 1, (_bump - 0.6) * 0.8)
		fl.skew = SKEW
		fl.set_corner_radius_all(14)
		draw_style_box(fl, Rect2(Vector2.ZERO, size))
	if not disabled:
		var r := Rect2(Vector2(10, 6), Vector2(size.x - 20, size.y * 0.32))
		draw_style_box(_shine, r)
		if not show_key:
			return
		# SPACE 키캡: 아래 테두리에 걸치게
		var kw := 86.0
		var kr := Rect2(Vector2(size.x * 0.5 - kw * 0.5, size.y - 12.0), Vector2(kw, 26.0))
		draw_style_box(_keycap, kr)
		draw_string(_key_font, kr.position + Vector2(0, 19), "SPACE", HORIZONTAL_ALIGNMENT_CENTER, kw, 15, Color(0.92, 0.85, 1.0))
