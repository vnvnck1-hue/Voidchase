## 캐릭터 턴테이블 (전투 HUD 좌측 하단). 애니메이션이 잘 된 스탠딩 넷을 타원 위에 둥글게 세우고, 선택한 캐릭터가 앞(크고 밝게),
## 나머지는 뒤(작고 딤드)로 돌아간다. 클릭·◀ ▶ 버튼·휠·Tab(Shift+Tab 은 반대)으로 돌린다. 임시 로스터는 캐릭터 선택 씬(Touch_Game_demo_anim.tscn)의
## StandingCharacter 데이터와 같다: 스틸(절차 숨쉬기 idle) / idle 스프라이트 시트 / 올리비아 본 리그(자체 AnimationPlayer idle).
##   출처: scenes/Touch_Game_demo_anim.tscn 의 stand_character (tools/expand/apply_standing.py 가 쓴 값).
##   올리비아 리그는 그 씬에서 tools/rig/extract_olivia_rig.gd 로 떼어 낸 scenes/characters/olivia_rig.tscn.
class_name VDTurntable
extends Control

signal selected_changed(index: int)
signal front_pressed(index: int)          # 이미 앞에 있는 캐릭터를 눌렀다 (VDBattle 이 스킬창을 연다/닫는다)

const OLIVIA_RIG := "res://scenes/characters/olivia_rig.tscn"
## 스킬 SP 알림 외곽선 (생성물: tools/shaders/build_sp_alert.gd). 쓸 SP 가 있는 캐릭터 실루엣이 금빛 네온으로 숨쉬고 스캔 띠가 훑는다.
const AlertShader := preload("res://shaders/sp_alert_outline.tres")
const ALERT_LINE_PX := 3.5                # 외곽선 두께 (디자인 px)
const ALERT_GLOW_PX := 9.0                # 선 바깥 글로우 폭
const ALERT_FADE := 5.0                   # 켜고 끄는 빠르기 (1/초)
const ALERT_BACK := 0.7                   # 뒤 캐릭터의 선 세기 (앞 = 1)
## 리그는 파츠마다 z 가 달라 한 장으로 합쳐야 실루엣 외곽선을 그릴 수 있다 → 서브뷰포트에 그려 그 텍스처를 Sprite2D 로 보여 준다.
const RIG_VP := Vector2(560, 620)         # 서브뷰포트 크기 (디자인 px, 앞 캐릭터 크기 기준)
const RIG_FOOT := Vector2(280, 590)       # 그 안의 발 위치
const Frame := preload("res://scripts/void_defense/vd_battle_frame.gd")
const UILayout := preload("res://scripts/void_defense/vd_battle_ui_layout.gd")
const Items := preload("res://scripts/void_defense/vd_items.gd")
const PIN := Rect2(0, 600, 620, 480)        # 디자인 좌표에서 이 컨트롤의 자리 (시안 좌표 - PIN.position = 로컬)
const LAVA := Color(0.17, 0.1, 0.32, 0.6)    # 좌측 뒷패널: 시안의 어두운 언덕 위로 더 어두운 보라 방울이 일렁인다
const LAVA_DARK := Color(0.0, 0.0, 0.0, 0.55)
## 스탠딩은 약 1800px 높이 원화. scale 은 StandingCharacter 의 pixel_scale/texture_scales 와 같다 (화면 ~576px).
const ROSTER := [
	# 애니메이션이 제대로 된 넷만: 올리비아 본 리그 1 + idle 시트 2 + 스틸(숨쉬기) 1
	# hero = 이 스탠딩이 맡는 분대 영웅 (분대 카드 초상과 같은 그림: tools/expand/make_portraits.py). 스킬창·SP 알림이 이 id 로 이어진다
	{"name": "올리비아", "hero": "mage", "rig": OLIVIA_RIG, "scale": 0.32},
	{"name": "캐릭터 2", "hero": "healer", "sheet": "res://assets/textures/standing/char_02_idle.png", "grid": Vector2i(8, 8), "count": 57, "fps": 10.0, "scale": 0.911},
	{"name": "캐릭터 4", "hero": "knight", "sheet": "res://assets/textures/standing/char_07_idle.png", "grid": Vector2i(7, 6), "count": 37, "fps": 10.0, "scale": 1.0622},
	{"name": "캐릭터 1", "hero": "gunner", "tex": "res://assets/textures/standing/char_01.png", "scale": 0.32},
]

