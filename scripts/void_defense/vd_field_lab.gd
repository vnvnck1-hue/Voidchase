## 필드 연구실 (2026-11-11, 로비 카드): 전투의 배경이 되는 것들 — 타일 · 배경(하늘·지면) · 뒤/앞 프랍 · 앞 안개 — 의
## 색조·채도·명도·대비·불투명도·덧색을 슬라이더로 바꾸며, VFX 와 캐릭터가 얼마나 잘 보이는지 실제 전투 화면에서 바로 확인한다.
## 미리보기는 진짜 전투(VoidDefense.tscn)를 전투 연습장 모드(VDSandbox, 왼쪽 패널)로 띄운 것: 영웅 4명이 고른 적과 계속 싸운다.
## 값은 vd_field_look.gd 가 테마(공허 / 사막)별로 user://vd_field_look.cfg 에 저장하고 본 전투가 그대로 읽는다 (바꾸면 곧 자동 저장).
##   H 패널 숨기기 · C 원본과 비교(보정 끄기) · F10 배경 무늬·앞 안개 조정 패널(기존 VDNebulaTuner)
extends Node

const FieldLook := preload("res://scripts/void_defense/vd_field_look.gd")
const BATTLE := "res://scenes/void_defense/VoidDefense.tscn"
const PANEL_RECT := Rect2(1464, 76, 440, 0)
const ACCENT := Color(0.55, 0.9, 1.0)
const SAVE_DELAY := 0.6

var battle: VDBattle
var group := "tile"
var _profile := ""
var _layer: CanvasLayer
var _panel: PanelContainer
var _rows: VBoxContainer          # 고른 요소의 슬라이더 줄
var _group_hint: Label
var _status: Label
var _tabs := {}                   # group -> Button
var _theme_buttons: Array[Button] = []
var _chk_bypass: CheckBox
var _sliders := {}                # key -> HSlider
var _labels := {}                 # key -> Label
var _picker: ColorPickerButton
var _loading := false
var _dirty := false
var _save_in := 0.0


func _ready() -> void:
	# 전투 연습장으로 연다: 영웅 4명 모두. 연습장 패널에서 캐릭터·적을 바꿀 수 있다
	VDBattle.sandbox_request = VDData.HERO_ORDER.duplicate()
	battle = (load(BATTLE) as PackedScene).instantiate()
	add_child(battle)
	_profile = _current_profile()
	_build_ui()
	_rebuild_rows()
	print("[field-lab] ready  profile=%s" % _profile)


func _current_profile() -> String:
	return VDWorldTheme.profile(battle.background_theme)


func _process(delta: float) -> void:
	# 설정 메뉴에서 테마를 바꿔도 따라간다
	var p := _current_profile()
	if p != _profile:
		_profile = p
		_rebuild_rows()
	if _dirty:
		_save_in -= delta
		if _save_in <= 0.0:
			_flush()


func _exit_tree() -> void:
	FieldLook.bypass = false
	if _dirty:
		_flush()


func _flush() -> void:
	_dirty = false
	FieldLook.save()
	if _status:
		_status.text = "저장됨 — 본 전투에 그대로 반영됩니다"


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_H:
			_panel.visible = not _panel.visible
			get_viewport().set_input_as_handled()
		KEY_C:
			set_bypass(not FieldLook.bypass)
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- 값 바꾸기 (테스트도 이 함수들을 쓴다)

func set_value(g: String, key: String, value: Variant) -> void:
	FieldLook.set_v(_profile, g, key, value)
	# 지금 보이는 요소면 슬라이더·색 버튼도 따라 움직인다
	if g == group:
		if _sliders.has(key):
			(_sliders[key] as HSlider).set_value_no_signal(float(value))
			_update_label(key)
		elif key == "tint" and _picker:
			_picker.color = value
	_changed()


func set_bypass(on: bool) -> void:
	FieldLook.bypass = on
	if _chk_bypass:
		_chk_bypass.set_pressed_no_signal(on)
	battle.apply_field_look()
	_status.text = "원본 보기 — 보정을 잠시 껐습니다 (C 로 되돌리기)" if on else "보정 적용 중"


func select_group(g: String) -> void:
	group = g
	_rebuild_rows()


func set_theme(i: int) -> void:
	battle.set_background_theme(i)
	_profile = _current_profile()
	_rebuild_rows()


func reset_group() -> void:
	FieldLook.reset(_profile, group)
	_changed()
	_rebuild_rows()


func reset_all() -> void:
	FieldLook.reset(_profile)
	_changed()
	_rebuild_rows()


