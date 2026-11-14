## 전투 필드 기본 엠비언트 (2026-11-13): 사이파이 앰비언스 루프 두 개를 겹쳐 계속 깐다.
## 파일 출처는 assets/audio/void_defense/SOURCES.md (Ultra Sci-Fi Game Audio Ambience Pack, Eric Berzins).
##   바탕(loop02): 고르게 깔리는 저음 드론 (원본 평균 -19.7dB, 초당 -21~-19dB)
##   너울(loop15): 부풀었다 가라앉는 초저역 너울 (원본 평균 -13.8dB, 초당 -19~-11dB). 에너지 대부분이 120Hz 아래라
##     귀에는 RMS 보다 26dB 작게 들린다(A 가중) → 숫자상 더 크게 둬야 두 층이 다 들린다.
## 두 루프 길이(20.2초 / 29.0초)가 달라 겹침이 계속 바뀌고, 층마다 느린 음량 흔들림(주기가 서로 다름)을 얹어 반복감을 줄인다.
## 밸런스(A 가중, 귀 기준): 바탕 -43.5dB · 너울 -50.8dB · 합 -42.7dB — 발소리(-41)·적 공격(-39)·명중(-26) 등 모든 효과음 아래.
## 실제 RMS 는 합 약 -24dB, 피크 -11.7dBFS 로 여유가 있다. 입장 때 서서히 켜진다.
class_name VDAmbience
extends Node

const DIR := "res://assets/audio/void_defense/ambience/"
## [파일, 기준 dB, 흔들림 폭 dB, 흔들림 주기 초]
const LAYERS := [
	["amb_scifi_loop02.wav", -12.0, 1.2, 41.0],   # 바탕 드론: RMS -31.7dB · A 가중 -43.5dB
	["amb_scifi_loop15.wav", -11.0, 1.8, 57.0],   # 너울: RMS -24.8dB · A 가중 -50.8dB (바탕보다 7dB 아래 밑울림)
]
const FADE_IN_SEC := 3.0
const SILENT_DB := -60.0

static var enabled := true

var players: Array[AudioStreamPlayer] = []
var _fade := 0.0          # 0..1 입장 페이드
var _t := 0.0
var _phases: Array[float] = []


func _ready() -> void:
	name = "Ambience"
	process_mode = Node.PROCESS_MODE_ALWAYS   # 궁극기 연출(트리 일시정지) 중에도 끊기지 않는다
	for layer in LAYERS:
		var stream: AudioStream = load(DIR + layer[0])
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = "Master"
		p.volume_db = SILENT_DB
		add_child(p)
		players.append(p)
		_phases.append(randf() * TAU)
		if enabled and stream:
			p.play(randf() * stream.get_length())   # 매번 다른 지점에서 시작해 두 층의 겹침이 달라진다


func toggle() -> void:
	enabled = not enabled
	for p in players:
		if enabled:
			p.play(randf() * p.stream.get_length())
		else:
			p.stop()
	_fade = 0.0


func is_on() -> bool:
	return enabled


## 층의 현재 목표 음량(dB): 기준 + 느린 사인 흔들림 + 입장 페이드.
func layer_db(i: int) -> float:
	var l: Array = LAYERS[i]
	var db: float = l[1] + l[2] * sin(_t * TAU / l[3] + _phases[i])
	if _fade >= 1.0:
		return db
	return lerpf(SILENT_DB, db, ease(_fade, 0.4))   # 앞쪽이 빨리 차오르는 곡선 (dB 선형 페이드는 끝이 확 커진다)


func _process(delta: float) -> void:
	if not enabled:
		return
	_t += delta
	_fade = minf(_fade + delta / FADE_IN_SEC, 1.0)
	for i in players.size():
		players[i].volume_db = layer_db(i)
