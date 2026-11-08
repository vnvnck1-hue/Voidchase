## 성좌판 HUD: 화면 오른쪽에 육각 10칸 + 아래 보관함. 전투 밖에서 드래그로 놓고/옮기고/빼고,
## 침식 칸은 우클릭으로 정화(정수 소모). 구역 클리어 보상(3택1) 패널도 여기서 띄운다.
## 발동 순간 칸이 펄스하고, 투사체는 이 칸의 화면 좌표를 월드로 바꿔 전장으로 날아간다.
## 생김새는 시안 PSD(화면 컨셉_2) 그대로: 칸 좌표·투명도·색·아이콘은 VDRelicLayout(생성물)과 assets/textures/relic_ui/.
class_name VDRelicHud
extends Control

const Layout := preload("res://scripts/void_defense/relics/vd_relic_layout.gd")

const TRAY_X := -170.0               # 보관함: 보드 왼쪽 아래 (보드 아래는 분대 카드 자리). 배치 중에만 보인다
const TRAY_Y := 700.0
const TRAY_SLOT := 66.0
const TRAY_COLS := 4
const TRAY_MAX := 8
const TRAY_ICON_SCALE := 0.62
const PULSE_SEC := 0.45              # 발동 연출 길이: 앞 BURST_K 동안 시안 섬광, 그 뒤 시안 테두리가 사라짐
const BURST_K := 0.35
const TIP_W := 300.0
## 칸 바깥 획(시안 26%)을 이만큼 더 진하게: 시안은 보드 뒤가 밝은 보라라 칸이 보이지만 전장 배경은 훨씬 어둡다
const EDGE_OPACITY := 0.55

var b: VDBattle
var board: VDRelicBoard
var runtime: VDRelicRuntime

var _drag := {}                      # {"from": "tray"|"cell", "index"/"cell", "id"}
var _hover_cell := Vector2i(-99, -99)
var _hover_tray := -1
var _pulses := []                    # [{cell, t}]
var _offers := []                    # 대기 중인 보상 묶음 (각각 Array[String])
var _tex := {}                       # 이름 -> Texture2D
var _badge_font: Font
var _tip_root: Control               # 말꼬리 끝이 원점, 시안처럼 살짝 기울어진 툴팁
var _tip: PanelContainer
var _tip_title: Label
var _tip_label: Label
var _tip_tail := false
var _pick: PanelContainer
var _pick_box: VBoxContainer
var _offer_open := false             # 보상 카드가 떠 있는 중
var _offer_layer: Control            # 화면 가운데 보상 카드 층 (HUD 루트에 붙는다)
var _cards: Array[Button] = []
var _cell_fx := {}                   # Vector2i -> {kind, t}: 칸 연출 (해금·침식·정화·놓기)
var _tray_pop := {}                  # 보관함 칸 i -> 경과(초): 날아온 유물이 톡 튄다
const CELL_FX_SEC := {"unlock": 0.7, "corrupt": 0.6, "purify": 0.6, "place": 0.35, "rotate": 0.25}
const CARD := Vector2(300, 400)
const CARD_GAP := 36.0

## 회전 UX: 소켓 유물에는 늘 작은 ⟳ 배지, 가리키면 칸 둘레에 도는 화살표 + "클릭·휠 회전" 안내.
## 돌리면 칸 전체가 이전 방향에서 새 방향으로 휙 돌아 들어오고(뒤로 살짝 넘침), 둘레에 휩쓴 호가 남고,
## 소켓 연결이 새로 생기거나 끊기면 칸 위에 "연결!" / "연결 끊김" 글자가 뜬다.
const ROT_SEC := 0.34
const TAP_MOVE := 10.0               # 이 거리 안에서 누르고 떼면 클릭(회전), 넘으면 드래그
const HINT_SEC := 2.6                # 소켓 유물을 처음 올렸을 때 회전 안내를 띄우는 시간
const FLOAT_SEC := 0.9
## 칸 호버 강조: 나머지 화면(전장·카드·상단 바)을 딤드하고 가리킨 칸을 키워 빛낸다.
const DIM_ALPHA := 0.58              # 배치 중
const DIM_ALPHA_BATTLE := 0.32       # 전투 중엔 전장을 너무 가리지 않게
const HOVER_SCALE := 0.08
## 그리기 순서는 z 로: 턴테이블 캐릭터(z 최대 ~220) 위, 게임 오버 패널(500) 아래.
## 딤 막 < 성좌판(이 HUD) < 안내 메시지 띠 < 보상 카드 층
const Z_DIM := 400
var _rot_anim := {}                  # Vector2i -> {t, ang}: 회전 연출 (ang = 시작 각도 오프셋, 0 으로 돌아온다)
var _floats := []                    # [{pos, text, col, t}]: 칸 위로 떠오르는 짧은 글자
var _hint := {}                      # {cell, t}: 회전 안내 말풍선
var _rotated_once := false           # 한 번이라도 돌려 봤으면 처음 놓을 때 안내는 생략
var _press_pos := Vector2.ZERO
var _dim: ColorRect
var _dim_k := 0.0
var _hov_k := {}                     # Vector2i -> 0..1 호버 강조 정도 (부드럽게)


func setup(battle: VDBattle, board_: VDRelicBoard, runtime_: VDRelicRuntime) -> void:
	b = battle
	board = board_
	runtime = runtime_
	runtime.origin_of = cell_world_pos
	runtime.fired.connect(_on_fired)
	board.changed.connect(queue_redraw)
	board.cell_fx.connect(func(c: Vector2i, kind: String) -> void:
		_cell_fx[c] = {"kind": kind, "t": 0.0}
		if kind == "unlock":
			b.audio.play("chime", 0.05, -4.0, 1.2)
		elif kind == "corrupt":
			b.audio.play("frost", 0.05, -4.0, 0.6)
		elif kind == "place" and not _rotated_once and not board.ports_of(c).is_empty():
			_hint = {"cell": c, "t": 0.0})
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_on_mouse_exited)
	SceneSwitcher.pin(self, Vector2(1, 0), Layout.PIN_RECT)

	for n in ["hex_edge", "hex_base", "hex_ring_fire", "hex_ring_gauge", "hex_fill_gauge", "hex_burst", "star", "star_small"]:
		_tex[n] = load(Layout.DIR + n + ".png")
	for id in Layout.RELIC_ICON:
		_tex[Layout.RELIC_ICON[id]] = load(Layout.DIR + Layout.RELIC_ICON[id] + ".png")
	_badge_font = load("res://assets/fonts/ARCO.otf")

	_build_tip()

	# 보드 뒤 어두운 구름 (시안의 사각형 4): 시안에서 분대 카드·하단 패널보다 아래 레이어라 HUD 맨 뒤에 끼운다
	var backdrop := TextureRect.new()
	backdrop.texture = load(Layout.DIR + "board_backdrop.png")
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.modulate = Color(1, 1, 1, Layout.OPACITY_BACKDROP)
	SceneSwitcher.pin(backdrop, Vector2(1, 0), Rect2(Layout.BACKDROP_RECT.position + Layout.PIN_RECT.position, Layout.BACKDROP_RECT.size))
	get_parent().add_child(backdrop)
	get_parent().move_child(backdrop, 0)

	# 칸 호버 딤: 화면 전체를 덮는 어둠막을 이 HUD 바로 아래에 (보드·툴팁·보상 카드만 그 위로)
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.0, 0.06)
	_dim.modulate.a = 0.0
	_dim.visible = false
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.z_index = Z_DIM
	z_index = Z_DIM + 1

	# 보상 선택 패널: 보드 왼쪽에 세로로 3장
	_pick = PanelContainer.new()
	_pick.visible = false
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color(0.08, 0.05, 0.16, 0.96)
	pb.border_color = Color(1.0, 0.85, 0.45)
	pb.set_border_width_all(2)
	pb.set_corner_radius_all(8)
	pb.set_content_margin_all(12)
	_pick.add_theme_stylebox_override("panel", pb)
	_pick.position = Vector2(-380, 40)
	_pick_box = VBoxContainer.new()
	_pick_box.add_theme_constant_override("separation", 8)
	_pick.add_child(_pick_box)
	add_child(_pick)


