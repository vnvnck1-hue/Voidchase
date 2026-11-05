## 성좌판 HUD: 화면 오른쪽에 육각 10칸 + 아래 보관함. 전투 밖에서 드래그로 놓고/옮기고/빼고,
## 침식 칸은 우클릭으로 정화(정수 소모). 구역 클리어 보상(3택1) 패널도 여기서 띄운다.
## 발동 순간 칸이 펄스하고, 투사체는 이 칸의 화면 좌표를 월드로 바꿔 전장으로 날아간다.
class_name VDRelicHud
extends Control

const R := 60.0                      # 격자 간격용 반지름: 열 90px·행 104px (목업: 열 ~90, 행 ~110)
const R_DRAW := 54.0                 # 그리는 육각 반지름: pointy-top 폭 94·높이 108px (목업 폭 100~110)
const HEX_ROT := PI / 6.0            # 목업처럼 꼭짓점이 위로 (격자 로직은 flat-top odd-q 그대로)
const ORIGIN := Vector2(96.0, 70.0)  # 보드 (0,0) 셀 중심
const TRAY_Y := 640.0                # 보관함 첫 줄 y
const TRAY_SLOT := 66.0
const TRAY_COLS := 4
const TRAY_MAX := 8

var b: VDBattle
var board: VDRelicBoard
var runtime: VDRelicRuntime

var _drag := {}                      # {"from": "tray"|"cell", "index"/"cell", "id"}
var _hover_cell := Vector2i(-99, -99)
var _hover_tray := -1
var _pulses := []                    # [{cell, t}]
var _offers := []                    # 대기 중인 보상 묶음 (각각 Array[String])
var _tip: PanelContainer
var _tip_label: Label
var _pick: PanelContainer
var _pick_box: VBoxContainer
var _title: Label


