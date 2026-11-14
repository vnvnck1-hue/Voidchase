## 궁극기 준비 카드 오버차지(shaders/card_ult_flame.gdshader, 2026-11-09 황금 불꽃 → 사이파이 에너지 줄기) 조절값. VDSummonFx · vd_super_cutin_fx.gd 와 같은 모양(PARAMS · g · save …)이라
## 연출 연구실이 그대로 다룬다. 연구실에서 바꾸고 저장하면 user://card_flame_fx.json 에 남아 실제 전투 카드에도 그대로 쓰인다.
## PARAMS 의 def 가 코드 기본값(셰이더 uniform 기본값과 같게 둔다). 연구실의 "값 복사" 로 받은 줄을 여기 def 에 옮기면 기본값이 된다.
## 키는 셰이더 uniform 이름. 색은 "이름_r/_g/_b" 세 줄로 나눠 두고 apply() 가 Color 로 묶어 넣는다.
## class_name 없음: preload 해서 쓴다.
extends RefCounted

const SAVE_PATH := "user://card_flame_fx.json"
const TRANS_NAMES := []          # 곡선 고르는 옵션 없음 (연구실 공용 인터페이스)
const COLORS := ["hot_color", "gold_color", "edge_color"]

## [키, 그룹, 이름, 최소, 최대, 단계, 기본값]
const PARAMS := [
	["top_reach",      "1 에너지 줄기", "윗변 줄기 길이(px)",      0.0,  104.0, 0.5,  100.0],
	["side_reach",     "1 에너지 줄기", "옆변 줄기 길이(px)",      0.0,  104.0, 0.5,  34.0],
	["bottom_reach",   "1 에너지 줄기", "아랫변 줄기 길이(px)",    0.0,  104.0, 0.5,  10.0],
	["tongue_px",      "1 에너지 줄기", "줄기 간격(px)",      4.0,  80.0,  0.5,  22.0],
	["tongue_cut",     "1 에너지 줄기", "줄기 성김(클수록 짧게)",   0.0,  1.5,   0.01, 0.45],
	["rise_speed",     "1 에너지 줄기", "흐름 속도·박자",         0.0,  6.0,   0.01, 2.2],
	["flame_strength", "1 에너지 줄기", "줄기 밝기",               0.0,  3.0,   0.01, 1.8],
	["halo_strength",  "2 후광·테두리", "후광 밝기",            0.0,  2.0,   0.01, 0.55],
	["halo_px",        "2 후광·테두리", "후광 번짐(px)",        1.0,  60.0,  0.5,  13.0],
	["rim_strength",   "2 후광·테두리", "안쪽 테두리·스윕 밝기",     0.0,  3.0,   0.01, 1.25],
	["rim_px",         "2 후광·테두리", "안쪽 테두리 두께(px)", 0.0,  20.0,  0.1,  5.0],
	["ember_amount",   "3 픽셀",    "떠오르는 사각 픽셀 양",                  0.0,  1.0,   0.01, 0.6],
	["hot_color_r",    "4 색",      "가장 밝은 곳 R",           0.0,  1.0,   0.01, 0.9],
	["hot_color_g",    "4 색",      "가장 밝은 곳 G",           0.0,  1.0,   0.01, 1.0],
	["hot_color_b",    "4 색",      "가장 밝은 곳 B",           0.0,  1.0,   0.01, 1.0],
	["gold_color_r",   "4 색",      "본색 R",                   0.0,  1.0,   0.01, 0.3],
	["gold_color_g",   "4 색",      "본색 G",                   0.0,  1.0,   0.01, 0.85],
	["gold_color_b",   "4 색",      "본색 B",                   0.0,  1.0,   0.01, 1.0],
	["edge_color_r",   "4 색",      "끝 색 R",                  0.0,  1.0,   0.01, 0.72],
	["edge_color_g",   "4 색",      "끝 색 G",                  0.0,  1.0,   0.01, 0.35],
	["edge_color_b",   "4 색",      "끝 색 B",                  0.0,  1.0,   0.01, 1.0],
	["flare",          "5 켜짐",    "막 찼을 때 더 세게(배)",   0.0,  2.0,   0.01, 0.8],
	["flare_sec",      "5 켜짐",    "그 세게 타는 시간(초)",    0.05, 2.0,   0.01, 0.6],
	["fade_in",        "5 켜짐",    "켜지는 속도(/초)",         0.5,  20.0,  0.1,  4.0],
	["fade_out",       "5 켜짐",    "꺼지는 속도(/초)",         0.5,  20.0,  0.1,  2.5],
]
## 셰이더로 보내지 않는 값 (카드 쪽 켜짐·꺼짐 타이밍)
const LOCAL_KEYS := ["flare", "flare_sec", "fade_in", "fade_out"]

## 2026-11-09 사이파이 리스타일: 이보다 낮은 _style 로 저장된 파일에서는 RESTYLED 키(색)를 버리고 새 기본값을 쓴다 (길이·밝기 튜닝은 그대로 살린다)
const STYLE := 2
const RESTYLED := ["hot_color_r", "hot_color_g", "hot_color_b", "gold_color_r", "gold_color_g", "gold_color_b", "edge_color_r", "edge_color_g", "edge_color_b"]

static var values := {}
static var version := 0          # 값이 바뀔 때마다 +1: 전투 카드가 보고 셰이더에 다시 넣는다
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
		var old_style := int(data.get("_style", 1)) < STYLE
		for k in data:
			if values.has(k) and not (old_style and k in RESTYLED):
				values[k] = float(data[k])


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
	version += 1


## 셰이더 uniform 에 지금 값을 넣는다 (intensity·tex_size 는 카드 쪽이 따로).
static func apply(m: ShaderMaterial) -> void:
	for p in PARAMS:
		var key: String = p[0]
		if key in LOCAL_KEYS or key.ends_with("_r") or key.ends_with("_g") or key.ends_with("_b"):
			continue
		m.set_shader_parameter(key, g(key))
	for c in COLORS:
		m.set_shader_parameter(c, Color(g(c + "_r"), g(c + "_g"), g(c + "_b")))


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
	return "줄기 위 %.0f · 옆 %.0f · 아래 %.0f px  ·  밝기 %.2f  ·  막 찼을 때 x%.2f (%.2f초)" % [g("top_reach"), g("side_reach"), g("bottom_reach"), g("flame_strength"), 1.0 + g("flare"), g("flare_sec")]
