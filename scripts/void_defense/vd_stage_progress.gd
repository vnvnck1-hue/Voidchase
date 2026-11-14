## 스테이지 진행도 게이지 (상단 가운데 HUD). 모양은 화면 컨셉_3.psd 의 '진행도 바' 그룹 그대로
##   (틀·명판 텍스처와 수치는 tools/battle_ui/extract_progress_bar.py 가 만든 vd_stage_progress_layout.gd).
##   바 전체 = 이 스테이지에 남은 공허: 웨이브 수만큼 같은 폭의 구획으로 나뉘고, 오른쪽 구획부터 1웨이브.
##   지금 웨이브 구획은 그 웨이브 몬스터의 남은 체력만큼 차 있고, 아직 안 온 웨이브(왼쪽)는 꽉 차 있다.
##   싸우면 초록 끝이 왼쪽으로 줄고, 깎인 몫은 빨간 잔상으로 잠깐 버텼다가 따라 내려온다. 0 이 되면 스테이지 정화.
##   위 명판: 지금 웨이브 남은 체력 / 총 체력 · 아래 명판: 스테이지에 남은 몫(%) · 바 위 왼쪽 WAVE n/N, 오른쪽 남은 적.
##   스테이지 첫 웨이브가 나타날 때 바가 빈 상태에서 쭉 차오른다. 다음 웨이브가 내려앉는 동안은 그 구획을 꽉 찬 채로 둔다.
## class_name 없음: preload 해서 쓴다.
extends Control

const Layout := preload("res://scripts/void_defense/vd_stage_progress_layout.gd")

const GHOST_HOLD := 0.35
const NOTCH_ALPHA := 0.45            # 시안은 overlay 로 채움을 어둡게 한다
const DIVIDER_W := 12.0              # 웨이브 구획선 (PSD 픽셀)
const SIDE_TEXT_PX := 46.0           # 바 위 WAVE · 남은 적 글자 (PSD 픽셀)

var ratio := 0.0             # 보이는 스테이지 몫 0..1 (부드럽게 따라간다)
var _target := 0.0           # 지금 웨이브 몫 0..1 (내려앉는 중이면 1)
var _stage_target := 0.0     # 스테이지 몫 = ((N - i) + _target) / N
var _ghost := 0.0
var _ghost_hold := 0.0
var _kick := 0.0
var _wave_i := 1
var _wave_n := 1
var _wave_text := ""
var _left_text := ""
var _hp_text := ""
var _frame: Texture2D
var _num_font: Font
var _font: Font
var _trough := PackedVector2Array(Layout.TROUGH_POLY)   # 바닥 홈 경로 (채움·잔상도 이 모양)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = load(Layout.FRAME_TEX)
	_num_font = VDData.GameFonts.display()
	_font = VDData.font()


## cur / total: 지금 웨이브의 남은 체력 합 / 총 체력. alive: 남은 적 수. arriving: 다음 웨이브가 내려앉는 중.
func set_values(cur: float, total: float, alive: int, wave_i: int, wave_n: int, arriving := false) -> void:
	var t := clampf(cur / total, 0.0, 1.0) if total > 0.0 else 0.0
	if arriving:
		t = 1.0
	_wave_i = clampi(wave_i, 1, maxi(wave_n, 1))
	_wave_n = maxi(wave_n, 1)
	var st := (float(_wave_n - _wave_i) + t) / float(_wave_n)
	if st < _stage_target - 0.002 and not arriving:
		_ghost_hold = GHOST_HOLD
		_kick = minf(1.0, _kick + (_stage_target - st) * 6.0 * _wave_n + 0.25)
	_target = t
	_stage_target = st
	_wave_text = "WAVE %d/%d" % [_wave_i, _wave_n]
	_left_text = "남은 적 %d" % alive
	_hp_text = "%d/%d" % [int(ceilf(cur)), int(ceilf(total))]


## 새 웨이브. new_stage 면 바를 비우고 다시 차오르게 (스테이지 첫 웨이브), 아니면 이어서 (구획만 넘어간다).
func reset(new_stage := true) -> void:
	if not new_stage:
		return
	ratio = 0.0
	_target = 0.0
	_stage_target = 0.0
	_ghost = 0.0
	_kick = 0.0


