## VOID DEFENSE 카메라: 위치는 VDBattle 이 정하고, 여기서는 그 위에 얹는 움직임만 다룬다.
##   위빙   : 평소에 아주 살살 떠다닌다(offset 리사주 + 미세한 줌 호흡). 역동감용.
##   셰이크 : shake(amount) 로 트라우마를 쌓으면 제곱에 비례해 흔들리고 빠르게 가라앉는다. 약하게 쓴다.
##   히트스탑: hitstop(sec) 동안 Engine.time_scale 을 거의 0 으로 내렸다가 원래 배속으로 되돌린다.
##   슬로모션: slowmo(sec, scale) 동안 시간을 scale 배로 늦췄다가 끝 무렵 부드럽게 원래 배속으로 되돌린다(처치·사망 연출).
##            히트스탑과 겹치면 두 배율이 곱해진다. 둘 다 배속(속도 버튼) 위에 얹힌다.
##   줌     : base_zoom 을 트윈하면(전투 줌인 등) 호흡이 그 위에 곱해진다.
## 위빙·셰이크는 실제 시간으로 움직여서 히트스탑 중에도 화면이 멈춘 채 흔들린다.
## 배경 셰이더(void_nebula)의 parallax 도 여기서 넣는다.
class_name VDCamera
extends Camera2D

const WEAVE_PX := Vector2(7.0, 4.5)     # 위빙 진폭
const WEAVE_ZOOM := 0.006               # 줌 호흡 진폭(비율)
const SHAKE_PX := 5.0                   # 트라우마 1 일 때 최대 흔들림 (9 는 어지러웠다)
const SHAKE_DECAY := 2.6                # 초당 트라우마 감소
const HITSTOP_SCALE := 0.04             # 히트스탑 중 시간 배율
const HITSTOP_GAP := 0.12               # 히트스탑 끝난 뒤 이 시간(실시간) 동안은 새 히트스탑 무시
const SLOW_EASE := 0.4                  # 슬로모션 마지막 이 비율 동안 원래 배속으로 부드럽게 돌아온다

var base_zoom := Vector2.ONE
var bg_material: ShaderMaterial
var parallax_k := 0.00035               # 화면 이동 1px 당 배경 이동(셰이더 좌표)

var _t := 0.0
var _trauma := 0.0
var _stop_until := 0.0                  # 히트스탑 끝나는 실시간(초)
var _stop_ready_at := 0.0
var _saved_scale := 1.0                 # 효과(히트스탑·슬로모션)가 없을 때의 배속
var _stopping := false
var _slowing := false
var _slow_from := 0.0                   # 슬로모션 시작 실시간(초)
var _slow_until := 0.0
var _slow_scale := 1.0
var _clock_us := 0
var _punch := 0.0                       # 줌 펀치 (치명타 등): 순간 확 당겼다가 실제 시간으로 빠르게 풀린다


## 줌 펀치: amount 비율만큼 순간 줌인 (예 0.04 = 4%). 겹치면 큰 쪽.
func punch(amount: float) -> void:
	_punch = maxf(_punch, amount)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func hitstop(sec: float) -> void:
	var now := _now()
	if _stopping:
		_stop_until = maxf(_stop_until, now + sec)
		return
	if now < _stop_ready_at:
		return
	_save_speed()
	_stopping = true
	_stop_until = now + sec
	_apply_scale()


## 슬로모션: sec(실시간) 동안 시간을 scale 배로. 진행 중이면 더 길거나 더 느린 쪽이 이긴다(짧은 것이 긴 것을 끊지 않는다).
func slowmo(sec: float, scale: float) -> void:
	var now := _now()
	if _slowing and now + sec <= _slow_until and scale >= _slow_scale:
		return
	_save_speed()
	_slow_scale = minf(scale, _slow_scale) if _slowing else scale
	_slow_until = maxf(_slow_until, now + sec) if _slowing else now + sec
	_slow_from = now
	_slowing = true
	_apply_scale()


## 궁극기 연출 시작: 진행 중인 히트스탑·슬로모션을 끊고 원래 배속으로 (TrioChess cam.cancel_hitstop).
func cancel_effects() -> void:
	if _stopping or _slowing:
		_stopping = false
		_slowing = false
		Engine.time_scale = _saved_scale


## 히트스탑·슬로모션을 감안한 현재 배속(속도 토글이 쓴다).
func game_speed() -> float:
	return _saved_scale if (_stopping or _slowing) else Engine.time_scale


func set_game_speed(s: float) -> void:
	if _stopping or _slowing:
		_saved_scale = s
		_apply_scale()
	else:
		Engine.time_scale = s


func _save_speed() -> void:
	if not _stopping and not _slowing:
		_saved_scale = Engine.time_scale


## 슬로모션 배율: 앞부분은 scale 그대로, 마지막 SLOW_EASE 구간에서 1 로 부드럽게.
func _slow_factor(now: float) -> float:
	if not _slowing:
		return 1.0
	var dur := maxf(_slow_until - _slow_from, 0.0001)
	var k := clampf((now - _slow_from) / dur, 0.0, 1.0)
	var e := clampf((k - (1.0 - SLOW_EASE)) / SLOW_EASE, 0.0, 1.0)
	return lerpf(_slow_scale, 1.0, e * e * (3.0 - 2.0 * e))


func _apply_scale() -> void:
	Engine.time_scale = _saved_scale * (HITSTOP_SCALE if _stopping else 1.0) * _slow_factor(_now())


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


func _exit_tree() -> void:
	if _stopping or _slowing:
		Engine.time_scale = _saved_scale
		_stopping = false
		_slowing = false


func _process(delta: float) -> void:
	# delta / time_scale 는 배율이 바뀌는 프레임에 튀므로 시계로 잰다
	var now_us := Time.get_ticks_usec()
	var real := clampf((now_us - _clock_us) / 1000000.0, 0.0, 0.1) if _clock_us > 0 else minf(delta, 0.1)
	_clock_us = now_us
	var now := _now()
	var was := _stopping or _slowing
	if _stopping and now >= _stop_until:
		_stopping = false
		_stop_ready_at = now + HITSTOP_GAP
	if _slowing and now >= _slow_until:
		_slowing = false
	if _stopping or _slowing:
		_apply_scale()
	elif was:
		Engine.time_scale = _saved_scale
	_t += real
	# 위빙: 서로 맞지 않는 주기의 사인을 겹쳐 반복이 안 느껴지게
	var weave := Vector2(
		sin(_t * 0.31) * 0.65 + sin(_t * 0.53 + 1.3) * 0.35,
		sin(_t * 0.27 + 2.1) * 0.6 + sin(_t * 0.47 + 0.4) * 0.4) * WEAVE_PX
	# 셰이크
	var sh := Vector2.ZERO
	if _trauma > 0.0:
		var k := _trauma * _trauma * SHAKE_PX
		sh = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * k
		_trauma = maxf(0.0, _trauma - SHAKE_DECAY * real)
	offset = weave + sh
	_punch = move_toward(_punch, 0.0, real * maxf(0.25, _punch * 9.0))
	zoom = base_zoom * (1.0 + WEAVE_ZOOM * sin(_t * 0.23 + 0.7) + _punch)
	if bg_material:
		bg_material.set_shader_parameter("parallax", (global_position + offset) * parallax_k)
