## VOID DEFENSE 사운드: 효과음 풀. 파일 출처는 assets/audio/void_defense/SOURCES.md. (BGM 없음)
class_name VDAudio
extends Node

const DIR := "res://assets/audio/void_defense/"
const POOL_SIZE := 14
## 같은 효과음이 이 간격(ms) 안에 다시 요청되면 건너뛴다 (적 여럿이 동시에 때릴 때 뭉개짐 방지).
const THROTTLE_MS := 45

## 이름 -> [파일들]. 여러 개면 랜덤 재생.
const SFX := {
	"knight_attack": ["knight_attack.wav"],
	"knight_hit": ["knight_hit.wav"],
	"gun": ["gun_01.wav", "gun_02.wav", "gun_03.wav"],
	"gun_hit": ["gun_hit.wav"],
	"mage_cast": ["mage_cast.wav"],
	"mage_hit": ["mage_hit.wav"],
	"heal": ["heal.wav"],
	"enemy_attack": ["enemy_attack.wav"],
	"ally_hurt": ["ally_hurt.wav"],
	"enemy_hit": ["enemy_hit.wav"],
	"enemy_die": ["enemy_die.wav"],
	"enemy_spawn": ["enemy_spawn.wav"],
	"boss_spawn": ["boss_spawn.wav"],
	"hero_down": ["hero_down.wav"],
	"wave_start": ["wave_start.wav"],
	"wave_clear": ["wave_clear.wav"],
	"defeat": ["defeat.wav"],
	"essence": ["essence.wav"],
	"click": ["click.wav"],
	"place": ["place.wav"],
}
## 이름별 볼륨(dB). 없으면 DEFAULT_DB.
const VOLUME_DB := {
	"gun": -10.0, "gun_hit": -8.0, "knight_hit": -6.0, "mage_hit": -6.0,
	"enemy_attack": -8.0, "ally_hurt": -6.0, "enemy_hit": -9.0, "enemy_spawn": -8.0,
	"essence": -8.0, "click": -4.0, "place": -6.0, "heal": -4.0,
	"wave_start": -2.0, "wave_clear": -2.0, "boss_spawn": 0.0, "defeat": 0.0, "hero_down": -2.0,
}
const DEFAULT_DB := -5.0

var _streams := {}          # name -> Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_ms := {}          # name -> last play time
var enabled := true
var play_count := {}        # 테스트용: 이름별 재생 횟수


func _ready() -> void:
	for name in SFX:
		var arr: Array = []
		for f in SFX[name]:
			var s := load(DIR + f)
			if s:
				arr.append(s)
			else:
				push_warning("[VDAudio] missing " + DIR + f)
		_streams[name] = arr
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


## 효과음 재생. pitch_var 만큼 피치를 흔들어 반복감을 줄인다.
func play(name: String, pitch_var := 0.06, db_offset := 0.0) -> void:
	if not enabled or not _streams.has(name) or _streams[name].is_empty():
		return
	var now := Time.get_ticks_msec()
	if _last_ms.has(name) and now - int(_last_ms[name]) < THROTTLE_MS:
		return
	_last_ms[name] = now
	play_count[name] = int(play_count.get(name, 0)) + 1
	var arr: Array = _streams[name]
	var stream: AudioStream = arr[randi() % arr.size()]
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stop()
	p.stream = stream
	p.volume_db = float(VOLUME_DB.get(name, DEFAULT_DB)) + db_offset
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()
