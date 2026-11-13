## 전투 입장 연출 (2026-11-09): 화면 전체를 덮은 하프톤 안개가 중앙에서 타원으로 열리며 전장이 드러난다.
## 앞 안개 레이어(5) 위에 덧판 ColorRect 하나를 깔고 halftone_fog.gdshader 의 reveal 을 0 → 1 로 돌린다.
## 덧판은 가장자리 마스크를 끄고(edge_mask 0) 구멍만 그리므로, 앞 안개 스타일이 기체든 하프톤이든 그 위에서 같은 연출이 나온다.
## 색·도트 간격·각도·일렁임은 배경 조정 패널에 저장된 하프톤 값(VDNebulaTuner.halftone_params)을 그대로 쓴다. 끝나면 스스로 지워진다.
## 시계는 UIIntro 와 같은 이유로 프레임 간격을 잘라 쓴다 (씬 전환 직후의 긴 프레임에 연출이 통째로 넘어가지 않게).
class_name VDFogReveal
extends ColorRect

signal finished

const SHADER := preload("res://shaders/halftone_fog.gdshader")
const DUR := 1.5          # 열리는 데 걸리는 시간 (실제 시간). 가운데 도트가 보이기 시작 ≈ 0.3s · 가운데가 다 열림 ≈ 0.5s · 가장자리 ≈ 1.0s

var _mat: ShaderMaterial
var _phase := 0.0
var _speed := 0.06
var _t := 0.0
var _delay := 0.0
var _dur := DUR
var _clock_us := 0
var _done := false


## parent(앞 안개 레이어) 에 덧판을 깔고 delay 초 뒤 dur 동안 연다. params: fog_color · wisp_color · ht_* (halftone_params).
static func play(parent: Node, params: Dictionary, aspect: float, delay := 0.0, dur := DUR) -> VDFogReveal:
	var r := VDFogReveal.new()
	r.setup(params, aspect)
	r._delay = delay
	r._dur = dur
	parent.add_child(r)
	return r


func setup(params: Dictionary, aspect: float) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	for k in params:
		_mat.set_shader_parameter(k, params[k])
	_speed = float(params.get("ht_speed", 0.06))
	_mat.set_shader_parameter("aspect", aspect)
	_mat.set_shader_parameter("edge_mask", 0.0)
	_mat.set_shader_parameter("reveal", 0.0)
	_mat.set_shader_parameter("wisp_phase", 0.0)
	material = _mat
	_clock_us = Time.get_ticks_usec()


## 열린 정도 (0 다 덮임 → 1 평소). 연출 경과 시간에서 셈한다: 살짝 느리게 시작해 거의 일정한 속도로 번지고 끝에서 녹아든다.
## (급한 in-out 곡선은 구멍이 화면을 지나는 구간이 0.3초 남짓이라 망점 테두리를 볼 틈이 없었다)
func reveal_at(t: float) -> float:
	var k := clampf((t - _delay) / maxf(_dur, 0.001), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)   # smoothstep


func elapsed() -> float:
	return _t


func _process(_delta: float) -> void:
	if _done:
		return
	var now := Time.get_ticks_usec()
	var dt := clampf((now - _clock_us) / 1_000_000.0, 0.0, UIIntro.MAX_DT)
	_clock_us = now
	_t += dt
	# 경계 일렁임은 평소 안개(VDNebulaTuner 가 wisp_phase 를 돌린다)처럼 실제 시간으로 흐른다
	_phase += dt * _speed
	_mat.set_shader_parameter("wisp_phase", _phase)
	_mat.set_shader_parameter("reveal", reveal_at(_t))
	if _t >= _delay + _dur:
		_done = true
		finished.emit()
		queue_free()
