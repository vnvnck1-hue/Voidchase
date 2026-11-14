## 건너 투사체 '에너지 볼트': 흰 코어 → 분홍·라일락 → 보라 → 남색 꼬리의 창날 모양 탄.
## 쿼드 두 장(더하기 후광 + 몸통)에 생성형 비주얼 셰이더 vfx/gun_bolt/gun_bolt.tres 를 건다 (tools/shaders/build_gun_bolt.gd).
## 셰이더가 텍스처 4장(실루엣 거리장·흐름 노이즈·조각·색 띠)을 겹친다 (tools/vfx/build_gun_bolt_textures.py).
##   VDGunBolt.fire(parent, from, to)            from → to 로 FLIGHT 초 동안 날아가 착탄 뒤 촉으로 빨려 들며 사라진다
##   VDGunBolt.fire(parent, from, to, 0.1, 1.3)  비행 시간·크기 배율
## 촉(쿼드 UV.x ≈ 0.972)이 노드 원점이다. 발사 직후엔 꼬리가 총구에서 자라난다 (len_k).
class_name VDGunBolt
extends Node2D

const SHADER := preload("res://vfx/gun_bolt/gun_bolt.tres")
const SHADER_ADD := preload("res://vfx/gun_bolt/gun_bolt_add.tres")
const FLIGHT := 0.14        # 평타 비행 시간 (초). vd_battle 이 이만큼 늦춰 명중시킨다
const FADE := 0.12          # 착탄 뒤 사라지는 시간
const LEN_PX := 235.0       # 볼트 길이 (크기 배율 1)
const ASPECT := 4.0         # 쿼드 가로:세로 (bolt_shape.png 와 같다)
const TIP_U := 0.972        # 실루엣 촉의 UV.x

var from := Vector2.ZERO
var to := Vector2.ZERO
var flight := FLIGHT
var size_k := 1.0
var tint := Color.WHITE
var _t := 0.0
var _len_at_hit := 1.0
var _mats: Array[ShaderMaterial] = []


static func fire(parent: Node, from_: Vector2, to_: Vector2, flight_ := FLIGHT, size_k_ := 1.0, tint_ := Color.WHITE) -> VDGunBolt:
	var b := VDGunBolt.new()
	b.from = from_
	b.to = to_
	b.flight = maxf(flight_, 0.01)
	b.size_k = size_k_
	b.tint = tint_
	b.z_index = 50
	parent.add_child(b)
	return b


func _ready() -> void:
	position = from
	rotation = (to - from).angle()
	var length := LEN_PX * size_k
	var quad := QuadMesh.new()
	quad.size = Vector2(length, length / ASPECT)
	quad.center_offset = Vector3(-length * (TIP_U - 0.5), 0.0, 0.0)
	var sd := randf() * 100.0
	# 후광(더하기)을 먼저, 그 위에 몸통
	for i in 2:
		var mat := ShaderMaterial.new()
		mat.shader = SHADER_ADD if i == 0 else SHADER
		mat.set_shader_parameter("layer", 1.0 if i == 0 else 0.0)
		mat.set_shader_parameter("seed", sd)
		mat.set_shader_parameter("tint", tint)
		var mi := MeshInstance2D.new()
		mi.mesh = quad
		mi.material = mat
		mi.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # 흐름·조각 텍스처가 이음매 없이 흐르게
		# 실루엣은 위아래 비대칭(큰 불꽃 혀가 위쪽). 쿼드 UV 는 세로가 화면과 반대라 뒤집어 주고,
		# 왼쪽으로 쏠 때는 회전으로 한 번 더 뒤집히므로 그대로 둔다 → 어느 쪽으로 쏴도 혀가 화면 위쪽
		mi.scale.y = -1.0 if to.x >= from.x else 1.0
		add_child(mi)
		_mats.append(mat)
	_apply(_len_k(0.0), 1.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	if _t < flight:
		var k := _t / flight
		position = from.lerp(to, k)
		_len_at_hit = _len_k(k)
		_apply(_len_at_hit, 1.0, 1.0)
		return
	var f := (_t - flight) / FADE
	if f >= 1.0:
		queue_free()
		return
	# 착탄: 꼬리가 촉으로 빨려 들며 갉혀 없어진다
	position = to
	var e := 1.0 - (1.0 - f) * (1.0 - f)
	_apply(lerpf(_len_at_hit, 0.16, e), 1.0 + f * 2.2, 1.0 - f * f)


## 꼬리 길이 비율: 총구에서 나온 만큼만 (꼬리가 총구 뒤로 넘어가 쏘는 캐릭터 얼굴을 덮지 않게. 첫 프레임엔 촉만 보인다).
func _len_k(k: float) -> float:
	var length := LEN_PX * size_k
	return clampf((from.distance_to(to) * k + length * 0.1) / length, 0.1, 1.0)


func _apply(len_k: float, erosion: float, opacity: float) -> void:
	for m in _mats:
		m.set_shader_parameter("len_k", len_k)
		m.set_shader_parameter("erosion", erosion)
		m.set_shader_parameter("opacity", opacity)


## 프로브·쇼룸용: 날아가지 않고 그 자리에 멈춘 볼트 (len_k 고정, 결만 흐른다).
func freeze(len_k := 1.0) -> void:
	set_process(false)
	position = to
	_apply(len_k, 1.0, 1.0)
