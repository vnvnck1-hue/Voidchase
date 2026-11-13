## 허브·대화·결과 화면이 같이 쓰는 사이파이 UI 조각: 색, 패널 스타일, 글자, 버튼, 화면 덧판(스캔선·비네트).
## 색은 모니터룸 원화(남보라 바탕 + 청록·핫핑크 네온)와 전투 HUD(보라·굵은 외곽선)에 맞춘다.
class_name UiKit
extends RefCounted

const GameFonts := preload("res://scripts/game_fonts.gd")

const INK := Color(0.045, 0.035, 0.1)
const PANEL := Color(0.085, 0.065, 0.17, 0.94)
const PANEL_SOFT := Color(0.12, 0.09, 0.24, 0.82)
const LINE := Color(0.62, 0.5, 0.95, 0.55)
const CYAN := Color(0.42, 0.95, 0.93)
const PINK := Color(1.0, 0.36, 0.62)
const VIOLET := Color(0.68, 0.45, 1.0)
const GOLD := Color(1.0, 0.82, 0.38)
const CREAM := Color(1.0, 0.97, 0.9)
const DIM := Color(0.72, 0.68, 0.88)
const MUTED := Color(0.5, 0.46, 0.68)


static func box(bg := PANEL, border := LINE, width := 2, radius := 10, margin := 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


## 굵은 검은 외곽선 + 아래 그림자: 전투 HUD 의 만화 패널 느낌.
static func comic_box(bg: Color, radius := 12, margin := 18) -> StyleBoxFlat:
	var sb := box(bg, Color(0.03, 0.02, 0.07), 3, radius, margin)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(0, 6)
	return sb


static func label(text: String, size: int, col := CREAM, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func outlined(l: Label, col := INK, size := 8) -> Label:
	l.add_theme_color_override("font_outline_color", col)
	l.add_theme_constant_override("outline_size", size)
	return l


## 작은 태그 글자 (영문 대문자, 자간 넓게): "CASE 01 · 접수됨" 같은 머리표.
static func tag(text: String, col := CYAN, size := 15) -> Label:
	var l := label(text, size, col, GameFonts.bold())
	return l


## 납작한 메뉴 버튼 (탭·보조 버튼). accent 는 호버·눌림 때 테두리 색.
static func button(text: String, accent := CYAN, size := 22, min_size := Vector2(0, 52)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_stylebox_override("normal", box(Color(0.1, 0.08, 0.2, 0.88), Color(accent, 0.35), 2, 8, 12))
	b.add_theme_stylebox_override("hover", box(Color(0.17, 0.12, 0.32, 0.96), accent, 2, 8, 12))
	b.add_theme_stylebox_override("pressed", box(Color(accent.darkened(0.55), 0.96), accent, 2, 8, 12))
	b.add_theme_stylebox_override("disabled", box(Color(0.07, 0.06, 0.13, 0.7), Color(1, 1, 1, 0.08), 2, 8, 12))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## 화면 전체 덧판: 가는 스캔선 + 가장자리 어둡게 + 아래쪽 색 번짐. 마우스는 통과.
static func screen_fx(scan := 0.06, vignette := 0.55, tint := Color(0.1, 0.05, 0.25, 0.0)) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float scan = 0.06;
uniform float vignette = 0.55;
uniform vec4 tint : source_color = vec4(0.0);
void fragment() {
	vec2 p = UV - 0.5;
	float v = smoothstep(0.35, 0.95, length(p * vec2(1.0, 0.82))) * vignette;
	float line = step(0.5, fract(FRAGCOORD.y / 3.0)) * scan;
	float roll = smoothstep(0.0, 0.04, abs(fract(UV.y - TIME * 0.05) - 0.5) - 0.46) * 0.05;
	float a = clamp(v + line + roll, 0.0, 1.0);
	COLOR = vec4(mix(vec3(0.02, 0.01, 0.06), tint.rgb, tint.a), max(a, tint.a * 0.35));
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("scan", scan)
	m.set_shader_parameter("vignette", vignette)
	m.set_shader_parameter("tint", tint)
	r.material = m
	return r


## 그림을 화면에 꽉 채우는 TextureRect (비율 유지, 넘치는 쪽은 잘림).
static func cover(tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## 얼굴 칩: 전신 그림에서 얼굴 둘레만 둥글게 오려 그린다 (말풍선·분대 카드). face/face_r 은 CaseData.CAST 값.
static func face_chip(who: String, px: float) -> Control:
	var c := CaseData.cast(who)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: Color = c["color"]
	var path := String(c["portrait"])
	var tex: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
	holder.draw.connect(func() -> void:
		var center := Vector2(px, px) * 0.5
		holder.draw_circle(center, px * 0.5, Color(0.03, 0.02, 0.07))
		holder.draw_circle(center, px * 0.5 - 3.0, col.darkened(0.45))
		if tex == null:
			# 초상이 없는 화자(의뢰인·단말): 신호 파형
			var pts := PackedVector2Array()
			for i in 25:
				var x := -0.32 + 0.64 * i / 24.0
				pts.append(center + Vector2(x * px, sin(i * 1.3) * px * 0.12 * (1.0 - absf(x) * 2.2)))
			holder.draw_polyline(pts, col.lightened(0.3), 3.0, true))
	if tex:
		# 원 안으로 자르기: clip_children 을 쓰는 둥근 패널 안에 그림을 놓는다
		var clip := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.WHITE
		sb.set_corner_radius_all(int(px * 0.5))
		clip.add_theme_stylebox_override("panel", sb)
		clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		clip.position = Vector2(4, 4)
		clip.size = Vector2(px - 8, px - 8)
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(clip)
		var img := TextureRect.new()
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ts := tex.get_size()
		var face: Vector2 = c["face"]
		var view := ts.x * float(c["face_r"]) * 2.0          # 원화에서 오려 낼 정사각형 한 변(px)
		var k := (px - 8.0) / view
		img.size = ts * k
		img.position = Vector2(px - 8, px - 8) * 0.5 - face * ts * k
		clip.add_child(img)
	return holder
