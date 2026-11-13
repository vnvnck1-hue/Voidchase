## 게임 글꼴을 세 역할로 나눠 한곳에서 관리하고, 설정 메뉴 [글꼴 조합] · [글꼴 바꾸기 (F5)] 패널(scripts/font_tuner.gd)에서
## 게임을 켠 채로 바꿔 본다. 고른 값은 user://fonts.cfg 에 저장된다. 글꼴 파일과 라이선스 원문은 assets/fonts/<이름>/ (docs/폰트_리서치.md).
##   본문(body)       : 메뉴·카드 설명·HP·툴팁처럼 UI 글자 대부분. VDData.font() 가 이것을 돌려준다.
##   강조(bold)       : 큰 버튼·컷인 이름·툴팁 제목·스킬창처럼 굵게 쓰던 한글.
##   숫자·타이틀(display): 피해 숫자·배너 제목·로딩·READY! 같은 팝 글자 (원래 ARCO). VDDamageLog.font() 가 이것을 돌려준다.
## 역할마다 한글 글꼴 하나 + 영어·숫자 글꼴 하나를 고른다. 영어 글꼴을 고르면 라틴·숫자는 그 글꼴, 거기 없는 한글은 한글 글꼴,
## 한글 글꼴에도 없는 글자(와구리체는 2,780자뿐)는 시스템 고딕이 그린다.
## 구현: 역할마다 FontVariation 하나를 계속 같은 객체로 돌려주고, 바꿀 때는 그 base_font·fallbacks·굵기만 갈아 끼운다.
## Font.changed 신호로 그 글꼴을 쓰는 Theme·Label·LabelSettings 는 저절로 다시 그려지고, draw_string 으로 직접 그리는
## 노드는 apply 때 트리 전체에 queue_redraw 를 걸어 준다. 기본값은 바꾸기 전 모습(맑은 고딕 + ARCO)과 같다.
## class_name 을 두지 않는다(헤드리스 실행이 전역 클래스 캐시를 갱신하지 않음) — 쓰는 곳은 preload 로 부른다.
extends RefCounted

const CFG_PATH := "user://fonts.cfg"
const SYSTEM_NAMES := ["Malgun Gothic", "맑은 고딕", "Noto Sans KR", "Apple SD Gothic Neo", "sans-serif"]

## 한글 글꼴: [id, 표시 이름, 경로 ("" = 시스템 맑은 고딕)]
const KO := [
	["system", "맑은 고딕 (시스템·기존)", ""],
	["kart", "넥슨 카트 고딕", "res://assets/fonts/NexonKartGothic/NEXONKartGothic-ExtraBold.otf"],
	["swagger", "스웨거체", "res://assets/fonts/Swagger/SDSwaggerTTF.ttf"],
	["yangjin", "양진체", "res://assets/fonts/Yangjin/Yangjin-v0.93.otf"],
	["waguri", "와구리체 (한글 2,780자)", "res://assets/fonts/Waguri/WAGURI.otf"],
]
## 영어·숫자 글꼴: [id, 표시 이름, 경로, 가변 글꼴 굵기 wght (0 = 고정 굵기)]. "same" = 한글 글꼴의 영문을 그대로 쓴다.
const LATIN := [
	["same", "한글 글꼴 그대로", "", 0],
	["arco", "ARCO (기존)", "res://assets/fonts/ARCO.otf", 0],
	["bangers", "Bangers", "res://assets/fonts/Bangers/Bangers-Regular.ttf", 0],
	["bungee", "Bungee", "res://assets/fonts/Bungee/Bungee-Regular.ttf", 0],
	["boogaloo", "Boogaloo", "res://assets/fonts/Boogaloo/Boogaloo-Regular.ttf", 0],
	["lemon", "Lemon", "res://assets/fonts/Lemon/Lemon-Regular.ttf", 0],
	["dynapuff", "DynaPuff Bold", "res://assets/fonts/DynaPuff/DynaPuff-Variable.ttf", 700],
	["slackey", "Slackey", "res://assets/fonts/Slackey/Slackey-Regular.ttf", 0],
	["galindo", "Galindo", "res://assets/fonts/Galindo/Galindo-Regular.ttf", 0],
	["chicle", "Chicle", "res://assets/fonts/Chicle/Chicle-Regular.ttf", 0],
	["ranchers", "Ranchers", "res://assets/fonts/Ranchers/Ranchers-Regular.ttf", 0],
]
## 역할: [id, 이름, 설명, 기본 한글, 기본 영어, 시스템 고딕 굵기, 미리보기 문장]
const ROLES := [
	["body", "본문", "메뉴 · 카드 설명 · HP · 툴팁 등 UI 글자 대부분", "system", "same", 400,
		"마음 정리 상담소 · 공허 정수 +120 · Wave 3/5"],
	["bold", "강조", "큰 버튼 · 컷인 이름 · 툴팁 제목 · 스킬창", "system", "same", 900,
		"전투 시작!  메이드 출동  잉걸불 혜성"],
	["display", "숫자·타이틀", "피해 숫자 · 배너 제목 · 로딩 · READY! 팝 글자", "system", "arco", 900,
		"-1,240  READY!  STAGE 3  공허 강하"],
]
## 한 번에 고르는 조합: [이름, {역할: [한글, 영어]}]
const PRESETS := [
	["기본 (맑은 고딕 + ARCO)", {"body": ["system", "same"], "bold": ["system", "same"], "display": ["system", "arco"]}],
	["카트 고딕 + DynaPuff", {"body": ["kart", "same"], "bold": ["kart", "dynapuff"], "display": ["kart", "dynapuff"]}],
	["스웨거 + Bangers", {"body": ["system", "same"], "bold": ["swagger", "same"], "display": ["swagger", "bangers"]}],
	["양진 + Galindo", {"body": ["yangjin", "same"], "bold": ["yangjin", "galindo"], "display": ["yangjin", "galindo"]}],
	["와구리 + Chicle", {"body": ["system", "same"], "bold": ["waguri", "chicle"], "display": ["waguri", "chicle"]}],
	["카트 고딕 + Ranchers", {"body": ["kart", "same"], "bold": ["kart", "ranchers"], "display": ["kart", "ranchers"]}],
]

