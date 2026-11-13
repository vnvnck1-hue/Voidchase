## Autoload: 로비와 각 모드 씬 사이를 오가고, 오른쪽 위 작은 설정(톱니) 버튼과 설정 메뉴를 띄운다.
## 모드 전환은 로비에서만 한다: 어디서든 Esc 로 로비로 나가 카드를 골라 들어간다(로비는 숫자키로도 입장). F11 은 전체화면.
## 화면 CRT 효과(scripts/crt_overlay.gd)도 여기서 띄운다: 설정 메뉴 [CRT 효과] · F6 다음 프리셋 · F7 조정 패널.
## 게임 글꼴(scripts/game_fonts.gd)도 여기서 바꾼다: 설정 메뉴 [글꼴 조합] · [글꼴 바꾸기] 패널(scripts/font_tuner.gd) · F5.
## 화면 녹화(scripts/screen_recorder.gd)도 여기 붙는다: 설정 메뉴 [화면 녹화 시작/멈춤] · F12 → 동영상/KSC_Touch_Game/*.avi.
## 설정 메뉴: 각 씬이 add_setting() 으로 자기 항목(배경 조정 등)을 넣고, 그 아래에 전체화면·로비로·게임 종료가 붙는다.
##   씬 항목은 그 씬(owner)이 트리에서 빠질 때 저절로 지워진다. 메뉴가 열려 있을 때 Esc 는 메뉴만 닫는다.
## 화면 대응: 기본은 stretch aspect "expand"(project.godot) 라서 울트라와이드·4:3 에서도 검은 띠 없이 화면을 채운다.
## 원화 폭이 정해져 있어 넓히면 가장자리가 드러나는 씬만 SCENES 의 "aspect": "keep" 으로 16:9 를 유지한다.
## UI 는 1920x1080 기준 좌표로 짠 뒤 pin() 으로 화면 가장자리·가운데에 붙인다.
## 로비에서 모드로 들어갈 때는 페이크 로딩 화면(scripts/loading_screen.gd, 약 3초)을 거친다. 로딩이 다 차면 검은 로딩 화면 아래에서
## 씬을 먼저 바꾸고(무거운 씬 생성의 멈춤이 전환 중이 아니라 로딩 중에 일어나게), 그 위를 그래픽 와이프 전환(scripts/screen_transition.gd,
## 약 1초)이 덮는다. 다 덮이면 로딩 화면을 치우고, 전환이 걷히면서 새 씬의 등장 연출(안개 열림·HUD 슬라이드 등)이 이어진다 —
## 씬은 intro_lead() 만큼 연출을 늦춘다 (전환이 아직 안 떴어도 _wipe_pending 으로 예정 시간을 돌려준다).
## 그 밖의 전환(로비로 나가기, SCENES 에 "loading": false 인 연출 연구실 같은 도구)은 로딩 화면 없이 코믹 파편 전환만 쓴다.
## 일반 전환 프리셋은 설정 메뉴 [화면 전환] 에서 고른다. 전투 진입 전환(환자의 머릿속으로 들어가는 워프)은 목적이 다른 별개의 것이다:
## SCENES 에 "enter_wipe": true 인 씬(메인전투)에 로비에서 들어갈 때만 쓰고, 설정 메뉴 [전투 진입 전환] 에서 따로 고른다.
extends CanvasLayer

