## CRT 효과 조정 패널(디버그 창). F7 이나 설정 메뉴 → [CRT 조정] 으로 연다. 왼쪽 위에 뜨고 CRT 레이어보다 위(설정 레이어 100)라 선명하다.
## 위에 프리셋 고르기, 아래에 CrtOverlay.PARAMS 슬라이더. 슬라이더를 만지면 그 프리셋 위에 '손봄' 표시가 붙고 user://crt.cfg 에 저장된다.
## [프리셋 복원] 으로 손본 값을 버리고, [값 복사] 로 crt_overlay.gd 의 PRESETS 에 붙여 넣을 수 있는 사전 문자열을 클립보드에 담는다.
extends Control

const ROW_LABEL_W := 190.0
const ROW_SLIDER_W := 180.0

var crt: CanvasLayer     # CrtOverlay

var _panel: PanelContainer
var _options: OptionButton
var _desc: Label
var _sliders := {}
var _values := {}
var _loading := false


func setup(c: CanvasLayer) -> void:
	crt = c


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	SceneSwitcher.pin(_panel, Vector2(0, 0), Rect2(40, 60, 470, 0))
	_panel.custom_minimum_size = Vector2(470, 0)
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.12, 0.92)
	sb.border_color = Color(0.5, 0.85, 1.0, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_panel.add_child(box)
	box.add_child(_label("CRT 조정  (F7 · F6 다음 프리셋)", 18, Color(0.75, 0.92, 1.0)))

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var pl := _label("프리셋", 14)
	pl.custom_minimum_size = Vector2(60, 0)
	top.add_child(pl)
	_options = OptionButton.new()
	_options.focus_mode = Control.FOCUS_NONE
	_options.custom_minimum_size = Vector2(240, 32)
	for n in crt.preset_names():
		_options.add_item(n)
	_options.item_selected.connect(func(i: int) -> void: crt.apply_preset(i))
	top.add_child(_options)
	box.add_child(top)
	_desc = _label("", 12, Color(0.75, 0.68, 0.9))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(440, 0)
	box.add_child(_desc)
	box.add_child(HSeparator.new())

	for p in crt.PARAMS:
		var key: String = p[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name_l := _label(p[1], 13)
		name_l.custom_minimum_size = Vector2(ROW_LABEL_W, 0)
		row.add_child(name_l)
		var s := HSlider.new()
		s.min_value = p[2]
		s.max_value = p[3]
		s.step = p[4]
		s.custom_minimum_size = Vector2(ROW_SLIDER_W, 18)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.focus_mode = Control.FOCUS_NONE
		s.value_changed.connect(_on_value.bind(key))
		row.add_child(s)
		var val_l := _label("", 13, Color(1.0, 0.9, 0.6))
		val_l.custom_minimum_size = Vector2(52, 0)
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_l)
		box.add_child(row)
		_sliders[key] = s
		_values[key] = val_l

	box.add_child(HSeparator.new())
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	btns.add_child(_button("프리셋 복원", func() -> void: crt.apply_preset(crt.preset)))
	btns.add_child(_button("값 복사", func() -> void:
		DisplayServer.clipboard_set(crt.values_text())
		print("[crt] ", crt.values_text())))
	btns.add_child(_button("다음 (F6)", func() -> void: crt.cycle()))
	box.add_child(btns)
	crt.changed.connect(_sync)
	_sync()


func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_sync()


func is_open() -> bool:
	return _panel.visible


func _on_value(v: float, key: String) -> void:
	(_values[key] as Label).text = str(snappedf(v, 0.001))
	if _loading or is_equal_approx(v, float(crt.P[key])):
		return   # 슬라이더가 같은 값을 다시 알릴 때는 '손봄'으로 치지 않는다
	crt.set_param(key, v)
	_options.select(crt.preset)
	_desc.text = _desc_text()


func _desc_text() -> String:
	var p: Dictionary = crt.PRESETS[crt.preset]
	return ("[손봄]  " if crt.modified else "") + str(p["desc"])


func _sync() -> void:
	_loading = true
	_options.select(crt.preset)
	_desc.text = _desc_text()
	for p in crt.PARAMS:
		var key: String = p[0]
		(_sliders[key] as HSlider).value = float(crt.P[key])
		(_values[key] as Label).text = str(snappedf(float(crt.P[key]), 0.001))
	_loading = false


func _label(text: String, size: int, color := Color(0.92, 0.9, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b
