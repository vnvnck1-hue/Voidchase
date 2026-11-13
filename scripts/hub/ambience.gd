## 절차 생성 배경음 (음원 파일 없이): 허브·타이틀의 잔잔한 패드와 다이브 중의 낮은 드론.
## 16초짜리 이음매 없는 루프를 한 번 합성해 둔다 — 모든 주파수·떨림을 1/16 Hz 의 배수로 잡아 끝과 처음이 정확히 이어진다.
##   "hub"  A 장조 패드(따뜻한 3화음) + 모니터 신호음 같은 높은 종소리 몇 개
##   "dive" A 단조의 낮은 드론 + 느린 맥박 (전투 효과음을 가리지 않게 낮고 조용하다)
## 합성은 작업 스레드에서 하고(시작 때 멈춤 없음), 끝나면 서서히 켠다. 켜고 끄기는 허브 설정 메뉴 [배경음] (GameSave 에 저장).
class_name Ambience
extends Node

const RATE := 22050
const LOOP := 16.0
const VOL_DB := {"hub": -17.0, "dive": -21.0}

static var _cache := {}            # kind -> AudioStreamWAV

var kind := "hub"
var _player: AudioStreamPlayer
var _task := -1
var _fade: Tween


func _init(kind_ := "hub") -> void:
	kind = kind_


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.volume_db = -60.0
	add_child(_player)
	if not GameSave.ambience_on():
		return
	if _cache.has(kind):
		_start()
	else:
		_task = WorkerThreadPool.add_task(_build.bind(kind))
		set_process(true)
		return
	set_process(false)


func _process(_dt: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		set_process(false)
		if GameSave.ambience_on():
			_start()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _start() -> void:
	_player.stream = _cache[kind]
	_player.play()
	fade_to(float(VOL_DB.get(kind, -18.0)), 2.0)


func fade_to(db: float, sec: float) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween().set_ignore_time_scale()
	_fade.tween_property(_player, "volume_db", db, sec)


func fade_out(sec := 0.6) -> void:
	fade_to(-60.0, sec)


func set_on(on: bool) -> void:
	GameSave.set_ambience_on(on)
	if on:
		if _cache.has(kind):
			_start()
		elif _task < 0:
			_task = WorkerThreadPool.add_task(_build.bind(kind))
			set_process(true)
	else:
		fade_out(0.4)


func is_on() -> bool:
	return GameSave.ambience_on()


## 1/16 Hz 격자에 맞춘 주파수 (루프가 정확히 이어지게).
static func _q(f: float) -> float:
	return roundf(f * LOOP) / LOOP


static func _build(k: String) -> void:
	var n := int(LOOP * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	# 패드: [주파수, 세기, 떨림 Hz, 떨림 위상]
	var voices := []
	var bells := []    # [시작 초, 주파수, 세기]
	if k == "hub":
		voices = [[_q(110.0), 0.2, 0.0625, 0.0], [_q(110.4), 0.14, 0.125, 1.0], [_q(164.81), 0.15, 0.125, 2.1],
			[_q(220.0), 0.1, 0.1875, 0.7], [_q(277.18), 0.1, 0.0625, 3.0], [_q(329.63), 0.06, 0.25, 1.6]]
		bells = [[1.5, 659.25, 0.07], [4.0, 554.37, 0.06], [6.5, 880.0, 0.05], [9.5, 739.99, 0.06], [12.0, 659.25, 0.05], [13.5, 987.77, 0.035]]
	else:
		voices = [[_q(55.0), 0.26, 0.0625, 0.0], [_q(55.3), 0.18, 0.125, 1.3], [_q(82.41), 0.14, 0.1875, 2.0],
			[_q(110.0), 0.1, 0.5, 0.4], [_q(130.81), 0.07, 0.0625, 2.6]]
		bells = [[3.0, 329.63, 0.03], [11.0, 293.66, 0.03]]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for vc in voices:
			var trem := 0.72 + 0.28 * sin(TAU * float(vc[2]) * t + float(vc[3]))
			v += sin(TAU * float(vc[0]) * t) * float(vc[1]) * trem
		for b in bells:
			var bt := t - float(b[0])
			if bt >= 0.0 and bt < 2.4:
				var env := minf(bt * 60.0, 1.0) * exp(-bt * 2.6)
				v += (sin(TAU * float(b[1]) * bt) + 0.35 * sin(TAU * float(b[1]) * 2.0 * bt)) * float(b[2]) * env
		if k != "hub":
			v *= 0.86 + 0.14 * sin(TAU * 1.0 * t)   # 느린 맥박 (1 Hz: 루프 격자의 배수)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	_cache[k] = s