const LOBBY := 0
## "name" 은 코드가 씬을 찾는 키라 그대로 둔다 (메인전투 = "VoidDefense_greybox": VDSandbox.scene_index · 테스트가 쓴다)
const SCENES := [
	{"name": "Lobby", "path": "res://scenes/Lobby.tscn", "title": "로비", "desc": "모드 선택 화면"},
	{"name": "VoidDefense_greybox", "path": "res://scenes/void_defense/VoidDefense.tscn", "title": "메인전투", "desc": "VOID DEFENSE 본 전투. 절차 생성 방을 전진하며 싸우는 자동전투 디펜스. 배치 → 전투 → 갈림길 선택. 유닛은 원화 조립 테스트의 캐릭터·몬스터.", "enter_wipe": true},
	{"name": "Touch_Game_demo_anim", "path": "res://scenes/Touch_Game_demo_anim.tscn", "title": "터치 게임 · 캐릭터 선택", "desc": "넓은 배경 + 캐릭터 선택창 + 스탠딩 원화 등장 연출.", "aspect": "keep"},
	{"name": "VoidDefense_visual", "path": "res://scenes/void_defense/VoidDefenseVisualTest.tscn", "title": "VOID DEFENSE (원화 조립 테스트)", "desc": "컨셉 원화 분리본 64장을 assembly.json 좌표대로 조립하고 절차 아이들·위빙을 얹은 화면. R 보조 레이어 · H HUD · O 1:1 · G 리그 피벗 · A 애니메이션.", "aspect": "keep"},
	{"name": "FxLab", "path": "res://scenes/void_defense/FxLab.tscn", "title": "연출 연구실", "desc": "몬스터 등장 · 초궁극기 컷인 같은 연출을 목록에서 골라 타이밍·세기를 슬라이더로 바꾸며 실시간 반복 재생. 저장하면 VOID DEFENSE 전투에 반영.", "loading": false},
	{"name": "VfxShowroom", "path": "res://scenes/void_defense/VfxShowroom.tscn", "title": "VFX 쇼룸", "desc": "게임에 쓰이는 VFX 전부를 칸마다 반복 재생해 한눈에 본다. 분류 탭 · 칸을 누르면 크게 보기.", "loading": false},
	{"name": "FieldLab", "path": "res://scenes/void_defense/FieldLab.tscn", "title": "필드 연구실", "desc": "전투 배경(타일 · 하늘 · 프랍 · 앞 안개)의 색조·채도·명도를 슬라이더로 조절해 VFX·캐릭터 시인성을 맞춘다. 실제 전투 화면에서 바로 확인, 저장하면 본 전투에 반영.", "loading": false},
]
const DESIGN := Vector2(1920, 1080)
const GEAR_RECT := Rect2(1860, 16, 44, 44)       # 설정 버튼 (오른쪽 위 끝)
const MENU_RECT := Rect2(1600, 68, 304, 0)       # 설정 메뉴 (버튼 바로 아래, 높이는 내용만큼)
const MENU_BG := Color(0.07, 0.05, 0.13, 0.98)
const MENU_BORDER := Color(0.62, 0.5, 0.95, 0.7)
const LoadingScreen := preload("res://scripts/loading_screen.gd")
const CrtOverlay := preload("res://scripts/crt_overlay.gd")
const CrtTuner := preload("res://scripts/crt_tuner.gd")
const FontTuner := preload("res://scripts/font_tuner.gd")
const GameFonts := preload("res://scripts/game_fonts.gd")
const ScreenTransition := preload("res://scripts/screen_transition.gd")
const ScreenRecorder := preload("res://scripts/screen_recorder.gd")
## 씬 파일을 매번 다시 파싱하지 않도록 PackedScene 을 미리 들고 있는다.
var _packed: Array[PackedScene] = []
var _root: Control
var _gear: Button
var _menu: PanelContainer
var _menu_box: VBoxContainer
## 씬이 넣은 설정 항목: {who, text, action, state}
var _items: Array[Dictionary] = []
## 떠 있는 로딩 화면 / 코믹 파편 전환 (없으면 null). 이 동안은 다른 전환·Esc 를 받지 않는다.
var _loading: LoadingScreen
var _wipe: CanvasLayer
## 로딩 경로에서 씬을 바꾼 직후 ~ 전환을 띄우기 전: 새 씬의 intro_lead() 가 예정된 전환 시간을 돌려주게 한다
var _wipe_pending := false
## 지금 들어가는 씬의 전환 프리셋: SCENES 에 "enter_wipe" 가 있으면 설정의 전투 진입 전환, 없으면 -1 (= 일반 화면 전환)
var _enter_wipe := -1
## 화면 CRT 효과 (CanvasLayer 99, 모든 씬 공통) 와 그 조정 패널 (설정 레이어 안이라 선명하다)
var crt: CanvasLayer
var _crt_tuner: Control
## 글꼴 바꾸기 패널 (F5)
var _font_tuner: Control
## 화면 녹화 (F12, scripts/screen_recorder.gd)
var recorder: ScreenRecorder
## 다음 로딩 화면에 띄울 접속 문구·팁 (허브가 다이브 직전에 넣는다. 한 번 쓰고 비운다)
var loading_caption := ""
var loading_tip := ""
## Esc·[상담소로] 를 가로채는 곳 (의뢰 런의 일시정지 메뉴). 유효하고 true 를 돌려주면 여기서는 아무것도 하지 않는다.
var esc_guard := Callable()


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
	crt = CrtOverlay.new()
	add_child(crt)
	_crt_tuner = CrtTuner.new()
	_crt_tuner.setup(crt)
	_root.add_child(_crt_tuner)
	add_choice_setting(self, "CRT 효과  (F6)", crt.preset_names(), crt.get_preset, crt.apply_preset)
	add_setting(self, "CRT 조정  (F7)", _crt_tuner.toggle, _crt_tuner.is_open)
	_font_tuner = FontTuner.new()
	_root.add_child(_font_tuner)
	add_choice_setting(self, "글꼴 조합", GameFonts.preset_names(),
		func() -> int: return GameFonts.preset_index(),
		func(i: int) -> void:
			GameFonts.apply_preset(i)
			_font_tuner.refresh())
	add_setting(self, "글꼴 바꾸기  (F5)", _font_tuner.toggle, _font_tuner.is_open)
	add_choice_setting(self, "화면 전환", ScreenTransition.general_names(),
		func() -> int: return ScreenTransition.get_preset(),
		func(i: int) -> void: ScreenTransition.set_preset(i))
	add_choice_setting(self, "전투 진입 전환", ScreenTransition.enter_names(),
		func() -> int: return ScreenTransition.get_enter(),
		func(i: int) -> void: ScreenTransition.set_enter(i))
	recorder = ScreenRecorder.new()
	_root.add_child(recorder)
	add_setting(self, recorder.menu_text, recorder.toggle)
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
## who 가 트리에서 빠지면(씬 전환) 항목도 지워진다. text 는 글자 대신 () -> String 을 줘도 된다(메뉴를 열 때마다 다시 읽음).
func add_setting(who: Node, text: Variant, action: Callable, state := Callable()) -> void:
	_add_setting_item(who, {"text": text, "action": action, "state": state})


