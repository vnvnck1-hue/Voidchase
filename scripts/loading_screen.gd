## 페이크 로딩 화면: 로비에서 모드에 들어갈 때 SceneSwitcher 가 띄운다. 검정 바탕 오른쪽 아래에
## NOW LOADING... 문구 + 카드 메이드(8프레임 8fps 루프, docs/loading_concepts_v1/HANDOFF.md 의 A 시안).
## 진행 막대 대신 문구 글자가 왼쪽부터 하나씩 위로 통통 튄다(파도). 실제로 기다릴 일은 없지만 진짜 로딩처럼 보이게,
## 숨은 진행도를 매번 다르게 짠 계단(빠르게 오르다 멈칫)으로 돌리고 그 진행이 오를 때 파도가 빨라진다.
## 중간중간 화면 전체가 잠깐 굳는다(메인 스레드가 막힌 것처럼 메이드·글자가 같이 멈춤).
## 흐름: start() → 페이드 인 → DURATION_MIN~MAX 초 사이에서 매번 고른 시간만큼 진행 → covered 신호(이때 SceneSwitcher 가 씬을 바꾼다) → reveal() 로 걷힘.
## 시간은 실시간 시계(Time.get_ticks_usec)로 잰다: 씬 전환 등 진짜 멈춤이 와도 총 길이는 그대로.
extends CanvasLayer

signal covered    # 숨은 진행이 100% 에 닿아 화면이 다 가려진 상태 (여기서 씬을 바꾼다)
signal finished   # 걷히고 나서 지워지기 직전

const SHEET := preload("res://assets/textures/loading/card_maid_sheet.png")
const SHEET_COLS := 4
const SHEET_FRAMES := 8
const SHEET_CELL := 448
const MAID_FPS := 8.0
const DURATION_MIN := 1.0    # 페이드 인부터 100% 까지 걸리는 시간은 이 사이에서 매번 랜덤
const DURATION_MAX := 3.0
const FADE_IN := 0.15
const FADE_OUT := 0.3
const HOLD_FULL := 0.18      # 100% 에 닿고 잠깐 머문 뒤 covered
const FG := Color(1, 1, 1)
const MAID_RECT := Rect2(1672, 836, 200, 200)     # 1920x1080 기준, 오른쪽 아래에 붙인다
const TEXT := "NOW LOADING..."
const TEXT_RECT := Rect2(1000, 892, 670, 90)      # 글자는 이 안에서 오른쪽 끝에 맞춘다 (위쪽 여백 = 점프 높이)
const TEXT_SIZE := 60
const TEXT_BASELINE := 76.0                       # TEXT_RECT 위에서부터 글자 바닥선까지
## 파도: 위상 1 = 한 바퀴. 시간에 따라 WAVE_SPEED 로 가고, 숨은 진행도가 0→1 오르는 동안 WAVE_BOOST 바퀴를 더 간다.
const WAVE_SPEED := 0.75
const WAVE_BOOST := 2.0
const LETTER_LAG := 0.06     # 다음 글자가 늦게 튀는 정도 (위상). 14글자면 파도가 한 바퀴를 거의 채운다
const HOP_LEN := 0.2         # 한 글자가 떠 있는 길이 (위상)
const HOP_H := 16.0
const SLANT := 0.22          # 기울임 (위로 갈수록 오른쪽)

var _root: Control
var _maid: TextureRect
var _atlas: AtlasTexture
var _text: Control
var _font: Font
var _x: PackedFloat32Array   # 글자별 왼쪽 x (TEXT_RECT 기준)
var _wave := 0.0             # 지금 그리는 파도 위상
var _rng := RandomNumberGenerator.new()
## 진행 계단: [{t: 시작 시각, dur: 오르는 시간, to: 도착 진행도}] (t 오름차순)
var _steps: Array[Dictionary] = []
## 굳는 구간: [[시작, 끝], ...]
var _freezes: Array[PackedFloat64Array] = []
var _t0 := 0
var _shown := 0.0            # 굳기 전 마지막으로 그린 시각 (굳은 동안 이 시각의 모습을 유지)
var _covered := false
var _duration := DURATION_MAX


func _ready() -> void:
	layer = 120   # SceneSwitcher 의 톱니·설정 메뉴(100) 위
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_plan()


func start() -> void:
	_t0 = Time.get_ticks_usec()
	_root.modulate.a = 0.0
	create_tween().set_ignore_time_scale().tween_property(_root, "modulate:a", 1.0, FADE_IN)


## covered 뒤에 부른다: 새 씬이 첫 화면을 그릴 틈을 두고 걷어낸다.
func reveal() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var tw := create_tween().set_ignore_time_scale()
	tw.tween_property(_root, "modulate:a", 0.0, FADE_OUT)
	await tw.finished
	finished.emit()
	queue_free()