static var _roles := {}       # 역할 id -> FontVariation (계속 같은 객체)
static var _variants := []    # [FontVariation, 역할 id, 시스템 대체 글꼴, 키] — 시스템 고딕 대신 다른 시스템 글꼴을 먼저 찾는 곳(스킬창)
static var _sel := {}         # 역할 id -> [한글 id, 영어 id]
static var _files := {}       # 경로 -> FontFile
static var _system := {}      # 굵기 -> SystemFont


static func body() -> Font:
	return role("body")


static func bold() -> Font:
	return role("bold")


static func display() -> Font:
	return role("display")


static func role(id: String) -> Font:
	_ensure()
	return _roles[id]


## 역할을 따르되, 한글이 "시스템" 일 때는 names 시스템 글꼴을 먼저 찾는 글꼴 (예: 스킬창의 시안 글꼴이 깔려 있으면 그것).
static func variant(role_id: String, names: PackedStringArray, weight: int) -> Font:
	_ensure()
	var key := "%s|%s|%d" % [role_id, ",".join(names), weight]
	for v in _variants:
		if v[3] == key:
			return v[0]
	var sf := SystemFont.new()
	var all := PackedStringArray(names)
	all.append_array(PackedStringArray(SYSTEM_NAMES))
	sf.font_names = all
	sf.font_weight = weight
	var fv := FontVariation.new()
	_variants.append([fv, role_id, sf, key])
	_build(fv, role_id, sf)
	return fv


# ------------------------------------------------------------ 선택 · 저장

static func selection(role_id: String) -> Array:
	_ensure()
	return _sel[role_id].duplicate()


static func ko_index(role_id: String) -> int:
	return _index(KO, selection(role_id)[0])


static func latin_index(role_id: String) -> int:
	return _index(LATIN, selection(role_id)[1])


## 한 역할의 한글·영어 글꼴을 바꾼다 (빈 문자열 = 그대로). 화면에 바로 반영되고 저장된다.
static func set_role(role_id: String, ko_id := "", latin_id := "") -> void:
	_ensure()
	var s: Array = _sel[role_id]
	if ko_id != "":
		s[0] = ko_id
	if latin_id != "":
		s[1] = latin_id
	_apply(role_id)
	_save()
	_redraw_all()


static func apply_preset(i: int) -> void:
	_ensure()
	var p: Dictionary = PRESETS[clampi(i, 0, PRESETS.size() - 1)][1]
	for rid in p:
		_sel[rid] = (p[rid] as Array).duplicate()
		_apply(rid)
	_save()
	_redraw_all()