## 시안의 정보창: 보라 박스 + 진한 테두리 + 그림자 + 위로 향한 말꼬리, -5.5° 기울어짐.
func _build_tip() -> void:
	_tip_root = Control.new()
	_tip_root.visible = false
	_tip_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_root.rotation = deg_to_rad(Layout.TIP_ROT_DEG)
	_tip_root.z_index = 10
	add_child(_tip_root)

	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.custom_minimum_size = Vector2(TIP_W, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Layout.TIP_FILL
	sb.border_color = Layout.TIP_BORDER_COLOR
	sb.set_border_width_all(Layout.TIP_BORDER)
	sb.set_corner_radius_all(7)
	sb.shadow_color = Layout.TIP_SHADOW_COLOR
	sb.shadow_offset = Layout.TIP_SHADOW_OFFSET
	sb.shadow_size = 2
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 14
	_tip.add_theme_stylebox_override("panel", sb)
	_tip_root.add_child(_tip)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	_tip.add_child(box)
	_tip_title = Label.new()
	_tip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tf := SystemFont.new()
	tf.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans KR", "sans-serif"])
	tf.font_weight = 800
	_tip_title.add_theme_font_override("font", tf)
	_tip_title.add_theme_font_size_override("font_size", Layout.TIP_TITLE_SIZE)
	_tip_title.add_theme_color_override("font_color", Layout.TIP_TITLE_COLOR)
	box.add_child(_tip_title)
	_tip_label = Label.new()
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size = Vector2(TIP_W - 40.0, 0)   # 폭을 못 박아야 줄바꿈 높이가 제대로 나온다
	_tip_label.add_theme_font_override("font", VDData.font())
	_tip_label.add_theme_font_size_override("font_size", Layout.TIP_BODY_SIZE)
	_tip_label.add_theme_color_override("font_color", Layout.TIP_BODY_COLOR)
	_tip_label.add_theme_color_override("font_outline_color", Layout.TIP_BODY_OUTLINE_COLOR)
	_tip_label.add_theme_constant_override("outline_size", 4)
	box.add_child(_tip_label)

	# 말꼬리는 박스 위에 그려 박스 윗테두리를 덮는다
	var tail := Control.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.draw.connect(func() -> void:
		if not _tip_tail:
			return
		var pts := PackedVector2Array(Layout.TIP_TAIL)
		tail.draw_colored_polygon(pts, Layout.TIP_FILL)
		tail.draw_line(pts[0], pts[1], Layout.TIP_BORDER_COLOR, Layout.TIP_BORDER)
		tail.draw_line(pts[1], pts[2], Layout.TIP_BORDER_COLOR, Layout.TIP_BORDER))
	_tip_root.add_child(tail)


func _process(dt: float) -> void:
	for c in _cell_fx.keys():
		_cell_fx[c]["t"] += dt
		if _cell_fx[c]["t"] >= CELL_FX_SEC[_cell_fx[c]["kind"]]:
			_cell_fx.erase(c)
	for i in _tray_pop.keys():
		_tray_pop[i] += dt
		if _tray_pop[i] > 0.35:
			_tray_pop.erase(i)
	for p in _pulses:
		p["t"] += dt
	_pulses = _pulses.filter(func(p: Dictionary) -> bool: return p["t"] < PULSE_SEC)
	for c in _rot_anim.keys():
		_rot_anim[c]["t"] += dt
		if _rot_anim[c]["t"] >= ROT_SEC:
			_rot_anim.erase(c)
	for f in _floats:
		f["t"] += dt
	_floats = _floats.filter(func(f: Dictionary) -> bool: return f["t"] < FLOAT_SEC)
	if not _hint.is_empty():
		_hint["t"] += dt
		if _hint["t"] >= HINT_SEC or board.relic_at(_hint["cell"]) == "":
			_hint = {}
	# 호버 강조·딤 (실제 시간으로 부드럽게)
	var on_slot := VDRelicData.BOARD_CELLS.has(_hover_cell) or (editable() and _hover_tray >= 0) or not _drag.is_empty()
	var want := (DIM_ALPHA if editable() else DIM_ALPHA_BATTLE) if on_slot else 0.0
	_dim_k = lerpf(_dim_k, want, 1.0 - exp(-dt * (14.0 if want > _dim_k else 8.0)))
	if _dim_k < 0.005 and want == 0.0:
		_dim_k = 0.0
	_dim.modulate.a = _dim_k
	_dim.visible = _dim_k > 0.0
	for c in VDRelicData.BOARD_CELLS:
		var to := 1.0 if c == _hover_cell else 0.0
		var k: float = _hov_k.get(c, 0.0)
		k = lerpf(k, to, 1.0 - exp(-dt * 18.0))
		if k < 0.002 and to == 0.0:
			_hov_k.erase(c)
		else:
			_hov_k[c] = k
	queue_redraw()


func editable() -> bool:
	return b != null and b.state not in [VDBattle.State.BATTLE, VDBattle.State.SPAWNING, VDBattle.State.GAMEOVER]


# ---------------------------------------------------------------- geometry

func cell_center(c: Vector2i) -> Vector2:
	return Layout.CELL_CENTERS.get(c, Vector2(-1000, -1000))


func tray_rect(i: int) -> Rect2:
	return Rect2(Vector2(TRAY_X + (i % TRAY_COLS) * TRAY_SLOT, TRAY_Y + (i / TRAY_COLS) * TRAY_SLOT), Vector2(TRAY_SLOT - 6.0, TRAY_SLOT - 6.0))


func cell_at(p: Vector2) -> Vector2i:
	for c in VDRelicData.BOARD_CELLS:
		if cell_center(c).distance_to(p) <= Layout.HEX_R * 0.87:
			return c
	return Vector2i(-99, -99)


func tray_at(p: Vector2) -> int:
	for i in TRAY_MAX:
		if tray_rect(i).has_point(p):
			return i
	return -1


## 칸·보관함 위에서만 마우스를 받는다 (넓어진 HUD 사각형이 전장 클릭을 막지 않게). 드래그 중엔 어디서든.
func _has_point(p: Vector2) -> bool:
	if not _drag.is_empty():
		return true
	return cell_at(p).x != -99 or (editable() and Rect2(TRAY_X - 8.0, TRAY_Y - 30.0, TRAY_COLS * TRAY_SLOT + 8.0, 2 * TRAY_SLOT + 30.0).has_point(p))


## 셀 중심의 전장 월드 좌표 (투사체 출발점).
func cell_world_pos(c: Vector2i) -> Vector2:
	var screen := get_global_transform() * cell_center(c)
	return b.get_viewport().get_canvas_transform().affine_inverse() * screen


## 다음에 열릴 칸 (BOARD_CELLS 순서상 첫 잠긴 칸). 시안처럼 잠긴 칸보다 덜 흐리게 그린다.
func _next_locked() -> Vector2i:
	for c in VDRelicData.BOARD_CELLS:
		if board.state_of(c) == VDRelicBoard.Cell.LOCKED:
			return c
	return Vector2i(-99, -99)


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var p: Vector2 = event.position
		_hover_cell = cell_at(p)
		_hover_tray = tray_at(p)
		if not _drag.is_empty():
			if not _drag.get("moved", false) and p.distance_to(_press_pos) >= TAP_MOVE:
				_drag["moved"] = true   # 이제부터 드래그 (그 전엔 클릭일 수 있어 아이콘을 그대로 둔다)
			accept_event()
		_update_tip(p)
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	var p: Vector2 = mb.position
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			if not editable():
				return
			var c := cell_at(p)
			var ti := tray_at(p)
			_press_pos = p
			if board.relic_at(c) != "":
				_drag = {"from": "cell", "cell": c, "id": board.relic_at(c)}
				accept_event()
			elif ti >= 0 and ti < board.tray.size():
				_drag = {"from": "tray", "index": ti, "id": board.tray[ti]}
				accept_event()
		elif not _drag.is_empty():
			# 유물 칸을 누르고 거의 안 움직이고 떼면 = 클릭: 회전
			if _drag["from"] == "cell" and not _drag.get("moved", false):
				var c: Vector2i = _drag["cell"]
				_drag = {}
				rotate_cell(c, 1)
				_update_tip(p)
			else:
				_drop(p)
			accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		var c := cell_at(p)
		if board.state_of(c) == VDRelicBoard.Cell.CORRUPT:
			try_purify(c)
			accept_event()
		elif board.relic_at(c) != "" and editable():
			rotate_cell(c, 1)
			_update_tip(p)
			accept_event()
	elif mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and mb.pressed and _drag.is_empty():
		# 휠: 위로 = 시계 방향, 아래로 = 반대
		var c := cell_at(p)
		if board.relic_at(c) != "" and editable():
			rotate_cell(c, 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			_update_tip(p)
			accept_event()


## 유물 칸 회전 (클릭·우클릭·휠 공통): 소켓 60° × steps. 칸이 휙 돌아 들어오고, 연결이 생기거나 끊기면 글자로 알린다.
func rotate_cell(c: Vector2i, steps: int) -> bool:
	if board.ports_of(c).is_empty():
		b._show_msg("이 유물에는 소켓이 없어 회전해도 달라지지 않습니다", 1.2)
		b.audio.play("denied", 0.03)
		_rot_anim[c] = {"t": ROT_SEC * 0.55, "ang": 0.25 * (1 if steps > 0 else -1)}   # 거절: 살짝 꿈틀만
		return false
	var before := _links_of(c)
	board.rotate(c, steps)
	_rotated_once = true
	_hint = {}
	var after := _links_of(c)
	# 화면에서 소켓 하나가 옮겨 가는 각도 (시안은 x 가 뒤집혀 있어 논리 방향과 부호가 다를 수 있다)
	var step_ang := _dir_vec(0).angle_to(_dir_vec(1)) * steps
	_rot_anim[c] = {"t": 0.0, "ang": -step_ang}
	var gained := 0
	for nb in after:
		if not before.has(nb):
			gained += 1
	var lost := 0
	for nb in before:
		if not after.has(nb):
			lost += 1
	var top := cell_center(c) + Vector2(0.0, -Layout.HEX_R * 0.95)
	if top.y < 110.0:
		top = cell_center(c) + Vector2(0.0, Layout.HEX_R * 1.25)   # 맨 위 칸: 상단 바·화면 끝에 글자가 가리지 않게 아래로
	if gained > 0:
		_floats.append({"pos": top, "text": "연결!" if gained == 1 else "연결 ×%d!" % gained, "col": Color(0.55, 1.0, 0.75), "t": 0.0})
		for nb in after:
			if not before.has(nb):
				_pulses.append({"cell": nb, "t": PULSE_SEC * 0.2, "col": Color.WHITE})
		b.audio.play("chime", 0.03, -5.0, 1.35)
	elif lost > 0:
		_floats.append({"pos": top, "text": "연결 끊김", "col": Color(0.75, 0.72, 0.85), "t": 0.0})
	b.audio.play("tick", 0.03, -3.0, 1.15 if steps > 0 else 0.95)
	b.audio.play("click", 0.05, -8.0, 1.4)
	return true


## c 와 소켓으로 이어진 이웃 칸들 (회전 전후 비교용).
func _links_of(c: Vector2i) -> Array:
	var out := []
	for nb in VDRelicData.neighbors(c):
		if board.linked(c, nb):
			out.append(nb)
	return out


func _on_mouse_exited() -> void:
	if not _drag.is_empty():
		return
	_hover_cell = Vector2i(-99, -99)
	_hover_tray = -1
	_tip_root.visible = false


func _drop(p: Vector2) -> void:
	var c := cell_at(p)
	var ti := tray_at(p)
	var moved := false
	if board.can_place(c):
		if _drag["from"] == "tray":
			moved = board.place_from_tray(int(_drag["index"]), c)
		else:
			moved = board.move(_drag["cell"], c)
	elif _drag["from"] == "cell" and (ti >= 0 or p.y >= TRAY_Y - 10.0):
		moved = board.to_tray(_drag["cell"])
	if moved:
		b.audio.play("place")
	_drag = {}
	_update_tip(p)


## 침식 정화: 정수가 모자라면 메시지만.
func try_purify(c: Vector2i) -> bool:
	if not editable():
		return false
	if b.essence < VDRelicData.PURIFY_COST:
		b._show_msg("정화에는 공허 정수 %d 이 필요합니다" % VDRelicData.PURIFY_COST, 1.4)
		_cell_fx[c] = {"kind": "corrupt", "t": 0.25}   # 거절: 칸이 한 번 더 부르르
		return false
	if not board.purify(c):
		return false
	b.spend_essence(VDRelicData.PURIFY_COST)
	b.audio.play("heal", 0.05, -2.0)
	b._show_msg("침식을 정화했습니다", 1.2)
	return true


func _update_tip(p: Vector2) -> void:
	if not _drag.is_empty():
		_tip_root.visible = false
		return
	var cell_ok := VDRelicData.BOARD_CELLS.has(_hover_cell)
	if board.relic_at(_hover_cell) != "":
		var id := board.relic_at(_hover_cell)
		var body := _relic_body(id)
		var extra := runtime.describe(_hover_cell)
		var g := runtime.gauge(_hover_cell)
		if g["text"] != "":
			body += "\n충전: " + g["text"]
		if extra != "":
			body += "\n— 지금 자리: " + extra.replace("\n", " · ")
		if not VDRelicData.ports_of_def(id).is_empty():
			body += "\n클릭 · 우클릭 · 휠: 소켓 회전"
		_show_tip(VDRelicData.def(id)["name"], body, _hover_cell)
	elif _hover_tray >= 0 and _hover_tray < board.tray.size():
		var id := board.tray[_hover_tray]
		_show_tip(VDRelicData.def(id)["name"], _relic_body(id), Vector2i(-99, -99), tray_rect(_hover_tray))
	elif cell_ok and board.state_of(_hover_cell) == VDRelicBoard.Cell.CORRUPT:
		_show_tip("공허 침식", "인접한 유물의 효과 −%d%%.\n우클릭: 정수 %d 로 정화" % [int(VDRelicData.CORRUPT_PENALTY * 100), VDRelicData.PURIFY_COST], _hover_cell)
	elif cell_ok and board.state_of(_hover_cell) == VDRelicBoard.Cell.LOCKED:
		_show_tip("잠긴 칸", "구역을 클리어하면 위에서부터 하나씩 열립니다.", _hover_cell)
	else:
		_tip_root.visible = false


func _relic_body(id: String) -> String:
	var d := VDRelicData.def(id)
	return "[%s] %s\n배치: %s" % [d["tag"], d["desc"], d["grammar"]]


## 칸을 가리킬 땐 말꼬리 끝이 칸 아래 꼭짓점에 오게(시안 위치), 보관함은 그 위에 꼬리 없이 띄운다.
func _show_tip(title: String, body: String, c: Vector2i, tray_rc := Rect2()) -> void:
	_tip_title.text = title
	_tip_label.text = body
	_tip.reset_size()
	var right := size.x - 6.0
	if c.x != -99 and board.relic_at(c) != "":
		# 유물 칸: 보드 위 관계 표시(링·화살표·값)를 가리지 않게 보드 왼쪽 바깥에, 칸 높이에 맞춰 꼬리 없이
		_tip_tail = false
		var board_left := Layout.CELL_CENTERS[Vector2i(1, 0)].x - Layout.HEX_R
		_tip_root.position = Vector2(board_left - 16.0, cell_center(c).y - 24.0)
		_tip.position = Vector2(-TIP_W, 0.0)
	elif c.x != -99:
		_tip_tail = true
		var tip := cell_center(c) + Vector2(0.0, Layout.HEX_R * 0.866 + 4.0)
		_tip_root.position = tip
		var x := -TIP_W * Layout.TIP_TAIL_FRAC
		x = minf(x, right - tip.x - TIP_W)
		_tip.position = Vector2(x, 21.0)
	else:
		_tip_tail = false
		var tip := Vector2(tray_rc.get_center().x, TRAY_Y - 34.0)
		_tip_root.position = tip
		_tip.position = Vector2(minf(-TIP_W * 0.5, right - tip.x - TIP_W), -_tip.size.y)
	_tip_root.visible = true
	_tip_root.get_child(1).queue_redraw()


# ---------------------------------------------------------------- rewards

## 구역 클리어 보상 제시. 이미 고르는 중이면 줄을 선다.
func offer(ids: Array) -> void:
	_offers.append(ids)
	if not _offer_open:
		_show_next_offer()


func has_offer() -> bool:
	return _offer_open or not _offers.is_empty()


## 보상 카드: 화면 가운데에 3장이 차례로 뒤집히며(가로 0 → 1, 탄성) 떨어져 앉는다.
## 마우스를 올리면 떠오르며 커지고, 고르면 번쩍 → 보관함으로 빨려 들어가고 나머지는 떨어져 사라진다.
func _show_next_offer() -> void:
	if _offers.is_empty():
		_offer_open = false
		if _offer_layer:
			_offer_layer.queue_free()
			_offer_layer = null
		return
	var ids: Array = _offers.pop_front()
	_offer_open = true
	if _offer_layer:
		_offer_layer.queue_free()
	_offer_layer = Control.new()
	_offer_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer_layer.z_index = Z_DIM + 50   # 딤 막·성좌판 위
	_offer_layer.size = b.hud_root.size
	b.hud_root.add_child(_offer_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.0, 0.08, 0.0)
	dim.size = _offer_layer.size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer_layer.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.5, 0.25)
	var scr := _offer_layer.size
	var head := Label.new()
	head.text = "유물 발견!"
	head.add_theme_font_size_override("font_size", 52)
	head.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	head.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.22))
	head.add_theme_constant_override("outline_size", 14)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer_layer.add_child(head)
	head.reset_size()
	head.position = Vector2((scr.x - head.size.x) * 0.5, scr.y * 0.5 - CARD.y * 0.5 - 150.0)
	VDJuice.bump(head, 1.4)
	var sub := Label.new()
	sub.text = "하나를 골라 보관함에 넣으세요"
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.85, 0.8, 1.0))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer_layer.add_child(sub)
	sub.reset_size()
	sub.position = Vector2((scr.x - sub.size.x) * 0.5, head.position.y + 74.0)
	b.audio.play("chime", 0.0, -3.0, 1.0)
	_cards.clear()
	var total := ids.size() * CARD.x + (ids.size() - 1) * CARD_GAP
	for i in ids.size():
		var card := _make_card(String(ids[i]))
		var base := Vector2((scr.x - total) * 0.5 + i * (CARD.x + CARD_GAP), scr.y * 0.5 - CARD.y * 0.5 + 10.0)
		card.set_meta("base", base)
		card.position = base + Vector2(0, 90)
		card.scale = Vector2(0.0, 1.0)
		card.modulate = Color(2.0, 2.0, 2.0, 0.0)
		card.rotation = randf_range(-0.12, 0.12)
		_offer_layer.add_child(card)
		_cards.append(card)
		var tw := card.create_tween().set_ignore_time_scale(true)
		tw.tween_interval(0.15 + 0.13 * i)
		tw.tween_callback(func() -> void: b.audio.play("tick", 0.02, -3.0, 1.2 + 0.15 * i))
		tw.tween_property(card, "modulate:a", 1.0, 0.08)
		tw.parallel().tween_property(card, "position", base, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(card, "rotation", 0.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate", Color.WHITE, 0.2)


func _make_card(id: String) -> Button:
	var d := VDRelicData.def(id)
	var col := VDRelicData.color_of(id)
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.size = CARD
	btn.pivot_offset = CARD * 0.5
	var mk := func(bg: Color, border: Color, glow: float) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = border
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(18)
		sb.shadow_color = Color(col, glow)
		sb.shadow_size = 18
		sb.shadow_offset = Vector2(0, 6)
		return sb
	btn.add_theme_stylebox_override("normal", mk.call(Color(0.09, 0.05, 0.18, 0.97), col, 0.35))
	btn.add_theme_stylebox_override("hover", mk.call(Color(0.14, 0.08, 0.26, 0.98), col.lightened(0.5), 0.75))
	btn.add_theme_stylebox_override("pressed", mk.call(Color(0.2, 0.12, 0.34, 1.0), Color.WHITE, 0.9))
	btn.add_theme_stylebox_override("hover_pressed", mk.call(Color(0.2, 0.12, 0.34, 1.0), Color.WHITE, 0.9))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.position = Vector2(20, 20)
	vb.size = CARD - Vector2(40, 40)
	vb.add_theme_constant_override("separation", 10)
	btn.add_child(vb)
	var icon_box := CenterContainer.new()
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.custom_minimum_size = Vector2(0, 120)
	vb.add_child(icon_box)
	var ic := TextureRect.new()
	ic.texture = _tex.get(Layout.RELIC_ICON.get(id, ""))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(110, 110)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(ic)
	# 아이콘이 둥실둥실
	var bob := ic.create_tween().set_loops().set_ignore_time_scale(true)
	bob.tween_property(ic, "position:y", -6.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(ic, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var add_label := func(text: String, fs: int, c: Color, outline := 0) -> Label:
		var l := Label.new()
		l.text = text
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_color_override("font_color", c)
		if outline > 0:
			l.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.16))
			l.add_theme_constant_override("outline_size", outline)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(CARD.x - 40, 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(l)
		return l
	add_label.call(d["name"], 28, col.lightened(0.25), 8)
	add_label.call("[%s]" % d["tag"], 16, Color(0.75, 0.7, 0.9))
	add_label.call(d["desc"], 17, Color(0.95, 0.93, 1.0))
	add_label.call("배치: %s" % d["grammar"], 14, Color(0.7, 0.66, 0.85))
	btn.mouse_entered.connect(func() -> void:
		if btn.disabled:
			return
		b.audio.play("tick", 0.03, -8.0, 1.5)
		var tw := btn.create_tween().set_ignore_time_scale(true)
		tw.tween_property(btn, "position", btn.get_meta("base") + Vector2(0, -22), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(btn, "scale", Vector2.ONE * 1.07, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(btn, "rotation", randf_range(-0.04, 0.04), 0.14))
	btn.mouse_exited.connect(func() -> void:
		if btn.disabled:
			return
		var tw := btn.create_tween().set_ignore_time_scale(true)
		tw.tween_property(btn, "position", btn.get_meta("base"), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(btn, "scale", Vector2.ONE, 0.18)
		tw.parallel().tween_property(btn, "rotation", 0.0, 0.18))
	btn.set_meta("id", id)
	btn.pressed.connect(pick.bind(id))
	return btn


func pick(id: String) -> void:
	if board.tray.size() >= TRAY_MAX:
		b._show_msg("보관함이 가득 찼습니다 — 유물을 올리거나 비우세요", 1.6)
		for c in _cards:
			if is_instance_valid(c) and c.get_meta("id", "") == id:
				var tw := c.create_tween().set_ignore_time_scale(true)
				tw.tween_property(c, "rotation", 0.08, 0.05)
				tw.tween_property(c, "rotation", -0.08, 0.08)
				tw.tween_property(c, "rotation", 0.0, 0.06)
		return
	var slot := board.tray.size()
	board.add_to_tray(id)
	b.audio.play("essence", 0.05)
	_offer_open = false
	_fly_cards(id, slot)
	var layer := _offer_layer
	_offer_layer = null
	b.get_tree().create_timer(0.55, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
		if not _offer_open:
			_show_next_offer())


## 고른 카드는 번쩍 → 작아지며 보관함 칸으로 빨려 들어가고, 나머지는 기울며 떨어져 사라진다.
func _fly_cards(id: String, slot: int) -> void:
	var picked := false
	var dest := get_global_transform() * tray_rect(mini(slot, TRAY_MAX - 1)).get_center()
	for c in _cards:
		if not is_instance_valid(c):
			continue
		c.disabled = true
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := c.create_tween().set_ignore_time_scale(true)
		if not picked and c.get_meta("id", "") == id:
			picked = true
			c.modulate = Color(2.2, 2.1, 1.6)
			tw.tween_property(c, "scale", Vector2.ONE * 1.15, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(c, "modulate", Color.WHITE, 0.2)
			tw.tween_property(c, "global_position", dest - CARD * 0.5, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(c, "scale", Vector2.ONE * 0.12, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(c, "rotation", 0.6, 0.36)
			tw.tween_callback(func() -> void:
				_tray_pop[slot] = 0.0
				b.audio.play("place", 0.05)
				c.visible = false)
		else:
			tw.tween_property(c, "position:y", c.position.y + 160.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(c, "rotation", randf_range(-0.4, 0.4), 0.32)
			tw.parallel().tween_property(c, "modulate:a", 0.0, 0.3)


# ---------------------------------------------------------------- draw

func _on_fired(c: Vector2i, id: String) -> void:
	_pulses.append({"cell": c, "t": 0.0, "col": VDRelicData.color_of(id)})


static func _back_out(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


## 칸 연출 덧그림: 해금(흰 섬광 + 퍼지는 고리 + 별가루) / 침식(보라 균열이 뻗고 번쩍) / 정화(금빛 고리 + 별가루) / 놓기(고리).
func _draw_cell_fx(center: Vector2, cfx: Dictionary) -> void:
	var k: float = cfx["t"] / CELL_FX_SEC[cfx["kind"]]
	var r := Layout.HEX_R
	match cfx["kind"]:
		"unlock", "purify":
			var col := Color(1.0, 0.95, 0.8) if cfx["kind"] == "unlock" else Color(1.0, 0.85, 0.45)
			if k < 0.4:
				_hex("hex_burst", center, Color(1, 1, 1, 1.0 - k / 0.4))
			draw_arc(center, r * (0.6 + 0.9 * k), 0.0, TAU, 40, Color(col, 1.0 - k), 4.0 * (1.0 - k) + 1.0, true)
			for i in 8:
				var a := TAU * i / 8.0 + 0.3
				var p := center + Vector2(cos(a), sin(a)) * r * (0.4 + 1.1 * k)
				var sr := 5.0 * (1.0 - k)
				if sr < 0.4:
					continue   # 퇴화 폴리곤 방지 (triangulation failed)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -sr * 1.6), p + Vector2(sr * 0.4, 0), p + Vector2(0, sr * 1.6), p + Vector2(-sr * 0.4, 0)]), Color(col, 1.0 - k))
		"corrupt":
			_hex("hex_burst", center, Color(0.8, 0.3, 1.0, (1.0 - k) * 0.8))
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(center)
			var grow := minf(k / 0.5, 1.0)
			for i in 5:
				var a := TAU * i / 5.0 + rng.randf_range(-0.3, 0.3)
				var p := center
				var pts := PackedVector2Array([p])
				for s in 4:
					p += Vector2(cos(a), sin(a)) * r * 0.22 * grow + Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5))
					pts.append(p)
				draw_polyline(pts, Color(0.85, 0.35, 1.0, 1.0 - k * 0.5), 3.0)
		"place":
			draw_arc(center, r * (0.7 + 0.5 * k), 0.0, TAU, 36, Color(1, 1, 1, 0.8 * (1.0 - k)), 3.0, true)


## 가리킨 유물 h 와 주변 칸의 관계. cell -> {"kind": "out"(h 가 준다) | "in"(h 가 받는다) | "both" | "empty"(빈 칸 보너스) | "corrupt"(침식 패널티), "labels": [..]}
## 소켓 보정·체인·인접 수 문법·바로 위·빈 이웃·침식을 전부 모은다. 툴팁 글 대신 보드 위에 그리기 위한 것.
func _relations(h: Vector2i) -> Dictionary:
	var rel := {}
	var id := board.relic_at(h)
	if id == "":
		return rel
	# rel[c] = {"kind", "in": [h 가 받는 것], "out": [h 가 주는 것]} — 라벨은 방향별 한 줄로 합쳐 그린다
	var add := func(c: Vector2i, kind: String, label: String) -> void:
		if not rel.has(c):
			rel[c] = {"kind": kind, "in": [], "out": []}
		var r: Dictionary = rel[c]
		if r["kind"] != kind and kind in ["in", "out"] and r["kind"] in ["in", "out"]:
			r["kind"] = "both"
		elif r["kind"] in ["empty", "corrupt"] and kind in ["in", "out"]:
			r["kind"] = kind
		var key := "out" if kind == "out" else "in"
		if label != "" and not r[key].has(label):
			r[key].append(label)
	var fx := func(ef: Dictionary) -> String:
		var parts: Array[String] = []
		if float(ef.get("haste", 0.0)) > 0.0:
			parts.append("가속+%d%%" % int(round(float(ef["haste"]) * 100)))
		if float(ef.get("power", 0.0)) > 0.0:
			parts.append("위력+%d%%" % int(round(float(ef["power"]) * 100)))
		return " ".join(parts)
	var h_chain: bool = VDRelicData.def(id)["trigger"]["type"] == "chain"
	for nb in VDRelicData.neighbors(h):
		var nid := board.relic_at(nb)
		var st := board.state_of(nb)
		if st == VDRelicBoard.Cell.CORRUPT:
			add.call(nb, "corrupt", "침식 −%d%%" % int(VDRelicData.CORRUPT_PENALTY * 100))
			continue
		if nid == "":
			if id == "ember" and board.is_open(nb):
				add.call(nb, "empty", "빈칸 대기−10%")
			continue
		# 소켓: h → nb / nb → h
		if board.port_to(h, nb):
			add.call(nb, "out", fx.call(VDRelicData.port_effect_of(id)))
		if board.port_to(nb, h):
			add.call(nb, "in", fx.call(VDRelicData.port_effect_of(nid)))
		# 체인: 연결된 상대가 chain 이면 h 의 발동이 상대를 깨운다, h 가 chain 이면 상대의 발동이 h 를 깨운다
		if board.linked(h, nb):
			if VDRelicData.def(nid)["trigger"]["type"] == "chain":
				add.call(nb, "out", "체인")
			if h_chain:
				add.call(nb, "in", "체인")
		# 인접 수 문법: h 가 세는 쪽 / nb 가 세는 쪽
		if id == "thunder_shard":
			add.call(nb, "in", "피해+20%")
		elif id == "essence_vial":
			add.call(nb, "in", "정수+1")
		if nid == "thunder_shard":
			add.call(nb, "out", "피해+20%")
		elif nid == "essence_vial":
			add.call(nb, "out", "정수+1")
		# 바로 위 칸: 서리 결정은 위 칸 유물로 둔화 2배
		if id == "frost_crystal" and nb == Vector2i(h.x, h.y - 1):
			add.call(nb, "in", "둔화×2")
		if nid == "frost_crystal" and nb == Vector2i(h.x, h.y + 1):
			add.call(nb, "out", "둔화×2")
	return rel


const REL_COLOR := {"in": Color(0.55, 1.0, 0.75), "out": Color(1.0, 0.85, 0.4), "both": Color(1.0, 1.0, 1.0), "empty": Color(0.75, 0.7, 1.0), "corrupt": Color(1.0, 0.35, 0.45)}


## 관계 화살표 + 값 라벨. in: 상대 → h, out: h → 상대, both: 양쪽 머리. 빈 칸·침식은 화살표 없이 라벨만.
func _draw_relations(h: Vector2i, rel: Dictionary, t: float) -> void:
	var font := VDData.font()
	var hc := cell_center(h)
	var r := Layout.HEX_R
	for c in rel:
		var info: Dictionary = rel[c]
		var kind: String = info["kind"]
		var col: Color = REL_COLOR[kind]
		var cc := cell_center(c)
		var dir := (cc - hc).normalized()
		var a := hc + dir * (r * 0.55)
		var bpt := cc - dir * (r * 0.55)
		if kind in ["in", "out", "both"]:
			# 흐르는 점선: 주는 쪽에서 받는 쪽으로 움직인다
			var flow := 1.0 if kind == "out" else -1.0
			var seg := 10.0
			var len := a.distance_to(bpt)
			var off := fmod(t * 40.0 * flow, seg * 2.0)
			var x := -seg * 2.0 + off
			while x < len:
				var s0 := clampf(x, 0.0, len)
				var s1 := clampf(x + seg, 0.0, len)
				if s1 > s0:
					draw_line(a + dir * s0, a + dir * s1, Color(0.05, 0.02, 0.1, 0.9), 7.0)
					draw_line(a + dir * s0, a + dir * s1, col, 4.0)
				x += seg * 2.0
			if kind in ["out", "both"]:
				_arrow_head(bpt, dir, col)
			if kind in ["in", "both"]:
				_arrow_head(a, -dir, col)
		# 값 라벨: 두 칸이 맞닿는 변 위에 방향별 한 줄(▶ 주는 것 / ◀ 받는 것)씩 어두운 알약 배경으로 (아이콘 사이 틈에만)
		var lines: Array = []
		if not info["out"].is_empty():
			lines.append(["▶ " + " · ".join(info["out"]), REL_COLOR["out"] if kind != "empty" else col])
		if not info["in"].is_empty():
			lines.append(["◀ " + " · ".join(info["in"]), REL_COLOR["in"] if kind in ["in", "out", "both"] else col])
		if not lines.is_empty():
			# 관계 칸의 아래쪽(아이콘 밑)에 둔다: 맞닿는 변에 두면 이웃끼리 겹친다
			var mid := cc + Vector2(0.0, Layout.HEX_R * 0.52)
			var fs := 13
			var n := lines.size()
			for i in n:
				var text: String = lines[i][0]
				var lc: Color = lines[i][1]
				var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var y := mid.y + (i - (n - 1) * 0.5) * 17.0
				var rc := Rect2(mid.x - w * 0.5 - 6.0, y - 8.5, w + 12.0, 17.0)
				draw_rect(rc, Color(0.05, 0.02, 0.1, 0.92))
				draw_rect(rc, Color(lc, 0.7), false, 1.0)
				draw_string(font, Vector2(rc.position.x + 6.0, y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lc)


func _arrow_head(tip: Vector2, dir: Vector2, col: Color) -> void:
	var perp := dir.orthogonal()
	var pts := PackedVector2Array([tip, tip - dir * 14.0 + perp * 9.0, tip - dir * 14.0 - perp * 9.0])
	var outline := PackedVector2Array([tip + dir * 3.0, tip - dir * 17.0 + perp * 12.0, tip - dir * 17.0 - perp * 12.0])
	draw_colored_polygon(outline, Color(0.05, 0.02, 0.1, 0.95))
	draw_colored_polygon(pts, col)


## 방향 d 의 화면 벡터: 논리 이웃 좌표에서 뽑되, 시안은 1열이 왼쪽이라 x 를 뒤집는다.
func _dir_vec(d: int) -> Vector2:
	var v := VDRelicData.cell_pos(VDRelicData.neighbor_in(Vector2i(0, 0), d), 1.0)
	return Vector2(-v.x, v.y).normalized()


## 회전 아이콘: 어두운 원 + 270° 호 + 끝 화살촉. spin 으로 호를 돌린다.
func _rot_icon(pos: Vector2, r: float, col: Color, spin: float) -> void:
	draw_circle(pos, r + 3.0, Color(0.06, 0.02, 0.12, 0.92 * col.a))
	var a0 := spin - PI * 0.5
	var a1 := a0 + PI * 1.5
	draw_arc(pos, r * 0.62, a0, a1, 16, col, 2.5, true)
	var tip := pos + Vector2(cos(a1), sin(a1)) * r * 0.62
	var tan := Vector2(-sin(a1), cos(a1))
	var nrm := Vector2(cos(a1), sin(a1))
	draw_colored_polygon(PackedVector2Array([tip + tan * 4.5, tip - tan * 1.5 + nrm * 4.0, tip - tan * 1.5 - nrm * 4.0]), col)


## 가리킨 소켓 유물: 칸 둘레를 천천히 도는 화살표 두 개 — "돌릴 수 있다".
func _draw_rot_orbit(center: Vector2, t: float) -> void:
	var r := Layout.HEX_R * 1.06
	var spin := t * 1.6
	var col := Color(1.0, 0.9, 0.55, 0.85 + 0.15 * sin(t * 6.0))
	for i in 2:
		var a0 := spin + PI * i
		var a1 := a0 + deg_to_rad(70.0)
		draw_arc(center, r, a0, a1, 18, Color(0.06, 0.02, 0.12, 0.85), 7.0, true)
		draw_arc(center, r, a0, a1, 18, col, 3.5, true)
		var tip := center + Vector2(cos(a1), sin(a1)) * r
		var tan := Vector2(-sin(a1), cos(a1))
		var nrm := Vector2(cos(a1), sin(a1))
		draw_colored_polygon(PackedVector2Array([tip + tan * 13.0, tip - tan * 2.0 + nrm * 9.0, tip - tan * 2.0 - nrm * 9.0]), Color(0.06, 0.02, 0.12, 0.85))
		draw_colored_polygon(PackedVector2Array([tip + tan * 9.0, tip + nrm * 6.0, tip - nrm * 6.0]), col)


## 방금 돌린 칸: 둘레에 휩쓴 호(돌아간 방향으로 뻗고 사라짐) + 끝 화살촉.
func _draw_rot_sweep(center: Vector2, ra: Dictionary) -> void:
	var k: float = ra["t"] / ROT_SEC
	var ang: float = -float(ra["ang"])           # 돌아간 방향
	if absf(ang) < 0.5:
		return                                    # 거절(꿈틀)엔 호를 그리지 않는다
	var e := 1.0 - pow(1.0 - minf(k / 0.6, 1.0), 3.0)
	var a := 1.0 - k
	var r := Layout.HEX_R * 1.1
	for i in 2:
		var base := -PI * 0.5 + PI * i
		var a0 := base - ang
		var a1 := base - ang + ang * 2.0 * e
		draw_arc(center, r, a0, a1, 20, Color(1.0, 1.0, 1.0, 0.9 * a), 5.0 * a + 1.0, true)
		var tip := center + Vector2(cos(a1), sin(a1)) * r
		var tan := Vector2(-sin(a1), cos(a1)) * signf(ang)
		var nrm := Vector2(cos(a1), sin(a1))
		draw_colored_polygon(PackedVector2Array([tip + tan * 11.0, tip + nrm * 7.0, tip - nrm * 7.0]), Color(1, 1, 1, a))


## 소켓 유물을 처음 올렸을 때: 칸 아래에서 통통 튀는 안내 말풍선.
func _draw_hint(center: Vector2, ht: float, t: float) -> void:
	var a := clampf(ht / 0.15, 0.0, 1.0) * clampf((HINT_SEC - ht) / 0.3, 0.0, 1.0)
	var text := "클릭해서 회전!"
	var fnt := VDData.font()
	var fs := 17
	var w := fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := center + Vector2(0.0, Layout.HEX_R * 0.866 + 26.0 + sin(t * 7.0) * 3.0)
	var rc := Rect2(pos.x - w * 0.5 - 30.0, pos.y - 14.0, w + 42.0, 28.0)
	# 보드 폭 안으로 (왼쪽은 툴팁 자리, 오른쪽은 화면 끝)
	var board_left := Layout.CELL_CENTERS[Vector2i(1, 0)].x - Layout.HEX_R
	rc.position.x = clampf(rc.position.x, board_left, size.x - 6.0 - rc.size.x)
	draw_colored_polygon(PackedVector2Array([Vector2(pos.x - 8.0, rc.position.y + 1.0), Vector2(pos.x + 8.0, rc.position.y + 1.0), Vector2(pos.x, rc.position.y - 9.0)]), Color(0.98, 0.86, 0.45, a))
	draw_rect(rc, Color(0.98, 0.86, 0.45, a))
	draw_rect(rc, Color(0.2, 0.08, 0.3, a), false, 2.0)
	_rot_icon(Vector2(rc.position.x + 16.0, pos.y), 8.0, Color(0.25, 0.1, 0.35, a), -t * 3.0)
	draw_string(fnt, Vector2(rc.position.x + 30.0, pos.y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.06, 0.3, a))
	_draw_rot_orbit(center, t)


## 소켓: 변 가운데의 작은 삼각형(태그 색, 바깥을 향함). 이웃 유물에 닿았으면 변을 가로지르는 흰 다리 + 발동 중엔 번쩍.
func _draw_ports(c: Vector2i, center: Vector2, id: String, burst: bool) -> void:
	var col := VDRelicData.color_of(id)
	var edge_r := Layout.HEX_R * 0.866 - 2.0
	for d in board.ports_of(c):
		var dir := _dir_vec(d)
		var perp := dir.orthogonal()
		var nb := VDRelicData.neighbor_in(c, d)
		var touching := board.relic_at(nb) != ""
		var p := center + dir * (edge_r - 8.0)
		var tri := PackedVector2Array([p + dir * 11.0, p + perp * 8.0, p - perp * 8.0])
		var outline := PackedVector2Array([p + dir * 14.0, p + perp * 11.0, p - perp * 11.0])
		draw_colored_polygon(outline, Color(0.08, 0.03, 0.16, 0.95))
		draw_colored_polygon(tri, col.lightened(0.15) if touching else col.darkened(0.25))
		if touching:
			var a := center + dir * (edge_r - 4.0)
			var bpt := center + dir * (edge_r + 10.0)
			draw_line(a, bpt, Color(col, 0.9), 9.0)
			draw_line(a, bpt, Color(1, 1, 1, 1.0 if burst else 0.85), 4.0)


func _closed_hex(center: Vector2, r: float) -> PackedVector2Array:
	var pts := VDRelicData.hex_points(center, r)
	pts.append(pts[0])
	return pts


func _hex(name: String, center: Vector2, mod := Color.WHITE) -> void:
	draw_texture(_tex[name], center - Layout.HEX_TEX_SIZE * 0.5, mod)


func _icon(id: String, center: Vector2, scl := 1.0, mod := Color.WHITE) -> void:
	var name: String = Layout.RELIC_ICON.get(id, "")
	if name == "":
		# 아직 전용 아이콘이 없는 유물: 태그 색 글리프 (임시)
		var d := VDRelicData.def(id)
		if d.is_empty():
			return
		var fs := int(46 * scl)
		var pos := center + Vector2(-60.0, fs * 0.36)
		draw_string_outline(VDData.font(), pos, d["glyph"], HORIZONTAL_ALIGNMENT_CENTER, 120.0, fs, 6, Color(0.08, 0.03, 0.16, mod.a))
		draw_string(VDData.font(), pos, d["glyph"], HORIZONTAL_ALIGNMENT_CENTER, 120.0, fs, VDRelicData.color_of(id) * mod)
		return
	var sz: Vector2 = Layout.ICON_SIZE[name] * scl
	draw_texture_rect(_tex[name], Rect2(center - sz * 0.5, sz), false, mod)


## 충전 게이지: 보라 채움을 아래에서부터 ratio 만큼만 (시안의 마스크 처리).
func _gauge(center: Vector2, ratio: float) -> void:
	if ratio <= 0.01:
		return
	var tex: Texture2D = _tex["hex_fill_gauge"]
	var half_h := Layout.HEX_R * 0.866025
	var top := Layout.HEX_TEX_SIZE.y * 0.5 + half_h - clampf(ratio, 0.0, 1.0) * half_h * 2.0
	var src := Rect2(0.0, top, Layout.HEX_TEX_SIZE.x, Layout.HEX_TEX_SIZE.y - top)
	var dst := Rect2(center - Layout.HEX_TEX_SIZE * 0.5 + Vector2(0.0, top), src.size)
	draw_texture_rect_region(tex, dst, src, Color(1, 1, 1, Layout.OPACITY_GAUGE_FILL))


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var pulse_of := {}
	for p in _pulses:
		pulse_of[p["cell"]] = minf(pulse_of.get(p["cell"], 1.0), p["t"] / PULSE_SEC)
	var next := _next_locked()
	var drop_ok := not _drag.is_empty() and board.can_place(_hover_cell)
	# 유물을 가리키면 영향을 주고받는 칸을 색 링·화살표·값으로 강조하고 나머지는 어둡게 누른다
	var rel := {}
	var hover_relic := _drag.is_empty() and board.relic_at(_hover_cell) != "" and editable()
	if hover_relic:
		rel = _relations(_hover_cell)
	# 장식 별: 시안 위치에서 반짝
	for i in Layout.STARS.size():
		var s: Dictionary = Layout.STARS[i]
		var tex: Texture2D = _tex[s["tex"]]
		var k := 0.85 + 0.15 * sin(t * 2.2 + i * 1.7)
		var sz := tex.get_size() * k
		draw_texture_rect(tex, Rect2(s["pos"] - sz * 0.5, sz), false, Color(1, 1, 1, 0.7 + 0.3 * k))
	# 가리킨 칸은 키워 그리므로 맨 마지막에 (이웃 칸에 덮이지 않게)
	var order: Array = VDRelicData.BOARD_CELLS.duplicate()
	if order.has(_hover_cell):
		order.erase(_hover_cell)
		order.append(_hover_cell)
	for c: Vector2i in order:
		var center := cell_center(c)
		var st := board.state_of(c)
		var id := board.relic_at(c)
		# 칸 연출: 배율(가운데 기준) + 흔들림 + 회전을 칸 그림 전체에 건다
		var cfx: Dictionary = _cell_fx.get(c, {})
		var cs := 1.0
		var shake := Vector2.ZERO
		if not cfx.is_empty():
			var k: float = cfx["t"] / CELL_FX_SEC[cfx["kind"]]
			match cfx["kind"]:
				"unlock":
					cs = lerpf(0.2, 1.0, _back_out(minf(k / 0.6, 1.0)))
				"place", "purify":
					cs = 1.0 + 0.3 * (1.0 - k) * (1.0 - k) * cos(k * PI * 2.5)
				"corrupt":
					shake = Vector2(sin(cfx["t"] * 90.0), cos(cfx["t"] * 70.0)) * 5.0 * (1.0 - k)
				"rotate":
					cs = 1.0 + 0.12 * (1.0 - k)
		# 호버: 뒤에 보라 빛 번짐 + 칸이 살짝 커진다
		var hk: float = _hov_k.get(c, 0.0)
		if hk > 0.01:
			var gs := 1.3 + 0.05 * sin(t * 5.0)
			draw_set_transform(center * (1.0 - gs), 0.0, Vector2(gs, gs))
			_hex("hex_burst", center, Color(0.72, 0.5, 1.0, 0.55 * hk))
			cs *= 1.0 + HOVER_SCALE * hk
		# 회전: 이전 방향(ang)에서 새 방향으로 휙 돌아 들어온다. 육각형이라 다 돌면 칸 모양은 그대로
		var rot := 0.0
		if _rot_anim.has(c):
			rot = float(_rot_anim[c]["ang"]) * (1.0 - _back_out(_rot_anim[c]["t"] / ROT_SEC))
		draw_set_transform_matrix(Transform2D(rot, Vector2(cs, cs), 0.0, center + shake) * Transform2D(0.0, -center))
		match st:
			VDRelicBoard.Cell.LOCKED:
				var a := Layout.OPACITY_NEXT if c == next else Layout.OPACITY_LOCKED
				_hex("hex_base", center, Color(1, 1, 1, a))
				_hex("hex_edge", center, Color(1, 1, 1, EDGE_OPACITY * a / Layout.OPACITY_OPEN))
			VDRelicBoard.Cell.CORRUPT:
				_hex("hex_base", center, Color(1, 1, 1, Layout.OPACITY_OPEN))
				_hex("hex_ring_gauge", center, Color(0.75, 0.3, 1.0, 0.85))
				var tt := t * 3.0
				for i in 3:
					var a := tt + TAU * i / 3.0
					draw_line(center, center + Vector2(cos(a), sin(a)) * (Layout.HEX_R * 0.7), Color(0.8, 0.3, 1.0, 0.7), 2.0)
			_:
				_hex("hex_base", center, Color(1, 1, 1, Layout.OPACITY_OPEN))
				_hex("hex_edge", center, Color(1, 1, 1, EDGE_OPACITY))
		var hovered := c == _hover_cell and editable() and st == VDRelicBoard.Cell.OPEN
		var g := runtime.gauge(c) if id != "" else {"ratio": 0.0}
		var k: float = pulse_of.get(c, 1.0)
		if id != "" and g["ratio"] > 0.0:
			_gauge(center, g["ratio"])
			_hex("hex_ring_gauge", center, Color(1, 1, 1, Layout.OPACITY_OPEN))
		elif hovered or (drop_ok and c == _hover_cell):
			_hex("hex_ring_gauge", center, Color(1, 1, 1, 0.55))
		if hover_relic and rel.has(c):
			# 관계 칸: 종류 색 링(숨쉬듯 맥동) + 같은 색 외곽선
			var rc: Color = REL_COLOR[rel[c]["kind"]]
			var breathe := 0.8 + 0.2 * sin(t * 6.0)
			_hex("hex_ring_gauge", center, Color(rc, 0.9 * breathe))
			draw_polyline(_closed_hex(center, Layout.HEX_R - 3.0), Color(rc, 0.95), 3.0)
		elif hover_relic and c != _hover_cell:
			# 관계없는 칸은 어둡게 눌러 관련 칸만 떠오르게
			draw_colored_polygon(VDRelicData.hex_points(center, Layout.HEX_R - 1.0), Color(0.02, 0.0, 0.05, 0.5))
		if k < BURST_K:
			_hex("hex_burst", center, Color(1, 1, 1, 1.0 - k / BURST_K))
		var dragging_this: bool = _drag.get("from", "") == "cell" and _drag["cell"] == c and _drag.get("moved", false)
		if id != "" and not dragging_this:
			var ok := runtime._grammar_ok(c, id)
			_icon(id, center, 1.0, Color.WHITE if ok else Color(0.5, 0.5, 0.5, 0.8))
			if not ok:
				draw_line(center + Vector2(-Layout.HEX_R * 0.45, -Layout.HEX_R * 0.45), center + Vector2(Layout.HEX_R * 0.45, Layout.HEX_R * 0.45), Color(1, 0.3, 0.3, 0.9), 3.0)
		if k < 1.0:
			_hex("hex_ring_fire", center, Color(1, 1, 1, Layout.OPACITY_OPEN * (1.0 - k)))
		if id != "" and not dragging_this:
			_draw_ports(c, center, id, k < BURST_K)
		if id != "" and not dragging_this:
			var n := runtime.badge(c)
			if n > 0:
				var oc: Color = Layout.BADGE_OUTLINE_COLOR_BURST if k < BURST_K else Layout.BADGE_OUTLINE_COLOR
				var pos := center + Layout.BADGE_OFFSET + Vector2(-30.0, Layout.BADGE_FONT_SIZE * 0.35)
				draw_string_outline(_badge_font, pos, "+%d" % n, HORIZONTAL_ALIGNMENT_CENTER, 60.0, Layout.BADGE_FONT_SIZE, Layout.BADGE_OUTLINE, oc)
				draw_string(_badge_font, pos, "+%d" % n, HORIZONTAL_ALIGNMENT_CENTER, 60.0, Layout.BADGE_FONT_SIZE, Color.WHITE)
		# 돌릴 수 있는 유물: 왼쪽 아래 꼭짓점 쪽에 작은 회전 배지 (배치 중에만)
		if id != "" and not dragging_this and editable() and not board.ports_of(c).is_empty():
			var bk := 0.6 + 0.4 * hk
			_rot_icon(center + Vector2(-0.33, 0.55) * Layout.HEX_R, 10.0 + 2.0 * hk, Color(1.0, 0.9, 0.55, bk), -t * 1.5 * hk)
		if hk > 0.01:
			draw_polyline(_closed_hex(center, Layout.HEX_R - 2.0), Color(0.92, 0.82, 1.0, 0.9 * hk), 3.0)
		draw_set_transform(Vector2.ZERO)
		if not cfx.is_empty():
			_draw_cell_fx(center, cfx)
		if _rot_anim.has(c):
			_draw_rot_sweep(center, _rot_anim[c])
	if hover_relic:
		# 가리킨 칸은 흰 링, 관계 화살표·값은 모든 칸 위에
		draw_polyline(_closed_hex(cell_center(_hover_cell), Layout.HEX_R - 3.0), Color(1, 1, 1, 0.95), 3.0)
		_draw_relations(_hover_cell, rel, t)
		if not board.ports_of(_hover_cell).is_empty():
			_draw_rot_orbit(cell_center(_hover_cell), t)
	if not _hint.is_empty():
		_draw_hint(cell_center(_hint["cell"]), float(_hint["t"]), t)
	for f in _floats:
		var fk: float = f["t"] / FLOAT_SEC
		var pos: Vector2 = f["pos"] + Vector2(0.0, -30.0 * fk)
		var fs := int(22.0 * (1.0 + 0.5 * maxf(0.0, 1.0 - fk * 5.0)))
		var a := clampf((1.0 - fk) * 2.5, 0.0, 1.0)
		var fnt := VDData.font()
		var w := fnt.get_string_size(f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(fnt, pos + Vector2(-w * 0.5, 0.0), f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 7, Color(0.08, 0.02, 0.14, a))
		draw_string(fnt, pos + Vector2(-w * 0.5, 0.0), f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(f["col"], a))
	# 보관함: 시안 칸 색(어두운 남보라 + 흐린 보라 테두리). 전투 중엔 편집할 수 없으니 감춘다
	if not editable():
		return
	var font := VDData.font()
	draw_string(font, Vector2(TRAY_X, TRAY_Y - 12), "보관함 — 드래그해 올리기 / 내리기", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.8, 1.0, 0.9))
	for i in TRAY_MAX:
		var rc := tray_rect(i)
		var has := i < board.tray.size()
		var hov := i == _hover_tray and has
		draw_rect(rc, Color(0.051, 0.031, 0.094, Layout.OPACITY_OPEN))
		draw_rect(rc, Color(0.67, 0.34, 1.0) if hov else Color(0.37, 0.32, 0.56, 0.9 if has else 0.45), false, 2.0)
		if has and not (_drag.get("from", "") == "tray" and int(_drag["index"]) == i):
			var pop := 0.0
			if _tray_pop.has(i):
				var k: float = _tray_pop[i] / 0.35
				pop = (1.0 - k) * (1.0 - k) * cos(k * PI * 2.0) * 0.6
				draw_rect(rc.grow(4.0 * (1.0 - k)), Color(1.0, 0.9, 0.6, 1.0 - k), false, 3.0)
			_icon(board.tray[i], rc.get_center(), TRAY_ICON_SCALE * (1.0 + pop))
	# 드래그 고스트
	if not _drag.is_empty() and (_drag.get("moved", false) or _drag["from"] == "tray"):
		_icon(_drag["id"], get_local_mouse_position(), 1.0, Color(1, 1, 1, 0.85))
