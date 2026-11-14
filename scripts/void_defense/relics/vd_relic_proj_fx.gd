## 유물 투사체 연출(VDRelicFx) 조절값. VDSummonFx · vd_super_cutin_fx.gd · vd_card_flame_fx.gd 와 같은 모양(PARAMS · g · save …)이라
## 연출 연구실이 그대로 다룬다. 연구실에서 바꾸고 저장하면 user://relic_proj_fx.json 에 남아 실제 전투에도 그대로 쓰인다.
## 키: 공통 값은 이름만, 종류별 값은 "종류.이름" (bolt 뇌운 조각 · comet 잉걸불(궤적 불꽃 셰이더 + 옅은 꼬리 띠) · frost 서리 결정 · feather 별 깃털 · essence 정수병).
## 연구실은 고른 종류의 값과 공통 값만 보여 준다 (visible_for). PARAMS 의 def 가 코드 기본값 — "값 복사" 로 받은 줄을 아래 표에 옮기면 기본값이 된다.
## class_name 없음: preload 해서 쓴다.
extends RefCounted

const SAVE_PATH := "user://relic_proj_fx.json"
## 비행 이징 프리셋 (연구실 드롭다운). 0 = 종류별 기본 곡선 (뇌운 = 감속, 서리 = 살짝 감속, 나머지 = 부드럽게 가속→감속)
## [이름, Tween.TransitionType, Tween.EaseType] — 값은 Tween.interpolate_value 로 계산해 Godot 트윈 곡선과 똑같다
const EASE_PRESETS := [
	["기본 (종류별 곡선)", -1, -1],
	["Linear (일정)", Tween.TRANS_LINEAR, Tween.EASE_IN],
	["Sine In", Tween.TRANS_SINE, Tween.EASE_IN], ["Sine Out", Tween.TRANS_SINE, Tween.EASE_OUT], ["Sine In Out", Tween.TRANS_SINE, Tween.EASE_IN_OUT],
	["Quad In", Tween.TRANS_QUAD, Tween.EASE_IN], ["Quad Out", Tween.TRANS_QUAD, Tween.EASE_OUT], ["Quad In Out", Tween.TRANS_QUAD, Tween.EASE_IN_OUT],
	["Cubic In", Tween.TRANS_CUBIC, Tween.EASE_IN], ["Cubic Out", Tween.TRANS_CUBIC, Tween.EASE_OUT], ["Cubic In Out", Tween.TRANS_CUBIC, Tween.EASE_IN_OUT],
	["Quart In", Tween.TRANS_QUART, Tween.EASE_IN], ["Quart Out", Tween.TRANS_QUART, Tween.EASE_OUT], ["Quart In Out", Tween.TRANS_QUART, Tween.EASE_IN_OUT],
	["Quint In", Tween.TRANS_QUINT, Tween.EASE_IN], ["Quint Out", Tween.TRANS_QUINT, Tween.EASE_OUT], ["Quint In Out", Tween.TRANS_QUINT, Tween.EASE_IN_OUT],
	["Expo In", Tween.TRANS_EXPO, Tween.EASE_IN], ["Expo Out", Tween.TRANS_EXPO, Tween.EASE_OUT], ["Expo In Out", Tween.TRANS_EXPO, Tween.EASE_IN_OUT],
	["Circ In", Tween.TRANS_CIRC, Tween.EASE_IN], ["Circ Out", Tween.TRANS_CIRC, Tween.EASE_OUT], ["Circ In Out", Tween.TRANS_CIRC, Tween.EASE_IN_OUT],
	["Back In (뒤로 젖혔다)", Tween.TRANS_BACK, Tween.EASE_IN], ["Back Out (지나쳤다 돌아옴)", Tween.TRANS_BACK, Tween.EASE_OUT], ["Back In Out", Tween.TRANS_BACK, Tween.EASE_IN_OUT],
	["Elastic Out (출렁)", Tween.TRANS_ELASTIC, Tween.EASE_OUT], ["Bounce Out (통통)", Tween.TRANS_BOUNCE, Tween.EASE_OUT],
	["Spring Out (용수철)", Tween.TRANS_SPRING, Tween.EASE_OUT],
]
## 연구실 공용 인터페이스: 단계 0 인 줄은 이 이름들 중 고르는 드롭다운
static var TRANS_NAMES: Array = EASE_PRESETS.map(func(e: Array) -> String: return e[0])
const KINDS := ["bolt", "comet", "frost", "feather", "essence"]
const KIND_NAMES := ["뇌운 조각 (번개)", "잉걸불 (불덩이)", "서리 결정 (정지장 탄)", "별 깃털 (실드 패킷)", "공허 정수병 (정수 회수)"]

