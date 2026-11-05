## 캐릭터 턴테이블 (전투 HUD 좌측 하단). 애니메이션이 잘 된 스탠딩 넷을 타원 위에 둥글게 세우고, 선택한 캐릭터가 앞(크고 밝게),
## 나머지는 뒤(작고 딤드)로 돌아간다. 클릭·◀ ▶ 버튼·휠로 돌린다. 임시 로스터는 캐릭터 선택 씬(Touch_Game_demo_anim.tscn)의
## StandingCharacter 데이터와 같다: 스틸(절차 숨쉬기 idle) / idle 스프라이트 시트 / 메이드 본 리그(자체 AnimationPlayer idle).
##   출처: scenes/Touch_Game_demo_anim.tscn 의 stand_character (tools/expand/apply_standing.py 가 쓴 값). 올리비아 리그(7번)는 그 씬 안에만 있어 뺐다.
class_name VDTurntable
extends Control

signal selected_changed(index: int)

const MAID_RIG := "res://scenes/characters/maid_rig.tscn"
## 스탠딩은 약 1800px 높이 원화. scale 은 StandingCharacter 의 pixel_scale/texture_scales 와 같다 (화면 ~576px).
const ROSTER := [
	# 애니메이션이 제대로 된 넷만: 본 리그 1 + idle 시트 2 + 스틸(숨쉬기) 1
	{"name": "메이드", "rig": MAID_RIG, "scale": 0.32},
	{"name": "캐릭터 2", "sheet": "res://assets/textures/standing/char_02_idle.png", "grid": Vector2i(8, 8), "count": 57, "fps": 10.0, "scale": 0.911},
	{"name": "캐릭터 4", "sheet": "res://assets/textures/standing/char_07_idle.png", "grid": Vector2i(7, 6), "count": 37, "fps": 10.0, "scale": 1.0622},
	{"name": "캐릭터 1", "tex": "res://assets/textures/standing/char_01.png", "scale": 0.32},
]

const CENTER := Vector2(270.0, 410.0)     # 타원 중심 (컨트롤 로컬, 발 기준). 목업: 앞 캐릭터 x≈230
const RADIUS := Vector2(135.0, 44.0)      # 타원 반지름 (가로, 세로)
const FRONT_SCALE := 0.78                 # 앞 캐릭터 배율 (스탠딩 576px × 0.78 ≈ 450px)
const BACK_SCALE := 0.62                  # 뒤 캐릭터는 앞의 80~85% (목업 비율)
const DIM := Color(0.28, 0.2, 0.46)       # 뒤 캐릭터 틴트 (남보라 딤드)
const IDLE_PERIOD := 2.5333               # 리그 idle 과 같은 주기 (StandingCharacter 와 동일)
const TURN_SEC := 0.45

var selected := 0
var _angle := 0.0                          # 턴테이블 회전 (선택 캐릭터가 앞에 오게 트윈)
var _items: Array[Dictionary] = []        # {node, kind, sprite, scale, t}
var _tween: Tween
var _name: Label
var _btn_prev: Button
var _btn_next: Button
var _hover := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	SceneSwitcher.pin(self, Vector2(0, 1), Rect2(0, 600, 620, 480))
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
	_name.z_index = 100
	add_child(_name)
	_btn_prev = _arrow("◀", Vector2(16, 404), -1)
	_btn_next = _arrow("▶", Vector2(520, 404), 1)
	_angle = _target_angle(selected)
	_layout(true)


func _arrow(text: String, pos: Vector2, step: int) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(60, 60)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 28)
	b.z_index = 61
	b.pressed.connect(select_next.bind(step))
	add_child(b)
	return b


## 캐릭터 하나: 발이 원점인 Node2D 래퍼. 스틸/시트는 Sprite2D, 리그는 씬 인스턴스.
func _make_item(def: Dictionary) -> Dictionary:
	var wrap := Node2D.new()
	wrap.name = def["name"]
	add_child(wrap)
	var it := {"node": wrap, "kind": "still", "sprite": null, "scale": float(def["scale"]), "t": randf() * IDLE_PERIOD, "def": def}
	if def.has("rig"):
		var rig: Node2D = (load(def["rig"]) as PackedScene).instantiate()
		wrap.add_child(rig)
		it["kind"] = "rig"
		it["sprite"] = rig
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
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_angle", _angle + diff, TURN_SEC)
	_tween.tween_callback(func() -> void: _tween = null)
	selected_changed.emit(selected)


func select_next(step: int) -> void:
	select(selected + step)


func _process(dt: float) -> void:
	for it in _items:
		it["t"] += dt
	_layout(false)


## 타원 위 배치: 각도 a 에서 cos(a)=1 이 맨 앞. depth 0(뒤)~1(앞) 로 크기·밝기·z 를 정한다.
func _layout(_force: bool) -> void:
	var n := _items.size()
	for i in n:
		var it := _items[i]
		var a := _angle + TAU * i / n
		var depth := (cos(a) + 1.0) * 0.5
		var pos := CENTER + Vector2(sin(a) * RADIUS.x, cos(a) * RADIUS.y)
		var node: Node2D = it["node"]
		var s := lerpf(BACK_SCALE, FRONT_SCALE, depth * depth) * float(it["scale"])
		node.position = pos
		node.z_index = int(depth * 50.0)
		var k := pow(depth, 4.0)   # 앞 하나만 밝고 옆(depth 0.5)·뒤는 딤드
		node.modulate = DIM.lerp(Color.WHITE, k)
		if i == _hover and i != selected:
			node.modulate = node.modulate.lightened(0.2)
		var sp = it["sprite"]
		match it["kind"]:
			"sheet":
				var spr := sp as Sprite2D
				spr.frame = int(float(it["t"]) * float(it["def"]["fps"])) % maxi(int(it["def"]["count"]), 1)
				spr.scale = Vector2(s, s)
			"rig":
				(sp as Node2D).scale = Vector2(s, s)
			_:
				# 스틸: 숨쉬기 + 발을 축으로 한 느린 기울임 (StandingCharacter 와 같은 수치)
				var spr := sp as Sprite2D
				var w := TAU * float(it["t"]) / IDLE_PERIOD
				var breath := sin(w)
				var sway := sin(w * 0.5 + 0.8)
				spr.scale = Vector2(s * (1.0 - 0.014 * 0.5 * breath), s * (1.0 + 0.014 * breath))
				spr.rotation = deg_to_rad(0.9) * sway
				spr.position = Vector2(2.0 * sway, 0.0)
	_name.text = ROSTER[selected]["name"]


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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := item_at(event.position)
		if h != _hover:
			_hover = h
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var i := item_at(mb.position)
			if i >= 0:
				select(i)
				accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and item_at(mb.position) >= 0:
			select_next(-1)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and item_at(mb.position) >= 0:
			select_next(1)
			accept_event()
