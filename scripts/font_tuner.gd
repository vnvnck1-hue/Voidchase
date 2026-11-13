## 글꼴 바꾸기 패널. F5 나 설정 메뉴 → [글꼴 바꾸기] 로 연다. CRT 조정 패널 오른쪽에 뜨고, 설정 레이어(100) 안이라 CRT 위에서도 선명하다.
## 맨 위 [조합] 으로 미리 짠 조합을 한 번에 고르고, 아래 역할(본문 · 강조 · 숫자·타이틀)마다 한글 글꼴과 영어·숫자 글꼴을 따로 고른다.
## 고르는 즉시 게임 화면 전체에 반영되고 user://fonts.cfg 에 저장된다 (scripts/game_fonts.gd). 미리보기 줄은 그 역할 글꼴로 그린다.
extends Control

const GameFonts := preload("res://scripts/game_fonts.gd")
const PANEL_RECT := Rect2(530, 60, 660, 0)   # CRT 조정 패널(40..510) 옆
const COL_W := 270.0

var _panel: PanelContainer
var _preset: OptionButton
var _ko := {}       # 역할 id -> OptionButton
var _latin := {}
var _syncing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	SceneSwitcher.pin(_panel, Vector2(0, 0), PANEL_RECT)
	_panel.custom_minimum_size = Vector2(PANEL_RECT.size.x, 0)
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.12, 0.94)
	sb.border_color = Color(1.0, 0.72, 0.4, 0.65)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)
	box.add_child(_label("글꼴 바꾸기  (F5)", 18, Color(1.0, 0.86, 0.62)))

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var pl := _label("조합", 14)
	pl.custom_minimum_size = Vector2(60, 0)
	top.add_child(pl)
	_preset = _options(GameFonts.preset_names())
	_preset.custom_minimum_size = Vector2(300, 34)
	_preset.item_selected.connect(func(i: int) -> void:
		if not _syncing:
			GameFonts.apply_preset(i)
			_sync())
	top.add_child(_preset)
	box.add_child(top)

	var ko_names := []
	for k in GameFonts.KO:
		ko_names.append(k[1])
	var la_names := []
	for k in GameFonts.LATIN:
		la_names.append(k[1])
	for r in GameFonts.ROLES:
		var rid: String = r[0]
		box.add_child(HSeparator.new())
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		head.add_child(_label(r[1], 16, Color(0.8, 0.92, 1.0)))
		var d := _label(r[2], 14, Color(0.72, 0.68, 0.88))
		d.size_flags_vertical = Control.SIZE_SHRINK_END
		head.add_child(d)
		box.add_child(head)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_label("한글", 14))
		var ko := _options(ko_names)
		ko.custom_minimum_size = Vector2(COL_W, 32)
		ko.item_selected.connect(func(i: int) -> void:
			if not _syncing:
				GameFonts.set_role(rid, GameFonts.KO[i][0])
				_sync())
		row.add_child(ko)
		row.add_child(_label("영어·숫자", 14))
		var la := _options(la_names)
		la.custom_minimum_size = Vector2(COL_W - 40.0, 32)
		la.item_selected.connect(func(i: int) -> void:
			if not _syncing:
				GameFonts.set_role(rid, "", GameFonts.LATIN[i][0])
				_sync())
		row.add_child(la)
		box.add_child(row)
		_ko[rid] = ko
		_latin[rid] = la
		var pv := Label.new()
		pv.text = r[6]
		pv.add_theme_font_override("font", GameFonts.role(rid))
		pv.add_theme_font_size_override("font_size", 26)
		pv.add_theme_color_override("font_color", Color.WHITE)
		pv.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.2))
		pv.add_theme_constant_override("outline_size", 6)
		box.add_child(pv)

	box.add_child(HSeparator.new())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	foot.add_child(_button("기본값으로", func() -> void:
		GameFonts.apply_preset(0)
		_sync()))
	foot.add_child(_button("닫기 (F5)", toggle))
	var note := _label("고르면 바로 적용 · user://fonts.cfg 에 저장", 13, Color(0.66, 0.62, 0.8))
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(note)
	box.add_child(foot)
	_sync()


func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_sync()


func is_open() -> bool:
	return _panel.visible


## 바깥(설정 메뉴의 [글꼴 조합])에서 조합을 바꿨을 때 고르기 칸을 다시 맞춘다.
func refresh() -> void:
	_sync()


func _sync() -> void:
	_syncing = true
	_preset.select(GameFonts.preset_index())   # -1 = 직접 고름 (빈칸으로 보인다)
	if GameFonts.preset_index() < 0:
		_preset.text = "직접 고름"
	for r in GameFonts.ROLES:
		(_ko[r[0]] as OptionButton).select(GameFonts.ko_index(r[0]))
		(_latin[r[0]] as OptionButton).select(GameFonts.latin_index(r[0]))
	_syncing = false


func _options(items: Array) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.fit_to_longest_item = false
	o.clip_text = true
	for it in items:
		o.add_item(it)
	return o


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