func setup(battle: VDBattle, board_: VDRelicBoard, runtime_: VDRelicRuntime) -> void:
	b = battle
	board = board_
	runtime = runtime_
	runtime.origin_of = cell_world_pos
	runtime.fired.connect(_on_fired)
	board.changed.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_STOP
	SceneSwitcher.pin(self, Vector2(1, 0), Rect2(1640, 100, 280, 800))

	_title = Label.new()
	_title.text = "유물 성좌판"
	_title.position = Vector2(30, -16)
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(0.9, 0.82, 1.0))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_tip = PanelContainer.new()
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.06, 0.18, 0.95)
	sb.border_color = Color(0.7, 0.5, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	_tip.add_theme_stylebox_override("panel", sb)
	_tip_label = Label.new()
	_tip_label.add_theme_font_size_override("font_size", 15)
	_tip_label.custom_minimum_size = Vector2(300, 0)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(_tip_label)
	add_child(_tip)

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


func _process(dt: float) -> void:
	for p in _pulses:
		p["t"] += dt
	_pulses = _pulses.filter(func(p: Dictionary) -> bool: return p["t"] < 0.45)
	queue_redraw()


func editable() -> bool:
	return b != null and b.state not in [VDBattle.State.BATTLE, VDBattle.State.SPAWNING, VDBattle.State.GAMEOVER]


# ---------------------------------------------------------------- geometry

func cell_center(c: Vector2i) -> Vector2:
	return ORIGIN + VDRelicData.cell_pos(c, R)


func tray_rect(i: int) -> Rect2:
	return Rect2(Vector2(14.0 + (i % TRAY_COLS) * TRAY_SLOT, TRAY_Y + (i / TRAY_COLS) * TRAY_SLOT), Vector2(TRAY_SLOT - 6.0, TRAY_SLOT - 6.0))


func cell_at(p: Vector2) -> Vector2i:
	for c in VDRelicData.BOARD_CELLS:
		if cell_center(c).distance_to(p) <= R * 0.9:
			return c
	return Vector2i(-99, -99)


func tray_at(p: Vector2) -> int:
	for i in TRAY_MAX:
		if tray_rect(i).has_point(p):
			return i
	return -1


## 셀 중심의 전장 월드 좌표 (투사체 출발점).
func cell_world_pos(c: Vector2i) -> Vector2:
	var screen := get_global_transform() * cell_center(c)
	return b.get_viewport().get_canvas_transform().affine_inverse() * screen


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var p: Vector2 = event.position
		_hover_cell = cell_at(p)
		_hover_tray = tray_at(p)
		_update_tip(p)
		if not _drag.is_empty():
			accept_event()
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
			if board.relic_at(c) != "":
				_drag = {"from": "cell", "cell": c, "id": board.relic_at(c)}
				accept_event()
			elif ti >= 0 and ti < board.tray.size():
				_drag = {"from": "tray", "index": ti, "id": board.tray[ti]}
				accept_event()
		elif not _drag.is_empty():
			_drop(p)
			accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		var c := cell_at(p)
		if board.state_of(c) == VDRelicBoard.Cell.CORRUPT:
			try_purify(c)
			accept_event()


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
		return false
	if not board.purify(c):
		return false
	b.essence -= VDRelicData.PURIFY_COST
	b._refresh_essence()
	b.audio.play("heal", 0.05, -2.0)
	b._show_msg("침식을 정화했습니다", 1.2)
	return true


func _update_tip(p: Vector2) -> void:
	var id := ""
	var extra := ""
	if board.relic_at(_hover_cell) != "":
		id = board.relic_at(_hover_cell)
		extra = runtime.describe(_hover_cell)
	elif _hover_tray >= 0 and _hover_tray < board.tray.size():
		id = board.tray[_hover_tray]
	elif board.state_of(_hover_cell) == VDRelicBoard.Cell.CORRUPT:
		_tip_label.text = "공허 침식\n인접한 유물의 효과 −%d%%.\n우클릭: 정수 %d 로 정화" % [int(VDRelicData.CORRUPT_PENALTY * 100), VDRelicData.PURIFY_COST]
		_tip.visible = true
		_tip.position = Vector2(p.x - 340.0, p.y - 20.0)
		return
	elif board.state_of(_hover_cell) == VDRelicBoard.Cell.LOCKED and VDRelicData.BOARD_CELLS.has(_hover_cell):
		_tip_label.text = "잠긴 칸\n구역을 클리어하면 위에서부터 하나씩 열립니다."
		_tip.visible = true
		_tip.position = Vector2(p.x - 340.0, p.y - 20.0)
		return
	if id == "":
		_tip.visible = false
		return
	var d := VDRelicData.def(id)
	var text := "%s  [%s]\n%s\n배치: %s" % [d["name"], d["tag"], d["desc"], d["grammar"]]
	if extra != "":
		text += "\n— 지금 자리: " + extra.replace("\n", " · ")
	_tip_label.text = text
	_tip.visible = true
	_tip.position = Vector2(p.x - 340.0, p.y - 20.0)


# ---------------------------------------------------------------- rewards

## 구역 클리어 보상 제시. 이미 고르는 중이면 줄을 선다.
func offer(ids: Array) -> void:
	_offers.append(ids)
	if not _pick.visible:
		_show_next_offer()


func has_offer() -> bool:
	return _pick.visible or not _offers.is_empty()


func _show_next_offer() -> void:
	for ch in _pick_box.get_children():
		ch.queue_free()
	if _offers.is_empty():
		_pick.visible = false
		return
	var ids: Array = _offers.pop_front()
	var head := Label.new()
	head.text = "유물 발견 — 하나를 고르세요"
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_pick_box.add_child(head)
	for id in ids:
		var d := VDRelicData.def(id)
		var btn := Button.new()
		btn.text = "%s  [%s]\n%s\n배치: %s" % [d["name"], d["tag"], d["desc"], d["grammar"]]
		btn.custom_minimum_size = Vector2(340, 0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", VDRelicData.color_of(id))
		btn.pressed.connect(pick.bind(id))
		_pick_box.add_child(btn)
	_pick.visible = true


func pick(id: String) -> void:
	if board.tray.size() >= TRAY_MAX:
		b._show_msg("보관함이 가득 찼습니다 — 유물을 올리거나 비우세요", 1.6)
		return
	board.add_to_tray(id)
	b.audio.play("essence", 0.05)
	_show_next_offer()


# ---------------------------------------------------------------- draw

func _on_fired(c: Vector2i, id: String) -> void:
	_pulses.append({"cell": c, "t": 0.0, "col": VDRelicData.color_of(id)})


func _draw() -> void:
	var font := VDData.font()
	# 보드
	for c in VDRelicData.BOARD_CELLS:
		var center := cell_center(c)
		var pts := VDRelicData.hex_points(center, R_DRAW, HEX_ROT)
		var st := board.state_of(c)
		var id := board.relic_at(c)
		var hovered := c == _hover_cell and editable()
		match st:
			VDRelicBoard.Cell.LOCKED:
				draw_colored_polygon(pts, Color(0.12, 0.08, 0.2, 0.5))
				draw_polyline(_closed(pts), Color(0.45, 0.35, 0.6, 0.5), 1.5)
				draw_string(font, center + Vector2(-10, 6), "·", HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color(0.6, 0.5, 0.8, 0.6))
			VDRelicBoard.Cell.CORRUPT:
				draw_colored_polygon(pts, Color(0.03, 0.01, 0.06, 0.95))
				draw_polyline(_closed(pts), Color(0.75, 0.25, 0.95), 2.5)
				var tt := Time.get_ticks_msec() * 0.003
				for i in 3:
					var a := tt + TAU * i / 3.0
					draw_line(center, center + Vector2(cos(a), sin(a)) * (R * 0.7), Color(0.8, 0.3, 1.0, 0.7), 2.0)
			_:
				var fill := Color(0.25, 0.16, 0.42, 0.85)
				if id != "":
					fill = VDRelicData.color_of(id).darkened(0.55)
					fill.a = 0.95
				if hovered:
					fill = fill.lightened(0.15)
				draw_colored_polygon(pts, fill)
				var edge := VDRelicData.color_of(id) if id != "" else Color(0.65, 0.5, 0.95)
				draw_polyline(_closed(pts), edge, 4.0 if id != "" else 2.0)
				# 안쪽 베벨: 목업처럼 두 겹 테두리
				draw_polyline(_closed(VDRelicData.hex_points(center, R_DRAW - 8.0, HEX_ROT)), Color(edge, 0.35), 1.5)
		if id != "" and not (_drag.get("from", "") == "cell" and _drag["cell"] == c):
			_draw_relic(center, id, font, 1.5)
			var g := runtime.gauge(c)
			if g["ratio"] > 0.0:
				draw_arc(center, R_DRAW - 9.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(g["ratio"], 0.0, 1.0), 32, Color(1, 1, 1, 0.75), 3.0)
			if g["text"] != "":
				# 진행 표시(카운트·남은 초)는 육각형 아래쪽 안에 작게
				draw_string(font, center + Vector2(-R, R_DRAW * 0.74), g["text"], HORIZONTAL_ALIGNMENT_CENTER, R * 2.0, 14, Color(1, 1, 1, 0.95))
			if not runtime._grammar_ok(c, id):
				draw_line(center + Vector2(-R_DRAW * 0.5, -R_DRAW * 0.5), center + Vector2(R_DRAW * 0.5, R_DRAW * 0.5), Color(1, 0.3, 0.3, 0.9), 3.0)
	# 발동 펄스
	for p in _pulses:
		var k: float = p["t"] / 0.45
		var center := cell_center(p["cell"])
		var pc: Color = p["col"]
		draw_circle(center, (R_DRAW - 4.0) * (1.0 - k * 0.5), Color(pc, 0.45 * (1.0 - k)))
		draw_arc(center, R_DRAW + 4.0 + 26.0 * k, 0.0, TAU, 32, Color(pc.lightened(0.5), 1.0 - k), 3.0)
		draw_arc(center, R_DRAW + 2.0 + 14.0 * k, 0.0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - k)), 1.5)
	# 보관함
	draw_string(font, Vector2(14, TRAY_Y - 12), "보관함 — 드래그해 올리기 / 내리기", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.8, 1.0, 0.9))
	for i in TRAY_MAX:
		var rc := tray_rect(i)
		var has := i < board.tray.size()
		draw_rect(rc, Color(0.12, 0.08, 0.2, 0.8))
		draw_rect(rc, Color(0.5, 0.4, 0.7, 0.7 if has else 0.35), false, 1.5)
		if has and not (_drag.get("from", "") == "tray" and int(_drag["index"]) == i):
			_draw_relic(rc.get_center(), board.tray[i], font, 0.95)
	if not editable():
		draw_string(font, Vector2(14, TRAY_Y + 2 * TRAY_SLOT + 18), "전투 중에는 배치를 바꿀 수 없습니다", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.7, 0.7, 0.9))
	# 드래그 고스트
	if not _drag.is_empty():
		_draw_relic(get_local_mouse_position(), _drag["id"], font, 1.5)


func _draw_relic(center: Vector2, id: String, font: Font, scl := 1.0) -> void:
	var col := VDRelicData.color_of(id)
	var d := VDRelicData.def(id)
	draw_circle(center, 20.0 * scl, Color(col, 0.25))
	draw_string(font, center + Vector2(-30.0 * scl, 6.0 * scl), d["glyph"], HORIZONTAL_ALIGNMENT_CENTER, 60.0 * scl, int(24 * scl), col)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(pts)
	out.append(pts[0])
	return out
