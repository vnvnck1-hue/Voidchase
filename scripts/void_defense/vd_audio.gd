## VOID DEFENSE 사운드: 효과음 풀. 파일 출처는 assets/audio/void_defense/SOURCES.md. (BGM 없음)
## 2026-11-06: 전투·UI 소리를 세명이 오리라(TrioChess) Sfx 로 바꿨다. 녹음 파일은 trio/ 에 복사, 합성음(whoosh·boom·rise·clash)은
## TrioChess sfx.gd 의 합성식을 그대로 옮겼다. 볼륨은 TrioChess 의 (호출 dB + 파일 레벨 보정 + SFX 버스 -1.5) 를 그대로 쓴다.
## 적 소환(enemy_spawn·boss_spawn)만 기존 파일.
class_name VDAudio
extends Node

const DIR := "res://assets/audio/void_defense/"
const POOL_SIZE := 14
## 같은 효과음이 이 간격(ms) 안에 다시 요청되면 건너뛴다 (적 여럿이 동시에 때릴 때 뭉개짐 방지).
const THROTTLE_MS := 45
const RATE := 22050

## 이름 -> [파일들 또는 "synth:이름"]. 여러 개면 랜덤 재생.
const SFX := {
	# 전투 (TrioChess combat.gd·skills.gd 에서 같은 순간에 쓰는 소리)
	"knight_attack": ["synth:whoosh"],                     # 근접 휘두르기
	"knight_hit": ["trio/sfx-mon_hit.wav"],                # 근접 명중 (thud)
	"gun": ["trio/sfx-bow_shot.wav"],                      # 원거리 발사
	"gun_hit": ["trio/sfx-arrow-hit-el-01.mp3"],
	"mage_cast": ["trio/sfx-bolt_cast.wav"],
	"mage_hit": ["trio/sfx-bolt_hit.wav"],
	"heal": ["trio/sfx-witch_heal.wav"],
	"enemy_attack": ["trio/sfx-mon_attack.wav"],
	"ally_hurt": ["trio/sfx-ally_hurt.wav"],
	"enemy_hit": ["trio/sfx-mon_hit.wav"],
	"enemy_die": ["trio/sfx-mon_die.wav"],
	"boss_die": ["trio/sfx-boss_die.wav"],
	"hero_down": ["trio/sfx-merc_die.wav"],
	"boss_slam": ["trio/sfx-boss_attack.wav"],
	"explode": ["trio/sfx-fireball_boom.wav"],
	"frost": ["trio/sfx-frost_burst.wav"],
	"lightning": ["trio/sfx-lightning_strike.wav"],
	"fizzle": ["trio/sfx-bolt_fizzle.wav"],
	"whoosh": ["synth:whoosh"],
	"boom": ["synth:boom"],
	"rise": ["synth:rise"],
	"clash": ["synth:clash"],
	# 흐름
	"wave_start": ["trio/sfx-wave_start.wav"],
	"wave_clear": ["trio/sfx-wave_clear.wav"],
	"victory": ["trio/sfx-victory.wav"],
	"defeat": ["trio/sfx-defeat.wav"],
	# 재화·UI
	"essence": ["trio/sfx-mon_drop.wav"],                  # 반짝 (sparkle)
	"tick": ["trio/sfx-qty_tick.wav"],                     # 정수가 바닥에 떨어짐·HUD 에 도착
	"chime": ["trio/sfx-toast_good.wav"],
	"pop": ["trio/sfx-stack_gain.wav"],
	"click": ["trio/sfx-btn_click.wav"],
	"denied": ["trio/sfx-btn_denied.wav"],
	"place": ["trio/sfx-stack_gain.wav"],
	# 적 소환은 기존 그대로 (요청: 제외)
	"enemy_spawn": ["enemy_spawn.wav"],
	"boss_spawn": ["boss_spawn.wav"],
	"boss_roar": ["boss_roar.wav"],                        # 강적(웨이브에서 가장 센 적) 등장 괴성 — 마녀산장 sfx-boss_roar.wav
	"slab_rise": ["slab_rise_01.wav", "slab_rise_02.wav", "slab_rise_03.wav", "slab_rise_04.wav"],   # 갈림길 석판 솟아오름 — ElevenLabs SFX, docs/sfx_slab_rise_v1
	"slab_rise_boss": ["slab_rise_boss.wav"],             # 다음 웨이브가 보스·대형 적일 때(VDData.is_hard_wave)
	"super_ult": ["super_ult_01.wav", "super_ult_02.wav", "super_ult_03.wav", "super_ult_04.wav",   # 초궁극기 컷인 맞물림 "파칭~!" — ElevenLabs SFX, docs/sfx_super_ult_v1
		"super_ult_05.wav", "super_ult_06.wav", "super_ult_07.wav", "super_ult_08.wav"],
	"step": ["step.wav"],                                  # 아군 발소리: 스테이지(방) 사이 이동 때 — 마녀산장 sfx-witch_step.wav
	# 캐릭터 추임새(voice()): _skill 은 액티브 스킬 시전 때(VDSkills.cast), _hurt 는 아군이 피해를 받을 때(VDBattle._apply_hit).
	# 건너: ElevenLabs Irohauta, 고른 기록 docs/voice_gunner_v1
	"voice_gunner_skill": ["voice/gunner_skill_01.wav", "voice/gunner_skill_02.wav", "voice/gunner_skill_03.wav", "voice/gunner_skill_04.wav",
		"voice/gunner_skill_05.wav", "voice/gunner_skill_06.wav", "voice/gunner_skill_07.wav", "voice/gunner_skill_08.wav"],
	"voice_gunner_hurt": ["voice/gunner_hurt_01.wav", "voice/gunner_hurt_02.wav", "voice/gunner_hurt_03.wav", "voice/gunner_hurt_04.wav",
		"voice/gunner_hurt_05.wav", "voice/gunner_hurt_06.wav", "voice/gunner_hurt_07.wav"],
	# 기사·마법사·힐러: 같은 날 승인(docs/voice_squad_v1, 기사 Lola·Aisyah / 마법사 Suzu·Ayame / 힐러 Koume·Kano)
	"voice_knight_skill": ["voice/knight_skill_01.wav", "voice/knight_skill_02.wav", "voice/knight_skill_03.wav", "voice/knight_skill_04.wav", "voice/knight_skill_05.wav", "voice/knight_skill_06.wav"],
	"voice_knight_hurt": ["voice/knight_hurt_01.wav", "voice/knight_hurt_02.wav", "voice/knight_hurt_03.wav", "voice/knight_hurt_04.wav", "voice/knight_hurt_05.wav", "voice/knight_hurt_06.wav", "voice/knight_hurt_07.wav", "voice/knight_hurt_08.wav", "voice/knight_hurt_09.wav"],
	"voice_mage_skill": ["voice/mage_skill_01.wav", "voice/mage_skill_02.wav", "voice/mage_skill_03.wav", "voice/mage_skill_04.wav", "voice/mage_skill_05.wav", "voice/mage_skill_06.wav", "voice/mage_skill_07.wav"],
	"voice_mage_hurt": ["voice/mage_hurt_01.wav", "voice/mage_hurt_02.wav", "voice/mage_hurt_03.wav", "voice/mage_hurt_04.wav", "voice/mage_hurt_05.wav", "voice/mage_hurt_06.wav", "voice/mage_hurt_07.wav"],
	"voice_healer_skill": ["voice/healer_skill_01.wav", "voice/healer_skill_02.wav", "voice/healer_skill_03.wav", "voice/healer_skill_04.wav", "voice/healer_skill_05.wav", "voice/healer_skill_06.wav", "voice/healer_skill_07.wav"],
	"voice_healer_hurt": ["voice/healer_hurt_01.wav", "voice/healer_hurt_02.wav", "voice/healer_hurt_03.wav", "voice/healer_hurt_04.wav", "voice/healer_hurt_05.wav", "voice/healer_hurt_06.wav", "voice/healer_hurt_07.wav", "voice/healer_hurt_08.wav", "voice/healer_hurt_09.wav"],
}
## 이름별 볼륨(dB). 없으면 DEFAULT_DB. TrioChess 기준값 (호출 dB + 파일 보정 - 1.5).
const VOLUME_DB := {
	"knight_attack": -12.0, "knight_hit": -1.0, "gun": -14.0, "gun_hit": -9.5, "mage_cast": -14.0, "mage_hit": -3.5,
	"heal": -4.5, "enemy_attack": -18.0, "ally_hurt": -9.5, "enemy_hit": -6.0, "enemy_die": -2.5, "boss_die": -6.5,
	"hero_down": -4.5, "boss_slam": 0.5, "explode": -7.5, "frost": -3.5, "lightning": -12.5, "fizzle": -4.0,
	"whoosh": -7.5, "boom": -3.5, "rise": -6.0, "clash": -9.5,
	"wave_start": -5.5, "wave_clear": -2.5, "victory": 0.5, "defeat": -8.0,
	"essence": -4.5, "tick": -2.5, "chime": 1.0, "pop": 3.0, "click": -3.0, "denied": -7.5, "place": 3.0,
	"enemy_spawn": -8.0, "boss_spawn": 0.0, "boss_roar": -1.0, "step": -14.0, "slab_rise": -6.0, "slab_rise_boss": -5.0, "super_ult": -2.0,   # step: 마녀산장 selected.json 값
	"voice_gunner_skill": -6.0, "voice_gunner_hurt": -7.0,
	"voice_knight_skill": -6.0, "voice_knight_hurt": -7.0, "voice_mage_skill": -6.0, "voice_mage_hurt": -7.0,
	"voice_healer_skill": -6.0, "voice_healer_hurt": -7.0,
}
## 피격 추임새는 맞을 때마다 나오면 시끄럽다: 같은 영웅은 이 시간(ms) 안에 다시 내지 않는다.
const HURT_VOICE_COOLDOWN_MS := 1200
const DEFAULT_DB := -5.0
## 녹음 파일은 피치를 크게 올리면 부서져 들린다: 요청 피치 변화 중 이 비율만 남긴다 (TrioChess FILES 의 keep).
const FILE_PITCH_KEEP := 0.4