func _process(_delta: float) -> void:
	if not visible:
		return
	var dt := get_process_delta_time() / maxf(Engine.time_scale, 0.05)   # 실제 시간 (히트스탑·슬로모션과 무관)
	dt = minf(dt, 0.1)
	# 차오를 때는 천천히 쭉, 깎일 때는 빠르게
	ratio = move_toward(ratio, _stage_target, dt * (0.9 if _stage_target > ratio else 2.5))
	_ghost_hold -= dt
	if _ghost < ratio:
		_ghost = ratio
	elif _ghost_hold <= 0.0:
		_ghost = move_toward(_ghost, ratio, dt * (0.2 + (_ghost - ratio) * 2.0))
	_kick = maxf(0.0, _kick - dt * 5.0)
	queue_redraw()


func _draw() -> void:
	var k := size.x / Layout.SIZE.x
	var shake := Vector2(sin(Time.get_ticks_msec() * 0.09) * 3.0, -1.5) * _kick
	draw_set_transform(shake, 0.0, Vector2(k, k))
	draw_texture_rect(_frame, Rect2(Vector2.ZERO, Layout.SIZE), false)
	var x0 := Layout.FILL_X0
	var span := Layout.FILL_X1 - x0
	var fill_x := x0 + span * ratio
	if _ghost > ratio + 0.001:
		draw_colored_polygon(_bar_poly(x0 + span * _ghost), Layout.GHOST_COLOR)   # 흰빛 없이 처음부터 빨강 (사용자 요청)
	if ratio > 0.002:
		var poly := _bar_poly(fill_x)
		draw_polyline(_closed(poly), Layout.FILL_GLOW, 8.0, true)
		draw_polygon(poly, _bar_colors(poly, fill_x))
		# 눈금: 채워진 곳에만
		var top := _trough[0].y
		var bot := _trough[5].y
		var nc := Color(Layout.NOTCH_COLOR, NOTCH_ALPHA)
		for nx in Layout.NOTCH_X:
			if float(nx) + Layout.NOTCH_W < fill_x - 10.0:
				draw_rect(Rect2(float(nx), top, Layout.NOTCH_W, bot - top), nc)
		# 윗면 광택
		draw_rect(Rect2(x0 + 22.0, top + 4.0, maxf(fill_x - x0 - 44.0, 0.0), 5.0), Color(1, 1, 1, 0.22))
	if _kick > 0.5:
		draw_polyline(_closed(_trough), Color(1, 1, 1, (_kick - 0.5) * 1.2), 4.0, true)
	_draw_dividers()
	_draw_texts()
	draw_set_transform(Vector2.ZERO)


## 바 모양 (바닥 홈 경로) 을 오른쪽 끝 x 까지: 오른쪽 끝 점들을 통째로 옮긴다. 너무 짧으면 끝 모양을 눌러 담는다.
func _bar_poly(right: float) -> PackedVector2Array:
	var src := _trough
	var shift := right - Layout.FILL_X1
	var min_x := Layout.FILL_X0 + 18.0
	var out := PackedVector2Array()
	for p in src:
		if p.x >= Layout.FILL_TIP_FROM - 0.5:   # Vector2 는 float32 라 같은 값도 살짝 작다
			out.append(Vector2(maxf(p.x + shift, min_x + (p.x - Layout.FILL_TIP_FROM) * 0.3), p.y))
		else:
			out.append(p)
	return out


## 끝쪽 FILL_TIP_LEN 만큼 연두로 번지는 꼭짓점 색 (꼭짓점 x 로 섞는다)
func _bar_colors(poly: PackedVector2Array, right: float) -> PackedColorArray:
	var cols := PackedColorArray()
	for p in poly:
		var u := clampf(1.0 - (right - p.x) / Layout.FILL_TIP_LEN, 0.0, 1.0)
		cols.append(Layout.FILL_COLOR.lerp(Layout.FILL_TIP_COLOR, u * u))
	return cols


func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var c := poly.duplicate()
	c.append(poly[0])
	return c


