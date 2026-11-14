## 선택한 테마의 배경 실시간 조정 패널. F10(또는 F2) / 설정 → [배경 조정].
## [배경] 공허 void_nebula.gdshader / 사막 desert_sand.gdshader
##   모양  : 구름 덩어리 크기 (왼쪽 = 크고 둥근 덩어리, 오른쪽 = 잘고 촘촘한 무늬) → scale
##   속도  : 기체가 흐르고 섞이는 속도 → flow_speed
##   컬러  : 기체의 주 색. 하늘·라일락·빛·알갱이·앞 안개 색은 기본 팔레트와의 색상/채도/밝기 차이를 유지한 채 따라간다
## [앞 안개] 공허 void_vignette.gdshader / 사막 desert_dust.gdshader (FOG_PARAMS가 슬라이더·저장·복사를 정의한다)
##   스타일(2026-11-09): 기체(위 셰이더) / 하프톤(halftone_fog.gdshader, 테마 공통·HALFTONE_PARAMS). 패널의 스타일 버튼과 설정 메뉴 [앞 안개 스타일]로 고른다.
##   스타일별 슬라이더는 uniform 이름이 달라(ht_*) 서로 값이 섞이지 않고, 둘 다 같은 cfg 에 저장된다.
## 위험 연출: danger_flash()(아군 사망 — 잠시 붉고 빠르게), set_boss()(보스 전투 — 더 강렬하고 빠르게)가 패널 값 위에 얹힌다.
## 흐름은 셰이더의 TIME 대신 여기서 쌓은 위상(phase)으로 움직여, 속도가 바뀌어도 무늬가 튀지 않는다.
## 공허는 기존 user://vd_nebula.cfg, 사막은 user://vd_desert.cfg에 따로 저장한다. [값 복사]는 한 줄로 복사한다.
class_name VDNebulaTuner
extends Control

const CFG_PATH := "user://vd_nebula.cfg"
const SCALE_MIN := 0.8
const SCALE_MAX := 3.6
const SPEED_MAX := 0.15
## 컬러를 따라 바뀌는 셰이더 색 (기준은 col_gas)
const PALETTE := ["col_deep", "col_night", "col_lilac", "col_gas", "col_glow"]
## 앞 안개 슬라이더: [셰이더 uniform, 이름, 최소, 최대, 간격]
const FOG_PARAMS := [
	["strength", "세기", 0.0, 1.0, 0.01],
	["reach", "범위 (안쪽으로 파고듦)", 0.0, 1.0, 0.01],
	["wisp_scale", "결 크기 (클수록 잘다)", 0.5, 8.0, 0.05],
	["wisp_speed", "흐름 속도", 0.0, 0.3, 0.002],
	["wisp_amount", "일렁임", 0.0, 1.0, 0.01],
	["wisp_glow", "결 빛", 0.0, 1.0, 0.01],
]
## 하프톤 스타일 슬라이더 (halftone_fog.gdshader)
const HALFTONE_PARAMS := [
	["ht_strength", "세기", 0.0, 1.0, 0.01],
	["ht_reach", "범위 (안쪽으로 파고듦)", 0.0, 1.0, 0.01],
	["ht_size", "도트 간격 (1080p 기준 px)", 4.0, 40.0, 0.5],
	["ht_angle", "격자 각도", 0.0, 90.0, 1.0],
	["ht_light", "밝은 도트 띠", 0.0, 1.0, 0.01],
	["ht_wobble", "경계 일렁임", 0.0, 1.0, 0.01],
	["ht_speed", "흐름 속도", 0.0, 0.3, 0.002],
]
const ALL_FOG_PARAMS := FOG_PARAMS + HALFTONE_PARAMS
## 셰이더 기본값을 못 읽을 때 쓰는 값 (void_nebula.gdshader · void_vignette.gdshader 와 같게)
const FALLBACK := {
	"col_deep": Color(0.054, 0.033, 0.096), "col_night": Color(0.099, 0.065, 0.192), "col_lilac": Color(0.283, 0.195, 0.384),
	"col_gas": Color(0.161, 0.071, 0.525), "col_glow": Color(0.293, 0.277, 0.640),
	"scale": 1.724, "flow_speed": 0.11,
	"strength": 0.82, "reach": 0.33, "wisp_scale": 7.05, "wisp_speed": 0.25, "wisp_amount": 0.84, "wisp_glow": 0.73,
	"ht_strength": 0.92, "ht_reach": 0.33, "ht_size": 14.0, "ht_angle": 45.0, "ht_light": 0.70, "ht_wobble": 0.35, "ht_speed": 0.06,
}
const DESERT_FALLBACK := {
	"col_deep": Color(0.30, 0.13, 0.09), "col_night": Color(0.49, 0.25, 0.145), "col_lilac": Color(0.61, 0.34, 0.20),
	"col_gas": Color(0.68, 0.405, 0.24), "col_glow": Color(0.78, 0.525, 0.33),
	"scale": 1.7, "flow_speed": 0.04, "glow_amount": 0.20,
	"strength": 0.30, "reach": 0.22, "wisp_scale": 2.4, "wisp_speed": 0.07, "wisp_amount": 0.45, "wisp_glow": 0.35,
	"ht_strength": 0.80, "ht_reach": 0.22, "ht_size": 14.0, "ht_angle": 45.0, "ht_light": 0.60, "ht_wobble": 0.35, "ht_speed": 0.06,
}
## 앞 안개 색은 하늘 위쪽(col_deep)보다 조금 더 어둡게, 결의 빛은 기체 색을 어둡게 눌러서
const FOG_DARKEN := 0.15
const WISP_DARKEN := 0.35

