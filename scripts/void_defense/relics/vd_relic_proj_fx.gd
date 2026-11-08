## 유물 투사체 연출(VDRelicFx) 조절값. VDSummonFx · vd_super_cutin_fx.gd · vd_card_flame_fx.gd 와 같은 모양(PARAMS · g · save …)이라
## 연출 연구실이 그대로 다룬다. 연구실에서 바꾸고 저장하면 user://relic_proj_fx.json 에 남아 실제 전투에도 그대로 쓰인다.
## 키: 공통 값은 이름만, 종류별 값은 "종류.이름" (bolt 뇌운 조각 · comet 잉걸불 · frost 서리 결정 · feather 별 깃털 · essence 정수병).
## 연구실은 고른 종류의 값과 공통 값만 보여 준다 (visible_for). PARAMS 의 def 가 코드 기본값 — "값 복사" 로 받은 줄을 아래 표에 옮기면 기본값이 된다.
## class_name 없음: preload 해서 쓴다.
extends RefCounted

const SAVE_PATH := "user://relic_proj_fx.json"
const TRANS_NAMES := []          # 곡선 고르는 옵션 없음 (연구실 공용 인터페이스)
const KINDS := ["bolt", "comet", "frost", "feather", "essence"]
const KIND_NAMES := ["뇌운 조각 (번개)", "잉걸불 (불덩이)", "서리 결정 (얼음)", "별 깃털 (아군 보호)", "공허 정수병 (정수 회수)"]

## [키, 이름, 최소, 최대, 단계]
const COMMON := [
	["size_k",     "전체 크기 배율",            0.2, 2.0,   0.01],
	["step_fps",   "떨림·결 홀드 fps (카툰 투스)", 4.0, 60.0,  1.0],
	["burst_size", "착탄 버스트 크기(px)",      40.0, 600.0, 5.0],
	["burst_dur",  "착탄 버스트 길이(초)",      0.08, 1.5,   0.01],
	["word_k",     "만화 글자 크기 배율",       0.0, 2.5,   0.05],
	["word_hold",  "만화 글자 머무는 시간(초)",  0.0, 1.0,   0.01],
	["spark_k",    "반짝이 크기 배율",          0.0, 3.0,   0.05],
]
const COMMON_DEF := {"size_k": 0.7, "step_fps": 15.0, "burst_size": 270.0, "burst_dur": 0.42, "word_k": 1.0, "word_hold": 0.16, "spark_k": 1.0}

