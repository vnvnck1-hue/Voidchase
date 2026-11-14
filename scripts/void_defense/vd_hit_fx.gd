## 몬스터 피격 파티클(VDTouchHit — 터치 게임 데모의 별 섬광 + 번개) 조절값. vd_card_flame_fx.gd 와 같은 모양(PARAMS · g · save …)이라
## 연출 연구실이 그대로 다룬다. 연구실에서 바꾸고 저장하면 user://hit_fx.json 에 남아 실제 전투에도 그대로 쓰인다.
## PARAMS 의 def 가 코드 기본값. 연구실의 "값 복사" 로 받은 줄을 여기 def 에 옮기면 기본값이 된다.
## class_name 없음: preload 해서 쓴다.
extends RefCounted

const SAVE_PATH := "user://hit_fx.json"
const TRANS_NAMES := []          # 곡선 고르는 옵션 없음 (연구실 공용 인터페이스)

## [키, 그룹, 이름, 최소, 최대, 단계, 기본값]
const PARAMS := [
	["size",       "1 크기",   "전체 크기 (1=데모 원본)",            0.05, 2.0, 0.01, 0.4],
	["heavy_size", "1 크기",   "강타 크기 배 (호출 배율 0.5 이상)",  0.5, 3.0,  0.01, 1.25],
	["speed",      "2 시간",   "재생 속도",                         0.2, 3.0,  0.01, 1.0],
	["emit_sec",   "2 시간",   "방출 시간(초) — 지나면 새로 안 나옴", 0.05, 2.0, 0.01, 0.6],
	["flash",      "3 구성",   "별 섬광 (0=끔, 1=켬)",              0.0, 1.0,  1.0,  1.0],
	["lightning",  "3 구성",   "번개 (0=끔, 1=강타만, 2=항상)",      0.0, 2.0,  1.0,  1.0],
	["digits",     "3 구성",   "데미지 숫자 파티클 (0=끔, 1=켬)",    0.0, 1.0,  1.0,  0.0],
	["tint_k",     "4 색",     "부른 쪽 색 섞기 (0=데모 색 그대로)", 0.0, 1.0,  0.01, 0.0],
	["alpha",      "4 색",     "불투명도",                          0.0, 1.0,  0.01, 1.0],
	["max_live",   "5 제한",   "동시에 살아 있는 최대 개수",          4.0, 64.0, 1.0,  24.0],
	# 몬스터 몸 반응 (VDUnit.hit_punch · 피격 섬광). 아군은 코드 기본값 그대로
	["punch_k",    "6 몸 반응", "찌그러짐 세기(배, 0=끔)",            0.0, 3.0,  0.01, 1.0],
	["punch_sx",   "6 몸 반응", "눌림: 가로 퍼짐",                    0.0, 1.0,  0.01, 0.42],
	["punch_sy",   "6 몸 반응", "눌림: 세로 눌림",                    0.0, 0.9,  0.01, 0.36],
	["punch_rx",   "6 몸 반응", "튀어 오름: 가로 좁아짐",             0.0, 0.9,  0.01, 0.2],
	["punch_ry",   "6 몸 반응", "튀어 오름: 세로 늘어남",             0.0, 1.0,  0.01, 0.3],
	["punch_wob",  "6 몸 반응", "한 번 더 출렁임",                    0.0, 0.5,  0.01, 0.09],
	["recoil_px",  "6 몸 반응", "뒤로 밀림(px)",                      0.0, 60.0, 0.5,  15.0],
	["punch_sec",  "6 몸 반응", "튀어 오르는 시간(초)",               0.01, 0.4, 0.01, 0.07],
	["settle_sec", "6 몸 반응", "제자리로 돌아오는 시간(초)",         0.02, 1.0, 0.01, 0.16],
	["white_k",    "6 몸 반응", "하얀 번쩍임 밝기 (0=끔)",            0.0, 2.0,  0.01, 1.0],
	["white_fade", "6 몸 반응", "번쩍임 사라지는 속도(/초)",          0.5, 20.0, 0.1,  5.0],
	# 아군이 몬스터를 때린 순간의 화면 (VDBattle._hit_feel: 보통 셰이크 0.32·히트스탑 0.03초, 기사 0.45·0.05초)
	["shake_k",    "7 화면",   "흔들림(배, 0=끔)",                   0.0, 3.0,  0.01, 1.0],
	["hitstop_k",  "7 화면",   "히트스탑 길이(배, 0=끔)",            0.0, 3.0,  0.01, 1.0],
	# 피격 색 (VDUnit._hit_tint): 맞는 순간 몬스터 실루엣을 순백으로 덮고(소환 화이트닝과 같은 셰이더), 속성 공격이면 곧 그 속성의 형광색으로 바뀌었다 빠진다.
	# 물리(기사·건너·적 공격)는 흰빛만. 몸이 하얀 정도는 위 "하얀 번쩍임 밝기"(white_k), 흰빛이 빠지는 속도는 white_fade
	["el_hold",    "8 피격 색", "속성 색 전 순백 시간(초)",           0.0, 0.3,  0.005, 0.05],
	["el_keep",    "8 피격 색", "속성 색 꽉 찬 채 유지(초)",          0.0, 0.5,  0.005, 0.1],
	["el_fade",    "8 피격 색", "속성 색 사라지는 속도(/초)",         0.5, 12.0, 0.1,  4.0],
	["el_shade",   "8 피격 색", "속성 색일 때 원화 명암 남기기",      0.0, 1.0,  0.01, 0.3],
	["tick_k",     "8 피격 색", "도트 피해(화상 등) 번쩍임 세기",     0.0, 1.0,  0.01, 0.5],
	["el_bolt_r",  "8 피격 색", "번개 R", 0.0, 2.0, 0.01, 1.0],
	["el_bolt_g",  "8 피격 색", "번개 G", 0.0, 2.0, 0.01, 1.0],
	["el_bolt_b",  "8 피격 색", "번개 B", 0.0, 2.0, 0.01, 0.12],
	["el_fire_r",  "8 피격 색", "화염 R", 0.0, 2.0, 0.01, 1.0],
	["el_fire_g",  "8 피격 색", "화염 G", 0.0, 2.0, 0.01, 0.4],
	["el_fire_b",  "8 피격 색", "화염 B", 0.0, 2.0, 0.01, 0.02],
	["el_frost_r", "8 피격 색", "서리 R", 0.0, 2.0, 0.01, 0.2],
	["el_frost_g", "8 피격 색", "서리 G", 0.0, 2.0, 0.01, 0.95],
	["el_frost_b", "8 피격 색", "서리 B", 0.0, 2.0, 0.01, 1.0],
	["el_arcane_r", "8 피격 색", "비전·정수 R", 0.0, 2.0, 0.01, 1.0],
	["el_arcane_g", "8 피격 색", "비전·정수 G", 0.0, 2.0, 0.01, 0.18],
	["el_arcane_b", "8 피격 색", "비전·정수 B", 0.0, 2.0, 0.01, 0.92],
]
## 공격 속성(유물 태그와 같은 이름) → 피격 색 키. "" (물리) 는 흰빛만
const ELEMENT_KEY := {"번개": "el_bolt", "화염": "el_fire", "서리": "el_frost", "정수": "el_arcane"}


