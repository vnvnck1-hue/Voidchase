## 화면 전환(그래픽 와이프) 조절값. vd_kill_fx.gd 등과 같은 모양(PARAMS · g · set_value · save · load_saved · reset · describe · summary)이라
## 연출 연구실("화면 전환")이 그대로 다룬다. 연구실에서 바꾸고 저장하면 user://transition_fx.json 에 남아 실제 전환(scripts/screen_transition.gd)에도 그대로 쓰인다.
## 색은 vd_fx_colors.gd 방식(키_r/_g/_b 세 줄 → 연구실에서 컬러 피커 한 줄). 기본값 = 레퍼런스 "COLOR DROP #31" 팔레트(셰이더 기본값과 같다).
## 번개 닫힘 프리셋(scripts/screen_transition_lightning.gd)은 그림·색이 PSD 원본 그대로라 시간(lt_in_dur/lt_out_dur)만 조절한다. 기본값은 gif 실측.
## 프리셋(슬래시 스택 / 슬라이스 / 번개 닫힘)은 조절값이 아니라 설정 메뉴 [화면 전환] 에서 고른다 (연구실에서는 '대상' 으로 바꿔 본다).
## class_name 없음: preload 해서 쓴다.
extends RefCounted

const SAVE_PATH := "user://transition_fx.json"
const TRANS_NAMES := []          # 곡선 고르는 옵션 없음 (연구실 공용 인터페이스)
## [키, 그룹, 이름, 최소, 최대, 단계, 기본값]  (const 는 상수식이어야 해서 색 세 줄도 vd_card_flame_fx.gd 처럼 직접 적는다)
const PARAMS := [
	["in_dur",    "1 타이밍", "덮는 시간(초)",                 0.15, 1.5, 0.01, 0.43],
	["out_dur",   "1 타이밍", "걷히는 시간(초)",               0.15, 1.5, 0.01, 0.63],
	["lt_in_dur",  "1 타이밍", "번개 닫힘: 덮는 시간(초)",   0.15, 1.5, 0.01, 0.36],
	["lt_out_dur", "1 타이밍", "번개 닫힘: 되감아 여는 시간(초)", 0.15, 1.5, 0.01, 0.3],
	["dot_size",  "2 망점",   "하프톤 점 간격(px, 1080p 기준)", 4.0, 40.0, 0.5, 11.5],
	["plane1_r",  "3 색", "색판 1 (처음 들어오는 판) R",    0.0, 1.0, 0.01, 0.16],
	["plane1_g",  "3 색", "색판 1 (처음 들어오는 판) G",    0.0, 1.0, 0.01, 0.165],
	["plane1_b",  "3 색", "색판 1 (처음 들어오는 판) B",    0.0, 1.0, 0.01, 0.19],
	["plane2_r",  "3 색", "색판 2 (주 강조색) R",           0.0, 1.0, 0.01, 0.648],
	["plane2_g",  "3 색", "색판 2 (주 강조색) G",           0.0, 1.0, 0.01, 0.177],
	["plane2_b",  "3 색", "색판 2 (주 강조색) B",           0.0, 1.0, 0.01, 0.307],
	["plane3_r",  "3 색", "색판 3 R",                       0.0, 1.0, 0.01, 0.758],
	["plane3_g",  "3 색", "색판 3 G",                       0.0, 1.0, 0.01, 0.237],
	["plane3_b",  "3 색", "색판 3 B",                       0.0, 1.0, 0.01, 0.379],
	["plane4_r",  "3 색", "색판 4 (다 덮인 화면) R",        0.0, 1.0, 0.01, 0.176],
	["plane4_g",  "3 색", "색판 4 (다 덮인 화면) G",        0.0, 1.0, 0.01, 0.132],
	["plane4_b",  "3 색", "색판 4 (다 덮인 화면) B",        0.0, 1.0, 0.01, 0.145],
	["accent_r",  "3 색", "강조 A (망점·앞선·그라데이션) R", 0.0, 1.0, 0.01, 0.605],
	["accent_g",  "3 색", "강조 A (망점·앞선·그라데이션) G", 0.0, 1.0, 0.01, 0.284],
	["accent_b",  "3 색", "강조 A (망점·앞선·그라데이션) B", 0.0, 1.0, 0.01, 0.386],
	["accent2_r", "3 색", "강조 B (속도선·그라데이션) R",    0.0, 1.0, 0.01, 0.949],
	["accent2_g", "3 색", "강조 B (속도선·그라데이션) G",    0.0, 1.0, 0.01, 0.149],
	["accent2_b", "3 색", "강조 B (속도선·그라데이션) B",    0.0, 1.0, 0.01, 0.369],
	# 번개 일섬 (sk_) · 번개 재단 (ct_) · 둘의 공통 (zz_): scripts/screen_transition_strike.gd
	["sk_in_dur",  "1 타이밍", "덮는 시간(초)",                            0.15, 1.5, 0.01, 0.23],
	["sk_out_dur", "1 타이밍", "여는 시간(초)",                            0.15, 1.5, 0.01, 0.46],
	["sk_lead",    "1 타이밍", "번개가 먼저 치는 구간 (덮기 중 비율)",     0.10, 0.50, 0.01, 0.26],
	["sk_clash",   "1 타이밍", "판이 맞물리는 때 (덮기 중 비율)",          0.45, 0.90, 0.01, 0.48],
	["sk_pull",    "1 타이밍", "닫히기 직전 움찔 물러나는 정도",           0.0, 0.30, 0.01, 0.02],
	["ct_in_dur",  "1 타이밍", "덮는 시간(초)",                            0.15, 1.5, 0.01, 0.23],
	["ct_out_dur", "1 타이밍", "여는 시간(초)",                            0.15, 1.5, 0.01, 0.45],
	["ct_clash",   "1 타이밍", "칼날 띠가 다 꽂히는 때 (덮기 중 비율)",    0.45, 0.90, 0.01, 0.68],
	["ct_cut",     "2 모양",   "베인 화면이 어긋나는 정도",                0.0, 3.0, 0.05, 1.0],
	["ct_band",    "2 모양",   "칼날 띠 굵기 (화면 높이 = 1)",             0.05, 0.30, 0.005, 0.118],
	["zz_flash",   "3 타격감", "섬광 세기",                                0.0, 2.0, 0.05, 0.35],
	["zz_shake",   "3 타격감", "충돌 흔들림",                              0.0, 3.0, 0.05, 1.9],
	["zz_split",   "3 타격감", "장면 색 갈라짐",                           0.0, 3.0, 0.05, 0.65],
	["zz_zig",     "3 타격감", "지그재그 번개 세기",                       0.0, 1.0, 0.05, 0.5],
	["zz_sparks",  "3 타격감", "파편 (0 = 끔)",                            0.0, 1.0, 0.05, 1.0],
	["zz_bolt_r",  "4 색", "번개 R",              0.0, 1.0, 0.01, 0.719],
	["zz_bolt_g",  "4 색", "번개 G",              0.0, 1.0, 0.01, 0.282],
	["zz_bolt_b",  "4 색", "번개 B",              0.0, 1.0, 0.01, 1.0],
	["zz_glow_r",  "4 색", "빛·뒤따르는 쐐기 R",  0.0, 1.0, 0.01, 0.56],
	["zz_glow_g",  "4 색", "빛·뒤따르는 쐐기 G",  0.0, 1.0, 0.01, 0.25],
	["zz_glow_b",  "4 색", "빛·뒤따르는 쐐기 B",  0.0, 1.0, 0.01, 1.0],
	["zz_plate_r", "4 색", "판 (움직일 때) R",    0.0, 1.0, 0.01, 0.184],
	["zz_plate_g", "4 색", "판 (움직일 때) G",    0.0, 1.0, 0.01, 0.051],
	["zz_plate_b", "4 색", "판 (움직일 때) B",    0.0, 1.0, 0.01, 0.443],
	["zz_dark_r",  "4 색", "다 덮인 화면 R",      0.0, 1.0, 0.01, 0.051],
	["zz_dark_g",  "4 색", "다 덮인 화면 G",      0.0, 1.0, 0.01, 0.039],
	["zz_dark_b",  "4 색", "다 덮인 화면 B",      0.0, 1.0, 0.01, 0.149],
]
## 프리셋별 덮기/걷기 시간 키 (프리셋 번호 = scripts/screen_transition.gd 의 PRESET_NAMES 순서)
const DUR_KEYS := [["in_dur", "out_dur"], ["in_dur", "out_dur"], ["lt_in_dur", "lt_out_dur"], ["sk_in_dur", "sk_out_dur"], ["ct_in_dur", "ct_out_dur"]]


