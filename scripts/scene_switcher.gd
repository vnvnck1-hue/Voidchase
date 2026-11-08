## Autoload: 로비와 각 모드 씬 사이를 오가고, 오른쪽 위 작은 설정(톱니) 버튼과 설정 메뉴를 띄운다.
## 모드 전환은 로비에서만 한다: 어디서든 Esc 로 로비로 나가 카드를 골라 들어간다(로비는 숫자키로도 입장). F11 은 전체화면.
## 설정 메뉴: 각 씬이 add_setting() 으로 자기 항목(배경 조정 등)을 넣고, 그 아래에 전체화면·로비로·게임 종료가 붙는다.
##   씬 항목은 그 씬(owner)이 트리에서 빠질 때 저절로 지워진다. 메뉴가 열려 있을 때 Esc 는 메뉴만 닫는다.
## 화면 대응: 기본은 stretch aspect "expand"(project.godot) 라서 울트라와이드·4:3 에서도 검은 띠 없이 화면을 채운다.
## 원화 폭이 정해져 있어 넓히면 가장자리가 드러나는 씬만 SCENES 의 "aspect": "keep" 으로 16:9 를 유지한다.
## UI 는 1920x1080 기준 좌표로 짠 뒤 pin() 으로 화면 가장자리·가운데에 붙인다.
## 로비에서 모드로 들어갈 때는 페이크 로딩 화면(scripts/loading_screen.gd, 약 3초)을 거친다. 로비로 나갈 때는 바로 바뀐다.
## SCENES 에 "loading": false 인 씬(연출 연구실 같은 도구)은 로딩 화면 없이 바로 들어간다.
extends CanvasLayer

const LOBBY := 0
const SCENES := [
	{"name": "Lobby", "path": "res://scenes/Lobby.tscn", "title": "로비", "desc": "모드 선택 화면"},
	{"name": "Touch_Game_demo", "path": "res://scenes/Touch_Game_demo.tscn", "title": "터치 게임 데모", "desc": "몬스터를 클릭해 때리는 Unity 포팅 데모. 파티클·히트스톱·카메라 셰이크."},
	{"name": "Touch_Game_demo_anim", "path": "res://scenes/Touch_Game_demo_anim.tscn", "title": "터치 게임 · 캐릭터 선택", "desc": "넓은 배경 + 캐릭터 선택창 + 스탠딩 원화 등장 연출.", "aspect": "keep"},
	{"name": "VoidDefense_greybox", "path": "res://scenes/void_defense/VoidDefense.tscn", "title": "VOID DEFENSE (그레이박스)", "desc": "절차 생성 방을 전진하며 싸우는 자동전투 디펜스. 배치 → 전투 → 갈림길 선택. 유닛은 원화 조립 테스트의 캐릭터·몬스터."},
	{"name": "VoidDefense_visual", "path": "res://scenes/void_defense/VoidDefenseVisualTest.tscn", "title": "VOID DEFENSE (원화 조립 테스트)", "desc": "컨셉 원화 분리본 64장을 assembly.json 좌표대로 조립하고 절차 아이들·위빙을 얹은 화면. R 보조 레이어 · H HUD · O 1:1 · G 리그 피벗 · A 애니메이션.", "aspect": "keep"},
	{"name": "FxLab", "path": "res://scenes/void_defense/FxLab.tscn", "title": "연출 연구실", "desc": "몬스터 등장 · 초궁극기 컷인 같은 연출을 목록에서 골라 타이밍·세기를 슬라이더로 바꾸며 실시간 반복 재생. 저장하면 VOID DEFENSE 전투에 반영.", "loading": false},
]
const DESIGN := Vector2(1920, 1080)
const GEAR_RECT := Rect2(1860, 16, 44, 44)       # 설정 버튼 (오른쪽 위 끝)
const MENU_RECT := Rect2(1600, 68, 304, 0)       # 설정 메뉴 (버튼 바로 아래, 높이는 내용만큼)
const MENU_BG := Color(0.07, 0.05, 0.13, 0.98)
const MENU_BORDER := Color(0.62, 0.5, 0.95, 0.7)
const LoadingScreen := preload("res://scripts/loading_screen.gd")
## 씬 파일을 매번 다시 파싱하지 않도록 PackedScene 을 미리 들고 있는다.
var _packed: Array[PackedScene] = []
var _root: Control
var _gear: Button
var _menu: PanelContainer
var _menu_box: VBoxContainer
## 씬이 넣은 설정 항목: {who, text, action, state}
var _items: Array[Dictionary] = []
## 떠 있는 로딩 화면 (없으면 null). 이 동안은 다른 전환·Esc 를 받지 않는다.
var _loading: LoadingScreen


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = VDData.font()
	theme.default_font_size = 18
	_root.theme = theme
	add_child(_root)
	_build_gear()
	_build_menu()
	for sc in SCENES:
		_packed.append(load(sc["path"]))
	get_tree().node_added.connect(_on_node_added)
	_refresh()


