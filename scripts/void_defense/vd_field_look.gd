## 필드 색 보정 (2026-11-11, 로비 → 필드 연구실): 전투 배경이 되는 요소마다 색조·채도·명도·대비·덧색·불투명도를 조절한다.
## VFX 와 캐릭터가 잘 보이도록 배경을 누르거나 살리는 용도. 값은 테마(공허 / 사막)별로 user://vd_field_look.cfg 에 저장되고,
## 전투(VDBattle.apply_field_look)가 읽어 그대로 쓴다 — 연구실에서 맞춘 값이 본 전투에 반영된다.
##   요소(GROUPS): all 전체(나머지 모두에 곱해진다) · tile 타일 · bg 배경(하늘·지면) · prop_back 뒤쪽 프랍 · prop_front 앞쪽 프랍 · fog 앞 안개
##   타일·프랍은 shaders/field_look.gdshader 재질을 입히고, 배경·앞 안개 셰이더는 같은 fl_* uniform 을 include 로 갖고 있다.
##   tile 의 zone = 아군 배치 구역·적 등장 구역 색 띠의 세기 (VDBoard.zone_k).
## class_name 없음: 헤드리스 실행이 전역 클래스 캐시를 갱신하지 않으므로 preload 해서 쓴다.
extends RefCounted

const CFG_PATH := "user://vd_field_look.cfg"
const SHADER := preload("res://shaders/field_look.gdshader")
const GROUPS := [
	["all", "전체"],
	["tile", "타일"],
	["bg", "배경"],
	["prop_back", "뒤 프랍"],
	["prop_front", "앞 프랍"],
	["fog", "앞 안개"],
]
const GROUP_HINTS := {
	"all": "아래 요소 전부에 한꺼번에 곱해진다. 배경 전체를 빠르게 누르거나 살릴 때.",
	"tile": "바닥 블록(윗면·옆면)과 그 위의 구역 색 띠.",
	"bg": "맨 뒤의 하늘·지면 무늬 (공허 성운 / 사막 모래).",
	"prop_back": "바닥보다 뒤에 떠 있는 아치·기둥·바위 (공허 테마).",
	"prop_front": "바닥보다 앞에 떠 있는 작은 파편·바위 (공허 테마).",
	"fog": "화면 가장자리를 덮는 앞 안개 / 모래바람 / 하프톤.",
}
## [키, 이름, 최소, 최대, 간격, 기본값, 표시 형식]
const PARAMS := [
	["hue", "색조", -180.0, 180.0, 1.0, 0.0, "%+.0f°"],
	["sat", "채도", 0.0, 2.0, 0.01, 1.0, "×%.2f"],
	["val", "명도", 0.0, 2.0, 0.01, 1.0, "×%.2f"],
	["contrast", "대비", 0.3, 1.7, 0.01, 1.0, "×%.2f"],
	["alpha", "불투명도", 0.0, 1.0, 0.01, 1.0, "%.2f"],
	["tint_amount", "덧색 세기", 0.0, 1.0, 0.01, 0.0, "%.2f"],
]
## 요소 전용 슬라이더
const EXTRA := {
	"tile": [["zone", "구역 색 띠 세기", 0.0, 2.5, 0.01, 1.0, "×%.2f"]],
}
const TINT_DEFAULT := Color(0.1, 0.08, 0.16)
const PROFILES := ["void", "desert", "bio"]

static var _values := {}      # profile -> group -> key -> 값 (기본값과 다른 것만 저장)
static var _loaded := false
static var config_path := CFG_PATH   # 테스트는 임시 파일로 바꾼다 (사용자 저장값을 건드리지 않게)
static var bypass := false    # true 면 보정을 끄고 원본을 보여 준다 (연구실 "원본 비교", 저장되지 않음)


static func params_of(group: String) -> Array:
	return PARAMS + EXTRA.get(group, [])


static func default_of(key: String) -> Variant:
	if key == "tint":
		return TINT_DEFAULT
	for g: String in EXTRA:
		for p: Array in EXTRA[g]:
			if p[0] == key:
				return p[5]
	for p: Array in PARAMS:
		if p[0] == key:
			return p[5]
	return 0.0


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_values = {}
	var cfg := ConfigFile.new()
	if cfg.load(config_path) != OK:
		return
	for section in cfg.get_sections():
		var parts := section.split("/")
		if parts.size() != 2:
			continue
		for key in cfg.get_section_keys(section):
			_slot(parts[0], parts[1])[key] = cfg.get_value(section, key)