## 연구실: 이 조절값이 그 프리셋에서 쓰이는가 (대상 프리셋의 줄만 보여 준다)
static func visible_for(key: String, preset: int) -> bool:
	if key.begins_with("sk_"):
		return preset == 3
	if key.begins_with("ct_"):
		return preset == 4
	if key.begins_with("zz_"):
		return preset >= 3
	if key.begins_with("lt_"):
		return preset == 2
	return preset <= 1
## 셰이더 uniform 으로 그대로 넘어가는 색 키
const COLOR_KEYS := ["plane1", "plane2", "plane3", "plane4", "accent", "accent2"]

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


static func col(base: String) -> Color:
	return Color(g(base + "_r"), g(base + "_g"), g(base + "_b"))


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
		for p in PARAMS:   # 범위 밖 값(손으로 고친 0초 등)은 슬라이더 범위로 자른다
			if data.has(p[0]):
				values[p[0]] = clampf(float(data[p[0]]), p[3], p[4])


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


## 연구실 머리줄 (preset = 연구실에서 고른 대상)
static func summary(preset := 0) -> String:
	var keys: Array = DUR_KEYS[clampi(preset, 0, DUR_KEYS.size() - 1)]
	var head := "덮기 %.2f초 · 걷기 %.2f초" % [g(keys[0]), g(keys[1])]
	if preset >= 3:
		return head + " · 섬광 %.2f · 흔들림 %.2f · 번개 #%s · 판 #%s" % [g("zz_flash"), g("zz_shake"), col("zz_bolt").to_html(false), col("zz_plate").to_html(false)]
	if preset == 2:
		return head + " · 원화 프레임 그대로"
	return head + " · 망점 %.1fpx · 색판 #%s #%s #%s #%s" % [g("dot_size"),
		col("plane1").to_html(false), col("plane2").to_html(false), col("plane3").to_html(false), col("plane4").to_html(false)]


## 셰이더 재질에 색·망점 값을 넣는다 (전환 러너가 만들 때와 값이 바뀔 때 부른다)
static func apply(mat: ShaderMaterial) -> void:
	for k in COLOR_KEYS:
		mat.set_shader_parameter("col_" + k, col(k))
	mat.set_shader_parameter("dot_size", g("dot_size"))
