## VOID DEFENSE 카메라: 위치는 VDBattle 이 정하고, 여기서는 그 위에 얹는 움직임만 다룬다.
##   위빙   : 평소에 아주 살살 떠다닌다(offset 리사주 + 미세한 줌 호흡). 역동감용.
##   셰이크 : shake(amount) 로 트라우마를 쌓으면 제곱에 비례해 흔들리고 빠르게 가라앉는다. 약하게 쓴다.
##   히트스탑: hitstop(sec) 동안 Engine.time_scale 을 거의 0 으로 내렸다가 원래 배속으로 되돌린다.
##   줌     : base_zoom 을 트윈하면(전투 줌인 등) 호흡이 그 위에 곱해진다.
## 위빙·셰이크는 실제 시간으로 움직여서 히트스탑 중에도 화면이 멈춘 채 흔들린다.
## 배경 셰이더(void_nebula)의 parallax 도 여기서 넣는다.
class_name VDCamera
extends Camera2D

const WEAVE_PX := Vector2(9.5, 6.0)     # 위빙 진폭
const WEAVE_ZOOM := 0.008               # 줌 호흡 진폭(비율)
const SHAKE_PX := 9.0                   # 트라우마 1 일 때 최대 흔들림
const SHAKE_DECAY := 2.6                # 초당 트라우마 감소
const HITSTOP_SCALE := 0.04             # 히트스탑 중 시간 배율
const HITSTOP_GAP := 0.12               # 히트스탑 끝난 뒤 이 시간(실시간) 동안은 새 히트스탑 무시

var base_zoom := Vector2.ONE
var bg_material: ShaderMaterial
var parallax_k := 0.00035               # 화면 이동 1px 당 배경 이동(셰이더 좌표)

var _t := 0.0
var _trauma := 0.0
var _stop_until := 0.0                  # 히트스탑 끝나는 실시간(초)
var _stop_ready_at := 0.0
var _saved_scale := 1.0
var _stopping := false


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
	_stopping = true
	_saved_scale = Engine.time_scale
	Engine.time_scale = _saved_scale * HITSTOP_SCALE
	_stop_until = now + sec


## 히트스탑을 감안한 현재 배속(속도 토글이 쓴다).
func game_speed() -> float:
	return _saved_scale if _stopping else Engine.time_scale


func set_game_speed(s: float) -> void:
	if _stopping:
		_saved_scale = s
		Engine.time_scale = s * HITSTOP_SCALE
	else:
		Engine.time_scale = s


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


func _exit_tree() -> void:
	if _stopping:
		Engine.time_scale = _saved_scale
		_stopping = false


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.0001)
	real = minf(real, 0.1)
	if _stopping and _now() >= _stop_until:
		_stopping = false
		Engine.time_scale = _saved_scale
		_stop_ready_at = _now() + HITSTOP_GAP
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
	zoom = base_zoom * (1.0 + WEAVE_ZOOM * sin(_t * 0.23 + 0.7))
	if bg_material:
		bg_material.set_shader_parameter("parallax", (global_position + offset) * parallax_k)