## 위험 연출 (패널 값 위에 잠시 얹는다. 저장되지 않음)
##   아군 사망: 붉게 물들고 흐름이 빨라졌다가 천천히 원래대로 (danger_flash)
##   보스 전투: 색이 더 진하고 밝아지며(조금 마젠타 쪽으로) 흐름이 빨라진 채 유지 (set_boss)
const DANGER_RED := Color(0.62, 0.04, 0.10)   # 아군 사망 때 기체 주 색이 향하는 붉은색
const DANGER_SPEED := 3.0                     # 아군 사망 때 흐름 속도 배율 (최대)
const DANGER_IN := 0.25
const DANGER_HOLD := 0.7
const DANGER_OUT := 2.2
const BOSS_SAT := 0.4                         # 보스: 채도 +40%
const BOSS_VAL := 0.8                         # 보스: 밝기 +80%
const BOSS_HUE := 0.035                       # 보스: 색상을 마젠타 쪽으로
const BOSS_SPEED := 1.8                       # 보스: 흐름 속도 배율
const BOSS_FADE := 1.5
const GLOW_BOOST := 0.6                       # 위험 연출 중 기체 빛(glow_amount) 증가

var bg_mat: ShaderMaterial
var fog_mat: ShaderMaterial
var style_setter: Callable      # 스타일 버튼 → VDBattle.set_fog_style (셰이더 교체 후 setup 을 다시 부른다)
var config_directory := "user://"  # 검증 도구는 프로젝트 안의 임시 설정 폴더를 사용한다.
var _profile := "void"
var _config_path := CFG_PATH

var _defaults := {}          # 셰이더 기본값
var _shape := 0.0            # 0..1
var _speed := 0.0            # flow_speed
var _color := Color.WHITE    # 기체 주 색
var _fogv := {}              # 앞 안개 uniform -> 값
var _red := 0.0              # 아군 사망 위험 연출 0..1
var _boss := 0.0             # 보스 전투 연출 0..1
var _red_tween: Tween
var _boss_tween: Tween
var _phase := 0.0            # 배경 흐름 위상 (실시간 x 속도 누적)
var _wisp_phase := 0.0       # 앞 안개 흐름 위상
var _last_us := 0
var _mood_on := false

var _panel: PanelContainer
var _s_shape: HSlider
var _s_speed: HSlider
var _picker: ColorPickerButton
var _l_shape: Label
var _l_speed: Label
var _fog_sliders := {}       # uniform -> HSlider
var _fog_labels := {}        # uniform -> Label
var _loading := false
var _title: Label
var _shape_hint: Label
var _color_caption: Label
var _fog_caption: Label
var _style_buttons: Array[Button] = []