## 목록 선택형 설정. 현재 값을 읽는 getter와 선택을 적용하는 setter를 받는다.
func add_choice_setting(who: Node, text: String, choices: Array, getter: Callable, setter: Callable) -> void:
	_add_setting_item(who, {"kind": "choice", "text": text, "choices": choices, "getter": getter, "setter": setter})


func _add_setting_item(who: Node, item: Dictionary) -> void:
	var first := _items.all(func(it: Dictionary) -> bool: return it["who"] != who)
	item["who"] = who
	_items.append(item)
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
		# 씬이 넣은 항목 먼저, 전역 항목(CRT 효과·조정)은 그 아래
		var ordered := _items.filter(func(it: Dictionary) -> bool: return it["who"] != self)
		ordered.append_array(_items.filter(func(it: Dictionary) -> bool: return it["who"] == self))
		for it in ordered:
			if it.get("kind", "action") == "choice":
				_menu_box.add_child(_choice_control(it))
			else:
				var text: String = it["text"].call() if it["text"] is Callable else it["text"]
				_menu_box.add_child(_item_control(text, it["action"], it["state"]))
		_menu_box.add_child(HSeparator.new())
	_menu_box.add_child(_item_control("전체화면  (F11)", toggle_fullscreen, is_fullscreen))
	if current_index() != LOBBY:
		_menu_box.add_child(_item_control("상담소로  (Esc)", request_lobby))
	_menu_box.add_child(_item_control("게임 종료", func() -> void: get_tree().quit()))
	pin(_menu, Vector2(1, 0), MENU_RECT)   # 항목 수가 줄면 높이도 다시 줄도록 rect 를 다시 잡는다