const CENTER := Vector2(270.0, 410.0)     # 타원 중심 (컨트롤 로컬, 발 기준). 목업: 앞 캐릭터 x≈230
const RADIUS := Vector2(135.0, 44.0)      # 타원 반지름 (가로, 세로)
const FRONT_SCALE := 0.78                 # 앞 캐릭터 배율 (스탠딩 576px × 0.78 ≈ 450px)
const BACK_SCALE := 0.62                  # 뒤 캐릭터는 앞의 80~85% (목업 비율)
const DIM := Color(0.28, 0.2, 0.46)       # 뒤 캐릭터 틴트 (남보라 딤드)
const IDLE_PERIOD := 2.5333               # 리그 idle 과 같은 주기 (StandingCharacter 와 동일)
const TURN_SEC := 0.225                  # 한 칸 도는 시간 (0.45 → 2배 빠르게)
## 그리기 순서: 캐릭터마다 겹치지 않는 z 구간을 깊이 순위로 준다. 리그는 파츠마다 z(올리비아 1~18)를 써서
## 깊이 × 50 같은 연속 값을 주면 뒤에 있는 리그의 파츠가 앞 캐릭터 위로 튀어나온다.
const Z_BASE := 10
const Z_BAND := 40                        # 리그 파츠 z(최대 31)보다 넉넉히
const Z_TOP := Z_BASE + 4 * Z_BAND        # 캐릭터들 위: 슬롯·버튼·이름

var selected := 1                          # 시안처럼 멜빵바지 캐릭터(캐릭터 2)가 앞
var _angle := 0.0                          # 턴테이블 회전 (선택 캐릭터가 앞에 오게 트윈)
var _items: Array[Dictionary] = []        # {node, kind, sprite, scale, t}
var _tween: Tween
var _name: Label
var _btn_prev: Button
var _btn_next: Button
var _hover := -1
var _clock_us := 0                       # 배속(Engine.time_scale)과 무관하게 실제 시간으로 재생
var _slots := {}                         # 로스터 번호 -> 아이템 3칸 (시안 예시는 앞 캐릭터에)
var _strip: Control
var _hover_slot := -1
var _glow: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	SceneSwitcher.pin(self, Vector2(0, 1), PIN)
	_build_backdrop()
	for i in ROSTER.size():
		_items.append(_make_item(ROSTER[i]))
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 26)
	_name.add_theme_color_override("font_color", Color(1, 1, 1))
	_name.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.35))
	_name.add_theme_constant_override("outline_size", 8)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name.position = Vector2(24, 6)   # 왼쪽 위: 앞 캐릭터 머리(가운데)와 겹치지 않는다
	_name.size = Vector2(300, 36)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.z_index = Z_TOP + 10
	add_child(_name)
	for i in ROSTER.size():
		_slots[i] = Items.mock_slots("left") if i == 1 else Items.mock_slots(-1)
	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.z_index = Z_TOP
	_strip.size = PIN.size
	_strip.draw.connect(_draw_slots)
	add_child(_strip)
	_btn_prev = _arrow("◀", Vector2(16, 404), -1)
	_btn_next = _arrow("▶", Vector2(520, 404), 1)
	_angle = _target_angle(selected)
	_layout(true)


## 시안의 좌측 하단: 어두운 언덕 패널(라바램프로 일렁임) + 바닥 그림자 타원 + 빛줄기(더하기 합성).
func _build_backdrop() -> void:
	var o := PIN.position
	var panel := TextureRect.new()
	panel.texture = load(UILayout.DIR + "panel_left.png")
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.position = UILayout.PANEL_LEFT_RECT.position - o
	panel.size = UILayout.PANEL_LEFT_RECT.size
	panel.material = Frame.lava_material(panel.size, LAVA, LAVA_DARK, 0.3, 7.0, 3.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = -1
	add_child(panel)
	var shadow := TextureRect.new()
	shadow.texture = load(UILayout.DIR + "left_shadow.png")
	shadow.position = UILayout.LEFT_SHADOW_RECT.position - o
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.z_index = -1
	add_child(shadow)
	var glow := TextureRect.new()
	glow.texture = load(UILayout.DIR + "left_glow.png")
	glow.position = UILayout.LEFT_GLOW_RECT.position - o
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	glow.z_index = Z_BASE + (ROSTER.size() - 1) * Z_BAND - 1   # 앞 캐릭터 바로 아래, 나머지 위 (_layout 에서 다시 맞춤)
	_glow = glow
	add_child(glow)


func _slot_at(p: Vector2) -> int:
	for j in UILayout.LEFT_SLOTS.size():
		if (UILayout.LEFT_SLOTS[j] - PIN.position).distance_to(p) < 20.0 * UILayout.LEFT_SLOT_SCALE:
			return j
	return -1


func _draw_slots() -> void:
	for j in UILayout.LEFT_SLOTS.size():
		Frame.draw_slot(_strip, UILayout.LEFT_SLOTS[j] - PIN.position, UILayout.LEFT_SLOT_SCALE, _slots[selected][j], j == _hover_slot)


func _arrow(text: String, pos: Vector2, step: int) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(60, 60)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 28)
	b.z_index = Z_TOP + 1
	b.pressed.connect(select_next.bind(step))
	add_child(b)
	return b


