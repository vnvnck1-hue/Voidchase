## 대사 옹알이 음성 (음성 파일 없이): 글자가 찍힐 때마다 그 글자의 모음에 맞는 짧은 음절 소리를 화자의 목소리 높이로 낸다.
## 실제 말은 아니지만 "누가 말하고 있다"는 느낌을 준다 (동물의 숲·언더테일 식). 2026-11-13 사용자 요청: 대사에 음성이 없어 어색함.
##   - 음절 = 성대 파형(배음 합) × 모음별 포먼트(F1·F2) 가중 × 짧은 엔벨로프. 화자·모음마다 한 번 합성해 캐시한다.
##   - 한글은 중성(모음)을 뽑아 ㅏ·ㅔ·ㅣ·ㅗ·ㅜ 다섯 갈래로, 그 밖의 글자는 코드로 고른다. 공백·문장부호는 쉰다.
##   - 문장 끝이 "?" 면 끝을 올리고, "." "…" 이면 내린다. 글자마다 높이가 조금씩 흔들린다.
## 쓰는 곳: StoryDialog (대화창) · VDBark (전투 말풍선). 설정 메뉴 [대사 음성] 으로 끈다 (GameSave).
class_name VoiceBabble
extends Node

const RATE := 22050
const SYL_SEC := 0.095
const MIN_GAP_MS := 62            # 음절 사이 최소 간격 (타자 속도가 빨라도 말소리가 뭉개지지 않게)
const POOL := 3
## 화자: f0 기본 음높이(Hz) · form 포먼트 배율(작은 몸집일수록 큼) · bright 높은 배음의 양 · breath 숨소리 · wob 높이 흔들림
const VOICES := {
	"chief": {"f0": 292.0, "form": 1.12, "bright": 0.8, "breath": 0.06, "wob": 0.07},
	"knight": {"f0": 330.0, "form": 1.14, "bright": 1.0, "breath": 0.04, "wob": 0.10},
	"gunner": {"f0": 372.0, "form": 1.2, "bright": 0.9, "breath": 0.05, "wob": 0.08},
	"mage": {"f0": 236.0, "form": 1.05, "bright": 0.5, "breath": 0.12, "wob": 0.035},
	"healer": {"f0": 348.0, "form": 1.16, "bright": 0.6, "breath": 0.14, "wob": 0.05},
	"client": {"f0": 270.0, "form": 1.08, "bright": 0.45, "breath": 0.16, "wob": 0.04},
	"boss": {"f0": 118.0, "form": 0.82, "bright": 1.2, "breath": 0.1, "wob": 0.05},
}
## 모음 포먼트 [F1, F2] (Hz)
const FORMANTS := {"a": [850.0, 1350.0], "e": [520.0, 1950.0], "i": [310.0, 2450.0], "o": [480.0, 880.0], "u": [340.0, 780.0]}
## 한글 중성 번호(0~20) → 모음 갈래
const JUNG := ["a", "e", "a", "e", "o", "e", "o", "e", "o", "a", "e", "e", "o", "u", "o", "e", "i", "u", "u", "i", "i"]

static var _cache := {}            # "who/vowel" -> AudioStreamWAV

var volume_db := -13.0
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## 글자 하나를 말한다. at = 문장 안 위치(0..1), ending = 문장의 마지막 문장부호 ("?" "!" "." …)
func say(who: String, ch: String, at := 0.5, ending := "") -> void:
	if ch == "" or not GameSave.voice_on() or not VOICES.has(who):
		return
	var v := vowel_of(ch)
	if v == "":
		return
	var now := Time.get_ticks_msec()
	if now - _last_ms < MIN_GAP_MS:
		return
	_last_ms = now
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _clip(who, v)
	# 억양: 문장 앞쪽이 조금 높고 뒤로 갈수록 내려가다, 물음표면 끝에서 올라간다
	var contour := 1.05 - 0.1 * at
	if at > 0.75:
		var k := (at - 0.75) / 0.25
		if ending == "?":
			contour += 0.22 * k
		elif ending == "!":
			contour += 0.08 * k
		else:
			contour -= 0.07 * k
	var wob := float(VOICES[who]["wob"])
	p.pitch_scale = clampf(contour * randf_range(1.0 - wob, 1.0 + wob), 0.5, 2.0)
	p.volume_db = volume_db
	p.play()


## 문장의 마지막 문장부호 (억양용).
static func ending_of(text: String) -> String:
	var t := text.strip_edges().trim_suffix("\"").trim_suffix("'").trim_suffix("」").strip_edges()
	return t.right(1) if t != "" else ""


## 글자 → 모음 갈래 ("" = 쉼).
static func vowel_of(ch: String) -> String:
	var c := ch.unicode_at(0)
	if c >= 0xAC00 and c <= 0xD7A3:
		return JUNG[((c - 0xAC00) / 28) % 21]
	if (c >= 0x30 and c <= 0x39) or (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A) or (c >= 0x3131 and c <= 0x318E):
		return ["a", "e", "i", "o", "u"][c % 5]
	return ""


static func _clip(who: String, vowel: String) -> AudioStreamWAV:
	var key := who + "/" + vowel
	if _cache.has(key):
		return _cache[key]
	var vd: Dictionary = VOICES[who]
	var f0 := float(vd["f0"])
	var form := float(vd["form"])
	var f1 := float(FORMANTS[vowel][0]) * form
	var f2 := float(FORMANTS[vowel][1]) * form
	var bright := float(vd["bright"])
	var breath := float(vd["breath"])
	# 배음 세기: 성대 파형의 기울기(1/h) × 포먼트 두 봉우리
	var amps := PackedFloat32Array()
	var h := 1
	while f0 * h < 4800.0:
		var f := f0 * h
		var g := exp(-pow((f - f1) / 170.0, 2.0)) + 0.75 * exp(-pow((f - f2) / 260.0, 2.0)) + 0.1 * bright * exp(-pow((f - 3200.0 * form) / 500.0, 2.0))
		amps.append((0.22 / h + g) / (1.0 + 0.15 * h / maxf(bright, 0.2)))
		h += 1
	var norm := 0.0
	for a in amps:
		norm += a
	var n := int(SYL_SEC * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var peak := 0.0
	var seed_v := float(hash(key) % 1000) * 0.01
	for i in n:
		var t := float(i) / RATE
		var k := float(i) / n
		# 음절 안에서 높이가 살짝 솟았다 내려온다 (말소리의 굴곡)
		var f := f0 * (1.0 + 0.045 * sin(PI * k))
		var v := 0.0
		for j in amps.size():
			v += sin(TAU * f * (j + 1) * t + seed_v * j) * amps[j]
		v /= norm
		var noise := sin(t * 9173.0 + sin(t * 3301.0) * 5.0) * breath     # 값이 매번 같은 가짜 잡음 (숨소리)
		var env := minf(k / 0.1, 1.0) * pow(1.0 - k, 1.4)
		buf[i] = (v + noise) * env
		peak = maxf(peak, absf(buf[i]))
	# 가장 큰 값이 0.6 이 되게 맞춘다 (잘려서 찌그러지지 않게, 화자·모음마다 크기가 고르게)
	var gain := 0.6 / maxf(peak, 0.001)
	for i in n:
		data.encode_s16(i * 2, int(buf[i] * gain * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	_cache[key] = s
	return s


## 화자의 다섯 모음을 미리 만들어 둔다 (첫 글자에서 멈칫하지 않게).
static func warm(who: String) -> void:
	if VOICES.has(who):
		for v in FORMANTS:
			_clip(who, v)