## 웨이브 구획선: 오른쪽부터 1웨이브. 지금 웨이브 구획 위에 작은 삼각 표시.
func _draw_dividers() -> void:
	var x0 := Layout.FILL_X0
	var span := Layout.FILL_X1 - x0
	var top := _trough[0].y - 5.0
	var bot := _trough[5].y + 5.0
	for j in range(1, _wave_n):
		var x := x0 + span * float(j) / float(_wave_n)
		var r := Rect2(x - DIVIDER_W * 0.5, top, DIVIDER_W, bot - top)
		draw_rect(r.grow(3.0), Color.BLACK)
		draw_rect(r, Layout.FRAME_COLOR)
	# 지금 웨이브 구획 가운데 아래쪽에 ▲
	var seg := float(_wave_n - _wave_i)
	var cx := x0 + span * (seg + 0.5) / float(_wave_n)
	var y := bot + 2.0
	var tri := PackedVector2Array([Vector2(cx, y), Vector2(cx + 14.0, y + 16.0), Vector2(cx - 14.0, y + 16.0)])
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
	draw_colored_polygon(PackedVector2Array([tri[0] + Vector2(0, -6), tri[1] + Vector2(7, 4), tri[2] + Vector2(-7, 4)]), Color.BLACK)
	draw_colored_polygon(tri, Color(Layout.FILL_TIP_COLOR, pulse))


func _draw_texts() -> void:
	# 위 명판: 웨이브 남은 체력 (시안: 흰 글자 + 남색 외곽선, 넓게 늘이고 기울임)
	_slanted(_hp_text, Layout.TOP_TEXT_RECT, Layout.TOP_PLATE, Layout.TOP_TEXT_XFORM, Layout.TOP_TEXT_COLOR,
		Layout.TOP_TEXT_STROKE, Layout.TOP_TEXT_STROKE_PX * 2.0)
	# 아래 명판: 스테이지에 남은 몫
	_slanted("%d%%" % int(ceilf(_stage_target * 100.0 - 0.001)), Layout.BOTTOM_TEXT_RECT, Layout.BOTTOM_PLATE,
		Layout.BOTTOM_TEXT_XFORM, Layout.BOTTOM_TEXT_COLOR, Color(0, 0, 0, 0), 0.0)
	# 바 위 양옆
	var y := Layout.TOP_PLATE.end.y + 2.0
	var left := Rect2(Layout.FILL_X0 + 20.0, 0, Layout.TOP_PLATE.position.x - Layout.FILL_X0 - 50.0, 0)
	var right := Rect2(Layout.TOP_PLATE.end.x + 30.0, 0, Layout.FILL_X1 - Layout.TOP_PLATE.end.x - 50.0, 0)
	_side(Vector2(left.position.x, y), _wave_text, left.size.x, HORIZONTAL_ALIGNMENT_LEFT, Color(1.0, 0.94, 1.0))
	_side(Vector2(right.position.x, y), _left_text, right.size.x, HORIZONTAL_ALIGNMENT_RIGHT, Color(1.0, 0.82, 0.9))


func _side(at: Vector2, s: String, w: float, align: HorizontalAlignment, col: Color) -> void:
	var fs := int(SIDE_TEXT_PX)
	draw_string_outline(_font, at, s, align, w, fs, 14, Color(0.06, 0.02, 0.14))
	draw_string(_font, at, s, align, w, fs, col)


## 시안 글자 bbox 에 맞춰 늘이고 기울여 그린다. 명판보다 넓어지면 줄인다.
func _slanted(s: String, rect: Rect2, plate: Rect2, xf: Vector3, col: Color, stroke: Color, stroke_px: float) -> void:
	var fs := int(round(rect.size.y / xf.z / 0.72))
	var w := _num_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * xf.x
	var room := plate.size.x - 40.0
	if w > room:
		fs = int(fs * room / w)
		w = room
	var cap := float(fs) * 0.72 * xf.z
	var base := Vector2(plate.get_center().x - w * 0.5 + xf.y * cap * 0.5, rect.end.y - (rect.size.y - cap) * 0.5)
	var k := size.x / Layout.SIZE.x
	var shake := Vector2(sin(Time.get_ticks_msec() * 0.09) * 3.0, -1.5) * _kick
	var m := Transform2D(Vector2(k, 0), Vector2(0, k), shake) * Transform2D(Vector2(xf.x, 0), Vector2(xf.y, xf.z), base)
	draw_set_transform_matrix(m)
	if stroke_px > 0.0:
		draw_string_outline(_num_font, Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(stroke_px), stroke)
	draw_string(_num_font, Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	draw_set_transform(shake, 0.0, Vector2(k, k))
