## 전투 HUD 틀 (시안 PSD 화면 컨셉_2): 상단 바 + 스테이지 명판, 하단 그림자 띠, 우측 하단 라바램프 뒷패널,
## 분대 카드 4장(캐릭터 선택창 패널 아트 재사용) + 카드마다 아이템 슬롯 3칸.
## 좌표·텍스처는 tools/battle_ui/extract_battle_ui.py 가 만든 VDBattleUILayout(생성물)과 assets/textures/battle_ui/.
## class_name 없음: vd_battle.gd 가 preload 해서 쓴다.
extends Control

signal card_pressed(hid: String)   # 분대 카드를 눌렀다 (궁극기 시전)

const Layout := preload("res://scripts/void_defense/vd_battle_ui_layout.gd")
const Items := preload("res://scripts/void_defense/vd_items.gd")
const LavaShader := preload("res://shaders/lava_lamp.gdshader")
const FlameShader := preload("res://shaders/card_ult_flame.gdshader")
const CardFlameFx := preload("res://scripts/void_defense/vd_card_flame_fx.gd")   # 불꽃 조절값 (연출 연구실에서 다듬는다)
## 카드 윤곽 부호 거리장 (tools/battle_ui/build_card_sdf.py 생성물): 패널 텍스처보다 FLAME_PAD_TEX(px) 만큼 넓다
const FLAME_SDF_DIR := "res://assets/textures/battle_ui/card_sdf/"
const FLAME_PAD_TEX := Vector2(64, 104)

## 분대 영웅 → 캐릭터 선택창 패널 (전장 유닛과 같은 얼굴)
const HERO_PANEL := {
	"gunner": "res://assets/textures/char_panels/panel_01.png",
	"mage": "res://assets/textures/char_panels/new_panel_08.png",
	"knight": "res://assets/textures/char_panels/new_panel_04.png",
	"healer": "res://assets/textures/char_panels/panel_03.png",
}
const PANEL_TEX := Vector2(300, 229)
const Energy := preload("res://scripts/void_defense/vd_energy_bar_layout.gd")   # 카드 위 HP+마나 에너지바 (생성물)
const ORIGIN := Vector2(1000, 790)       # 카드 컨트롤의 디자인 좌표 왼쪽 위

var cards: Control
var stage_label: Label
var _card_tex := {}
var _heroes: Array = []                  # HERO_ORDER
var _state := {}                         # hid -> {hp, mana, full, alive, stat, ult, ult_full}
var _items := {}                         # hid -> Array[String] (3칸)
var _hover_slot := Vector2i(-1, -1)      # (카드, 슬롯)
var _hits := {}                          # hid -> 피격 연출 상태 (hit_card)
var _hover_card := -1                    # 마우스가 올라간 카드 (살짝 떠오른다)
var _clock_us := 0
var _fx := {}                            # hid -> {ghost, hold, heal, pop, pop_k, lift, down_t}: 카드 손맛 상태 (실제 시간)
var _flames := {}                        # hid -> Node2D: 궁극기 준비 때 카드 윤곽을 따라 타오르는 황금 불꽃 (card_ult_flame)
var _flame_k := {}                       # hid -> 불꽃 세기 (켜고 끌 때 부드럽게)
var _flame_layer: CanvasLayer             # 불꽃은 HUD CanvasGroup 밖에서 그린다: 그룹 버퍼를 거치면 가산 블렌드가 어둡게 섞인다
var _flame_ver := -1                      # 마지막으로 셰이더에 넣은 CardFlameFx.version
var _bars: Node2D                         # 에너지바(HP+마나): 불꽃 층에서 불꽃보다 나중에 그려 불꽃에 가려지지 않게
## 입장 애니메이션(UIIntro)이 미는 틀 조각: 하단 그림자 띠 · 우측 하단 뒷패널 · 상단 바 · 명판
var _shade: TextureRect
var _panel: TextureRect
var _top_bar: NinePatchRect
var _top_plate: TextureRect
## 분대 카드 입장: 카드가 아래에서 차례로 튀어 올라온다. _fx[hid]["in_t"] = 경과(음수면 아직 대기), INTRO_SEC 지나면 끝
const INTRO_SEC := 0.55
const INTRO_DROP := 320.0                 # 시작 위치 (아래로, px)
const STAMP_FONT_SIZE := 30
## 궁극기 게이지가 막 찼을 때(ult_t 0 부터, 실제 시간): 카드가 순백으로 번쩍 + 짧고 강한 핀치 진동(가로·세로가 번갈아 꼬집히듯 찌그러지며 살짝 비틀림)
const ULT_FLASH_SEC := 0.34
const ULT_FLASH_HOLD := 0.07     # 처음 이만큼은 완전히 하얗게
const ULT_PINCH_SEC := 0.34
const ULT_PINCH_AMP := 0.12        # 찌그러짐 최대 (배율)
const ULT_PINCH_HZ := 16.0         # 진동 빠르기
const ULT_PINCH_TWIST := 0.045     # 비틀림 최대 (라디안)

## 피격 색: 흰 섬광(밝게 곱하기) → 붉은 기 (카드 텍스처에 곱하는 modulate)
const HIT_WHITE := Color(2.6, 2.4, 2.4)
const HIT_RED := Color(1.7, 0.42, 0.48)


