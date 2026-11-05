## VOID DEFENSE 그레이박스 프로토타입 — 절차 생성 맵을 전진하며 싸우는 전투 루프.
##   PLACEMENT(현재 방 입구 쪽 4열에서 드래그 배치) → [배치 완료] → SPAWNING → BATTLE(실시간 자동전투)
##   → 적 전멸: TRANSITION(그 자리에서 회복·정수 회수, 출구 생성 — 진형은 다음 방 도착 때 잡는다)
##   → CHOOSE_PATH(갈림길이면 플레이어가 길 선택, 외길이면 자동) → TRAVEL(복도를 따라 다음 방으로 이동)
##   → 다음 방에서 저장된 진형으로 자리 잡고 PLACEMENT (전투는 다시 플레이어가 시작)
##   → 아군 전멸: GAMEOVER(다시 도전)
class_name VDBattle
extends Node2D

signal wave_cleared(wave: int)
signal game_over(wave: int)
signal state_changed(state: int)

enum State { PLACEMENT, SPAWNING, BATTLE, TRANSITION, CHOOSE_PATH, TRAVEL, GAMEOVER }

const WAVE_HEAL := 50.0
const SPORE_FLIGHT_SEC := 0.34
const TRAVEL_SEC_PER_TILE := 0.11
const BATTLE_ZOOM := 1.18      # 전투(적 등장~전멸) 동안 카메라 줌인 배율
const ZOOM_IN_SEC := 0.7
const ZOOM_OUT_SEC := 0.45

var state: State = State.PLACEMENT
var wave := 1
var essence := 0
var allies: Array[VDUnit] = []
var enemies: Array[VDUnit] = []
var map: VDMap
var room := {}                 # 현재 전투 방
var formation := {}            # hero id -> 방 로컬 (a, c). 배치 완료 시 저장, 다음 방에서 재사용
var exits: Array = []          # 현재 갈림길 후보

var board: VDBoard
var props: VDProps
var units_root: Node2D
var fx_root: Node2D
const GAME_SPEEDS := [1.0, 1.5, 2.0]   # 속도 버튼이 차례로 바꾸는 배속
var camera: VDCamera
var nebula_tuner: VDNebulaTuner
var audio: VDAudio
var vfx: VDVfx
var ground_fx: Node2D          # 바닥 이펙트(포털·마법진·먼지): 보드 위, 유닛 아래
var dmg_log: VDDamageLog       # 피해 숫자: 헥스 블레이드 DamageLog 이식(ARCO 글꼴·팝·포물선·연타 열기)
var skills: VDSkills          # 액티브 스킬 시전 (마나가 차면 자동)
var relic_board: VDRelicBoard  # 유물 성좌판 상태 (칸·유물·보관함)
var relics: VDRelicRuntime     # 유물 발동기 (전투 이벤트 → 효과)
var relic_hud: VDRelicHud      # 성좌판 HUD (드래그 배치·보상 선택)
var turntable: VDTurntable     # 좌측 하단 캐릭터 턴테이블

var _dragging: VDUnit = null
var _spawning := false          # 적 등장 연출 진행 중 (배치 완료 버튼 잠금)
var _pending_start := false     # 등장 중에 배치 완료를 눌렀으면 끝나고 시작
var _run_id := 0               # 재시작 시 진행 중이던 코루틴을 무효화
var _cam_target := Vector2.ZERO   # 방 중심 (이동 중에는 분대 중심). 전투 중 포커스는 focus 가 정한다
const VDCombatFocus := preload("res://scripts/void_defense/vd_combat_focus.gd")
var focus := VDCombatFocus.new()   # 전투 카메라: 치열한 곳을 부드럽게 따라가며 살짝 줌인/아웃
var _cam_clock_us := 0
var _zoom_tween: Tween

# HUD
var _lbl_wave: Label
var _lbl_msg: Label
var _lbl_essence: Label
var _lbl_boss: Label
var _boss_bar: ProgressBar
var _btn_main: Button
var _btn_speed: Button
var _path_box: HBoxContainer
var _cards := {}
var _over_panel: Control
var _lbl_over: Label
var _msg_tween: Tween


func _ready() -> void:
	randomize()
	print("[VD] VoidDefense ready (main_scene=%s)" % ProjectSettings.get_setting("application/run/main_scene"))
	audio = VDAudio.new()
	add_child(audio)
	skills = VDSkills.new(self)
	relic_board = VDRelicBoard.new()
	relics = VDRelicRuntime.new(self, relic_board)
	_build_world()
	_build_hud()
	_new_run()


# ---------------------------------------------------------------- build