## 속성의 피격 형광색. 모르는 속성·물리는 흰색
static func element_color(element: String) -> Color:
	var k: String = ELEMENT_KEY.get(element, "")
	if k == "":
		return Color.WHITE
	return Color(g(k + "_r"), g(k + "_g"), g(k + "_b"))

static var values := {}
static var version := 0
static var _loaded := false


static func defaults() -> Dictionary:
	var d := {}
	for p in PARAMS:
		d[p[0]] = float(p[6])
	return d


static func g(key: String) -> float:
	if not _loaded:
		load_saved()
	return float(values.get(key, 0.0))


static func set_value(key: String, v: float) -> void:
	if not _loaded:
		load_saved()
	values[key] = v
	version += 1


static func load_saved() -> void:
	_loaded = true
	values = defaults()
	version += 1
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		for k in data:
			if values.has(k):
				values[k] = float(data[k])


static func save() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(values, "\t"))
	return true


static func reset() -> void:
	_loaded = true
	values = defaults()
	version += 1


## 기본값과 다른 값만 "키 = 값" 줄로
static func describe(all := false) -> String:
	var lines := PackedStringArray()
	for p in PARAMS:
		var v := g(p[0])
		if all or not is_equal_approx(v, float(p[6])):
			lines.append("%s = %s   # %s" % [p[0], str(snappedf(v, 0.001)), p[2]])
	return "\n".join(lines) if not lines.is_empty() else "(모두 기본값)"


## 연구실 머리줄
static func summary() -> String:
	var lt: String = ["끔", "강타만", "항상"][clampi(int(g("lightning")), 0, 2)]
	return "크기 x%.2f (강타 x%.2f)  ·  속도 x%.2f  ·  번개 %s  ·  색 섞기 %.0f%%" % [g("size"), g("heavy_size"), g("speed"), lt, g("tint_k") * 100.0]