## 카드·슬롯 위에서만 마우스를 받는 영역 (나머지는 전장으로 통과).
class HitArea extends Control:
	var hit: Callable

	func _has_point(p: Vector2) -> bool:
		return hit.is_valid() and hit.call(p)


func setup(hero_order: Array) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_heroes = hero_order
	for i in _heroes.size():
		var hid: String = _heroes[i]
		_card_tex[hid] = load(HERO_PANEL[hid])
		_items[hid] = Items.mock_slots(i)
		_state[hid] = {"hp": 1.0, "mana": 0.0, "full": false, "alive": true, "stat": "", "ult": 0.0, "ult_full": false, "level": 1, "sp": 0}
		_fx[hid] = {"ghost": 1.0, "shown": 1.0, "hold": 0.0, "heal": 0.0, "pop": 0.0, "pop_k": 1.0, "lift": 0.0, "down_t": -1.0, "ult_t": -1.0, "lv_t": -1.0}

	# 하단 그림자 띠 (화면 폭 전체)
	var shade := TextureRect.new()
	shade.texture = load(Layout.DIR + "bottom_shade.png")
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.anchor_left = 0.0
	shade.anchor_right = 1.0
	shade.anchor_top = 1.0
	shade.anchor_bottom = 1.0
	shade.offset_top = Layout.SHADE_RECT.position.y - 1080.0
	shade.offset_bottom = Layout.SHADE_RECT.end.y - 1080.0
	shade.modulate = Color(1, 1, 1, Layout.SHADE_OPACITY)
	add_child(shade)
	_shade = shade

	# 우측 하단 뒷패널 + 라바램프
	var panel := TextureRect.new()
	panel.texture = load(Layout.DIR + "panel_right.png")
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneSwitcher.pin(panel, Vector2(1, 1), Layout.PANEL_RIGHT_RECT)
	panel.material = lava_material(Layout.PANEL_RIGHT_RECT.size, Layout.LAVA_COLOR, Layout.LAVA_DARK, 0.62, 3.0, 0.0)
	add_child(panel)
	_panel = panel

	cards = HitArea.new()
	cards.hit = func(p: Vector2) -> bool: return _hit_slot(p).x >= 0 or _hit_card(p) >= 0
	cards.mouse_filter = Control.MOUSE_FILTER_PASS
	SceneSwitcher.pin(cards, Vector2(1, 1), Rect2(ORIGIN, Vector2(1920, 1080) - ORIGIN))
	cards.draw.connect(_draw_cards)
	cards.gui_input.connect(_cards_input)
	cards.mouse_exited.connect(func() -> void:
		_hover_slot = Vector2i(-1, -1)
		_hover_card = -1
		cards.tooltip_text = "")
	add_child(cards)
	_flame_layer = CanvasLayer.new()
	_flame_layer.layer = 11
	add_child(_flame_layer)
	for i in _heroes.size():
		_flames[_heroes[i]] = _make_flame(i)
		_flame_k[_heroes[i]] = 0.0
	_bars = Node2D.new()
	_bars.draw.connect(_draw_bars)
	_flame_layer.add_child(_bars)          # 불꽃 노드들 다음 → 그 위에 그려진다

	_build_top()


## 상단 바: 왼쪽 들쭉날쭉한 부분은 고정, 오른쪽 띠만 화면 폭에 맞춰 늘인다. 명판·스테이지 글자는 오른쪽에 붙는다.
func _build_top() -> void:
	var bar := NinePatchRect.new()
	bar.texture = load(Layout.DIR + "top_bar.png")
	bar.patch_margin_left = Layout.TOP_STRETCH_FROM
	bar.patch_margin_right = 4
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.offset_left = Layout.TOP_RECT.position.x
	bar.offset_right = Layout.TOP_RECT.end.x - 1920.0
	bar.offset_top = Layout.TOP_RECT.position.y
	bar.offset_bottom = Layout.TOP_RECT.end.y
	add_child(bar)
	_top_bar = bar
	var plate := TextureRect.new()
	plate.texture = load(Layout.DIR + "top_plate.png")
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneSwitcher.pin(plate, Vector2(1, 0), Layout.TOP_PLATE_RECT)
	add_child(plate)
	_top_plate = plate
	stage_label = Label.new()
	stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font
	if ResourceLoader.exists(Layout.STAGE_FONT):
		font = load(Layout.STAGE_FONT)
	else:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Segoe Script", "Segoe UI", "sans-serif"])
		sf.font_weight = 700
		sf.font_italic = true
		font = sf
	stage_label.add_theme_font_override("font", font)
	stage_label.add_theme_font_size_override("font_size", Layout.STAGE_TEXT_SIZE)
	stage_label.add_theme_color_override("font_color", Layout.STAGE_TEXT_COLOR)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 명판 가운데에 맞춘다 (시안 글자 기준선 위치 = 명판 세로 가운데 근처)
	var pr := Layout.TOP_PLATE_RECT
	var cy := Layout.STAGE_TEXT_POS.y - Layout.STAGE_TEXT_SIZE * 0.32
	SceneSwitcher.pin(stage_label, Vector2(1, 0), Rect2(pr.position.x, cy - 30.0, pr.size.x, 60.0))
	add_child(stage_label)