func _build_gear() -> void:
	_gear = Button.new()
	_gear.focus_mode = Control.FOCUS_NONE
	_gear.tooltip_text = "설정"
	_gear.add_theme_stylebox_override("normal", _flat(Color(0.08, 0.05, 0.15, 0.55), Color(1, 1, 1, 0.18)))
	_gear.add_theme_stylebox_override("hover", _flat(Color(0.18, 0.12, 0.3, 0.8), Color(0.8, 0.7, 1.0, 0.6)))
	_gear.add_theme_stylebox_override("pressed", _flat(Color(0.25, 0.17, 0.4, 0.9), Color(0.8, 0.7, 1.0, 0.9)))
	pin(_gear, Vector2(1, 0), GEAR_RECT)
	_gear.pressed.connect(func() -> void: set_menu_open(not _menu.visible))
	_gear.draw.connect(_draw_gear)   # 글꼴에 톱니 글자가 없을 수 있어서 직접 그린다
	_root.add_child(_gear)


func _draw_gear() -> void:
	var c := _gear.size * 0.5
	var col := Color(0.92, 0.88, 1.0, 0.95)
	var pts := PackedVector2Array()
	var teeth := 8
	for i in teeth * 4:
		# 톱니 하나 = 바깥 두 점 + 안쪽 두 점
		var a := TAU * i / (teeth * 4.0)
		var r := 13.0 if (i % 4) < 2 else 9.5
		pts.append(c + Vector2.from_angle(a + TAU / (teeth * 8.0)) * r)
	_gear.draw_colored_polygon(pts, col)
	_gear.draw_circle(c, 4.2, Color(0.1, 0.07, 0.18))


func _build_menu() -> void:
	_menu = PanelContainer.new()
	var sb := _flat(MENU_BG, MENU_BORDER)
	sb.set_content_margin_all(12)
	_menu.add_theme_stylebox_override("panel", sb)
	pin(_menu, Vector2(1, 0), MENU_RECT)
	_menu.visible = false
	_root.add_child(_menu)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 6)
	_menu.add_child(_menu_box)


func _flat(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	return sb


## 설정 메뉴에 항목을 넣는다. state 를 주면 켜짐/꺼짐 토글(CheckButton)로, 없으면 누르면 메뉴가 닫히는 버튼으로 보인다.
## who 가 트리에서 빠지면(씬 전환) 항목도 지워진다.
func add_setting(who: Node, text: String, action: Callable, state := Callable()) -> void:
	var first := _items.all(func(it: Dictionary) -> bool: return it["who"] != who)
	_items.append({"who": who, "text": text, "action": action, "state": state})
	if first:
		who.tree_exiting.connect(_drop_items.bind(who), CONNECT_ONE_SHOT)
	if _menu.visible:
		_rebuild_menu()


func _drop_items(who: Node) -> void:
	_items = _items.filter(func(it: Dictionary) -> bool: return it["who"] != who)
	if _menu.visible:
		_rebuild_menu()


func set_menu_open(on: bool) -> void:
	if on:
		_rebuild_menu()
	_menu.visible = on


func _rebuild_menu() -> void:
	for c in _menu_box.get_children():
		_menu_box.remove_child(c)
		c.queue_free()
	var title := Label.new()
	title.text = "설정"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.85, 0.78, 1.0))
	_menu_box.add_child(title)
	if not _items.is_empty():
		for it in _items:
			_menu_box.add_child(_item_control(it["text"], it["action"], it["state"]))
		_menu_box.add_child(HSeparator.new())
	_menu_box.add_child(_item_control("전체화면  (F11)", toggle_fullscreen, is_fullscreen))
	if current_index() != LOBBY:
		_menu_box.add_child(_item_control("로비로  (Esc)", go_lobby))
	_menu_box.add_child(_item_control("게임 종료", func() -> void: get_tree().quit()))
	pin(_menu, Vector2(1, 0), MENU_RECT)   # 항목 수가 줄면 높이도 다시 줄도록 rect 를 다시 잡는다


