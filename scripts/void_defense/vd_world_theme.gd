## 타일·배경·앞 안개를 함께 선택하는 전투 테마. 마지막 선택은 다음 입장/실행에도 유지한다.
## 앞 안개 스타일(기체 / 하프톤)은 테마와 별개로 고르고 같은 설정 파일에 함께 저장한다 (2026-11-09).
class_name VDWorldTheme
extends RefCounted

enum Kind { VOID, DESERT }
const LABELS := ["공허", "사막"]
const VOID_BG := preload("res://shaders/void_nebula.gdshader")
const VOID_FOG := preload("res://shaders/void_vignette.gdshader")
const DESERT_BG := preload("res://shaders/desert_sand.gdshader")
const DESERT_FOG := preload("res://shaders/desert_dust.gdshader")

## 앞 안개 스타일: 기체(테마별 기존 셰이더) / 하프톤(서브컬처·애니풍 망점 그라데이션, 테마 공통 셰이더에 테마 색)
enum FogStyle { GAS, HALFTONE }
const FOG_LABELS := ["기체", "하프톤"]
const HALFTONE_FOG := preload("res://shaders/halftone_fog.gdshader")

static var config_path := "user://vd_world_theme.cfg"
static var selected: int = Kind.DESERT
static var fog_style: int = FogStyle.GAS
static var _loaded := false


static func load_selected() -> int:
	if not _loaded:
		_loaded = true
		selected = Kind.DESERT
		fog_style = FogStyle.GAS
		var config := ConfigFile.new()
		if config.load(config_path) == OK:
			var value := int(config.get_value("world", "theme", Kind.DESERT))
			if value in [Kind.VOID, Kind.DESERT]:
				selected = value
			var style := int(config.get_value("world", "fog_style", FogStyle.GAS))
			if style in [FogStyle.GAS, FogStyle.HALFTONE]:
				fog_style = style
	return selected


static func select(value: int, persist := true) -> void:
	if value not in [Kind.VOID, Kind.DESERT]:
		return
	load_selected()   # 저장 파일의 다른 칸(안개 스타일)을 기본값으로 덮어쓰지 않게 먼저 읽는다
	selected = value
	if persist:
		_save()


static func select_fog_style(value: int, persist := true) -> void:
	if value not in [FogStyle.GAS, FogStyle.HALFTONE]:
		return
	load_selected()
	fog_style = value
	if persist:
		_save()


static func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("world", "theme", selected)
	config.set_value("world", "fog_style", fog_style)
	var error := config.save(config_path)
	if error != OK:
		push_warning("배경 테마 저장 실패: %s" % error_string(error))


static func background(value: int) -> Shader:
	return VOID_BG if value == Kind.VOID else DESERT_BG


## 테마와 현재 앞 안개 스타일에 맞는 앞 안개 셰이더.
static func foreground(value: int) -> Shader:
	if fog_style == FogStyle.HALFTONE:
		return HALFTONE_FOG
	return VOID_FOG if value == Kind.VOID else DESERT_FOG


static func profile(value: int) -> String:
	return "void" if value == Kind.VOID else "desert"