func elapsed() -> float:
	return (Time.get_ticks_usec() - _t0) / 1e6


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # 로딩 중 클릭이 아래(로비·톱니)로 새지 않게
	add_child(_root)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.BLACK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	_atlas = AtlasTexture.new()
	_atlas.atlas = SHEET
	_atlas.region = Rect2(0, 0, SHEET_CELL, SHEET_CELL)
	_maid = TextureRect.new()
	_maid.texture = _atlas
	_maid.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_maid.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_maid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin(_maid, MAID_RECT)

	# 글꼴은 데미지 로그와 같은 ARCO
	var base := FontVariation.new()
	base.base_font = VDDamageLog.font()
	_root.theme = Theme.new()
	_root.theme.default_font = base   # 아래 Label 전부에 적용
	_font = base
	# 글자마다 따로 튀어야 해서 Label 대신 한 글자씩 직접 그린다. 오른쪽 끝을 TEXT_RECT 에 맞춘다.
	# 글자 사이 간격은 앞까지의 문자열 폭 차이로 잡는다 (커닝 포함).
	var w := base.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	for i in TEXT.length():
		_x.append(TEXT_RECT.size.x - w + base.get_string_size(TEXT.left(i), HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x)
	_text = Control.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.draw.connect(_draw_text)
	_pin(_text, TEXT_RECT)


## 직접 그리는 글자에는 FontVariation.variation_transform 기울임이 안 먹어서, 글자마다 기울인 변환을 걸어 그린다.
func _draw_text() -> void:
	for i in TEXT.length():
		var at := Vector2(_x[i], TEXT_BASELINE - _hop(i))
		_text.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-SLANT, 1), at))
		_text.draw_string(_font, Vector2.ZERO, TEXT[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, FG)
	_text.draw_set_transform_matrix(Transform2D.IDENTITY)


## i 번째 글자의 지금 높이: 파도가 지나갈 때 sin 반 바퀴로 떴다가 내려온다.
func _hop(i: int) -> float:
	var k := fposmod(_wave - i * LETTER_LAG, 1.0) / HOP_LEN
	return sin(PI * k) * HOP_H if k < 1.0 else 0.0


func _pin(c: Control, rect: Rect2) -> void:
	SceneSwitcher.pin(c, Vector2(1, 1), rect)
	_root.add_child(c)


## 매번 다른 진행 계단과 굳는 구간을 짠다.
## 계단: 1초면 3~5번, 3초면 5~7번(길이에 비례). 오를 때는 0.06~0.35초로 빠르게, 사이사이 쉬는 시간은 들쭉날쭉. 99% 근처에서 한 번 더 버틴다.
func _plan() -> void:
	_rng.randomize()
	_duration = _rng.randf_range(DURATION_MIN, DURATION_MAX)
	var long := inverse_lerp(DURATION_MIN, DURATION_MAX, _duration)   # 0 = 가장 짧음, 1 = 가장 김
	var n := _rng.randi_range(3, 5) + roundi(2.0 * long)
	var end_t := _duration - HOLD_FULL
	# 도착 진행도: 0~0.96 사이를 고르지 않게 나눈 뒤 마지막 직전은 0.97~0.99 에서 버티고 1.0
	var marks: Array[float] = []
	for i in n - 2:
		marks.append(_rng.randf_range(0.08, 0.93))
	marks.sort()
	marks.append(_rng.randf_range(0.97, 0.99))
	marks.append(1.0)
	# 시작 시각: 페이드 인 뒤부터 end_t 사이에 무게를 달리해 흩뿌린다 (앞쪽이 조금 빽빽)
	var weights: Array[float] = []
	var total := 0.0
	for i in n:
		var w := _rng.randf_range(0.4, 1.6)
		weights.append(w)
		total += w
	var t := FADE_IN + _rng.randf_range(0.05, 0.2)
	var span := end_t - t
	for i in n:
		var dur := _rng.randf_range(0.06, 0.35) if i < n - 1 else 0.1
		var gap := span * weights[i] / total
		_steps.append({"t": t, "dur": minf(dur, gap * 0.8), "to": marks[i]})
		t += gap
	# 마지막 계단이 정확히 end_t 에 닿게 끝을 맞춘다
	var last := _steps[n - 1]
	last["t"] = end_t - last["dur"]
	# 굳는 구간: 1초면 1~2번, 3초면 2~3번. 0.12~0.32초, 서로 겹치지 않게
	var k := _rng.randi_range(1, 2) + roundi(long)
	for i in k:
		var a := FADE_IN + (end_t - FADE_IN) * (i + _rng.randf_range(0.15, 0.75)) / k
		_freezes.append(PackedFloat64Array([a, a + _rng.randf_range(0.12, 0.32)]))


func _progress_at(t: float) -> float:
	var p := 0.0
	for s in _steps:
		if t < s["t"]:
			break
		var from := p
		var k := clampf((t - s["t"]) / maxf(s["dur"], 0.001), 0.0, 1.0)
		p = lerpf(from, s["to"], 1.0 - pow(1.0 - k, 3.0))   # 오를 때 ease-out
	return p


func _frozen(t: float) -> bool:
	for f in _freezes:
		if t >= f[0] and t < f[1]:
			return true
	return false


func _process(_delta: float) -> void:
	if _t0 == 0:
		return
	var t := elapsed()
	if not _frozen(t):
		_shown = t
	_draw_at(_shown)
	if not _covered and t >= _duration:
		_covered = true
		_draw_at(_duration)
		covered.emit()


func _draw_at(t: float) -> void:
	var frame := int(t * MAID_FPS) % SHEET_FRAMES
	@warning_ignore("integer_division")
	var row := frame / SHEET_COLS
	_atlas.region = Rect2((frame % SHEET_COLS) * SHEET_CELL, row * SHEET_CELL, SHEET_CELL, SHEET_CELL)
	_wave = t * WAVE_SPEED + _progress_at(t) * WAVE_BOOST
	_text.queue_redraw()
