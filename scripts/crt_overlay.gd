## 화면 CRT 효과 (shaders/crt.gdshader). SceneSwitcher 가 만들어 모든 씬 위에 두는 CanvasLayer(99) 의 전체 화면 ColorRect 하나.
## 설정 메뉴 [CRT 효과] 로 프리셋을 고르고, F6 으로 순환, F7 조정 패널(scripts/crt_tuner.gd)로 값을 하나씩 다듬는다.
## 프리셋은 PRESETS 표(기본값 BASE 위에 덮어쓰는 값만 적는다). 고른 프리셋·손본 값은 user://crt.cfg 에 저장된다.
## 프리셋은 게임 톤(선 굵은 카툰 원화 · 보라 공허 배경)에 맞춰 선이 뭉개지지 않을 만큼만 잡았다 (2026-11-09).
extends CanvasLayer

const SHADER := preload("res://shaders/crt.gdshader")
const CFG_PATH := "user://crt.cfg"
const LAYER := 99

## 조정 값: [키, 이름, 최소, 최대, 간격]  (기본값은 BASE)
const PARAMS := [
	["curvature", "화면 휨", 0.0, 0.3, 0.005],
	["corner", "둥근 모서리", 0.0, 0.2, 0.005],
	["aberration", "색수차 (px)", 0.0, 6.0, 0.1],
	["bleed", "가로 색 번짐 (px)", 0.0, 6.0, 0.1],
	["bloom", "블룸 세기", 0.0, 1.0, 0.01],
	["bloom_radius", "블룸 반지름 (px)", 1.0, 16.0, 0.5],
	["brightness", "밝기", 0.5, 2.0, 0.01],
	["contrast", "대비", 0.5, 1.6, 0.01],
	["saturation", "채도", 0.0, 2.0, 0.01],
	["tint_r", "색조 R", 0.5, 1.5, 0.01],
	["tint_g", "색조 G", 0.5, 1.5, 0.01],
	["tint_b", "색조 B", 0.5, 1.5, 0.01],
	["scan_strength", "주사선 어둡기", 0.0, 1.0, 0.01],
	["scan_pitch", "주사선 간격 (px)", 1.5, 12.0, 0.5],
	["scan_sharp", "주사선 날카로움", 0.5, 6.0, 0.1],
	["mask_strength", "형광체 줄무늬", 0.0, 1.0, 0.01],
	["mask_pitch", "줄무늬 폭 (실제 px)", 1.0, 6.0, 1.0],
	["interlace", "인터레이스 떨림", 0.0, 1.0, 0.05],
	["vignette", "비네트", 0.0, 1.0, 0.01],
	["vignette_size", "비네트 시작 반지름", 0.2, 1.5, 0.01],
	["flicker", "깜빡임", 0.0, 0.3, 0.005],
	["noise_amount", "노이즈", 0.0, 0.5, 0.005],
	["roll_strength", "흘러내리는 띠", 0.0, 1.0, 0.01],
	["roll_speed", "띠 속도", 0.0, 2.0, 0.01],
	["roll_height", "띠 높이", 0.02, 0.6, 0.01],
	["jitter", "가로 떨림 (px)", 0.0, 6.0, 0.1],
]
const BASE := {
	"curvature": 0.0, "corner": 0.0, "aberration": 0.0, "bleed": 0.0, "bloom": 0.0, "bloom_radius": 5.0,
	"brightness": 1.0, "contrast": 1.0, "saturation": 1.0, "tint_r": 1.0, "tint_g": 1.0, "tint_b": 1.0,
	"scan_strength": 0.0, "scan_pitch": 3.0, "scan_sharp": 1.5, "mask_strength": 0.0, "mask_pitch": 2.0, "interlace": 0.0,
	"vignette": 0.0, "vignette_size": 0.8, "flicker": 0.0, "noise_amount": 0.0,
	"roll_strength": 0.0, "roll_speed": 0.25, "roll_height": 0.18, "jitter": 0.0,
}
## id · 이름 · 설명 · BASE 위에 덮을 값
const PRESETS := [
	{"id": "off", "name": "끄기", "desc": "효과 없음"},
	{"id": "soft", "name": "은은한 모니터", "desc": "평면 · 가는 주사선 · 살짝 번짐. 원화 선을 거의 건드리지 않는다",
		"v": {"scan_strength": 0.14, "scan_pitch": 3.0, "scan_sharp": 1.2, "aberration": 0.6, "bloom": 0.12, "bloom_radius": 4.0,
			"vignette": 0.22, "vignette_size": 0.9, "saturation": 1.05, "contrast": 1.03, "noise_amount": 0.015}},
	{"id": "classic", "name": "클래식 브라운관", "desc": "살짝 휜 유리 · 주사선 · RGB 줄무늬 · 색수차. 표준 CRT 느낌",
		"v": {"curvature": 0.045, "corner": 0.04, "scan_strength": 0.32, "scan_pitch": 3.0, "scan_sharp": 1.6,
			"mask_strength": 0.12, "mask_pitch": 2.0, "aberration": 1.4, "bleed": 1.0, "bloom": 0.25, "bloom_radius": 6.0,
			"brightness": 1.08, "contrast": 1.05, "saturation": 1.1, "vignette": 0.4, "vignette_size": 0.75,
			"flicker": 0.03, "noise_amount": 0.025}},
	{"id": "arcade", "name": "아케이드", "desc": "굵은 주사선 · 진한 형광체 · 강한 블룸 · 높은 채도. 오락실 캐비닛",
		"v": {"curvature": 0.025, "corner": 0.025, "scan_strength": 0.45, "scan_pitch": 4.0, "scan_sharp": 2.2,
			"mask_strength": 0.25, "mask_pitch": 2.0, "aberration": 0.8, "bloom": 0.4, "bloom_radius": 8.0,
			"brightness": 1.15, "contrast": 1.1, "saturation": 1.25, "vignette": 0.3, "vignette_size": 0.85, "flicker": 0.02}},
	{"id": "void", "name": "공허 보라 형광체", "desc": "보라 기운 도는 형광체 · 부드러운 블룸 · 느린 띠. 이 게임 색감에 맞춘 것",
		"v": {"curvature": 0.03, "corner": 0.035, "tint_r": 0.96, "tint_g": 0.93, "tint_b": 1.08,
			"scan_strength": 0.25, "scan_pitch": 3.0, "scan_sharp": 1.4, "mask_strength": 0.1, "mask_pitch": 2.0,
			"aberration": 1.0, "bleed": 0.8, "bloom": 0.35, "bloom_radius": 7.0, "saturation": 1.15, "contrast": 1.04, "brightness": 1.06,
			"vignette": 0.45, "vignette_size": 0.7, "flicker": 0.025, "noise_amount": 0.02,
			"roll_strength": 0.25, "roll_speed": 0.12, "roll_height": 0.22}},
	{"id": "worn", "name": "낡은 TV", "desc": "많이 휜 화면 · 색 번짐 · 노이즈 · 떨림 · 흘러내리는 띠. 고장 직전 텔레비전",
		"v": {"curvature": 0.08, "corner": 0.06, "scan_strength": 0.35, "scan_pitch": 3.0, "scan_sharp": 1.4,
			"aberration": 2.6, "bleed": 1.8, "bloom": 0.2, "bloom_radius": 6.0, "brightness": 1.12, "contrast": 0.96,
			"saturation": 0.9, "tint_r": 1.04, "tint_g": 0.98, "tint_b": 0.95, "vignette": 0.55, "vignette_size": 0.65,
			"flicker": 0.06, "noise_amount": 0.08, "roll_strength": 0.6, "roll_speed": 0.3, "roll_height": 0.15,
			"jitter": 1.2, "interlace": 0.5}},
]

