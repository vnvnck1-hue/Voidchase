## 필드 연구실 (2026-11-11, 로비 카드): 전투의 배경이 되는 것들 — 타일 · 배경(하늘·지면) · 뒤/앞 프랍 · 앞 안개 — 의
## 색조·채도·명도·대비·불투명도·덧색을 슬라이더로 바꾸며, VFX 와 캐릭터가 얼마나 잘 보이는지 실제 전투 화면에서 바로 확인한다.
## 미리보기는 진짜 전투(VoidDefense.tscn)를 전투 연습장 모드(VDSandbox, 왼쪽 패널)로 띄운 것: 영웅 4명이 고른 적과 계속 싸운다.
## 값은 vd_field_look.gd 가 테마(공허 / 사막)별로 user://vd_field_look.cfg 에 저장하고 본 전투가 그대로 읽는다 (바꾸면 곧 자동 저장).
##   H 패널 숨기기 · C 원본과 비교(보정 끄기) · F10 배경 무늬·앞 안개 조정 패널(기존 VDNebulaTuner)
## 2026-11-12: 위쪽 [패링 연출] 탭 — 패링에 쓰이는 시각효과·VFX 수치 전부(vd_parry_fx.gd PARAMS)를 실제 전투 화면에서 바꾼다.
##   공허 응시자를 불러 다섯 패턴을 버튼으로 바로 시전해 보며 조절한다. 바꾼 값은 곧 user://parry_fx.json 에 저장되어 본 전투에 반영된다.
extends Node

const ParryFx := preload("res://scripts/void_defense/vd_parry_fx.gd")

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
var mode := "look"                # look 배경 색 · parry 패링 연출
var parry_group := ""
var _mode_tabs := {}
var _look_box: VBoxContainer
var _parry_box: VBoxContainer
var _parry_rows: VBoxContainer
var _parry_pick: OptionButton
var _parry_sliders := {}
var _parry_labels := {}
var _parry_dirty := false
var _chk_auto: CheckBox
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
	if _dirty or _parry_dirty:
		_save_in -= delta
		if _save_in <= 0.0:
			_flush()


func _exit_tree() -> void:
	FieldLook.bypass = false
	if battle and battle.parry:
		battle.parry.auto_parry = -1.0
	if _dirty or _parry_dirty:
		_flush()


func _flush() -> void:
	if _parry_dirty:
		_parry_dirty = false
		ParryFx.save()
	if not _dirty:
		if _status:
			_status.text = "패링 연출 저장됨 — 본 전투에 그대로 반영됩니다"
		return
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


# ---------------------------------------------------------------- 패링 연출 탭 (테스트도 이 함수들을 쓴다)

func set_mode(m: String) -> void:
	mode = m
	_look_box.visible = m == "look"
	_parry_box.visible = m == "parry"
	for k: String in _mode_tabs:
		(_mode_tabs[k] as Button).set_pressed_no_signal(k == m)
	if m == "parry":
		_rebuild_parry_rows()


func parry_groups() -> Array:
	var out := []
	for p: Array in ParryFx.PARAMS:
		if not out.has(p[1]):
			out.append(p[1])
	return out


func select_parry_group(g: String) -> void:
	parry_group = g
	_rebuild_parry_rows()


func set_parry_value(key: String, v: float) -> void:
	ParryFx.set_value(key, v)
	if _parry_sliders.has(key):
		(_parry_sliders[key] as HSlider).set_value_no_signal(v)
	_update_parry_label(key)
	_parry_dirty = true
	_save_in = SAVE_DELAY
	_status.text = "바뀜 — 곧 자동 저장 (다음 패링부터 적용)"


## [값 저장] 버튼: 자동 저장을 기다리지 않고 지금 바로 user://parry_fx.json 에 쓴다 (본 전투가 읽는 파일).
func save_parry() -> bool:
	_parry_dirty = false
	var ok: bool = ParryFx.save()
	if _status:
		_status.text = ("패링 값 저장 완료 (%s) — 본 전투에 그대로 반영됩니다" % Time.get_time_string_from_system()) if ok 			else "저장 실패 — 파일을 쓸 수 없습니다 (%s)" % ParryFx.SAVE_PATH
	return ok


