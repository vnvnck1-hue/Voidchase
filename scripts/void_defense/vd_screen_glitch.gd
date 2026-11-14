## 화면 전체 '나쁜 피해' 글리치 (shaders/screen_glitch.gdshader): 아군이 피해를 받거나 공허가 성좌판을 침식하면
## 화면이 가로 띠로 찢어지며 청록/자홍으로 갈라지고 밝은 부분에 납작한 색 잔상이 남는다 (참고: 틱톡식 글리치 이모지).
## HUD 위 CanvasLayer(13) 에 전체 화면 ColorRect 하나. 안 켜져 있으면 숨긴다. 실제 시간으로 돌아 히트스탑 중에도 움직인다.
## 종류: hit(피격, strength 로 세기·지속, hit_scale 배율 — 2026-11-09 사용자 요청으로 절반) · corrupt(침식, 길고 맥동하며 더 어둡다)
##       defeat(패배: 큰 폭발 → 낮게 들끓으며 가끔 튀고, 굵은 띠가 통째로 끊긴다(dropout). VDBattle._do_game_over)
## 값(P)은 VDGlitchTuner(F9) 의 '화면 글리치' 칸에서 바꾸고 user://vd_screen_glitch.cfg 에 저장한다.
## 발동: 피격은 VDHurtGlitch.on_hit 콜백(vd_battle) 에서 카드 흔들림과 함께, 침식은 VDBattle._relic_rewards 에서.
extends CanvasLayer

const SHADER := preload("res://shaders/screen_glitch.gdshader")
const CFG_PATH := "user://vd_screen_glitch.cfg"

## 조정 값: [키, 이름, 최소, 최대, 간격, 기본]
const PARAMS := [
	["life", "피격 지속 (초)", 0.1, 1.5, 0.01, 0.3],
	["corrupt_life", "침식 지속 (초)", 0.2, 3.0, 0.05, 1.0],
	["defeat_life", "패배 지속 (초)", 0.5, 5.0, 0.1, 2.6],
	["step_fps", "박자 (초당 프레임)", 4.0, 60.0, 1.0, 18.0],
	["min_amount", "약한 피격 세기", 0.0, 1.0, 0.05, 0.3],
	["hit_scale", "피격 세기 배율", 0.0, 1.0, 0.05, 0.5],
	["split_px", "청록/자홍 분리 (px)", 0.0, 30.0, 0.5, 9.0],
	["band_count", "굵은 띠 수", 2.0, 40.0, 1.0, 12.0],
	["band_shift_px", "굵은 띠 밀림 (px)", 0.0, 200.0, 1.0, 70.0],
	["band_chance", "굵은 띠 비율", 0.0, 1.0, 0.05, 0.35],
	["fine_count", "가는 띠 수", 10.0, 200.0, 1.0, 90.0],
	["fine_shift_px", "가는 띠 밀림 (px)", 0.0, 300.0, 1.0, 160.0],
	["fine_chance", "가는 띠 비율", 0.0, 1.0, 0.05, 0.25],
	["ghost_px", "색 잔상 거리 (px)", 0.0, 60.0, 1.0, 22.0],
	["ghost_strength", "색 잔상 세기", 0.0, 1.0, 0.05, 0.8],
	["ghost_thresh", "색 잔상 밝기 문턱", 0.0, 1.0, 0.05, 0.55],
	["darken", "어두워짐", 0.0, 1.0, 0.05, 0.2],
	["cooldown", "재발동 간격 (초)", 0.0, 1.0, 0.05, 0.12],
]
const SHADER_KEYS := ["split_px", "band_count", "band_shift_px", "band_chance", "fine_count", "fine_shift_px", "fine_chance",
	"ghost_px", "ghost_strength", "ghost_thresh", "darken"]
## 종류별 배율 (키 -> 배수) 와 띠 끊김 비율
const KIND_MUL := {
	"corrupt": {"darken": 1.6},
	"defeat": {"darken": 1.5, "band_chance": 1.4, "band_shift_px": 1.3, "fine_chance": 1.3},
}
const KIND_DROPOUT := {"defeat": 0.3}

static var enabled := true

var P := {}

var _rect: ColorRect
var _mat: ShaderMaterial
var _kind := ""
var _amp0 := 0.0
var _life := 0.0
var _t0_us := 0
var _next_us := 0
var _last_kick_us := -1_000_000_000
var _flick := 1.0          # 박자마다 바뀌는 세기 흔들림 (0.55..1)
var _spike := 0.0          # 패배: 박자마다 가끔 튀어 오르는 세기
var _active := false


func _init() -> void:
	layer = 13
	process_mode = Node.PROCESS_MODE_ALWAYS   # 실제 시간으로 사그라든다: 궁극기 조준으로 트리가 멈춰도 화면에 얼어붙지 않게
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)
	reset_values()
	load_values()


func reset_values() -> void:
	for p in PARAMS:
		P[p[0]] = p[5]