signal changed           # 프리셋·값이 바뀜 (조정 패널·설정 메뉴 갱신용)

var preset := 0          # PRESETS 인덱스
var P := {}              # 현재 값 (키 -> float). 프리셋을 고르면 그 값으로, 슬라이더로 손보면 modified
var modified := false

var _rect: ColorRect
var _mat: ShaderMaterial


func _init() -> void:
	layer = LAYER
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)
	P = BASE.duplicate()
	_load()
	_push()


func preset_names() -> Array:
	return PRESETS.map(func(p: Dictionary) -> String: return p["name"])


func get_preset() -> int:
	return preset


func preset_id() -> String:
	return PRESETS[preset]["id"]


## 프리셋 i 의 값으로 되돌리고 적용한다.
func apply_preset(i: int) -> void:
	preset = clampi(i, 0, PRESETS.size() - 1)
	P = BASE.duplicate()
	for k in PRESETS[preset].get("v", {}):
		P[k] = PRESETS[preset]["v"][k]
	modified = false
	_push()
	_save()
	changed.emit()


func cycle(dir := 1) -> void:
	apply_preset(posmod(preset + dir, PRESETS.size()))


func is_on() -> bool:
	return preset != 0


## 조정 패널: 값 하나를 바꾼다 (프리셋은 그대로 두고 '손봄' 표시).
func set_param(key: String, v: float) -> void:
	P[key] = v
	modified = true
	if preset == 0:
		preset = 1   # 끄기 상태에서 슬라이더를 만지면 보이게
	_push()
	_save_soon()


## BASE 와 다른 값만 모은 사전 문자열 (PRESETS 의 "v" 에 그대로 붙여 넣을 수 있다).
func values_text() -> String:
	var parts := PackedStringArray()
	for p in PARAMS:
		var k: String = p[0]
		if not is_equal_approx(float(P[k]), float(BASE[k])):
			parts.append('"%s": %s' % [k, str(snappedf(float(P[k]), 0.001))])
	return "{" + ", ".join(parts) + "}"


func _push() -> void:
	_rect.visible = preset != 0
	for k in P:
		_mat.set_shader_parameter(k, float(P[k]))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("crt", "preset", preset)
	cfg.set_value("crt", "modified", modified)
	for k in P:
		cfg.set_value("values", k, float(P[k]))
	cfg.save(CFG_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	preset = clampi(int(cfg.get_value("crt", "preset", 0)), 0, PRESETS.size() - 1)
	modified = bool(cfg.get_value("crt", "modified", false))
	if modified:
		P = BASE.duplicate()
		for p in PARAMS:
			P[p[0]] = clampf(float(cfg.get_value("values", p[0], BASE[p[0]])), p[2], p[3])
	else:
		P = BASE.duplicate()
		for k in PRESETS[preset].get("v", {}):
			P[k] = PRESETS[preset]["v"][k]


## 슬라이더를 끄는 동안 값이 바뀔 때마다 파일을 쓰지 않고, 멈춘 뒤 한 번 쓴다 (씬을 떠날 때 남은 것도 쓴다).
const SAVE_DELAY := 0.4
var _save_queued := false


func _save_soon() -> void:
	if not is_inside_tree():
		_flush_save()
		return
	if _save_queued:
		return
	_save_queued = true
	get_tree().create_timer(SAVE_DELAY, true, false, true).timeout.connect(_flush_save)


func _flush_save() -> void:
	_save_queued = false
	_save()


func _exit_tree() -> void:
	if _save_queued:
		_flush_save()