static func lava_material(sz: Vector2, lava: Color, dark: Color, region_top: float, wobble: float, seed: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LavaShader
	m.set_shader_parameter("rect_size", sz)
	m.set_shader_parameter("lava_color", lava)
	m.set_shader_parameter("dark_color", dark)
	m.set_shader_parameter("rim_color", Color(lava.lightened(0.45), 0.3))
	m.set_shader_parameter("region_top", region_top)
	m.set_shader_parameter("edge_wobble", wobble)
	m.set_shader_parameter("seed", seed)
	return m


## 피격 글리치(VDHurtGlitch)가 가시를 달 영웅 카드: id = 영웅 id, 텍스처 + 텍스처 px → 화면(캔버스) 변환.
## 흔들림 오프셋 · 피격 색까지 넣어 주므로 글리치 가시가 흔들리는 카드를 따라가고 같은 색으로 물든다.
func glitch_targets() -> Array:
	var out := []
	for i in _heroes.size():
		var hid: String = _heroes[i]
		var tex: Texture2D = _card_tex[hid]
		var r := _card_rect(i)
		out.append({"id": hid, "tex": tex, "tint": _hit_tint(hid),
			"xf": cards.get_global_transform_with_canvas() * Transform2D(0.0, r.size / tex.get_size(), 0.0, r.position + _shake(hid))})
	return out


## 피격 연출: 카드가 카툰식으로(박자 끊어) 흔들리고, 흰 섬광 → 붉은 기가 빠지는 색 변화.
## p = VDHurtGlitch.P (shake_px · shake_time · shake_fps · flash_white · flash_time · flash_red). 실제 시간 기준.
func hit_card(hid: String, strength: float, p: Dictionary) -> void:
	if not _state.has(hid):
		return
	_hits[hid] = {"t0": Time.get_ticks_usec(), "seed": randi(), "amp": float(p["shake_px"]) * lerpf(0.6, 1.0, strength),
		"shake": float(p["shake_time"]), "fps": float(p["shake_fps"]), "white": float(p["flash_white"]),
		"flash": float(p["flash_time"]), "red": float(p["flash_red"])}


func _hit_elapsed(hid: String) -> float:
	if not _hits.has(hid):
		return -1.0
	return (Time.get_ticks_usec() - int(_hits[hid]["t0"])) / 1_000_000.0


## 흔들림 오프셋: shake_fps 박자마다 새 위치로 '툭' 옮기고(가로 위주), 세기는 시간에 따라 줄어든다.
func _shake(hid: String) -> Vector2:
	var e := _hit_elapsed(hid)
	if e < 0.0:
		return Vector2.ZERO
	var h: Dictionary = _hits[hid]
	if e >= h["shake"]:
		return Vector2.ZERO
	var k := floori(e * float(h["fps"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([h["seed"], k])
	var amp: float = h["amp"] * (1.0 - e / float(h["shake"]))
	var sx := 1.0 if k % 2 == 0 else -1.0                 # 좌우로 번갈아 튀게
	return Vector2(sx * rng.randf_range(0.5, 1.0), rng.randf_range(-0.4, 0.4)) * amp


## 피격 색: 처음 flash_white 초는 밝게 번쩍, 그다음 붉은 기가 flash_time 동안 빠진다.
func _hit_tint(hid: String) -> Color:
	var e := _hit_elapsed(hid)
	if e < 0.0:
		return Color.WHITE
	var h: Dictionary = _hits[hid]
	if e < h["white"]:
		return HIT_WHITE
	var k := 1.0 - (e - float(h["white"])) / maxf(float(h["flash"]), 0.001)
	if k <= 0.0:
		if e >= h["shake"]:
			_hits.erase(hid)
		return Color.WHITE
	return Color.WHITE.lerp(HIT_RED, k * float(h["red"]))


func set_stage(zone: int, stage: int) -> void:
	stage_label.text = "W%d - S%d" % [zone, stage]


func set_hero(hid: String, hp_ratio: float, mana_ratio: float, full: bool, alive: bool, stat: String, ult_ratio := 0.0, ult_full := false, level := 1, sp := 0) -> void:
	var s: Dictionary = _state[hid]
	var f: Dictionary = _fx[hid]
	if level > int(s["level"]):
		f["lv_t"] = 0.0                  # 레벨 배지가 톡 튄다
	s["level"] = level
	s["sp"] = sp
	if hp_ratio < float(s["hp"]) - 0.0001:
		f["hold"] = VDUnit.GHOST_FLASH   # 잔상: 흰색으로 번쩍한 뒤 주황으로 일정하게 줄어든다
	elif hp_ratio > float(s["hp"]) + 0.002:
		f["heal"] = 1.0                  # 회복: 바·카드가 초록빛으로 번쩍
	s["hp"] = hp_ratio
	s["mana"] = mana_ratio
	s["full"] = full
	s["alive"] = alive
	s["stat"] = stat
	if ult_full and not s["ult_full"]:
		f["ult_t"] = 0.0             # 궁극기 준비: 카드가 번쩍
	s["ult"] = ult_ratio
	s["ult_full"] = ult_full


## 카드가 톡 튀어나온다 (READY 0.6 · 궁극기 1.0).
func pop_card(hid: String, k := 1.0) -> void:
	if _fx.has(hid):
		_fx[hid]["pop"] = 1.0
		_fx[hid]["pop_k"] = k


## 영웅이 쓰러짐: 카드가 크게 흔들리며 금이 가고 '전투 불능' 도장이 쾅.
func card_down(hid: String) -> void:
	if _fx.has(hid):
		_fx[hid]["down_t"] = 0.0
		_hits[hid] = {"t0": Time.get_ticks_usec(), "seed": randi(), "amp": 22.0, "shake": 0.5, "fps": 24.0,
			"white": 0.06, "flash": 0.35, "red": 1.0}


## 새 판: 도장·잔상 초기화.
func reset_cards() -> void:
	for hid in _fx:
		_fx[hid] = {"ghost": 1.0, "shown": 1.0, "hold": 0.0, "heal": 0.0, "pop": 0.0, "pop_k": 1.0, "lift": 0.0, "down_t": -1.0, "ult_t": -1.0, "lv_t": -1.0}


## 전투 입장 애니메이션 (시각적 위계 순): 상단 바 → 명판·스테이지 글자(위에서) → 하단 띠(아래에서 스르륵) →
## 우측 뒷패널(오른쪽에서) → 분대 카드가 왼쪽부터 한 장씩 아래에서 튀어 올라온다. t0 = 첫 조각이 움직이기 시작하는 시각(초).
## 카드가 모두 자리를 잡는 시각을 돌려준다 (VDBattle 이 뒤 조각 타이밍에 쓴다).
func play_intro(t0 := 0.0) -> float:
	UIIntro.slide(_top_bar, UIIntro.FROM_TOP, t0, 0.5, 140.0)
	UIIntro.slide(_top_plate, UIIntro.FROM_TOP, t0 + 0.1, 0.5, 160.0)
	UIIntro.slide(stage_label, UIIntro.FROM_TOP, t0 + 0.18, 0.45, 90.0)
	UIIntro.slide(_shade, UIIntro.FROM_BOTTOM, t0 + 0.05, 0.6, 120.0, true, UIIntro.Ease.QUINT)
	UIIntro.slide(_panel, UIIntro.FROM_RIGHT, t0 + 0.2, 0.6, 260.0, true, UIIntro.Ease.QUINT)
	var card_t0 := t0 + 0.3
	var step := 0.09
	for i in _heroes.size():
		_fx[_heroes[i]]["in_t"] = -(card_t0 + step * i)
	return card_t0 + step * (_heroes.size() - 1) + INTRO_SEC


## 카드 입장 진행 (1 = 아직 화면 밖, 0 = 제자리). 탄성 곡선으로 살짝 넘치고 돌아온다.
static func _intro_k(f: Dictionary) -> float:
	if not f.has("in_t"):
		return 0.0
	var t: float = f["in_t"]
	if t <= 0.0:
		return 1.0
	if t >= INTRO_SEC:
		return 0.0
	return 1.0 - UIIntro.back_out(t / INTRO_SEC)


func _process(_dt: float) -> void:
	var now_us := Time.get_ticks_usec()
	var dt := clampf((now_us - _clock_us) / 1000000.0, 0.0, 0.1) if _clock_us > 0 else 0.0
	_clock_us = now_us
	for i in _heroes.size():
		var hid: String = _heroes[i]
		var f: Dictionary = _fx[hid]
		var hp: float = _state[hid]["hp"]
		# HP 바 (TrioChess 방식): 채움은 빠르게 스르륵, 잔상은 번쩍인 뒤 일정한 속도로 따라 내려온다
		f["shown"] = lerpf(f["shown"], hp, 1.0 - exp(-dt * 25.0))
		if f["ghost"] < hp:
			f["ghost"] = hp
		elif f["ghost"] > hp:
			f["hold"] -= dt
			if f["hold"] <= 0.0:
				f["ghost"] = move_toward(f["ghost"], hp, dt * VDUnit.HP_DRAIN)
		f["heal"] = maxf(0.0, f["heal"] - dt * 2.5)
		f["pop"] = maxf(0.0, f["pop"] - dt * 2.4)
		var lift_to := 1.0 if (i == _hover_card and _state[hid]["alive"]) else 0.0
		f["lift"] = lerpf(f["lift"], lift_to, 1.0 - exp(-dt * 16.0))
		if f["down_t"] >= 0.0:
			f["down_t"] += dt
		if f["ult_t"] >= 0.0:
			f["ult_t"] += dt
		if f["lv_t"] >= 0.0:
			f["lv_t"] += dt
		if f.has("in_t"):
			if f["in_t"] < INTRO_SEC:
				f["in_t"] += dt    # 입장 (음수 = 대기 시간, 실제 시간)
			else:
				f.erase("in_t")
		# 궁극기 준비 불꽃: 차면 확 타오르고(막 찼을 땐 잠깐 더 세게), 쓰거나 쓰러지면 사그라든다. 수치는 CardFlameFx (연출 연구실)
		var want := 1.0 if (_state[hid]["ult_full"] and _state[hid]["alive"]) else 0.0
		var since: float = f["ult_t"]
		var flare_sec := CardFlameFx.g("flare_sec")
		if want > 0.0 and since >= 0.0 and since < flare_sec:
			want = 1.0 + CardFlameFx.g("flare") * (1.0 - since / flare_sec)
		_flame_k[hid] = move_toward(_flame_k[hid], want, dt * (CardFlameFx.g("fade_in") if want > _flame_k[hid] else CardFlameFx.g("fade_out")))
		var fl: Node2D = _flames[hid]
		if _flame_ver != CardFlameFx.version:
			CardFlameFx.apply(fl.material)
		fl.visible = _flame_k[hid] > 0.01
		if fl.visible:
			(fl.material as ShaderMaterial).set_shader_parameter("intensity", _flame_k[hid])
	_flame_ver = CardFlameFx.version
	cards.queue_redraw()
	_bars.transform = cards.get_global_transform_with_canvas()
	_bars.queue_redraw()


# ---------------------------------------------------------------- cards

func _card_rect(i: int) -> Rect2:
	var r: Rect2 = Layout.CARD_RECTS[i]
	return Rect2(r.position - ORIGIN, r.size)


## 패널 텍스처 좌표 → 카드 컨트롤 좌표
func _tp(i: int, p: Vector2) -> Vector2:
	var r := _card_rect(i)
	return r.position + p * (r.size / PANEL_TEX)


## 에너지바 (시안 화면 컨셉_3 '에너지바'): 카드 위에 걸친 한 틀 안에 HP(위 초록 띠)와 마나(아래 파란 띠).
## 틀 텍스처 위에 흰 마스크를 비율만큼 왼쪽부터 잘라 채움 색으로 그린다. 좌표는 PSB px → 카드 패널 → 카드 변환.
## 불꽃 층의 _bars 에 그린다 (카드는 HUD 층이라 불꽃 아래, 바는 불꽃 위).
func _draw_bars() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in _heroes.size():
		var hid: String = _heroes[i]
		_draw_energy(_bars, _card_rect(i), _state[hid], _fx[hid], t, _card_xform(i))
	_bars.draw_set_transform(Vector2.ZERO)


## 카드 하나의 그리기 변환: 피격 흔들림 + 호버 떠오름 + pop (카드 가운데 기준 배율). 카드·불꽃·바가 같이 쓴다.
func _card_xform(i: int) -> Transform2D:
	var hid: String = _heroes[i]
	var f: Dictionary = _fx[hid]
	var pk: float = f["pop"]
	var osc := sin((1.0 - pk) * PI * 3.0) * pk * pk * 0.16 * float(f["pop_k"])
	var scl: Vector2 = Vector2.ONE * (1.0 + 0.03 * f["lift"]) * Vector2(1.0 + osc, 1.0 + osc * 0.6)
	var off: Vector2 = _shake(hid) + Vector2(0, -12.0 * f["lift"] - 26.0 * pk * pk * float(f["pop_k"]))
	var ik := _intro_k(f)
	if ik > 0.0:
		off.y += INTRO_DROP * ik     # 입장: 아래에서 올라온다 (바·슬롯·불꽃·배지가 같은 변환을 쓰므로 함께)
	var rot := 0.0
	var ut: float = f["ult_t"]
	if ut >= 0.0 and ut < ULT_PINCH_SEC:
		var e := 1.0 - ut / ULT_PINCH_SEC
		e *= e
		var p := sin(ut * TAU * ULT_PINCH_HZ) * ULT_PINCH_AMP * e
		scl *= Vector2(1.0 + p, 1.0 - p)
		rot = sin(ut * TAU * ULT_PINCH_HZ * 0.7 + 1.3) * ULT_PINCH_TWIST * e
	var c := _card_rect(i).get_center()
	return Transform2D(rot, scl, 0.0, c + off) * Transform2D(0.0, -c)


func _draw_energy(ci: CanvasItem, r: Rect2, s: Dictionary, f: Dictionary, t: float, card_xf: Transform2D) -> void:
	var k := float(Energy.TEX_SCALE)
	ci.draw_set_transform_matrix(card_xf * Transform2D(0.0, r.size / PANEL_TEX, 0.0, r.position) * Energy.XF * Transform2D(0.0, Vector2(1.0 / k, 1.0 / k), 0.0, Vector2.ZERO))
	var dim := Color.WHITE if s["alive"] else Color(0.55, 0.52, 0.62)
	ci.draw_texture(cached(Energy.FRAME), Vector2.ZERO, dim)
	# 마나: 가득 차면 밝게 숨쉰다 (READY)
	var mp_col: Color = Energy.MP_FILL
	if s["full"]:
		mp_col = mp_col.lerp(Color(0.62, 0.88, 1.0), 0.45 + 0.35 * sin(t * 7.0))
	_energy_band(ci, Energy.MP_MASK, Energy.MP_X, s["mana"], mp_col * dim)
	# HP: 잔상(흰→주황) 위에 실제 HP. 체력이 낮으면 노랑 → 빨강, 회복 순간엔 밝은 초록
	if f["ghost"] > f["shown"]:
		_energy_band(ci, Energy.HP_MASK, Energy.HP_X, f["ghost"], VDUnit.ghost_col(f["hold"]))
	var hp_col := VDUnit.hp_tint(s["hp"], Energy.HP_FILL)
	_energy_band(ci, Energy.HP_MASK, Energy.HP_X, f["shown"], hp_col.lerp(Color(0.85, 1.0, 0.8), f["heal"]) * dim)


func _energy_band(ci: CanvasItem, mask: String, band_x: Vector2, ratio: float, col: Color) -> void:
	if ratio <= 0.0:
		return
	var tex := cached(mask)
	var k := float(Energy.TEX_SCALE)
	# 가득이면 띠 끝 안티에일리어싱까지 전부
	var w: float = float(tex.get_width()) if ratio >= 0.999 else lerpf(band_x.x, band_x.y, clampf(ratio, 0.0, 1.0)) * k
	var rr := Rect2(0.0, 0.0, w, tex.get_height())
	ci.draw_texture_rect_region(tex, rr, rr, col)


## 아이템 슬롯 하나 (시안 슬롯 + 아이콘). 좌측 턴테이블도 같이 쓴다. scl 1 = 카드 슬롯 크기.
## 그리기 명령은 텍스처 RID 만 들고 가므로, 그리는 동안 해제되지 않게 참조를 붙들어 둔다 (안 그러면 흰 사각형).
static var _tex_cache := {}


static func cached(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


static func draw_slot(ci: CanvasItem, center: Vector2, scl: float, id: String, hovered: bool) -> void:
	var tex_slot := cached(Layout.DIR + "item_slot.png")
	var sz := tex_slot.get_size() / float(Layout.SLOT_TEX_SCALE) * scl
	var mod := Color(1.25, 1.2, 1.4) if hovered else Color.WHITE
	ci.draw_texture_rect(tex_slot, Rect2(center - Layout.SLOT_PIVOT * scl, sz), false, mod)
	var tex: Texture2D = cached(Layout.DIR + id + ".png") if Items.ITEMS.has(id) else null
	if tex != null:
		var box: Vector2 = Layout.ITEM_ICON_SIZE.get(id, Vector2(32, 32)) * scl
		var k := minf(box.x / tex.get_width(), box.y / tex.get_height())
		var isz := tex.get_size() * k
		ci.draw_texture_rect(tex, Rect2(center - isz * 0.5, isz), false)


func _draw_cards() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in _heroes.size():
		var hid: String = _heroes[i]
		var s: Dictionary = _state[hid]
		var r := _card_rect(i)
		var tex: Texture2D = _card_tex[hid]
		# 피격 흔들림: 카드·바·슬롯을 통째로 옮긴다
		var f: Dictionary = _fx[hid]
		# 호버: 살짝 떠오름 / pop: 크게 튀었다 감쇠 진동으로 가라앉음 (카드 가운데 기준 배율)
		var pk: float = f["pop"]
		var card_xf := _card_xform(i)
		cards.draw_set_transform_matrix(card_xf)
		# 궁극기 준비 불꽃은 카드와 같은 변환으로 (카드가 튀고 흔들리면 같이)
		var fl: Node2D = _flames[hid]
		fl.transform = cards.get_global_transform_with_canvas() * card_xf * Transform2D(0.0, r.position)
		var tint := _hit_tint(hid) if s["alive"] else Color(0.42, 0.4, 0.5)
		if f["heal"] > 0.0:
			tint = tint.lerp(Color(1.2, 1.6, 1.2), f["heal"] * 0.5)
		if f["lift"] > 0.01:
			tint = tint * Color(1.0 + 0.12 * f["lift"], 1.0 + 0.12 * f["lift"], 1.0 + 0.15 * f["lift"])
		cards.draw_texture_rect(tex, r, false, tint)
		if pk > 0.5:
			cards.draw_texture_rect(tex, r, false, Color(2.0, 1.9, 1.4, (pk - 0.5) * 0.9))
		# 궁극기 막 참: 순백 섬광 (밝게 곱해 하얗게 날린다 — 검은 외곽선은 남아 실루엣이 읽힌다)
		var ut: float = f["ult_t"]
		if s["alive"] and ut >= 0.0 and ut < ULT_FLASH_SEC:
			var a := 1.0 - clampf((ut - ULT_FLASH_HOLD) / (ULT_FLASH_SEC - ULT_FLASH_HOLD), 0.0, 1.0)
			cards.draw_texture_rect(tex, r, false, Color(8.0, 8.0, 8.0, pow(a, 1.6)))
		# 에너지바는 _draw_bars 가 불꽃 위 층에 그린다
		if s["alive"]:
			_draw_ult_badge(i, r, t, s, float(f["ult_t"]), card_xf)
		_draw_level_badge(r, s, float(f["lv_t"]), t)
		var slots: Array = Layout.CARD_SLOTS[i]
		for j in slots.size():
			draw_slot(cards, slots[j] - ORIGIN, 1.0, _items[hid][j], _hover_slot == Vector2i(i, j))
		if f["down_t"] >= 0.0:
			_draw_down(r, float(f["down_t"]), i, card_xf)
		cards.draw_set_transform(Vector2.ZERO)


## 쓰러진 카드: 금(지그재그 선 두 줄)이 쭉 그어지고, 붉은 '전투 불능' 도장이 크게 떨어져 쾅 박힌다.
func _draw_down(r: Rect2, t: float, seed_i: int, card_xf: Transform2D) -> void:
	var crack := clampf(t / 0.18, 0.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + seed_i
	for line in 2:
		var pts := PackedVector2Array()
		var a := r.position + Vector2(r.size.x * rng.randf_range(0.2, 0.5), r.size.y * 0.12)
		var dir := Vector2(rng.randf_range(0.1, 0.5) * (1.0 if line == 0 else -1.0), 1.0).normalized()
		pts.append(a)
		var steps := 6
		for k in steps:
			if float(k + 1) / steps > crack:
				break
			a += dir * r.size.y * 0.13 + Vector2(rng.randf_range(-12, 12), 0)
			pts.append(a)
		if pts.size() > 1:
			cards.draw_polyline(pts, Color(0.05, 0.0, 0.08, 0.9), 4.0)
			cards.draw_polyline(pts, Color(1.0, 0.85, 0.9, 0.7), 1.5)
	var st := clampf((t - 0.12) / 0.16, 0.0, 1.0)
	if st <= 0.0:
		return
	var s := lerpf(2.6, 1.0, st * st)
	var a := minf(1.0, st * 2.0)
	var c := r.get_center() + Vector2(0, -6)
	var font := VDData.font()
	var txt := "전투 불능"
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, STAMP_FONT_SIZE).x
	var xf := Transform2D(-0.22, Vector2(s, s), 0.0, c)
	cards.draw_set_transform_matrix(card_xf * xf)
	var box := Rect2(Vector2(-w * 0.5 - 14, -STAMP_FONT_SIZE * 0.8), Vector2(w + 28, STAMP_FONT_SIZE * 1.3))
	cards.draw_rect(box, Color(0.95, 0.2, 0.3, 0.18 * a))
	cards.draw_rect(box, Color(0.95, 0.2, 0.3, 0.95 * a), false, 4.0)
	cards.draw_string_outline(font, Vector2(-w * 0.5, STAMP_FONT_SIZE * 0.32), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, STAMP_FONT_SIZE, 8, Color(0.15, 0.0, 0.05, a))
	cards.draw_string(font, Vector2(-w * 0.5, STAMP_FONT_SIZE * 0.32), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, STAMP_FONT_SIZE, Color(1.0, 0.35, 0.42, a))


func _hit_slot(p: Vector2) -> Vector2i:
	for i in _heroes.size():
		var slots: Array = Layout.CARD_SLOTS[i]
		for j in slots.size():
			if (slots[j] - ORIGIN).distance_to(p) < 20.0:
				return Vector2i(i, j)
	return Vector2i(-1, -1)


func _hit_card(p: Vector2) -> int:
	for i in range(_heroes.size() - 1, -1, -1):
		var r := _card_rect(i)
		# 기울어진 패널: 모서리 대신 가운데 70% 사각형으로 충분
		if r.grow_individual(-r.size.x * 0.05, -r.size.y * 0.12, -r.size.x * 0.05, -r.size.y * 0.1).has_point(p):
			return i
	return -1


## 카드 위 한 점(화면·캔버스 좌표) — 궁극기 조준 화살표가 여기서 나간다.
func card_anchor(hid: String) -> Vector2:
	var i := _heroes.find(hid)
	if i < 0:
		return Vector2.ZERO
	var r := _card_rect(i)
	return cards.get_global_transform_with_canvas() * Vector2(r.get_center().x, r.position.y + r.size.y * 0.3)


## 화면·캔버스 좌표 p 에 있는 카드의 영웅 id (없으면 "").
func card_at(p: Vector2) -> String:
	var ci := _hit_card(cards.get_global_transform_with_canvas().affine_inverse() * p)
	return _heroes[ci] if ci >= 0 else ""


## 부활: 금·'전투 불능' 도장을 걷어 내고 카드가 톡 튄다.
func card_up(hid: String) -> void:
	if _fx.has(hid):
		_fx[hid]["down_t"] = -1.0
		pop_card(hid, 1.0)


func _cards_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pi := _hit_card(event.position)
		if pi >= 0 and _hit_slot(event.position).x < 0:
			cards.accept_event()
			card_pressed.emit(_heroes[pi])
		return
	if not (event is InputEventMouseMotion):
		return
	var p: Vector2 = event.position
	_hover_slot = _hit_slot(p)
	if _hover_slot.x >= 0:
		cards.tooltip_text = Items.tooltip(_items[_heroes[_hover_slot.x]][_hover_slot.y])
		return
	var ci := _hit_card(p)
	_hover_card = ci
	if ci < 0:
		cards.tooltip_text = ""
		return
	var hid: String = _heroes[ci]
	var sk: Dictionary = VDData.SKILLS[hid]
	var ud: Dictionary = VDData.ULTS[hid]
	cards.tooltip_text = "%s\n%s\n★ 고유 스킬 %s — %s\n✦ 궁극기 %s — %s\n   (궁극기 게이지가 차면 카드를 탭)" % [VDData.HEROES[hid]["name"], _state[hid]["stat"], sk["name"], sk["desc"], ud["name"], ud["desc"]]


## 궁극기 게이지 배지: 카드 왼쪽 위 원형 게이지(분홍 호가 차오른다). 가득 차면 금빛으로 숨쉬고 막 찼을 땐(since = ult_t) 크게 튄다.
## 카드 둘레가 타오르는 황금 불꽃은 _make_flame (card_ult_flame 셰이더).
const ULT_BADGE := Vector2(54, 64)       # 패널 텍스처 px (위쪽 에너지바 왼쪽 끝을 가리지 않게)
const ULT_BADGE_R := 21.0


## 레벨 배지 (시안 카드 오른쪽 아래 "LV.2"): 어두운 알약 + 흰 기울임 글자. 레벨이 오르면 금빛으로 톡 튄다.
## SP 가 남아 있으면(배치 단계) 카드 오른쪽 위에 붉은 점 + 숫자: 스킬창에서 쓰라는 신호 (기획서의 'SP 뱃지').
static var _lv_box: StyleBoxFlat
static var _sp_box: StyleBoxFlat


func _draw_level_badge(r: Rect2, s: Dictionary, since: float, t: float) -> void:
	if _lv_box == null:
		_lv_box = StyleBoxFlat.new()
		_lv_box.bg_color = Color(0.12, 0.06, 0.2, 0.92)
		_lv_box.border_color = Color(0.55, 0.4, 0.8, 0.9)
		_lv_box.set_border_width_all(2)
		_lv_box.set_corner_radius_all(9)
		_sp_box = StyleBoxFlat.new()
		_sp_box.bg_color = Color("ff4d5e")
		_sp_box.border_color = Color(1, 1, 1, 0.9)
		_sp_box.set_border_width_all(2)
		_sp_box.set_corner_radius_all(12)
	var pop := clampf(1.0 - since * 2.2, 0.0, 1.0) if since >= 0.0 else 0.0
	var sz := Vector2(58.0, 24.0) * (1.0 + 0.35 * pop)
	var badge := Rect2(r.end - sz - Vector2(12.0, 30.0), sz)
	cards.draw_style_box(_lv_box, badge)
	if pop > 0.0:
		cards.draw_rect(badge, Color(1.0, 0.9, 0.5, pop * 0.7))
	var dim := Color.WHITE if s["alive"] else Color(0.6, 0.58, 0.68)
	cards.draw_string(VDData.font(), badge.position + Vector2(0, sz.y * 0.72), "LV.%d" % int(s["level"]), HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(14 * (1.0 + 0.35 * pop)), dim)
	var sp := int(s["sp"])
	if sp > 0 and s["alive"]:
		var k := 0.5 + 0.5 * sin(t * 5.0)
		var dot := Rect2(r.position + Vector2(r.size.x - 30.0, 6.0 - 2.0 * k), Vector2(24.0, 24.0))
		cards.draw_circle(dot.get_center(), 16.0 + 3.0 * k, Color(1.0, 0.3, 0.4, 0.25 + 0.15 * k))
		cards.draw_style_box(_sp_box, dot)
		cards.draw_string(VDData.font(), dot.position + Vector2(0, 17.0), str(sp), HORIZONTAL_ALIGNMENT_CENTER, dot.size.x, 13, Color.WHITE)


func _draw_ult_badge(i: int, r: Rect2, t: float, s: Dictionary, since: float, card_xf: Transform2D) -> void:
	var full: bool = s["ult_full"]
	var pop := clampf(1.0 - since * 3.0, 0.0, 1.0) if (full and since >= 0.0) else 0.0
	var k := 0.5 + 0.5 * sin(t * 6.0)
	var gold := Color(1.0, 0.84, 0.3)
	var ctr := _tp(i, ULT_BADGE)
	var rad := ULT_BADGE_R * (1.0 + 0.35 * pop * pop + (0.06 * k if full else 0.0))
	if full:
		cards.draw_circle(ctr, rad + 7.0 + 4.0 * k, Color(gold, 0.18 + 0.15 * k))
	cards.draw_circle(ctr, rad + 3.0, Color(0.05, 0.02, 0.09, 0.92))
	cards.draw_arc(ctr, rad - 2.0, 0.0, TAU, 40, Color(1, 1, 1, 0.12), 5.0, true)
	var ratio := clampf(float(s["ult"]), 0.0, 1.0)
	if ratio > 0.0:
		cards.draw_arc(ctr, rad - 2.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 40, gold if full else Color(1.0, 0.5, 0.82), 5.0, true)
	# 가운데 별: 차오를수록 밝아진다
	var sr := rad * 0.55
	var star := PackedVector2Array()
	for q in 8:
		var a := TAU * q / 8.0 - PI * 0.5
		star.append(ctr + Vector2(cos(a), sin(a)) * (sr if q % 2 == 0 else sr * 0.38))
	cards.draw_colored_polygon(star, gold.lerp(Color(1, 1, 0.9), k) if full else Color(0.55, 0.45, 0.65).lerp(Color(1.0, 0.7, 0.9), ratio))
	# 준비됐다는 표시는 카드 윤곽의 황금 불꽃(card_ult_flame)이 맡는다


## 궁극기 준비 불꽃 한 장: 카드 윤곽 거리장(SDF)을 카드보다 넓은 사각형에 그리고 card_ult_flame 셰이더가 윤곽 둘레 불꽃을 만든다.
## 위치·배율은 _draw_cards 가 카드 변환과 같게 맞춘다 (원점 = 카드 왼쪽 위).
func _make_flame(i: int) -> Node2D:
	var sdf: Texture2D = load(FLAME_SDF_DIR + String(HERO_PANEL[_heroes[i]]).get_file())
	var sz := _card_rect(i).size
	var pad := FLAME_PAD_TEX * (sz / PANEL_TEX)
	var n := Node2D.new()
	var m := ShaderMaterial.new()
	m.shader = FlameShader
	m.set_shader_parameter("tex_size", sdf.get_size())
	m.set_shader_parameter("intensity", 0.0)
	CardFlameFx.apply(m)
	n.material = m
	n.visible = false
	n.draw.connect(func() -> void: n.draw_texture_rect(sdf, Rect2(-pad, sz + pad * 2.0), false))
	_flame_layer.add_child(n)
	return n


## 막 찬 것처럼 다시 확 타오르게 (연출 연구실 재생).
func reignite(hid: String) -> void:
	if _fx.has(hid):
		_fx[hid]["ult_t"] = 0.0