func setup(bg: ShaderMaterial, fog: ShaderMaterial, profile := "void") -> void:
	# 테마 전환 전에 지연 저장을 끝내야 이전 프로필의 조정값이 새 프로필로 유실되지 않는다.
	if _save_queued:
		_flush_save()
	bg_mat = bg
	fog_mat = fog
	_profile = profile
	var config_name := "vd_desert.cfg" if profile == "desert" else ("vd_bio.cfg" if profile == "bio" else "vd_nebula.cfg")
	_config_path = config_directory.path_join(config_name)
	_defaults.clear()
	var fallback: Dictionary = DESERT_FALLBACK if profile == "desert" else FALLBACK
	for p in PALETTE + ["scale", "flow_speed"]:
		_defaults[p] = _default_of(bg.shader, p, fallback[p])
	for fp in ALL_FOG_PARAMS:
		_defaults[fp[0]] = _default_of(fog.shader, fp[0], fallback[fp[0]])
	_defaults["glow_amount"] = _default_of(bg.shader, "glow_amount", fallback.get("glow_amount", 0.8))
	_reset_values()
	_load()
	_sync_controls()
	_apply()


## 아군 사망: 배경·앞 안개가 잠시 붉게 물들고 빠르게 흐르다가 원래대로 돌아온다. 연달아 오면 다시 붉어진다.
func danger_flash() -> void:
	if _red_tween:
		_red_tween.kill()
	_red_tween = create_tween().set_ignore_time_scale(true)
	_red_tween.tween_property(self, "_red", 1.0, DANGER_IN * (1.0 - _red)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_red_tween.tween_interval(DANGER_HOLD)
	_red_tween.tween_property(self, "_red", 0.0, DANGER_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 보스 전투 연출 켜기/끄기 (부드럽게 전환).
func set_boss(on: bool) -> void:
	var target := 1.0 if on else 0.0
	if is_equal_approx(_boss, target) and _boss_tween == null:
		return
	if _boss_tween:
		_boss_tween.kill()
	_boss_tween = create_tween().set_ignore_time_scale(true)
	_boss_tween.tween_property(self, "_boss", target, BOSS_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_boss_tween.finished.connect(func() -> void: _boss_tween = null)


## 위험 연출을 바로 끈다 (새 판 시작 등).
func clear_moods() -> void:
	for tw in [_red_tween, _boss_tween]:
		if tw:
			(tw as Tween).kill()
	_red_tween = null
	_boss_tween = null
	_red = 0.0
	_boss = 0.0
	_apply()


## 위험 연출이 얹힌 기체 주 색.
func _mood_color() -> Color:
	var c := _color
	if _boss > 0.0:
		c = Color.from_hsv(fposmod(c.h + BOSS_HUE * _boss, 1.0), clampf(c.s * (1.0 + BOSS_SAT * _boss), 0.0, 1.0),
			clampf(c.v * (1.0 + BOSS_VAL * _boss), 0.0, 1.0))
	if _red > 0.0:
		c = c.lerp(DANGER_RED, _red)
	return c


func _speed_mul() -> float:
	return (1.0 + (BOSS_SPEED - 1.0) * _boss) * (1.0 + (DANGER_SPEED - 1.0) * _red)


func _process(_delta: float) -> void:
	if bg_mat == null:
		return
	# 실시간으로 위상을 쌓는다 (히트스탑·배속과 무관하게 일정하게 흐름)
	var now := Time.get_ticks_usec()
	var dt := 0.0 if _last_us == 0 else minf((now - _last_us) / 1000000.0, 0.1)
	_last_us = now
	var mul := _speed_mul()
	_phase += dt * _speed * mul
	_wisp_phase += dt * float(_fogv[_speed_key()]) * mul
	bg_mat.set_shader_parameter("phase", _phase)
	fog_mat.set_shader_parameter("wisp_phase", _wisp_phase)
	# 연출 중에는 매 프레임, 끝난 직후 한 번 더 (원래 색으로 정확히 되돌리기)
	var active := _red > 0.0 or _boss > 0.0
	if active or _mood_on:
		_apply_shader()
	_mood_on = active


## 셰이더에 적힌 기본값. 색(vec4)은 Vector4 로 올 수 있어 Color 로 바꾸고, 못 읽으면(헤드리스 등) fallback.
static func _default_of(sh: Shader, p: String, fallback: Variant) -> Variant:
	var v: Variant = RenderingServer.shader_get_parameter_default(sh.get_rid(), p)
	if v == null:
		return fallback
	if v is Vector4:
		return Color(v.x, v.y, v.z, v.w)
	if fallback is Color and not (v is Color):
		return fallback
	return v


func _reset_values() -> void:
	_shape = inverse_lerp(SCALE_MIN, SCALE_MAX, float(_defaults["scale"]))
	_speed = float(_defaults["flow_speed"])
	_color = _defaults["col_gas"]
	for fp in ALL_FOG_PARAMS:
		_fogv[fp[0]] = float(_defaults[fp[0]])


func _halftone() -> bool:
	return VDWorldTheme.fog_style == VDWorldTheme.FogStyle.HALFTONE


## 현재 스타일의 슬라이더 목록 / 흐름 속도 키
func _style_params() -> Array:
	return HALFTONE_PARAMS if _halftone() else FOG_PARAMS


func _speed_key() -> String:
	return "ht_speed" if _halftone() else "wisp_speed"


func _ready() -> void:
	# offset 까지 0 으로 맞춰야 화면 전체 크기가 된다(크기가 0 이면 오른쪽에 pin 한 버튼이 화면 왼쪽 밖으로 나간다)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	SceneSwitcher.pin(_panel, Vector2(0, 0), Rect2(40, 150, 440, 0))   # 왼쪽: 오른쪽 위 설정 메뉴와 겹치지 않게
	_panel.custom_minimum_size = Vector2(440, 0)
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.12, 0.88)
	sb.border_color = Color(0.45, 0.6, 1.0, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_panel.add_child(box)
	_title = _label("", 18, Color(0.75, 0.85, 1.0))
	box.add_child(_title)

	box.add_child(_label("배경", 14, Color(0.6, 0.75, 1.0)))
	_l_shape = _label("", 15)
	box.add_child(_l_shape)
	_s_shape = _slider(0.0, 1.0, 0.01, _on_shape)
	box.add_child(_s_shape)
	_shape_hint = _hint("")
	box.add_child(_shape_hint)
	_l_speed = _label("", 15)
	box.add_child(_l_speed)
	_s_speed = _slider(0.0, SPEED_MAX, 0.001, _on_speed)
	box.add_child(_s_speed)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_color_caption = _label("", 15)
	row.add_child(_color_caption)
	_picker = ColorPickerButton.new()
	_picker.custom_minimum_size = Vector2(120, 32)
	_picker.edit_alpha = false
	_picker.focus_mode = Control.FOCUS_NONE
	_picker.color_changed.connect(_on_color)
	row.add_child(_picker)
	box.add_child(row)

	box.add_child(HSeparator.new())
	_fog_caption = _label("", 14, Color(0.6, 0.75, 1.0))
	box.add_child(_fog_caption)
	# 스타일 버튼: 기체 / 하프톤 (설정 메뉴 [앞 안개 스타일]과 같은 값)
	var style_row := HBoxContainer.new()
	style_row.add_theme_constant_override("separation", 8)
	style_row.add_child(_label("스타일", 15))
	var group := ButtonGroup.new()
	for i in VDWorldTheme.FOG_LABELS.size():
		var b := Button.new()
		b.text = VDWorldTheme.FOG_LABELS[i]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(90, 30)
		b.pressed.connect(_on_style.bind(i))
		style_row.add_child(b)
		_style_buttons.append(b)
	box.add_child(style_row)
	for fp in ALL_FOG_PARAMS:
		var key: String = fp[0]
		var l := _label("", 15)
		box.add_child(l)
		_fog_labels[key] = l
		var s := _slider(fp[2], fp[3], fp[4], _on_fog.bind(key))
		box.add_child(s)
		_fog_sliders[key] = s

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	var b_reset := Button.new()
	b_reset.text = "기본값"
	b_reset.focus_mode = Control.FOCUS_NONE
	b_reset.pressed.connect(func() -> void:
		_reset_values()
		_sync_controls()
		_apply()
		_save())
	btns.add_child(b_reset)
	var b_copy := Button.new()
	b_copy.text = "값 복사"
	b_copy.focus_mode = Control.FOCUS_NONE
	b_copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(values_text())
		print("[nebula] ", values_text()))
	btns.add_child(b_copy)
	box.add_child(btns)

	_sync_controls()
	_apply()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_F10 or event.keycode == KEY_F2):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_panel.visible = not _panel.visible


func is_open() -> bool:
	return _panel.visible


func values_text() -> String:
	var s := "배경: 모양=%.2f (scale %.2f)  속도=%.3f  컬러=#%s  |  앞 안개(%s):" % [_shape, _scale(), _speed, _color.to_html(false), VDWorldTheme.FOG_LABELS[VDWorldTheme.fog_style]]
	for fp in _style_params():
		s += "  %s=%.3f" % [fp[0], _fogv[fp[0]]]
	return s


func _scale() -> float:
	return lerpf(SCALE_MIN, SCALE_MAX, _shape)


func _on_shape(v: float) -> void:
	if _loading:
		return
	_shape = v
	_apply()
	_save_soon()


func _on_speed(v: float) -> void:
	if _loading:
		return
	_speed = v
	_apply()
	_save_soon()


func _on_color(c: Color) -> void:
	if _loading:
		return
	_color = c
	_apply()
	_save_soon()


func _on_fog(v: float, key: String) -> void:
	if _loading:
		return
	_fogv[key] = v
	_apply()
	_save_soon()


func _on_style(style: int) -> void:
	if _loading or style == VDWorldTheme.fog_style:
		return
	if style_setter.is_valid():
		style_setter.call(style)   # 셰이더를 바꾸고 setup() 을 다시 불러 이 패널도 새로 맞춘다
	else:
		VDWorldTheme.select_fog_style(style)
		_apply()


## 현재 값 → 셰이더 파라미터. 팔레트는 기본 col_gas 와의 HSV 차이를 유지한 채 새 주 색을 따라간다.
func _apply() -> void:
	if bg_mat == null:
		return
	_apply_shader()
	if _l_shape:
		var desert := _profile == "desert"
		var theme_label := "사막" if desert else ("바이오 연구실" if _profile == "bio" else "공허")
		_title.text = "%s 배경 조정  (F10)" % theme_label
		_shape_hint.text = "← 넓은 모래 물결        촘촘한 모래 물결 →" if desert else "← 크고 둥근 덩어리        잘고 촘촘한 무늬 →"
		_color_caption.text = "컬러 (모래 주 색)" if desert else "컬러 (기체 주 색)"
		if _halftone():
			_fog_caption.text = "앞 안개 · 하프톤 (망점 그라데이션 · 색은 컬러를 따라감)"
		else:
			_fog_caption.text = "앞 모래바람 (가장자리 먼지 · 색은 컬러를 따라감)" if desert else "앞 안개 (가장자리를 덮는 기체 · 색은 컬러를 따라감)"
		_l_shape.text = "모양 (%s 크기)   %.2f" % ["모래 물결" if desert else "구름", _shape]
		_l_speed.text = "속도 (흐름)   x%.1f" % (_speed / maxf(float(_defaults["flow_speed"]), 0.0001))
		var shown := _style_params()
		for fp in ALL_FOG_PARAMS:
			var on: bool = fp in shown
			(_fog_labels[fp[0]] as Label).visible = on
			(_fog_sliders[fp[0]] as HSlider).visible = on
			(_fog_labels[fp[0]] as Label).text = "%s   %.2f" % [fp[1], _fogv[fp[0]]]


## 셰이더 파라미터만 (위험 연출 중에는 매 프레임 부른다). 색은 위험 연출이 얹힌 주 색을 따라간다.
func _apply_shader() -> void:
	var col := _mood_color()
	bg_mat.set_shader_parameter("scale", _scale())
	bg_mat.set_shader_parameter("flow_speed", _speed)
	bg_mat.set_shader_parameter("glow_amount", float(_defaults["glow_amount"]) * (1.0 + GLOW_BOOST * maxf(_red, _boss)))
	var base: Color = _defaults["col_gas"]
	for p in PALETTE:
		bg_mat.set_shader_parameter(p, _follow(_defaults[p], base, col))
	var deep := _follow(_defaults["col_deep"], base, col)
	if _halftone():
		# 하프톤: 안개 본색은 어두운 톤, 밝은 도트는 기체 빛 색 — 두 톤 차이가 커야 망점이 또렷하다
		var dark := _follow(_defaults["col_lilac"], base, col) if _profile == "desert" else deep
		fog_mat.set_shader_parameter("fog_color", dark)
		fog_mat.set_shader_parameter("wisp_color", _follow(_defaults["col_glow"], base, col))
	elif _profile == "desert":
		fog_mat.set_shader_parameter("fog_color", _follow(_defaults["col_lilac"], base, col))
		fog_mat.set_shader_parameter("wisp_color", col)
	else:
		fog_mat.set_shader_parameter("fog_color", deep.darkened(FOG_DARKEN))
		fog_mat.set_shader_parameter("wisp_color", col.darkened(WISP_DARKEN))
	for fp in _style_params():
		fog_mat.set_shader_parameter(fp[0], _fogv[fp[0]])


## 입장 연출(VDFogReveal: 안개가 중앙에서 열림)이 쓰는, 지금 저장값 기준 하프톤 앞 안개 파라미터 (색 + ht_*).
## 앞 안개 스타일이 기체여도 하프톤 슬라이더 값(같은 cfg 에 저장)으로 준다. 색은 _apply_shader 의 하프톤 분기와 같다.
func halftone_params() -> Dictionary:
	var col := _mood_color()
	var base: Color = _defaults["col_gas"]
	var deep := _follow(_defaults["col_deep"], base, col)
	var out := {
		"fog_color": _follow(_defaults["col_lilac"], base, col) if _profile == "desert" else deep,
		"wisp_color": _follow(_defaults["col_glow"], base, col),
	}
	for fp in HALFTONE_PARAMS:
		out[fp[0]] = _fogv[fp[0]]
	return out


static func _follow(orig: Color, base: Color, now: Color) -> Color:
	var h := fposmod(orig.h - base.h + now.h, 1.0)
	var s := clampf(orig.s * (now.s / maxf(base.s, 0.001)), 0.0, 1.0)
	var v := clampf(orig.v * (now.v / maxf(base.v, 0.001)), 0.0, 1.0)
	return Color.from_hsv(h, s, v)


func _sync_controls() -> void:
	if _s_shape == null:
		return
	_loading = true
	_s_shape.value = _shape
	_s_speed.value = _speed
	for fp in ALL_FOG_PARAMS:
		(_fog_sliders[fp[0]] as HSlider).value = _fogv[fp[0]]
	_picker.color = _color
	for i in _style_buttons.size():
		_style_buttons[i].button_pressed = i == VDWorldTheme.fog_style
	_loading = false


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("nebula", "shape", _shape)
	cf.set_value("nebula", "speed", _speed)
	cf.set_value("nebula", "color", _color)
	for fp in ALL_FOG_PARAMS:
		cf.set_value("fog", fp[0], _fogv[fp[0]])
	cf.save(_config_path)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(_config_path) != OK:
		return
	_shape = clampf(float(cf.get_value("nebula", "shape", _shape)), 0.0, 1.0)
	_speed = clampf(float(cf.get_value("nebula", "speed", _speed)), 0.0, SPEED_MAX)
	var col = cf.get_value("nebula", "color", _color)
	if col is Color:   # 손으로 고친·깨진 파일의 엉뚱한 값은 무시
		_color = col
	# 예전 저장 파일의 [nebula] fog 는 앞 안개 세기
	_fogv["strength"] = float(cf.get_value("nebula", "fog", _fogv["strength"]))
	for fp in ALL_FOG_PARAMS:
		_fogv[fp[0]] = clampf(float(cf.get_value("fog", fp[0], _fogv[fp[0]])), fp[2], fp[3])


func _label(text: String, size: int, col := Color(0.88, 0.9, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", VDData.font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _hint(text: String) -> Label:
	var l := _label(text, 12, Color(0.6, 0.66, 0.85))
	return l


func _slider(lo: float, hi: float, step: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(400, 20)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(cb)
	return s


## 슬라이더를 끄는 동안 값이 바뀔 때마다 파일을 쓰지 않고, 멈춘 뒤 한 번 쓴다 (씬을 떠날 때 남은 것도 쓴다).
const SAVE_DELAY := 0.4
var _save_queued := false


func _save_soon() -> void:
	if not is_inside_tree():
		_flush_save()
		return
	if _save_queued:
		return
	_save_queued = true
	get_tree().create_timer(SAVE_DELAY, true, false, true).timeout.connect(_flush_save)


func _flush_save() -> void:
	_save_queued = false
	_save()


func _exit_tree() -> void:
	if _save_queued:
		_flush_save()
