## 패링 충돌 화면 연출: 방사형 블러 + 색수차 + 집중선 (shaders/parry_impact.gdshader) 과 만화 타이포 팝업("PARRY!").
## 화면 전체 CanvasLayer(12: HUD 위, 화면 글리치 13 아래). 전부 실제 시간으로 돈다 — 히트스탑·슬로모션 중에도 터지고 빠진다.
##   kick(월드 점, 세기, 색)       충돌 순간: 임팩트 프레임(색 반전 섬광) → 블러·색수차·집중선이 확 걸렸다가 풀린다
##   pop(월드 점, 글자, 색)        톱니 폭발 모양 판 위에 글자가 쾅 찍혔다가 튕겨 나간다
## 세기는 vd_parry_fx.gd 의 "7 충돌 화면" 값 (연출 연구실 "패링" 에서 다듬는다).
class_name VDParryImpact
extends CanvasLayer

const Fx := preload("res://scripts/void_defense/vd_parry_fx.gd")
const INK := Color("1b0b38")
const PINK := Color("ff2e88")

static var enabled := true

var _rect: ColorRect
var _mat: ShaderMaterial
var _t0 := -1.0                 # kick 시각 (실제 시간, 초)
var _sec := 0.5
var _amp := 1.0
var _frame := 0


func _init() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/parry_impact.gdshader")
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


func toggle() -> void:
	enabled = not enabled
	if not enabled:
		_rect.visible = false
		_t0 = -1.0


func is_on() -> bool:
	return enabled


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _screen(world_at: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_at


## 충돌 순간. amp: 세기 배율 (성공 1.0, 실패는 조금 약하게), col: 가장자리·임팩트 프레임 색.
func kick(world_at: Vector2, amp := 1.0, col := Color(1.0, 0.9, 0.3), sec := -1.0) -> void:
	if not enabled or amp <= 0.0:
		return
	var size := get_viewport().get_visible_rect().size
	var at := _screen(world_at)
	_mat.set_shader_parameter("center", Vector2(clampf(at.x / size.x, 0.05, 0.95), clampf(at.y / size.y, 0.05, 0.95)))
	_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_mat.set_shader_parameter("tint", col)
	_mat.set_shader_parameter("blur", Fx.g("hit_blur"))
	_mat.set_shader_parameter("chroma", Fx.g("hit_chroma"))
	_mat.set_shader_parameter("lines", Fx.g("hit_lines"))
	_amp = amp
	_sec = sec if sec > 0.0 else Fx.g("hit_sec")
	_t0 = _now()
	_rect.visible = true
	_push()


func _process(_delta: float) -> void:
	if _t0 < 0.0:
		return
	_push()


func _push() -> void:
	var t := _now() - _t0
	if t >= _sec:
		_t0 = -1.0
		_rect.visible = false
		return
	var p := t / _sec
	# 확 걸리고(0.03초) 길게 풀린다. 임팩트 프레임은 처음 두세 프레임만
	var k := minf(t / 0.03, 1.0) * pow(1.0 - p, 1.6)
	_frame += 1
	_mat.set_shader_parameter("k", k * _amp)
	_mat.set_shader_parameter("seed", float(_frame / 3))
	_mat.set_shader_parameter("flash", Fx.g("hit_invert") * _amp * (1.0 if t < 0.05 else 0.0))


## 타이포 팝업: 톱니 폭발 판 + 글자. 충돌점 위쪽 화면에 비스듬히 쾅 찍힌다.
func pop(world_at: Vector2, text: String, col := Color(1.0, 0.93, 0.3)) -> void:
	var scale_k: float = Fx.g("hit_type")
	if not enabled or scale_k <= 0.0:
		return
	var size := get_viewport().get_visible_rect().size
	var at := _screen(world_at)
	at = Vector2(clampf(at.x, size.x * 0.18, size.x * 0.82), clampf(at.y, size.y * 0.2, size.y * 0.8))
	var card := TypeBurst.new()
	card.text = text
	card.col = col
	card.unit = size.y / 1080.0 * scale_k
	card.position = at
	add_child(card)


## 톱니 폭발 판 + 글자 한 장. 실제 시간 트윈.
class TypeBurst extends Node2D:
	var text := "PARRY!"
	var col := Color(1.0, 0.93, 0.3)
	var unit := 1.0
	var _spikes := PackedVector2Array()
	var _inner := PackedVector2Array()
	var _label: Label

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		var n := 14
		for i in n * 2:
			var a := TAU * i / float(n * 2) + randf_range(-0.05, 0.05)
			var r := (randf_range(150.0, 215.0) if i % 2 == 0 else randf_range(84.0, 104.0)) * unit
			_spikes.append(Vector2(cos(a) * r * 1.45, sin(a) * r * 0.72))
			_inner.append(Vector2(cos(a) * r * 1.45, sin(a) * r * 0.72) * 0.8)
		_label = Label.new()
		_label.text = text
		_label.add_theme_font_override("font", VDDamageLog.font())
		_label.add_theme_font_size_override("font_size", int(92.0 * unit))
		_label.add_theme_color_override("font_color", Color.WHITE)
		_label.add_theme_color_override("font_outline_color", VDParryImpact.INK)
		_label.add_theme_constant_override("outline_size", int(26.0 * unit))
		_label.add_theme_color_override("font_shadow_color", VDParryImpact.PINK)
		_label.add_theme_constant_override("shadow_offset_x", int(7.0 * unit))
		_label.add_theme_constant_override("shadow_offset_y", int(8.0 * unit))
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)
		_label.reset_size()
		_label.position = -_label.size * 0.5
		_label.pivot_offset = _label.size * 0.5
		rotation = randf_range(-0.2, -0.1)
		scale = Vector2(0.25, 0.25)
		_label.scale = Vector2(2.2, 2.2)
		var tw := create_tween().set_ignore_time_scale(true)
		tw.tween_property(self, "scale", Vector2(1.28, 1.28), 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_label, "scale", Vector2(0.92, 0.92), 0.09).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "rotation", rotation + 0.04, 0.42)
		tw.tween_property(self, "scale", Vector2(1.5, 0.0), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.11)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		var shadow := PackedVector2Array()
		for p in _spikes:
			shadow.append(p * 1.06 + Vector2(9.0, 11.0) * unit)
		draw_colored_polygon(shadow, VDParryImpact.INK)
		var rim := PackedVector2Array()
		for p in _spikes:
			rim.append(p * 1.07)
		draw_colored_polygon(rim, VDParryImpact.INK)
		draw_colored_polygon(_spikes, VDParryImpact.PINK)
		draw_colored_polygon(_inner, col)