func reset_parry(only_group := false) -> void:
	for p: Array in ParryFx.PARAMS:
		if not only_group or p[1] == parry_group:
			ParryFx.set_value(p[0], float(p[6]))
	_parry_dirty = true
	_save_in = SAVE_DELAY
	_rebuild_parry_rows()


func gazer() -> VDUnit:
	for e in battle.enemies:
		if is_instance_valid(e) and e.alive and e.id == "gazer":
			return e
	return null


## 연습장의 적을 공허 응시자로 바꿔 다시 세운다.
func summon_gazer() -> void:
	for i in VDSandbox.ENEMY_SETS.size():
		if VDSandbox.ENEMY_SETS[i][1] == ["gazer"]:
			VDSandbox._set_i = i
	VDSandbox._hp_i = 2
	if battle.sandbox:
		battle.sandbox.respawn_enemies()
	_status.text = "공허 응시자를 불러왔습니다 (체력 ×10)"


## 패턴 하나를 바로 시전한다 (ram · beam · barrage · gale · sweep).
func cast_pattern(pattern: String) -> bool:
	var u := gazer()
	if u == null:
		_status.text = "공허 응시자가 없습니다 — [응시자 불러오기] 를 먼저 누르세요"
		return false
	var ok := battle.state == VDBattle.State.BATTLE and battle.enemy_skills.gazer.cast(u, pattern)
	_status.text = ("시전: %s" % VDGazerSkills.NAMES[pattern]) if ok else "지금은 시전할 수 없습니다 (등장 중 · 시전 중 · 기절)"
	return ok


func set_auto_parry(on: bool) -> void:
	battle.parry.auto_parry = 0.93 if on else -1.0
	if _chk_auto:
		_chk_auto.set_pressed_no_signal(on)


func _rebuild_parry_rows() -> void:
	_loading = true
	for c in _parry_rows.get_children():
		_parry_rows.remove_child(c)
		c.queue_free()
	_parry_sliders.clear()
	_parry_labels.clear()
	var groups := parry_groups()
	if parry_group == "" or not groups.has(parry_group):
		parry_group = "7 충돌 화면" if groups.has("7 충돌 화면") else String(groups[0])
	_parry_pick.select(groups.find(parry_group))
	for p: Array in ParryFx.PARAMS:
		if p[1] != parry_group:
			continue
		var key: String = p[0]
		var lab := _label("", 14)
		_parry_rows.add_child(lab)
		_parry_labels[key] = lab
		var sl := HSlider.new()
		sl.min_value = p[3]
		sl.max_value = p[4]
		sl.step = p[5]
		sl.value = ParryFx.g(key)
		sl.custom_minimum_size = Vector2(0, 20)
		sl.focus_mode = Control.FOCUS_NONE
		sl.value_changed.connect(func(v: float) -> void:
			if not _loading:
				set_parry_value(key, v))
		_parry_rows.add_child(sl)
		_parry_sliders[key] = sl
		_update_parry_label(key)
	_loading = false


func _update_parry_label(key: String) -> void:
	if not _parry_labels.has(key):
		return
	for p: Array in ParryFx.PARAMS:
		if p[0] == key:
			var v := ParryFx.g(key)
			var changed := not is_equal_approx(v, float(p[6]))
			(_parry_labels[key] as Label).text = "%s   %s" % [p[2], str(snappedf(v, 0.001))]
			(_parry_labels[key] as Label).add_theme_color_override("font_color", Color(1.0, 0.9, 0.55) if changed else Color(0.88, 0.9, 1.0))


