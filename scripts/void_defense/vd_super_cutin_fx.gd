## 초궁극기 컷인(vd_super_cutin.gd) 조절값. VDSummonFx 와 같은 모양(PARAMS · g · save …)이라 연출 연구실이 그대로 다룬다.
## 연구실에서 바꾸고 저장하면 user://super_cutin_fx.json 에 남아 실제 전투 컷인에도 그대로 쓰인다.
## PARAMS 의 def 가 코드 기본값. 연구실의 "값 복사" 로 받은 줄을 여기 def 에 옮기면 기본값이 된다.
## class_name 없음: preload 해서 쓴다.
extends RefCounted

const SAVE_PATH := "user://super_cutin_fx.json"
const TRANS_NAMES := []          # 곡선 고르는 옵션 없음 (연구실 공용 인터페이스)

## [키, 그룹, 이름, 최소, 최대, 단계, 기본값]
const PARAMS := [
	["impact",         "1 박자",   "맞물림 시각(초)",          0.04, 0.6,  0.01,  0.23],
	["glint",          "1 박자",   "눈 반짝·이름 시각(초)",    0.1,  1.2,  0.01,  0.39],
	["exit",           "1 박자",   "접히기 시작(초)",          0.4,  3.0,  0.01,  0.78],
	["close",          "1 박자",   "접히는 시간(초)",          0.03, 0.6,  0.01,  0.15],
	["band_dist",      "2 띠",     "띠 날아오는 거리(px)",     0.0,  4000.0, 50.0, 2600.0],
	["band_skew",      "2 띠",     "띠 기울기 스미어",         0.0,  1.5,  0.01,  0.67],
	["sliver_dist",    "2 띠",     "조각 띠 거리(px)",         0.0,  3000.0, 50.0, 1900.0],
	["squash",         "2 띠",     "맞물림 세로 찌그러짐",     1.0,  2.0,  0.01,  1.32],
	["squash_sec",     "2 띠",     "찌그러짐 복원(초)",        0.05, 1.2,  0.01,  0.38],
	["slide",          "3 캐릭터", "미끄러져 오는 거리(px)",   0.0,  1500.0, 10.0, 380.0],
	["smear_x",        "3 캐릭터", "가로 늘어짐",              0.5,  4.0,  0.05,  3.1],
	["smear_y",        "3 캐릭터", "세로 눌림",                0.2,  1.5,  0.01,  0.73],
	["arrive_sec",     "3 캐릭터", "도착 시간(초)",            0.05, 0.8,  0.01,  0.18],
	["silhouette_sec", "3 캐릭터", "흰 실루엣 빠짐(초)",       0.0,  0.6,  0.01,  0.24],
	["push_in",        "3 캐릭터", "천천히 줌인 배율",         0.9,  1.3,  0.005, 1.04],
	["rgb_split",      "3 캐릭터", "색수차 거리(px)",          0.0,  120.0, 1.0,  71.0],
	["rgb_alpha",      "3 캐릭터", "색수차 세기",              0.0,  1.0,  0.01,  0.83],
	["dim",            "4 타격",   "화면 어둡게",              0.0,  1.0,  0.01,  0.79],
	["flash",          "4 타격",   "화면 섬광",                0.0,  1.0,  0.01,  0.23],
	["flash_sec",      "4 타격",   "섬광 빠짐(초)",            0.0,  0.6,  0.01,  0.07],
	["window_flash",   "4 타격",   "창 흰 번쩍",               0.0,  1.0,  0.01,  0.89],
	["zoom_punch",     "4 타격",   "줌 펀치 배율",             1.0,  1.4,  0.005, 1.335],
	["zoom_sec",       "4 타격",   "줌 펀치 복원(초)",         0.03, 0.8,  0.01,  0.24],
	["shake",          "4 타격",   "흔들림(px)",               0.0,  80.0, 1.0,   15.0],
	["shake_decay",    "4 타격",   "흔들림 감쇠",              2.0,  40.0, 0.5,   14.0],
	["slash_alpha",    "4 타격",   "대각 섬광 남는 세기",      0.0,  1.0,  0.01,  0.75],
	["sparks",         "4 타격",   "튀는 별 조각 수",          0.0,  60.0, 1.0,   21.0],
	["sparkle_pop",    "5 반짝·글씨", "큰 별 팝 배율",         0.5,  3.0,  0.05,  0.95],
	["ring",           "5 반짝·글씨", "눈 고리 퍼짐",          0.0,  10.0, 0.1,   10.0],
	["title_scale",    "5 반짝·글씨", "이름 도장 시작 배율",   1.0,  5.0,  0.05,  1.3],
	["title_sec",      "5 반짝·글씨", "이름 도장 시간(초)",    0.03, 0.6,  0.01,  0.1],
	["title_kick",     "5 반짝·글씨", "도장 흔들림(px)",       0.0,  60.0, 1.0,   13.0],
	["speed_lines",    "6 창 안",  "속도선 간격(초, 작을수록 많이)", 0.005, 0.2, 0.001, 0.015],
	["drift",          "6 창 안",  "성운·먼지 흐름 배율",      0.0,  3.0,  0.05,  2.7],
	["line_sec",       "6 창 안",  "접힌 뒤 빛줄기(초)",       0.03, 0.8,  0.01,  0.18],
]

static var values := {}
static var _loaded := false


static func defaults() -> Dictionary:
	var d := {}
	for p in PARAMS:
		d[p[0]] = p[6]
	return d


static func g(key: String) -> float:
	if not _loaded:
		load_saved()
	return float(values.get(key, 0.0))


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


## 기본값과 다른 값만 "키 = 값" 줄로
static func describe(all := false) -> String:
	var lines := PackedStringArray()
	for p in PARAMS:
		var v := g(p[0])
		if all or not is_equal_approx(v, float(p[6])):
			lines.append("%s = %s   # %s" % [p[0], str(snappedf(v, 0.001)), p[2]])
	return "\n".join(lines) if not lines.is_empty() else "(모두 기본값)"


## 연구실 머리줄: 전체 길이와 박자
static func summary() -> String:
	return "총 길이 %.2f초  (맞물림 %.2f · 반짝 %.2f · 접힘 %.2f~%.2f)" % [duration(), g("impact"), g("glint"), g("exit"), duration()]


static func duration() -> float:
	return g("exit") + g("close")
