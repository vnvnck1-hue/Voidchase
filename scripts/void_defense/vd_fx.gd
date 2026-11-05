## 그레이박스 이펙트: 탄도선 / 피격 링 / 떠오르는 숫자. 수명이 끝나면 스스로 사라진다.
class_name VDFx
extends Node2D

var kind := "hit"          # "tracer" | "hit" | "number"
var to := Vector2.ZERO     # tracer: 끝점 (부모 로컬)
var color := Color.WHITE
var text := ""
var life := 0.3
var _t := 0.0


static func tracer(parent: Node, from: Vector2, to_: Vector2, col: Color) -> VDFx:
	var f := VDFx.new()
	f.kind = "tracer"
	f.position = from
	f.to = to_
	f.color = col
	f.life = 0.18
	f.z_index = 50
	parent.add_child(f)
	return f


static func hit(parent: Node, at: Vector2, col: Color) -> VDFx:
	var f := VDFx.new()
	f.kind = "hit"
	f.position = at
	f.color = col
	f.life = 0.28
	f.z_index = 50
	parent.add_child(f)
	return f


static func number(parent: Node, at: Vector2, txt: String, col: Color) -> VDFx:
	var f := VDFx.new()
	f.kind = "number"
	f.position = at + Vector2(randf_range(-10, 10), 0)
	f.text = txt
	f.color = col
	f.life = 0.8
	f.z_index = 60
	parent.add_child(f)
	return f


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	if kind == "number":
		position.y -= 45.0 * delta
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / life
	match kind:
		"tracer":
			draw_line(Vector2.ZERO, to - position, Color(color, a), 3.0)
		"hit":
			draw_arc(Vector2.ZERO, 8.0 + 30.0 * (_t / life), 0.0, TAU, 24, Color(color, a), 3.0)
		"number":
			draw_string(VDData.font(), Vector2(-50, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 20, Color(color, a))
