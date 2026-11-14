## 그레이박스 이펙트: 탄도선. 수명이 끝나면 스스로 사라진다.
## (예전 피격 링·떠오르는 숫자는 VDVfx 플립북·VDDamageLog 로 옮겨져 쓰이지 않아 2026-11-10 정리)
class_name VDFx
extends Node2D

var to := Vector2.ZERO     # 끝점 (부모 로컬)
var color := Color.WHITE
var life := 0.18
var _t := 0.0


static func tracer(parent: Node, from: Vector2, to_: Vector2, col: Color) -> VDFx:
	var f := VDFx.new()
	f.position = from
	f.to = to_
	f.color = col
	f.z_index = 50
	parent.add_child(f)
	return f


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	draw_line(Vector2.ZERO, to - position, Color(color, 1.0 - _t / life), 3.0)