## 띠 모양 (relic_ribbon.gdshader uniform) — 종류마다 따로
const SHAPE := [
	["half_w",       "띠 반폭(px)",                 2.0, 80.0, 0.5],
	["head_round",   "머리 둥근 캡",                 0.0, 1.0,  0.01],
	["tail_pow",     "꼬리 가늘어짐 (작을수록 굵게)", 0.05, 3.0, 0.01],
	["edge_w",       "어두운 테두리 두께",           0.0, 0.6,  0.01],
	["core_w",       "코어 시작",                    0.0, 1.0,  0.01],
	["hot_w",        "핫 코어 시작",                 0.0, 1.0,  0.01],
	["hot_hdr",      "핫 코어 밝기(HDR)",            0.5, 3.0,  0.01],
	["distort",      "가장자리 일렁임",              0.0, 0.8,  0.01],
	["streak_amt",   "속도선 양",                    0.0, 1.0,  0.01],
	["streak_speed", "속도선 흐름 속도",             0.0, 15.0, 0.1],
]
## 비행 (bolt 는 따로: 충전·꽂힘·유지·침식)
const MOTION := [
	["flight",     "비행 시간(초)",                 0.05, 2.0,  0.01],
	["after",      "착탄 뒤 남는 시간(초)",         0.05, 1.5,  0.01],
	["curve",      "곡선 휨 (거리 비율)",           0.0,  1.0,  0.01],
	["len_start",  "출발 꼬리 길이",                0.02, 1.0,  0.01],
	["len_end",    "다 자란 꼬리 길이",             0.02, 1.0,  0.01],
	["overshoot",  "착탄 뒤 더 흘러 나가는 양",     0.0,  1.0,  0.01],
	["erode_sec",  "착탄 뒤 침식 시간(초)",         0.02, 1.0,  0.01],
	["spark_rate", "비행 중 반짝이 빈도",           0.0,  1.0,  0.01],
]
const BOLT := [
	["charge",  "충전 (슬롯 반짝)(초)",     0.0, 0.6,  0.01],
	["strike",  "꽂히는 시간(초)",          0.01, 0.5, 0.01],
	["hold",    "떨며 유지(초)",            0.0, 1.0,  0.01],
	["erode",   "침식(초)",                 0.02, 1.0, 0.01],
	["curve",   "곡선 휨 (거리 비율)",      0.0, 1.0,  0.01],
	["zig",     "지그재그 꺾임(px)",        0.0, 120.0, 1.0],
	["jitter",  "잔떨림(px)",               0.0, 30.0, 0.5],
	["kinks",   "큰 꺾임 수",               1.0, 12.0, 1.0],
]
const IMPACT := [
	["burst",   "버스트 배율",              0.0, 3.0,  0.01],
	["rays",    "버스트 광선 수",           0.0, 24.0, 1.0],
	["word",    "글자 크기",                0.0, 90.0, 1.0],
	["ring_n",  "착탄 반짝이 수",           0.0, 24.0, 1.0],
	["ring_r",  "착탄 반짝이 반경(px)",     0.0, 200.0, 1.0],
]
const EXTRA := {
	"frost": [["side_off", "옆 결정 띠 간격(px)", 0.0, 60.0, 0.5], ["side_w", "옆 결정 띠 굵기 비율", 0.0, 1.5, 0.01]],
	"feather": [["sway", "좌우 흔들림(px)", 0.0, 80.0, 0.5]],
	"essence": [["count", "띠 개수", 1.0, 8.0, 1.0], ["spread", "띠 퍼짐(px)", 0.0, 400.0, 5.0], ["stagger", "띠 시간차(초)", 0.0, 0.4, 0.01]],
}
## 종류별 기본값 (지금 연출 그대로)
const KIND_DEF := {
	"bolt": {"half_w": 27.0, "head_round": 0.08, "tail_pow": 0.25, "edge_w": 0.22, "core_w": 0.5, "hot_w": 0.8, "hot_hdr": 1.25, "distort": 0.05, "streak_amt": 0.2, "streak_speed": 6.0,
		"charge": 0.1, "strike": 0.06, "hold": 0.16, "erode": 0.18, "curve": 0.16, "zig": 34.0, "jitter": 5.0, "kinks": 5.0,
		"burst": 1.0, "rays": 9.0, "word": 40.0, "ring_n": 8.0, "ring_r": 60.0},
	"comet": {"half_w": 28.0, "head_round": 0.22, "tail_pow": 0.6, "edge_w": 0.16, "core_w": 0.42, "hot_w": 0.72, "hot_hdr": 1.15, "distort": 0.32, "streak_amt": 0.35, "streak_speed": 3.5,
		"flight": 0.46, "after": 0.39, "curve": 0.4, "len_start": 0.2, "len_end": 0.55, "overshoot": 0.3, "erode_sec": 0.3, "spark_rate": 0.25,
		"burst": 1.05, "rays": 11.0, "word": 36.0, "ring_n": 7.0, "ring_r": 55.0},
	"frost": {"half_w": 20.0, "head_round": 0.16, "tail_pow": 0.55, "edge_w": 0.16, "core_w": 0.42, "hot_w": 0.72, "hot_hdr": 1.15, "distort": 0.1, "streak_amt": 0.4, "streak_speed": 4.0,
		"flight": 0.38, "after": 0.42, "curve": 0.26, "len_start": 0.15, "len_end": 0.45, "overshoot": 0.25, "erode_sec": 0.25, "spark_rate": 0.35,
		"burst": 0.85, "rays": 6.0, "word": 32.0, "ring_n": 6.0, "ring_r": 50.0, "side_off": 12.0, "side_w": 0.4},
	"feather": {"half_w": 17.0, "head_round": 0.3, "tail_pow": 0.8, "edge_w": 0.16, "core_w": 0.42, "hot_w": 0.72, "hot_hdr": 1.15, "distort": 0.08, "streak_amt": 0.25, "streak_speed": 3.0,
		"flight": 0.62, "after": 0.38, "curve": 0.2, "len_start": 0.18, "len_end": 0.4, "overshoot": 0.2, "erode_sec": 0.3, "spark_rate": 0.45,
		"burst": 0.7, "rays": 8.0, "word": 30.0, "ring_n": 8.0, "ring_r": 46.0, "sway": 22.0},
	"essence": {"half_w": 9.0, "head_round": 0.25, "tail_pow": 0.9, "edge_w": 0.2, "core_w": 0.42, "hot_w": 0.72, "hot_hdr": 1.15, "distort": 0.05, "streak_amt": 0.3, "streak_speed": 3.0,
		"flight": 0.5, "after": 0.4, "curve": 0.0, "len_start": 0.15, "len_end": 0.35, "overshoot": 0.2, "erode_sec": 0.22, "spark_rate": 0.3,
		"burst": 0.0, "rays": 0.0, "word": 0.0, "ring_n": 6.0, "ring_r": 22.0, "count": 3.0, "spread": 140.0, "stagger": 0.07},
}

