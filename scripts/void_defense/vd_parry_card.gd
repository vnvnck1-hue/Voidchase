## 패링 대상 강조 (분대 카드 위): 컨셉 PSD '캐릭터 강조 효과 예시' 그룹을 그대로 옮겼다.
##   레이어 67 복사 2  카드 위로 솟는 노란 빛기둥      → beam_up.png + parry_beam 셰이더 (밑에서 차오르고, 빛 띠가 위로 흐른다)
##   레이어 67 ×2      카드를 덮는 노란 빛(두 겹)        → beam_low.png (gain 으로 두 겹 몫)
##   그룹 292          카드 윗변의 반짝이 셋             → sparkle_a/b/c.png: 하나씩 엇박으로 "팟" 튀어나와 제각각 깜빡인다
## 좌표는 캐릭터 패널 텍스처 px (원점 = 카드 왼쪽 위, 폭 300) — VDBattleFrame 이 카드와 같은 변환을 매 프레임 넣는다.
## 그 위에 눌러야 할 단축키 키캡이 통통 튄다. 연출은 실제 시간 (예고 순간의 히트스탑·슬로모션과 상관없이 바로 보인다).
class_name VDParryCard
extends Node2D

const L := preload("res://scripts/void_defense/vd_parry_layout.gd")
const BeamShader := preload("res://shaders/parry_beam.tres")
const Fx := preload("res://scripts/void_defense/vd_parry_fx.gd")   # 연출 연구실 "패링" 의 "6 카드 강조"

var key_text := ""
var _up: Sprite2D
var _low: Sprite2D
var _sparks: Array[Sprite2D] = []
var _key: Node2D
var _tw: Array[Tween] = []
var _leaving := false
var _sk := 1.0                   # 반짝이 배율 (패널 px 배율 × spark_scale)


func _ready() -> void:
	_sk = L.PANEL_K * Fx.g("spark_scale")
	_low = _beam("beam_low.png", L.BEAM_LOW_POS, L.BEAM_LOW_SIZE, 0.0, false)
	_up = _beam("beam_up.png", L.BEAM_UP_POS, L.BEAM_UP_SIZE, 1.0, true)
	for it in L.SPARKLES:
		var s := Sprite2D.new()
		s.texture = load(L.DIR + String(it[0]))
		s.centered = false
		s.offset = -(it[2] as Vector2)
		s.position = it[1]
		s.scale = Vector2.ZERO
		add_child(s)
		_sparks.append(s)
	_key = Node2D.new()
	_key.position = Vector2(150.0, -128.0)
	_key.scale = Vector2.ZERO
	_key.draw.connect(_draw_key)
	add_child(_key)
	_play_in()