## [키, 이름, 최소, 최대, 단계]
const COMMON := [
	["size_k",     "전체 크기 배율",            0.2, 2.0,   0.01],
	["step_fps",   "떨림·결 홀드 fps (카툰 투스)", 4.0, 60.0,  1.0],
	["burst_size", "착탄 피격 크기 (270=보통)", 40.0, 600.0, 5.0],
	["burst_dur",  "착탄 피격 길이 (0.42=보통)", 0.08, 1.5, 0.01],
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
	["ease",       "비행 이징",                     0.0,  28.0, 0.0],   # 단계 0 = EASE_PRESETS 드롭다운 (최대 = 프리셋 수 - 1)
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
	["ease",    "꽂힘 이징",                0.0, 28.0, 0.0],
	["hold",    "떨며 유지(초)",            0.0, 1.0,  0.01],
	["erode",   "침식(초)",                 0.02, 1.0, 0.01],
	["curve",   "곡선 휨 (거리 비율)",      0.0, 1.0,  0.01],
	["zig",     "지그재그 꺾임(px)",        0.0, 120.0, 1.0],
	["jitter",  "잔떨림(px)",               0.0, 30.0, 0.5],
	["kinks",   "큰 꺾임 수",               1.0, 12.0, 1.0],
]
const IMPACT := [
	["burst",   "착탄 피격 배율 (0=끔)", 0.0, 3.0,  0.01],
	["heavy",   "강타 (1=더 크게 + 번개)", 0.0, 1.0, 1.0],
	["word",    "글자 크기",                0.0, 90.0, 1.0],
	["ring_n",  "착탄 반짝이 수",           0.0, 24.0, 1.0],
	["ring_r",  "착탄 반짝이 반경(px)",     0.0, 200.0, 1.0],
]
const EXTRA := {
	"comet": [["flame_on", "궤적 불꽃 셰이더 (0=끔: 꼬리 띠만)", 0.0, 1.0, 1.0], ["flame_size", "불꽃 크기(px, 불덩이 지름 ≈ 0.6배)", 40.0, 400.0, 1.0], ["flame_len", "꼬리 불꽃 길이 (×3 반지름)", 0.3, 4.0, 0.01], ["speed_stretch", "빠를수록 늘어남", 0.0, 2.0, 0.01],
		["trail", "꼬리 띠 불투명도", 0.0, 1.0, 0.01], ["burn_out", "착탄 뒤 침식 세기", 1.0, 6.0, 0.05], ["splat", "착탄 뒤 퍼짐 배율", 1.0, 3.0, 0.01], ["flame_core", "흰 코어 문턱 (클수록 작게)", 0.0, 0.9, 0.01],
		["flame_wave", "꼬리 물결 (일렁임)", 0.0, 2.0, 0.01], ["flame_flow", "불꽃 결 흐름 속도", 0.0, 4.0, 0.01],
		["shade_w", "뒤 어두운 글로우 번짐 (반지름 배)", 0.0, 3.0, 0.01], ["shade_a", "뒤 어두운 글로우 진하기", 0.0, 1.0, 0.01],
		["shade_flick", "뒤 어두운 글로우 일렁임", 0.0, 2.0, 0.01], ["shade_len", "뒤 어두운 글로우 꼬리 길이 배", 0.5, 3.0, 0.01],
		["light_i", "에디티브 글로우 라이팅 세기 (0=끔)", 0.0, 4.0, 0.01], ["light_w", "에디티브 글로우 퍼짐 (반지름 배)", 0.0, 4.0, 0.01], ["light_flick", "에디티브 글로우 깜빡임", 0.0, 2.0, 0.01],
		["col_pow", "색 바뀜 곡선 (작을수록 일찍 착탄 색)", 0.2, 4.0, 0.01]],
	"frost": [["side_off", "옆 결정 띠 간격(px)", 0.0, 60.0, 0.5], ["side_w", "옆 결정 띠 굵기 비율", 0.0, 1.5, 0.01]],
	"feather": [["sway", "좌우 흔들림(px)", 0.0, 80.0, 0.5]],
	"essence": [["count", "띠 개수", 1.0, 8.0, 1.0], ["spread", "띠 퍼짐(px)", 0.0, 400.0, 5.0], ["stagger", "띠 시간차(초)", 0.0, 0.4, 0.01]],
}