func _build_world() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	# 공허 하늘: 남색 밤하늘 아래로 푸른 기체가 흐르고 섞이는 셰이더 (shaders/void_nebula.gdshader)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = load("res://shaders/void_nebula.gdshader")
	bg.material = bg_mat
	bg_layer.add_child(bg)

	props = VDProps.new()
	add_child(props)
	add_child(props.back)        # 바닥 뒤 프랍: 보드보다 먼저
	board = VDBoard.new()
	add_child(board)
	ground_fx = Node2D.new()
	ground_fx.name = "GroundFx"
	add_child(ground_fx)
	units_root = Node2D.new()
	units_root.y_sort_enabled = true
	add_child(units_root)
	add_child(props.front)       # 바닥 앞 프랍: 유닛 위
	fx_root = Node2D.new()
	fx_root.z_index = 50
	add_child(fx_root)
	vfx = VDVfx.new()
	add_child(vfx)

	camera = VDCamera.new()
	camera.position_smoothing_enabled = false   # 부드러움은 focus(smooth damp)가 맡는다 — 두 번 거르면 굼떠진다
	camera.bg_material = bg_mat
	add_child(camera)
	camera.make_current()

	# 앞 안개: 월드 위, HUD 아래. 가장자리를 흐르는 기체가 덮어 맵 끝이 공허 속으로 잠기는 공간감.
	var fog_layer := CanvasLayer.new()
	fog_layer.layer = 5
	add_child(fog_layer)
	var fog := ColorRect.new()
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/void_vignette.gdshader")
	fog.material = mat
	fog_layer.add_child(fog)
	# 셰이더 기본 aspect 는 16:9 라서 화면 비율이 바뀌면(울트라와이드 등) 무늬가 늘어난다. 실제 비율을 넣어 준다.
	var fit_aspect := func() -> void:
		var ar := bg.size.x / maxf(bg.size.y, 1.0)
		bg_mat.set_shader_parameter("aspect", ar)
		mat.set_shader_parameter("aspect", ar)
	bg.resized.connect(fit_aspect)
	fit_aspect.call()
	# 배경 조정 패널: 공허 배경(모양·속도·컬러)과 앞 안개를 실시간으로 (앞 안개 색도 배경 컬러를 따라간다)
	nebula_tuner = VDNebulaTuner.new()
	nebula_tuner.setup(bg_mat, mat)
	var tuner_layer := CanvasLayer.new()
	tuner_layer.layer = 20
	add_child(tuner_layer)
	tuner_layer.add_child(nebula_tuner)
	SceneSwitcher.add_setting(self, "배경 조정  (F10)", nebula_tuner.toggle, nebula_tuner.is_open)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = VDData.font()
	theme.default_font_size = 20
	root.theme = theme
	hud.add_child(root)
	dmg_log = VDDamageLog.new()
	root.add_child(dmg_log)
	relic_hud = VDRelicHud.new()
	root.add_child(relic_hud)
	relic_hud.setup(self, relic_board, relics)
	SceneSwitcher.add_setting(self, "유물 전부 지급 (테스트)", func() -> void:
		for id in VDRelicData.RELIC_ORDER:
			relic_board.add_to_tray(id))

	_label(root, "VOID DEFENSE", Vector2(40, 26), 38, Color(0.95, 0.9, 1.0))
	_label(root, "greybox prototype · procedural rooms", Vector2(44, 70), 14, Color(0.8, 0.75, 0.95))
	_lbl_wave = _label(root, "", Vector2(40, 96), 24, Color(1, 1, 1))

	# 1920x1080 기준 좌표를 SceneSwitcher.pin 으로 화면 가운데·오른쪽에 붙인다(울트라와이드 대응)
	_lbl_msg = _label(root, "", Vector2(460, 112), 26, Color(1.0, 0.85, 0.42))
	SceneSwitcher.pin(_lbl_msg, Vector2(0.5, 0), Rect2(460, 112, 1000, 40))
	_lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_lbl_boss = _label(root, "", Vector2(660, 24), 24, Color(1, 0.9, 0.95))
	SceneSwitcher.pin(_lbl_boss, Vector2(0.5, 0), Rect2(660, 24, 600, 32))
	_lbl_boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_bar = ProgressBar.new()
	SceneSwitcher.pin(_boss_bar, Vector2(0.5, 0), Rect2(660, 62, 600, 20))
	_boss_bar.show_percentage = false
	_boss_bar.add_theme_stylebox_override("fill", _flat(Color(0.9, 0.2, 0.3)))
	_boss_bar.add_theme_stylebox_override("background", _flat(Color(0.1, 0.05, 0.15)))
	root.add_child(_boss_bar)
	_lbl_boss.visible = false
	_boss_bar.visible = false

	_lbl_essence = _label(root, "", Vector2(1540, 28), 28, Color(0.85, 0.7, 1.0))
	SceneSwitcher.pin(_lbl_essence, Vector2(1, 0), Rect2(1480, 18, 360, 44))   # 오른쪽 끝은 설정 버튼 자리
	_lbl_essence.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_btn_speed = Button.new()
	SceneSwitcher.pin(_btn_speed, Vector2(1, 0), Rect2(1350, 22, 110, 36))   # 정수 표시 왼쪽
	_btn_speed.focus_mode = Control.FOCUS_NONE
	_btn_speed.pressed.connect(_toggle_speed)
	root.add_child(_btn_speed)
	_refresh_speed_label()

	# 갈림길 선택 버튼 (화면 중앙 아래, 선택 중에만 표시)
	_path_box = HBoxContainer.new()
	SceneSwitcher.pin(_path_box, Vector2(0.5, 1), Rect2(560, 780, 800, 70))
	_path_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_path_box.add_theme_constant_override("separation", 30)
	_path_box.visible = false
	root.add_child(_path_box)

	# 하단 분대 바
	var panel := Panel.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -150
	panel.offset_bottom = 0
	panel.add_theme_stylebox_override("panel", _flat(Color(0.12, 0.08, 0.2, 0.92)))
	root.add_child(panel)
	var x := 1040.0   # 왼쪽은 캐릭터 턴테이블 자리 (목업: 초상 카드는 오른쪽)
	for hid in VDData.HERO_ORDER:
		var def: Dictionary = VDData.HEROES[hid]
		var card := PanelContainer.new()
		card.position = Vector2(x, 20)
		card.custom_minimum_size = Vector2(150, 110)
		var sb := _flat(Color(0.2, 0.15, 0.3))
		sb.border_color = def["color"]
		sb.set_border_width_all(3)
		card.add_theme_stylebox_override("panel", sb)
		var vb := VBoxContainer.new()
		card.add_child(vb)
		var nm := Label.new()
		nm.text = def["name"]
		nm.add_theme_color_override("font_color", def["color"])
		nm.add_theme_font_size_override("font_size", 22)
		vb.add_child(nm)
		var hpb := ProgressBar.new()
		hpb.custom_minimum_size = Vector2(0, 14)
		hpb.show_percentage = false
		hpb.add_theme_stylebox_override("fill", _flat(Color(0.3, 0.85, 0.4)))
		hpb.add_theme_stylebox_override("background", _flat(Color(0.05, 0.05, 0.1)))
		vb.add_child(hpb)
		var mpb := ProgressBar.new()
		mpb.custom_minimum_size = Vector2(0, 8)
		mpb.show_percentage = false
		mpb.add_theme_stylebox_override("fill", _flat(Color(0.3, 0.55, 1.0)))
		mpb.add_theme_stylebox_override("background", _flat(Color(0.05, 0.05, 0.1)))
		vb.add_child(mpb)
		var sk := Label.new()
		sk.text = "★ " + VDData.SKILLS[hid]["name"]
		sk.tooltip_text = VDData.SKILLS[hid]["desc"]
		sk.mouse_filter = Control.MOUSE_FILTER_STOP
		sk.add_theme_font_size_override("font_size", 13)
		sk.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0))
		vb.add_child(sk)
		var st := Label.new()
		st.add_theme_font_size_override("font_size", 14)
		st.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
		vb.add_child(st)
		panel.add_child(card)
		_cards[hid] = {"panel": card, "hp": hpb, "mana": mpb, "skill": sk, "name": nm, "stat": st}
		x += 170.0
	for i in 2:
		var lock := PanelContainer.new()
		lock.position = Vector2(x, 20)
		lock.custom_minimum_size = Vector2(70, 110)
		lock.add_theme_stylebox_override("panel", _flat(Color(0.16, 0.13, 0.22)))
		var l := Label.new()
		l.text = "잠금"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", Color(0.5, 0.45, 0.6))
		lock.add_child(l)
		panel.add_child(lock)
		x += 80.0

	_btn_main = Button.new()
	SceneSwitcher.pin(_btn_main, Vector2(1, 1), Rect2(1620, 866, 280, 60))   # 분대 바 위, 보관함 아래
	_btn_main.focus_mode = Control.FOCUS_NONE
	_btn_main.add_theme_font_size_override("font_size", 30)
	_btn_main.pressed.connect(start_battle)
	root.add_child(_btn_main)

	# 캐릭터 턴테이블 (좌측 하단): 스탠딩을 둥글게 세우고 돌려 본다
	turntable = VDTurntable.new()
	root.add_child(turntable)

	# 게임오버 오버레이
	_over_panel = Control.new()
	_over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over_panel.visible = false
	root.add_child(_over_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over_panel.add_child(center)
	var vb2 := VBoxContainer.new()
	vb2.add_theme_constant_override("separation", 24)
	center.add_child(vb2)
	_lbl_over = Label.new()
	_lbl_over.add_theme_font_size_override("font_size", 40)
	_lbl_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb2.add_child(_lbl_over)
	var retry := Button.new()
	retry.text = "다시 도전"
	retry.custom_minimum_size = Vector2(260, 70)
	retry.add_theme_font_size_override("font_size", 28)
	retry.pressed.connect(restart)
	vb2.add_child(retry)


func _label(parent: Node, text: String, pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _flat(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(8)
	return sb


# ---------------------------------------------------------------- run / units

func _new_run() -> void:
	_run_id += 1
	for e in enemies:
		e.queue_free()
	enemies.clear()
	for a in allies:
		a.queue_free()
	allies.clear()
	map = VDMap.new()
	map.rng.randomize()
	for arg in OS.get_cmdline_user_args():   # --vdseed=N : 맵 생성을 재현(테스트·캡처용)
		if arg.begins_with("--vdseed="):
			map.rng.seed = int(arg.substr(9))
	room = map.create_root()
	board.map = map
	board.current_room = room
	board.exits = []
	board.show_exits = false
	props.clear()
	props.scatter_room(map, room)
	nebula_tuner.clear_moods()
	formation.clear()
	var taken := {}
	for hid in VDData.HERO_ORDER:
		var def: Dictionary = VDData.HEROES[hid]
		var local: Vector2i = VDMap.nearest_zone_cell(room, def["start"], "A", taken)
		taken[local] = true
		formation[hid] = local
		var u := _make_unit(def, hid, 0, VDMap.to_world(room, local.x, local.y))
		allies.append(u)
	wave = 1
	essence = 0
	exits = []
	relic_board.reset()
	relics.reset()
	_refresh_essence()
	_over_panel.visible = false
	_lbl_boss.visible = false
	_boss_bar.visible = false
	_path_box.visible = false
	_cam_target = VDData.to_screen(VDMap.center_f(room))
	camera.position = _cam_target
	camera.reset_smoothing()
	focus.reset(_cam_target, camera.base_zoom.x)
	_set_state(State.PLACEMENT)
	_spawn_wave(_run_id)   # 분대가 자리 잡은 뒤 적이 먼저 등장: 배치 단계에서 위치가 보인다


func _make_unit(def: Dictionary, id: String, team: int, cell: Vector2i, hp_mult := 1.0, atk_mult := 1.0) -> VDUnit:
	var u := VDUnit.new()
	u.setup(def, id, team, cell, hp_mult, atk_mult)
	units_root.add_child(u)
	u.snap_to_cell()
	u.died.connect(_on_unit_died)
	return u


func _unit_at(cell: Vector2i, list: Array[VDUnit]) -> VDUnit:
	for u in list:
		if u.alive and u.cell == cell:
			return u
	return null


func _occupied(cell: Vector2i) -> bool:
	return _unit_at(cell, allies) != null or _unit_at(cell, enemies) != null


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if state == State.PLACEMENT:
				_begin_drag()
			elif state == State.CHOOSE_PATH:
				_click_exit(_mouse_cell())
		else:
			_end_drag()
	elif event is InputEventMouseMotion and _dragging:
		_update_drag()


func _mouse_cell() -> Vector2i:
	return VDData.to_cell(board.get_local_mouse_position())


func _placement_valid(cell: Vector2i, u: VDUnit) -> bool:
	if VDMap.zone(room, cell) != "A":
		return false
	var other := _unit_at(cell, allies)
	return other == null or other == u


func _begin_drag() -> void:
	var u := _unit_at(_mouse_cell(), allies)
	if u == null:
		return
	_dragging = u
	u.z_index = 100
	_update_drag()


func _update_drag() -> void:
	_dragging.position = board.get_local_mouse_position() + Vector2(0, -8)
	var c := _mouse_cell()
	board.set_hover(c, _placement_valid(c, _dragging))


func _end_drag() -> void:
	if _dragging == null:
		return
	var c := _mouse_cell()
	if _placement_valid(c, _dragging):
		if c != _dragging.cell:
			audio.play("place")
			vfx.spawn("dust", ground_fx, VDData.to_screen(Vector2(c)), 0.9)
		_dragging.cell = c
	_dragging.snap_to_cell()
	_dragging.z_index = 0
	_dragging = null
	board.set_hover(Vector2i(-1, -1), false, false)


func _click_exit(cell: Vector2i) -> void:
	for i in exits.size():
		var ex: Dictionary = exits[i]
		if cell in ex["corridor"] or VDMap.in_room(map.rooms[ex["room_id"]], cell):
			choose_path(i)
			return


## 테스트/외부용: 영웅을 현재 방의 로컬 (a, c) 로 바로 옮긴다.
func place_hero(id: String, local: Vector2i) -> bool:
	for u in allies:
		var cell := VDMap.to_world(room, local.x, local.y)
		if u.id == id and _placement_valid(cell, u):
			u.cell = cell
			u.snap_to_cell()
			return true
	return false


# ---------------------------------------------------------------- flow

## 배치 완료: 적은 이미 등장해 있으므로 짧은 "전투 개시" 연출 뒤 바로 전투. 적이 아직 등장 중이면 끝난 뒤 시작한다.
func start_battle() -> void:
	if state != State.PLACEMENT:
		return
	if _spawning:
		_pending_start = true
		return
	for a in allies:
		a.home_cell = a.cell
		formation[a.id] = VDMap.to_local(room, a.cell)
	audio.play("click")
	_begin_battle(_run_id)


func _begin_battle(run: int) -> void:
	_set_state(State.SPAWNING)
	_show_msg("전투 개시!", 1.0)
	audio.play("wave_start", 0.0)
	# 잠들어 있던 적이 깨어난다: 작게 움찔
	for e in enemies:
		if e.alive:
			var tw := e.create_tween()
			tw.tween_property(e, "scale", Vector2(1.18, 0.86), 0.08)
			tw.tween_property(e, "scale", Vector2.ONE, 0.16)
	await get_tree().create_timer(0.5).timeout
	if run != _run_id or state != State.SPAWNING:
		return
	_set_state(State.BATTLE)
	relics.on_battle_start()


## 적 등장(배치 단계에서 미리): 방의 E 구역 셀을 섞어 차례로 솟아난다. 끝나면 배치 완료 버튼이 열린다.
func _spawn_wave(run: int) -> void:
	_spawning = true
	_refresh_main_button()
	var types := VDData.wave_enemies(wave)
	var mult := VDData.scaling(wave)
	print("[VD] room %d (%s) / wave %d: %d enemies %s (x%.2f)" % [room["id"], room["shape"], wave, types.size(), str(types), mult])
	_show_msg("공허의 잔재가 균열에서 나타난다...", 1.4)
	var spots: Array = VDMap.local_cells(room, "E")
	spots.shuffle()
	var used := {}
	for t in types:
		if run != _run_id:
			return
		var cell := _random_spawn_cell(spots, used)
		if cell.x == -999:
			continue
		used[cell] = true
		var def: Dictionary = VDData.ENEMIES[t]
		var e := _make_unit(def, t, 1, cell, mult * 0.7, mult)
		var foot := VDData.to_screen(Vector2(cell))
		# 차원 소환: 새하얀 빛줄기로 떨어져 바닥에 꽂힌다. 꽂히는 순간 충격파·먼지·섬광 + 화면 흔들림.
		# 값은 VDSummonFx (로비 → 연출 연구실에서 조절)
		e.appear(VDSummonFx.play_impact.bind(vfx, ground_fx, fx_root, camera, foot, e.is_boss))
		enemies.append(e)
		audio.play("boss_spawn" if e.is_boss else "enemy_spawn", 0.12)
		# 균열(포털)이 바닥에서 소용돌이치며 낙하 지점을 예고한다
		VDSummonFx.play_portal(vfx, ground_fx, foot, e.is_boss)
		if e.is_boss:
			_lbl_boss.text = e.display_name
			_lbl_boss.visible = true
			_boss_bar.visible = true
			nebula_tuner.set_boss(true)   # 배경이 더 강렬하고 빠르게: 위험 연출
			_show_msg("보스 등장: " + e.display_name, 1.6)
		await get_tree().create_timer(maxf(VDSummonFx.g("interval"), 0.01)).timeout
	await get_tree().create_timer(VDUnit.appear_duration() + 0.1).timeout   # 마지막 적의 출렁임이 끝날 때까지
	if run != _run_id:
		return
	_spawning = false
	_refresh_main_button()
	if _pending_start:
		_pending_start = false
		start_battle()


func _random_spawn_cell(spots: Array, used: Dictionary) -> Vector2i:
	for l in spots:
		var c := VDMap.to_world(room, l.x, l.y)
		if not used.has(c) and not _occupied(c):
			return c
	return Vector2i(-999, -999)


func _on_unit_died(u: VDUnit) -> void:
	if u.team == 1:
		essence += u.essence
		_refresh_essence()
		dmg_log.spawn_status(_chest(u) + Vector2(0, -24), "+%d" % u.essence, Color(0.85, 0.65, 1.0), u)
		audio.play("enemy_die", 0.1)
		audio.play("essence", 0.1)
		# 처치: 보라빛 폭발. 보스는 크게 + 바닥 충격파
		var at := _chest(u)
		vfx.spawn("kill_burst", fx_root, at, 2.6 if u.is_boss else 1.5, randf() * TAU, Color(0.85, 0.65, 1.0))
		# 처치 타격감: 일반은 살짝, 보스는 크게
		camera.shake(1.0 if u.is_boss else 0.55)
		camera.hitstop(0.16 if u.is_boss else 0.06)
		if u.is_boss:
			vfx.spawn("shockwave", ground_fx, u.position, 1.3, 0.0, Color(0.9, 0.7, 1.0), Vector2(1.0, 0.5))
			vfx.spawn("burst", fx_root, at, 0.6, 0.0, Color(0.9, 0.6, 1.0))
			nebula_tuner.set_boss(false)
		print("[VD] enemy down: %s  (+%d essence)" % [u.display_name, u.essence])
		relics.on_enemy_killed(u)
		if state == State.BATTLE and _alive_count(enemies) == 0:
			_finish_wave(_run_id)
	else:
		print("[VD] hero down: %s" % u.display_name)
		audio.play("hero_down", 0.0)
		nebula_tuner.danger_flash()   # 배경·앞 안개가 잠시 붉고 빠르게: 위험 알림
		vfx.spawn("lightning", fx_root, u.position + Vector2(0, u._top * 0.9), 0.6, 0.0, Color(1.0, 0.45, 0.55))
		vfx.spawn("burst", fx_root, _chest(u), 0.45, 0.0, Color(1.0, 0.4, 0.5))
		if state == State.BATTLE and _alive_count(allies) == 0:
			_do_game_over()


func _alive_count(list: Array[VDUnit]) -> int:
	var n := 0
	for u in list:
		if u.alive:
			n += 1
	return n


func _finish_wave(run: int) -> void:
	_set_state(State.TRANSITION)
	print("[VD] room %d cleared (wave %d)  essence=%d" % [room["id"], wave, essence])
	wave_cleared.emit(wave)
	_lbl_boss.visible = false
	_boss_bar.visible = false
	_show_msg("구역 클리어!  회복 · 정수 회수", 1.8)
	for a in allies:
		a.reset_combat()   # 기절·가드 해제 (마나는 이어진다)
	relics.on_battle_end()
	audio.play("wave_clear", 0.0)
	vfx.spawn("shockwave", ground_fx, VDData.to_screen(VDMap.center_f(room)), 1.6, 0.0, Color(1.0, 0.9, 0.5), Vector2(1.0, 0.5))
	await get_tree().create_timer(0.6).timeout
	if run != _run_id:
		return
	for a in allies:
		if a.alive:
			var before := a.hp
			a.heal(WAVE_HEAL)
			var gain := int(a.hp - before)
			if gain > 0:
				audio.play("heal", 0.05, -4.0)
				vfx.spawn("heal", fx_root, _chest(a), 0.5, 0.0, Color(0.8, 1.0, 0.8))
				dmg_log.spawn_status(_chest(a), "+%d" % gain, Color(0.55, 1.0, 0.6), a)
	_relic_rewards()
	await get_tree().create_timer(0.9).timeout
	if run != _run_id:
		return
	for e in enemies:
		e.queue_free()
	enemies.clear()
	room["cleared"] = true
	var before := map.tiles.duplicate()
	exits = map.generate_exits(room)
	print("[VD] exits from room %d: %s" % [room["id"], str(exits.map(func(x): return x["label"]))])
	# 새 복도·방 블록이 바닥 아래에서 시간차로 솟아오르고, 그 둘레에 떠다니는 프랍이 따라 떠오른다
	var new_cells := map.tiles.keys().filter(func(c: Vector2i) -> bool: return not before.has(c))
	if not new_cells.is_empty():
		props.remove_near(new_cells)
		var rise := board.raise_tiles(new_cells, VDMap.to_world(room, int(room["len"]) - 1, 2))
		for ex in exits:
			props.scatter_room(map, map.rooms[ex["room_id"]], rise * 0.5)
		await get_tree().create_timer(rise * 0.85).timeout
		if run != _run_id:
			return
	board.exits = exits
	board.show_exits = true
	board.queue_redraw()
	_set_state(State.CHOOSE_PATH)
	if exits.size() == 1:
		_show_msg("길이 하나뿐 — 전진합니다", 1.2)
		await get_tree().create_timer(0.8).timeout
		if run != _run_id or state != State.CHOOSE_PATH:
			return
		choose_path(0)
	else:
		_show_msg("갈림길!  빛나는 길을 클릭하거나 아래 버튼으로 선택", 3.0)


## 갈림길 선택 → 복도를 따라 다음 방으로 이동 → 저장된 진형으로 재배치.
func choose_path(i: int) -> void:
	if state != State.CHOOSE_PATH or i < 0 or i >= exits.size():
		return
	var ex: Dictionary = exits[i]
	var next_room: Dictionary = map.rooms[ex["room_id"]]
	print("[VD] path chosen: %d (%s) -> room %d" % [i, ex["label"], next_room["id"]])
	audio.play("click")
	board.show_exits = false
	_path_box.visible = false
	_set_state(State.TRAVEL)
	_travel(_run_id, ex, next_room)


func _travel(run: int, ex: Dictionary, next_room: Dictionary) -> void:
	var corridor: Array = ex["corridor"]
	var longest := 0.0
	var k := 0
	var taken := {}
	for a in allies:
		# 저장한 진형 자리가 이 방 모양의 아군 구역에 없으면 가장 가까운 아군 칸으로
		var local: Vector2i = VDMap.nearest_zone_cell(next_room, formation[a.id], "A", taken)
		taken[local] = true
		formation[a.id] = local
		var dest := VDMap.to_world(next_room, local.x, local.y)
		if not a.alive:
			a.cell = dest
			a.home_cell = dest
			a.snap_to_cell()
			continue
		var lane := k % 2
		var waypoints: Array[Vector2i] = [corridor[lane], corridor[corridor.size() - 2 + lane], dest]
		var tw := create_tween()
		tw.tween_interval(0.12 * k)
		# 출발 순서가 올 때부터 걷기 애니메이션(VDUnit.moving)
		tw.tween_callback(func() -> void:
			a.moving = true
			vfx.spawn("dash", ground_fx, a.position, 1.0, 0.0, Color.WHITE, Vector2.ONE, a.position.x > VDData.to_screen(Vector2(corridor[0])).x))
		var prev := a.cell
		var total := 0.12 * k
		for wp in waypoints:
			var d := float(VDData.manhattan(prev, wp))
			var dur := maxf(0.15, d * TRAVEL_SEC_PER_TILE)
			tw.tween_property(a, "position", VDData.to_screen(Vector2(wp)), dur)
			total += dur
			prev = wp
		a.cell = dest
		a.home_cell = dest
		tw.tween_callback(func() -> void: a.moving = false)
		longest = maxf(longest, total)
		k += 1
	await get_tree().create_timer(longest + 0.2).timeout
	if run != _run_id:
		return
	room = next_room
	board.current_room = room
	board.exits = []
	exits = []
	for a in allies:
		a.snap_to_cell()
	wave += 1
	_cam_target = VDData.to_screen(VDMap.center_f(room))
	_set_state(State.PLACEMENT)
	_show_msg("새 구역(%s) 도착 — 적의 위치를 보고 진형을 잡은 뒤 전투를 시작하세요" % VDMap.SHAPE_NAMES[room["shape"]], 2.4)
	_spawn_wave(_run_id)


func _do_game_over() -> void:
	_set_state(State.GAMEOVER)
	print("[VD] GAME OVER at wave %d" % wave)
	_lbl_over.text = "거점 함락 — 구역 %d · WAVE %d 도달 · 정수 %d" % [room["id"] + 1, wave, essence]
	_over_panel.visible = true
	audio.play("defeat", 0.0)
	game_over.emit(wave)


func restart() -> void:
	_new_run()
	audio.play("click")


func _set_state(s: State) -> void:
	state = s
	board.placement_mode = (s == State.PLACEMENT)
	board.queue_redraw()
	# 전투에 집중: 배치 완료(적 등장)부터 살짝 줌인, 전투가 끝나면(클리어·게임 오버) 바로 원래대로
	match s:
		State.SPAWNING:
			_zoom_to(BATTLE_ZOOM, ZOOM_IN_SEC)
		State.PLACEMENT, State.TRANSITION, State.GAMEOVER:
			_zoom_to(1.0, ZOOM_OUT_SEC)
			nebula_tuner.set_boss(false)   # 전투가 끝나면 보스 연출도 풀린다
	match s:
		State.PLACEMENT:
			_refresh_main_button()
		State.SPAWNING:
			_btn_main.text = "전투 개시!"
			_btn_main.disabled = true
		State.BATTLE:
			_btn_main.text = "전투 중"
			_btn_main.disabled = true
		State.TRANSITION:
			_btn_main.text = "회복 중..."
			_btn_main.disabled = true
		State.CHOOSE_PATH:
			_btn_main.text = "길 선택"
			_btn_main.disabled = true
			_rebuild_path_buttons()
		State.TRAVEL:
			_btn_main.text = "이동 중..."
			_btn_main.disabled = true
		State.GAMEOVER:
			_btn_main.text = "게임 오버"
			_btn_main.disabled = true
	_refresh_wave_label()
	state_changed.emit(s)


func _zoom_to(z: float, dur: float) -> void:
	if _zoom_tween:
		_zoom_tween.kill()
	if camera.base_zoom.is_equal_approx(Vector2(z, z)):
		return
	# base_zoom 위에 카메라 위빙의 줌 호흡이 곱해진다
	_zoom_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_zoom_tween.tween_property(camera, "base_zoom", Vector2(z, z), dur)


## 배치 단계 버튼: 적이 등장 중이면 잠그고, 끝나면 "배치 완료".
func _refresh_main_button() -> void:
	if state != State.PLACEMENT:
		return
	_btn_main.text = "적 등장 중..." if _spawning else "배치 완료 ▶"
	_btn_main.disabled = _spawning


func _rebuild_path_buttons() -> void:
	for c in _path_box.get_children():
		c.queue_free()
	if exits.size() < 2:
		_path_box.visible = false
		return
	for i in exits.size():
		var b := Button.new()
		b.text = "길 %d  %s" % [i + 1, exits[i]["label"]]
		b.custom_minimum_size = Vector2(240, 64)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(choose_path.bind(i))
		_path_box.add_child(b)
	_path_box.visible = true


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	if state != State.BATTLE:
		return
	_tick_team(allies, enemies, delta)
	_tick_team(enemies, allies, delta)
	relics.tick(delta)


func _tick_team(team_units: Array[VDUnit], foes: Array[VDUnit], dt: float) -> void:
	for u in team_units:
		if not u.alive:
			continue
		u.tick_status(dt)
		# 기절·빙결 중이거나 스킬 연출 중이면 쉰다 (타이머도 멈춘다)
		if u.stun_timer > 0.0 or u.casting:
			continue
		# 롤토체스식 자동 시전: 기본 공격으로 마나가 가득 차면 다음 행동 대신 액티브 스킬
		if u.mana_full() and not u.moving and skills.cast(u):
			u.mana = 0.0
			u.atk_timer = 0.0
			continue
		u.atk_timer += dt
		u.move_timer += dt
		if u.is_healer:
			var patient := _most_wounded(u, team_units)
			if patient != null and u.atk_timer >= u.atk_cd * u.cd_mult() and VDData.manhattan(u.cell, patient.cell) <= u.attack_range:
				u.atk_timer = 0.0
				var amount := u.atk * 1.5
				patient.heal(amount)
				u.gain_mana(u.mana_gain)
				u.attack_anim(patient.position)
				audio.play("heal")
				# 힐러 발밑 마법진 + 대상 위 회복 반짝임
				vfx.loop("magic_circle", ground_fx, u.position, 0.35, 0.2, 0.0, Color(0.6, 1.0, 0.7), Vector2(1.0, 0.5), 0.3, 1.5)
				vfx.spawn("heal", fx_root, _chest(patient), 0.5, 0.0, Color(0.8, 1.0, 0.8))
				dmg_log.spawn_status(_chest(patient), "+%d" % int(amount), Color(0.55, 1.0, 0.6), patient)
				continue
		var target := _nearest(u, foes)
		if target == null:
			continue
		var d := VDData.manhattan(u.cell, target.cell)
		if d <= u.attack_range:
			if u.atk_timer >= u.atk_cd * u.cd_mult() and not u.moving:
				u.atk_timer = 0.0
				u.gain_mana(u.mana_gain)
				u.attack_anim(target.position)
				_play_attack_sfx(u)
				_attack_vfx(u, target)
				if u.team == 0:
					relics.on_ally_attack(u, target)   # 유물 트리거: 평타 횟수·특정 영웅 공격
				if u.id == "mage":
					_delayed_hit(u, target, 0.22)   # 오브가 날아간 뒤 명중
				elif u.id == "skirmisher":
					_delayed_hit(u, target, SPORE_FLIGHT_SEC)
				else:
					if u.id == "fast":
						u.move_timer = 0.0
					_apply_hit(u, target)
		elif u.move_timer >= u.move_cd * u.cd_mult() and not u.moving:
			var next := _step_toward(u, target.cell)
			if next != u.cell:
				u.move_timer = 0.0
				if u.id == "fast":
					var left := VDData.to_screen(Vector2(next)).x < u.position.x
					vfx.spawn("dash", ground_fx, u.position, 0.85, 0.0, Color(0.85, 0.55, 1.0), Vector2.ONE, left, 1.8)
				else:
					vfx.spawn("dust", ground_fx, u.position, 1.0, 0.0, Color(1, 1, 1, 0.7))
				u.move_to_cell(next, u.move_sec)


## 피해 적용 + 명중 연출 + 숫자.
func _apply_hit(u: VDUnit, target: VDUnit) -> void:
	if not is_instance_valid(target) or not target.alive:
		return
	target.last_hit_by = u
	var dealt := target.take_damage(u.atk)
	if u.id == "skirmisher":
		audio.play("ally_hurt", 0.1)
	_hit_vfx(u, target)
	_hit_feel(u)
	focus.add_heat(target.position, 1.6 if (u.is_boss or target.is_boss) else 1.0)   # 명중한 곳으로 시선이 조금 끌린다
	dmg_log.spawn(_chest(target) + Vector2(0, -16), int(dealt), u.atk >= 50.0 or u.is_boss, target)


## 유물 피해: 영웅 피해와 같은 길(take_damage·숫자·명중 연출)을 쓴다. 처치도 같은 died 시그널로 돈다.
func relic_damage(target: VDUnit, amount: float, relic_id: String, col: Color, big: bool) -> float:
	if not is_instance_valid(target) or not target.alive or amount <= 0.0:
		return 0.0
	target.last_hit_by = relic_id
	var dealt := target.take_damage(amount)
	var at := _chest(target)
	if big:
		vfx.spawn("hit_light", fx_root, at, 1.4, randf() * TAU, col)
		focus.add_heat(target.position, 0.8)
	dmg_log.spawn(at + Vector2(0, -16), int(dealt), big, target)
	return dealt


## 구역 클리어 보상: 성좌판 칸 해금 → (확률) 침식 → 유물 3택1 제시.
func _relic_rewards() -> void:
	var opened := relic_board.unlock(VDRelicData.UNLOCK_PER_CLEAR)
	if opened > 0:
		_show_msg("성좌판 칸이 열렸습니다  (%d/%d)" % [relic_board.open_count(), VDRelicData.BOARD_CELLS.size()], 1.6)
	var boss_room := wave % VDData.WAVES_PER_STAGE == 0
	if boss_room or randf() < VDRelicData.CORRUPT_CHANCE:
		var c := relic_board.corrupt_random()
		if c.x >= 0:
			_show_msg("공허가 성좌판을 침식했습니다!  (우클릭으로 정화)", 2.0)
			print("[VD] relic board corrupted at %s" % str(c))
	var ids := []
	for i in VDRelicData.PICK_COUNT:
		ids.append(VDRelicData.RELIC_ORDER[randi() % VDRelicData.RELIC_ORDER.size()])
	relic_hud.offer(ids)
	print("[VD] relic offer: %s  open=%d  fired=%s" % [str(ids), relic_board.open_count(), str(relics.fire_count)])


## 타격감: 약한 카메라 셰이크 + 짧은 히트스탑. 아군의 묵직한 공격(기사)·보스 공격은 조금 더 세게.
## 적이 아군을 때릴 때는 셰이크만 (보스만 히트스탑).
func _hit_feel(u: VDUnit) -> void:
	if u.team == 0:
		var heavy := u.id == "knight"
		camera.shake(0.45 if heavy else 0.32)
		camera.hitstop(0.05 if heavy else 0.03)
	else:
		camera.shake(0.5 if u.is_boss else 0.28)
		if u.is_boss:
			camera.hitstop(0.05)


func _delayed_hit(u: VDUnit, target: VDUnit, delay: float) -> void:
	var run := _run_id
	var shot_wave := wave
	await get_tree().create_timer(delay).timeout
	if run != _run_id or wave != shot_wave or state != State.BATTLE or not is_instance_valid(u):
		return
	_apply_hit(u, target)


## 유닛의 가슴 높이(비주얼 위쪽 끝의 55%). 원화 유닛은 150px 안팎, 박스 유닛은 70px.
func _chest(u: VDUnit) -> Vector2:
	return u.position + Vector2(0, u._top * 0.55)


## 공격 순간의 연출(공격자 쪽): 기사 베기 궤적 / 건너 총구 섬광 + 예광 / 마법사 오브 투사체.
func _attack_vfx(u: VDUnit, target: VDUnit) -> void:
	var from := _chest(u)
	var to := _chest(target)
	var dir := (to - from).normalized()
	match u.id:
		"knight":
			var mid := from.lerp(to, 0.6)
			vfx.spawn("slash", fx_root, mid, 2.8, dir.angle(), Color(0.75, 0.9, 1.0), Vector2.ONE, dir.x < 0.0)
		"gunner":
			var muzzle := from + dir * 40.0
			vfx.spawn("hit_light", fx_root, muzzle, 1.2, dir.angle(), Color(1.0, 0.95, 0.7))
			VDFx.tracer(fx_root, muzzle, to, Color(1.0, 0.95, 0.75))
		"mage":
			vfx.projectile("orb", fx_root, from + Vector2(0, -10), to, 0.22, 0.2, Color(0.85, 0.6, 1.0), 8.0)
		"skirmisher":
			var muzzle := from + Vector2(u._facing * 21.0, 0.0)
			var tint := Color(1.0, 0.35, 0.8)
			vfx.spawn("hit_light", fx_root, muzzle, 1.0, dir.angle(), tint)
			vfx.projectile("orb", fx_root, muzzle, to, SPORE_FLIGHT_SEC, 0.14, tint, 8.0,
				func() -> Vector2:
					return _chest(target) if is_instance_valid(target) and target.alive else to)
		_:
			pass


## 명중 순간의 연출(대상 쪽): 직업별 스파크, 적의 공격은 보라-붉은 스파크.
func _hit_vfx(u: VDUnit, target: VDUnit) -> void:
	var at := _chest(target)
	if u.id == "skirmisher":
		vfx.spawn("burst", fx_root, at, 0.35, 0.0, Color(1.0, 0.35, 0.8))
		return
	if u.team == 1:
		vfx.spawn("hit_light", fx_root, at, 1.8, randf() * TAU, Color(1.0, 0.55, 0.75))
		return
	match u.id:
		"knight":
			vfx.spawn("hit_heavy", fx_root, at, 1.8, randf_range(-0.6, 0.6), Color(0.9, 0.95, 1.0))
		"gunner":
			vfx.spawn("gun_hit", fx_root, at, 0.55, randf() * TAU)
		"mage":
			vfx.spawn("burst", fx_root, at, 0.45, 0.0, Color(0.85, 0.55, 1.0))
		_:
			vfx.spawn("hit_light", fx_root, at, 1.4, randf() * TAU)


## 공격자별 효과음: 아군은 직업별 공격음 + 명중음, 적은 공격음 + 아군 피격음.
func _play_attack_sfx(u: VDUnit) -> void:
	if u.team == 1:
		audio.play("enemy_attack", 0.12)
		if u.id != "skirmisher":
			audio.play("ally_hurt", 0.1)
		return
	match u.id:
		"knight":
			audio.play("knight_attack", 0.08)
			audio.play("knight_hit", 0.1)
		"gunner":
			audio.play("gun", 0.08)
			audio.play("gun_hit", 0.1)
		"mage":
			audio.play("mage_cast", 0.05)
			audio.play("mage_hit", 0.1)
		_:
			audio.play("enemy_hit", 0.1)


func _nearest(u: VDUnit, foes: Array[VDUnit]) -> VDUnit:
	var best: VDUnit = null
	var best_d := 1 << 30
	for f in foes:
		if not f.alive:
			continue
		var d := VDData.manhattan(u.cell, f.cell)
		if d < best_d:
			best_d = d
			best = f
	return best


func _most_wounded(healer: VDUnit, team_units: Array[VDUnit]) -> VDUnit:
	var best: VDUnit = null
	var best_ratio := 0.75
	for a in team_units:
		if not a.alive or a == healer:
			continue
		var r := a.hp / a.max_hp
		if r < best_ratio:
			best_ratio = r
			best = a
	return best


## 현재 방 안에서만 한 칸 전진 (전투는 방 안에 갇힌다).
func _step_toward(u: VDUnit, goal: Vector2i) -> Vector2i:
	var best := u.cell
	var best_d := VDData.manhattan(u.cell, goal)
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nc: Vector2i = u.cell + dir
		if not VDMap.in_room(room, nc) or _occupied(nc):
			continue
		var nd := VDData.manhattan(nc, goal)
		if nd < best_d:
			best_d = nd
			best = nc
	return best


# ---------------------------------------------------------------- hud / camera

func _process(_delta: float) -> void:
	for a in allies:
		var c: Dictionary = _cards[a.id]
		c["hp"].value = 100.0 * a.hp / a.max_hp
		c["mana"].value = 100.0 * a.mana / VDData.MAX_MANA
		c["skill"].modulate = Color(1.6, 1.6, 1.2) if a.mana_full() else Color.WHITE
		c["stat"].text = "HP %d/%d  ATK %d" % [int(a.hp), int(a.max_hp), int(a.atk)]
		if a.alive:
			c["panel"].modulate = Color(1, 1, 1, 1)
		else:
			c["panel"].modulate = Color(1, 1, 1, 0.4)
			c["stat"].text = "전투 불능"
	if _boss_bar.visible:
		for e in enemies:
			if e.is_boss:
				_boss_bar.value = 100.0 * e.hp / e.max_hp
				break
	# 카메라: 전투 중엔 가장 치열한 곳(+ 전장 폭에 맞춘 줌), 이동 중엔 분대 중심, 그 외엔 현재 방 중심.
	# 실제 시간으로 움직인다(히트스탑·배속과 무관). 상태 전환 줌 트윈이 도는 동안은 트윈이 줌을 맡는다.
	# delta / time_scale 는 히트스탑이 시작·끝나는 프레임에 최대 25배로 튀므로 시계로 잰다
	var now_us := Time.get_ticks_usec()
	var dt := clampf((now_us - _cam_clock_us) / 1000000.0, 0.0, 0.1) if _cam_clock_us > 0 else 0.0
	_cam_clock_us = now_us
	var zoom_tweening := _zoom_tween != null and _zoom_tween.is_running()
	if zoom_tweening or state != State.BATTLE:
		focus.sync_zoom(camera.base_zoom.x)
	match state:
		State.BATTLE:
			focus.track(dt, allies, enemies, _cam_target, get_viewport_rect().size, BATTLE_ZOOM)
			if not zoom_tweening:
				camera.base_zoom = Vector2(focus.zoom, focus.zoom)
		State.TRAVEL:
			var sum := Vector2.ZERO
			var n := 0
			for a in allies:
				if a.alive:
					sum += a.position
					n += 1
			if n > 0:
				_cam_target = sum / n
			focus.follow(dt, _cam_target, true)
		_:
			focus.follow(dt, _cam_target)
	camera.position = focus.pos


func _refresh_wave_label() -> void:
	var stage := (wave - 1) / VDData.WAVES_PER_STAGE + 1
	var in_stage := (wave - 1) % VDData.WAVES_PER_STAGE + 1
	_lbl_wave.text = "구역 %d  ·  스테이지 %d  ·  WAVE %d/%d" % [room.get("id", 0) + 1, stage, in_stage, VDData.WAVES_PER_STAGE]


func _refresh_essence() -> void:
	_lbl_essence.text = "공허 정수  %d" % essence


func _show_msg(text: String, dur := 1.6) -> void:
	_lbl_msg.text = text
	_lbl_msg.modulate.a = 1.0
	if _msg_tween:
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_interval(dur)
	_msg_tween.tween_property(_lbl_msg, "modulate:a", 0.0, 0.4)


func _toggle_speed() -> void:
	audio.play("click")
	# x1 → x1.5 → x2 → x1. 히트스탑 중이어도 배속이 꼬이지 않게 camera 를 거친다
	var cur := camera.game_speed()
	var next: float = GAME_SPEEDS[0]
	for sp in GAME_SPEEDS:
		if sp > cur + 0.01:
			next = sp
			break
	camera.set_game_speed(next)
	_refresh_speed_label()


func _refresh_speed_label() -> void:
	_btn_speed.text = "속도 x%s" % ("%.1f" % camera.game_speed()).trim_suffix(".0")