## 지금 선택과 같은 조합의 번호 (어느 조합과도 다르면 -1 = 직접 고름)
static func preset_index() -> int:
	_ensure()
	for i in PRESETS.size():
		var p: Dictionary = PRESETS[i][1]
		var same := true
		for r in ROLES:
			if p[r[0]] != _sel[r[0]]:
				same = false
				break
		if same:
			return i
	return -1


static func preset_names() -> Array:
	var out := []
	for p in PRESETS:
		out.append(p[0])
	return out


## 지금 조합을 사람이 읽는 한 줄로 (캡처·로그용)
static func describe() -> String:
	_ensure()
	var parts := []
	for r in ROLES:
		var s: Array = _sel[r[0]]
		var ln: String = LATIN[_index(LATIN, s[1])][1]
		parts.append("%s=%s%s" % [r[1], KO[_index(KO, s[0])][1], "" if s[1] == "same" else " + " + ln])
	return " | ".join(parts)


# ------------------------------------------------------------ 내부

static func _ensure() -> void:
	if not _roles.is_empty():
		return
	for r in ROLES:
		_sel[r[0]] = [r[3], r[4]]
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		for r in ROLES:
			var ko := str(cfg.get_value("fonts", r[0] + "_ko", r[3]))
			var la := str(cfg.get_value("fonts", r[0] + "_latin", r[4]))
			_sel[r[0]] = [ko if _index(KO, ko) >= 0 else r[3], la if _index(LATIN, la) >= 0 else r[4]]
	for r in ROLES:
		_roles[r[0]] = FontVariation.new()
		_apply(r[0])


static func _save() -> void:
	var cfg := ConfigFile.new()
	for r in ROLES:
		cfg.set_value("fonts", r[0] + "_ko", _sel[r[0]][0])
		cfg.set_value("fonts", r[0] + "_latin", _sel[r[0]][1])
	cfg.save(CFG_PATH)


static func _apply(role_id: String) -> void:
	_build(_roles[role_id], role_id, null)
	for v in _variants:
		if v[1] == role_id:
			_build(v[0], role_id, v[2])


## fv 를 역할의 지금 선택대로 다시 짠다. system_override 가 있으면 "시스템" 한글 대신 그것을 쓴다.
static func _build(fv: FontVariation, role_id: String, system_override: Font) -> void:
	var rdef: Array = ROLES[_index(ROLES, role_id)]
	var weight: int = rdef[5]
	var s: Array = _sel[role_id]
	var ko_def: Array = KO[maxi(0, _index(KO, s[0]))]
	var la_def: Array = LATIN[maxi(0, _index(LATIN, s[1]))]
	var sys: Font = system_override if system_override != null else _system_font(weight)
	var ko_font: Font = sys if ko_def[2] == "" else _file(ko_def[2])
	if ko_font == null:
		ko_font = sys
	var base: Font = ko_font
	var fallbacks: Array[Font] = []
	var ot := {}
	if la_def[2] != "":
		var lf := _file(la_def[2])
		if lf != null:
			base = lf
			fallbacks.append(ko_font)
			if int(la_def[3]) > 0:
				ot[TextServerManager.get_primary_interface().name_to_tag("wght")] = int(la_def[3])
	if ko_font != sys:
		fallbacks.append(sys)   # 한글 글꼴에도 없는 글자
	fv.base_font = base
	fv.variation_opentype = ot
	fv.fallbacks = fallbacks


static func _file(path: String) -> Font:
	if not _files.has(path):
		_files[path] = load(path) as Font if ResourceLoader.exists(path) else null
		if _files[path] == null:
			push_warning("[game_fonts] 글꼴을 못 읽음: " + path)
	return _files[path]


static func _system_font(weight: int) -> Font:
	if not _system.has(weight):
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(SYSTEM_NAMES)
		sf.font_weight = weight
		_system[weight] = sf
	return _system[weight]


static func _index(table: Array, id: String) -> int:
	for i in table.size():
		if table[i][0] == id:
			return i
	return -1


## draw_string 으로 직접 그리는 노드(HP 바·카드·성좌판 등)는 Font.changed 를 듣지 않으니 한 번씩 다시 그리게 한다.
static func _redraw_all() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var stack: Array[Node] = [tree.root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem:
			(n as CanvasItem).queue_redraw()
		stack.append_array(n.get_children())