const FxColors := preload("res://scripts/void_defense/vd_fx_colors.gd")
## 색 (연구실에선 컬러 피커 한 줄 = "키_r/_g/_b" 세 값). [키, 이름, 기본 색]
const COMMON_COLORS := [["word_ink", "만화 글자 외곽선", Color(0.08, 0.02, 0.14)]]
## 종류별: 띠 4톤(테두리 → 몸통 → 코어 → 핫), 착탄 피격 색(몬스터 피격 tint_k 만큼 섞임), 만화 글자, 비행 중 반짝이, 착탄 반짝이
const KIND_COLORS := {
	"bolt": [["col_edge", "띠 테두리", Color(0.42, 0.06, 0.55)], ["col_body", "띠 몸통", Color(0.95, 0.25, 0.8)], ["col_core", "띠 코어", Color(1.0, 0.88, 0.35)],
		["col_hot", "띠 핫 코어", Color(0.8, 1.0, 1.0)], ["col_spike", "착탄 피격 색", Color(0.98, 0.35, 0.8)], ["col_word", "만화 글자", Color(0.45, 1.0, 0.35)],
		["col_spark", "충전 반짝이", Color(1.0, 0.95, 0.7)], ["col_ring", "착탄 반짝이", Color(1.0, 1.0, 1.0)]],
	"comet": [["col_edge", "꼬리 띠 테두리", Color(0.62, 0.1, 0.05)], ["col_body", "꼬리 띠 몸통", Color(1.0, 0.45, 0.08)], ["col_core", "꼬리 띠 코어", Color(1.0, 0.82, 0.3)],
		["col_hot", "꼬리 띠 핫 코어", Color(1.0, 0.98, 0.8)], ["col_spike", "착탄 피격 색", Color(1.0, 0.5, 0.12)], ["col_word", "만화 글자", Color(1.0, 0.6, 0.2)],
		["col_spark", "비행 반짝이", Color(1.0, 0.82, 0.3)], ["col_ring", "착탄 반짝이", Color(1.0, 0.9, 0.5)]],
	"frost": [["col_edge", "띠 테두리", Color(0.0, 0.22, 0.3)], ["col_body", "띠 몸통", Color(0.08, 0.78, 0.86)], ["col_core", "띠 코어", Color(0.6, 1.0, 0.98)],
		["col_hot", "띠 핫 코어", Color(0.95, 1.0, 1.0)], ["col_spike", "착탄 피격 색", Color(0.2, 0.9, 0.95)], ["col_word", "만화 글자", Color(0.45, 1.0, 0.95)],
		["col_spark", "비행 반짝이", Color(0.8, 1.0, 1.0)], ["col_ring", "착탄 반짝이", Color(0.75, 1.0, 1.0)]],
	"feather": [["col_edge", "띠 테두리", Color(0.03, 0.3, 0.25)], ["col_body", "띠 몸통", Color(0.3, 0.95, 0.7)], ["col_core", "띠 코어", Color(0.8, 1.0, 0.92)],
		["col_hot", "띠 핫 코어", Color(1.0, 1.0, 1.0)], ["col_spike", "착탄 피격 색", Color(0.4, 1.0, 0.8)], ["col_word", "만화 글자", Color(0.5, 1.0, 0.8)],
		["col_spark", "비행 반짝이", Color(0.8, 1.0, 0.92)], ["col_ring", "착탄 반짝이", Color(0.85, 1.0, 0.95)]],
	"essence": [["col_edge", "띠 테두리", Color(0.3, 0.08, 0.5)], ["col_body", "띠 몸통", Color(0.65, 0.35, 0.95)], ["col_core", "띠 코어", Color(0.85, 0.65, 1.0)],
		["col_hot", "띠 핫 코어", Color(1.0, 0.95, 1.0)], ["col_spike", "착탄 피격 색", Color(0.7, 0.4, 1.0)], ["col_word", "만화 글자", Color(0.9, 0.8, 1.0)],
		["col_spark", "비행 반짝이", Color(0.85, 0.65, 1.0)], ["col_ring", "착탄 반짝이", Color(1.0, 0.95, 1.0)]],
}
## 잉걸불 불꽃(flame_trail 셰이더): 머리 → 가운데 → 꼬리 그라데이션 + 흰 코어 + 후광을 '출발' 과 '착탄' 두 벌로 두고
## 비행 동안 출발 → 착탄 색으로 바뀐다 (col_pow 곡선). 뒤에 깔리는 어두운 글로우 색은 한 벌, 에디티브 글로우 라이팅(HDR)도 출발 → 착탄.
const COMET_FLAME_COLORS := [
	["fl_head_a", "머리 (출발)", Color(1.0, 0.78, 0.25)], ["fl_mid_a", "가운데 (출발)", Color(1.0, 0.45, 0.1)], ["fl_tail_a", "꼬리 (출발)", Color(1.0, 0.25, 0.05)],
	["fl_core_a", "흰 코어 (출발)", Color(1.0, 1.0, 0.85)], ["fl_glow_a", "후광 (출발)", Color(1.0, 0.3, 0.05)],
	["fl_head_b", "머리 (착탄)", Color(1.0, 0.95, 0.6)], ["fl_mid_b", "가운데 (착탄)", Color(1.0, 0.38, 0.08)], ["fl_tail_b", "꼬리 (착탄)", Color(0.75, 0.1, 0.12)],
	["fl_core_b", "흰 코어 (착탄)", Color(1.0, 1.0, 0.95)], ["fl_glow_b", "후광 (착탄)", Color(0.9, 0.15, 0.05)],
	["fl_shade", "뒤 어두운 글로우", Color(0.14, 0.02, 0.05)],
	["fl_light_a", "에디티브 글로우 라이팅 (출발)", Color(1.0, 0.45, 0.12), 2.0], ["fl_light_b", "에디티브 글로우 라이팅 (착탄)", Color(1.0, 0.3, 0.08), 2.0],
]
## 종류별 기본값 (지금 연출 그대로)
const KIND_DEF := {
	"bolt": {"half_w": 27.0, "head_round": 0.08, "tail_pow": 0.25, "edge_w": 0.22, "core_w": 0.5, "hot_w": 0.8, "hot_hdr": 1.25, "distort": 0.05, "streak_amt": 0.2, "streak_speed": 6.0,
		"charge": 0.1, "strike": 0.06, "hold": 0.16, "erode": 0.18, "curve": 0.16, "zig": 34.0, "jitter": 5.0, "kinks": 5.0,
		"burst": 1.0, "heavy": 1.0, "word": 40.0, "ring_n": 8.0, "ring_r": 60.0},
	"comet": {"half_w": 28.0, "head_round": 0.22, "tail_pow": 0.6, "edge_w": 0.16, "core_w": 0.42, "hot_w": 0.72, "hot_hdr": 1.15, "distort": 0.32, "streak_amt": 0.35, "streak_speed": 3.5,
		"flight": 0.46, "after": 0.39, "curve": 0.4, "len_start": 0.2, "len_end": 0.55, "overshoot": 0.3, "erode_sec": 0.3, "spark_rate": 0.25,
		"burst": 1.05, "heavy": 1.0, "word": 36.0, "ring_n": 7.0, "ring_r": 55.0,
		"flame_on": 1.0, "flame_size": 240.0, "flame_len": 1.9, "speed_stretch": 0.4, "trail": 0.2, "burn_out": 3.2, "splat": 1.5, "flame_core": 0.45,
		"flame_wave": 0.8, "flame_flow": 1.1, "shade_w": 1.2, "shade_a": 0.65, "shade_flick": 1.0, "shade_len": 1.25,
		"light_i": 0.6, "light_w": 1.6, "light_flick": 0.6, "col_pow": 1.0},
	"frost": {"half_w": 18.0, "head_round": 0.3, "tail_pow": 0.45, "edge_w": 0.16, "core_w": 0.42, "hot_w": 0.72, "hot_hdr": 1.2, "distort": 0.03, "streak_amt": 0.4, "streak_speed": 4.0,
		"flight": 0.38, "after": 0.42, "curve": 0.26, "len_start": 0.15, "len_end": 0.45, "overshoot": 0.25, "erode_sec": 0.25, "spark_rate": 0.35,
		"burst": 0.85, "heavy": 0.0, "word": 32.0, "ring_n": 8.0, "ring_r": 50.0, "side_off": 12.0, "side_w": 0.4},
	"feather": {"half_w": 15.0, "head_round": 0.45, "tail_pow": 0.5, "edge_w": 0.16, "core_w": 0.42, "hot_w": 0.72, "hot_hdr": 1.2, "distort": 0.02, "streak_amt": 0.25, "streak_speed": 3.0,
		"flight": 0.62, "after": 0.38, "curve": 0.2, "len_start": 0.18, "len_end": 0.4, "overshoot": 0.2, "erode_sec": 0.3, "spark_rate": 0.45,
		"burst": 0.7, "heavy": 0.0, "word": 30.0, "ring_n": 8.0, "ring_r": 46.0, "sway": 0.0},
	"essence": {"half_w": 9.0, "head_round": 0.25, "tail_pow": 0.9, "edge_w": 0.2, "core_w": 0.42, "hot_w": 0.72, "hot_hdr": 1.15, "distort": 0.05, "streak_amt": 0.3, "streak_speed": 3.0,
		"flight": 0.5, "after": 0.4, "curve": 0.0, "len_start": 0.15, "len_end": 0.35, "overshoot": 0.2, "erode_sec": 0.22, "spark_rate": 0.3,
		"burst": 0.0, "heavy": 0.0, "word": 0.0, "ring_n": 6.0, "ring_r": 22.0, "count": 3.0, "spread": 140.0, "stagger": 0.07},
}

