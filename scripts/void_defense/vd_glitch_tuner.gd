## 피격 글리치 실시간 조정 패널(디버그 창). F9 나 오른쪽 위 설정 버튼 → [글리치 조정] 으로 연다. 배경 조정 패널 오른쪽에 뜬다.
## VDHurtGlitch.PARAMS 표 하나로 슬라이더·저장·복사가 정해진다. 값은 바뀔 때마다 user://vd_glitch.cfg 에 저장된다.
## [약하게]/[세게] 버튼으로 바로 발동해 볼 수 있다 (쿨다운 무시).
## class_name 없음: vd_battle.gd 가 preload 해서 쓴다.
extends Control

const Glitch := preload("res://scripts/void_defense/vd_hurt_glitch.gd")
const ROW_LABEL_W := 210.0
const ROW_SLIDER_W := 170.0

var glitch: Node                 # VDHurtGlitch

var _panel: PanelContainer
var _sliders := {}               # 키 -> HSlider
var _values := {}                # 키 -> Label
var _loading := false


func setup(g: Node) -> void:
	glitch = g


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	SceneSwitcher.pin(_panel, Vector2(0, 0), Rect2(500, 150, 470, 0))   # 배경 조정 패널(40~480) 오른쪽
	_panel.custom_minimum_size = Vector2(470, 0)
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.12, 0.9)
	sb.border_color = Color(1.0, 0.45, 0.8, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_panel.add_child(box)
	box.add_child(_label("피격 글리치 조정  (F9)", 18, Color(1.0, 0.75, 0.92)))
	box.add_child(_label("아군 피격 때 맞은 영웅 카드가 흔들리며 테두리가 가로로 튀는 카툰 글리치", 12, Color(0.75, 0.68, 0.9)))

	for p in Glitch.PARAMS:
		var key: String = p[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name_l := _label(p[1], 14)
		name_l.custom_minimum_size = Vector2(ROW_LABEL_W, 0)
		row.add_child(name_l)
		var s := HSlider.new()
		s.min_value = p[2]
		s.max_value = p[3]
		s.step = p[4]
		s.custom_minimum_size = Vector2(ROW_SLIDER_W, 20)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.focus_mode = Control.FOCUS_NONE
		s.value_changed.connect(_on_value.bind(key))
		row.add_child(s)
		var val_l := _label("", 14, Color(1.0, 0.9, 0.6))
		val_l.custom_minimum_size = Vector2(52, 0)
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_l)
		box.add_child(row)
		_sliders[key] = s
		_values[key] = val_l

	box.add_child(HSeparator.new())
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	btns.add_child(_button("약하게 발동", func() -> void: _test(0.35)))
	btns.add_child(_button("세게 발동", func() -> void: _test(1.0)))
	btns.add_child(_button("기본값", func() -> void:
		glitch.reset_values()
		glitch.save_values()
		_sync()))
	btns.add_child(_button("값 복사", func() -> void:
		DisplayServer.clipboard_set(glitch.values_text())
		print("[glitch] ", glitch.values_text())))
	box.add_child(btns)
	_sync()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_panel.visible = not _panel.visible


func is_open() -> bool:
	return _panel.visible


## 버튼 테스트: 쿨다운을 무시하고 아무 영웅 카드에 우선해서 바로 발동.
func _test(strength: float) -> void:
	glitch.reset_timer()
	var heroes: Array = VDData.HERO_ORDER
	glitch.kick(strength, heroes[randi() % heroes.size()])


func _on_value(v: float, key: String) -> void:
	(_values[key] as Label).text = _fmt(v, key)
	if _loading:
		return
	glitch.P[key] = v
	glitch.save_values()


func _sync() -> void:
	_loading = true
	for p in Glitch.PARAMS:
		var key: String = p[0]
		(_sliders[key] as HSlider).value = float(glitch.P[key])
		(_values[key] as Label).text = _fmt(float(glitch.P[key]), key)
	_loading = false


func _fmt(v: float, key: String) -> String:
	for p in Glitch.PARAMS:
		if p[0] == key:
			return "%d" % roundi(v) if float(p[4]) >= 1.0 else "%.2f" % v
	return str(v)


func _label(text: String, size: int, col := Color(0.9, 0.88, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", VDData.font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b
