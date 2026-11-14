## VFX 쇼룸: 게임에 실제로 쓰이는 VFX 를 칸(vd_showroom_tile.gd)마다 하나씩, 전투와 같은 호출로 반복 재생해 한눈에 본다.
## 목록은 scripts/void_defense/vd_showroom_catalog.gd 의 ENTRIES (분류 · 이름 · 쓰이는 곳 · 재생 함수).
##   위쪽 분류 탭으로 거르고, 칸을 누르면 크게 보기 (소리·히트스탑·슬로모션까지 전투 그대로). 크게 보기에서 ◀ ▶ / 방향키로 넘기기.
##   화면 밖으로 스크롤된 칸은 멈춰 둔다 (칸마다 SubViewport 라서). Esc: 크게 보기 닫기 → 로비
extends Control

const Tile := preload("res://scripts/void_defense/vd_showroom_tile.gd")
const Catalog := preload("res://scripts/void_defense/vd_showroom_catalog.gd")

const BG := Color(0.05, 0.03, 0.1)
const ACCENT := Color(0.85, 0.7, 1.0)
const CARD_BG := Color(0.1, 0.06, 0.18, 0.92)
const COLS := 4
const TILE_PX := Vector2i(424, 238)
const TOP_H := 132.0

var _catalog
var _cat := "전체"
var _tabs: HBoxContainer
var _scroll: ScrollContainer
var _grid: GridContainer
var _cards: Array[Control] = []
var _tiles: Array = []
var _count: Label
var _focus_layer: CanvasLayer
var _focus_tile
var _focus_index := -1
var _focus_list: Array = []      # 크게 보기에서 넘길 순서 (지금 탭의 항목들)
var _focus_title: Label
var _focus_desc: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font = VDData.font()
	theme.default_font_size = 18
	self.theme = theme
	_catalog = Catalog.new()
	add_child(_catalog)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build_top()
	_build_grid()
	_show_cat("전체")


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- 위쪽 (제목 · 분류 탭)

func _build_top() -> void:
	var title := _label(self, "VFX 쇼룸", 40, Color(0.98, 0.95, 1.0))
	SceneSwitcher.pin(title, Vector2(0, 0), Rect2(40, 18, 400, 50))
	_count = _label(self, "", 16, Color(0.72, 0.66, 0.88))
	SceneSwitcher.pin(_count, Vector2(0, 0), Rect2(250, 34, 900, 24))
	var back := Button.new()
	back.text = "◀ 로비"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void: SceneSwitcher.go_lobby())
	SceneSwitcher.pin(back, Vector2(1, 0), Rect2(1720, 18, 120, 42))   # 오른쪽 끝(톱니 설정 버튼) 옆
	add_child(back)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	SceneSwitcher.pin(_tabs, Vector2(0, 0), Rect2(40, 76, 1840, 44))
	add_child(_tabs)
	for c in ["전체"] + Catalog.CATS:
		var b := Button.new()
		b.text = c
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_stylebox_override("normal", _flat(Color(0.12, 0.08, 0.2, 0.9), Color(1, 1, 1, 0.12)))
		b.add_theme_stylebox_override("hover", _flat(Color(0.2, 0.13, 0.32, 0.95), Color(0.8, 0.7, 1.0, 0.5)))
		b.add_theme_stylebox_override("pressed", _flat(Color(0.36, 0.22, 0.58, 1.0), Color(0.9, 0.8, 1.0, 0.9)))
		b.pressed.connect(_show_cat.bind(c))
		_tabs.add_child(b)


func _build_grid() -> void:
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = TOP_H
	_scroll.offset_left = 24
	_scroll.offset_right = -24
	_scroll.offset_bottom = -12
	add_child(_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(center)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	center.add_child(_grid)
	_scroll.resized.connect(_fit_columns)


## 화면이 넓으면(울트라와이드) 줄마다 칸을 더 놓는다
func _fit_columns() -> void:
	_grid.columns = maxi(2, int((_scroll.size.x + 14.0) / (TILE_PX.x + 14.0 + 16.0)))


func _show_cat(c: String) -> void:
	_cat = c
	for b in _tabs.get_children():
		b.button_pressed = b.text == c
	for card in _cards:
		card.queue_free()
	_cards.clear()
	_tiles.clear()
	var list := _entries_of(c)
	for i in list.size():
		_add_card(list[i], i)
	_count.text = "%d 개  ·  칸을 누르면 크게 보기 (소리 · 히트스탑 포함)" % list.size()
	_scroll.scroll_vertical = 0


func _entries_of(c: String) -> Array:
	var out := []
	for e in _catalog.entries:
		if c == "전체" or e["cat"] == c:
			out.append(e)
	return out


func _add_card(e: Dictionary, index: int) -> void:
	var card := PanelContainer.new()
	var sb := _flat(CARD_BG, Color(Catalog.cat_color(e["cat"]), 0.45))
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_open_focus(_entries_of(_cat), index))
	card.mouse_entered.connect(func() -> void: sb.border_color = Color(Catalog.cat_color(e["cat"]), 1.0))
	card.mouse_exited.connect(func() -> void: sb.border_color = Color(Catalog.cat_color(e["cat"]), 0.45))
	_grid.add_child(card)
	_cards.append(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)
	var tile = Tile.new()
	tile.setup(e, TILE_PX)
	vb.add_child(tile)
	_tiles.append(tile)
	tile.start()
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(head)
	var t := _label(head, e["title"], 19, Color(0.98, 0.95, 1.0))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	var tag := _label(head, e["cat"], 13, Catalog.cat_color(e["cat"]))
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var used := _label(vb, e["used"], 13, Color(0.7, 0.66, 0.84))
	used.custom_minimum_size = Vector2(TILE_PX.x, 0)
	used.clip_text = true
	used.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	used.tooltip_text = e["used"]