## [키, 그룹, 이름, 최소, 최대, 단계, 기본값] — 연구실 패널이 읽는 목록 (위 표에서 만든다)
static var PARAMS: Array = _build_params()

## 2026-11-10: 잉걸불은 사용자 요청으로 예전 불덩이로 되돌려 저장값을 다시 살린다 (RESTYLED_KINDS 에서 뺌).
## 2026-11-09 사이파이 리스타일: 이보다 낮은 _style 로 저장된 파일에서는 서리 결정·별 깃털의 색·띠 모양·전용 값을 버리고
## 새 기본값을 쓴다 (비행 시간·글자 크기 같은 튜닝은 그대로 살린다).
const STYLE := 2
const RESTYLED_KINDS := ["frost", "feather"]

static var values := {}
static var _loaded := false


static func _build_params() -> Array:
	var out: Array = []
	for r in COMMON:
		out.append([r[0], "0 공통", r[1], r[2], r[3], r[4], COMMON_DEF[r[0]]])
	out += FxColors.rows("0 공통", COMMON_COLORS)
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
				out.append([kind + "." + r[0], tb[0], r[1], r[2], r[3], r[4], d.get(r[0], 0.0)])   # ease 는 0 = 기본 곡선
		out += FxColors.rows("5 색", KIND_COLORS[kind].map(func(c: Array) -> Array: return [kind + "." + c[0], c[1], c[2]]))
		if kind == "comet":
			out += FxColors.rows("6 불꽃 색 (머리 → 꼬리 · 출발 → 착탄)", COMET_FLAME_COLORS.map(func(c: Array) -> Array: return ["comet." + c[0]] + c.slice(1)))
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