## 캐릭터 하나: 발이 원점인 Node2D 래퍼. 스틸/시트는 Sprite2D, 리그는 씬 인스턴스.
func _make_item(def: Dictionary) -> Dictionary:
	var wrap := Node2D.new()
	wrap.name = def["name"]
	add_child(wrap)
	var it := {"node": wrap, "kind": "still", "sprite": null, "scale": float(def["scale"]), "t": randf() * IDLE_PERIOD, "def": def,
		"alert": false, "alert_k": 0.0, "mat": null}
	if def.has("rig"):
		# 리그는 서브뷰포트에 그리고 그 텍스처를 Sprite2D 로 보여 준다 (발이 원점). 해상도는 _sync_rig_vp 가 창 배율에 맞춘다
		var vp := SubViewport.new()
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		wrap.add_child(vp)
		var rig: Node2D = (load(def["rig"]) as PackedScene).instantiate()
		vp.add_child(rig)
		var sp := Sprite2D.new()
		sp.centered = false
		sp.texture = vp.get_texture()
		wrap.add_child(sp)
		it["kind"] = "rig"
		it["sprite"] = sp
		it["rig"] = rig
		it["vp"] = vp
		it["ss"] = 0.0
		_sync_rig_vp(it)
		# 뷰포트 텍스처는 프리멀티플라이드라 늘 알림 재질로 그린다 (strength 0 이면 그림 그대로)
		_alert_material(it)
		# 리그 idle 도 실제 시간으로: AnimationPlayer 를 수동 모드로 두고 _process 에서 직접 advance
		var ap := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer   # 올리비아는 Skeleton/Spine_1 아래
		if ap:
			ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			it["anim"] = ap
	else:
		var sp := Sprite2D.new()
		sp.centered = false
		if def.has("sheet"):
			sp.texture = load(def["sheet"])
			sp.hframes = def["grid"].x
			sp.vframes = def["grid"].y
			it["kind"] = "sheet"
		else:
			sp.texture = load(def["tex"])
		sp.offset = Vector2(-sp.texture.get_width() / sp.hframes / 2.0, -float(sp.texture.get_height()) / sp.vframes)
		wrap.add_child(sp)
		it["sprite"] = sp
	return it


## 이 캐릭터의 알림 재질 (없으면 만든다). 캐릭터마다 프레임·배율이 달라 재질도 하나씩.
func _alert_material(it: Dictionary) -> ShaderMaterial:
	if it["mat"] == null:
		var m := ShaderMaterial.new()
		m.shader = AlertShader
		m.set_shader_parameter("premult", 1.0 if it["kind"] == "rig" else 0.0)
		it["mat"] = m
	(it["sprite"] as Sprite2D).material = it["mat"]
	return it["mat"]


## 리그 서브뷰포트 해상도를 창 배율에 맞춘다: 앞 캐릭터가 화면 px 과 1:1 이 되게 (창이 크면 선명하게, 작으면 가볍게).
func _sync_rig_vp(it: Dictionary) -> void:
	var ss := clampf(snappedf(get_viewport().get_final_transform().get_scale().x, 0.05), 0.5, 3.0)
	if is_equal_approx(ss, float(it["ss"])):
		return
	it["ss"] = ss
	var vp: SubViewport = it["vp"]
	vp.size = Vector2i((RIG_VP * ss).ceil())
	var rig: Node2D = it["rig"]
	rig.position = RIG_FOOT * ss
	rig.scale = Vector2.ONE * float(it["scale"]) * FRONT_SCALE * ss
	(it["sprite"] as Sprite2D).offset = -RIG_FOOT * ss


func hero_of(i: int) -> String:
	return String(ROSTER[posmod(i, ROSTER.size())].get("hero", ""))


