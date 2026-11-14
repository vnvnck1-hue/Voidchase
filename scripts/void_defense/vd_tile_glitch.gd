## 전투 필드 타일 글리치 (2026-11-11): 이곳이 의뢰인의 마음을 옮긴 디지털 세계라는 느낌을 바닥에 넣는다.
## 보드 바로 위·바닥 이펙트 아래에 타일 윗면 마름모를 한 장씩 깔고 shaders/tile_glitch.gdshader 로 그 아래 화면을 비튼다.
##   · 타일이 가끔 혼자 '치지직' (프리셋 3종: 신호 잡음 / 데이터 붕괴 / 기억 홀로그램) — 설정 [타일 글리치] · F4 로 넘김
##   · 기억 스캔선: 깊이 방향으로 전장을 훑는 빛
##   · 충격 물결: 강타·처치·내려찍기 지점에서 타일 단위로 글리치가 번진다 (VDShockwave.struck)
##   · 구역 로딩: 새 방·복도가 다 솟아오르면 분대 쪽에서 새 타일로 물결이 한 번 지나간다
##   · 바닥 기억 로그: 현재 방의 한 칸에 기억 조각 글자가 바닥에 누운 채 잠깐 찍힌다 — 설정 [바닥 기억 로그]
## 솟아오르는 중인 타일은 건너뛴다(보드가 내려 그리는 중이라 자리가 다르다).
class_name VDTileGlitch
extends Node2D

const SHADER := preload("res://shaders/tile_glitch.gdshader")
const LABELS := ["끄기", "신호 잡음", "데이터 붕괴", "기억 홀로그램"]
## LABELS 와 같은 순서 (0 = 끄기). density: 한 박자에 타일 하나가 지직거릴 확률, rate: 박자/초
const PRESETS := [
	{},
	{"style": 0, "density": 0.04, "rate": 1.3, "step_fps": 16.0, "amount": 1.0, "sweep": 0.22, "sweep_period": 10.0},
	{"style": 1, "density": 0.03, "rate": 0.8, "step_fps": 9.0, "amount": 1.0, "sweep": 0.22, "sweep_period": 10.0},
	{"style": 2, "density": 0.028, "rate": 0.55, "step_fps": 12.0, "amount": 1.0, "sweep": 0.45, "sweep_period": 7.0},
]
const MAX_PULSES := 6
const COL := Color(0.15, 0.96, 0.93)
## 바닥 기억 로그 문구: 진단명·무거운 말은 쓰지 않는다 (docs/네러티브_기획서.md 소재 원칙). %s 는 무작위 16진수.
const LOG_LINES := [
	"MEM_%s", "기억 조각 #%s", "SYNC 9%s", "마음 연결 안정", "// 잊고 있던 것", "ECHO_%s",
	"정리 중…", "꿈 캐시 %s", "어제의 대화", "…괜찮아", "감정 로그 %s", "좋았던 날",
]
const LOG_SEC := 1.9
const LOG_FONT := 21
const IDLE_BOOT_DELAY := 1.2   # 전투 입장: 안개가 열릴 즈음 첫 물결

static var config_path := "user://vd_tile_glitch.cfg"
static var selected := 1
static var log_on := true
static var _loaded := false

var board: VDBoard
var time := 0.0
var manual_time := false       # 캡처: time 을 밖에서 넣는다
var density_boost := 1.0       # 캡처: 지직거리는 타일을 늘린다

var _mat: ShaderMaterial
var _sig := Vector3i(-1, -1, -1)
var _known := {}
var _boot_due := false
var _pulses: Array[Dictionary] = []
var _pv := PackedVector4Array()
var _ps := PackedVector4Array()
var _log_layer: Node2D
var _log := {}
var _log_wait := 3.0


static func load_saved() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(config_path) == OK:
		selected = clampi(int(cfg.get_value("tile_glitch", "style", 1)), 0, LABELS.size() - 1)
		log_on = bool(cfg.get_value("tile_glitch", "log", true))


