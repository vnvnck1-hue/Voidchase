## 기사 검기: VFX연구 vfx/sword_slash 의 CEL(셀 초승달)만 옮긴 한 번 재생용 버전. 끝나면 스스로 사라진다.
## 타이밍은 30fps 프레임(f) 단위: f0–3 순백 스윕 · f3 색 진입 · f4–14 얇아지며 셀 단계 3→1.
## 쿼드 한 장(Sprite2D + 셰이더)이 레이어 하나이고, 쿼드 중심이 호의 중심이다.
##   VDSwordSlash.spawn(parent, center, size, aim, flip)
class_name VDSwordSlash
extends Node2D

const SHADER := preload("res://shaders/sword_slash_cel.gdshader")
const END_FRAME := 15.0

var size := 200.0            ## 쿼드 한 변 (px)
var arc_start := 0.58        ## 시작 각 (turns, 0 = 오른쪽, 0.25 = 아래)
var arc_sweep := 0.5         ## 휘두르는 각 (turns, + = 시계 방향)
var tint := Color.WHITE

var _t := 0.0
var _shards_done := false
var _layers: Array[Sprite2D] = []
var _shards: Array[Dictionary] = []

static var _tex: ImageTexture


## aim 방향(라디안)을 가운데로 위→아래로 휘두르는 초승달을 center 에 띄운다. flip 이면 반대로 돈다.
static func spawn(parent: Node, center: Vector2, sz: float, aim: float, flip := false,
		sweep := 0.42, col := Color.WHITE) -> VDSwordSlash:
	var s := VDSwordSlash.new()
	var sw := -sweep if flip else sweep
	s.arc_sweep = sw
	s.arc_start = aim / TAU - sw * 0.5
	s.size = sz
	s.tint = col
	s.position = center
	parent.add_child(s)
	return s


func _ready() -> void:
	if _tex == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_tex = ImageTexture.create_from_image(img)
	# 보조 호 2줄(안쪽 굵은 줄, 바깥 실선) → 본체 순으로 쌓는다
	_add_layer({"radius": 0.35, "thickness": 0.04, "edge_band": 0.45, "body_band": 1.2,
		"col_body": Color(0.6, 0.92, 1.0), "glow": 0.0, "seed": 11.0})
	_add_layer({"radius": 0.462, "thickness": 0.01, "edge_band": 1.2, "glow": 0.0, "seed": 23.0})
	_add_layer({"radius": 0.42, "thickness": 0.15, "glow_width": 0.022})
	modulate = tint
	_update(0.0)


func _process(delta: float) -> void:
	_t += delta
	var f := _t * 30.0
	if f > END_FRAME:
		queue_free()
		return
	_update(f)
	_step_shards(delta)