func index_of_hero(hid: String) -> int:
	for i in ROSTER.size():
		if ROSTER[i].get("hero", "") == hid:
			return i
	return -1


## 스킬 SP 알림: 이 영웅의 스탠딩 외곽선을 켜고 끈다 (부드럽게 켜지고 꺼진다).
func set_alert(hid: String, on: bool) -> void:
	var i := index_of_hero(hid)
	if i >= 0 and i < _items.size():
		_items[i]["alert"] = on


func is_alerting(hid: String) -> bool:
	var i := index_of_hero(hid)
	return i >= 0 and i < _items.size() and bool(_items[i]["alert"])


func _target_angle(i: int) -> float:
	return -TAU * i / ROSTER.size()


func select(i: int) -> void:
	i = posmod(i, ROSTER.size())
	if i == selected and _tween == null:
		return
	selected = i
	# 가장 짧은 방향으로 돈다
	var target := _target_angle(i)
	var diff := fposmod(target - _angle + PI, TAU) - PI
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_angle", _angle + diff, TURN_SEC)
	_tween.tween_callback(func() -> void: _tween = null)
	selected_changed.emit(selected)


func select_next(step: int) -> void:
	select(selected + step)


func _process(_dt: float) -> void:
	if not is_visible_in_tree():
		_clock_us = 0
		return
	# 게임 배속·히트스탑·슬로모션과 무관하게 항상 기본 속도로 재생한다
	var now_us := Time.get_ticks_usec()
	var dt := clampf((now_us - _clock_us) / 1000000.0, 0.0, 0.1) if _clock_us > 0 else 0.0
	_clock_us = now_us
	for it in _items:
		it["t"] += dt
		if it.has("anim"):
			(it["anim"] as AnimationPlayer).advance(dt)
		if it.has("vp"):
			_sync_rig_vp(it)
		it["alert_k"] = move_toward(float(it["alert_k"]), 1.0 if it["alert"] else 0.0, dt * ALERT_FADE)
	_layout(false)


## 타원 위 배치: 각도 a 에서 cos(a)=1 이 맨 앞. depth 0(뒤)~1(앞) 로 크기·밝기·z 를 정한다.
func _layout(_force: bool) -> void:
	var n := _items.size()
	# 깊이 순위 (0 = 맨 뒤). 같은 깊이(옆으로 나란할 때)는 번호로 고정해 프레임마다 뒤바뀌지 않게 한다
	var order := range(n)
	order.sort_custom(func(x: int, y: int) -> bool:
		var dx := cos(_angle + TAU * x / n)
		var dy := cos(_angle + TAU * y / n)
		return dx < dy - 0.0001 or (absf(dx - dy) <= 0.0001 and x < y))
	var rank := {}
	for r in n:
		rank[order[r]] = r
	if _glow:
		_glow.z_index = Z_BASE + (n - 1) * Z_BAND - 1
	for i in n:
		var it := _items[i]
		var a := _angle + TAU * i / n
		var depth := (cos(a) + 1.0) * 0.5
		var pos := CENTER + Vector2(sin(a) * RADIUS.x, cos(a) * RADIUS.y)
		var node: Node2D = it["node"]
		var s := lerpf(BACK_SCALE, FRONT_SCALE, depth * depth) * float(it["scale"])
		node.position = pos
		node.z_index = Z_BASE + int(rank[i]) * Z_BAND
		var k := pow(depth, 4.0)   # 앞 하나만 밝고 옆(depth 0.5)·뒤는 딤드
		node.modulate = DIM.lerp(Color.WHITE, k)
		if i == _hover and i != selected:
			node.modulate = node.modulate.lightened(0.2)
		var spr := it["sprite"] as Sprite2D
		match it["kind"]:
			"sheet":
				spr.frame = int(float(it["t"]) * float(it["def"]["fps"])) % maxi(int(it["def"]["count"]), 1)
				spr.scale = Vector2(s, s)
			"rig":
				# 서브뷰포트는 앞 캐릭터 크기(× 창 배율)로 그려 두었다 → 깊이에 맞춰 줄여 보여 준다
				var rs := s / (float(it["scale"]) * FRONT_SCALE * maxf(float(it["ss"]), 0.01))
				spr.scale = Vector2(rs, rs)
			_:
				# 스틸: 숨쉬기 + 발을 축으로 한 느린 기울임 (StandingCharacter 와 같은 수치)
				var w := TAU * float(it["t"]) / IDLE_PERIOD
				var breath := sin(w)
				var sway := sin(w * 0.5 + 0.8)
				spr.scale = Vector2(s * (1.0 - 0.014 * 0.5 * breath), s * (1.0 + 0.014 * breath))
				spr.rotation = deg_to_rad(0.9) * sway
				spr.position = Vector2(2.0 * sway, 0.0)
		_sync_alert(it, spr, depth)
	_name.text = ROSTER[selected]["name"]
	if _strip:
		_strip.queue_redraw()