## [키, 그룹, 이름, 최소, 최대, 단계, 기본값] — 연구실 패널이 읽는 목록 (위 표에서 만든다)
static var PARAMS: Array = _build_params()

static var values := {}
static var _loaded := false


static func _build_params() -> Array:
	var out: Array = []
	for r in COMMON:
		out.append([r[0], "0 공통", r[1], r[2], r[3], r[4], COMMON_DEF[r[0]]])
	for i in KINDS.size():
		var kind: String = KINDS[i]
		var d: Dictionary = KIND_DEF[kind]
		var name: String = KIND_NAMES[i]
		var tables := [["1 비행", BOLT if kind == "bolt" else MOTION], ["2 띠 모양", SHAPE]]
		if kind != "essence":
			tables.append(["3 착탄", IMPACT])
		else:
			tables.append(["3 착탄", IMPACT.filter(func(r: Array) -> bool: return r[0] in ["ring_n", "ring_r"])])
		if EXTRA.has(kind):
			tables.append(["4 " + name.get_slice(" (", 0) + " 전용", EXTRA[kind]])
		for tb in tables:
			for r in tb[1]:
				if kind == "essence" and r[0] == "curve":
					continue        # 정수 띠는 제각각 휘는 퍼짐(spread)으로
				out.append([kind + "." + r[0], tb[0], r[1], r[2], r[3], r[4], d[r[0]]])
	return out


## 연구실: 이 종류를 다듬을 때 보여 줄 줄인가 (공통 + 그 종류).
static func visible_for(key: String, kind: String) -> bool:
	return not key.contains(".") or key.begins_with(kind + ".")


static func defaults() -> Dictionary:
	var d := {}
	for p in PARAMS:
		d[p[0]] = float(p[6])
	return d


static func g(key: String) -> float:
	if not _loaded:
		load_saved()
	return float(values.get(key, 0.0))


## 종류별 값: k("bolt", "zig") = g("bolt.zig")
static func k(kind: String, key: String) -> float:
	return g(kind + "." + key)


static func set_value(key: String, v: float) -> void:
	if not _loaded:
		load_saved()
	values[key] = v


static func load_saved() -> void:
	_loaded = true
	values = defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		for key in data:
			if values.has(key):
				values[key] = float(data[key])


static func save() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(values, "\t"))
	return true


static func reset() -> void:
	_loaded = true
	values = defaults()


## 기본값과 다른 값만 "키 = 값" 줄로
static func describe(all := false) -> String:
	var lines := PackedStringArray()
	for p in PARAMS:
		var v := g(p[0])
		if all or not is_equal_approx(v, float(p[6])):
			lines.append("%s = %s   # %s" % [p[0], str(snappedf(v, 0.001)), p[2]])
	return "\n".join(lines) if not lines.is_empty() else "(모두 기본값)"


## 착탄까지 · 전체 길이 (초)
static func timing(kind: String) -> Vector2:
	if kind == "bolt":
		var fl := k(kind, "charge") + k(kind, "strike")
		return Vector2(fl, fl + k(kind, "hold") + k(kind, "erode") + 0.08)
	var extra := k(kind, "stagger") * maxf(k(kind, "count") - 1.0, 0.0) if kind == "essence" else 0.0
	return Vector2(k(kind, "flight"), k(kind, "flight") + k(kind, "after") + extra)


## 연구실 머리줄
static func summary(kind := "bolt") -> String:
	var tm := timing(kind)
	return "착탄 %.2f초 · 전체 %.2f초  ·  크기 x%.2f  ·  버스트 %.0fpx / %.2f초" % [tm.x, tm.y, g("size_k"), g("burst_size"), g("burst_dur")]