func _changed() -> void:
	battle.apply_field_look()
	_dirty = true
	_save_in = SAVE_DELAY
	if _status:
		_status.text = "바뀜 — 곧 자동 저장"
	_refresh_tab_marks()


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 46   # 전투 연습장 패널(45) 위, 설정 메뉴(100) 아래
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = VDData.font()
	theme.default_font_size = 16
	root.theme = theme
	_layer.add_child(root)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.12, 0.92)
	sb.border_color = Color(ACCENT, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = Vector2(PANEL_RECT.size.x, 0)
	SceneSwitcher.pin(_panel, Vector2(1, 0), PANEL_RECT)
	root.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)

	box.add_child(_label("필드 연구실", 24, Color(1.0, 0.92, 0.6)))
	var intro := _label("전투 배경 요소의 색을 조절해 VFX·캐릭터가 잘 보이게 맞춘다. 바꾼 값은 자동 저장되어 본 전투에 반영된다.", 13, Color(0.78, 0.8, 0.95))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)

	# 테마
	var theme_row := HBoxContainer.new()
	theme_row.add_theme_constant_override("separation", 6)
	box.add_child(theme_row)
	theme_row.add_child(_label("테마", 15, Color(0.7, 0.8, 1.0)))
	for i in VDWorldTheme.LABELS.size():
		var bt := _button(VDWorldTheme.LABELS[i], set_theme.bind(i))
		bt.toggle_mode = true
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		theme_row.add_child(bt)
		_theme_buttons.append(bt)

	# 요소 탭 (3 x 2)
	box.add_child(_label("조절할 요소", 15, Color(0.7, 0.8, 1.0)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for g: Array in FieldLook.GROUPS:
		var bt := _button(g[1], select_group.bind(g[0]))
		bt.toggle_mode = true
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(bt)
		_tabs[g[0]] = bt
	_group_hint = _label("", 13, Color(0.75, 0.78, 0.9))
	_group_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_group_hint)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	box.add_child(_rows)

	var reset_row := HBoxContainer.new()
	reset_row.add_theme_constant_override("separation", 6)
	box.add_child(reset_row)
	for pair in [["이 요소 초기화", reset_group], ["테마 전체 초기화", reset_all]]:
		var bt := _button(pair[0], pair[1])
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reset_row.add_child(bt)

	_chk_bypass = CheckBox.new()
	_chk_bypass.text = "원본 보기 (보정 끄고 비교)  [C]"
	_chk_bypass.focus_mode = Control.FOCUS_NONE
	_chk_bypass.toggled.connect(set_bypass)
	box.add_child(_chk_bypass)

	var more_row := HBoxContainer.new()
	more_row.add_theme_constant_override("separation", 6)
	box.add_child(more_row)
	var bt_neb := _button("배경 무늬·안개 조정  [F10]", func() -> void: battle.nebula_tuner.toggle())
	bt_neb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more_row.add_child(bt_neb)
	more_row.add_child(_button("값 복사", func() -> void:
		DisplayServer.clipboard_set(FieldLook.values_text(_profile))
		_status.text = "값을 클립보드에 복사했습니다"))

	_status = _label("H 패널 숨기기 · 왼쪽 패널에서 캐릭터·적 바꾸기", 13, Color(1.0, 0.85, 0.45))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)


## 고른 요소의 슬라이더 줄을 다시 만든다 (요소·테마가 바뀔 때).
func _rebuild_rows() -> void:
	_loading = true
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	_sliders.clear()
	_labels.clear()
	for i in _theme_buttons.size():
		_theme_buttons[i].set_pressed_no_signal(i == battle.background_theme)
	for g: String in _tabs:
		(_tabs[g] as Button).set_pressed_no_signal(g == group)
	_group_hint.text = FieldLook.GROUP_HINTS.get(group, "")
	for p: Array in FieldLook.params_of(group):
		var key: String = p[0]
		var lab := _label("", 15)
		_rows.add_child(lab)
		_labels[key] = lab
		var s := HSlider.new()
		s.min_value = p[2]
		s.max_value = p[3]
		s.step = p[4]
		s.value = float(FieldLook.get_v(_profile, group, key))
		s.custom_minimum_size = Vector2(0, 22)
		s.focus_mode = Control.FOCUS_NONE
		s.value_changed.connect(_on_slider.bind(key))
		_rows.add_child(s)
		_sliders[key] = s
		_update_label(key)
		if key == "tint_amount":
			# 덧색: 세기 슬라이더 바로 아래 색 고르기
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_rows.add_child(row)
			row.add_child(_label("덧색 (이 색 쪽으로 물들인다)", 14, Color(0.8, 0.82, 0.95)))
			_picker = ColorPickerButton.new()
			_picker.custom_minimum_size = Vector2(120, 28)
			_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_picker.edit_alpha = false
			_picker.focus_mode = Control.FOCUS_NONE
			_picker.color = FieldLook.get_v(_profile, group, "tint")
			_picker.color_changed.connect(func(c: Color) -> void:
				if not _loading:
					set_value(group, "tint", c))
			row.add_child(_picker)
	_refresh_tab_marks()
	_loading = false


func _on_slider(v: float, key: String) -> void:
	if _loading:
		return
	FieldLook.set_v(_profile, group, key, v)
	_update_label(key)
	_changed()


func _update_label(key: String) -> void:
	for p: Array in FieldLook.params_of(group):
		if p[0] == key:
			var v := float(FieldLook.get_v(_profile, group, key))
			var changed := not is_equal_approx(v, float(p[5]))
			(_labels[key] as Label).text = "%s   %s" % [p[1], String(p[6]) % v]
			(_labels[key] as Label).add_theme_color_override("font_color", Color(1.0, 0.9, 0.55) if changed else Color(0.88, 0.9, 1.0))


## 기본값에서 바뀐 요소의 탭에 ● 표시.
func _refresh_tab_marks() -> void:
	for g: Array in FieldLook.GROUPS:
		var bt: Button = _tabs.get(g[0])
		if bt:
			bt.text = String(g[1]) + ("" if FieldLook.is_default(_profile, g[0]) else " ●")


func _label(text: String, size: int, col := Color(0.88, 0.9, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	b.custom_minimum_size = Vector2(0, 34)
	b.pressed.connect(cb)
	return b