## 색: c("comet", "col_body") = "comet.col_body_r/_g/_b". kind 가 "" 면 공통 색
static func c(kind: String, key: String, alpha := 1.0) -> Color:
	var base := key if kind == "" else kind + "." + key
	return Color(g(base + "_r"), g(base + "_g"), g(base + "_b"), alpha)


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
		var old_style := int(data.get("_style", 1)) < STYLE
		for key in data:
			if values.has(key) and not (old_style and _restyled(key)):
				values[key] = float(data[key])


## 리스타일 때 기본값으로 되돌린 키인가: 세 종류의 색(col_* · fl_*), 띠 모양(SHAPE), 전용 값(EXTRA), 서리 착탄 반짝이 수
static func _restyled(key: String) -> bool:
	var kind := key.get_slice(".", 0)
	if not key.contains(".") or not kind in RESTYLED_KINDS:
		return false
	var name := key.get_slice(".", 1)
	if name.begins_with("col_") or name.begins_with("fl_") or key == "frost.ring_n":
		return true
	for r in SHAPE + EXTRA.get(kind, []):
		if r[0] == name:
			return true
	return false


static func save() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	var out := values.duplicate()
	out["_style"] = STYLE
	f.store_string(JSON.stringify(out, "\t"))
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
			var shown: String = TRANS_NAMES[clampi(int(v), 0, TRANS_NAMES.size() - 1)] if p[5] == 0.0 else str(snappedf(v, 0.001))
			lines.append("%s = %s   # %s" % [p[0], shown, p[2]])
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
	return "착탄 %.2f초 · 전체 %.2f초  ·  크기 x%.2f  ·  착탄 피격 %.0f / %.2f초" % [tm.x, tm.y, g("size_k"), g("burst_size"), g("burst_dur")]


## 비행 이징 값: 프리셋 i (1 이상) 의 곡선에서 x(0..1) 자리. Back·Elastic 은 0..1 을 잠깐 넘는다 (지나쳤다 돌아옴)
static func ease_value(i: int, x: float) -> float:
	var e: Array = EASE_PRESETS[clampi(i, 1, EASE_PRESETS.size() - 1)]
	return float(Tween.interpolate_value(0.0, 1.0, clampf(x, 0.0, 1.0), 1.0, e[1], e[2]))


## 비행 진행 0..1 → 곡선 위 머리 자리. 프리셋 i 가 0 이면 종류별 기본 곡선 (VDRelicFx 와 연구실 곡선 미리보기가 같이 쓴다)
static func fly(kind: String, i: int, x: float) -> float:
	if i > 0:
		return ease_value(i, x)
	match kind:
		"bolt":
			return 1.0 - pow(1.0 - x, 2.0)   # 번개: 확 꽂히고 끝에서 감속
		"frost":
			return 1.0 - pow(1.0 - x, 1.3)
	return x * x * (3.0 - 2.0 * x)          # 잉걸불·깃털·정수: 부드럽게 가속 → 감속