## strength 0..1 → 세기(min_amount..1)·지속. kind: "hit" | "corrupt". 진행 중이면 더 센 쪽으로 다시 시작한다.
func kick(strength: float, kind := "hit") -> void:
	if not enabled:
		return
	var now := Time.get_ticks_usec()
	if _active and now - _last_kick_us < int(float(P["cooldown"]) * 1_000_000.0) and kind == "hit":
		return
	if _active and _kind == "defeat" and kind != "defeat":
		return   # 패배 연출 중엔 다른 글리치가 끼어들지 않는다
	var s := clampf(strength, 0.0, 1.0)
	var amp := lerpf(float(P["min_amount"]), 1.0, s) * (float(P["hit_scale"]) if kind == "hit" else 1.0)
	if _active and amp < _amp0 * _envelope() and kind == _kind:
		return   # 진행 중인 더 센 글리치를 약한 것이 끊지 않는다
	_last_kick_us = now
	_kind = kind
	_amp0 = amp
	match kind:
		"corrupt":
			_life = float(P["corrupt_life"])
		"defeat":
			_life = float(P["defeat_life"])
		_:
			_life = float(P["life"]) * lerpf(0.7, 1.0, s)
	_t0_us = now
	_next_us = now
	_active = true
	_rect.visible = true
	_step(now)
	_push()   # 맞은 그 프레임부터 바로 보이게 (다음 _process 를 기다리지 않는다)


## 쿨다운을 무시하고 바로 (조정 패널 테스트 버튼).
func reset_timer() -> void:
	_last_kick_us = -1_000_000_000
	_active = false


func is_active() -> bool:
	return _active


func toggle() -> void:
	enabled = not enabled
	if not enabled:
		_stop()


func is_on() -> bool:
	return enabled


func values_text() -> String:
	var parts := PackedStringArray()
	for p in PARAMS:
		parts.append('"%s": %s' % [p[0], str(snappedf(float(P[p[0]]), 0.001))])
	return "{" + ", ".join(parts) + "}"


func save_values() -> void:
	var cfg := ConfigFile.new()
	for k in P:
		cfg.set_value("screen_glitch", k, float(P[k]))
	cfg.save(CFG_PATH)


func load_values() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	for p in PARAMS:
		P[p[0]] = float(cfg.get_value("screen_glitch", p[0], p[5]))


func _elapsed() -> float:
	return (Time.get_ticks_usec() - _t0_us) / 1_000_000.0


## 0..1 진행에 따른 세기 (현재 박자 흔들림 제외). 피격: 빠르게 사그라듦 · 침식: 세 번 맥동하며 사그라듦 ·
## 패배: 처음 1/4 동안 큰 폭발이 가라앉고, 그 뒤로는 낮게 들끓으며(0.25 → 0.12) 박자마다 가끔 튀어 오른다(_spike).
func _envelope() -> float:
	var p := clampf(_elapsed() / maxf(_life, 0.001), 0.0, 1.0)
	if _kind == "corrupt":
		return (1.0 - p * 0.8) * (0.45 + 0.55 * absf(sin(p * PI * 3.0 + 0.4)))
	if _kind == "defeat":
		var burst := pow(maxf(0.0, 1.0 - p / 0.25), 1.5)
		var simmer := lerpf(0.25, 0.12, p)
		return clampf(burst + simmer + _spike * (1.0 - p * 0.5), 0.0, 1.0)
	return pow(1.0 - p, 1.6)


func _step(now: int) -> void:
	_next_us = now + int(1_000_000.0 / maxf(float(P["step_fps"]), 1.0))
	_flick = randf_range(0.55, 1.0)
	_spike = (0.6 if randf() < 0.18 else 0.0) if _kind == "defeat" else 0.0
	_mat.set_shader_parameter("seed", randf() * 100.0)


func _process(_delta: float) -> void:
	if not _active:
		return
	var now := Time.get_ticks_usec()
	if _elapsed() >= _life:
		_stop()
		return
	if now >= _next_us:
		_step(now)
	_push()


func _push() -> void:
	var mul: Dictionary = KIND_MUL.get(_kind, {})
	for k in SHADER_KEYS:
		_mat.set_shader_parameter(k, float(P[k]) * float(mul.get(k, 1.0)))
	_mat.set_shader_parameter("dropout", float(KIND_DROPOUT.get(_kind, 0.0)))
	_mat.set_shader_parameter("amount", clampf(_amp0 * _envelope() * _flick, 0.0, 1.0))


func _stop() -> void:
	_active = false
	_rect.visible = false
	_mat.set_shader_parameter("amount", 0.0)


## 화면 일부만 글리치되며 가라앉는 한 번짜리 연출 (패배 배너·패널이 글리치되며 물질화하는 느낌).
## rect 는 1920x1080 기준 좌표 (가운데에 붙여 넓은 화면에서도 가운데를 덮는다). 전체 글리치와 별개로 돌고 sec 뒤 스스로 사라진다.
func burst_rect(rect: Rect2, sec: float, amp := 1.0) -> void:
	if not enabled:
		return
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var mul: Dictionary = KIND_MUL["defeat"]
	for k in SHADER_KEYS:
		m.set_shader_parameter(k, float(P[k]) * float(mul.get(k, 1.0)))
	m.set_shader_parameter("dropout", 0.3)
	m.set_shader_parameter("amount", amp)
	r.material = m
	SceneSwitcher.pin(r, Vector2(0.5, 0.5), rect)
	add_child(r)
	var fps := maxf(float(P["step_fps"]), 1.0)
	var tw := r.create_tween().set_ignore_time_scale(true)
	tw.tween_method(func(v: float) -> void:
		var beat := floorf(v * sec * fps)
		var wob := beat * 0.618 - floorf(beat * 0.618)   # 박자마다 0..1 로 흔들리는 값
		m.set_shader_parameter("seed", fmod(beat * 7.31 + 3.0, 100.0))
		m.set_shader_parameter("amount", amp * pow(1.0 - v, 1.4) * (0.6 + 0.4 * wob)),
		0.0, 1.0, sec)
	tw.tween_callback(r.queue_free)