func _choice_control(item: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = item["text"]
	box.add_child(label)
	var options := OptionButton.new()
	options.name = "BackgroundTheme" if item["text"] == "배경 테마" else ("FogStyle" if item["text"] == "앞 안개 스타일" else "Choice")
	options.focus_mode = Control.FOCUS_NONE
	options.custom_minimum_size = Vector2(0, 38)
	for choice in item["choices"]:
		options.add_item(choice)
	options.select(int(item["getter"].call()))
	options.item_selected.connect(func(index: int) -> void:
		item["setter"].call(index)
		options.select(int(item["getter"].call()))
	)
	box.add_child(options)
	return box


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
	_reset_globals()
	set_menu_open(false)
	if current_index() == LOBBY and SCENES[i].get("loading", true):
		_load_into(i)
		return
	_wipe_into(i)


func _change(i: int) -> void:
	print("[scene_switcher] -> ", SCENES[i]["path"])
	get_tree().change_scene_to_packed(_packed[i])
	# 덮는 동안에도 옛 씬이 돌며 히트스톱·슬로모션·일시정지를 걸 수 있다: 바뀐 뒤 한 번 더 되돌린다
	_reset_globals()
	call_deferred("_reset_globals")
	call_deferred("_refresh")


## 씬이 바뀌어도 남는 엔진 전역 상태 (시간 배율·트리 일시정지·커서 모양) 를 기본값으로.
func _reset_globals() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## 로딩 화면으로 덮고 → 로딩이 다 차면 그 아래에서 씬을 바꾸고(멈춤은 여기서) → 새 씬이 그려지면 그 위를 그래픽 와이프로 덮고
## → 다 덮이면 로딩 화면을 치우고 → 바로 걷는다 (새 씬은 이미 그려져 있어 기다릴 프레임이 없다).
func _load_into(i: int) -> void:
	_loading = LoadingScreen.new()
	_loading.caption = loading_caption
	_loading.tip = loading_tip
	loading_caption = ""
	loading_tip = ""
	add_child(_loading)
	_loading.start()
	await _loading.covered
	_enter_wipe = ScreenTransition.enter_preset() if SCENES[i].get("enter_wipe", false) else -1
	_wipe_pending = true
	_change(i)
	await get_tree().process_frame
	await get_tree().process_frame
	_wipe = ScreenTransition.new()
	_wipe.preset_override = _enter_wipe
	_wipe_pending = false
	add_child(_wipe)
	_wipe.start()
	await _wipe.covered
	_loading.queue_free()
	_loading = null
	_wipe.finished.connect(func() -> void: _wipe = null, CONNECT_ONE_SHOT)
	_wipe.reveal(0)


## 새 씬의 등장 연출을 늦출 시간(초): 코믹 파편 전환이 걷히는 중이면 가운데 구멍이 다 열릴 때까지, 아니면 0.
## 씬은 _ready 에서 UIIntro 지연값·안개 열림 시각에 이 값을 더한다 (숨은 상태는 즉시 만들어지므로 그동안 조각이 보이지 않는다).
func intro_lead() -> float:
	if _wipe_pending:
		return ScreenTransition.full_lead(2, _enter_wipe)
	if _wipe == null or not is_instance_valid(_wipe):
		return 0.0
	return _wipe.time_to_open()


## 코믹 파편으로 덮고 → 다 덮이면 씬을 바꾸고 → 새 씬이 그려진 뒤 걷는다.
func _wipe_into(i: int) -> void:
	_wipe = ScreenTransition.new()
	add_child(_wipe)
	_wipe.start()
	await _wipe.covered
	_change(i)
	_wipe.finished.connect(func() -> void: _wipe = null, CONNECT_ONE_SHOT)
	_wipe.reveal()


func is_loading() -> bool:
	return _loading != null or _wipe != null or _wipe_pending


func go_lobby() -> void:
	switch_to(LOBBY)


## Esc · 설정 메뉴 [상담소로]: 씬이 가로채지 않으면(esc_guard) 바로 허브로 나간다.
func request_lobby() -> void:
	if esc_guard.is_valid() and esc_guard.call():
		return
	go_lobby()


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
					request_lobby()
				get_viewport().set_input_as_handled()
			KEY_F11:
				toggle_fullscreen()
				if _menu.visible:
					_rebuild_menu()
			KEY_F6:
				crt.cycle()
				if _menu.visible:
					_rebuild_menu()
				get_viewport().set_input_as_handled()
			KEY_F7:
				_crt_tuner.toggle()
				get_viewport().set_input_as_handled()
			KEY_F5:
				_font_tuner.toggle()
				if _menu.visible:
					_rebuild_menu()
				get_viewport().set_input_as_handled()


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