static var _synth := {}     # 합성음은 세션당 한 번 만든다
var _streams := {}          # name -> Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_ms := {}          # name -> last play time
var enabled := true
var play_count := {}        # 테스트용: 이름별 재생 횟수


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 궁극기 연출(트리 일시정지) 중에도 소리가 난다
	if _synth.is_empty():
		_synthesize()
	for name in SFX:
		var arr: Array = []
		for f in SFX[name]:
			var s: AudioStream = _synth.get(f.substr(6)) if f.begins_with("synth:") else load(DIR + f)
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


## 효과음 재생. pitch_var 만큼 피치를 흔들어 반복감을 줄인다. pitch 는 기준 피치(TrioChess 호출의 피치 인자).
func play(name: String, pitch_var := 0.06, db_offset := 0.0, pitch := 1.0) -> void:
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
	var base := pitch if _is_synth(stream) else 1.0 + (pitch - 1.0) * FILE_PITCH_KEEP
	p.pitch_scale = maxf(0.05, base + randf_range(-pitch_var, pitch_var))
	p.play()


## 캐릭터 추임새 "voice_<hero_id>_<kind>" (kind: skill·hurt). 목소리가 없는 영웅은 조용히 건너뛴다.
func voice(hero_id: String, kind: String) -> void:
	var name := "voice_%s_%s" % [hero_id, kind]
	if kind == "hurt" and _last_ms.has(name) and Time.get_ticks_msec() - int(_last_ms[name]) < HURT_VOICE_COOLDOWN_MS:
		return
	play(name, 0.02)