## 빛 한 장. bottom_pivot: 밑변을 축으로 세로 배율을 줄 수 있게 아래쪽에 원점을 둔다.
func _beam(file: String, pos: Vector2, size: Vector2, base: float, bottom_pivot: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(L.DIR + file)
	s.centered = false
	s.scale = Vector2.ONE * L.PANEL_K
	if bottom_pivot:
		s.offset = Vector2(0, -size.y)
		s.position = pos + Vector2(0, size.y * L.PANEL_K)
	else:
		s.position = pos
	var m := ShaderMaterial.new()
	m.shader = BeamShader
	m.set_shader_parameter("base", base)
	m.set_shader_parameter("reveal", 0.0)
	s.material = m
	add_child(s)
	return s


func _rt() -> Tween:
	var tw := create_tween().set_ignore_time_scale(true)
	_tw.append(tw)
	return tw


static func _sp(n: Sprite2D, key: String, v: Variant) -> void:
	(n.material as ShaderMaterial).set_shader_parameter(key, v)


func _play_in() -> void:
	var k := L.PANEL_K
	# 카드가 먼저 번쩍 덮이고
	var lt := _rt()
	lt.tween_method(func(v: float) -> void: _sp(_low, "reveal", v), 0.0, 1.0, 0.09)
	lt.parallel().tween_method(func(v: float) -> void: _sp(_low, "gain", v), 2.6, Fx.g("card_low"), 0.3)
	# 빛기둥이 밑에서 솟구쳐 넘쳤다가 제 높이로
	_up.scale = Vector2(k * 0.6, k * 0.2)
	var ut := _rt()
	ut.tween_method(func(v: float) -> void: _sp(_up, "reveal", v), 0.0, 1.0, 0.12)
	ut.parallel().tween_property(_up, "scale", Vector2(k * 1.06, k * Fx.g("card_over")), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ut.parallel().tween_method(func(v: float) -> void: _sp(_up, "gain", v), 2.6, Fx.g("card_up"), 0.35)
	ut.tween_property(_up, "scale", Vector2(k, k), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 반짝이: 왼쪽부터 하나씩 팟 → 제각각 깜빡임
	for i in _sparks.size():
		var s := _sparks[i]
		s.rotation = -0.5
		var st := _rt()
		st.tween_interval(0.05 + Fx.g("spark_gap") * i)
		st.tween_property(s, "scale", Vector2(_sk * 0.5, _sk * 1.9), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		st.parallel().tween_property(s, "rotation", 0.08, 0.06)
		st.tween_property(s, "scale", Vector2(_sk, _sk), 0.26).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		st.parallel().tween_property(s, "rotation", 0.0, 0.18)
		st.tween_callback(_twinkle.bind(s, i))
	# 키캡: 통 튀어나와 계속 통통
	var kt := _rt()
	kt.tween_interval(0.08)
	kt.tween_property(_key, "scale", Vector2(1.5, 1.5), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	kt.tween_property(_key, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	kt.tween_callback(func() -> void:
		if _leaving:
			return
		var loop := _rt().set_loops()
		loop.tween_property(_key, "scale", Vector2(1.14, 1.14), 0.11).set_trans(Tween.TRANS_SINE)
		loop.tween_property(_key, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_SINE))


func _twinkle(s: Sprite2D, i: int) -> void:
	if _leaving:
		return
	var k := _sk
	var period := 0.16 + 0.05 * i
	var loop := _rt().set_loops()
	loop.tween_property(s, "scale", Vector2(k * 0.8, k * 1.12), period).set_trans(Tween.TRANS_SINE)
	loop.parallel().tween_property(s, "modulate", Color(1.5, 1.5, 1.2), period)
	loop.tween_property(s, "scale", Vector2(k * 1.05, k * 0.9), period).set_trans(Tween.TRANS_SINE)
	loop.parallel().tween_property(s, "modulate", Color.WHITE, period)


func _draw_key() -> void:
	var ks := Fx.g("key_scale")
	if key_text == "" or ks <= 0.0:
		return
	_key.draw_set_transform(Vector2.ZERO, 0.0, Vector2(ks, ks))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.32, 0.2, 0.03, 0.96)
	box.border_color = Color(1.0, 0.93, 0.45)
	box.set_border_width_all(4)
	box.border_width_bottom = 8
	box.set_corner_radius_all(12)
	var sz := Vector2(84.0, 78.0)
	_key.draw_style_box(box, Rect2(-sz * 0.5, sz))
	var font := VDData.font()
	_key.draw_string_outline(font, Vector2(-sz.x * 0.5, 16.0), key_text, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 48, 8, Color(0.2, 0.1, 0.0))
	_key.draw_string(font, Vector2(-sz.x * 0.5, 16.0), key_text, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 48, Color(1.0, 0.97, 0.7))
	_key.draw_string_outline(font, Vector2(-80.0, 76.0), "패링!", HORIZONTAL_ALIGNMENT_CENTER, 160.0, 32, 8, Color(0.2, 0.08, 0.0))
	_key.draw_string(font, Vector2(-80.0, 76.0), "패링!", HORIZONTAL_ALIGNMENT_CENTER, 160.0, 32, Color(1.0, 0.93, 0.45))


## 강조 끝. success: 빛기둥이 위로 치솟으며 반짝이가 크게 터진다 / 아니면 조용히 꺼진다.
func leave(success: bool) -> void:
	if _leaving:
		return
	_leaving = true
	for tw in _tw:
		if tw and tw.is_valid():
			tw.kill()
	_tw.clear()
	var k := L.PANEL_K
	var out := create_tween().set_ignore_time_scale(true).set_parallel(true)
	if success:
		_sp(_up, "reveal", 1.0)
		_sp(_low, "reveal", 1.0)
		out.tween_property(_up, "scale", Vector2(k * 1.25, k * 2.6), 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		out.tween_method(func(v: float) -> void:
			_sp(_up, "gain", 4.0 * v)
			_sp(_low, "gain", 5.0 * v)
			_sp(_up, "alpha_k", v)
			_sp(_low, "alpha_k", v), 1.0, 0.0, 0.4)
		for s in _sparks:
			out.tween_property(s, "scale", Vector2(_sk * 2.3, _sk * 2.3), 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			out.tween_property(s, "modulate", Color(2.0, 2.0, 1.6, 0.0), 0.36)
		out.tween_property(_key, "scale", Vector2(1.9, 1.9), 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		out.tween_property(_key, "modulate:a", 0.0, 0.26)
	else:
		out.tween_method(func(v: float) -> void:
			_sp(_up, "alpha_k", v)
			_sp(_low, "alpha_k", v), 1.0, 0.0, 0.16)
		for s in _sparks:
			out.tween_property(s, "scale", Vector2(0.0, _sk * 1.4), 0.14)
		out.tween_property(_key, "scale", Vector2.ZERO, 0.12)
	out.chain().tween_callback(queue_free)