static func _slot(profile: String, group: String) -> Dictionary:
	if not _values.has(profile):
		_values[profile] = {}
	if not _values[profile].has(group):
		_values[profile][group] = {}
	return _values[profile][group]


static func get_v(profile: String, group: String, key: String) -> Variant:
	_ensure()
	return _values.get(profile, {}).get(group, {}).get(key, default_of(key))


static func set_v(profile: String, group: String, key: String, value: Variant) -> void:
	_ensure()
	var d: Variant = default_of(key)
	var same: bool = (value as Color).is_equal_approx(d) if value is Color else is_equal_approx(float(value), float(d))
	if same:
		_slot(profile, group).erase(key)
	else:
		_slot(profile, group)[key] = value


## group 이 "" 이면 그 테마의 모든 요소를 기본값으로.
static func reset(profile: String, group := "") -> void:
	_ensure()
	if group == "":
		_values.erase(profile)
	elif _values.has(profile):
		_values[profile].erase(group)


static func is_default(profile: String, group := "") -> bool:
	_ensure()
	var p: Dictionary = _values.get(profile, {})
	if group != "":
		return p.get(group, {}).is_empty()
	for g in p:
		if not p[g].is_empty():
			return false
	return true


static func save() -> void:
	_ensure()
	var cfg := ConfigFile.new()
	for profile: String in _values:
		for group: String in _values[profile]:
			for key: String in _values[profile][group]:
				cfg.set_value("%s/%s" % [profile, group], key, _values[profile][group][key])
	var err := cfg.save(config_path)
	if err != OK:
		push_warning("필드 색 보정 저장 실패: %s" % error_string(err))


## 테스트용: 저장 파일을 건드리지 않고 메모리 값만 비운다.
static func clear_memory() -> void:
	_loaded = true
	_values = {}
	bypass = false


## "전체"를 곱한 실제 적용값: {hue(도), sat, val, contrast, alpha, tint(Color, a = 세기), zone}.
static func effective(profile: String, group: String) -> Dictionary:
	if bypass:
		return {"hue": 0.0, "sat": 1.0, "val": 1.0, "contrast": 1.0, "alpha": 1.0, "tint": Color(1, 1, 1, 0), "zone": 1.0}
	var out := {}
	out["hue"] = float(get_v(profile, group, "hue")) + float(get_v(profile, "all", "hue"))
	for k in ["sat", "val", "contrast", "alpha"]:
		out[k] = float(get_v(profile, group, k)) * float(get_v(profile, "all", k))
	# 덧색: 요소의 덧색 위에 "전체" 덧색이 한 번 더 얹힌다
	var own: Color = get_v(profile, group, "tint")
	var own_a := float(get_v(profile, group, "tint_amount"))
	var all_c: Color = get_v(profile, "all", "tint")
	var all_a := float(get_v(profile, "all", "tint_amount"))
	var a := 1.0 - (1.0 - own_a) * (1.0 - all_a)
	var c := own
	if a > 0.0001:
		c = (own * (own_a * (1.0 - all_a)) + all_c * all_a) / a
	out["tint"] = Color(c.r, c.g, c.b, a)
	out["zone"] = float(get_v(profile, group, "zone"))
	return out


## 재질에 fl_* uniform 을 넣는다.
static func apply(profile: String, group: String, mat: ShaderMaterial) -> void:
	if mat == null:
		return
	var e := effective(profile, group)
	mat.set_shader_parameter("fl_hue", float(e["hue"]) / 360.0)
	mat.set_shader_parameter("fl_sat", e["sat"])
	mat.set_shader_parameter("fl_val", e["val"])
	mat.set_shader_parameter("fl_contrast", e["contrast"])
	mat.set_shader_parameter("fl_alpha", e["alpha"])
	mat.set_shader_parameter("fl_tint", e["tint"])


static func new_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	return m


## 한 줄 요약 (값 복사용). 기본값과 다른 것만.
static func values_text(profile: String) -> String:
	_ensure()
	var parts: Array[String] = []
	for g: Array in GROUPS:
		var d: Dictionary = _values.get(profile, {}).get(g[0], {})
		if d.is_empty():
			continue
		var items: Array[String] = []
		for key: String in d:
			var v: Variant = d[key]
			items.append("%s=%s" % [key, ("#" + (v as Color).to_html(false)) if v is Color else ("%.2f" % float(v))])
		parts.append("%s(%s)" % [g[1], ", ".join(items)])
	return "필드 색 보정 [%s] " % profile + ("기본값" if parts.is_empty() else "  ".join(parts))


## 저장 파일을 다시 읽는다 (테스트용).
static func reload_config() -> void:
	_loaded = false
	bypass = false
	_ensure()
