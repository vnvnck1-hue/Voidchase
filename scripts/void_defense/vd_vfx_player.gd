## VDVfx 가 만든 플립북 스프라이트의 프레임 진행. 루프가 아니면 마지막 프레임 뒤에 사라진다.
extends Sprite2D

var _t := 0.0
var _spin := 0.0


func _process(delta: float) -> void:
	var info: Dictionary = VDVfx.LIB[get_meta("name")]
	var speed: float = get_meta("speed", 1.0)
	_t += delta * speed
	var frames: int = info["frames"]
	var idx := int(_t * float(info["fps"]))
	if bool(get_meta("loop", false)):
		frame = idx % frames
		var spin := float(get_meta("spin", 0.0))
		if spin != 0.0:
			_spin += spin * delta
			_apply_spin()
	elif idx >= frames:
		queue_free()
	else:
		frame = idx


## 회전은 납작하게 누르기(stretch) 전에 적용한다. 그래야 아이소 바닥의 마법진이 타원 모양은 그대로 두고
## 중심을 축으로 돈다. Node2D 의 rotation 을 바로 돌리면 눌린 타원 자체가 기울어지며 돈다.
func _apply_spin() -> void:
	var stretch: Vector2 = get_meta("stretch", Vector2.ONE)
	var spun := Transform2D(float(get_meta("rot", 0.0)) + _spin, get_meta("base_scale", Vector2.ONE), 0.0, Vector2.ZERO)
	transform = Transform2D(0.0, stretch, 0.0, position) * spun