static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("tile_glitch", "style", selected)
	cfg.set_value("tile_glitch", "log", log_on)
	cfg.save(config_path)


func _ready() -> void:
	load_saved()
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("half_tile", Vector2(VDData.TILE_W, VDData.TILE_H) * 0.5)
	material = _mat
	_pv.resize(MAX_PULSES)
	_ps.resize(MAX_PULSES)
	_log_layer = Node2D.new()
	_log_layer.name = "MemoryLog"
	_log_layer.draw.connect(_draw_log)
	add_child(_log_layer)
	set_style(selected, false)


func set_style(i: int, persist := true) -> void:
	selected = clampi(i, 0, LABELS.size() - 1)
	if persist:
		_save()
	visible = selected > 0
	if selected > 0:
		var p: Dictionary = PRESETS[selected]
		for key: String in p:
			_mat.set_shader_parameter(key, p[key])
		_mat.set_shader_parameter("density", float(p["density"]) * density_boost)


func cycle() -> String:
	set_style((selected + 1) % LABELS.size())
	return LABELS[selected]


func toggle_log() -> void:
	log_on = not log_on
	_save()
	if not log_on:
		_log.clear()
		_log_layer.queue_redraw()


func is_log_on() -> bool:
	return log_on


## cell 을 중심으로 타일 단위 글리치 물결. speed 칸/초, life 초, radius 최대 반경(칸; 0 이면 그 칸만).
func pulse(cell: Vector2, strength := 1.0, speed := 9.0, life := 0.6, radius := 2.0, delay := 0.0) -> void:
	_pulses.append({"cell": cell, "t0": time + delay, "k": strength, "speed": speed, "life": life, "r": radius})
	if _pulses.size() > MAX_PULSES:
		_pulses.pop_front()


## VDShockwave.struck: 평타는 건너뛰고 강타는 그 칸만, 처치·내려찍기·보스는 주변으로 번진다.
func on_struck(floor_at: Vector2, kind: String, k: float) -> void:
	if selected == 0:
		return
	var cell := Vector2(VDData.to_cell(floor_at))
	match kind:
		"heavy":
			pulse(cell, 0.8 * k, 0.0, 0.28, 0.0)
		"kill":
			pulse(cell, 1.0, 8.0, 0.5, 2.2)
		"slam":
			pulse(cell, 1.0, 10.0, 0.7, 4.5)
		"boss":
			pulse(cell, 1.0, 9.0, 1.2, 8.0)


func _draw() -> void:
	if board == null or board.map == null:
		return
	var lo := INF
	var hi := -INF
	for cell: Vector2i in board.map.tiles:
		lo = minf(lo, cell.x + cell.y)
		hi = maxf(hi, cell.x + cell.y)
		if board._rise.has(cell):
			continue
		var d := VDData.diamond(VDData.to_screen(Vector2(cell)))
		d.resize(4)
		draw_colored_polygon(d, Color.WHITE)
	if lo <= hi:
		_mat.set_shader_parameter("sweep_range", Vector2(lo, hi))


func _process(delta: float) -> void:
	if not visible or board == null or board.map == null:
		return
	if not manual_time:
		time += delta
	_sync_tiles()
	_pulses = _pulses.filter(func(p: Dictionary) -> bool: return time - p["t0"] < p["life"])
	for i in MAX_PULSES:
		if i < _pulses.size():
			var p := _pulses[i]
			_pv[i] = Vector4(p["cell"].x, p["cell"].y, p["t0"], p["k"])
			_ps[i] = Vector4(p["speed"], p["life"], p["r"], 0.0)
		else:
			_pv[i] = Vector4.ZERO
			_ps[i] = Vector4.ZERO
	_mat.set_shader_parameter("u_time", time)
	_mat.set_shader_parameter("pulses", _pv)
	_mat.set_shader_parameter("pulse_shape", _ps)
	_tick_log(delta)