func _item_control(text: String, action: Callable, state := Callable()) -> Button:
	var b: Button
	if state.is_valid():
		b = CheckButton.new()
		b.button_pressed = state.call()
		b.toggled.connect(func(_on: bool) -> void:
			action.call()
			b.set_pressed_no_signal(state.call()))
	else:
		b = Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void:
			set_menu_open(false)
			action.call())
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 38)
	return b


func _on_node_added(n: Node) -> void:
	if n.get_parent() == get_tree().root:
		call_deferred("_refresh")


func current_index() -> int:
	var cs := get_tree().current_scene
	if cs == null:
		return -1
	for i in SCENES.size():
		if cs.scene_file_path == SCENES[i]["path"]:
			return i
	return -1


func _refresh() -> void:
	var cur := current_index()
	var keep: bool = cur >= 0 and SCENES[cur].get("aspect", "expand") == "keep"
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP if keep else Window.CONTENT_SCALE_ASPECT_EXPAND


func switch_to(i: int) -> void:
	if i < 0 or i >= SCENES.size() or i == current_index():
		return
	if get_tree().current_scene == null or is_loading():
		return  # 이미 이번 프레임에 전환이 예약됨 / 로딩 화면이 도는 중
	Engine.time_scale = 1.0
	set_menu_open(false)
	if current_index() == LOBBY and SCENES[i].get("loading", true):
		_load_into(i)
		return
	_change(i)


func _change(i: int) -> void:
	print("[scene_switcher] -> ", SCENES[i]["path"])
	get_tree().change_scene_to_packed(_packed[i])
	call_deferred("_refresh")


## 로딩 화면으로 덮고 → 다 덮이면 씬을 바꾸고 → 새 씬이 그려진 뒤 걷는다.
func _load_into(i: int) -> void:
	_loading = LoadingScreen.new()
	add_child(_loading)
	_loading.start()
	await _loading.covered
	_change(i)
	_loading.finished.connect(func() -> void: _loading = null, CONNECT_ONE_SHOT)
	_loading.reveal()


func is_loading() -> bool:
	return _loading != null


func go_lobby() -> void:
	switch_to(LOBBY)


func _input(event: InputEvent) -> void:
	if is_loading() and event is InputEventKey and event.keycode != KEY_F11:
		get_viewport().set_input_as_handled()   # 로딩 중 키 입력은 삼킨다 (F11 만 통과)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if _menu.visible:
					set_menu_open(false)
				else:
					go_lobby()
				get_viewport().set_input_as_handled()
			KEY_F11:
				toggle_fullscreen()
				if _menu.visible:
					_rebuild_menu()


func is_fullscreen() -> bool:
	var mode := get_window().mode
	return mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN


func toggle_fullscreen() -> void:
	get_window().mode = Window.MODE_WINDOWED if is_fullscreen() else Window.MODE_FULLSCREEN


## 1920x1080 기준으로 잡은 rect 를 화면 비율이 바뀌어도 anchor 쪽에 붙어 있게 한다.
## anchor: (0|0.5|1, 0|0.5|1) = 왼/가운데/오른, 위/가운데/아래. 부모 Control 이 화면 전체를 덮을 때 쓴다.
static func pin(c: Control, anchor: Vector2, rect: Rect2, ref := DESIGN) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = rect.position.x - anchor.x * ref.x
	c.offset_right = rect.end.x - anchor.x * ref.x
	c.offset_top = rect.position.y - anchor.y * ref.y
	c.offset_bottom = rect.end.y - anchor.y * ref.y