## SP 알림 재질 갱신. 알림이 켜져 있거나(사그라드는 중 포함) 리그면 재질로 그린다: 딤드는 modulate 대신 body_tint 로 넘겨
## 몸만 어두워지고 외곽선은 밝게 남는다 (뒤로 돌아가 있어도 눈에 띄게). 꺼지면 재질을 떼고 원래 modulate 로 돌아간다.
func _sync_alert(it: Dictionary, spr: Sprite2D, depth: float) -> void:
	var k := float(it["alert_k"])
	if k <= 0.0 and it["kind"] != "rig":
		if spr.material != null:
			spr.material = null
		return
	var m := _alert_material(it)
	var node: Node2D = it["node"]
	m.set_shader_parameter("body_tint", node.modulate)
	node.modulate = Color.WHITE
	var tex := spr.texture
	var tsz := Vector2(tex.get_size())
	if tsz.x < 1.0 or tsz.y < 1.0:
		return
	var fr := Vector4(0, 0, 1, 1)
	if spr.hframes > 1 or spr.vframes > 1:
		var fsz := Vector2(1.0 / spr.hframes, 1.0 / spr.vframes)
		var fo := Vector2(spr.frame_coords) * fsz
		fr = Vector4(fo.x, fo.y, fo.x + fsz.x, fo.y + fsz.y)
	var ppx := 1.0 / maxf(spr.scale.y, 0.0001)                 # 디자인 1px = 텍스처 몇 px
	var strength := k * lerpf(ALERT_BACK, 1.0, depth * depth)
	m.set_shader_parameter("frame_rect", fr)
	m.set_shader_parameter("quad_rect", fr)
	m.set_shader_parameter("tex_px", Vector2.ONE / tsz)
	m.set_shader_parameter("quad_tex_px", Vector2.ONE / tsz)
	m.set_shader_parameter("ppx", ppx)
	m.set_shader_parameter("quad_pad", (ALERT_LINE_PX + ALERT_GLOW_PX + 4.0) * ppx if k > 0.0 else 0.0)
	m.set_shader_parameter("outline_px", ALERT_LINE_PX)
	m.set_shader_parameter("glow_px", ALERT_GLOW_PX)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("t", fmod(Time.get_ticks_msec() * 0.001, 3600.0))


## 캐릭터 히트 상자: 발 위치에서 위로 높이 h, 폭 0.4h.
func _rect_of(i: int) -> Rect2:
	var it := _items[i]
	var node: Node2D = it["node"]
	var a := _angle + TAU * i / _items.size()
	var depth := (cos(a) + 1.0) * 0.5
	var h := 576.0 * lerpf(BACK_SCALE, FRONT_SCALE, depth * depth)
	return Rect2(node.position + Vector2(-h * 0.2, -h), Vector2(h * 0.4, h))


func item_at(p: Vector2) -> int:
	var best := -1
	var best_z := -1
	for i in _items.size():
		if _rect_of(i).has_point(p):
			var z: int = (_items[i]["node"] as Node2D).z_index
			if z > best_z:
				best_z = z
				best = i
	return best


## Tab: 다음 캐릭터, Shift+Tab: 이전. GUI 포커스 이동보다 먼저 받으려고 _input 에서 처리한다
## (입력칸에 글자를 치는 중이면 양보).
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB):
		return
	if not is_visible_in_tree():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	select_next(-1 if event.shift_pressed else 1)
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := item_at(event.position)
		if h != _hover:
			_hover = h
		_hover_slot = _slot_at(event.position)
		tooltip_text = Items.tooltip(_slots[selected][_hover_slot]) if _hover_slot >= 0 else ""
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var i := item_at(mb.position)
			if i >= 0:
				if i == selected:
					front_pressed.emit(i)   # 앞 캐릭터를 누름: 스킬창 열기/닫기
				else:
					select(i)
				accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and item_at(mb.position) >= 0:
			select_next(-1)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and item_at(mb.position) >= 0:
			select_next(1)
			accept_event()
