## 몬스터 피격 파티클: 터치 게임 데모(Touch_Game_demo)의 몬스터가 맞을 때 터지는 파티클을 그대로 가져왔다.
##   flash     — 노란 별 섬광 (star_ab 알파 + star_add · glow_add 가산) + 데미지 숫자(Damages, 기본 끔)
##   lightning — 아래로 치는 번개 줄기 + 빛 + 먼지 (기본: 강타만)
## 씬 scenes/void_defense/vd_touch_hit.tscn 은 tools/expand/extract_touch_hit.py 가 데모 씬에서 떼어 만든 생성물이다 (손으로 고치지 않는다).
## 파티클은 UnityParticles2D (Unity ParticleSystem CPU 재현) 그대로라 모양·시간은 데모와 같고, 크기·속도·구성·색은 vd_hit_fx.gd 조절값(연출 연구실 "몬스터 피격").
## 예전 스파이크(꽃잎 모양) 피격 대신 VDVfx.spawn("burst") 와 유물 투사체 착탄이 이걸 쓴다.
class_name VDTouchHit
extends Node2D

const P := preload("res://scripts/void_defense/vd_hit_fx.gd")
const SCENE := preload("res://scenes/void_defense/vd_touch_hit.tscn")
const LIFE_MAX := 3.0            # 안전장치: 이보다 오래 남지 않는다 (초, 재생 속도 1 기준)

static var _live: Array = []     # 오래된 것부터 (weakref)

var _age := 0.0
var _emit_sec := 0.6
var _speed := 1.0
var _parts: Array = []
var _stopped := false


## scl 은 예전 시트 배율 (0.35 보통 타격 · 0.5 이상 강타). 크기 = size × scl / 0.45 (× 강타 배) — size 1 · scl 0.45 가 데모 원본 크기.
static func spawn(parent: Node, pos: Vector2, scl := 0.45, heavy := false, tint := Color.WHITE, speed := 1.0) -> VDTouchHit:
	if parent == null:
		return null
	_trim()
	var h: VDTouchHit = SCENE.instantiate()
	h.position = pos
	var k := P.g("size") * scl / 0.45 * (P.g("heavy_size") if heavy else 1.0)
	h.scale = Vector2(k, k)                  # 노드 사이 간격(번개 위치 등)
	h._speed = P.g("speed") * speed
	h._emit_sec = P.g("emit_sec")
	var c := Color.WHITE.lerp(Color(tint.r, tint.g, tint.b), P.g("tint_k"))
	c.a = P.g("alpha") * tint.a
	h.modulate = c
	var lt := int(P.g("lightning"))
	var flash := h.get_node("flash")
	var bolt := h.get_node("lightning")
	flash.visible = P.g("flash") >= 0.5
	bolt.visible = lt == 2 or (lt == 1 and heavy)
	(h.get_node("flash/star_ab/Damages") as UnityParticles2D).renderer_enabled = P.g("digits") >= 0.5
	for n in _particles(h):
		n.size_mul = k                        # 파티클 크기·속도·궤적
		n.speed_mul = h._speed
	parent.add_child(h)
	if flash.visible:
		flash.play()
	if bolt.visible:
		bolt.play()
	_live.append(weakref(h))
	return h


static func _particles(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is UnityParticles2D:
			out.append(c)
		out.append_array(_particles(c))
	return out


## 동시에 너무 많으면 가장 오래된 것부터 지운다
static func _trim() -> void:
	_live = _live.filter(func(w: WeakRef) -> bool: return w.get_ref() != null)
	var cap := int(P.g("max_live"))
	while _live.size() >= cap and not _live.is_empty():
		var old = _live.pop_front().get_ref()
		if old:
			old.queue_free()


func _process(delta: float) -> void:
	_age += delta * _speed
	if not _stopped and _age >= _emit_sec:
		# 반복(loop) 방출기(먼지·숫자)는 여기서 멈춘다. 이미 나온 파티클은 수명대로 사라진다
		_stopped = true
		for n in [get_node("flash"), get_node("lightning")]:
			n.stop()
	if _stopped:
		if _parts.is_empty():
			_parts = _particles(self)   # 하위 트리를 매 프레임 훑지 않게 한 번만 모은다
		var alive := false
		for n in _parts:
			if n.is_alive():
				alive = true
				break
		if not alive:
			queue_free()
	if _age > LIFE_MAX:
		queue_free()
