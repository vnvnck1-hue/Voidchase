## VDVfx 가 만든 플립북 스프라이트의 프레임 진행. 루프가 아니면 마지막 프레임 뒤에 사라진다.
extends Sprite2D

var _t := 0.0


func _process(delta: float) -> void:
	var info: Dictionary = VDVfx.LIB[get_meta("name")]
	var speed: float = get_meta("speed", 1.0)
	_t += delta * speed
	var frames: int = info["frames"]
	var idx := int(_t * float(info["fps"]))
	if bool(get_meta("loop", false)):
		frame = idx % frames
		rotation += float(get_meta("spin", 0.0)) * delta
	elif idx >= frames:
		queue_free()
	else:
		frame = idx
