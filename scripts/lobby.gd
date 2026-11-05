## 게임 로비: 각 모드(씬)로 들어가는 메뉴. 목록은 SceneSwitcher.SCENES 를 그대로 쓴다.
## 카드 클릭 / 입장 버튼 / 숫자키로 진입, 모드 안에서는 Esc 로 로비 복귀.
extends Control

const BG_TOP := Color(0.36, 0.24, 0.52)
const BG_BOTTOM := Color(0.14, 0.08, 0.24)
const ACCENT := Color(0.85, 0.7, 1.0)
const CARD_COLORS := [Color(0.95, 0.47, 0.66), Color(0.62, 0.42, 0.92), Color(0.5, 0.9, 1.0)]
const STANDING_ART := "res://assets/textures/standing/char_01.png"

var _cards: Array[PanelContainer] = []


func _ready() -> void:
	# 화면 전체를 덮는다(부모가 Control 이 아니면 뷰포트 기준). 화면 비율이 바뀌면(울트라와이드 등) 같이 늘어나고,
	# 왼쪽 메뉴는 왼쪽에, 달·스탠딩 원화는 오른쪽에, 안내 문구는 아래에 붙는다(SceneSwitcher.pin).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font = VDData.font()
	theme.default_font_size = 20
	self.theme = theme
	_build_background()
	_build_header()
	_build_cards()
	_build_footer()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_TOP
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var grad := TextureRect.new()
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new()
	g.set_color(0, Color(BG_TOP, 0.0))
	g.set_color(1, BG_BOTTOM)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.15)
	gt.fill_to = Vector2(0, 1)
	grad.texture = gt
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)
	# 달 (오른쪽 위에 붙는 자리 안에 그린다)
	var moon_slot := Control.new()
	moon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneSwitcher.pin(moon_slot, Vector2(1, 0), Rect2(1470, 80, 300, 300))
	add_child(moon_slot)
	var moon := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 48:
		pts.append(Vector2(150, 150) + Vector2.from_angle(TAU * i / 48.0) * 150.0)
	moon.polygon = pts
	moon.color = Color(0.55, 0.42, 0.72)
	moon_slot.add_child(moon)
	# 스탠딩 원화 (있으면 오른쪽에 장식으로)
	if ResourceLoader.exists(STANDING_ART):
		var art := TextureRect.new()
		art.texture = load(STANDING_ART)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		SceneSwitcher.pin(art, Vector2(1, 1), Rect2(1300, 140, 620, 980))
		art.modulate = Color(1, 1, 1, 0.92)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)


func _build_header() -> void:
	_label("미소녀 카드게임", Vector2(100, 90), 24, ACCENT)
	_label("PROTOTYPE LOBBY", Vector2(100, 124), 64, Color(0.98, 0.95, 1.0))
	_label("모드를 선택하세요", Vector2(104, 206), 22, Color(0.85, 0.8, 0.95))


func _build_cards() -> void:
	var modes: Array = SceneSwitcher.SCENES
	var y := 290.0
	# 카드가 늘어도 안내 문구(1000) 위까지만 쓰도록 간격을 줄인다 (4장일 때 176)
	var step := minf(176.0, 690.0 / (modes.size() - 1))
	for i in range(1, modes.size()):
		var m: Dictionary = modes[i]
		var col: Color = CARD_COLORS[(i - 1) % CARD_COLORS.size()]
		var card := PanelContainer.new()
		card.position = Vector2(100, y)
		card.custom_minimum_size = Vector2(1000, step - 26.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.06, 0.18, 0.78)
		sb.border_color = Color(col, 0.7)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 28
		sb.content_margin_right = 24
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel", sb)
		card.mouse_entered.connect(_on_card_hover.bind(card, col, true))
		card.mouse_exited.connect(_on_card_hover.bind(card, col, false))
		card.gui_input.connect(_on_card_input.bind(i))
		add_child(card)
		_cards.append(card)

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 24)
		card.add_child(hb)
		var num := Label.new()
		num.text = str(i)
		num.add_theme_font_size_override("font_size", 54)
		num.add_theme_color_override("font_color", col)
		num.custom_minimum_size = Vector2(60, 0)
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(num)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_child(vb)
		var title := Label.new()
		title.text = m["title"]
		title.add_theme_font_size_override("font_size", 32)
		title.add_theme_color_override("font_color", Color(0.98, 0.96, 1.0))
		vb.add_child(title)
		var desc := Label.new()
		desc.text = m["desc"]
		desc.add_theme_font_size_override("font_size", 18)
		desc.add_theme_color_override("font_color", Color(0.8, 0.76, 0.9))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(desc)
		var btn := Button.new()
		btn.text = "입장  ▶"
		btn.custom_minimum_size = Vector2(170, 64)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 26)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(_enter.bind(i))
		hb.add_child(btn)
		y += step


func _build_footer() -> void:
	var hint := _label("숫자키 1~5 로 바로 입장 · 모드 안에서 Esc 로 로비 복귀 · F11 전체화면", Vector2(104, 1000), 16, Color(0.7, 0.65, 0.85))
	SceneSwitcher.pin(hint, Vector2(0, 1), Rect2(104, 1000, 900, 24))
	var quit := Button.new()
	quit.text = "게임 종료"
	# 카드(x 100~1100)와 겹치지 않도록 카드 오른쪽 옆에 둔다
	quit.position = Vector2(1120, 912)
	quit.size = Vector2(180, 56)
	quit.focus_mode = Control.FOCUS_NONE
	quit.add_theme_font_size_override("font_size", 22)
	quit.pressed.connect(func() -> void: get_tree().quit())
	add_child(quit)


func _label(text: String, pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l


func _on_card_hover(card: PanelContainer, col: Color, on: bool) -> void:
	var sb: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
	sb.border_color = Color(col, 1.0) if on else Color(col, 0.7)
	sb.bg_color = Color(0.16, 0.1, 0.26, 0.9) if on else Color(0.1, 0.06, 0.18, 0.78)
	card.add_theme_stylebox_override("panel", sb)


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_enter(index)


func _enter(index: int) -> void:
	print("[lobby] enter mode %d" % index)
	SceneSwitcher.switch_to(index)


func _unhandled_input(event: InputEvent) -> void:
	# 로비에서는 숫자키가 모드 번호 (모드 전환은 로비에서만 한다)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				_enter(1)
			KEY_2, KEY_KP_2:
				_enter(2)
			KEY_3, KEY_KP_3:
				_enter(3)
			KEY_4, KEY_KP_4:
				_enter(4)
			KEY_5, KEY_KP_5:
				_enter(5)