static func _is_synth(s: AudioStream) -> bool:
	return _synth.values().has(s)


# ---------------------------------------------------------------- TrioChess sfx.gd 합성식

func _synthesize() -> void:
	_synth["whoosh"] = _make(0.2, func(t: float) -> float:
		var env := sin(PI * t / 0.2)
		return (randf() * 2.0 - 1.0) * env * 0.35)
	_synth["boom"] = _make(0.5, func(t: float) -> float:
		var f := 90.0 * exp(-t * 4.0) + 35.0
		return (sin(TAU * f * t) * 0.8 + (randf() * 2.0 - 1.0) * 0.5 * exp(-t * 9.0)) * exp(-t * 6.0))
	_synth["clash"] = _make(0.7, func(t: float) -> float:
		var f := 220.0 + 40.0 * sin(t * 30.0)
		return (sin(TAU * f * t) * 0.4 + sin(TAU * f * 1.5 * t) * 0.3 + (randf() * 2.0 - 1.0) * 0.3 * exp(-t * 10.0)) * exp(-t * 3.5))
	_synth["rise"] = _make(0.65, func(t: float) -> float:
		var f := 260.0 + 900.0 * t * t
		var env := minf(1.0, t * 5.0) * (1.0 - smoothstep(0.55, 0.65, t))
		return (sin(TAU * f * t) * 0.32 + sin(TAU * f * 2.01 * t) * 0.12 + (randf() * 2.0 - 1.0) * 0.12 * t) * env)


static func _make(dur: float, fn: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = clampf(fn.call(t), -1.0, 1.0)
		v *= minf(1.0, i / 40.0) * minf(1.0, (n - i) / 80.0)   # 클릭 방지 페이드
		data.encode_s16(i * 2, int(v * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