func _build_parry_box(box: VBoxContainer) -> void:
	_parry_box = VBoxContainer.new()
	_parry_box.add_theme_constant_override("separation", 6)
	_parry_box.visible = false
	box.add_child(_parry_box)
	var hint := _label("패링에 쓰이는 시각효과·VFX 를 전부 여기서 조절한다. 아래 버튼으로 공허 응시자의 패턴을 바로 시전해 확인. 별이 뜨면 노려진 영웅의 Z X C V.", 13, Color(0.75, 0.78, 0.9))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_parry_box.add_child(hint)
	var row0 := HBoxContainer.new()
	row0.add_theme_constant_override("separation", 6)
	_parry_box.add_child(row0)
	var bt_sum := _button("응시자 불러오기", summon_gazer)
	bt_sum.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row0.add_child(bt_sum)
	_chk_auto = CheckBox.new()
	_chk_auto.text = "자동으로 받아치기"
	_chk_auto.focus_mode = Control.FOCUS_NONE
	_chk_auto.toggled.connect(set_auto_parry)
	row0.add_child(_chk_auto)
	for names: Array in [["ram", "beam"], ["barrage", "gale", "sweep"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_parry_box.add_child(row)
		for n: String in names:
			var bt := _button(VDGazerSkills.NAMES[n], cast_pattern.bind(n))
			bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(bt)
	_parry_box.add_child(_label("조절할 연출", 15, Color(0.7, 0.8, 1.0)))
	_parry_pick = OptionButton.new()
	_parry_pick.focus_mode = Control.FOCUS_NONE
	for g in parry_groups():
		_parry_pick.add_item(String(g))
	_parry_pick.item_selected.connect(func(i: int) -> void: select_parry_group(String(parry_groups()[i])))
	_parry_box.add_child(_parry_pick)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_parry_box.add_child(scroll)
	_parry_rows = VBoxContainer.new()
	_parry_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_parry_rows.add_theme_constant_override("separation", 2)
	scroll.add_child(_parry_rows)
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	_parry_box.add_child(row3)
	var bt_save := _button("값 저장", func() -> void: save_parry())
	bt_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bt_save.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	bt_save.tooltip_text = "지금 값을 바로 저장한다 (바꾼 값은 잠시 뒤 자동 저장도 된다)"
	row3.add_child(bt_save)
	for pair in [["이 묶음 기본값", reset_parry.bind(true)], ["전체 기본값", reset_parry.bind(false)]]:
		var bt := _button(pair[0], pair[1])
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row3.add_child(bt)
	row3.add_child(_button("값 복사", func() -> void:
		DisplayServer.clipboard_set(ParryFx.describe())
		_status.text = "기본값과 다른 패링 값을 클립보드에 복사했습니다"))


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

	# 위쪽 탭: 배경 색 / 패링 연출
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	box.add_child(mode_row)
	for pair in [["look", "배경 색"], ["parry", "패링 연출"]]:
		var mb := _button(pair[1], set_mode.bind(pair[0]))
		mb.toggle_mode = true
		mb.button_pressed = pair[0] == "look"
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode_row.add_child(mb)
		_mode_tabs[pair[0]] = mb
	_look_box = VBoxContainer.new()
	_look_box.add_theme_constant_override("separation", 6)
	box.add_child(_look_box)
	_build_parry_box(box)

	# 테마
	var theme_row := HBoxContainer.new()
	theme_row.add_theme_constant_override("separation", 6)
	_look_box.add_child(theme_row)
	theme_row.add_child(_label("테마", 15, Color(0.7, 0.8, 1.0)))
	for i in VDWorldTheme.LABELS.size():
		var bt := _button(VDWorldTheme.LABELS[i], set_theme.bind(i))
		bt.toggle_mode = true
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		theme_row.add_child(bt)
		_theme_buttons.append(bt)

	# 요소 탭 (3 x 2)
	_look_box.add_child(_label("조절할 요소", 15, Color(0.7, 0.8, 1.0)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_look_box.add_child(grid)
	for g: Array in FieldLook.GROUPS:
		var bt := _button(g[1], select_group.bind(g[0]))
		bt.toggle_mode = true
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(bt)
		_tabs[g[0]] = bt
	_group_hint = _label("", 13, Color(0.75, 0.78, 0.9))
	_group_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_look_box.add_child(_group_hint)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	_look_box.add_child(_rows)

	var reset_row := HBoxContainer.new()
	reset_row.add_theme_constant_override("separation", 6)
	_look_box.add_child(reset_row)
	for pair in [["이 요소 초기화", reset_group], ["테마 전체 초기화", reset_all]]:
		var bt := _button(pair[0], pair[1])
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reset_row.add_child(bt)

	_chk_bypass = CheckBox.new()
	_chk_bypass.text = "원본 보기 (보정 끄고 비교)  [C]"
	_chk_bypass.focus_mode = Control.FOCUS_NONE
	_chk_bypass.toggled.connect(set_bypass)
	_look_box.add_child(_chk_bypass)

	var more_row := HBoxContainer.new()
	more_row.add_theme_constant_override("separation", 6)
	_look_box.add_child(more_row)
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