## 타일 수·솟아오르는 수가 바뀌면 마름모를 다시 깔고, 새 타일이 다 올라오면 구역 로딩 물결을 보낸다.
func _sync_tiles() -> void:
	var map := board.map
	var sig := Vector3i(map.tiles.size(), board._rise.size(), map.get_instance_id() % 1000000)
	if sig == _sig:
		return
	var new_map := sig.z != _sig.z
	_sig = sig
	queue_redraw()
	if new_map:
		_known.clear()
	var fresh: Array[Vector2i] = []
	for cell: Vector2i in map.tiles:
		if not _known.has(cell):
			fresh.append(cell)
	if not fresh.is_empty():
		_boot_due = true
	if _boot_due and board._rise.is_empty():
		_boot_due = false
		var first := _known.is_empty()
		var from := VDMap.center_f(board.current_room) if not board.current_room.is_empty() else Vector2(fresh[0] if not fresh.is_empty() else Vector2i.ZERO)
		var far := 3.0
		for cell: Vector2i in map.tiles:
			if not _known.has(cell):
				far = maxf(far, from.distance_to(Vector2(cell)))
				_known[cell] = true
		pulse(from, 0.9, far / 1.1, 1.4, far + 1.0, IDLE_BOOT_DELAY if first else 0.0)


# ---------------------------------------------------------------- 바닥 기억 로그

func _tick_log(delta: float) -> void:
	if not log_on:
		return
	if not _log.is_empty():
		_log["t"] += delta
		if _log["t"] >= LOG_SEC:
			_log.clear()
		_log_layer.queue_redraw()
		return
	_log_wait -= delta
	if _log_wait > 0.0:
		return
	_log_wait = randf_range(2.8, 6.0)
	var cur_id: int = board.current_room.get("id", -1)
	var cells: Array[Vector2i] = []
	for cell: Vector2i in board.map.tiles:
		var t: Dictionary = board.map.tiles[cell]
		if t["room"] == cur_id and t["kind"] == "room":
			cells.append(cell)
	if cells.is_empty():
		return
	show_log(cells.pick_random())


func show_log(cell: Vector2i, text := "") -> void:
	if text == "":
		text = LOG_LINES.pick_random()
		if text.contains("%s"):
			text = text % ("%X" % randi_range(0x100, 0xFFF))
	_log = {"cell": cell, "text": text, "t": 0.0}
	pulse(Vector2(cell), 0.9, 0.0, 0.45, 0.0)
	_log_layer.queue_redraw()


## 칸 모서리 꺾쇠 + 바닥에 누운 글자(등각 축을 따라 기울임). 타자기처럼 찍히고 끝에 깜빡이며 사라진다.
func _draw_log() -> void:
	if _log.is_empty():
		return
	var u: float = _log["t"] / LOG_SEC
	var a := clampf((1.0 - u) * 4.0, 0.0, 1.0)
	if u < 0.12 or u > 0.85:
		a *= 0.35 + 0.65 * float(int(_log["t"] * 30.0) % 2)
	var col := Color(COL, 0.8 * a)
	var c := VDData.to_screen(Vector2(_log["cell"]))
	var d := VDData.diamond(c, 5.0)
	for i in 4:
		var p := d[i]
		_log_layer.draw_line(p, p.lerp(d[(i + 1) % 4], 0.16), col, 2.0)
		_log_layer.draw_line(p, p.lerp(d[(i + 3) % 4], 0.16), col, 2.0)
	var text: String = _log["text"]
	var shown := text.substr(0, int(ceilf(text.length() * clampf(u * 3.5, 0.0, 1.0))))
	var font := VDData.font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LOG_FONT).x
	_log_layer.draw_set_transform_matrix(Transform2D(Vector2(0.894, 0.447), Vector2(-0.894, 0.447), c))
	_log_layer.draw_string(font, Vector2(-w * 0.5 + 1.5, 9.0), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, LOG_FONT, Color(0.0, 0.05, 0.1, 0.6 * a))
	_log_layer.draw_string(font, Vector2(-w * 0.5, 7.0), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, LOG_FONT, Color(COL.lerp(Color.WHITE, 0.35), a))
	_log_layer.draw_set_transform_matrix(Transform2D.IDENTITY)