func _update(f: float) -> void:
	var main := _mat(2)
	main.set_shader_parameter("head", _out(_seg(f, 0.0, 3.0), 3.0))
	main.set_shader_parameter("tail", _in(_seg(f, 4.0, 12.0), 1.8))
	main.set_shader_parameter("thin", 1.0 - 0.6 * _in(_seg(f, 4.0, 12.0), 1.4))
	main.set_shader_parameter("split", _seg(f, 6.0, 12.0))
	# 섬광: 스윕 f0–2 는 순백 단색, f3 에 색이 들어온다 (셀은 중간톤 없이 한 프레임에 바뀐다)
	main.set_shader_parameter("flash", 1.0 if f < 3.0 else 0.0)
	main.set_shader_parameter("energy", lerpf(1.25, 1.0, _seg(f, 3.0, 5.0)))
	main.set_shader_parameter("glow", 0.8 * (1.0 - _seg(f, 3.0, 9.0)))
	# 셀 단계 감쇠 3 → 2 → 1: 하늘색 몸통 먼저 빠지고, 마지막엔 흰 날 한 줄
	main.set_shader_parameter("body_band", lerpf(0.7, 0.26, _seg(f, 6.0, 9.0)))
	main.set_shader_parameter("edge_band", lerpf(0.26, 1.2, _seg(f, 9.0, 11.0)))
	main.set_shader_parameter("opacity", 1.0 - _seg(f, 11.0, 14.0))
	# 보조 호는 1f / 2f 늦게 따라와서 먼저 빠진다
	for i in 2:
		var d := 1.0 + i
		var m := _mat(i)
		# 안쪽 호는 본체 칼끝보다 먼저 멈춰야 좁은 칼끝 밖으로 삐져나오지 않는다
		var reach := 0.88 if i == 0 else 1.0
		m.set_shader_parameter("head", reach * _out(_seg(f, d, d + 3.0), 3.0))
		m.set_shader_parameter("tail", reach * _in(_seg(f, d + 2.0, d + 8.0), 1.6))
		m.set_shader_parameter("opacity", 1.0 - _seg(f, d + 6.0, d + 9.0))
	if not _shards_done and f >= 2.5:
		_shards_done = true
		var k := size / 480.0   # 원본은 480px 기준으로 맞춘 속도·크기
		for i in 4:
			var a := _angle(randf_range(0.7, 1.0))
			_shards.append({"pos": _arc_point(a, 0.42 - randf() * 0.04),
				"vel": (_tangent(a) * randf_range(450.0, 800.0) + _out_dir(a) * randf_range(0.0, 200.0)) * k,
				"life": randf_range(0.12, 0.22), "age": 0.0, "size": randf_range(11.0, 17.0) * k})


# ---------------------------------------------------------------- 파편 (속도 방향으로 늘어난 마름모)

func _step_shards(delta: float) -> void:
	if _shards.is_empty():
		return
	var damp := exp(-9.0 * delta)
	for p in _shards:
		p.age += delta
		p.vel *= damp
		p.pos += p.vel * delta
	_shards = _shards.filter(func(p: Dictionary) -> bool: return p.age < p.life)
	queue_redraw()


func _draw() -> void:
	for p in _shards:
		var t: float = p.age / p.life
		var sz: float = p.size * (1.0 - t * t)
		if sz < 0.3:
			continue
		var col := Color(1.0, 1.0, 1.0).lerp(Color(0.5, 0.88, 1.0), clampf(t / 0.35, 0.0, 1.0))
		col.a = 1.0 - t
		var speed: float = p.vel.length()
		var dir: Vector2 = p.vel / speed if speed > 1.0 else Vector2.RIGHT
		var side := dir.orthogonal()
		var length := sz * (1.0 + speed * 0.008 * 480.0 / size)
		draw_colored_polygon(PackedVector2Array([
			p.pos + dir * length, p.pos + side * sz * 0.35,
			p.pos - dir * length * 0.5, p.pos - side * sz * 0.35]), col)


# ---------------------------------------------------------------- 공용

func _add_layer(params: Dictionary) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("arc_start", arc_start)
	mat.set_shader_parameter("arc_sweep", arc_sweep)
	for k in params:
		mat.set_shader_parameter(k, params[k])
	var spr := Sprite2D.new()
	spr.texture = _tex
	spr.scale = Vector2.ONE * size / 4.0
	spr.material = mat
	add_child(spr)
	_layers.append(spr)


func _mat(i: int) -> ShaderMaterial:
	return _layers[i].material


func _angle(u: float) -> float:
	return (arc_start + arc_sweep * u) * TAU


func _arc_point(a: float, r: float) -> Vector2:
	return Vector2(cos(a), sin(a)) * r * size


func _tangent(a: float) -> Vector2:
	return Vector2(-sin(a), cos(a)) * signf(arc_sweep)


func _out_dir(a: float) -> Vector2:
	return Vector2(cos(a), sin(a))


static func _seg(f: float, a: float, b: float) -> float:
	return clampf((f - a) / (b - a), 0.0, 1.0)


static func _out(x: float, p: float) -> float:
	return 1.0 - pow(1.0 - x, p)


static func _in(x: float, p: float) -> float:
	return pow(x, p)
