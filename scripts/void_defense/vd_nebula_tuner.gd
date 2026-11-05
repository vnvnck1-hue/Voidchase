## 공허 배경 실시간 조정 패널(디버그 창). F10(또는 F2) 이나 오른쪽 위 설정 버튼 → [배경 조정] 으로 연다. 화면 왼쪽에 뜬다.
## [배경] shaders/void_nebula.gdshader
##   모양  : 구름 덩어리 크기 (왼쪽 = 크고 둥근 덩어리, 오른쪽 = 잘고 촘촘한 무늬) → scale
##   속도  : 기체가 흐르고 섞이는 속도 → flow_speed
##   컬러  : 기체의 주 색. 하늘·라일락·빛·알갱이·앞 안개 색은 기본 팔레트와의 색상/채도/밝기 차이를 유지한 채 따라간다
## [앞 안개] shaders/void_vignette.gdshader — 화면 가장자리를 덮는 흐르는 기체 (FOG_PARAMS 표 하나로 슬라이더·저장·복사가 정해진다)
## 위험 연출: danger_flash()(아군 사망 — 잠시 붉고 빠르게), set_boss()(보스 전투 — 더 강렬하고 빠르게)가 패널 값 위에 얹힌다.
## 흐름은 셰이더의 TIME 대신 여기서 쌓은 위상(phase)으로 움직여, 속도가 바뀌어도 무늬가 튀지 않는다.
## 값은 바뀔 때마다 user://vd_nebula.cfg 에 저장되어 다음 실행에도 유지된다. [값 복사] 는 클립보드에 한 줄로 복사한다.
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
## 셰이더 기본값을 못 읽을 때 쓰는 값 (void_nebula.gdshader · void_vignette.gdshader 와 같게)
const FALLBACK := {
	"col_deep": Color(0.054, 0.033, 0.096), "col_night": Color(0.099, 0.065, 0.192), "col_lilac": Color(0.283, 0.195, 0.384),
	"col_gas": Color(0.161, 0.071, 0.525), "col_glow": Color(0.293, 0.277, 0.640),
	"scale": 1.724, "flow_speed": 0.11,
	"strength": 0.82, "reach": 0.33, "wisp_scale": 7.05, "wisp_speed": 0.25, "wisp_amount": 0.84, "wisp_glow": 0.73,
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


func setup(bg: ShaderMaterial, fog: ShaderMaterial) -> void:
	bg_mat = bg
	fog_mat = fog
	for p in PALETTE + ["scale", "flow_speed"]:
		_defaults[p] = _default_of(bg.shader, p, FALLBACK[p])
	for fp in FOG_PARAMS:
		_defaults[fp[0]] = _default_of(fog.shader, fp[0], FALLBACK[fp[0]])
	_defaults["glow_amount"] = _default_of(bg.shader, "glow_amount", 0.8)
	_reset_values()
	_load()


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
	_wisp_phase += dt * float(_fogv["wisp_speed"]) * mul
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
	for fp in FOG_PARAMS:
		_fogv[fp[0]] = float(_defaults[fp[0]])


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
	box.add_child(_label("공허 배경 조정  (F10)", 18, Color(0.75, 0.85, 1.0)))

	box.add_child(_label("배경", 14, Color(0.6, 0.75, 1.0)))
	_l_shape = _label("", 15)
	box.add_child(_l_shape)
	_s_shape = _slider(0.0, 1.0, 0.01, _on_shape)
	box.add_child(_s_shape)
	box.add_child(_hint("← 크고 둥근 덩어리        잘고 촘촘한 무늬 →"))
	_l_speed = _label("", 15)
	box.add_child(_l_speed)
	_s_speed = _slider(0.0, SPEED_MAX, 0.001, _on_speed)
	box.add_child(_s_speed)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_label("컬러 (기체 주 색)", 15))
	_picker = ColorPickerButton.new()
	_picker.custom_minimum_size = Vector2(120, 32)
	_picker.edit_alpha = false
	_picker.focus_mode = Control.FOCUS_NONE
	_picker.color_changed.connect(_on_color)
	row.add_child(_picker)
	box.add_child(row)

	box.add_child(HSeparator.new())
	box.add_child(_label("앞 안개 (가장자리를 덮는 기체 · 색은 컬러를 따라감)", 14, Color(0.6, 0.75, 1.0)))
	for fp in FOG_PARAMS:
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
	var s := "배경: 모양=%.2f (scale %.2f)  속도=%.3f  컬러=#%s  |  앞 안개:" % [_shape, _scale(), _speed, _color.to_html(false)]
	for fp in FOG_PARAMS:
		s += "  %s=%.3f" % [fp[0], _fogv[fp[0]]]
	return s


func _scale() -> float:
	return lerpf(SCALE_MIN, SCALE_MAX, _shape)


func _on_shape(v: float) -> void:
	if _loading:
		return
	_shape = v
	_apply()
	_save()


func _on_speed(v: float) -> void:
	if _loading:
		return
	_speed = v
	_apply()
	_save()


func _on_color(c: Color) -> void:
	_color = c
	_apply()
	_save()


func _on_fog(v: float, key: String) -> void:
	if _loading:
		return
	_fogv[key] = v
	_apply()
	_save()


## 현재 값 → 셰이더 파라미터. 팔레트는 기본 col_gas 와의 HSV 차이를 유지한 채 새 주 색을 따라간다.
func _apply() -> void:
	if bg_mat == null:
		return
	_apply_shader()
	if _l_shape:
		_l_shape.text = "모양 (구름 크기)   %.2f" % _shape
		_l_speed.text = "속도 (흐름)   x%.1f" % (_speed / maxf(float(_defaults["flow_speed"]), 0.0001))
		for fp in FOG_PARAMS:
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
	fog_mat.set_shader_parameter("fog_color", deep.darkened(FOG_DARKEN))
	fog_mat.set_shader_parameter("wisp_color", col.darkened(WISP_DARKEN))
	for fp in FOG_PARAMS:
		fog_mat.set_shader_parameter(fp[0], _fogv[fp[0]])


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
	for fp in FOG_PARAMS:
		(_fog_sliders[fp[0]] as HSlider).value = _fogv[fp[0]]
	_picker.color = _color
	_loading = false


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("nebula", "shape", _shape)
	cf.set_value("nebula", "speed", _speed)
	cf.set_value("nebula", "color", _color)
	for fp in FOG_PARAMS:
		cf.set_value("fog", fp[0], _fogv[fp[0]])
	cf.save(CFG_PATH)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) != OK:
		return
	_shape = clampf(float(cf.get_value("nebula", "shape", _shape)), 0.0, 1.0)
	_speed = clampf(float(cf.get_value("nebula", "speed", _speed)), 0.0, SPEED_MAX)
	_color = cf.get_value("nebula", "color", _color)
	# 예전 저장 파일의 [nebula] fog 는 앞 안개 세기
	_fogv["strength"] = float(cf.get_value("nebula", "fog", _fogv["strength"]))
	for fp in FOG_PARAMS:
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