func _process(_delta: float) -> void:
	# 화면 밖 칸은 멈춘다 (크게 보기 중에는 뒤 칸 전부)
	var view := _scroll.get_global_rect()
	for tile in _tiles:
		if is_instance_valid(tile):
			tile.set_active(_focus_tile == null and view.intersects(tile.get_global_rect()))


# ---------------------------------------------------------------- 크게 보기

func _open_focus(list: Array, index: int) -> void:
	_focus_list = list
	if _focus_layer == null:
		_build_focus()
	_focus_layer.visible = true
	_focus_at(index)


func _build_focus() -> void:
	_focus_layer = CanvasLayer.new()
	_focus_layer.layer = 20
	add_child(_focus_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	_focus_layer.add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.01, 0.05, 0.94)
	shade.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_focus())
	root.add_child(shade)
	var holder := Control.new()
	holder.name = "Holder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneSwitcher.pin(holder, Vector2(0.5, 0.5), Rect2(160, 90, 1600, 900))
	root.add_child(holder)
	_focus_title = _label(root, "", 30, Color(0.98, 0.95, 1.0))
	SceneSwitcher.pin(_focus_title, Vector2(0.5, 0.0), Rect2(160, 22, 1300, 44))
	_focus_desc = _label(root, "", 16, Color(0.75, 0.7, 0.9))
	_focus_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SceneSwitcher.pin(_focus_desc, Vector2(0.5, 1.0), Rect2(160, 1000, 1600, 70))
	var prev := _nav_button(root, "◀", func() -> void: _focus_step(-1))
	SceneSwitcher.pin(prev, Vector2(0, 0.5), Rect2(40, 500, 80, 80))
	var next := _nav_button(root, "▶", func() -> void: _focus_step(1))
	SceneSwitcher.pin(next, Vector2(1, 0.5), Rect2(1800, 500, 80, 80))
	var close := _nav_button(root, "닫기", _close_focus)
	SceneSwitcher.pin(close, Vector2(1, 0), Rect2(1600, 18, 110, 46))


func _focus_at(index: int) -> void:
	_focus_index = posmod(index, _focus_list.size())
	var e: Dictionary = _focus_list[_focus_index]
	if is_instance_valid(_focus_tile):
		_focus_tile.queue_free()
	Engine.time_scale = 1.0
	var holder: Control = _focus_layer.get_child(0).get_node("Holder")
	_focus_tile = Tile.new()
	_focus_tile.setup(e, Vector2i(1600, 900), true)
	holder.add_child(_focus_tile)
	_focus_tile.start()
	_focus_title.text = "%s   ·   %s   (%d / %d)" % [e["title"], e["cat"], _focus_index + 1, _focus_list.size()]
	_focus_desc.text = "쓰이는 곳: " + e["used"]


func _focus_step(d: int) -> void:
	_focus_at(_focus_index + d)


func _close_focus() -> void:
	if is_instance_valid(_focus_tile):
		_focus_tile.queue_free()
	_focus_tile = null
	Engine.time_scale = 1.0
	_focus_layer.visible = false


func _input(event: InputEvent) -> void:
	if _focus_tile == null or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
			_close_focus()
			get_viewport().set_input_as_handled()   # SceneSwitcher 의 Esc(로비로) 보다 먼저
		KEY_LEFT, KEY_A:
			_focus_step(-1)
		KEY_RIGHT, KEY_D, KEY_SPACE:
			_focus_step(1)


# ---------------------------------------------------------------- 도우미

func _label(parent: Node, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _nav_button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_stylebox_override("normal", _flat(Color(0.12, 0.08, 0.2, 0.9), Color(1, 1, 1, 0.15)))
	b.add_theme_stylebox_override("hover", _flat(Color(0.24, 0.15, 0.4, 0.95), Color(0.8, 0.7, 1.0, 0.6)))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _flat(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	return sb
